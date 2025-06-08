import Foundation

struct Cast: Identifiable, Codable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
    let order: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath = "profile_path"
        case order
    }
} 