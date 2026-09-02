//
//  APIService.swift
//  OperaApp
//
//  Two data sources, both real:
//  - The OpenOpus API (https://api.openopus.org) for the opera/composer
//    catalog -- a free public catalog, so there's nothing to self-host here.
//  - Supabase Postgres for everything user-owned: lists, attendance logs,
//    recommendation feedback, plus the productions/venues/performances
//    catalog that OpenOpus doesn't provide.
//

import Foundation
import Supabase

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

enum APIError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to do that."
        }
    }
}

class APIService {
    static let shared = APIService()

    private let openOpusBaseURL = "https://api.openopus.org"
    private var db: SupabaseClient { SupabaseManager.client }

    private init() {}

    private func currentUserId() async throws -> UUID {
        guard let userId = try? await db.auth.session.user.id else {
            throw APIError.notAuthenticated
        }
        return userId
    }

    // MARK: - Search (OpenOpus)

    private func searchComposers(query: String) async throws -> [OpenOpusComposer] {
        let urlString = "\(openOpusBaseURL)/composer/list/search/\(query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query).json"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenOpusComposersResponse.self, from: data)
        return response.composers
    }

    func search(query: String, filters: SearchFilters? = nil) async throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []

        let composers = try await searchComposers(query: query)

        for composer in composers.prefix(3) {
            let worksURL = "\(openOpusBaseURL)/work/list/composer/\(composer.id)/genre/Opera.json"

            guard let url = URL(string: worksURL) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let worksResponse = try JSONDecoder().decode(OpenOpusWorksResponse.self, from: data)

                if let works = worksResponse.works {
                    for work in works.prefix(5) {
                        results.append(
                            SearchResult(
                                id: "\(composer.id)-\(work.id)",
                                type: .opera,
                                title: work.title,
                                subtitle: composer.complete_name ?? composer.name,
                                imageURL: composer.portrait
                            )
                        )
                    }
                }
            } catch {
                continue
            }
        }

        return results
    }

    // MARK: - Opera Works (OpenOpus)

    func fetchOpera(id: String) async throws -> Opera {
        let popular = try await fetchPopularOperas()
        if let opera = popular.first(where: { $0.id == id }) {
            return opera
        }
        throw URLError(.fileDoesNotExist)
    }

    func fetchPopularOperas(limit: Int = 20) async throws -> [Opera] {
        let urlString = "\(openOpusBaseURL)/composer/list/pop.json"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenOpusComposersResponse.self, from: data)

        var allOperas: [Opera] = []

        for composer in response.composers.prefix(5) {
            let worksURL = "\(openOpusBaseURL)/work/list/composer/\(composer.id)/genre/Opera.json"
            guard let url = URL(string: worksURL) else { continue }

            do {
                let (worksData, _) = try await URLSession.shared.data(from: url)
                let worksResponse = try JSONDecoder().decode(OpenOpusWorksResponse.self, from: worksData)

                if let works = worksResponse.works {
                    for work in works.prefix(4) {
                        allOperas.append(
                            Opera(
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
                        )
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

    // MARK: - Productions (Supabase)

    func fetchProduction(id: String) async throws -> Production {
        let row: ProductionRow = try await db
            .from("productions")
            .select(ProductionRow.selectQuery)
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return row.asProduction()
    }

    func fetchUpcomingProductions(limit: Int = 20) async throws -> [Production] {
        let rows: [ProductionRow] = try await db
            .from("productions")
            .select(ProductionRow.selectQuery)
            .execute()
            .value

        return rows
            .map { $0.asProduction() }
            .filter { $0.hasUpcomingPerformances }
            .sorted { ($0.nextPerformance?.date ?? .distantFuture) < ($1.nextPerformance?.date ?? .distantFuture) }
            .prefix(limit)
            .map { $0 }
    }

    func fetchProductionsForOpera(operaId: String) async throws -> [Production] {
        let rows: [ProductionRow] = try await db
            .from("productions")
            .select(ProductionRow.selectQuery)
            .eq("opera_id", value: operaId)
            .execute()
            .value
        return rows.map { $0.asProduction() }
    }

    // MARK: - User Lists (Supabase)

    func fetchUserLists() async throws -> [UserList] {
        let userId = try await currentUserId()
        let rows: [UserListRow] = try await db
            .from("user_lists")
            .select("*, list_items(*)")
            .eq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.map { $0.asUserList() }
    }

    func createList(name: String, type: UserList.ListType) async throws -> UserList {
        let userId = try await currentUserId()
        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let type: String
            let is_default: Bool
        }
        let row: UserListRow = try await db
            .from("user_lists")
            .insert(Insert(user_id: userId, name: name, type: type.rawValue, is_default: false))
            .select("*, list_items(*)")
            .single()
            .execute()
            .value
        return row.asUserList()
    }

    func addToList(listId: String, opera: Opera, notes: String? = nil) async throws {
        let userId = try await currentUserId()
        struct Insert: Encodable {
            let list_id: String
            let user_id: UUID
            let opera_id: String
            let opera_title: String
            let composer: String
            let image_url: String?
            let notes: String?
        }
        try await db
            .from("list_items")
            .insert(Insert(
                list_id: listId,
                user_id: userId,
                opera_id: opera.id,
                opera_title: opera.title,
                composer: opera.composer,
                image_url: opera.imageURL,
                notes: notes
            ))
            .execute()
    }

    func removeFromList(listId: String, itemId: String) async throws {
        try await db
            .from("list_items")
            .delete()
            .eq("id", value: itemId)
            .eq("list_id", value: listId)
            .execute()
    }

    // MARK: - Attendance Logs (Supabase)

    func fetchAttendanceLogs() async throws -> [AttendanceLog] {
        let userId = try await currentUserId()
        let rows: [AttendanceLogRow] = try await db
            .from("attendance_logs")
            .select()
            .eq("user_id", value: userId)
            .order("attendance_date", ascending: false)
            .execute()
            .value
        return rows.map { $0.asAttendanceLog() }
    }

    func createAttendanceLog(_ log: AttendanceLog) async throws -> AttendanceLog {
        let userId = try await currentUserId()
        let row: AttendanceLogRow = try await db
            .from("attendance_logs")
            .insert(AttendanceLogRow(from: log, userId: userId))
            .select()
            .single()
            .execute()
            .value
        return row.asAttendanceLog()
    }

    func updateAttendanceLog(_ log: AttendanceLog) async throws -> AttendanceLog {
        let userId = try await currentUserId()
        let row: AttendanceLogRow = try await db
            .from("attendance_logs")
            .update(AttendanceLogRow(from: log, userId: userId))
            .eq("id", value: log.id)
            .select()
            .single()
            .execute()
            .value
        return row.asAttendanceLog()
    }

    func deleteAttendanceLog(id: String) async throws {
        try await db.from("attendance_logs").delete().eq("id", value: id).execute()
    }

    // MARK: - Recommendations

    /// Rules-based recommendations from the user's taste profile: favorite
    /// composers/eras are weighted highest, general popularity fills in the
    /// rest. Not machine-learned, but real -- it reflects each user's actual
    /// profile and actual catalog/list state, nothing mocked.
    func fetchRecommendations(limit: Int = 10) async throws -> [Recommendation] {
        let userId = try await currentUserId()

        async let catalogTask = fetchPopularOperas(limit: 40)
        async let ownedTask: [String] = db
            .from("list_items")
            .select("opera_id")
            .eq("user_id", value: userId)
            .execute()
            .value
            .map { (row: OperaIdRow) in row.opera_id }
        async let dislikedTask: [String] = db
            .from("recommendation_feedback")
            .select("reference_id")
            .eq("user_id", value: userId)
            .eq("liked", value: false)
            .execute()
            .value
            .map { (row: ReferenceIdRow) in row.reference_id }

        let catalog = try await catalogTask
        let owned = Set((try? await ownedTask) ?? [])
        let disliked = Set((try? await dislikedTask) ?? [])

        let favoriteComposers = Set(
            (AuthenticationService.shared.currentUser?.favoriteComposers ?? []).map { $0.lowercased() }
        )
        let favoriteEras = Set(
            (AuthenticationService.shared.currentUser?.favoriteEras ?? []).map { $0.lowercased() }
        )

        let scored: [Recommendation] = catalog
            .filter { !owned.contains($0.id) && !disliked.contains($0.id) }
            .map { opera in
                var score = 0.4 + Double(opera.popularity) / 500.0
                var reason = "Popular with opera lovers"

                if favoriteComposers.contains(opera.composer.lowercased()) {
                    score += 0.35
                    reason = "By \(opera.composer), one of your favorite composers"
                } else if favoriteEras.contains(opera.era.lowercased()) {
                    score += 0.15
                    reason = "Matches your taste for \(opera.era) opera"
                }

                return Recommendation(
                    id: "rec-\(opera.id)",
                    type: .opera,
                    title: opera.title,
                    subtitle: opera.composerAndYear,
                    description: opera.synopsis,
                    imageURL: opera.imageURL,
                    reason: reason,
                    referenceId: opera.id,
                    referenceType: .opera,
                    score: min(score, 0.99),
                    createdAt: Date()
                )
            }

        return Array(scored.sorted { $0.score > $1.score }.prefix(limit))
    }

    func updateRecommendationFeedback(id: String, liked: Bool) async throws {
        let userId = try await currentUserId()
        // Recommendation ids from fetchRecommendations() are always
        // "rec-<operaId>"; recover the underlying catalog id from it.
        let referenceId = id.hasPrefix("rec-") ? String(id.dropFirst("rec-".count)) : id

        struct Upsert: Encodable {
            let user_id: UUID
            let reference_id: String
            let reference_type: String
            let liked: Bool
        }
        try await db
            .from("recommendation_feedback")
            .upsert(
                Upsert(user_id: userId, reference_id: referenceId, reference_type: "opera", liked: liked),
                onConflict: "user_id,reference_id,reference_type"
            )
            .execute()
    }

    // MARK: - Ticket Photo Storage

    func uploadTicketPhoto(imageData: Data) async throws -> String {
        let userId = try await currentUserId()
        let path = "\(userId.uuidString)/\(UUID().uuidString).jpg"
        try await db.storage.from("ticket-photos").upload(
            path,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg")
        )
        return path
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

// MARK: - Supabase row <-> model mapping

private struct OperaIdRow: Decodable { let opera_id: String }
private struct ReferenceIdRow: Decodable { let reference_id: String }

private struct VenueRow: Codable {
    let id: String
    let name: String
    let city: String
    let country: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let image_url: String?
    let website: String?
    let capacity: Int?

    func asVenue() -> Venue {
        Venue(
            id: id, name: name, city: city, country: country, address: address,
            latitude: latitude, longitude: longitude, imageURL: image_url,
            website: website, capacity: capacity
        )
    }
}

private struct CastMemberRow: Codable {
    let id: String
    let name: String
    let role: String
    let artist_id: String?
    let image_url: String?

    func asCastMember() -> CastMember {
        CastMember(id: id, name: name, role: role, artistId: artist_id, imageURL: image_url)
    }
}

private struct PerformanceRow: Codable {
    let id: String
    let production_id: String
    let date: Date
    let time: String
    let ticket_url: String?
    let ticket_price_range: String?
    let is_sold_out: Bool
    let notes: String?

    func asPerformance() -> Performance {
        Performance(
            id: id, productionId: production_id, date: date, time: time,
            ticketURL: ticket_url, ticketPriceRange: ticket_price_range,
            isSoldOut: is_sold_out, notes: notes
        )
    }
}

private struct ProductionRow: Codable {
    static let selectQuery = "*, venue:venues(*), cast_members(*), performances(*)"

    let id: String
    let opera_id: String
    let opera_title: String
    let company: String
    let company_id: String?
    let director: String?
    let conductor: String?
    let choreographer: String?
    let production_year: Int?
    let designer: String?
    let description: String?
    let image_url: String?
    let image_gallery: [String]
    let created_at: Date
    let updated_at: Date
    let venue: VenueRow?
    let cast_members: [CastMemberRow]
    let performances: [PerformanceRow]

    func asProduction() -> Production {
        Production(
            id: id,
            operaId: opera_id,
            operaTitle: opera_title,
            company: company,
            companyId: company_id,
            director: director,
            conductor: conductor,
            choreographer: choreographer,
            productionYear: production_year,
            designer: designer,
            cast: cast_members.map { $0.asCastMember() },
            venue: venue?.asVenue() ?? Venue(
                id: "unknown", name: "Unknown venue", city: "", country: "",
                address: nil, latitude: nil, longitude: nil, imageURL: nil, website: nil, capacity: nil
            ),
            performances: performances.map { $0.asPerformance() },
            description: description,
            imageURL: image_url,
            imageGallery: image_gallery,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

private struct ListItemRow: Codable {
    let id: String
    let opera_id: String
    let opera_title: String
    let composer: String
    let image_url: String?
    let notes: String?
    let tags: [String]
    let priority: Int?
    let added_at: Date
    let experienced_date: Date?
    let rating: Double?
    let production_id: String?

    func asListItem() -> ListItem {
        ListItem(
            id: id, operaId: opera_id, operaTitle: opera_title, composer: composer,
            imageURL: image_url, notes: notes, tags: tags, priority: priority,
            addedAt: added_at, experiencedDate: experienced_date, rating: rating,
            productionId: production_id
        )
    }
}

private struct UserListRow: Codable {
    let id: String
    let name: String
    let type: String
    let is_default: Bool
    let color: String?
    let icon_name: String?
    let created_at: Date
    let updated_at: Date
    let list_items: [ListItemRow]

    func asUserList() -> UserList {
        UserList(
            id: id,
            name: name,
            type: UserList.ListType(rawValue: type) ?? .custom,
            items: list_items.map { $0.asListItem() },
            isDefault: is_default,
            color: color,
            iconName: icon_name,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

private struct AttendanceLogRow: Codable {
    let id: String
    let user_id: UUID
    let opera_id: String
    let opera_title: String
    let composer: String
    let production_id: String?
    let venue_id: String?
    let venue_name: String
    let city: String
    let country: String
    let attendance_date: Date
    let performance_time: String?
    let overall_rating: Double?
    let music_rating: Double?
    let performance_rating: Double?
    let production_rating: Double?
    let notes: String?
    let tags: [String]
    let photos: [String]
    let ticket_image_url: String?
    let ticket_scanned_text: String?
    let ticket_extracted_date: Date?
    let ticket_extracted_venue: String?
    let ticket_extracted_seat_info: String?
    let ticket_extracted_price: String?
    let created_at: Date
    let updated_at: Date

    init(from log: AttendanceLog, userId: UUID) {
        id = log.id
        user_id = userId
        opera_id = log.operaId
        opera_title = log.operaTitle
        composer = log.composer
        production_id = log.productionId
        venue_id = log.venueId
        venue_name = log.venueName
        city = log.city
        country = log.country
        attendance_date = log.attendanceDate
        performance_time = log.performanceTime
        overall_rating = log.overallRating
        music_rating = log.musicRating
        performance_rating = log.performanceRating
        production_rating = log.productionRating
        notes = log.notes
        tags = log.tags
        photos = log.photos
        ticket_image_url = log.ticketImageURL
        ticket_scanned_text = log.ticketData?.scannedText
        ticket_extracted_date = log.ticketData?.extractedDate
        ticket_extracted_venue = log.ticketData?.extractedVenue
        ticket_extracted_seat_info = log.ticketData?.extractedSeatInfo
        ticket_extracted_price = log.ticketData?.extractedPrice
        created_at = log.createdAt
        updated_at = log.updatedAt
    }

    func asAttendanceLog() -> AttendanceLog {
        let ticketData: TicketData? = {
            guard ticket_scanned_text != nil || ticket_extracted_date != nil
                || ticket_extracted_venue != nil || ticket_extracted_seat_info != nil
                || ticket_extracted_price != nil else { return nil }
            return TicketData(
                scannedText: ticket_scanned_text,
                extractedDate: ticket_extracted_date,
                extractedVenue: ticket_extracted_venue,
                extractedSeatInfo: ticket_extracted_seat_info,
                extractedPrice: ticket_extracted_price
            )
        }()

        return AttendanceLog(
            id: id,
            userId: user_id.uuidString,
            operaId: opera_id,
            operaTitle: opera_title,
            composer: composer,
            productionId: production_id,
            venueId: venue_id,
            venueName: venue_name,
            city: city,
            country: country,
            attendanceDate: attendance_date,
            performanceTime: performance_time,
            overallRating: overall_rating,
            musicRating: music_rating,
            performanceRating: performance_rating,
            productionRating: production_rating,
            notes: notes,
            tags: tags,
            photos: photos,
            ticketImageURL: ticket_image_url,
            ticketData: ticketData,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}
