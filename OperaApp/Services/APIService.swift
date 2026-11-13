//
//  APIService.swift
//  OperaApp
//
//  Reads and writes through Neon's Data API.
//
//  Every method signature is unchanged from the Supabase version, so no view
//  needed editing. Two things did change underneath, and they matter:
//
//  1. The catalogue is ours now. Search used to call OpenOpus and build
//     "\(composer.id)-\(work.id)" as the opera id. That id matched nothing
//     the web app wrote, so a work saved on the phone never appeared on the
//     web and vice versa. Operas now come from our own opera_works table and
//     the id is its uuid -- the same value the web app stores in
//     list_items.opera_id and attendance_logs.opera_id.
//
//  2. Row level security does the filtering. None of these queries carry a
//     user id: "the rows I am allowed to see" is already the right answer,
//     and adding a client-side filter would only invite the two to disagree.
//

import Foundation

class APIService {
    static let shared = APIService()
    private init() {}

    private var neon: NeonClient { NeonClient.shared }

    // MARK: - Wire shapes

    private struct ComposerRow: Decodable {
        let name: String
        let portraitUrl: String?
    }

    private struct WorkRow: Decodable {
        let id: UUID
        let title: String
        let language: String?
        let premiereYear: Int?
        let description: String?
        let imageUrl: String?
        let operaComposers: ComposerRow?

