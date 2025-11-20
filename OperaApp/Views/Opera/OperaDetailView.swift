//
//  OperaDetailView.swift
//  OperaApp
//
//  04_Work screen - detailed opera work information
//

import SwiftUI

struct OperaDetailView: View {
    let operaId: String
    @StateObject private var viewModel = OperaDetailViewModel()
    @State private var selectedTab = 0
    @State private var showingAddToList = false
    
    var body: some View {
        ScrollView {
            if let opera = viewModel.opera {
                VStack(spacing: 0) {
                    // Hero image/header
                    OperaHeroView(opera: opera)
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Title and composer
                        VStack(alignment: .leading, spacing: 8) {
                            Text(opera.title)
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                            
                            Text(opera.composerAndYear)
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal)
                        
                        // Action buttons
                        OperaActionButtons(
                            showingAddToList: $showingAddToList,
                            opera: opera
                        )
                        .padding(.horizontal)
                        
                        // Quick info
                        QuickInfoView(opera: opera)
                            .padding(.horizontal)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal)
                        
                        // Synopsis
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Synopsis")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(opera.synopsis)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal)
                        
                        // Tabs for additional content
                        VStack(spacing: 0) {
                            // Tab picker
                            Picker("Content", selection: $selectedTab) {
                                Text("Recordings").tag(0)
                                Text("Productions").tag(1)
                                Text("Similar").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            
                            // Tab content
                            Group {
                                switch selectedTab {
                                case 0:
                                    RecordingsTabView()
                                case 1:
                                    ProductionsTabView(productions: viewModel.productions)
                                case 2:
                                    SimilarWorksTabView(recommendations: viewModel.similarWorks)
                                default:
                                    EmptyView()
                                }
                            }
                            .padding(.top)
                        }
                    }
                    .padding(.vertical)
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Opera not found")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddToList) {
            AddToListView(opera: viewModel.opera!)
        }
        .task {
            await viewModel.loadOpera(id: operaId)
        }
    }
}

// MARK: - Subviews

struct OperaHeroView: View {
    let opera: Opera
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

struct OperaActionButtons: View {
    @Binding var showingAddToList: Bool
    let opera: Opera
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { showingAddToList = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to List")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            
            Button(action: {
                // Share
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
}

struct QuickInfoView: View {
    let opera: Opera
    
    var body: some View {
        HStack(spacing: 24) {
            InfoItem(icon: "clock", value: "\(opera.duration ?? 0) min")
            InfoItem(icon: "music.note.list", value: "\(opera.acts ?? 0) acts")
            InfoItem(icon: "globe", value: opera.language)
        }
    }
}

struct InfoItem: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

struct RecordingsTabView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Recordings & Videos")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
                .padding()
            
            // TODO: Add recordings list with external links
        }
    }
}

struct ProductionsTabView: View {
    let productions: [Production]
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(productions) { production in
                ProductionListItem(production: production)
                    .padding(.horizontal)
            }
        }
    }
}

struct ProductionListItem: View {
    let production: Production
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 80, height: 80)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(production.company)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(production.venue.fullLocation)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                if let next = production.nextPerformance {
                    Text("Next: \(next.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Past production")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct SimilarWorksTabView: View {
    let recommendations: [Recommendation]
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(recommendations) { rec in
                RecommendationRow(recommendation: rec)
                    .padding(.horizontal)
            }
        }
    }
}

struct RecommendationRow: View {
    let recommendation: Recommendation
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(recommendation.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - ViewModel

@MainActor
class OperaDetailViewModel: ObservableObject {
    @Published var opera: Opera?
    @Published var productions: [Production] = []
    @Published var similarWorks: [Recommendation] = []
    @Published var isLoading = false
    
    func loadOpera(id: String) async {
        isLoading = true
        
        do {
            async let operaData = APIService.shared.fetchOpera(id: id)
            async let productionsData = APIService.shared.fetchProductionsForOpera(operaId: id)
            async let recommendations = APIService.shared.fetchRecommendations()
            
            opera = try await operaData
            productions = try await productionsData
            similarWorks = try await recommendations
        } catch {
            print("Error loading opera: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        OperaDetailView(operaId: "1")
    }
}

