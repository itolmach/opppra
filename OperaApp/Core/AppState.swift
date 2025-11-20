//
//  AppState.swift
//  OperaApp
//
//  Global app state management
//

import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: TabItem = .home
    @Published var showingSearch = false
    @Published var showingLogFlow = false
    
    // Navigation paths
    @Published var homeNavigationPath = NavigationPath()
    @Published var searchNavigationPath = NavigationPath()
    @Published var listsNavigationPath = NavigationPath()
    @Published var profileNavigationPath = NavigationPath()
    
    enum TabItem: Int {
        case home = 0
        case search = 1
        case lists = 2
        case profile = 3
    }
    
    func navigateToOpera(_ opera: Opera) {
        // Add opera to current tab's navigation path
        switch selectedTab {
        case .home:
            homeNavigationPath.append(opera)
        case .search:
            searchNavigationPath.append(opera)
        case .lists:
            listsNavigationPath.append(opera)
        case .profile:
            profileNavigationPath.append(opera)
        }
    }
    
    func resetNavigation() {
        homeNavigationPath = NavigationPath()
        searchNavigationPath = NavigationPath()
        listsNavigationPath = NavigationPath()
        profileNavigationPath = NavigationPath()
    }
}

