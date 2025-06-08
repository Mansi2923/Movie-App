import Foundation
import Combine
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

class MovieListViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var favorites: [Movie] = []
    @Published var filteredMovies: [Movie] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentPage = 1
    @Published var hasMorePages = true
    @Published var selectedFilter: MovieService.MovieFilter = .popular
    @Published var searchText = ""
    @Published var selectedGenre: Genre?
    @Published var selectedYear: Int?
    @Published var selectedRating: Double?
    @Published var viewType: UserPreferences.ViewType = .grid
    @Published var sortPreference: UserPreferences.SortPreference = .titleAZ
    @Published var deepSeekRecommendation: String?
    @Published var isLoadingRecommendation: Bool = false
    
    private var totalPages = 1
    private var isLoadingMore = false
    private var lastLoadTime: Date?
    private let minimumLoadInterval: TimeInterval = 2.0 // Minimum time between loads
    
    private let movieService: MovieServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    
    init(movieService: MovieServiceProtocol = MovieService.shared) {
        self.movieService = movieService
        setupBindings()
        loadUserPreferences()
        Task {
            await loadFavorites()
        }
    }
    
    private func setupBindings() {
        // Search text binding
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] (_: String) in
                self?.filterMovies()
            }
            .store(in: &cancellables)
        
        // Filter bindings
        Publishers.CombineLatest3($selectedGenre, $selectedYear, $selectedRating)
            .sink { [weak self] _ in
                self?.filterMovies()
            }
            .store(in: &cancellables)
        
        // View type binding
        $viewType
            .sink { [weak self] _ in
                self?.saveUserPreferences()
            }
            .store(in: &cancellables)
        
        // Sort preference binding
        $sortPreference
            .sink { [weak self] _ in
                self?.applySorting()
            }
            .store(in: &cancellables)
    }
    
    func loadMovies(filter: MovieService.MovieFilter = .popular) async {
        // Check if we should skip loading
        if let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < minimumLoadInterval {
            return
        }
        
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let (newMovies, totalPages) = try await movieService.fetchMovies(filter: filter, page: currentPage)
            // Map genreIds to genres if needed
            var mappedMovies = newMovies
            for i in 0..<mappedMovies.count {
                if mappedMovies[i].genres == nil, let ids = mappedMovies[i].genreIds {
                    mappedMovies[i].genres = ids.compactMap { id in
                        Genre.allGenres.first(where: { $0.id == id })
                    }
                }
            }
            await MainActor.run {
                self.movies = mappedMovies
                self.totalPages = totalPages
                self.filterMovies()
                self.isLoading = false
                self.lastLoadTime = Date()
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                self.movies = []
                self.filteredMovies = []
            }
        }
    }
    
    func filterMovies() {
        Task { @MainActor in
            var filtered = movies
            
            // If Now Playing, filter for movies with a release date in the current year and today or later
            if selectedFilter == .nowPlaying {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let thisYear = calendar.component(.year, from: today)
                filtered = filtered.filter { movie in
                    guard let releaseDate = movie.releaseDate,
                          let date = DateFormatter.tmdb.date(from: releaseDate) else { return false }
                    let movieYear = calendar.component(.year, from: date)
                    return movieYear == thisYear && date >= today
                }
            }
            
            // Apply genre filter
            if let genre = selectedGenre {
                filtered = filtered.filter { movie in
                    movie.genres?.contains(where: { $0.id == genre.id }) ?? false
                }
            }
            
            // Apply year filter
            if let year = selectedYear {
                filtered = filtered.filter { movie in
                    guard let releaseDate = movie.releaseDate else { return false }
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let date = formatter.date(from: releaseDate) {
                        let calendar = Calendar.current
                        return calendar.component(.year, from: date) == year
                    }
                    return false
                }
            }
            
            // Apply rating filter
            if let rating = selectedRating {
                filtered = filtered.filter { movie in
                    (movie.voteAverage ?? 0) >= rating
                }
            }
            
            // Apply sorting
            filtered.sort { movie1, movie2 in
                switch sortPreference {
                case .titleAZ:
                    return movie1.title < movie2.title
                case .titleZA:
                    return movie1.title > movie2.title
                case .releaseDateNewest:
                    return (movie1.releaseDate ?? "") > (movie2.releaseDate ?? "")
                case .releaseDateOldest:
                    return (movie1.releaseDate ?? "") < (movie2.releaseDate ?? "")
                case .ratingHighLow:
                    return (movie1.voteAverage ?? 0) > (movie2.voteAverage ?? 0)
                case .ratingLowHigh:
                    return (movie1.voteAverage ?? 0) < (movie2.voteAverage ?? 0)
                case .custom:
                    return false
                }
            }
            
            filteredMovies = filtered
        }
    }
    
    func loadMoreMoviesIfNeeded(currentMovie: Movie) async {
        guard !isLoadingMore,
              currentPage < totalPages,
              let lastMovie = movies.last,
              lastMovie.id == currentMovie.id else {
            return
        }
        
        await MainActor.run {
            isLoadingMore = true
            currentPage += 1
        }
        
        do {
            let (newMovies, _) = try await movieService.fetchMovies(filter: selectedFilter, page: currentPage)
            await MainActor.run {
                self.movies.append(contentsOf: newMovies)
                self.filterMovies()
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoadingMore = false
            }
        }
    }
    
    private func applySorting() {
        Task { @MainActor in
            switch sortPreference {
            case .titleAZ:
                filteredMovies.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .titleZA:
                filteredMovies.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
            case .releaseDateNewest:
                filteredMovies.sort {
                    let date0 = $0.releaseDate.flatMap { dateString in DateFormatter.tmdb.date(from: dateString) } ?? Date.distantPast
                    let date1 = $1.releaseDate.flatMap { dateString in DateFormatter.tmdb.date(from: dateString) } ?? Date.distantPast
                    return date0 > date1
                }
            case .releaseDateOldest:
                filteredMovies.sort {
                    let date0 = $0.releaseDate.flatMap { dateString in DateFormatter.tmdb.date(from: dateString) } ?? Date.distantFuture
                    let date1 = $1.releaseDate.flatMap { dateString in DateFormatter.tmdb.date(from: dateString) } ?? Date.distantFuture
                    return date0 < date1
                }
            case .ratingHighLow:
                filteredMovies.sort { ($0.voteAverage ?? 0.0) > ($1.voteAverage ?? 0.0) }
            case .ratingLowHigh:
                filteredMovies.sort { ($0.voteAverage ?? 0.0) < ($1.voteAverage ?? 0.0) }
            case .custom:
                break
            }
        }
    }
    
    private func loadUserPreferences() {
        if let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            viewType = preferences.defaultView
            sortPreference = preferences.sortPreference
        }
    }
    
    private func saveUserPreferences() {
        let preferences = UserPreferences(
            theme: .system,
            language: Locale.current.languageCode ?? "en",
            notificationsEnabled: true,
            defaultView: viewType,
            sortPreference: sortPreference,
            accessibilitySettings: AccessibilitySettings(
                isDynamicTypeEnabled: true,
                isReduceMotionEnabled: false,
                isReduceTransparencyEnabled: false,
                isVoiceOverEnabled: false
            )
        )
        
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "userPreferences")
        }
    }
    
    private func syncFavoriteState(for movie: Movie) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Get current state from Firestore
        let movieRef = db.collection("users").document(userId)
            .collection("movies").document(String(movie.id))
        let movieDoc = try await movieRef.getDocument()
        
        if let data = try? movieDoc.data().flatMap({ try Firestore.Decoder().decode(MovieUserData.self, from: $0) }) {
            let isFavorite = data.isFavorite ?? false
            await MainActor.run {
                // Update in movies array
                if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                    movies[index].userData = data
                }
                
                // Update in favorites array
                if isFavorite {
                    if !favorites.contains(where: { $0.id == movie.id }) {
                        favorites.append(movie)
                    }
                } else {
                    favorites.removeAll { $0.id == movie.id }
                }
            }
        }
    }

    func toggleFavorite(for movie: Movie) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                // Get current state from Firestore
                let movieRef = db.collection("users").document(userId)
                    .collection("movies").document(String(movie.id))
                let movieDoc = try await movieRef.getDocument()
                
                // Get current state, defaulting to false if not found
                let currentState: Bool
                if let data = try? movieDoc.data().flatMap({ try Firestore.Decoder().decode(MovieUserData.self, from: $0) }) {
                    currentState = data.isFavorite ?? false
                } else {
                    currentState = false
                }
                
                let newState = !currentState
                
                // Create new user data
                var userData = MovieUserData()
                userData.isFavorite = newState
                userData.lastUpdated = Date().ISO8601Format()
                
                // Update Firestore
                try await movieRef.setData(from: userData)
                
                // Update favorites collection
                let favoritesRef = db.collection("users").document(userId)
                    .collection("favorites").document(String(movie.id))
                
                if newState {
                    try await favoritesRef.setData([
                        "movieId": movie.id,
                        "addedAt": Date().ISO8601Format()
                    ])
                } else {
                    try await favoritesRef.delete()
                }
                
                // Update local state immediately
                await MainActor.run {
                    // Update in movies array
                    if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                        movies[index].userData = userData
                    }
                    
                    // Update in favorites array
                    if newState {
                        if !favorites.contains(where: { $0.id == movie.id }) {
                            favorites.append(movie)
                        }
                    } else {
                        favorites.removeAll { $0.id == movie.id }
                    }
                }
                
                // Force sync state
                try await syncFavoriteState(for: movie)
                
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    func loadFavorites() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // First get all favorite IDs
            let favoritesRef = db.collection("users").document(userId).collection("favorites")
            let snapshot = try await favoritesRef.getDocuments()
            
            let favoriteIds = snapshot.documents.compactMap { doc -> Int? in
                return doc.data()["movieId"] as? Int
            }
            
            // Then get all movie documents
            let moviesRef = db.collection("users").document(userId).collection("movies")
            let moviesSnapshot = try await moviesRef.getDocuments()
            
            var newFavorites: [Movie] = []
            
            // For each favorite ID, get the movie data
            for id in favoriteIds {
                // First try to get from local movies array
                if let existingMovie = movies.first(where: { $0.id == id }) {
                    newFavorites.append(existingMovie)
                    continue
                }
                
                // If not in local array, try to get from Firestore
                if let movieDoc = moviesSnapshot.documents.first(where: { $0.documentID == String(id) }) {
                    // Get the movie data from Firestore
                    let userData = try? Firestore.Decoder().decode(MovieUserData.self, from: movieDoc.data())
                    
                    // Create a basic movie object
                    let movie = Movie(
                        id: id,
                        title: movieDoc.data()["title"] as? String ?? "Unknown",
                        overview: movieDoc.data()["overview"] as? String ?? "",
                        posterPath: movieDoc.data()["posterPath"] as? String,
                        backdropPath: movieDoc.data()["backdropPath"] as? String,
                        releaseDate: movieDoc.data()["releaseDate"] as? String,
                        voteAverage: movieDoc.data()["voteAverage"] as? Double,
                        voteCount: movieDoc.data()["voteCount"] as? Int,
                        genreIds: nil,
                        genres: nil,
                        runtime: nil,
                        userData: userData,
                        extendedDetails: nil
                    )
                    newFavorites.append(movie)
                }
            }
            
            // Update the favorites array on the main thread
            await MainActor.run {
                self.favorites = newFavorites
            }
            
            // Sync state for each favorite
            for movie in newFavorites {
                try await syncFavoriteState(for: movie)
            }
            
        } catch {
            await MainActor.run {
                self.error = error
            }
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

extension DateFormatter {
    static let tmdb: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
} 