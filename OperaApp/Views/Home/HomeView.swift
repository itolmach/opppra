//
//  HomeView.swift
//  OperaApp
//
//  02_Home screen - personalized dashboard
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack(path: $appState.homeNavigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HomeHeaderView(user: authService.currentUser)
                        .padding(.horizontal)
                    
                    // Quick Actions
                    QuickActionsView()
                        .padding(.horizontal)
                    
                    // Season at a Glance
                    if let stats = viewModel.seasonStats {
                        SeasonStatsView(stats: stats)
                            .padding(.horizontal)
                    }
                    
                    // Upcoming Recommendations
                    if !viewModel.upcomingRecommendations.isEmpty {
                        SectionHeaderView(title: "Upcoming for You", actionTitle: "See All") {
                            // Navigate to recommendations
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.upcomingRecommendations) { production in
                                    ProductionCard(production: production)
                                        .frame(width: 280)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Your Wishlist Preview
                    if !viewModel.wishlistPreview.isEmpty {
                        SectionHeaderView(title: "Your Wishlist", actionTitle: "View All") {
                            appState.selectedTab = .lists
                        }
                        .padding(.horizontal)
                        
                        ForEach(viewModel.wishlistPreview.prefix(3)) { item in
                            WishlistItemRow(item: item)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Recent Logs
                    if !viewModel.recentLogs.isEmpty {
                        SectionHeaderView(title: "Recently Attended", actionTitle: "View All") {
                            // Navigate to logs
                        }
                        .padding(.horizontal)
                        
                        ForEach(viewModel.recentLogs.prefix(3)) { log in
                            LogItemRow(log: log)
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(Color.black)
            .navigationDestination(for: Opera.self) { opera in
                OperaDetailView(operaId: opera.id)
            }
            .navigationDestination(for: Production.self) { production in
                ProductionDetailView(productionId: production.id)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
}

// MARK: - Subviews

struct HomeHeaderView: View {
    let user: User?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back,")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
            
            Text(user?.displayName ?? "Opera Lover")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

struct QuickActionsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                icon: "magnifyingglass",
                title: "Search",
                color: .blue
            ) {
                appState.selectedTab = .search
            }
            
            QuickActionButton(
                icon: "ticket.fill",
                title: "Log Attendance",
                color: .green
            ) {
                appState.showingLogFlow = true
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
    }
}

struct SeasonStatsView: View {
    let stats: SeasonStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Season at a Glance")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                StatItem(value: "\(stats.attendedThisSeason)", label: "Attended")
                StatItem(value: "\(stats.upcomingPlanned)", label: "Planned")
                StatItem(value: "\(stats.newWorks)", label: "New Works")
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct SectionHeaderView: View {
    let title: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: action) {
                Text(actionTitle)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }
}

struct ProductionCard: View {
    let production: Production
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image placeholder
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .aspectRatio(4/3, contentMode: .fit)
                .overlay(
                    Image(systemName: "theatermasks.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                )
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(production.operaTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(production.company)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                if let next = production.nextPerformance {
                    Text(next.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct WishlistItemRow: View {
    let item: ListItem
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.operaTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(item.composer)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct LogItemRow: View {
    let log: AttendanceLog
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.operaTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(log.venueName) • \(log.attendanceDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            if let rating = log.overallRating {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text(String(format: "%.1f", rating))
                        .font(.caption)
                }
                .foregroundColor(.yellow)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - ViewModel

@MainActor
class HomeViewModel: ObservableObject {
    @Published var seasonStats: SeasonStats?
    @Published var upcomingRecommendations: [Production] = []
    @Published var wishlistPreview: [ListItem] = []
    @Published var recentLogs: [AttendanceLog] = []
    @Published var isLoading = false
    
    func loadData() async {
        isLoading = true
        
        async let stats = loadSeasonStats()
        async let recommendations = APIService.shared.fetchUpcomingProductions(limit: 5)
        async let logs = APIService.shared.fetchAttendanceLogs()
        async let lists = APIService.shared.fetchUserLists()
        
        do {
            seasonStats = try await stats
            upcomingRecommendations = try await recommendations
            recentLogs = try await logs
            
            let allLists = try await lists
            if let wishlist = allLists.first(where: { $0.type == .wantsToExperience }) {
                wishlistPreview = wishlist.items
            }
        } catch {
            print("Error loading home data: \(error)")
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadData()
    }
    
    private func loadSeasonStats() async throws -> SeasonStats {
        // TODO: Implement actual API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return SeasonStats(attendedThisSeason: 5, upcomingPlanned: 3, newWorks: 2)
    }
}

struct SeasonStats {
    let attendedThisSeason: Int
    let upcomingPlanned: Int
    let newWorks: Int
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationService.shared)
}

