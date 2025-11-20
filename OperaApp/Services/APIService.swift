//
//  APIService.swift
//  OperaApp
//
//  Network service for API calls
//

import Foundation

// MARK: - OpenOpus API Response Types

struct OpenOpusSearchResponse: Codable {
    let results: [OpenOpusWork]?
}

struct OpenOpusWork: Codable {
    let id: String
    let title: String
    let subtitle: String?
    let genre: String?
    let composer: OpenOpusComposer?
    let year: String?
    let recommended: Bool?
}

struct OpenOpusComposer: Codable {
    let id: String
    let name: String
    let complete_name: String?
    let birth: String?
    let death: String?
    let epoch: String?
    let portrait: String?
}

struct OpenOpusWorkDetail: Codable {
    let work: OpenOpusWorkDetailData?
}

struct OpenOpusWorkDetailData: Codable {
    let id: String
    let title: String
    let subtitle: String?
    let genre: String?
    let composer: OpenOpusComposer
    let year: String?
    let recommended: Bool?
}

struct OpenOpusComposersResponse: Codable {
    let composers: [OpenOpusComposer]
}

struct OpenOpusWorksResponse: Codable {
    let works: [OpenOpusWork]?
}

class APIService {
    static let shared = APIService()
    
    private let openOpusBaseURL = "https://api.openopus.org"
    
    private init() {}
    
    // Get auth token when needed for API calls
    @MainActor
    private func getAuthToken() -> String? {
        return AuthenticationService.shared.authToken
    }
    
    // MARK: - Search
    
