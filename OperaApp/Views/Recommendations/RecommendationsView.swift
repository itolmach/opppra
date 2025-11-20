//
//  RecommendationsView.swift
//  OperaApp
//
//  08_Recommendations - Personalized recommendations
//

import SwiftUI

struct RecommendationsView: View {
    @StateObject private var viewModel = RecommendationsViewModel()
    @State private var selectedCategory: RecommendationCategory = .all
    
    enum RecommendationCategory: String, CaseIterable {
        case all = "All"
        case operas = "Operas"
        case productions = "Productions"
        case venues = "Venues"
        case learningPaths = "Learning Paths"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(RecommendationCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding()
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredRecommendations) { rec in
                                RecommendationCard(recommendation: rec) {
                                    viewModel.updateFeedback(id: rec.id, liked: true)
                                } onDislike: {
                                    viewModel.updateFeedback(id: rec.id, liked: false)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadRecommendations()
            }
        }
    }
    
    private var filteredRecommendations: [Recommendation] {
        switch selectedCategory {
        case .all:
            return viewModel.recommendations
        case .operas:
            return viewModel.recommendations.filter { $0.type == .opera || $0.type == .similarWork }
        case .productions:
            return viewModel.recommendations.filter { $0.type == .production }
        case .venues:
            return viewModel.recommendations.filter { $0.type == .venue }
        case .learningPaths:
            return viewModel.recommendations.filter { $0.type == .learningPath }
        }
    }
}

// MARK: - Subviews

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.white : Color.white.opacity(0.1))
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(20)
        }
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    let onLike: () -> Void
    let onDislike: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image/placeholder
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [typeColor.opacity(0.3), typeColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(12)
                .overlay(
                    Image(systemName: typeIcon)
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Type badge
                Text(typeName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(typeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(typeColor.opacity(0.2))
                    .cornerRadius(6)
                
                Text(recommendation.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(recommendation.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: {
                        // Add to list
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add to List")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Feedback buttons
                    Button(action: onLike) {
                        Image(systemName: "hand.thumbsup")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: onDislike) {
                        Image(systemName: "hand.thumbsdown")
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var typeName: String {
        switch recommendation.type {
        case .opera: return "Opera Work"
        case .production: return "Production"
        case .venue: return "Venue"
        case .learningPath: return "Learning Path"
        case .similarWork: return "Similar Work"
        }
    }
    
    private var typeIcon: String {
        switch recommendation.type {
        case .opera, .similarWork: return "music.note"
        case .production: return "theatermasks"
        case .venue: return "building.columns"
        case .learningPath: return "map"
        }
    }
    
    private var typeColor: Color {
        switch recommendation.type {
        case .opera, .similarWork: return .purple
        case .production: return .red
        case .venue: return .blue
        case .learningPath: return .green
        }
    }
}

// MARK: - ViewModel

@MainActor
class RecommendationsViewModel: ObservableObject {
    @Published var recommendations: [Recommendation] = []
    @Published var isLoading = false
    
    func loadRecommendations() async {
        isLoading = true
        
        do {
            recommendations = try await APIService.shared.fetchRecommendations()
        } catch {
            print("Error loading recommendations: \(error)")
        }
        
        isLoading = false
    }
    
    func updateFeedback(id: String, liked: Bool) {
        Task {
            do {
                try await APIService.shared.updateRecommendationFeedback(id: id, liked: liked)
                // Remove from list or update
                if !liked {
                    recommendations.removeAll { $0.id == id }
                }
            } catch {
                print("Error updating feedback: \(error)")
            }
        }
    }
}

#Preview {
    RecommendationsView()
}

