//
//  MainTabView.swift
//  OperaApp
//
//  Main tab navigation container
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppState.TabItem.home)
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(AppState.TabItem.search)
            
            ListsView()
                .tabItem {
                    Label("Lists", systemImage: "list.bullet")
                }
                .tag(AppState.TabItem.lists)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(AppState.TabItem.profile)
        }
        .tint(.white)
        .sheet(isPresented: $appState.showingLogFlow) {
            LogFlowView()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationService.shared)
}

