//
//  MovieDetailView.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//

import SwiftUI
import AVKit

struct MovieDetailView: View {
    let movie: Movie
    @StateObject private var viewModel: MovieDetailViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showingReviewSheet = false
    @State private var showingTrailer = false
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    init(movie: Movie) {
        self.movie = movie
        _viewModel = StateObject(wrappedValue: MovieDetailViewModel(movie: movie))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Large poster image at the top, centered
                if let posterURL = MovieService.shared.getPosterURL(path: movie.posterPath, size: .large) {
                    AsyncImage(url: posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 260, maxHeight: 390)
                            .cornerRadius(20)
                            .shadow(radius: 12)
                            .padding(.top, 32)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                            .frame(width: 260, height: 390)
                            .cornerRadius(20)
                            .padding(.top, 32)
                    }
                }

                // Card with shadow for details
                VStack(alignment: .leading, spacing: 24) {
                    // Title and rating
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(movie.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                                .lineLimit(3)
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", movie.voteAverage ?? 0.0))
                                    .foregroundColor(.gray)
                                    .font(.headline)
                                if let releaseDate = movie.releaseDate {
                                    Text("•")
                                        .foregroundColor(.gray)
                                    Text(movie.formatReleaseDate())
                                        .foregroundColor(.gray)
                                }
                                if let runtime = movie.runtime {
                                    Text("•")
                                        .foregroundColor(.gray)
                                    Text("\(runtime) min")
                                        .foregroundColor(.gray)
                                }
                            }
                            .font(.subheadline)
                        }
                        Spacer()
                    }
                    // Genres
                    if let genres = movie.genres, !genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(genres) { genre in
                                    Text(genre.name)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                    Divider()
                    // Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overview")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                        if movie.overview.isEmpty {
                            Text("No overview available.")
                                .foregroundColor(.secondary)
                        } else {
                            Text(movie.overview)
                                .font(.body)
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                        }
                    }
                    Divider()
                    // Action buttons
                    actionButtons
                    // Tabs (cast, similar, reviews, etc.)
                    tabView
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
                )
                .padding(.horizontal, 16)
                .padding(.top, -32)
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewModel.toggleFavorite() }) {
                        Label(viewModel.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                              systemImage: viewModel.isFavorite ? "heart.slash" : "heart")
                    }
                    
                    Button(action: { showingReviewSheet = true }) {
                        Label("Write a Review", systemImage: "pencil")
                    }
                    
                    Button(action: { viewModel.shareMovie() }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                }
            }
        }
        .sheet(isPresented: $showingReviewSheet) {
            ReviewSheet(movie: movie, onDismiss: {
                viewModel.loadMovieDetails()
            })
        }
        .sheet(isPresented: $showingTrailer) {
            if let trailerURL = viewModel.trailerURL {
                VideoPlayer(player: AVPlayer(url: trailerURL))
            }
        }
        .onAppear {
            viewModel.loadMovieDetails()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Watch status button
            Menu {
                ForEach(WatchStatus.allCases, id: \.self) { status in
                    Button(action: { viewModel.updateWatchStatus(status) }) {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: viewModel.watchStatus.icon)
                    Text(viewModel.watchStatus.rawValue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Trailer button
            if viewModel.trailerURL != nil {
                Button(action: { showingTrailer = true }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Trailer")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var tabView: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack {
                ForEach(["Overview", "Cast", "Similar"], id: \.self) { tab in
                    Button(action: { 
                        withAnimation {
                            selectedTab = ["Overview", "Cast", "Similar"].firstIndex(of: tab) ?? 0
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(tab)
                                .fontWeight(selectedTab == ["Overview", "Cast", "Similar"].firstIndex(of: tab) ? .bold : .regular)
                                .foregroundColor(selectedTab == ["Overview", "Cast", "Similar"].firstIndex(of: tab) ? .blue : .gray)
                            Rectangle()
                                .fill(selectedTab == ["Overview", "Cast", "Similar"].firstIndex(of: tab) ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical)

            // Tab content
            TabView(selection: $selectedTab) {
                overviewTab
                    .tag(0)
                castTab
                    .tag(1)
                similarMoviesTab
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: 400)
        }
    }
    
    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Overview")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            
            if movie.overview.isEmpty {
                Text("No overview available.")
                    .foregroundColor(.secondary)
            } else {
                Text(movie.overview)
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
            
            if let userRating = viewModel.userRating {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Rating")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= userRating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    if let review = viewModel.userReview {
                        Text(review)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            // Reviews Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Reviews")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    Spacer()
                    Button(action: { showingReviewSheet = true }) {
                        Label("Write a Review", systemImage: "square.and.pencil")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                
                ReviewView(movieId: movie.id)
            }
            .padding(.top)
        }
    }
    
    private var similarMoviesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Similar Movies")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if viewModel.similarMovies.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No similar movies found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(viewModel.similarMovies) { movie in
                            NavigationLink(destination: MovieDetailView(movie: movie)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    AsyncImage(url: MovieService.shared.getPosterURL(path: movie.posterPath)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 120, height: 180)
                                    .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(movie.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .frame(width: 120)
                                        
                                        if let rating = movie.voteAverage {
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(.yellow)
                                                    .font(.system(size: 10))
                                                Text(String(format: "%.1f", rating))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var castTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cast & Crew")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if viewModel.cast.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No cast information available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(viewModel.cast.prefix(10)) { person in
                            VStack(alignment: .leading, spacing: 8) {
                                AsyncImage(url: MovieService.shared.getPosterURL(path: person.profilePath)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 100, height: 150)
                                .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 100)
                                    
                                    Text(person.character)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 100)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ReviewSheet: View {
    let movie: Movie
    let onDismiss: () -> Void
    @State private var rating = 3
    @State private var review = ""
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isReviewFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 16) {
                        Text("How would you rate this movie?")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                        
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(.yellow)
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            rating = index
                                        }
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Your Review")) {
                    TextEditor(text: $review)
                        .frame(minHeight: 120)
                        .focused($isReviewFocused)
                        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .navigationTitle("Write a Review")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isReviewFocused = false
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Post") {
                    isReviewFocused = false
                    let newReview = Review(
                        movieId: movie.id,
                        userId: UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString,
                        username: UserDefaults.standard.string(forKey: "username") ?? "Anonymous",
                        rating: Double(rating),
                        comment: review
                    )
                    ReviewService.shared.saveReview(newReview)
                    presentationMode.wrappedValue.dismiss()
                    onDismiss()
                }
                .disabled(review.isEmpty)
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isReviewFocused = true
                }
            }
        }
    }
}

// MARK: - Extensions

extension WatchStatus {
    var icon: String {
        switch self {
        case .wantToWatch: return "bookmark"
        case .watching: return "play.fill"
        case .watched: return "checkmark"
        }
    }
}
