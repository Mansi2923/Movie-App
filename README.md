# MovieList App

A modern iOS app for browsing and managing your favorite movies, built with SwiftUI and Firebase.

## Features

- Browse movies by different categories (Now Playing, Popular, Top Rated)
- View detailed movie information including cast, crew, and trailers
- Add movies to favorites
- Track your watch status (Want to Watch, Watching, Watched)
- User authentication and profile management
- Dark mode support
- Responsive and modern UI

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- CocoaPods
- Firebase account
- TMDB API key

## Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/MovieListApp.git
cd MovieListApp
```

2. Install dependencies:
```bash
pod install
```

3. Open `MovieListApp.xcworkspace` in Xcode

4. Configure Firebase:
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add an iOS app to your Firebase project
   - Download `GoogleService-Info.plist` and add it to your Xcode project
   - Enable Authentication (Email/Password) in Firebase Console
   - Set up Firestore Database with the following security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /movies/{movieId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /favorites/{movieId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

5. Configure TMDB API:
   - Get an API key from [TMDB](https://www.themoviedb.org/settings/api)
   - Replace the `apiKey` in `MovieService.swift` with your key

## Project Structure

```
MovieListApp/
├── Views/              # SwiftUI views
├── ViewModels/         # View models
├── Models/            # Data models
├── Services/          # Network and Firebase services
├── Utilities/         # Helper functions and extensions
└── Resources/         # Assets and configuration files
```

## Deployment

1. Update version and build numbers in Xcode project settings

2. Archive the app:
   - Select "Any iOS Device" as the build target
   - Go to Product > Archive

3. Upload to App Store:
   - Open Xcode Organizer
   - Select your archive
   - Click "Distribute App"
   - Follow the prompts to upload to App Store Connect

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [The Movie Database (TMDB)](https://www.themoviedb.org/) for the movie data API
- [Firebase](https://firebase.google.com/) for backend services
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) for the UI framework

## Author

Manasi Sawant 