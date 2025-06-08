import SwiftUI

struct LoginView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo or App Name
                Text("MovieListApp")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 40)
                
                // Email Field
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                // Password Field
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(isSignUp ? .newPassword : .password)
                
                // Sign In/Up Button
                Button(action: performAuthentication) {
                    Text(isSignUp ? "Sign Up" : "Sign In")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                // Toggle Sign In/Up
                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func performAuthentication() {
        Task {
            do {
                if isSignUp {
                    try await firebaseManager.signUp(email: email, password: password)
                } else {
                    try await firebaseManager.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
} 