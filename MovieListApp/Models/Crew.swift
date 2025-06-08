import Foundation

struct Crew: Identifiable, Codable {
    let id: Int
    let name: String
    let job: String
    let department: String
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case job
        case department
        case profilePath = "profile_path"
    }
} 