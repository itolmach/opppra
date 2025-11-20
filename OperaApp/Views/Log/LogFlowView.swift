//
//  LogFlowView.swift
//  OperaApp
//
//  06_LogFlow - Attendance logging with OCR scanning
//

import SwiftUI
import PhotosUI

struct LogFlowView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = LogFlowViewModel()
    @State private var currentStep: LogStep = .scanOrManual
    
    enum LogStep {
        case scanOrManual
        case ticketScanning
        case manualEntry
        case ratingAndNotes
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    switch currentStep {
                    case .scanOrManual:
                        ScanOrManualView(
                            onScan: {
                                currentStep = .ticketScanning
                            },
                            onManual: {
                                currentStep = .manualEntry
                            }
                        )
                        
                    case .ticketScanning:
                        TicketScanningView(
                            viewModel: viewModel,
                            onComplete: {
                                currentStep = .ratingAndNotes
                            }
                        )
                        
                    case .manualEntry:
                        ManualEntryView(
                            viewModel: viewModel,
                            onNext: {
                                currentStep = .ratingAndNotes
                            }
                        )
                        
                    case .ratingAndNotes:
                        RatingAndNotesView(
                            viewModel: viewModel,
                            onSave: {
                                Task {
                                    await viewModel.saveLog()
                                    dismiss()
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Log Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Step Views

struct ScanOrManualView: View {
    let onScan: () -> Void
    let onManual: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "ticket.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("Log Your Experience")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(.white)
            
            Text("Choose how you'd like to add this performance")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: onScan) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Scan Ticket / Playbill")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                
                Button(action: onManual) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Enter Manually")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct TicketScanningView: View {
    @ObservedObject var viewModel: LogFlowViewModel
    @State private var selectedImage: PhotosPickerItem?
    @State private var isProcessing = false
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                    
                    Text("Processing ticket...")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                        
                        Text("Tap to scan ticket or playbill")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("We'll extract the details automatically")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: selectedImage) { newValue in
                    if newValue != nil {
                        processTicket()
                    }
                }
            }
        }
    }
    
    private func processTicket() {
        isProcessing = true
        
        Task {
            // Simulate OCR processing
            await viewModel.processTicketScan()
            isProcessing = false
            onComplete()
        }
    }
}

struct ManualEntryView: View {
    @ObservedObject var viewModel: LogFlowViewModel
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Performance Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    // Opera selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Opera")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Search for opera...", text: $viewModel.operaTitle)
                            .textFieldStyle(OperaTextFieldStyle())
                    }
                    
                    // Date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        DatePicker("", selection: $viewModel.attendanceDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                    }
                    
                    // Venue
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Venue")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Opera house or venue", text: $viewModel.venueName)
                            .textFieldStyle(OperaTextFieldStyle())
                    }
                    
                    // City
                    VStack(alignment: .leading, spacing: 8) {
                        Text("City")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("City", text: $viewModel.city)
                            .textFieldStyle(OperaTextFieldStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 40)
                
                Button(action: onNext) {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isBasicInfoValid ? Color.white : Color.white.opacity(0.3))
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
                .disabled(!viewModel.isBasicInfoValid)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct RatingAndNotesView: View {
    @ObservedObject var viewModel: LogFlowViewModel
    let onSave: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("How was it?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                VStack(spacing: 20) {
                    // Overall rating
                    RatingSection(
                        title: "Overall",
                        rating: $viewModel.overallRating
                    )
                    
                    // Music rating
                    RatingSection(
                        title: "Music & Orchestra",
                        rating: $viewModel.musicRating
                    )
                    
                    // Performance rating
                    RatingSection(
                        title: "Singers",
                        rating: $viewModel.performanceRating
                    )
                    
                    // Production rating
                    RatingSection(
                        title: "Production & Direction",
                        rating: $viewModel.productionRating
                    )
                }
                .padding(.horizontal)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal)
                
                // Notes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextEditor(text: $viewModel.notes)
                        .frame(height: 120)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Tags
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TagSelectionView(selectedTags: $viewModel.tags)
                }
                .padding(.horizontal)
                
                Spacer(minLength: 40)
                
                Button(action: onSave) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Save Log")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(viewModel.isSaving)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct RatingSection: View {
    let title: String
    @Binding var rating: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.1f", rating))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
            }
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        rating = Double(star)
                    }) {
                        Image(systemName: rating >= Double(star) ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
    }
}

struct TagSelectionView: View {
    @Binding var selectedTags: [String]
    
    let availableTags = [
        "Memorable", "First Time", "Birthday", "Anniversary",
        "With Family", "With Friends", "Solo", "Must See Again"
    ]
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(availableTags, id: \.self) { tag in
                Button(action: {
                    if selectedTags.contains(tag) {
                        selectedTags.removeAll { $0 == tag }
                    } else {
                        selectedTags.append(tag)
                    }
                }) {
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedTags.contains(tag) ? Color.blue : Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            }
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - ViewModel

@MainActor
class LogFlowViewModel: ObservableObject {
    @Published var operaTitle = ""
    @Published var attendanceDate = Date()
    @Published var venueName = ""
    @Published var city = ""
    
    @Published var overallRating: Double = 0
    @Published var musicRating: Double = 0
    @Published var performanceRating: Double = 0
    @Published var productionRating: Double = 0
    
    @Published var notes = ""
    @Published var tags: [String] = []
    
    @Published var isSaving = false
    
    var isBasicInfoValid: Bool {
        !operaTitle.isEmpty && !venueName.isEmpty && !city.isEmpty
    }
    
    func processTicketScan() async {
        // Simulate OCR processing
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Mock extracted data
        operaTitle = "La Bohème"
        venueName = "Metropolitan Opera House"
        city = "New York"
        attendanceDate = Date()
    }
    
    func saveLog() async {
        isSaving = true
        
        let log = AttendanceLog(
            id: UUID().uuidString,
            userId: "user-1",
            operaId: "opera-1",
            operaTitle: operaTitle,
            composer: "Puccini", // TODO: Get from search
            productionId: nil,
            venueId: nil,
            venueName: venueName,
            city: city,
            country: "USA", // TODO: Get from location
            attendanceDate: attendanceDate,
            performanceTime: nil,
            overallRating: overallRating > 0 ? overallRating : nil,
            musicRating: musicRating > 0 ? musicRating : nil,
            performanceRating: performanceRating > 0 ? performanceRating : nil,
            productionRating: productionRating > 0 ? productionRating : nil,
            notes: notes.isEmpty ? nil : notes,
            tags: tags,
            photos: [],
            ticketImageURL: nil,
            ticketData: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            _ = try await APIService.shared.createAttendanceLog(log)
            // Success - haptic feedback
        } catch {
            print("Error saving log: \(error)")
        }
        
        isSaving = false
    }
}

#Preview {
    LogFlowView()
}

