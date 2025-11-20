//
//  OperaAppApp.swift
//  OperaApp
//
//  Main app entry point
//

import SwiftUI

@main
struct OperaAppApp: App {
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(appState)
                .onAppear {
                    authService.checkAuthStatus()
                }
        }
    }
}

