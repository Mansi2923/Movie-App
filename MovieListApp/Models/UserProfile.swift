import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String
    var username: String
    var email: String
    var profileImageURL: URL?
    var bio: String?
    var joinDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case profileImageURL = "profile_image_url"
        case bio
        case joinDate = "join_date"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        profileImageURL = try container.decodeIfPresent(URL.self, forKey: .profileImageURL)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        
        // Handle date decoding
        let dateString = try container.decode(String.self, forKey: .joinDate)
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            joinDate = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .joinDate, in: container, debugDescription: "Date string does not match format")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encodeIfPresent(bio, forKey: .bio)
        
        // Handle date encoding
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: joinDate)
        try container.encode(dateString, forKey: .joinDate)
    }
}

struct UserMovieData: Codable {
    var isFavorite: Bool
    var watchStatus: WatchStatus
    var rating: Int?
    var review: String?
    var lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case isFavorite = "is_favorite"
        case watchStatus = "watch_status"
        case rating
        case review
        case lastUpdated = "last_updated"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        watchStatus = try container.decode(WatchStatus.self, forKey: .watchStatus)
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        review = try container.decodeIfPresent(String.self, forKey: .review)
        
        // Handle date decoding
        let dateString = try container.decode(String.self, forKey: .lastUpdated)
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            lastUpdated = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .lastUpdated, in: container, debugDescription: "Date string does not match format")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(watchStatus, forKey: .watchStatus)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(review, forKey: .review)
        
        // Handle date encoding
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: lastUpdated)
        try container.encode(dateString, forKey: .lastUpdated)
    }
} 