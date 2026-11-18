//
//  AuthenticationService.swift
//  OperaApp
//
//  Sign-in against Neon's Managed Better Auth.
//
//  The public surface is unchanged from the Supabase version -- same
//  @Published properties, same method signatures -- so no view had to be
//  touched when the backend moved. Only what happens inside changed.
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

enum AuthenticationError: LocalizedError {
    case missingAppleIdentityToken
    case notAuthenticated
    case emailConfirmationRequired
    case appleSignInNotConfigured

    var errorDescription: String? {
        switch self {
        case .missingAppleIdentityToken:
            return "Apple did not return an identity token."
        case .notAuthenticated:
            return "You need to be signed in to do that."
        case .emailConfirmationRequired:
            return "Check your inbox to confirm your email address, then sign in."
        case .appleSignInNotConfigured:
            return "Sign in with Apple is not set up for this project yet. See NEON_SETUP.md."
        }
    }
}

// MARK: - Wire shapes

/// Rows as the Data API returns them. NeonClient decodes with
/// convertFromSnakeCase, so these are camelCase here and snake_case on the
/// wire -- deliberately not hand-spelled, which is where the Supabase
/// version accumulated typos.
private struct ProfileRow: Codable {
    let id: UUID
    var email: String
    var displayName: String?
    var profileImageUrl: String?
    var bio: String?
    var isProfilePublic: Bool
    var showStats: Bool
    var showLists: Bool
    var favoriteComposers: [String]
    var favoriteChoreographers: [String]
    var favoriteEras: [String]
    var favoriteHouses: [String]
    var primaryHouse: String?
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    func asUser(totalExperienced: Int, totalWishlist: Int) -> User {
        User(
            id: id.uuidString,
            email: email,
            displayName: displayName,
            profileImageURL: profileImageUrl,
            bio: bio,
            isProfilePublic: isProfilePublic,
            showStats: showStats,
            showLists: showLists,
            favoriteComposers: favoriteComposers,
            favoriteChoreographers: favoriteChoreographers,
            favoriteEras: favoriteEras,
            favoriteHouses: favoriteHouses,
            totalExperienced: totalExperienced,
            totalWishlist: totalWishlist,
            primaryHouse: primaryHouse,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct CountRow: Decodable { let count: Int }

/// Better Auth returns the session token alongside the user on sign-in and
/// sign-up. `token` here is the *session*, not the JWT -- see NeonClient.
private struct AuthSession: Decodable {
    let token: String
    let user: AuthUser
}

private struct AuthUser: Decodable {
    let id: UUID
    let email: String
    let name: String?
}

// MARK: - Service

@MainActor
final class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()

    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding = false
    @Published var authToken: String?

    private var appleSignInCoordinator: AppleSignInCoordinator?

    private override init() {
        super.init()
    }

    // MARK: Session

    func checkAuthStatus() {
        isLoading = true
        Task {
            // A stored session is not proof of a usable one: it can have been
            // revoked, or the account deleted. Minting a JWT is the cheapest
            // way to actually ask, so a dead session logs out cleanly instead
            // of leaving the app in a signed-in state that fails every call.
            do {
                authToken = try await NeonClient.shared.jwt()
                isAuthenticated = true
                await afterSignIn()
            } catch {
                await NeonClient.shared.signOut()
                isAuthenticated = false
                authToken = nil
                currentUser = nil
            }
            isLoading = false
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await NeonClient.shared.auth(
            "sign-in/email",
            body: ["email": email, "password": password],
            as: AuthSession.self)
        try await establish(session)
    }

    func signUp(email: String, password: String, displayName: String?) async throws {
        var body: [String: Any] = ["email": email, "password": password]
        // Better Auth requires a name; the display name is the natural one,
        // and the email's local part is a better fallback than an empty
        // string, which it rejects.
        body["name"] = displayName ?? String(email.prefix(while: { $0 != "@" }))

        let session = try await NeonClient.shared.auth(
            "sign-up/email", body: body, as: AuthSession.self)
        try await establish(session)
    }

    /// Native Sign in with Apple: the identity token Apple hands back is
    /// posted straight to Better Auth, so the app never opens a web view.
    ///
    /// Requires the Apple provider to be configured on the Neon project.
    /// Until it is, Better Auth answers with a provider error, which is
    /// translated here rather than surfaced as a raw failure.
    func signInWithApple() async throws {
        let coordinator = AppleSignInCoordinator()
        appleSignInCoordinator = coordinator
        defer { appleSignInCoordinator = nil }

        let credential = try await coordinator.performSignIn()
        guard
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthenticationError.missingAppleIdentityToken
        }

        var idToken: [String: Any] = ["token": identityToken]
        if let nonce = coordinator.rawNonce { idToken["nonce"] = nonce }

        var body: [String: Any] = ["provider": "apple", "idToken": idToken]
        // Apple sends the name only on the very first authorization, so it
        // has to be captured then or it is gone for good.
        if let name = credential.fullName,
           let formatted = PersonNameComponentsFormatter().string(for: name).nilIfBlank {
            body["name"] = formatted
        }

        do {
            let session = try await NeonClient.shared.auth(
                "sign-in/social", body: body, as: AuthSession.self)
            try await establish(session)
        } catch let error as NeonError {
            if case let .auth(_, code, _) = error,
               code == "PROVIDER_NOT_FOUND" || code == "INVALID_PROVIDER" {
                throw AuthenticationError.appleSignInNotConfigured
            }
            throw error
        }
    }

    func signOut() {
        Task {
            await NeonClient.shared.signOut()
            isAuthenticated = false
            authToken = nil
            currentUser = nil
            hasCompletedOnboarding = false
        }
    }

    private func establish(_ session: AuthSession) async throws {
        await NeonClient.shared.store(sessionToken: session.token)
        authToken = try await NeonClient.shared.jwt()
        isAuthenticated = true
        await afterSignIn()
    }

    /// Creates the profile and the two default lists if they are missing.
    ///
    /// On Supabase a trigger on auth.users did this at signup.
    /// neon_auth."user" is platform-managed and will not take a trigger, so
    /// the database exposes an idempotent function instead and both clients
    /// call it. Calling it on every sign-in is intended: it costs one request
    /// and it self-heals an account whose bootstrap failed first time.
    private func afterSignIn() async {
        do {
            try await NeonClient.shared.rpc("ensure_user_bootstrap")
        } catch {
            // Not fatal on its own -- the profile may simply already exist.
            // fetchUserProfile below is what decides whether we are usable.
        }
        await fetchUserProfile()
    }

    // MARK: Profile

    private func fetchUserProfile() async {
        do {
            // RLS scopes this to the caller, so no user id is needed in the
            // query: "the profile I am allowed to see" is the right one.
            let rows = try await NeonClient.shared.get(
                "profiles", query: "select=*&limit=1", as: [ProfileRow].self)
            guard let row = rows.first else {
                currentUser = nil
                return
            }
            let (experienced, wishlist) = await counts()
            currentUser = row.asUser(totalExperienced: experienced, totalWishlist: wishlist)
            hasCompletedOnboarding = row.hasCompletedOnboarding
        } catch {
            currentUser = nil
        }
    }

    /// Two exact counts, asked for with Prefer: count=exact and no rows, so
    /// the totals do not depend on downloading every row to count it.
    private func counts() async -> (Int, Int) {
        async let logs = try? NeonClient.shared.count("attendance_logs")
        async let wishes = try? NeonClient.shared.count(
            "list_items",
            select: "id,user_lists!inner(type)",
            filter: "user_lists.type=eq.wants_to_experience")
        return (await logs ?? 0, await wishes ?? 0)
    }

    func completeOnboarding(tasteProfile: UserTasteProfile) async {
        struct Patch: Encodable {
            let favoriteComposers: [String]
            let favoriteChoreographers: [String]
            let favoriteEras: [String]
            let favoriteHouses: [String]
            let hasCompletedOnboarding: Bool
        }
        do {
            _ = try await NeonClient.shared.patch(
                "profiles",
                query: "select=*",
                body: Patch(
                    favoriteComposers: tasteProfile.composers,
                    favoriteChoreographers: tasteProfile.choreographers,
                    favoriteEras: tasteProfile.eras,
                    favoriteHouses: tasteProfile.houses,
                    hasCompletedOnboarding: true),
                as: [ProfileRow].self)
            hasCompletedOnboarding = true
            await fetchUserProfile()
        } catch {
            // Left false, so onboarding is offered again rather than being
            // silently skipped with nothing saved.
        }
    }

    func updateUserProfile(_ user: User) async throws {
        struct Patch: Encodable {
            let displayName: String?
            let bio: String?
            let isProfilePublic: Bool
            let showStats: Bool
            let showLists: Bool
            let favoriteComposers: [String]
            let favoriteChoreographers: [String]
            let favoriteEras: [String]
            let favoriteHouses: [String]
            let primaryHouse: String?
        }
        _ = try await NeonClient.shared.patch(
            "profiles",
            query: "select=*",
            body: Patch(
                displayName: user.displayName,
                bio: user.bio,
                isProfilePublic: user.isProfilePublic,
                showStats: user.showStats,
                showLists: user.showLists,
                favoriteComposers: user.favoriteComposers,
                favoriteChoreographers: user.favoriteChoreographers,
                favoriteEras: user.favoriteEras,
                favoriteHouses: user.favoriteHouses,
                primaryHouse: user.primaryHouse),
            as: [ProfileRow].self)
        await fetchUserProfile()
    }

    func deleteAccount() async throws {
        // Better Auth owns the user record; the app's own rows go with it
        // through `on delete cascade` on the foreign keys into
        // neon_auth."user".
        _ = try await NeonClient.shared.auth(
            "delete-user", body: [:], as: EmptyResponse.self)
        await NeonClient.shared.signOut()
        isAuthenticated = false
        authToken = nil
        currentUser = nil
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

// MARK: - Apple Sign In

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
                                            ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    /// Kept so it can be sent to the server, which must compare it against
    /// the hash inside the identity token. Without that check an intercepted
    /// token could be replayed.
    private(set) var rawNonce: String?

    func performSignIn() async throws -> ASAuthorizationAppleIDCredential {
        let nonce = Self.randomNonce()
        rawNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthenticationError.missingAppleIdentityToken)
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // The key window of the active foreground scene. UIApplication.windows
        // is deprecated and returns the wrong window under multiple scenes.
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? ASPresentationAnchor()
    }

    private static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
