import Foundation
import OSLog

actor FeedbackService {
    
    enum FeedbackError: LocalizedError {
        case serverError(statusCode: Int, body: String)
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .serverError(let code, _):
                return "Server error (\(code))"
            case .networkError(let error):
                return error.localizedDescription
            }
        }
    }
    
    struct FeedbackRequest: Encodable {
        let feedbackType: String
        let messageContent: String
        let originalContent: String
        let ecosystem: String
        let channel: String
        let persona: String
        let deviceId: String
        let comment: String?
    }
    
    private let deviceId: String
    
    init() {
        self.deviceId = Self.getOrCreateDeviceId()
    }
    
    func submit(
        feedbackType: String,
        messageContent: String,
        originalContent: String,
        comment: String? = nil
    ) async throws {
        let apiKey = KeychainHelper.load() ?? ""
        
        var request = URLRequest(url: URL(string: AppConstants.rewriteBaseURL + AppConstants.feedbackEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.requestTimeoutSeconds
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        
        let feedbackRequest = FeedbackRequest(
            feedbackType: feedbackType,
            messageContent: messageContent,
            originalContent: originalContent,
            ecosystem: AppConstants.feedbackEcosystem,
            channel: AppConstants.feedbackChannel,
            persona: AppConstants.feedbackPersona,
            deviceId: deviceId,
            comment: comment
        )
        
        request.httpBody = try JSONEncoder().encode(feedbackRequest)
        
        Logger.feedback.info("Submitting \(feedbackType) feedback")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Logger.feedback.error("Network error: \(error.localizedDescription)")
            throw FeedbackError.networkError(error)
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw FeedbackError.networkError(URLError(.badServerResponse))
        }
        
        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Logger.feedback.error("Server error \(http.statusCode): \(bodyText)")
            throw FeedbackError.serverError(statusCode: http.statusCode, body: bodyText)
        }
        
        Logger.feedback.info("Feedback submitted successfully")
    }
    
    private static func getOrCreateDeviceId() -> String {
        let key = "device_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
