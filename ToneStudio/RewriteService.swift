import Foundation
import OSLog

actor RewriteService {

    enum RewriteError: LocalizedError {
        case noApiKey
        case serverError(statusCode: Int, body: String)
        case emptyResponse
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .noApiKey:
                return "API key not configured. Set it in the menu bar settings."
            case .serverError(let code, _):
                return "Server error (\(code)). Try again."
            case .emptyResponse:
                return "Empty response from server. Try again."
            case .networkError(let error):
                if (error as? URLError)?.code == .timedOut {
                    return "Request timed out. Try again."
                }
                return error.localizedDescription
            }
        }
    }

    private struct RewriteResponse: Codable {
        let success: Bool
        let data: RewriteData?
        let error: String?
        
        struct RewriteData: Codable {
            let rewritten: String
        }
    }

    func rewrite(text: String) async throws -> String {
        let apiKey = KeychainHelper.load() ?? ""

        var request = URLRequest(url: URL(string: AppConstants.rewriteBaseURL + AppConstants.rewriteEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.requestTimeoutSeconds
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let body: [String: String] = ["text": text, "style": "professional"]
        request.httpBody = try JSONEncoder().encode(body)

        Logger.rewrite.info("Sending rewrite request (\(text.count) chars)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Logger.rewrite.error("Network error: \(error.localizedDescription)")
            throw RewriteError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw RewriteError.networkError(URLError(.badServerResponse))
        }

        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Logger.rewrite.error("Server error \(http.statusCode): \(bodyText)")
            throw RewriteError.serverError(statusCode: http.statusCode, body: bodyText)
        }

        let decoded: RewriteResponse
        do {
            decoded = try JSONDecoder().decode(RewriteResponse.self, from: data)
        } catch {
            Logger.rewrite.error("Decode error: \(error.localizedDescription)")
            throw RewriteError.networkError(error)
        }

        guard decoded.success, let rewrittenText = decoded.data?.rewritten, !rewrittenText.isEmpty else {
            if let errorMsg = decoded.error {
                Logger.rewrite.error("API error: \(errorMsg)")
                throw RewriteError.serverError(statusCode: 400, body: errorMsg)
            }
            throw RewriteError.emptyResponse
        }

        Logger.rewrite.info("Rewrite success (\(rewrittenText.count) chars)")
        return rewrittenText
    }
}
