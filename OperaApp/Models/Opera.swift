//
//  Opera.swift
//  OperaApp
//
//  Core opera work model
//

import Foundation

// An opera work (e.g., "La Bohème" by Puccini)
struct Opera: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let composer: String
    let composerId: String?
    let librettist: String?
    let premiereYear: Int?
    let era: String // e.g., "Baroque", "Romantic", "Contemporary"
    let language: String
    let synopsis: String
    let duration: Int? // in minutes
    let acts: Int?
    
    // Metadata
    let imageURL: String?
    let popularity: Int // 0-100 score
    let tags: [String]
    
    var createdAt: Date
    var updatedAt: Date
    
    // Computed property for display
    var composerAndYear: String {
        if let year = premiereYear {
            return "\(composer) • \(year)"
        }
        return composer
    }
}

// A specific production of an opera work
struct Production: Codable, Identifiable, Hashable {
    let id: String
    let operaId: String
    let operaTitle: String
    let company: String
    let companyId: String?
    let director: String?
    let conductor: String?
    let choreographer: String?
    let productionYear: Int?
    let designer: String?
    
    // Cast information
    let cast: [CastMember]
    
    // Venue & Schedule
    let venue: Venue
    let performances: [Performance]
    
    // Description and images
    let description: String?
    let imageURL: String?
    let imageGallery: [String]
    
    var createdAt: Date
    var updatedAt: Date
    
    // Helper computed properties
    var nextPerformance: Performance? {
        performances
            .filter { $0.date > Date() }
            .sorted { $0.date < $1.date }
            .first
    }
    
    var hasUpcomingPerformances: Bool {
        nextPerformance != nil
    }
}

struct CastMember: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let artistId: String?
    let imageURL: String?
}

struct Performance: Codable, Identifiable, Hashable {
    let id: String
    let productionId: String
    let date: Date
    let time: String
    let ticketURL: String?
    let ticketPriceRange: String?
    let isSoldOut: Bool
    let notes: String?
}

struct Venue: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let country: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let imageURL: String?
    let website: String?
    let capacity: Int?
    
    var fullLocation: String {
        "\(city), \(country)"
    }
}

// Search result type that can represent different entities
enum SearchResultType: Codable {
    case opera(Opera)
    case production(Production)
    case venue(Venue)
    case artist(Artist)
}

struct Artist: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String // "composer", "singer", "conductor", "director", "choreographer"
    let bio: String?
    let imageURL: String?
    let birthYear: Int?
    let deathYear: Int?
    let nationality: String?
}

