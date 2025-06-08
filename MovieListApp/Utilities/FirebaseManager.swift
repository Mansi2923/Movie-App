import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private let auth: Auth
    private let db: Firestore
    private let storage: Storage
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        self.auth = Auth.auth()
        self.db = Firestore.firestore()
        self.storage = Storage.storage()
        setupFirebase()
        setupAuthStateListener()
    }
    
    private func setupFirebase() {
        // Firebase is already configured in AppDelegate
    }
    
    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        currentUser = result.user
    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        currentUser = result.user
    }
    
    func signOut() throws {
        try auth.signOut()
        currentUser = nil
    }
    
    // MARK: - User Profile Methods
    func updateUserProfile(name: String, imageData: Data?) async throws {
        guard let userId = currentUser?.uid else { 
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        var profileData: [String: Any] = ["name": name]
        
        if let imageData = imageData {
            let storageRef = storage.reference().child("profile_images/\(userId).jpg")
            
            // Set proper metadata for the image
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            // Upload with metadata and handle potential errors
            do {
                let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                let downloadURL = try await storageRef.downloadURL()
                profileData["profileImageURL"] = downloadURL.absoluteString
                profileData["lastUpdated"] = FieldValue.serverTimestamp()
            } catch {
                throw NSError(domain: "FirebaseManager", 
                            code: -2, 
                            userInfo: [NSLocalizedDescriptionKey: "Failed to upload profile image: \(error.localizedDescription)"])
            }
        }
        
        try await db.collection("users").document(userId).setData(profileData, merge: true)
    }
    
    func loadUserProfile() async throws -> (name: String, profileImageURL: String?) {
        guard let userId = currentUser?.uid else {
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        if let data = document.data() {
            let name = data["name"] as? String ?? ""
            let profileImageURL = data["profileImageURL"] as? String
            return (name, profileImageURL)
        }
        return ("", nil)
    }
    
    // MARK: - Favorite Movies Methods
    func addFavoriteMovie(movieId: Int) async throws {
        guard let userId = currentUser?.uid else { return }
        try await db.collection("users").document(userId).collection("favorites").document("\(movieId)").setData([
            "movieId": movieId,
            "addedAt": Date().ISO8601Format()
        ])
    }
    
    func removeFavoriteMovie(movieId: Int) async throws {
        guard let userId = currentUser?.uid else { return }
        let docRef = db.collection("users").document(userId).collection("favorites").document("\(movieId)")
        let doc = try await docRef.getDocument()
        if doc.exists {
            try await docRef.delete()
        }
    }
    
    func getFavoriteMovies() async throws -> [Int] {
        guard let userId = currentUser?.uid else { return [] }
        let snapshot = try await db.collection("users").document(userId).collection("favorites").getDocuments()
        let movieIds = snapshot.documents.compactMap { Int($0.documentID) }
        return movieIds
    }
    
    // MARK: - User Data Methods
    func getUserData() async throws -> [String: Any]? {
        guard let userId = currentUser?.uid else { return nil }
        let document = try await db.collection("users").document(userId).getDocument()
        return document.data()
    }
    
    func updateUserData(_ data: [String: Any]) async throws {
        guard let userId = currentUser?.uid else { return }
        try await db.collection("users").document(userId).setData(data, merge: true)
    }
} 
