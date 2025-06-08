import Foundation
import Combine
import FirebaseFirestore

class MovieService: ObservableObject {
    static let shared = MovieService()
    private let db = Firestore.firestore()
    let baseURL = "https://api.themoviedb.org/3"
    let imageBaseURL = "https://image.tmdb.org/t/p"
    // MovieService.swift
    private let bearerToken = Config.bearerToken
    let tmdbApiKey = Config.tmdbApiKey
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private var retryCount = 0
    private let maxRetries = 3
    
    private init() {}
    
    // MARK: - Movie Fetching
    
    func fetchMovieDetails(id: String) -> AnyPublisher<Movie, Error> {
        guard let url = URL(string: "\(baseURL)/movie/\(id)?append_to_response=videos,credits") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                
                return data
            }
            .decode(type: Movie.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .mapError { error in
                return error
            }
            .eraseToAnyPublisher()
    }
    
    func fetchSimilarMovies(movieId: Int) -> AnyPublisher<[Movie], Error> {
        guard let url = URL(string: "\(baseURL)/movie/\(movieId)/similar") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                
                return data
            }
            .decode(type: MovieResponse.self, decoder: JSONDecoder())
            .map { $0.results }
            .receive(on: DispatchQueue.main)
            .mapError { error in
                return error
            }
            .eraseToAnyPublisher()
    }
    
    func fetchMovies(filter: MovieFilter) -> AnyPublisher<[Movie], Error> {
        guard let url = URL(string: "\(baseURL)\(filter.path)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                
                return data
            }
            .decode(type: MovieResponse.self, decoder: JSONDecoder())
            .map(\.results)
            .receive(on: DispatchQueue.main)
            .mapError { error in
                return error
            }
            .eraseToAnyPublisher()
    }
    
    func fetchMovies(filter: MovieFilter, page: Int = 1) async throws -> ([Movie], Int) {
        let url = URL(string: "\(baseURL)\(filter.path)?api_key=\(tmdbApiKey)&page=\(page)")!
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            let decoder = JSONDecoder()
            let result = try decoder.decode(MovieResponse.self, from: data)
            return (result.results, result.totalPages)
        } catch {
            if retryCount < maxRetries {
                retryCount += 1
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
                return try await fetchMovies(filter: filter, page: page)
            }
            retryCount = 0
            throw error
        }
    }
    
    func searchMovies(query: String) async throws -> [Movie] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw NetworkError.noData
        }
        let encodedQuery = trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "\(baseURL)/search/movie?api_key=\(tmdbApiKey)&query=\(encodedQuery)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MovieResponse.self, from: data)
        return response.results
    }
    
    func fetchMovieDetails(id: Int) async throws -> ExtendedDetails {
        let url = URL(string: "\(baseURL)/movie/\(id)?api_key=\(tmdbApiKey)&append_to_response=credits,videos,similar")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let detailsResponse = try decoder.decode(MovieDetailsResponse.self, from: data)
            return detailsResponse.extendedDetails
        } catch {
            if retryCount < maxRetries {
                retryCount += 1
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
                return try await fetchMovieDetails(id: id)
            }
            retryCount = 0
            throw error
        }
    }
    
    func fetchMovie(id: Int) async throws -> Movie {
        let url = URL(string: "\(baseURL)/movie/\(id)?api_key=\(tmdbApiKey)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        let decoder = JSONDecoder()
        return try decoder.decode(Movie.self, from: data)
    }
    
    // MARK: - User Movie Management
    
    func updateMovieStatus(movieId: String, status: WatchStatus) {
        guard let userId = FirebaseManager.shared.currentUser?.uid else { return }
        
        DispatchQueue.main.async {
            self.db.collection("users").document(userId)
                .collection("movies").document(movieId)
                .setData([
                    "status": status.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error = error {
                        print("Error updating movie status: \(error.localizedDescription)")
                    }
                }
        }
    }
    
    func addMovieReview(movieId: String, rating: Int, review: String) {
        guard let userId = FirebaseManager.shared.currentUser?.uid else { return }
        
        DispatchQueue.main.async {
            self.db.collection("users").document(userId)
                .collection("movies").document(movieId)
                .updateData([
                    "userRating": rating,
                    "userReview": review,
                    "lastUpdated": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        print("Error adding movie review: \(error.localizedDescription)")
                    }
                }
        }
    }
    
    // MARK: - Custom Lists
    
    func createCustomList(name: String, description: String, isPublic: Bool) -> AnyPublisher<CustomList, Error> {
        guard let userId = FirebaseManager.shared.currentUser?.uid else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
                .eraseToAnyPublisher()
        }
        
        let list = CustomList(
            name: name,
            description: description,
            movies: [],
            isPublic: isPublic,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: userId
        )
        
        return Future<CustomList, Error> { promise in
            DispatchQueue.main.async {
                do {
                    let _ = try self.db.collection("lists").addDocument(from: list)
                    promise(.success(list))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Image Loading
    
    func getPosterURL(path: String?, size: ImageSize = .medium) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
    }
    
    // MARK: - Enums
    
    enum MovieFilter {
        case nowPlaying
        case popular
        case topRated
        case upcoming
        case similar(id: Int)
        
        var path: String {
            switch self {
            case .popular:
                return "/movie/popular"
            case .topRated:
                return "/movie/top_rated"
            case .upcoming:
                return "/movie/upcoming"
            case .nowPlaying:
                return "/movie/now_playing"
            case .similar(let id):
                return "/movie/\(id)/similar"
            }
        }
    }
    
    enum ImageSize: String {
        case small = "w185"
        case medium = "w342"
        case large = "w500"
        case original = "original"
    }
}

// MARK: - Response Models

struct MovieResponse: Codable {
    let page: Int
    let results: [Movie]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct MovieDetailsResponse: Codable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double?
    let runtime: Int?
    let genres: [Genre]?
    let credits: Credits?
    let videos: Videos?
    let similar: MovieResponse?
    
    var extendedDetails: ExtendedDetails {
        ExtendedDetails(
            credits: credits,
            videos: videos,
            similarMovies: similar?.results
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case runtime
        case genres
        case credits
        case videos
        case similar
    }
}

enum NetworkError: Error {
    case invalidResponse
    case serverError(statusCode: Int)
    case noData
    case decodingError
}

enum ImageSize: String {
    case small = "w185"
    case medium = "w342"
    case large = "w500"
    case original = "original"
}

protocol MovieServiceProtocol {
    func fetchMovies(filter: MovieService.MovieFilter, page: Int) async throws -> ([Movie], Int)
    func fetchMovieDetails(id: Int) async throws -> ExtendedDetails
    func searchMovies(query: String) async throws -> [Movie]
}

extension MovieService: MovieServiceProtocol {} 
