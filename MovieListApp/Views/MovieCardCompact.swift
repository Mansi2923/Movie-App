import SwiftUI

struct MovieCardCompact: View {
    let movie: Movie
    let viewModel: MovieListViewModel
    @State private var reviews: [Review] = []
    @Environment(\.colorScheme) var colorScheme
    @State private var isFavorite: Bool
    
    init(movie: Movie, viewModel: MovieListViewModel) {
        self.movie = movie
        self.viewModel = viewModel
        self._isFavorite = State(initialValue: movie.userData?.isFavorite ?? false)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                // Movie Poster with Overlay
                ZStack(alignment: .bottom) {
                    AsyncImage(url: MovieService.shared.getPosterURL(path: movie.posterPath)) { phase in
                        switch phase {
                        case .empty:
                            Color.gray.opacity(0.2)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            Image(systemName: "film")
                                .resizable()
                                .scaledToFit()
                                .padding(20)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12, corners: [.topLeft, .topRight])
                    .padding(.top, 8)
                    
                    // Gradient Overlay
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                    .offset(y: 0)
                    
                    // Rating Badge
                    if let releaseDate = movie.releaseDate,
                       let date = DateFormatter.tmdb.date(from: releaseDate),
                       date > Date() {
                        // Unreleased movie
                        HStack(spacing: 4) {
                            Text("Not yet rated")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    } else if let rating = movie.voteAverage {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 12))
                            Text(String(format: "%.1f", rating))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12, corners: [.topLeft, .topRight])
                
                // Heart button overlay
                Button(action: {
                    viewModel.toggleFavorite(for: movie)
                }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .white)
                        .padding(10)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .padding(10)
            }
            
            // Movie Info
            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 4)
                Text(movie.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let releaseDate = movie.releaseDate {
                    Text(movie.formatReleaseDate())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Reviews Preview
                if !reviews.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(reviews.prefix(1)) { review in
                            HStack(spacing: 4) {
                                Text(review.username)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(review.comment)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 4)
            }
            .padding([.horizontal, .bottom], 14)
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
        .onAppear {
            loadReviews()
            isFavorite = movie.userData?.isFavorite ?? false
        }
        .onChange(of: movie.userData?.isFavorite) { newValue in
            isFavorite = newValue ?? false
        }
    }
    
    private func loadReviews() {
        reviews = ReviewService.shared.getReviewsForMovie(movieId: movie.id)
    }
}

// MARK: - Preview Provider
struct MovieCardCompact_Previews: PreviewProvider {
    static var previews: some View {
        MovieCardCompact(movie: Movie.example, viewModel: MovieListViewModel())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

// Add this extension for custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
} 