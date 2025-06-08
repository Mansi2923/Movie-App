import SwiftUI

struct MovieRow: View {
    let movie: Movie
    
    var body: some View {
        HStack(spacing: 12) {
            // Movie Poster
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
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 90)
            .cornerRadius(8)
            .clipped()
            
            // Movie Info
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let rating = movie.voteAverage {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                    }
                    .font(.subheadline)
                }
                
                Text(movie.formatReleaseDate())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview Provider
struct MovieRow_Previews: PreviewProvider {
    static var previews: some View {
        MovieRow(movie: Movie(
            id: 1,
            title: "Sample Movie",
            overview: "Sample overview",
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "2024-03-15",
            voteAverage: 8.5,
            voteCount: 100,
            genreIds: nil,
            genres: nil,
            runtime: 120,
            userData: nil
        ))
        .previewLayout(.sizeThatFits)
        .padding()
    }
} 