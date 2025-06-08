import Foundation

class DeepSeekService {
    static let shared = DeepSeekService()
    private let endpoint = "https://api.deepseek.com/v1/chat/completions"

    func getMovieRecommendation(watchedMovies: [String], completion: @escaping (String?) -> Void) {
        let prompt = "Recommend me a movie based on these: \(watchedMovies.joined(separator: ", ")). Just give the title and a one-sentence reason."
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [[
                "role": "user",
                "content": prompt
            ]],
            "max_tokens": 100
        ]
        guard let url = URL(string: endpoint),
              let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.deepSeekApiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = httpBody
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("DeepSeek API error: \(error.localizedDescription)")
            }
            if let data = data {
                print("DeepSeek API raw response: \(String(data: data, encoding: .utf8) ?? "<nil>")")
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion(nil)
                return
            }
            completion(content.trimmingCharacters(in: .whitespacesAndNewlines))
        }.resume()
    }
} 