    // Helper: Search composers by name
    private func searchComposers(query: String) async throws -> [OpenOpusComposer] {
        let urlString = "\(openOpusBaseURL)/composer/list/search/\(query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query).json"
        
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenOpusComposersResponse.self, from: data)
        return response.composers
    }
    
    func search(query: String, filters: SearchFilters? = nil) async throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        print("🔍 Searching for: '\(query)'")
        
        var results: [SearchResult] = []
        
        // Strategy 1: Search composers and get their operas
        do {
            let composers = try await searchComposers(query: query)
            print("✅ Found \(composers.count) composers matching '\(query)'")
            
            // Get operas from matching composers
            for composer in composers.prefix(3) {
                let worksURL = "\(openOpusBaseURL)/work/list/composer/\(composer.id)/genre/Opera.json"
                
                if let url = URL(string: worksURL) {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        let worksResponse = try JSONDecoder().decode(OpenOpusWorksResponse.self, from: data)
                        
                        if let works = worksResponse.works {
                            print("✅ Found \(works.count) operas by \(composer.name)")
                            for work in works.prefix(5) {
                                let result = SearchResult(
                                    id: "\(composer.id)-\(work.id)",
                                    type: .opera,
                                    title: work.title,
                                    subtitle: composer.complete_name ?? composer.name,
                                    imageURL: composer.portrait
                                )
                                results.append(result)
                            }
                        }
                    } catch {
                        print("⚠️ Failed to get works for \(composer.name): \(error)")
                    }
                }
            }
        } catch {
            print("⚠️ Composer search failed: \(error)")
        }
        
        // Strategy 2: Also search mock data for immediate results
        let mockResults = mockSearchResults().filter { result in
            result.title.lowercased().contains(query.lowercased()) ||
            result.subtitle.lowercased().contains(query.lowercased())
        }
        
        // Combine results, prioritizing API results
        if !results.isEmpty {
            return results
        } else if !mockResults.isEmpty {
            print("📦 Returning \(mockResults.count) mock results")
            return mockResults
        }
        
        print("❌ No results found for '\(query)'")
        return []
    }
    
    // MARK: - Opera Works
    
    func fetchOpera(id: String) async throws -> Opera {
        // ID format from search is "composerId" or combined
        // For now, return from popular operas or use mock
        // OpenOpus doesn't have a direct work detail endpoint without composer ID
        let popular = try await fetchPopularOperas()
        if let opera = popular.first(where: { $0.id == id }) {
            return opera
        }
        // Fallback to mock if not found
        return mockOpera()
    }
    
    func fetchPopularOperas(limit: Int = 20) async throws -> [Opera] {
        // Get popular composers first
        let urlString = "\(openOpusBaseURL)/composer/list/pop.json"
        guard let url = URL(string: urlString) else {
            return mockOperas()
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenOpusComposersResponse.self, from: data)
        
        var allOperas: [Opera] = []
        
        // Get works from first few popular composers
        for composer in response.composers.prefix(5) {
            let worksURL = "\(openOpusBaseURL)/work/list/composer/\(composer.id)/genre/Opera.json"
            guard let url = URL(string: worksURL) else { continue }
            
            do {
                let (worksData, _) = try await URLSession.shared.data(from: url)
                let worksResponse = try JSONDecoder().decode(OpenOpusWorksResponse.self, from: worksData)
                
                if let works = worksResponse.works {
                    for work in works.prefix(4) {
                        let opera = Opera(
                            id: "\(composer.id)-\(work.id)",
                            title: work.title,
                            composer: composer.complete_name ?? composer.name,
                            composerId: composer.id,
                            librettist: nil,
                            premiereYear: Int(work.year ?? ""),
                            era: composer.epoch ?? "Unknown",
                            language: "Various",
                            synopsis: work.subtitle ?? "A masterful opera by \(composer.name)",
                            duration: nil,
                            acts: nil,
                            imageURL: composer.portrait,
                            popularity: work.recommended == true ? 90 : 70,
                            tags: [composer.epoch ?? "Classical", "Opera", work.genre ?? ""],
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                        allOperas.append(opera)
                    }
                }
            } catch {
                continue
            }
            
            if allOperas.count >= limit {
                break
            }
        }
        
        return Array(allOperas.prefix(limit))
    }
    
    // MARK: - Productions
    
    func fetchProduction(id: String) async throws -> Production {
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockProduction()
    }
    
    func fetchUpcomingProductions(limit: Int = 20) async throws -> [Production] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockProductions()
    }
    
    func fetchProductionsForOpera(operaId: String) async throws -> [Production] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockProductions()
    }
    
    // MARK: - User Lists
    
    func fetchUserLists() async throws -> [UserList] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockUserLists()
    }
    
    func createList(name: String, type: UserList.ListType) async throws -> UserList {
        try await Task.sleep(nanoseconds: 500_000_000)
        return UserList(
            id: UUID().uuidString,
            name: name,
            type: type,
            items: [],
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func addToList(listId: String, operaId: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    func removeFromList(listId: String, itemId: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    // MARK: - Attendance Logs
    
    func fetchAttendanceLogs() async throws -> [AttendanceLog] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockAttendanceLogs()
    }
    
    func createAttendanceLog(_ log: AttendanceLog) async throws -> AttendanceLog {
        try await Task.sleep(nanoseconds: 500_000_000)
        return log
    }
    
    func updateAttendanceLog(_ log: AttendanceLog) async throws -> AttendanceLog {
        try await Task.sleep(nanoseconds: 500_000_000)
        return log
    }
    
    func deleteAttendanceLog(id: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    // MARK: - Recommendations
    
    func fetchRecommendations() async throws -> [Recommendation] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockRecommendations()
    }
    
    func updateRecommendationFeedback(id: String, liked: Bool) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    // MARK: - OCR & Ticket Scanning
    
    func processTicketImage(_ imageData: Data) async throws -> TicketData {
        try await Task.sleep(nanoseconds: 2_000_000_000) // Simulate OCR processing
        
        return TicketData(
            scannedText: "Sample ticket text",
            extractedDate: Date(),
            extractedVenue: "Metropolitan Opera House",
            extractedSeatInfo: "Orchestra, Row K, Seat 15",
            extractedPrice: "$145.00"
        )
    }
}

// MARK: - Supporting Types

struct SearchFilters: Codable {
    var era: String?
    var composer: String?
    var venue: String?
    var language: String?
}

struct SearchResult: Identifiable {
    let id: String
    let type: SearchResultItemType
    let title: String
    let subtitle: String
    let imageURL: String?
}

enum SearchResultItemType {
    case opera
    case production
    case venue
    case artist
}

// MARK: - Mock Data

extension APIService {
    private func mockOpera() -> Opera {
        Opera(
            id: "1",
            title: "La Bohème",
            composer: "Giacomo Puccini",
            composerId: "puccini-1",
            librettist: "Luigi Illica, Giuseppe Giacosa",
            premiereYear: 1896,
            era: "Romantic",
            language: "Italian",
            synopsis: "Set in the Latin Quarter of Paris around 1830, it tells the story of the doomed love affair between a young seamstress, Mimì, and a struggling poet, Rodolfo.",
            duration: 135,
            acts: 4,
            imageURL: nil,
            popularity: 95,
            tags: ["Romantic", "Italian", "Popular", "Tragedy"],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func mockOperas() -> [Opera] {
        [
            mockOpera(),
            Opera(
                id: "2",
                title: "Carmen",
                composer: "Georges Bizet",
                composerId: "bizet-1",
                librettist: "Henri Meilhac, Ludovic Halévy",
                premiereYear: 1875,
                era: "Romantic",
                language: "French",
                synopsis: "The story of the downfall of Don José, a naïve soldier who is seduced by the fiery gypsy Carmen.",
                duration: 165,
                acts: 4,
                imageURL: nil,
                popularity: 92,
                tags: ["Romantic", "French", "Popular", "Drama"],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    private func mockProduction() -> Production {
        Production(
            id: "prod-1",
            operaId: "1",
            operaTitle: "La Bohème",
            company: "Metropolitan Opera",
            companyId: "met-1",
            director: "Franco Zeffirelli",
            conductor: "Yannick Nézet-Séguin",
            choreographer: nil,
            productionYear: 2023,
            designer: "Franco Zeffirelli",
            cast: [
                CastMember(id: "c1", name: "Anna Netrebko", role: "Mimì", artistId: "netrebko-1", imageURL: nil),
                CastMember(id: "c2", name: "Jonas Kaufmann", role: "Rodolfo", artistId: "kaufmann-1", imageURL: nil)
            ],
            venue: Venue(
                id: "v1",
                name: "Metropolitan Opera House",
                city: "New York",
                country: "USA",
                address: "Lincoln Center, New York, NY 10023",
                latitude: 40.7730,
                longitude: -73.9845,
                imageURL: nil,
                website: "https://www.metopera.org",
                capacity: 3800
            ),
            performances: [
                Performance(
                    id: "perf-1",
                    productionId: "prod-1",
                    date: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
                    time: "7:30 PM",
                    ticketURL: "https://www.metopera.org/tickets",
                    ticketPriceRange: "$50-$350",
                    isSoldOut: false,
                    notes: nil
                )
            ],
            description: "Franco Zeffirelli's iconic production of La Bohème returns to the Met.",
            imageURL: nil,
            imageGallery: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func mockProductions() -> [Production] {
        [mockProduction()]
    }
    
    private func mockUserLists() -> [UserList] {
        [
            UserList(
                id: "list-1",
                name: "Wanna Experience",
                type: .wantsToExperience,
                items: [],
                isDefault: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            UserList(
                id: "list-2",
                name: "Have Experienced",
                type: .hasExperienced,
                items: [],
                isDefault: true,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    private func mockAttendanceLogs() -> [AttendanceLog] {
        [
            AttendanceLog(
                id: "log-1",
                userId: "user-1",
                operaId: "1",
                operaTitle: "La Bohème",
                composer: "Puccini",
                productionId: "prod-1",
                venueId: "v1",
                venueName: "Metropolitan Opera House",
                city: "New York",
                country: "USA",
                attendanceDate: Date(),
                performanceTime: "7:30 PM",
                overallRating: 5.0,
                notes: "Absolutely stunning performance!",
                tags: ["Memorable", "First Time"],
                photos: [],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    private func mockRecommendations() -> [Recommendation] {
        [
            Recommendation(
                id: "rec-1",
                type: .opera,
                title: "Tosca",
                subtitle: "Giacomo Puccini",
                description: "Since you loved La Bohème, you'll enjoy this dramatic masterpiece",
                imageURL: nil,
                reason: "Similar composer and era",
                referenceId: "opera-tosca",
                referenceType: .opera,
                score: 0.92,
                createdAt: Date()
            )
        ]
    }
    
    private func mockSearchResults() -> [SearchResult] {
        [
            SearchResult(
                id: "1",
                type: .opera,
                title: "La Bohème",
                subtitle: "Giacomo Puccini • 1896",
                imageURL: nil
            ),
            SearchResult(
                id: "2",
                type: .opera,
                title: "Don Giovanni",
                subtitle: "Wolfgang Amadeus Mozart • 1787",
                imageURL: nil
            ),
            SearchResult(
                id: "3",
                type: .opera,
                title: "Carmen",
                subtitle: "Georges Bizet • 1875",
                imageURL: nil
            ),
            SearchResult(
                id: "4",
                type: .opera,
                title: "La Traviata",
                subtitle: "Giuseppe Verdi • 1853",
                imageURL: nil
            ),
            SearchResult(
                id: "5",
                type: .opera,
                title: "The Magic Flute",
                subtitle: "Wolfgang Amadeus Mozart • 1791",
                imageURL: nil
            ),
            SearchResult(
                id: "6",
                type: .opera,
                title: "Tosca",
                subtitle: "Giacomo Puccini • 1900",
                imageURL: nil
            ),
            SearchResult(
                id: "7",
                type: .opera,
                title: "Madama Butterfly",
                subtitle: "Giacomo Puccini • 1904",
                imageURL: nil
            ),
            SearchResult(
                id: "8",
                type: .opera,
                title: "Rigoletto",
                subtitle: "Giuseppe Verdi • 1851",
                imageURL: nil
            ),
            SearchResult(
                id: "9",
                type: .opera,
                title: "Don Carlos",
                subtitle: "Giuseppe Verdi • 1867",
                imageURL: nil
            ),
            SearchResult(
                id: "10",
                type: .opera,
                title: "Aida",
                subtitle: "Giuseppe Verdi • 1871",
                imageURL: nil
            )
        ]
    }
}

