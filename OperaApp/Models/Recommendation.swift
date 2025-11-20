//
//  Recommendation.swift
//  OperaApp
//
//  Recommendation models
//

import Foundation

struct Recommendation: Codable, Identifiable {
    let id: String
    let type: RecommendationType
    let title: String
    let subtitle: String
    let description: String
    let imageURL: String?
    let reason: String // Why this is recommended
    
    // Reference to the actual item
    let referenceId: String
    let referenceType: ReferenceType
    
    var score: Double // 0-1 confidence score
    var createdAt: Date
    
    enum RecommendationType: String, Codable {
        case opera = "opera"
        case production = "production"
        case venue = "venue"
        case learningPath = "learning_path"
        case similarWork = "similar_work"
    }
    
    enum ReferenceType: String, Codable {
        case opera
        case production
        case venue
        case artist
        case collection
    }
}

// A curated learning path or collection
struct LearningPath: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let curator: String?
    let imageURL: String?
    let items: [LearningPathItem]
    let estimatedDuration: String // e.g., "3 months", "1 season"
    let difficulty: String // "Beginner", "Intermediate", "Advanced"
    var createdAt: Date
}

struct LearningPathItem: Codable, Identifiable {
    let id: String
    let operaId: String
    let operaTitle: String
    let composer: String
    let order: Int
    let notes: String?
    let imageURL: String?
}

