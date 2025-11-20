//
//  ListsView.swift
//  OperaApp
//
//  07_Lists - User's lists management
//

import SwiftUI

struct ListsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ListsViewModel()
    @State private var showingCreateList = false
    @State private var selectedList: UserList?
    
    var body: some View {
        NavigationStack(path: $appState.listsNavigationPath) {
            ScrollView {
                VStack(spacing: 20) {
                    // Default lists
                    VStack(spacing: 12) {
                        ForEach(viewModel.defaultLists) { list in
                            ListCard(list: list)
                                .onTapGesture {
                                    selectedList = list
                                }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Custom lists section
                    if !viewModel.customLists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Custom Lists")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.customLists) { list in
                                ListCard(list: list)
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        selectedList = list
                                    }
                            }
                        }
                    }
                    
                    // Create new list button
                    Button(action: { showingCreateList = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New List")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.black)
            .navigationTitle("My Lists")
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView { newList in
                    viewModel.addList(newList)
                }
            }
            .sheet(item: $selectedList) { list in
                ListDetailView(list: list)
            }
            .task {
                await viewModel.loadLists()
            }
        }
    }
}

// MARK: - Subviews

struct ListCard: View {
    let list: UserList
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(iconColor)
                .frame(width: 60, height: 60)
                .background(iconColor.opacity(0.2))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(list.count) operas")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var iconName: String {
        switch list.type {
        case .wantsToExperience:
            return "heart.fill"
        case .hasExperienced:
            return "checkmark.circle.fill"
        case .custom:
            return list.iconName ?? "list.bullet"
        }
    }
    
    private var iconColor: Color {
        switch list.type {
        case .wantsToExperience:
            return .red
        case .hasExperienced:
            return .green
        case .custom:
            if let colorHex = list.color {
                return Color(hex: colorHex) ?? .blue
            }
            return .blue
        }
    }
}

struct ListDetailView: View {
    @Environment(\.dismiss) var dismiss
    let list: UserList
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(list.items) { item in
                        ListItemDetailRow(item: item)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.black)
            .navigationTitle(list.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .searchable(text: $searchText, prompt: "Search in list")
        }
    }
}

struct ListItemDetailRow: View {
    let item: ListItem
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 80, height: 80)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.operaTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(item.composer)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                if let rating = item.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                if !item.tags.isEmpty {
                    Text(item.tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Menu {
                Button(action: {}) {
                    Label("Move to List", systemImage: "arrow.right")
                }
                Button(action: {}) {
                    Label("Add Notes", systemImage: "note.text")
                }
                Button(role: .destructive, action: {}) {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct CreateListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var listName = ""
    @State private var selectedIcon = "list.bullet"
    @State private var selectedColor = Color.blue
    let onCreate: (UserList) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("List Name", text: $listName)
                }
                
                Section("Appearance") {
                    // Icon picker
                    // Color picker
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let newList = UserList(
                            id: UUID().uuidString,
                            name: listName,
                            type: .custom,
                            items: [],
                            isDefault: false,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                        onCreate(newList)
                        dismiss()
                    }
                    .disabled(listName.isEmpty)
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class ListsViewModel: ObservableObject {
    @Published var allLists: [UserList] = []
    @Published var isLoading = false
    
    var defaultLists: [UserList] {
        allLists.filter { $0.isDefault }
    }
    
    var customLists: [UserList] {
        allLists.filter { !$0.isDefault }
    }
    
    func loadLists() async {
        isLoading = true
        
        do {
            allLists = try await APIService.shared.fetchUserLists()
        } catch {
            print("Error loading lists: \(error)")
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadLists()
    }
    
    func addList(_ list: UserList) {
        allLists.append(list)
    }
}

// Helper extension for Color from hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            .sRGB,
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    ListsView()
        .environmentObject(AppState())
}

