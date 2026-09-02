//
//  OnboardingView.swift
//  OperaApp
//
//  Initial login/signup screen
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.1, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Logo and branding
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.house.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)
                        
                        Text("Opera")
                            .font(.system(size: 56, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        
                        Text("Your Personal Opera Journal")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 40)
                    
                    // Welcome message
                    VStack(spacing: 12) {
                        Text("Track every performance,\ndiscover new works")
                            .font(.title3)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 30)
                    
                    // Sign in form
                    VStack(spacing: 16) {
                        if showingSignUp {
                            TextField("Display Name", text: $displayName)
                                .textFieldStyle(OperaTextFieldStyle())
                                .textContentType(.name)
                                .autocapitalization(.words)
                        }
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(OperaTextFieldStyle())
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(OperaTextFieldStyle())
                            .textContentType(showingSignUp ? .newPassword : .password)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: handleAuthentication) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(showingSignUp ? "Create Account" : "Sign In")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading || !isFormValid)
                        
                        Button(action: { showingSignUp.toggle() }) {
                            Text(showingSignUp ? "Already have an account? Sign In" : "New here? Create Account")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 32)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
                    
                    // Sign in with Apple
                    Button(action: handleAppleSignIn) {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Continue with Apple")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 32)
                    .disabled(isLoading)
                    
                    // Privacy note
                    Text("Privacy-first. Your data stays yours.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 20)
                    
                    Spacer()
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        if showingSignUp {
            return !email.isEmpty && !password.isEmpty && password.count >= 6 && !displayName.isEmpty
        }
        return !email.isEmpty && !password.isEmpty
    }
    
    private func handleAuthentication() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                if showingSignUp {
                    try await authService.signUp(email: email, password: password, displayName: displayName)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func handleAppleSignIn() {
        isLoading = true
        Task {
            do {
                try await authService.signInWithApple()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Custom Styles

struct OperaTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.white.opacity(0.1))
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationService.shared)
}

