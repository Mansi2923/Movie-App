import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

class MovieDetailViewModel: ObservableObject {
    private var movie: Movie
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isFavorite = false
    @Published var watchStatus: WatchStatus = .wantToWatch
    @Published var userRating: Int?
    @Published var userReview: String?
    @Published var trailerURL: URL?
    @Published var similarMovies: [Movie] = []
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var cast: [CastMember] = []
    @Published var crew: [CrewMember] = []
    
    init(movie: Movie) {
        self.movie = movie
        loadUserProfile()
    }
    
    func loadMovieDetails() {
        isLoading = true
        error = nil
        
        // Load movie details
        MovieService.shared.fetchMovieDetails(id: String(movie.id))
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] updatedMovie in
                self?.updateMovieDetails(updatedMovie)
            })
            .store(in: &cancellables)
        
        // Load similar movies
        MovieService.shared.fetchSimilarMovies(movieId: movie.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                if case .failure(let error) = completion {
                }
            }, receiveValue: { [weak self] movies in
                self?.similarMovies = movies
            })
            .store(in: &cancellables)
    }
    
    private func loadUserProfile() {
        UserService.shared.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] profile in
                self?.userProfile = profile
                self?.loadUserMovieData()
            })
            .store(in: &cancellables)
    }
    
    private func loadUserMovieData() {
        guard let userId = userProfile?.id else { return }
        
        UserService.shared.getUserMovieData(userId: userId, movieId: movie.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] movieData in
                self?.isFavorite = movieData.isFavorite
                self?.watchStatus = movieData.watchStatus
                self?.userRating = movieData.rating
                self?.userReview = movieData.review
            })
            .store(in: &cancellables)
    }
    
    private func updateMovieDetails(_ updatedMovie: Movie) {
        self.movie = updatedMovie
        
        // Update cast and crew
        if let credits = updatedMovie.extendedDetails?.credits {
            self.cast = credits.cast
            self.crew = credits.crew
        }
        
        // Update trailer URL
        if let videos = updatedMovie.extendedDetails?.videos,
           let trailer = videos.results.first(where: { $0.type == "Trailer" && $0.site == "YouTube" }) {
            self.trailerURL = URL(string: "https://www.youtube.com/watch?v=\(trailer.key)")
        }
        
        // Load user data
        loadUserMovieData()
    }
    
    func toggleFavorite() {
        guard let userId = userProfile?.id else { return }
        
        UserService.shared.toggleFavorite(userId: userId, movieId: movie.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] isFavorite in
                self?.isFavorite = isFavorite
            })
            .store(in: &cancellables)
    }
    
    func updateWatchStatus(_ status: WatchStatus) {
        guard let userId = userProfile?.id else { return }
        
        UserService.shared.updateWatchStatus(userId: userId, movieId: movie.id, status: status)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] newStatus in
                self?.watchStatus = newStatus
            })
            .store(in: &cancellables)
    }
    
    func shareMovie() {
        guard let url = URL(string: "https://www.themoviedb.org/movie/\(movie.id)") else { return }
        let activityVC = UIActivityViewController(activityItems: [movie.title, url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func cleanup() {
        cancellables.removeAll()
    }
} 