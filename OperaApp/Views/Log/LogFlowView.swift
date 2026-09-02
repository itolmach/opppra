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
                                    if viewModel.saveError == nil {
                                        dismiss()
                                    }
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
    @State private var errorMessage: String?
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)

                    Text("Reading your ticket...")
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

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: selectedImage) { newValue in
                    guard let newValue else { return }
                    processTicket(newValue)
                }
            }
        }
    }

    private func processTicket(_ item: PhotosPickerItem) {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw OCRError.invalidImage
                }
                await viewModel.processTicketScan(imageData: data)
                onComplete()
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
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

                    // Composer
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Composer")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        TextField("Composer", text: $viewModel.composer)
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

                    // Country
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Country")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        TextField("Country", text: $viewModel.country)
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
                
                if let saveError = viewModel.saveError {
                    Text(saveError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

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
    @Published var composer = ""
    @Published var attendanceDate = Date()
    @Published var venueName = ""
    @Published var city = ""
    @Published var country = ""

    @Published var overallRating: Double = 0
    @Published var musicRating: Double = 0
    @Published var performanceRating: Double = 0
    @Published var productionRating: Double = 0

    @Published var notes = ""
    @Published var tags: [String] = []

    @Published var isSaving = false
    @Published var saveError: String?

    private var ticketImagePath: String?
    private var ticketData: TicketData?

    var isBasicInfoValid: Bool {
        !operaTitle.isEmpty && !venueName.isEmpty && !city.isEmpty
    }

    func processTicketScan(imageData: Data) async {
        do {
            let extracted = try await OCRService.scanTicket(imageData: imageData)
            ticketData = extracted

            if let venue = extracted.extractedVenue { venueName = venue }
            if let date = extracted.extractedDate { attendanceDate = date }

            ticketImagePath = try? await APIService.shared.uploadTicketPhoto(imageData: imageData)
        } catch {
            saveError = error.localizedDescription
        }
    }

    func saveLog() async {
        guard let userId = AuthenticationService.shared.currentUser?.id else {
            saveError = "You need to be signed in to save a log."
            return
        }

        isSaving = true
        saveError = nil

        // No catalog opera is linked in this free-text flow, so derive a
        // stable id from the title the user typed/OCR extracted.
        let operaId = "manual-\(operaTitle.lowercased().replacingOccurrences(of: " ", with: "-"))"

        let log = AttendanceLog(
            id: UUID().uuidString,
            userId: userId,
            operaId: operaId,
            operaTitle: operaTitle,
            composer: composer.isEmpty ? "Unknown" : composer,
            productionId: nil,
            venueId: nil,
            venueName: venueName,
            city: city,
            country: country.isEmpty ? "Unknown" : country,
            attendanceDate: attendanceDate,
            performanceTime: nil,
            overallRating: overallRating > 0 ? overallRating : nil,
            musicRating: musicRating > 0 ? musicRating : nil,
            performanceRating: performanceRating > 0 ? performanceRating : nil,
            productionRating: productionRating > 0 ? productionRating : nil,
            notes: notes.isEmpty ? nil : notes,
            tags: tags,
            photos: [],
            ticketImageURL: ticketImagePath,
            ticketData: ticketData,
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            _ = try await APIService.shared.createAttendanceLog(log)
        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
    }
}

#Preview {
    LogFlowView()
}

