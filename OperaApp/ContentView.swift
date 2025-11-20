//
//  ContentView.swift
//  OperaApp
//
//  Root view that handles authentication flow
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if authService.isLoading {
                SplashView()
            } else if !authService.isAuthenticated {
                OnboardingView()
            } else if !authService.hasCompletedOnboarding {
                TasteOnboardingView()
            } else {
                MainTabView()
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("Opera")
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService.shared)
        .environmentObject(AppState())
}

