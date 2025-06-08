//
//  MovieImagesView.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//
import SwiftUI

struct MovieImagesView: View {
    let movieImages: [String]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(movieImages, id: \.self) { imageURL in
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    } placeholder: {
                        ProgressView()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
