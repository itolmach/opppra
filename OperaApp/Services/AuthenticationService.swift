//
//  AuthenticationService.swift
//  OperaApp
//
//  Handles user authentication and session management via Supabase Auth.
//

import Foundation
import SwiftUI
import UIKit
import AuthenticationServices
import Supabase

enum AuthenticationError: LocalizedError {
    case missingAppleIdentityToken
    case notAuthenticated
    case emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .missingAppleIdentityToken:
            return "Apple didn't return an identity token. Please try again."
        case .notAuthenticated:
            return "You need to be signed in to do that."
        case .emailConfirmationRequired:
            return "Check your email to confirm your account, then sign in."
        }
    }
}

// Row shape of `public.profiles`, decoded/encoded directly against Supabase.
private struct ProfileRow: Codable {
    let id: UUID
    var email: String
    var display_name: String?
    var profile_image_url: String?
    var bio: String?
    var is_profile_public: Bool
    var show_stats: Bool
    var show_lists: Bool
    var favorite_composers: [String]
    var favorite_choreographers: [String]
    var favorite_eras: [String]
    var favorite_houses: [String]
    var primary_house: String?
    var has_completed_onboarding: Bool
    var created_at: Date
    var updated_at: Date

    func asUser(totalExperienced: Int, totalWishlist: Int) -> User {
        User(
            id: id.uuidString,
            email: email,
            displayName: display_name,
            profileImageURL: profile_image_url,
            bio: bio,
            isProfilePublic: is_profile_public,
            showStats: show_stats,
            showLists: show_lists,
            favoriteComposers: favorite_composers,
            favoriteChoreographers: favorite_choreographers,
            favoriteEras: favorite_eras,
            favoriteHouses: favorite_houses,
            totalExperienced: totalExperienced,
            totalWishlist: totalWishlist,
            primaryHouse: primary_house,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

private struct ProfileStatsRow: Codable {
    let total_experienced: Int
    let total_wishlist: Int
}

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()

    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding = false
    @Published var authToken: String?

    private var client: SupabaseClient { SupabaseManager.client }
    private var appleSignInCoordinator: AppleSignInCoordinator?

    private override init() {
        super.init()
    }

    func checkAuthStatus() {
        isLoading = true
        Task {
            do {
                let session = try await client.auth.session
                authToken = session.accessToken
                isAuthenticated = true
                await fetchUserProfile()
            } catch {
                isAuthenticated = false
                authToken = nil
            }
            isLoading = false
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        authToken = session.accessToken
        isAuthenticated = true
        await fetchUserProfile()
    }

    func signUp(email: String, password: String, displayName: String?) async throws {
        let metadata: [String: JSONValue]? = displayName.map { ["display_name": .string($0)] }
        let response = try await client.auth.signUp(email: email, password: password, data: metadata)

        guard let session = response.session else {
            // Email confirmation is required by the project's auth settings;
            // there's no session yet. Surface that distinctly so the UI can
            // tell the user to check their inbox instead of showing a
            // generic failure.
            throw AuthenticationError.emailConfirmationRequired
        }

        authToken = session.accessToken
        isAuthenticated = true
        await fetchUserProfile()
    }

    func signInWithApple() async throws {
        let coordinator = AppleSignInCoordinator()
        appleSignInCoordinator = coordinator
        let credential = try await coordinator.performSignIn()

        guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthenticationError.missingAppleIdentityToken
        }

        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken)
        )
        authToken = session.accessToken
        isAuthenticated = true

        if let given = credential.fullName?.givenName {
            let displayName = [given, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            try? await setDisplayNameIfMissing(displayName, userId: session.user.id)
        }

        await fetchUserProfile()
    }

    func signOut() {
        let currentClient = client
        Task { try? await currentClient.auth.signOut() }
        authToken = nil
        currentUser = nil
        isAuthenticated = false
        hasCompletedOnboarding = false
    }

    func completeOnboarding(tasteProfile: UserTasteProfile) async {
        guard let userId = try? await client.auth.session.user.id else { return }

        struct Update: Encodable {
            let favorite_composers: [String]
            let favorite_choreographers: [String]
            let favorite_eras: [String]
            let favorite_houses: [String]
            let has_completed_onboarding: Bool
        }
        let update = Update(
            favorite_composers: tasteProfile.composers,
            favorite_choreographers: tasteProfile.choreographers,
            favorite_eras: tasteProfile.eras,
            favorite_houses: tasteProfile.houses,
            has_completed_onboarding: true
        )

        do {
            try await client.from("profiles").update(update).eq("id", value: userId).execute()
            currentUser?.favoriteComposers = tasteProfile.composers
            currentUser?.favoriteChoreographers = tasteProfile.choreographers
            currentUser?.favoriteEras = tasteProfile.eras
            currentUser?.favoriteHouses = tasteProfile.houses
            hasCompletedOnboarding = true
        } catch {
            print("⚠️ Failed to save taste profile: \(error)")
        }
    }

    private func setDisplayNameIfMissing(_ displayName: String, userId: UUID) async throws {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        struct Update: Encodable { let display_name: String }
        try await client
            .from("profiles")
            .update(Update(display_name: displayName))
            .eq("id", value: userId)
            .is("display_name", value: nil)
            .execute()
    }

    private func fetchUserProfile() async {
        do {
            let session = try await client.auth.session
            let userId = session.user.id

            let row: ProfileRow = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            let stats: ProfileStatsRow? = try? await client
                .from("profile_stats")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value

            currentUser = row.asUser(
                totalExperienced: stats?.total_experienced ?? 0,
                totalWishlist: stats?.total_wishlist ?? 0
            )
            hasCompletedOnboarding = row.has_completed_onboarding
        } catch {
            print("⚠️ Failed to fetch profile: \(error)")
        }
    }

    func updateUserProfile(_ user: User) async throws {
        guard let userId = UUID(uuidString: user.id) else { throw AuthenticationError.notAuthenticated }

        struct Update: Encodable {
            let display_name: String?
            let bio: String?
            let is_profile_public: Bool
            let show_stats: Bool
            let show_lists: Bool
        }
        let update = Update(
            display_name: user.displayName,
            bio: user.bio,
            is_profile_public: user.isProfilePublic,
            show_stats: user.showStats,
            show_lists: user.showLists
        )

        try await client.from("profiles").update(update).eq("id", value: userId).execute()
        currentUser = user
    }

    func deleteAccount() async throws {
        // Deleting the auth.users row (which cascades to every table that
        // references it) requires the service-role key and can't run from
        // the client. Deploy the `delete-account` Supabase Edge Function
        // described in SUPABASE_SETUP.md, then call it here.
        _ = try await client.functions.invoke("delete-account")
        signOut()
    }
}

// MARK: - Sign in with Apple

private class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func performSignIn() async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: AuthenticationError.missingAppleIdentityToken)
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
