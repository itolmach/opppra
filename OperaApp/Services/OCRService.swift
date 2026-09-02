//
//  OCRService.swift
//  OperaApp
//
//  On-device text recognition for scanned tickets/playbills using Vision.
//  No network round trip and no third-party OCR service involved.
//

import Foundation
import Vision
import UIKit

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "That doesn't look like a photo we can read. Try another one."
        case .recognitionFailed(let error):
            return "Couldn't read the ticket: \(error.localizedDescription)"
        }
    }
}

enum OCRService {
    /// Runs on-device text recognition over a ticket/playbill photo and
    /// extracts the fields the log flow cares about with simple heuristics.
    /// Nothing here is a real parser for every ticket layout -- it is a best
    /// effort that always leaves the user able to correct fields by hand.
    static func scanTicket(imageData: Data) async throws -> TicketData {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw OCRError.invalidImage
        }

        let lines = try await recognizeTextLines(in: cgImage)
        let fullText = lines.joined(separator: "\n")

        return TicketData(
            scannedText: fullText.isEmpty ? nil : fullText,
            extractedDate: extractDate(from: lines),
            extractedVenue: extractVenue(from: lines),
            extractedSeatInfo: extractSeatInfo(from: lines),
            extractedPrice: extractPrice(from: lines)
        )
    }

    private static func recognizeTextLines(in cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }

    private static func extractPrice(from lines: [String]) -> String? {
        let pattern = #"[\$£€]\s?\d{1,4}(?:[.,]\d{2})?"#
        return firstMatch(of: pattern, in: lines)
    }

    private static func extractSeatInfo(from lines: [String]) -> String? {
        let keywords = ["seat", "row", "section", "orchestra", "balcony", "mezzanine", "box"]
        return lines.first { line in
            let lower = line.lowercased()
            return keywords.contains { lower.contains($0) }
        }
    }

    private static func extractVenue(from lines: [String]) -> String? {
        let keywords = ["opera", "theatre", "theater", "hall", "house", "auditorium"]
        return lines.first { line in
            let lower = line.lowercased()
            return keywords.contains { lower.contains($0) }
        }
    }

    private static func extractDate(from lines: [String]) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        for line in lines {
            guard let detector else { break }
            let range = NSRange(line.startIndex..., in: line)
            if let match = detector.firstMatch(in: line, range: range), let date = match.date {
                return date
            }
        }
        return nil
    }

    private static func firstMatch(of pattern: String, in lines: [String]) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range), let swiftRange = Range(match.range, in: line) {
                return String(line[swiftRange])
            }
        }
        return nil
    }
}
