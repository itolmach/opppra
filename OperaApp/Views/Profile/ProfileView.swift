//
//  ProfileView.swift
//  OperaApp
//
//  09_Profile - User profile and stats
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack(path: $appState.profileNavigationPath) {
            ScrollView {
                if let user = authService.currentUser {
                    VStack(spacing: 24) {
                        // Profile header
                        ProfileHeaderView(user: user)
                            .padding(.horizontal)
                        
                        // Stats
                        StatsGridView(user: user)
                            .padding(.horizontal)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal)
                        
                        // Favorite Houses
                        if !user.favoriteHouses.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Favorite Opera Houses")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ForEach(user.favoriteHouses, id: \.self) { house in
                                    Text(house)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                        
                        // Favorite Composers
                        if !user.favoriteComposers.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Favorite Composers")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ForEach(user.favoriteComposers, id: \.self) { composer in
                                    Text(composer)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal)
                        
                        // Actions
                        VStack(spacing: 12) {
                            ProfileActionButton(
                                icon: "square.and.arrow.up",
                                title: "Share Profile",
                                action: { viewModel.shareProfile() }
                            )
                            
                            ProfileActionButton(
                                icon: "square.and.arrow.down",
                                title: "Export Data",
                                action: { viewModel.exportData() }
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .background(Color.black)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

// MARK: - Subviews

struct ProfileHeaderView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile image
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text(user.displayName?.prefix(1).uppercased() ?? "O")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 4) {
                Text(user.displayName ?? "Opera Lover")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if let bio = user.bio {
                Text(bio)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}

struct StatsGridView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 16) {
            StatBox(value: "\(user.totalExperienced)", label: "Experienced")
            StatBox(value: "\(user.totalWishlist)", label: "Wishlist")
            StatBox(value: "\(user.favoriteComposers.count)", label: "Composers")
        }
    }
}

struct StatBox: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ProfileActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

// MARK: - ViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    func shareProfile() {
        // TODO: Implement profile sharing
        print("Share profile")
    }
    
    func exportData() {
        // TODO: Implement data export
        print("Export data")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationService.shared)
        .environmentObject(AppState())
}

