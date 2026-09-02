//
//  AppConfig.swift
//  OperaApp
//
//  Reads Supabase connection details injected via Config.xcconfig -> Info.plist.
//

import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            !value.isEmpty,
            !value.contains("YOUR-PROJECT"),
            let url = URL(string: value)
        else {
            fatalError(
                "SUPABASE_URL is not configured. Copy OperaApp/Config/Config.xcconfig.example to " +
                "OperaApp/Config/Config.xcconfig and fill in your Supabase project URL. See SUPABASE_SETUP.md."
            )
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !value.isEmpty,
            !value.contains("YOUR-ANON-KEY")
        else {
            fatalError(
                "SUPABASE_ANON_KEY is not configured. Copy OperaApp/Config/Config.xcconfig.example to " +
                "OperaApp/Config/Config.xcconfig and fill in your Supabase anon key. See SUPABASE_SETUP.md."
            )
        }
        return value
    }()
}
