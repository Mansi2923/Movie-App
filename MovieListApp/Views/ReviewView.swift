import SwiftUI

struct ReviewView: View {
    let movieId: Int
    @State private var reviews: [Review] = []
    @State private var showingAddReview = false
    @State private var newRating: Double = 5.0
    @State private var newComment: String = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reviews")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddReview = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            if reviews.isEmpty {
                Text("No reviews yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(reviews) { review in
                    ReviewCard(review: review)
                }
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
        .sheet(isPresented: $showingAddReview) {
            AddReviewView(movieId: movieId, onSave: { review in
                ReviewService.shared.saveReview(review)
                loadReviews()
            })
        }
        .onAppear(perform: loadReviews)
    }
    
    private func loadReviews() {
        reviews = ReviewService.shared.getReviewsForMovie(movieId: movieId)
    }
}

struct ReviewCard: View {
    let review: Review
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(review.rating) ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
            }
            
            Text(review.comment)
                .font(.body)
                .foregroundColor(.secondary)
            
            Text(review.timestamp, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AddReviewView: View {
    let movieId: Int
    let onSave: (Review) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var rating: Double = 5.0
    @State private var comment: String = ""
    @State private var username: String = UserDefaults.standard.string(forKey: "username") ?? ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rating")) {
                    HStack {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    rating = Double(index + 1)
                                }
                        }
                    }
                }
                
                Section(header: Text("Comment")) {
                    TextEditor(text: $comment)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Review")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    let review = Review(
                        movieId: movieId,
                        userId: UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString,
                        username: username,
                        rating: rating,
                        comment: comment
                    )
                    onSave(review)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(comment.isEmpty)
            )
        }
    }
} 