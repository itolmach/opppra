//
//  Search.swift
//  OperaApp
//
//  SearchResult and SearchFilters.
//
//  Both were referenced throughout -- by SearchView, by SearchViewModel and
//  by APIService.search -- but neither was ever defined, so the project could
//  not compile. They are declared here to match exactly how the views already
//  use them: a result shows a title, a subtitle and an icon chosen from its
//  type, and the filter sheet only ever constructs an empty SearchFilters and
//  resets to one.
//

import Foundation

struct SearchResult: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    /// Drives the row icon. The payload is carried so a tapped result can
    /// open the right detail screen without a second fetch.
    let type: SearchResultType

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension SearchResult {
    init(opera: Opera) {
        self.init(
            id: opera.id,
            title: opera.title,
            // Composer and premiere year, which is what distinguishes the
            // two La bohèmes -- Leoncavallo's and Puccini's -- in a list.
            subtitle: opera.composerAndYear,
            type: .opera(opera))
    }

    /// The opera a result stands for, when it is one.
    var opera: Opera? {
        if case let .opera(opera) = type { return opera }
        return nil
    }
}

/// Narrowing options for a search.
///
/// Empty means "no narrowing", which is what the UI currently offers: the
/// filter sheet's sections are still placeholders. The fields exist so the
/// view can be filled in without changing APIService's signature.
struct SearchFilters: Equatable {
    var era: String?
    var language: String?
    var composer: String?

    init(era: String? = nil, language: String? = nil, composer: String? = nil) {
        self.era = era
        self.language = language
        self.composer = composer
    }

    var isEmpty: Bool { era == nil && language == nil && composer == nil }
}
