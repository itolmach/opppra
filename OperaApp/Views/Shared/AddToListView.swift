//
//  AddToListView.swift
//  OperaApp
//
//  Shared component for adding operas to lists
//

import SwiftUI

struct AddToListView: View {
    @Environment(\.dismiss) var dismiss
    let opera: Opera
    @StateObject private var viewModel = AddToListViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Opera preview
                    OperaPreviewCard(opera: opera)
                        .padding()
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal)
                    
                    // Lists
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add to List")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.lists) { list in
                            ListSelectionRow(
                                list: list,
                                isSelected: viewModel.selectedLists.contains(list.id)
                            ) {
                                viewModel.toggleList(list.id)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes (Optional)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        TextEditor(text: $viewModel.notes)
                            .frame(height: 100)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.black)
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.save(operaId: opera.id)
                            dismiss()
                        }
                    }
                    .foregroundColor(.white)
                    .disabled(viewModel.selectedLists.isEmpty)
                }
            }
            .task {
                await viewModel.loadLists()
            }
        }
    }
}

struct OperaPreviewCard: View {
    let opera: Opera
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(opera.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(opera.composerAndYear)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

struct ListSelectionRow: View {
    let list: UserList
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                
                Text(list.name)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var iconName: String {
        switch list.type {
        case .wantsToExperience: return "heart.fill"
        case .hasExperienced: return "checkmark.circle.fill"
        case .custom: return list.iconName ?? "list.bullet"
        }
    }
    
    private var iconColor: Color {
        switch list.type {
        case .wantsToExperience: return .red
        case .hasExperienced: return .green
        case .custom: return .blue
        }
    }
}

// MARK: - ViewModel

@MainActor
class AddToListViewModel: ObservableObject {
    @Published var lists: [UserList] = []
    @Published var selectedLists: Set<String> = []
    @Published var notes = ""
    
    func loadLists() async {
        do {
            lists = try await APIService.shared.fetchUserLists()
        } catch {
            print("Error loading lists: \(error)")
        }
    }
    
    func toggleList(_ listId: String) {
        if selectedLists.contains(listId) {
            selectedLists.remove(listId)
        } else {
            selectedLists.insert(listId)
        }
    }
    
    func save(operaId: String) async {
        for listId in selectedLists {
            do {
                try await APIService.shared.addToList(listId: listId, operaId: operaId)
            } catch {
                print("Error adding to list: \(error)")
            }
        }
    }
}

#Preview {
    AddToListView(
        opera: Opera(
            id: "1",
            title: "La Bohème",
            composer: "Puccini",
            composerId: nil,
            librettist: nil,
            premiereYear: 1896,
            era: "Romantic",
            language: "Italian",
            synopsis: "A beautiful love story",
            duration: 135,
            acts: 4,
            imageURL: nil,
            popularity: 95,
            tags: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}

