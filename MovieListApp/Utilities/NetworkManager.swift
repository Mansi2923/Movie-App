//
//  NetworkManager.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//
import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private let bearerToken = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI3ZGFjYjc3MWIwMDdlYWY5ZDA0MWI1MTAxMWE0NTdhMCIsIm5iZiI6MTc0MjA2NTkyMi44NTEsInN1YiI6IjY3ZDVkMTAyMDUyNWYzZDc0ZjAxNDM1NyIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.fOE2oixxiAIPA9lXg4RDcG5NTRxM_ZGBK47MzfjppCk" // 
    
    private init() {}
    
    func fetchData(from url: URL, completion: @escaping (Data?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(nil)
                return
            }
            completion(data)
        }.resume()
    }
}
