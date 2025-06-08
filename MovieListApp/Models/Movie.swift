//
//  Movie.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//
import Foundation
import FirebaseFirestore

// MARK: - Watch Status
enum WatchStatus: String, Codable, CaseIterable {
    case wantToWatch = "Want to Watch"
    case watching = "Watching"
    case watched = "Watched"
}

// MARK: - Base Movie Model
struct Movie: Identifiable, Codable, Hashable, Equatable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String? // TMDB returns as String ("yyyy-MM-dd")
    let voteAverage: Double?
    let voteCount: Int?
    let genreIds: [Int]? // TMDB returns genre_ids as [Int]
    var genres: [Genre]? // For detailed fetches
    let runtime: Int?
    
    // User-specific data
    var userData: MovieUserData?
    
    // Extended details
    var extendedDetails: ExtendedDetails?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
        case genres
        case runtime
        case userData
        case extendedDetails
    }
}

// MARK: - User Data
struct MovieUserData: Codable, Equatable, Hashable {
    var status: WatchStatus?
    var userRating: Int?
    var userReview: String?
    var isFavorite: Bool?
    var customLists: [String]?
    var lastUpdated: String?
}

// MARK: - Movie Details
struct ExtendedDetails: Codable, Equatable, Hashable {
    let credits: Credits?
    let videos: Videos?
    var similarMovies: [Movie]?
}

struct Credits: Codable, Equatable, Hashable {
    let cast: [CastMember]
    let crew: [CrewMember]
}

struct Videos: Codable, Equatable, Hashable {
    let results: [Video]
}

struct Video: Codable, Equatable, Hashable {
    let key: String
    let type: String
    let site: String
}

// MARK: - Genre Model
struct Genre: Identifiable, Codable, Hashable, Equatable {
    let id: Int
    let name: String

    static let allGenres: [Genre] = [
        Genre(id: 28, name: "Action"),
        Genre(id: 12, name: "Adventure"),
        Genre(id: 16, name: "Animation"),
        Genre(id: 35, name: "Comedy"),
        Genre(id: 80, name: "Crime"),
        Genre(id: 99, name: "Documentary"),
        Genre(id: 18, name: "Drama"),
        Genre(id: 10751, name: "Family"),
        Genre(id: 14, name: "Fantasy"),
        Genre(id: 36, name: "History"),
        Genre(id: 27, name: "Horror"),
        Genre(id: 10402, name: "Music"),
        Genre(id: 9648, name: "Mystery"),
        Genre(id: 10749, name: "Romance"),
        Genre(id: 878, name: "Science Fiction"),
        Genre(id: 10770, name: "TV Movie"),
        Genre(id: 53, name: "Thriller"),
        Genre(id: 10752, name: "War"),
        Genre(id: 37, name: "Western")
    ]
}

struct CastMember: Codable, Identifiable, Equatable, Hashable {
    var id: Int
    var name: String
    var character: String
    var profilePath: String?
}

struct CrewMember: Codable, Identifiable, Equatable, Hashable {
    var id: Int
    var name: String
    var job: String
    var department: String
    var profilePath: String?
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    var theme: AppTheme
    var language: String
    var notificationsEnabled: Bool
    var defaultView: ViewType
    var sortPreference: SortPreference
    var accessibilitySettings: AccessibilitySettings
    
    enum AppTheme: String, Codable {
        case light
        case dark
        case system
    }
    
    enum ViewType: String, Codable {
        case grid
        case list
    }
    
    enum SortPreference: String, Codable, CaseIterable {
        case titleAZ
        case titleZA
        case releaseDateNewest
        case releaseDateOldest
        case ratingHighLow
        case ratingLowHigh
        case custom
    }
}

struct AccessibilitySettings: Codable {
    var isDynamicTypeEnabled: Bool
    var isReduceMotionEnabled: Bool
    var isReduceTransparencyEnabled: Bool
    var isVoiceOverEnabled: Bool
}

// MARK: - Custom List
struct CustomList: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var movies: [String] // Movie IDs
    var isPublic: Bool
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String // User ID
}

// MARK: - Movie Extensions
extension Movie {
    func formatReleaseDate() -> String {
        guard let dateString = releaseDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
        return dateString
    }
    
    func getGenreNames() -> [String] {
        return genres?.map { $0.name } ?? []
    }
}

// MARK: - Example for SwiftUI Previews
extension Movie {
    static let example = Movie(
        id: 1,
        title: "Minecraft Movie",
        overview: "A group of misfits find themselves struggling with ordinary problems until they are suddenly pulled through a mysterious portal into the Overworld: a bizarre, cubic wonderland that thrives on imagination. To get back home, they'll have to master this world and face its dangers.",
        posterPath: "/sample.jpg",
        backdropPath: "/sample_backdrop.jpg",
        releaseDate: "2025-03-31",
        voteAverage: 7.8,
        voteCount: 1234,
        genreIds: [12, 16],
        genres: [Genre(id: 12, name: "Adventure"), Genre(id: 16, name: "Animation")],
        runtime: 120,
        userData: nil,
        extendedDetails: nil
    )
}

