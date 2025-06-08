import SwiftUI

struct FavoriteMoviesView: View {
    @StateObject private var viewModel = MovieListViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color(colorScheme == .dark ? .black : .systemGray6)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.favorites.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Favorite Movies")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Add movies to your favorites to see them here")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.favorites) { movie in
                            NavigationLink(destination: MovieDetailView(movie: movie)) {
                                MovieCardLarge(movie: movie)
                                    .padding(.horizontal)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    // Refresh favorites
                    await viewModel.loadFavorites()
                }
            }
        }
        .navigationTitle("Favorites")
        .task {
            // Load favorites when view appears
            await viewModel.loadFavorites()
        }
    }
}

// MARK: - Preview Provider
struct FavoriteMoviesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FavoriteMoviesView()
        }
    }
} 