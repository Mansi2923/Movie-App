import XCTest
@testable import MovieListApp

final class MovieServiceTests: XCTestCase {
    var movieService: MovieService!
    
    override func setUp() {
        super.setUp()
        movieService = MovieService.shared
    }
    
    override func tearDown() {
        movieService = nil
        super.tearDown()
    }
    
    // MARK: - Network Tests
    
    func testFetchMoviesSuccess() async throws {
        // When
        let (movies, totalPages) = try await movieService.fetchMovies(page: 1)
        
        // Then
        XCTAssertFalse(movies.isEmpty)
        XCTAssertGreaterThan(totalPages, 0)
        XCTAssertFalse(movieService.isLoading)
        XCTAssertNil(movieService.error)
    }
    
    func testFetchMovieDetailsSuccess() async throws {
        // Given
        let movieId = 550 // Fight Club
        
        // When
        let details = try await movieService.fetchMovieDetails(id: movieId)
        
        // Then
        XCTAssertNotNil(details.credits)
        XCTAssertNotNil(details.videos)
        XCTAssertFalse(movieService.isLoading)
        XCTAssertNil(movieService.error)
    }
    
    func testSearchMoviesSuccess() async throws {
        // Given
        let query = "Inception"
        
        // When
        let movies = try await movieService.searchMovies(query: query)
        
        // Then
        XCTAssertFalse(movies.isEmpty)
        XCTAssertTrue(movies.contains { $0.title.contains(query) })
        XCTAssertFalse(movieService.isLoading)
        XCTAssertNil(movieService.error)
    }
    
    // MARK: - Image URL Tests
    
    func testGetPosterURL() {
        // Given
        let posterPath = "/test-poster.jpg"
        
        // When
        let url = movieService.getPosterURL(path: posterPath)
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains(posterPath) ?? false)
    }
    
    func testGetPosterURLWithNilPath() {
        // When
        let url = movieService.getPosterURL(path: nil)
        
        // Then
        XCTAssertNil(url)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidMovieId() async {
        // Given
        let invalidId = -1
        
        // When/Then
        do {
            _ = try await movieService.fetchMovieDetails(id: invalidId)
            XCTFail("Expected error for invalid movie ID")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }
    
    func testInvalidSearchQuery() async {
        // Given
        let invalidQuery = ""
        
        // When/Then
        do {
            _ = try await movieService.searchMovies(query: invalidQuery)
            XCTFail("Expected error for invalid search query")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetryOnFailure() async {
        // Given
        let mockService = MockMovieService()
        mockService.shouldFail = true
        mockService.retryCount = 0
        
        // When/Then
        do {
            _ = try await mockService.fetchMovies(page: 1)
            XCTFail("Expected error after retries")
        } catch {
            XCTAssertEqual(mockService.retryCount, 3) // Should retry 3 times
        }
    }
} 