//
//  MovieViewModel.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class MovieViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedMovie: Movie?
    @Published var searchResults: [Movie] = []
    @Published var isSearching = false
    @Published var watchlist: [Movie] = []
    @Published var favorites: [Movie] = []
    @Published var recentlyViewed: [Movie] = []
    @Published var userPreferences: UserPreferences?
    @Published var customLists: [CustomList] = []
    @Published var deepSeekRecommendation: String?
    @Published var isLoadingRecommendation: Bool = false
    
    private let movieService = MovieService.shared
    private let db = Firestore.firestore()
    private var searchWorkItem: DispatchWorkItem?
    private var currentPage = 1
    private var totalPages = 1
    private var isLoadingMore = false
    
    init() {
        loadUserPreferences()
        loadCustomLists()
    }
    
    // MARK: - Movie Loading
    
    func loadMovies() {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        Task {
            do {
                let (movies, totalPages) = try await movieService.fetchMovies(filter: .popular, page: currentPage)
                await MainActor.run {
                    self.movies = movies
                    self.totalPages = totalPages
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    // Clear movies on error to show error state
                    self.movies = []
                }
            }
        }
    }
    
    func loadMoreMovies() {
        guard !isLoadingMore, currentPage < totalPages else { return }
        isLoadingMore = true
        
        Task {
            do {
                let (newMovies, _) = try await movieService.fetchMovies(filter: .popular, page: currentPage + 1)
                await MainActor.run {
                    self.movies.append(contentsOf: newMovies)
                    self.currentPage += 1
                    self.isLoadingMore = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    // MARK: - Search
    
    func searchMovies(query: String) {
        searchWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !query.isEmpty else {
                self?.searchResults = []
                self?.isSearching = false
                return
            }
            
            Task {
                do {
                    let results = try await self.movieService.searchMovies(query: query)
                    await MainActor.run {
                        self.searchResults = results
                        self.isSearching = false
                    }
                } catch {
                    await MainActor.run {
                        self.error = error
                        self.isSearching = false
                    }
                }
            }
        }
        
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        isSearching = true
    }
    
    // MARK: - Movie Details
    
    func loadMovieDetails(for movie: Movie) {
        Task {
            do {
                let details = try await movieService.fetchMovieDetails(id: movie.id)
                await MainActor.run {
                    if let index = self.movies.firstIndex(where: { $0.id == movie.id }) {
                        self.movies[index].extendedDetails = details
                    }
                    if let index = self.searchResults.firstIndex(where: { $0.id == movie.id }) {
                        self.searchResults[index].extendedDetails = details
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    // MARK: - User Data
    
    func updateWatchStatus(_ status: WatchStatus, for movie: Movie) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let userData = MovieUserData(
            status: status,
            userRating: movie.userData?.userRating,
            userReview: movie.userData?.userReview,
            isFavorite: movie.userData?.isFavorite,
            customLists: movie.userData?.customLists,
            lastUpdated: Date().ISO8601Format()
        )
        
        do {
            try db.collection("users").document(userId)
                .collection("movies").document(String(movie.id))
                .setData(from: userData)
            
            if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                movies[index].userData = userData
            }
        } catch {
            self.error = error
        }
    }
    
    func updateUserRating(_ rating: Int, for movie: Movie) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var userData = movie.userData ?? MovieUserData()
        userData.userRating = rating
        userData.lastUpdated = Date().ISO8601Format()
        
        do {
            try db.collection("users").document(userId)
                .collection("movies").document(String(movie.id))
                .setData(from: userData)
            
            if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                movies[index].userData = userData
            }
        } catch {
            self.error = error
        }
    }
    
    func updateUserReview(_ review: String, for movie: Movie) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var userData = movie.userData ?? MovieUserData()
        userData.userReview = review
        userData.lastUpdated = Date().ISO8601Format()
        
        do {
            try db.collection("users").document(userId)
                .collection("movies").document(String(movie.id))
                .setData(from: userData)
            
            if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                movies[index].userData = userData
            }
        } catch {
            self.error = error
        }
    }
    
    func toggleFavorite(for movie: Movie) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        var userData = movie.userData ?? MovieUserData()
        userData.isFavorite = !(userData.isFavorite ?? false)
        userData.lastUpdated = Date().ISO8601Format()

        do {
            try db.collection("users").document(userId)
                .collection("movies").document(String(movie.id))
                .setData(from: userData)

            if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                movies[index].userData = userData
            }

            if userData.isFavorite ?? false {
                Task { try? await FirebaseManager.shared.addFavoriteMovie(movieId: movie.id) }
                favorites.append(movie)
            } else {
                Task { try? await FirebaseManager.shared.removeFavoriteMovie(movieId: movie.id) }
                favorites.removeAll { $0.id == movie.id }
            }
        } catch {
            self.error = error
        }
    }
    
    // MARK: - User Preferences
    
    func loadUserPreferences() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId)
            .collection("preferences").document("settings")
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.error = error
                        return
                    }
                    if let data = snapshot?.data(),
                       let preferences = try? Firestore.Decoder().decode(UserPreferences.self, from: data) {
                        self?.userPreferences = preferences
                    }
                }
            }
    }
    
    @MainActor
    func loadFavorites() {
        Task {
            do {
                let favoriteIds = try await FirebaseManager.shared.getFavoriteMovies()
                var favoriteMovies: [Movie] = []
                for id in favoriteIds {
                    do {
                        let movie = try await movieService.fetchMovie(id: id)
                        favoriteMovies.append(movie)
                    } catch {
                        print("Failed to fetch favorite movie id \(id): \(error)")
                    }
                }
                self.favorites = favoriteMovies
            } catch {
                print("Error fetching favorite IDs: \(error)")
                self.error = error
            }
        }
    }
    
    func updateUserPreferences(_ preferences: UserPreferences) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try db.collection("users").document(userId)
                .collection("preferences").document("settings")
                .setData(from: preferences)
            
            self.userPreferences = preferences
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Custom Lists
    
    private func loadCustomLists() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId)
            .collection("lists")
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.error = error
                        return
                    }
                    self?.customLists = snapshot?.documents.compactMap { document in
                        try? document.data(as: CustomList.self)
                    } ?? []
                }
            }
    }
    
    func createCustomList(name: String, description: String, isPublic: Bool) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let list = CustomList(
            name: name,
            description: description,
            movies: [],
            isPublic: isPublic,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: userId
        )
        
        do {
            try db.collection("users").document(userId)
                .collection("lists")
                .addDocument(from: list)
        } catch {
            self.error = error
        }
    }
    
    func addMovieToCustomList(_ movie: Movie, listId: String) {
        guard let userId = Auth.auth().currentUser?.uid,
              let list = customLists.first(where: { $0.id == listId }) else { return }
        
        var updatedList = list
        updatedList.movies.append(String(movie.id))
        updatedList.updatedAt = Date()
        
        do {
            try db.collection("users").document(userId)
                .collection("lists").document(listId)
                .setData(from: updatedList)
        } catch {
            self.error = error
        }
    }
    
    func removeMovieFromCustomList(_ movie: Movie, listId: String) {
        guard let userId = Auth.auth().currentUser?.uid,
              let list = customLists.first(where: { $0.id == listId }) else { return }
        
        var updatedList = list
        updatedList.movies.removeAll { $0 == String(movie.id) }
        updatedList.updatedAt = Date()
        
        do {
            try db.collection("users").document(userId)
                .collection("lists").document(listId)
                .setData(from: updatedList)
        } catch {
            self.error = error
        }
    }
    
    func fetchDeepSeekRecommendation() {
        isLoadingRecommendation = true
        let watchedTitles = movies.map { $0.title }
        DeepSeekService.shared.getMovieRecommendation(watchedMovies: watchedTitles) { [weak self] recommendation in
            DispatchQueue.main.async {
                self?.deepSeekRecommendation = recommendation
                self?.isLoadingRecommendation = false
            }
        }
    }
}
