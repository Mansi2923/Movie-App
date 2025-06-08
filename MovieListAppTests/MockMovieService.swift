import Foundation
@testable import MovieListApp

final class MockMovieService: MovieServiceProtocol {
    var mockMovies: [Movie] = []
    var mockMoreMovies: [Movie] = []
    var shouldFail = false
    var retryCount = 0
    var totalPages = 2
    var details: ExtendedDetails = ExtendedDetails(credits: nil, videos: nil, similarMovies: nil)
    var maxRetries = 3
    
    func fetchMovies(page: Int) async throws -> ([Movie], Int) {
        if shouldFail {
            if retryCount < maxRetries {
                retryCount += 1
                throw NetworkError.serverError(statusCode: 500)
            } else {
                retryCount = 0
                throw NetworkError.serverError(statusCode: 500)
            }
        }
        if page == 1 {
            return (mockMovies, totalPages)
        } else {
            return (mockMoreMovies, totalPages)
        }
    }
    
    func fetchMovieDetails(id: Int) async throws -> ExtendedDetails {
        if shouldFail {
            if retryCount < maxRetries {
                retryCount += 1
                throw NetworkError.serverError(statusCode: 500)
            } else {
                retryCount = 0
                throw NetworkError.serverError(statusCode: 500)
            }
        }
        return details
    }
    
    func searchMovies(query: String) async throws -> [Movie] {
        if shouldFail {
            if retryCount < maxRetries {
                retryCount += 1
                throw NetworkError.serverError(statusCode: 500)
            } else {
                retryCount = 0
                throw NetworkError.serverError(statusCode: 500)
            }
        }
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NetworkError.noData
        }
        return mockMovies.filter { $0.title.contains(query) }
    }
} 