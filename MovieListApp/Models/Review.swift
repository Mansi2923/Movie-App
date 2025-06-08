import Foundation

struct Review: Identifiable, Codable {
    let id: UUID
    let movieId: Int
    let userId: String
    let username: String
    let rating: Double
    let comment: String
    let timestamp: Date
    
    init(id: UUID = UUID(), movieId: Int, userId: String, username: String, rating: Double, comment: String, timestamp: Date = Date()) {
        self.id = id
        self.movieId = movieId
        self.userId = userId
        self.username = username
        self.rating = rating
        self.comment = comment
        self.timestamp = timestamp
    }
}

// MARK: - Review Service
class ReviewService {
    static let shared = ReviewService()
    private let userDefaults = UserDefaults.standard
    private let reviewsKey = "movie_reviews"
    
    private init() {}
    
    func saveReview(_ review: Review) {
        var reviews = getAllReviews()
        reviews.append(review)
        saveReviews(reviews)
    }
    
    func getReviewsForMovie(movieId: Int) -> [Review] {
        return getAllReviews().filter { $0.movieId == movieId }
    }
    
    func deleteReview(_ review: Review) {
        var reviews = getAllReviews()
        reviews.removeAll { $0.id == review.id }
        saveReviews(reviews)
    }
    
    private func getAllReviews() -> [Review] {
        guard let data = userDefaults.data(forKey: reviewsKey),
              let reviews = try? JSONDecoder().decode([Review].self, from: data) else {
            return []
        }
        return reviews
    }
    
    private func saveReviews(_ reviews: [Review]) {
        if let data = try? JSONEncoder().encode(reviews) {
            userDefaults.set(data, forKey: reviewsKey)
        }
    }
} 