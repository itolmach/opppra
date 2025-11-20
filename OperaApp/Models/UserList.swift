//
//  UserList.swift
//  OperaApp
//
//  User's custom lists and wishlist items
//

import Foundation

// User's list (wishlist, experienced, custom)
struct UserList: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var type: ListType
    var items: [ListItem]
    var isDefault: Bool // "Wanna Experience" and "Have Experienced" are defaults
    var color: String? // Hex color for custom lists
    var iconName: String?
    var createdAt: Date
    var updatedAt: Date
    
    enum ListType: String, Codable {
        case wantsToExperience = "wants_to_experience"
        case hasExperienced = "has_experienced"
        case custom = "custom"
    }
    
    var count: Int {
        items.count
    }
}

struct ListItem: Codable, Identifiable, Hashable {
    let id: String
    let operaId: String
    let operaTitle: String
    let composer: String
    let imageURL: String?
    var notes: String?
    var tags: [String]
    var priority: Int? // For wish lists
    var addedAt: Date
    
    // For experienced items
    var experiencedDate: Date?
    var rating: Double?
    var productionId: String?
}

// User's log entry for an attended performance
struct AttendanceLog: Codable, Identifiable {
    let id: String
    let userId: String
    let operaId: String
    let operaTitle: String
    let composer: String
    let productionId: String?
    let venueId: String?
    let venueName: String
    let city: String
    let country: String
    
    // Performance details
    let attendanceDate: Date
    let performanceTime: String?
    
    // User's experience
    var overallRating: Double? // 1-5
    var musicRating: Double?
    var performanceRating: Double?
    var productionRating: Double?
    var notes: String?
    var tags: [String]
    var photos: [String] // URLs to user-uploaded photos
    
    // OCR data from ticket
    var ticketImageURL: String?
    var ticketData: TicketData?
    
    var createdAt: Date
    var updatedAt: Date
}

struct TicketData: Codable {
    var scannedText: String?
    var extractedDate: Date?
    var extractedVenue: String?
    var extractedSeatInfo: String?
    var extractedPrice: String?
}