        func asOpera() -> Opera {
            Opera(
                id: id.uuidString,
                title: title,
                composer: operaComposers?.name ?? "Unknown",
                composerId: nil,
                librettist: nil,
                premiereYear: premiereYear,
                // The catalogue carries a premiere year but no era, so it is
                // derived rather than invented or left blank.
                era: Self.era(for: premiereYear),
                language: language ?? "",
                synopsis: description ?? "",
                duration: nil,
                acts: nil,
                // The only picture the catalogue has for a work is its
                // composer's portrait, from Wikimedia via Wikidata.
                imageURL: imageUrl ?? operaComposers?.portraitUrl,
                popularity: 0,
                tags: [],
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        private static func era(for year: Int?) -> String {
            guard let year else { return "Unknown" }
            switch year {
            case ..<1600: return "Renaissance"
            case ..<1750: return "Baroque"
            case ..<1830: return "Classical"
            case ..<1900: return "Romantic"
            case ..<1950: return "Modern"
            default: return "Contemporary"
            }
        }
    }

    /// A translated title, with its work nested. Used so a Russian or Italian
    /// search term finds the work it belongs to.
    private struct TitleRow: Decodable {
        let title: String
        let language: String
        let operaWorks: WorkRow?
    }

    private struct ListRow: Decodable {
        let id: UUID
        let name: String
        let type: String
        let isDefault: Bool
        let color: String?
        let iconName: String?
        let createdAt: Date
        let updatedAt: Date
        let listItems: [ListItemRow]?

        func asUserList() -> UserList {
            UserList(
                id: id.uuidString,
                name: name,
                type: UserList.ListType(rawValue: type) ?? .custom,
                items: (listItems ?? []).map { $0.asListItem() },
                isDefault: isDefault,
                color: color,
                iconName: iconName,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    private struct ListItemRow: Decodable {
        let id: UUID
        let operaId: String
        let operaTitle: String
        let composer: String
        let imageUrl: String?
        let notes: String?
        let tags: [String]?
        let priority: Int?
        let addedAt: Date
        let experiencedDate: Date?
        let rating: Double?
        let productionId: String?

        func asListItem() -> ListItem {
            ListItem(
                id: id.uuidString,
                operaId: operaId,
                operaTitle: operaTitle,
                composer: composer,
                imageURL: imageUrl,
                notes: notes,
                tags: tags ?? [],
                priority: priority,
                addedAt: addedAt,
                experiencedDate: experiencedDate,
                rating: rating,
                productionId: productionId
            )
        }
    }

    private struct LogRow: Decodable {
        let id: UUID
        let userId: UUID
        let operaId: String
        let operaTitle: String
        let composer: String
        let productionId: String?
        let venueId: String?
        let venueName: String
        let city: String
        let country: String
        let attendanceDate: Date
        let performanceTime: String?
        let overallRating: Double?
        let musicRating: Double?
        let performanceRating: Double?
        let productionRating: Double?
        let notes: String?
        let tags: [String]?
        let photos: [String]?
        let ticketImageUrl: String?
        let createdAt: Date
        let updatedAt: Date

        func asAttendanceLog() -> AttendanceLog {
            AttendanceLog(
                id: id.uuidString,
                userId: userId.uuidString,
                operaId: operaId,
                operaTitle: operaTitle,
                composer: composer,
                productionId: productionId,
                venueId: venueId,
                venueName: venueName,
                city: city,
                country: country,
                attendanceDate: attendanceDate,
                performanceTime: performanceTime,
                overallRating: overallRating,
                musicRating: musicRating,
                performanceRating: performanceRating,
                productionRating: productionRating,
                notes: notes,
                tags: tags ?? [],
                photos: photos ?? [],
                ticketImageURL: ticketImageUrl,
                ticketData: nil,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    // MARK: - Catalogue

    private static let workSelect =
        "id,title,language,premiere_year,description,image_url,opera_composers(name,portrait_url)"

    /// Searches the catalogue by title, by translated title, and by composer.
    ///
    /// Three queries rather than one because they hit different tables and
    /// PostgREST cannot OR across an embedded resource and its parent. They
    /// run concurrently and are merged here, de-duplicated by work id --
    /// "Хованщина" matches both the work title and its Russian title row,
    /// and should appear once.
    func search(query: String, filters: SearchFilters? = nil) async throws -> [SearchResult] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return [] }
        let pattern = "ilike.*\(Self.escape(term))*"

        async let byTitle = try? neon.get(
            "opera_works",
            query: "select=\(Self.workSelect)&status=eq.published&title=\(pattern)&limit=25",
            as: [WorkRow].self)

        async let byTranslation = try? neon.get(
            "opera_titles",
            query: "select=title,language,opera_works(\(Self.workSelect))&title=\(pattern)&limit=25",
            as: [TitleRow].self)

        async let byComposer = try? neon.get(
            "opera_works",
            query: "select=\(Self.workSelect)&status=eq.published" +
                   "&opera_composers.name=\(pattern)&limit=25",
            as: [WorkRow].self)

        var seen = Set<UUID>()
        var operas: [Opera] = []
        for row in (await byTitle ?? []) + (await byTranslation ?? []).compactMap({ $0.operaWorks })
                 + (await byComposer ?? []) {
            guard seen.insert(row.id).inserted else { continue }
            operas.append(row.asOpera())
        }
        return operas.map { SearchResult(opera: $0) }
    }

    func fetchOpera(id: String) async throws -> Opera {
        let rows = try await neon.get(
            "opera_works",
            query: "select=\(Self.workSelect)&id=eq.\(id)&limit=1",
            as: [WorkRow].self)
        guard let row = rows.first else {
            throw NeonError.api(status: 404, code: nil, message: "No opera with id \(id)")
        }
        return row.asOpera()
    }

    /// There is no popularity column, so "popular" is the best proxy the
    /// catalogue supports: well-documented works, newest premieres first.
    /// Named as it is only because the views already call it that.
    func fetchPopularOperas(limit: Int = 20) async throws -> [Opera] {
        let rows = try await neon.get(
            "opera_works",
            query: "select=\(Self.workSelect)&status=eq.published" +
                   "&premiere_year=not.is.null&order=premiere_year.desc&limit=\(limit)",
            as: [WorkRow].self)
        return rows.map { $0.asOpera() }
    }

    // MARK: - Productions
    //
    // The productions, venues and performances tables exist but have never
    // been populated: the playbill work went into opera_houses and
    // playbill_entries instead, which the web app's Афиша reads. These stay
    // so the views that call them still build, and return nothing rather
    // than failing.

    func fetchProduction(id: String) async throws -> Production {
        throw NeonError.api(status: 404, code: nil,
                            message: "Productions are not populated yet.")
    }

    func fetchUpcomingProductions(limit: Int = 20) async throws -> [Production] { [] }

    func fetchProductionsForOpera(operaId: String) async throws -> [Production] { [] }

    // MARK: - Lists

    func fetchUserLists() async throws -> [UserList] {
        let rows = try await neon.get(
            "user_lists",
            query: "select=id,name,type,is_default,color,icon_name,created_at,updated_at," +
                   "list_items(id,opera_id,opera_title,composer,image_url,notes,tags,priority," +
                   "added_at,experienced_date,rating,production_id)&order=created_at",
            as: [ListRow].self)
        return rows.map { $0.asUserList() }
    }

    func createList(name: String, type: UserList.ListType) async throws -> UserList {
        struct NewList: Encodable {
            let userId: String
            let name: String
            let type: String
            let isDefault: Bool
        }
        let userId = try await currentUserId()
        let rows = try await neon.post(
            "user_lists",
            body: [NewList(userId: userId, name: name, type: type.rawValue, isDefault: false)],
            as: [ListRow].self)
        guard let row = rows.first else {
            throw NeonError.api(status: 500, code: nil, message: "The list was not created.")
        }
        return row.asUserList()
    }

    func addToList(listId: String, opera: Opera, notes: String? = nil) async throws {
        struct NewItem: Encodable {
            let listId: String
            let userId: String
            let operaId: String
            let operaTitle: String
            let composer: String
            let imageUrl: String?
            let notes: String?
        }
        let userId = try await currentUserId()
        _ = try await neon.post(
            "list_items",
            body: [NewItem(listId: listId, userId: userId, operaId: opera.id,
                           operaTitle: opera.title, composer: opera.composer,
                           imageUrl: opera.imageURL, notes: notes)],
            as: [ListItemRow].self)
    }

    func removeFromList(listId: String, itemId: String) async throws {
        try await neon.delete("list_items", query: "id=eq.\(itemId)&list_id=eq.\(listId)")
    }

    // MARK: - Attendance logs

    private static let logSelect =
        "id,user_id,opera_id,opera_title,composer,production_id,venue_id,venue_name,city," +
        "country,attendance_date,performance_time,overall_rating,music_rating," +
        "performance_rating,production_rating,notes,tags,photos,ticket_image_url," +
        "created_at,updated_at"

    func fetchAttendanceLogs() async throws -> [AttendanceLog] {
        let rows = try await neon.get(
            "attendance_logs",
            query: "select=\(Self.logSelect)&order=attendance_date.desc",
            as: [LogRow].self)
        return rows.map { $0.asAttendanceLog() }
    }

    private struct LogPayload: Encodable {
        let userId: String
        let operaId: String
        let operaTitle: String
        let composer: String
        let productionId: String?
        let venueId: String?
        let venueName: String
        let city: String
        let country: String
        let attendanceDate: Date
        let performanceTime: String?
        let overallRating: Double?
        let musicRating: Double?
        let performanceRating: Double?
        let productionRating: Double?
        let notes: String?
        let tags: [String]
        let photos: [String]
        let ticketImageUrl: String?

        init(_ log: AttendanceLog, userId: String) {
            self.userId = userId
            operaId = log.operaId
            operaTitle = log.operaTitle
            composer = log.composer
            productionId = log.productionId
            venueId = log.venueId
            // These three are NOT NULL in the schema with no default, so an
            // empty string is the right value for "not recorded" -- sending
            // null fails the insert outright.
            venueName = log.venueName
            city = log.city
            country = log.country
            attendanceDate = log.attendanceDate
            performanceTime = log.performanceTime
            overallRating = log.overallRating
            musicRating = log.musicRating
            performanceRating = log.performanceRating
            productionRating = log.productionRating
            notes = log.notes
            tags = log.tags
            photos = log.photos
            ticketImageUrl = log.ticketImageURL
        }
    }

    func createAttendanceLog(_ log: AttendanceLog) async throws -> AttendanceLog {
        let userId = try await currentUserId()
        let rows = try await neon.post(
            "attendance_logs", body: [LogPayload(log, userId: userId)], as: [LogRow].self)
        guard let row = rows.first else {
            throw NeonError.api(status: 500, code: nil, message: "The log was not saved.")
        }
        return row.asAttendanceLog()
    }

    func updateAttendanceLog(_ log: AttendanceLog) async throws -> AttendanceLog {
        let userId = try await currentUserId()
        let rows = try await neon.patch(
            "attendance_logs",
            query: "id=eq.\(log.id)&select=\(Self.logSelect)",
            body: LogPayload(log, userId: userId),
            as: [LogRow].self)
        guard let row = rows.first else {
            throw NeonError.api(status: 404, code: nil, message: "That log no longer exists.")
        }
        return row.asAttendanceLog()
    }

    func deleteAttendanceLog(id: String) async throws {
        try await neon.delete("attendance_logs", query: "id=eq.\(id)")
    }

    // MARK: - Recommendations
    //
    // Previously assembled from OpenOpus popularity. With our own catalogue
    // there is nothing yet that deserves the name, so this returns works the
    // user has not already logged or listed -- honest, and useful -- rather
    // than pretending to a recommender that does not exist.

    func fetchRecommendations(limit: Int = 10) async throws -> [Recommendation] {
        let seen = Set(try await fetchAttendanceLogs().map(\.operaId))
        let listed = Set(try await fetchUserLists().flatMap { $0.items }.map(\.operaId))
        let known = seen.union(listed)

        let candidates = try await fetchPopularOperas(limit: limit + known.count)
        return candidates
            .filter { !known.contains($0.id) }
            .prefix(limit)
            .map { opera in
                Recommendation(
                    id: UUID().uuidString,
                    type: .opera,
                    title: opera.title,
                    subtitle: opera.composerAndYear,
                    description: opera.synopsis,
                    imageURL: opera.imageURL,
                    reason: "In the catalogue, and not yet on your lists",
                    // referenceId is the opera's id, so feedback and the tap
                    // target both resolve to the same work.
                    referenceId: opera.id,
                    referenceType: .opera,
                    score: 0,
                    createdAt: Date())
            }
    }

    func updateRecommendationFeedback(id: String, liked: Bool) async throws {
        struct Feedback: Encodable {
            let userId: String
            let referenceId: String
            let referenceType: String
            let liked: Bool
        }
        let userId = try await currentUserId()
        _ = try await neon.post(
            "recommendation_feedback",
            body: [Feedback(userId: userId, referenceId: id,
                            referenceType: "opera", liked: liked)],
            as: [EmptyResponse].self,
            returnRepresentation: false)
    }

    // MARK: - Photos

    /// Not wired up yet.
    ///
    /// Supabase Storage is gone and Neon Object Storage replaces it, but
    /// uploading needs a presigned URL, and presigning needs a credential
    /// that must not ship inside the app. That is a small server-side piece
    /// (a Neon Function) which does not exist yet. Throwing here is
    /// deliberate: it keeps the ticket-scanning flow honest instead of
    /// appearing to save a photo that goes nowhere.
    func uploadTicketPhoto(imageData: Data) async throws -> String {
        throw NeonError.api(
            status: 501, code: nil,
            message: "Photo upload is not available in this build yet.")
    }

    // MARK: - Helpers

    /// The signed-in user's id, read from the JWT rather than from a
    /// round-trip: it is already in the token the request will carry.
    private func currentUserId() async throws -> String {
        let jwt = try await neon.jwt()
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { throw NeonError.notSignedIn }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard
            let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sub = json["sub"] as? String
        else { throw NeonError.notSignedIn }
        return sub
    }

    /// PostgREST treats these as pattern and list syntax inside a filter, so
    /// a search for "Don Giovanni, K. 527" must not be read as two values.
    private static func escape(_ term: String) -> String {
        term.replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: ",", with: "")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
    }
}
