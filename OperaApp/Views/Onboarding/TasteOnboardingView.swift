//
//  TasteOnboardingView.swift
//  OperaApp
//
//  Taste profile onboarding flow
//

import SwiftUI

struct TasteOnboardingView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var currentStep = 0
    @State private var tasteProfile = UserTasteProfile(
        composers: [],
        choreographers: [],
        eras: [],
        houses: []
    )
    @State private var isCompleting = false
    
    private let totalSteps = 4
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 4) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Rectangle()
                            .fill(step <= currentStep ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 3)
                            .animation(.easeInOut, value: currentStep)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeTasteView()
                        .tag(0)
                    
                    ComposerSelectionView(selectedComposers: $tasteProfile.composers)
                        .tag(1)
                    
                    EraSelectionView(selectedEras: $tasteProfile.eras)
                        .tag(2)
                    
                    HouseSelectionView(selectedHouses: $tasteProfile.houses)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: { currentStep -= 1 }) {
                            Text("Back")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    
                    Button(action: handleNext) {
                        if isCompleting {
                            ProgressView()
                                .tint(.black)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(currentStep < totalSteps - 1 ? "Next" : "Complete")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isCompleting || !canProceed)
                }
                .padding()
            }
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return true
        case 1:
            return !tasteProfile.composers.isEmpty
        case 2:
            return !tasteProfile.eras.isEmpty
        case 3:
            return true // Houses are optional
        default:
            return false
        }
    }
    
    private func handleNext() {
        if currentStep < totalSteps - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        isCompleting = true
        Task {
            await authService.completeOnboarding(tasteProfile: tasteProfile)
            isCompleting = false
        }
    }
}

// MARK: - Onboarding Steps

struct WelcomeTasteView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.white)
            
            Text("Let's personalize\nyour experience")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Tell us about your tastes so we can recommend operas you'll love")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ComposerSelectionView: View {
    @Binding var selectedComposers: [String]
    
    private let composers = [
        "Giacomo Puccini", "Giuseppe Verdi", "Wolfgang Amadeus Mozart",
        "Richard Wagner", "Georges Bizet", "Gioachino Rossini",
        "Gaetano Donizetti", "Vincenzo Bellini", "Richard Strauss",
        "Pyotr Tchaikovsky", "Benjamin Britten", "George Frideric Handel"
    ]
    
    var body: some View {
        SelectionStepView(
            title: "Favorite Composers",
            subtitle: "Select at least one composer you enjoy",
            items: composers,
            selectedItems: $selectedComposers
        )
    }
}

struct EraSelectionView: View {
    @Binding var selectedEras: [String]
    
    private let eras = [
        "Baroque (1600-1750)",
        "Classical (1750-1820)",
        "Romantic (1810-1920)",
        "Verismo (1890-1920)",
        "Modern (1900-1950)",
        "Contemporary (1950-present)"
    ]
    
    var body: some View {
        SelectionStepView(
            title: "Preferred Eras",
            subtitle: "Which periods interest you?",
            items: eras,
            selectedItems: $selectedEras
        )
    }
}

struct HouseSelectionView: View {
    @Binding var selectedHouses: [String]
    
    private let houses = [
        "Metropolitan Opera (New York)",
        "La Scala (Milan)",
        "Royal Opera House (London)",
        "Vienna State Opera",
        "Paris Opera",
        "Bolshoi Theatre (Moscow)",
        "Teatro Real (Madrid)",
        "Sydney Opera House",
        "San Francisco Opera",
        "Bavarian State Opera (Munich)"
    ]
    
    var body: some View {
        SelectionStepView(
            title: "Favorite Opera Houses",
            subtitle: "Optional: Select houses you've visited or dream of visiting",
            items: houses,
            selectedItems: $selectedHouses
        )
    }
}

struct SelectionStepView: View {
    let title: String
    let subtitle: String
    let items: [String]
    @Binding var selectedItems: [String]
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(items, id: \.self) { item in
                        SelectableChip(
                            title: item,
                            isSelected: selectedItems.contains(item)
                        ) {
                            if selectedItems.contains(item) {
                                selectedItems.removeAll { $0 == item }
                            } else {
                                selectedItems.append(item)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .padding()
            .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    TasteOnboardingView()
        .environmentObject(AuthenticationService.shared)
}

