//
//  AppConfig.swift
//  OperaApp
//
//  Neon connection details, injected via Config.xcconfig -> Info.plist.
//
//  There is no API key here, and that is not an oversight. Supabase needed an
//  anon key; Neon's Data API does not. An unauthenticated request is simply
//  run as the `anonymous` Postgres role, and a signed-in one carries a JWT.
//  Either way the authorization boundary is row level security in the
//  database, exactly as it is for the web app.
//

import Foundation

enum AppConfig {
    /// PostgREST-compatible REST interface over the `opera` database.
    static let dataAPIURL: URL = required("NEON_DATA_API_URL", looksUnset: "YOUR-")

    /// Managed Better Auth: sign-up, sign-in, and the /token endpoint that
    /// exchanges a session for the JWT the Data API verifies.
    static let authURL: URL = required("NEON_AUTH_URL", looksUnset: "YOUR-")

    /// Sent as the Origin on auth calls. Better Auth checks it against the
    /// project's trusted origins and refuses anything else with
    /// INVALID_ORIGIN. It has to be an http(s) origin -- Neon rejects a
    /// custom scheme such as operaapp:// outright -- so the app presents the
    /// product's own web origin, which is already trusted for the web app.
    static let authOrigin: String =
        (Bundle.main.object(forInfoDictionaryKey: "NEON_AUTH_ORIGIN") as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
        ?? "https://itolmach.github.io"

    private static func required(_ key: String, looksUnset placeholder: String) -> URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.isEmpty,
            !value.contains(placeholder),
            let url = URL(string: value)
        else {
            // Deliberately fatal, and deliberately at launch. A missing
            // endpoint cannot be recovered from at runtime, and failing here
            // names the problem instead of surfacing it later as a pile of
            // unexplained network errors.
            fatalError(
                "\(key) is missing or cut short in OperaApp/Config/Config.xcconfig. " +
                "See NEON_SETUP.md."
            )
        }
        return url
    }
}
