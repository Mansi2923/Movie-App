import Foundation

struct Config {
    // TMDB API Configuration
    static let tmdbApiKey = "YOUR_TMDB_API_KEY"
    static let tmdbBaseURL = "https://api.themoviedb.org/3"
    static let tmdbImageBaseURL = "https://image.tmdb.org/t/p"
    
    // Firebase Configuration
    static let firebaseConfig = [
        "apiKey": "YOUR_FIREBASE_API_KEY",
        "authDomain": "YOUR_FIREBASE_AUTH_DOMAIN",
        "projectId": "YOUR_FIREBASE_PROJECT_ID",
        "storageBucket": "YOUR_FIREBASE_STORAGE_BUCKET",
        "messagingSenderId": "YOUR_FIREBASE_MESSAGING_SENDER_ID",
        "appId": "YOUR_FIREBASE_APP_ID"
    ]
    
    // Other Configuration
    static let appName = "MovieList"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
} 