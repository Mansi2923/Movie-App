import Foundation
import Combine

class UserService {
    static let shared = UserService()
    private let baseURL = "https://api.yourbackend.com/users"
    
    private init() {}
    
    func getCurrentUser() -> AnyPublisher<UserProfile, Error> {
        guard let url = URL(string: "\(baseURL)/me") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: UserProfile.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    func getUserMovieData(userId: String, movieId: Int) -> AnyPublisher<UserMovieData, Error> {
        guard let url = URL(string: "\(baseURL)/\(userId)/movies/\(movieId)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: UserMovieData.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    func toggleFavorite(userId: String, movieId: Int) -> AnyPublisher<Bool, Error> {
        guard let url = URL(string: "\(baseURL)/\(userId)/movies/\(movieId)/favorite") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { _ in true }
            .receive(on: DispatchQueue.main)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    func updateWatchStatus(userId: String, movieId: Int, status: WatchStatus) -> AnyPublisher<WatchStatus, Error> {
        guard let url = URL(string: "\(baseURL)/\(userId)/movies/\(movieId)/status") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["status": status.rawValue]
        request.httpBody = try? JSONEncoder().encode(body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { _ in status }
            .receive(on: DispatchQueue.main)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    func updateProfileImage(userId: String, imageData: Data) -> AnyPublisher<URL, Error> {
        guard let url = URL(string: "\(baseURL)/\(userId)/profile-image") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ProfileImageResponse.self, decoder: JSONDecoder())
            .map(\.imageURL)
            .receive(on: DispatchQueue.main)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
}

struct ProfileImageResponse: Codable {
    let imageURL: URL
    
    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
    }
} 