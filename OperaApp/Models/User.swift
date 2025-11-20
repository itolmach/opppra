//
//  User.swift
//  OperaApp
//
//  User model and profile data
//

import Foundation

struct User: Codable, Identifiable {
    let id: String
    var email: String
    var displayName: String?
    var profileImageURL: String?
    var bio: String?
    
    // Privacy settings
    var isProfilePublic: Bool
    var showStats: Bool
    var showLists: Bool
    
    // Onboarding preferences
    var favoriteComposers: [String]
    var favoriteChoreographers: [String]
    var favoriteEras: [String]
    var favoriteHouses: [String]
    
    // Statistics
    var totalExperienced: Int
    var totalWishlist: Int
    var primaryHouse: String?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String? = nil,
        profileImageURL: String? = nil,
        bio: String? = nil,
        isProfilePublic: Bool = false,
        showStats: Bool = true,
        showLists: Bool = false,
        favoriteComposers: [String] = [],
        favoriteChoreographers: [String] = [],
        favoriteEras: [String] = [],
        favoriteHouses: [String] = [],
        totalExperienced: Int = 0,
        totalWishlist: Int = 0,
        primaryHouse: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.bio = bio
        self.isProfilePublic = isProfilePublic
        self.showStats = showStats
        self.showLists = showLists
        self.favoriteComposers = favoriteComposers
        self.favoriteChoreographers = favoriteChoreographers
        self.favoriteEras = favoriteEras
        self.favoriteHouses = favoriteHouses
        self.totalExperienced = totalExperienced
        self.totalWishlist = totalWishlist
        self.primaryHouse = primaryHouse
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// User taste preferences for onboarding
struct UserTasteProfile: Codable {
    var composers: [String]
    var choreographers: [String]
    var eras: [String]
    var houses: [String]
    
    var isComplete: Bool {
        !composers.isEmpty && !eras.isEmpty
    }
}

