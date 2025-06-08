//
//  MovieListAppApp.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//
import SwiftUI
import FirebaseCore
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure URL cache
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB
        let diskCapacity = 100 * 1024 * 1024 // 100 MB
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, directory: nil)
        URLCache.shared = cache
        
        return true
    }
}

@main
struct MovieListAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some Scene {
        WindowGroup {
            if firebaseManager.currentUser != nil {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
