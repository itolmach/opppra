//
//  ProductionDetailView.swift
//  OperaApp
//
//  05_Production screen - specific production details
//

import SwiftUI

struct ProductionDetailView: View {
    let productionId: String
    @StateObject private var viewModel = ProductionDetailViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            if let production = viewModel.production {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero image
                    ProductionHeroView(production: production)
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Title and basic info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(production.operaTitle)
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                            
                            Text(production.company)
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack(spacing: 8) {
                                Image(systemName: "building.columns")
                                Text(production.venue.fullLocation)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal)
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                appState.showingLogFlow = true
                            }) {
                                HStack {
                                    Image(systemName: "ticket.fill")
                                    Text("Log Attendance")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Creative team
                        if let director = production.director {
                            CreativeTeamSection(production: production)
                                .padding(.horizontal)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal)
                        
                        // Cast
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cast")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(production.cast) { member in
                                CastMemberRow(member: member)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal)
                        
                        // Upcoming performances
                        if production.hasUpcomingPerformances {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Upcoming Performances")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ForEach(production.performances.filter { $0.date > Date() }) { performance in
                                    PerformanceRow(performance: performance)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Venue information
                        VenueInfoSection(venue: production.venue)
                            .padding(.horizontal)
                        
                        // Description
                        if let description = production.description {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("About this Production")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProduction(id: productionId)
        }
    }
}

// MARK: - Subviews

struct ProductionHeroView: View {
    let production: Production
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.red.opacity(0.3), Color.orange.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

struct CreativeTeamSection: View {
    let production: Production
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Creative Team")
                .font(.headline)
                .foregroundColor(.white)
            
            if let director = production.director {
                CreativeTeamItem(role: "Director", name: director)
            }
            
            if let conductor = production.conductor {
                CreativeTeamItem(role: "Conductor", name: conductor)
            }
            
            if let choreographer = production.choreographer {
                CreativeTeamItem(role: "Choreographer", name: choreographer)
            }
            
            if let designer = production.designer {
                CreativeTeamItem(role: "Designer", name: designer)
            }
        }
    }
}

struct CreativeTeamItem: View {
    let role: String
    let name: String
    
    var body: some View {
        HStack {
            Text(role)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 120, alignment: .leading)
            
            Text(name)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

struct CastMemberRow: View {
    let member: CastMember
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white.opacity(0.5))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(member.role)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct PerformanceRow: View {
    let performance: Performance
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(performance.date.formatted(date: .long, time: .omitted))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(performance.time)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                if let priceRange = performance.ticketPriceRange {
                    Text(priceRange)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            if performance.isSoldOut {
                Text("Sold Out")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
            } else if let url = performance.ticketURL {
                Link(destination: URL(string: url)!) {
                    Text("Tickets")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct VenueInfoSection: View {
    let venue: Venue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Venue")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(venue.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if let address = venue.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let capacity = venue.capacity {
                    Text("Capacity: \(capacity) seats")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let website = venue.website {
                    Link("Visit Website", destination: URL(string: website)!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - ViewModel

@MainActor
class ProductionDetailViewModel: ObservableObject {
    @Published var production: Production?
    @Published var isLoading = false
    
    func loadProduction(id: String) async {
        isLoading = true
        
        do {
            production = try await APIService.shared.fetchProduction(id: id)
        } catch {
            print("Error loading production: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ProductionDetailView(productionId: "prod-1")
    }
    .environmentObject(AppState())
}

