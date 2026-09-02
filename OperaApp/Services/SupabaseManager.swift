//
//  SupabaseManager.swift
//  OperaApp
//
//  Single shared Supabase client. Requires the supabase-swift package
//  (https://github.com/supabase/supabase-swift) to be added in Xcode:
//  File > Add Package Dependencies... -- see SUPABASE_SETUP.md.
//

import Foundation
import Supabase

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}
