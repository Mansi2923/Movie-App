//
//  MovieDetails.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//
import Foundation

struct MovieDetails: Decodable {
    let genres: [Genre]
    let releaseDate: String
    
    struct Genre: Decodable {
        let name: String
    }
    
    enum CodingKeys: String, CodingKey {
        case genres
        case releaseDate = "release_date"
    }
}
