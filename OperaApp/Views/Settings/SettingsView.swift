//
//  SettingsView.swift
//  OperaApp
//
//  10_Settings - App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthenticationService
    @State private var notificationsEnabled = true
    @State private var locationEnabled = false
    @State private var calendarEnabled = false
    @State private var profilePublic = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                // Account Section
                Section("Account") {
                    if let user = authService.currentUser {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.secondary)
                        }
                        
                        NavigationLink("Edit Profile") {
                            EditProfileView()
                        }
                    }
                }
                
                // Privacy Section
                Section("Privacy") {
                    Toggle("Public Profile", isOn: $profilePublic)
                    
                    NavigationLink("Privacy Settings") {
                        PrivacySettingsView()
                    }
                    
                    Button("Export My Data") {
                        // Export data
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        Toggle("Performance Reminders", isOn: .constant(true))
                        Toggle("New Recommendations", isOn: .constant(true))
                        Toggle("Wishlist Updates", isOn: .constant(true))
                    }
                }
                
                // Permissions Section
                Section("Permissions") {
                    Toggle("Location Access", isOn: $locationEnabled)
                        .onChange(of: locationEnabled) { _ in
                            // Request location permission
                        }
                    
                    Toggle("Calendar Access", isOn: $calendarEnabled)
                        .onChange(of: calendarEnabled) { _ in
                            // Request calendar permission
                        }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("Terms of Service") {
                        WebView(url: "https://operaapp.com/terms")
                    }
                    
                    NavigationLink("Privacy Policy") {
                        WebView(url: "https://operaapp.com/privacy")
                    }
                    
                    Button("Contact Support") {
                        // Open email
                    }
                }
                
                // Danger Zone
                Section {
                    Button(role: .destructive, action: {
                        showingSignOutConfirmation = true
                    }) {
                        Text("Sign Out")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Text("Delete Account")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        try? await authService.deleteAccount()
                        dismiss()
                    }
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var displayName = ""
    @State private var bio = ""
    
    var body: some View {
        Form {
            Section("Profile Information") {
                TextField("Display Name", text: $displayName)
                
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...5)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let user = authService.currentUser {
                displayName = user.displayName ?? ""
                bio = user.bio ?? ""
            }
        }
    }
}

struct PrivacySettingsView: View {
    @State private var showStats = true
    @State private var showLists = false
    @State private var showAttendance = false
    
    var body: some View {
        Form {
            Section("Public Profile Visibility") {
                Toggle("Show Statistics", isOn: $showStats)
                Toggle("Show Lists", isOn: $showLists)
                Toggle("Show Attendance History", isOn: $showAttendance)
            }
            
            Section {
                Text("Control what information is visible when you share your public profile link.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Privacy Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebView: View {
    let url: String
    
    var body: some View {
        ScrollView {
            Text("WebView placeholder for: \(url)")
                .foregroundColor(.white)
                .padding()
        }
        .background(Color.black)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService.shared)
}

