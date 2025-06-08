import SwiftUI

struct MainTabView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showingProfile = false
    @State private var showingProfileMenu = false
    
    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemGray6 // Change to your preferred color
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
    
    var body: some View {
        TabView {
            NavigationStack {
                MovieListView(defaultFilter: .nowPlaying)
            }
            .tabItem {
                Label("Now Playing", systemImage: "play.circle.fill")
            }
            
            NavigationStack {
                MovieListView(defaultFilter: .topRated)
            }
            .tabItem {
                Label("Top Rated", systemImage: "star.circle.fill")
            }
            
            NavigationStack {
                MovieListView(defaultFilter: .popular)
            }
            .tabItem {
                Label("Popular", systemImage: "flame.circle.fill")
            }
            
            NavigationStack {
                FavoriteMoviesView()
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.circle.fill")
            }
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }
} 