//
//  MovieListView.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//
import SwiftUI

struct MovieListView: View {
    @StateObject private var viewModel: MovieListViewModel
    @State private var selectedFilter: MovieService.MovieFilter
    @State private var showingFilters = false
    @State private var showingSortOptions = false
    @State private var filterSheetPresented = false
    @State private var selectedGenre: Genre?
    @State private var selectedYear: Int?
    @State private var selectedRating: Double?
    @State private var showingRecommendation = false
    @State private var recommendationText: String = ""
    @State private var isLoadingRecommendation = false
    @Environment(\.colorScheme) var colorScheme
    
    init(defaultFilter: MovieService.MovieFilter = .popular) {
        let viewModel = MovieListViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
        _selectedFilter = State(initialValue: defaultFilter)
    }
    
    private func loadMovies() async {
        await MainActor.run {
            Task {
                await viewModel.loadMovies(filter: selectedFilter)
            }
        }
    }
    
    private func handleFilterChange(_ newFilter: MovieService.MovieFilter) {
        withAnimation {
            Task { @MainActor in
                await loadMovies()
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(colorScheme == .dark ? .black : .systemGray6)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    if viewModel.isLoadingRecommendation {
                        ProgressView("Getting AI Recommendation...")
                            .padding()
                    } else if let recommendation = viewModel.deepSeekRecommendation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI Movie Recommendation")
                                .font(.headline)
                            Text(recommendation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    // Recommendation Button
                    Button(action: getRecommendation) {
                        HStack {
                            if isLoadingRecommendation {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Image(systemName: "wand.and.stars")
                            Text("Get Personalized Recommendations")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(viewModel.filteredMovies) { movie in
                                NavigationLink(destination: MovieDetailView(movie: movie)) {
                                    MovieCardCompact(movie: movie, viewModel: viewModel)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .task {
                                    if movie == viewModel.filteredMovies.last {
                                        await viewModel.loadMoreMoviesIfNeeded(currentMovie: movie)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await loadMovies()
                    }
                }
            }
        }
        .navigationTitle("Movies")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { filterSheetPresented = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    Button(action: { showingSortOptions = true }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $filterSheetPresented) {
            ModernFilterSheet(
                genres: Genre.allGenres,
                selectedGenre: $selectedGenre,
                selectedYear: $selectedYear,
                selectedRating: $selectedRating,
                onApply: { genre, year, rating in
                    viewModel.selectedGenre = genre
                    viewModel.selectedYear = year
                    viewModel.selectedRating = rating
                }
            )
        }
        .sheet(isPresented: $showingSortOptions) {
            SortOptionsView(selectedSort: $viewModel.sortPreference)
        }
        .onChange(of: selectedFilter, perform: handleFilterChange)
        .onAppear {
            viewModel.fetchDeepSeekRecommendation()
        }
        .alert(isPresented: $showingRecommendation) {
            Alert(title: Text("AI Movie Recommendation"), message: Text(recommendationText), dismissButton: .default(Text("OK")))
        }
        .task {
            await loadMovies()
        }
    }
    
    private func getRecommendation() {
        isLoadingRecommendation = true
        let watched = viewModel.filteredMovies.filter { $0.userData?.status == .watched }.prefix(5).map { $0.title }
        DeepSeekService.shared.getMovieRecommendation(watchedMovies: watched) { result in
            Task { @MainActor in
                isLoadingRecommendation = false
                recommendationText = result ?? "Sorry, no recommendation available."
                showingRecommendation = true
            }
        }
    }
    
    private func loadSimilarMovies(for movie: Movie) {
        Task {
            do {
                let url = URL(string: "\(MovieService.shared.baseURL)/movie/\(movie.id)/similar?api_key=\(MovieService.shared.tmdbApiKey)")!
                
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(MovieResponse.self, from: data)
                
                await MainActor.run {
                    if let index = viewModel.movies.firstIndex(where: { $0.id == movie.id }) {
                        viewModel.movies[index].extendedDetails?.similarMovies = response.results
                    }
                }
            } catch {
                // Removed: print statement for error loading similar movies.
            }
        }
    }
}

// Large Movie Card
struct MovieCardLarge: View {
    let movie: Movie
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                        .padding(20)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(12)
            .background(Color(.secondarySystemBackground))
            
            // Movie Info
            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .padding(.top, 4)
                
                HStack(spacing: 8) {
                    if let releaseDate = movie.releaseDate,
                       let date = DateFormatter.tmdb.date(from: releaseDate),
                       date > Date() {
                        // Unreleased movie
                        Text("Not yet rated")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if let rating = movie.voteAverage {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 12))
                            Text(String(format: "%.1f", rating))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let releaseDate = movie.releaseDate {
                        Text(movie.formatReleaseDate())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding([.horizontal, .bottom], 12)
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
    }
}

struct FilterView: View {
    @Binding var selectedFilter: MovieService.MovieFilter
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List {
            ForEach(MovieService.MovieFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation {
                        selectedFilter = filter
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack {
                        Text(filter.displayName)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                        Spacer()
                        if filter == selectedFilter {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .navigationTitle("Filter Movies")
        .navigationBarItems(trailing: Button("Done") {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

struct SortOptionsView: View {
    @Binding var selectedSort: UserPreferences.SortPreference
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List {
            ForEach(UserPreferences.SortPreference.allCases, id: \.self) { sort in
                Button(action: {
                    withAnimation {
                        selectedSort = sort
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack {
                        Text(label(for: sort))
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                        Spacer()
                        if selectedSort == sort {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .navigationTitle("Sort By")
        .navigationBarItems(trailing: Button("Done") {
            presentationMode.wrappedValue.dismiss()
        })
    }
    
    private func label(for sort: UserPreferences.SortPreference) -> String {
        switch sort {
        case .titleAZ: return "Title (A-Z)"
        case .titleZA: return "Title (Z-A)"
        case .releaseDateNewest: return "Release Date (Newest)"
        case .releaseDateOldest: return "Release Date (Oldest)"
        case .ratingHighLow: return "Rating (High to Low)"
        case .ratingLowHigh: return "Rating (Low to High)"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Extensions

extension MovieService.MovieFilter: CaseIterable, Equatable, Hashable {
    static var allCases: [MovieService.MovieFilter] {
        [.popular, .topRated, .upcoming, .nowPlaying]
    }
    
    var displayName: String {
        switch self {
        case .popular:
            return "Popular"
        case .topRated:
            return "Top Rated"
        case .upcoming:
            return "Upcoming"
        case .nowPlaying:
            return "Now Playing"
        case .similar(let id):
            return "Similar to Movie #\(id)"
        }
    }
    
    static func == (lhs: MovieService.MovieFilter, rhs: MovieService.MovieFilter) -> Bool {
        switch (lhs, rhs) {
        case (.popular, .popular),
             (.topRated, .topRated),
             (.upcoming, .upcoming),
             (.nowPlaying, .nowPlaying):
            return true
        case (.similar(let id1), .similar(let id2)):
            return id1 == id2
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .popular:
            hasher.combine(0)
        case .topRated:
            hasher.combine(1)
        case .upcoming:
            hasher.combine(2)
        case .nowPlaying:
            hasher.combine(3)
        case .similar(let id):
            hasher.combine(4)
            hasher.combine(id)
        }
    }
}

// Subview to break up complex expression for SwiftUI type-checking
struct MovieGridNavigationLink: View {
    let movie: Movie
    var body: some View {
        NavigationLink(destination: MovieDetailView(movie: movie)) {
            MovieCardLarge(movie: movie)
                .padding(.bottom, 6)
        }
    }
}

// Separate MovieGrid view to help SwiftUI type-checking
struct MovieGrid: View {
    let movies: [Movie]
    var body: some View {
        VStack {
            ForEach(movies) { movie in
                Text(movie.title)
            }
        }
    }
}

// Helper to get unique genres
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

struct ModernFilterSheet: View {
    let genres: [Genre]
    @Binding var selectedGenre: Genre?
    @Binding var selectedYear: Int?
    @Binding var selectedRating: Double?
    var onApply: (Genre?, Int?, Double?) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section(header: Text("Genre")) {
                if genres.isEmpty {
                    Picker("Genre", selection: $selectedGenre) {
                        Text("No genres available").tag(Genre?.none)
                    }
                    .disabled(true)
                } else {
                    Picker("Genre", selection: $selectedGenre) {
                        Text("None").tag(Genre?.none)
                        ForEach(genres, id: \ .id) { genre in
                            Text(genre.name).tag(Genre?.some(genre))
                        }
                    }
                }
            }
            Section(header: Text("Year")) {
                Picker("Year", selection: $selectedYear) {
                    Text("None").tag(Int?.none)
                    ForEach((1980...Calendar.current.component(.year, from: Date())).reversed(), id: \ .self) { year in
                        Text("\(year)").tag(Int?.some(year))
                    }
                }
            }
            Section(header: Text("Minimum Rating")) {
                Picker("Rating", selection: $selectedRating) {
                    Text("None").tag(Double?.none)
                    ForEach(Array(stride(from: 0.0, through: 10.0, by: 0.5)), id: \ .self) { rating in
                        Text(String(format: "%.1f", rating)).tag(Double?.some(rating))
                    }
                }
            }
        }
        .navigationTitle("Filter Movies")
        .navigationBarItems(trailing: Button("Done") {
            onApply(selectedGenre, selectedYear, selectedRating)
            presentationMode.wrappedValue.dismiss()
        })
    }
}

// MARK: - Preview Provider
struct MovieListView_Previews: PreviewProvider {
    static var previews: some View {
        MovieListView()
    }
} 
