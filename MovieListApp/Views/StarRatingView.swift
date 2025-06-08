//
//  StarRatingView.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//
import SwiftUI

struct StarRatingView: View {
    let rating: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                    .foregroundColor(index < Int(rating) ? .yellow : .gray)
                    .font(.subheadline)
            }
        }
    }
}
