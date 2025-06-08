import SwiftUI
import PhotosUI
import FirebaseStorage
import Photos
import FirebaseFirestore

struct ProfileView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var movieListViewModel = MovieListViewModel()
    @State private var name = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showImagePicker = false
    @State private var profileImageURL: String?
    @State private var imageLoadError = false
    @State private var userMovies: [Movie] = []
    @State private var showAddMovieSheet = false
    @State private var selectedMovieToAdd: Movie?
    @State private var selectedStatusToAdd: WatchStatus = .watching
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Add Movie Button
                Button(action: { showAddMovieSheet = true }) {
                    Label("Add Movie", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Profile image header
                VStack(spacing: 8) {
                    ZStack(alignment: .bottomTrailing) {
                        if let profileImage = profileImage {
                            profileImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                        } else if let imageURL = profileImageURL {
                            AsyncImage(url: URL(string: imageURL)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 120, height: 120)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                                case .failure(_):
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 120, height: 120)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray)
                        }
                        Button(action: { checkPhotoLibraryPermission() }) {
                            Image(systemName: "pencil.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .offset(x: 8, y: 8)
                    }
                    .padding(.top, 24)
                }
                
                // Name field
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
                    .disabled(isLoading)
                    .padding(.horizontal)
                
                // Edit Profile and Sign Out buttons
                HStack(spacing: 16) {
                    Button(action: {
                        Task { await saveProfile() }
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Label("Save Profile", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Button(action: {
                        try? firebaseManager.signOut()
                        dismiss()
                    }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // --- Watch Status Sections ---
                if !userMovies.isEmpty {
                    VStack(alignment: .leading, spacing: 28) {
                        ModernProfileMovieSection(
                            title: "\(Image(systemName: "play.fill")) Watching",
                            movies: userMovies.filter { $0.userData?.status == .watching },
                            color: .blue
                        )
                        ModernProfileMovieSection(
                            title: "\(Image(systemName: "checkmark.circle.fill")) Watched",
                            movies: userMovies.filter { $0.userData?.status == .watched },
                            color: .green
                        )
                        ModernProfileMovieSection(
                            title: "\(Image(systemName: "bookmark.fill")) Want to Watch",
                            movies: userMovies.filter { $0.userData?.status == .wantToWatch },
                            color: .orange
                        )
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.bottom, 32)
        }
        .onChange(of: selectedImage) { newItem in
            if let item = newItem {
                Task {
                    await handleImageSelection(item)
                }
            }
        }
        .onAppear {
            Task {
                await movieListViewModel.loadMovies()
                await loadProfile()
                userMovies = await fetchUserMovies()
            }
        }
        .interactiveDismissDisabled(isLoading)
        .sheet(isPresented: $showAddMovieSheet) {
            AddMovieToProfileSheet(
                allMovies: movieListViewModel.movies,
                selectedMovie: $selectedMovieToAdd,
                selectedStatus: $selectedStatusToAdd,
                onAdd: { movie, status in
                    if let movie = movie {
                        Task {
                            await saveMovieToUserProfile(movie: movie, status: status)
                            await refreshUserMovies()
                        }
                    }
                    showAddMovieSheet = false
                },
                onCancel: { showAddMovieSheet = false }
            )
        }
    }
    
    private func checkPhotoLibraryPermission() {
        Task { @MainActor in
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .notDetermined:
                let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                if newStatus == .authorized {
                    showImagePicker = true
                } else {
                    errorMessage = "Photo library access denied"
                }
            case .restricted, .denied:
                errorMessage = "Please allow photo library access in Settings to change profile picture"
            case .authorized, .limited:
                showImagePicker = true
            @unknown default:
                break
            }
        }
    }
    
    private func handleImageSelection(_ item: PhotosPickerItem) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"])
            }
            
            guard let uiImage = UIImage(data: data) else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
            }
            
            // Resize image if too large
            let maxSize: CGFloat = 1024
            let resizedImage = uiImage.resized(to: CGSize(width: maxSize, height: maxSize))
            
            // Compress the image with slightly higher quality
            guard let compressedData = resizedImage.jpegData(compressionQuality: 0.8),
                  let compressedImage = UIImage(data: compressedData) else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
            }
            
            await MainActor.run {
                withAnimation {
                    profileImage = Image(uiImage: compressedImage)
                    errorMessage = ""
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load image: \(error.localizedDescription)"
                selectedImage = nil
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func loadProfile() async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            let (loadedName, loadedImageURL) = try await firebaseManager.loadUserProfile()
            await MainActor.run {
                withAnimation {
                    name = loadedName
                    profileImageURL = loadedImageURL
                    errorMessage = ""
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func saveProfile() async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            var imageData: Data?
            if let selectedImage = selectedImage {
                if let data = try? await selectedImage.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data) {
                        // Resize image if too large
                        let maxSize: CGFloat = 1024
                        let resizedImage = uiImage.resized(to: CGSize(width: maxSize, height: maxSize))
                        
                        // Compress the image with slightly higher quality
                        if let compressedData = resizedImage.jpegData(compressionQuality: 0.8) {
                            imageData = compressedData
                        }
                    }
                }
            }
            
            try await firebaseManager.updateUserProfile(name: name, imageData: imageData)
            
            await MainActor.run {
                withAnimation {
                    selectedImage = nil
                    errorMessage = ""
                }
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }

    private func saveMovieToUserProfile(movie: Movie, status: WatchStatus) async {
        guard let userId = firebaseManager.currentUser?.uid else { return }
        let db = Firestore.firestore()
        var userData = movie.userData ?? MovieUserData()
        userData.status = status
        userData.lastUpdated = ISO8601DateFormatter().string(from: Date())
        do {
            try await db.collection("users").document(userId)
                .collection("movies").document(String(movie.id))
                .setData(from: userData)
        } catch {
            // Removed: print statement for error saving movie to user profile.
        }
    }
    
    private func refreshUserMovies() async {
        // TODO: Replace with real backend call to fetch user movies
        userMovies = await fetchUserMovies()
    }

    // Placeholder async fetch for user movies
    private func fetchUserMovies() async -> [Movie] {
        // TODO: Replace with real backend call
        return []
    }
}

struct ModernProfileMovieSection: View {
    let title: String
    let movies: [Movie]
    let color: Color
    @EnvironmentObject var movieListViewModel: MovieListViewModel
    var body: some View {
        if !movies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundColor(color)
                    Spacer()
                }
                .padding(.leading, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(movies) { movie in
                            MovieCardCompact(movie: movie, viewModel: movieListViewModel)
                                .frame(width: 150)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: color.opacity(0.08), radius: 4, y: 2)
            .padding(.horizontal, 8)
        }
    }
}

struct AddMovieToProfileSheet: View {
    let allMovies: [Movie]
    @Binding var selectedMovie: Movie?
    @Binding var selectedStatus: WatchStatus
    var onAdd: (Movie?, WatchStatus) -> Void
    var onCancel: () -> Void
    @State private var searchText = ""
    
    var filteredMovies: [Movie] {
        if searchText.isEmpty { return allMovies }
        return allMovies.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Search movies...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                List {
                    ForEach(filteredMovies, id: \.id) { movie in
                        HStack {
                            Text(movie.title)
                            Spacer()
                            if selectedMovie?.id == movie.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedMovie = movie }
                    }
                }
                .listStyle(.plain)
                Picker("Status", selection: $selectedStatus) {
                    Text("Watching").tag(WatchStatus.watching)
                    Text("Watched").tag(WatchStatus.watched)
                }
                .pickerStyle(.segmented)
                .padding()
                HStack {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.red)
                    Spacer()
                    Button("Add") { onAdd(selectedMovie, selectedStatus) }
                        .disabled(selectedMovie == nil)
                }
                .padding()
            }
            .navigationTitle("Add Movie")
        }
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? self
    }
}

// Demo array for allMovies
let demoAllMovies: [Movie] = [
    Movie(id: 1, title: "Sample Movie 1", overview: "Overview 1", posterPath: nil, backdropPath: nil, releaseDate: "2024-01-01", voteAverage: 7.5, voteCount: 100, genreIds: nil, genres: nil, runtime: 120, userData: nil, extendedDetails: nil),
    Movie(id: 2, title: "Sample Movie 2", overview: "Overview 2", posterPath: nil, backdropPath: nil, releaseDate: "2024-02-01", voteAverage: 8.0, voteCount: 200, genreIds: nil, genres: nil, runtime: 110, userData: nil, extendedDetails: nil)
] 