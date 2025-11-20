//
//  SearchView.swift
//  OperaApp
//
//  03_Search screen - search with filters and typeahead
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var showingFilters = false
    
    var body: some View {
        NavigationStack(path: $appState.searchNavigationPath) {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search operas, productions, venues...")
                    .padding()
                
                if searchText.isEmpty {
                    // Default state - popular & recent
                    DefaultSearchView()
                } else if viewModel.isSearching {
                    // Loading state
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.searchResults.isEmpty {
                    // No results
                    NoResultsView(searchTerm: searchText)
                } else {
                    // Results
                    SearchResultsList(results: viewModel.searchResults)
                }
            }
            .background(Color.black)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationDestination(for: Opera.self) { opera in
                OperaDetailView(operaId: opera.id)
            }
            .navigationDestination(for: Production.self) { production in
                ProductionDetailView(productionId: production.id)
            }
            .sheet(isPresented: $showingFilters) {
                SearchFiltersView(filters: $viewModel.filters)
            }
            .onChange(of: searchText) { newValue in
                viewModel.search(query: newValue)
            }
        }
    }
}

// MARK: - Subviews

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DefaultSearchView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Popular searches
                VStack(alignment: .leading, spacing: 12) {
                    Text("Popular")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    PopularSearchChips()
                }
                
                // Recent searches (if any)
                // TODO: Implement recent searches
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
}

struct PopularSearchChips: View {
    let popularSearches = ["La Bohème", "Carmen", "Magic Flute", "Tosca", "Rigoletto"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(popularSearches, id: \.self) { search in
                    Button(action: {
                        // Trigger search
                    }) {
                        Text(search)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct NoResultsView: View {
    let searchTerm: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No results for '\(searchTerm)'")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Button(action: {
                // Suggest adding
            }) {
                Text("Suggest adding this opera")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchResultsList: View {
    let results: [SearchResult]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(results) { result in
                    SearchResultRow(result: result)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(result.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(typeLabel)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var iconName: String {
        switch result.type {
        case .opera: return "music.note"
        case .production: return "theatermasks"
        case .venue: return "building.columns"
        case .artist: return "person.fill"
        }
    }
    
    private var typeLabel: String {
        switch result.type {
        case .opera: return "Opera Work"
        case .production: return "Production"
        case .venue: return "Venue"
        case .artist: return "Artist"
        }
    }
}

struct SearchFiltersView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var filters: SearchFilters
    
    var body: some View {
        NavigationView {
            Form {
                Section("Era") {
                    // Era filters
                }
                
                Section("Language") {
                    // Language filters
                }
                
                Section("Composer") {
                    // Composer filters
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        filters = SearchFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var filters = SearchFilters()
    
    private var searchTask: Task<Void, Never>?
    
    func search(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            isSearching = true
            
            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard !Task.isCancelled else {
                isSearching = false
                return
            }
            
            do {
                searchResults = try await APIService.shared.search(query: query, filters: filters)
            } catch {
                print("Search error: \(error)")
                searchResults = []
            }
            
            isSearching = false
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AppState())
}

