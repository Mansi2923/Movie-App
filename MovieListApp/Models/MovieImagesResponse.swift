//
//  MovieImagesResponse.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.

import Foundation

struct MovieImagesResponse: Decodable {
    let backdrops: [MovieImage]
    let posters: [MovieImage]
    
    struct MovieImage: Decodable {
        let filePath: String
        
        enum CodingKeys: String, CodingKey {
            case filePath = "file_path"
        }
    }
}
