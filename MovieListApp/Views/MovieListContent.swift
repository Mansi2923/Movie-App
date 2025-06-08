//
//  MovieListContent.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//
import SwiftUI

struct MovieGridItem: View {
    let movie: Movie
    @EnvironmentObject var movieListViewModel: MovieListViewModel
    
    var body: some View {
        NavigationLink(destination: MovieDetailView(movie: movie)) {
            MovieCardCompact(movie: movie, viewModel: movieListViewModel)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MovieListContent: View {
    @ObservedObject var viewModel: MovieViewModel
    @Binding var selectedFilter: MovieService.MovieFilter
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var movieListViewModel: MovieListViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color(colorScheme == .dark ? .black : .systemGray6)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else if viewModel.movies.isEmpty {
                emptyStateView
            } else {
                movieGridView
            }
        }
        .onChange(of: selectedFilter) { newFilter in
            withAnimation {
                viewModel.loadMovies()
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text("Network Error")
                .font(.title2)
                .foregroundColor(.primary)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: {
                viewModel.loadMovies()
            }) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "film")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Movies Found")
                .font(.title2)
                .foregroundColor(.primary)
            Text("Try changing your filter or check your connection")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var movieGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.movies) { movie in
                    MovieGridItem(movie: movie)
                        .onAppear {
                            if movie.id == viewModel.movies.last?.id {
                                viewModel.loadMoreMovies()
                            }
                        }
                }
            }
            .padding(8)
        }
        .refreshable {
            viewModel.loadMovies()
        }
    }
}

// MARK: - Preview Provider
struct MovieListContent_Previews: PreviewProvider {
    static var previews: some View {
        MovieListContent(
            viewModel: MovieViewModel(),
            selectedFilter: .constant(.popular)
        )
        .environmentObject(MovieListViewModel())
    }
}
