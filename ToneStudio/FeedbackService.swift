import Foundation
import OSLog

actor FeedbackService {
    
    static let shared = FeedbackService()
    
    enum FeedbackError: LocalizedError {
        case serverError(statusCode: Int, body: String)
        case networkError(Error)
        case authenticationFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .serverError(let code, _):
                return "Server error (\(code))"
            case .networkError(let error):
                return error.localizedDescription
            case .authenticationFailed(let error):
                return "Authentication failed: \(error.localizedDescription)"
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
    private let userService: UserService
    private var pendingFeedback: [FeedbackPayload] = []
    private var feedbackHistory: [String: FeedbackState] = [:]
    
    init() {
        self.deviceId = Self.getOrCreateDeviceId()
        self.userService = UserService.shared
    }
    
    func submit(
        feedbackType: String,
        messageContent: String,
        originalContent: String,
        comment: String? = nil
    ) async throws {
        do {
            try await userService.ensureAuthenticated()
        } catch {
            Logger.feedback.error("Failed to authenticate before feedback: \(error.localizedDescription)")
            throw FeedbackError.authenticationFailed(error)
        }
        
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
    
    func like(messageId: String, originalContent: String, conversationId: String) async throws {
        try await submit(feedbackType: "like", messageContent: "", originalContent: originalContent)
        updateLocalState(messageId: messageId, type: .like)
    }
    
    func dislike(messageId: String, originalContent: String, conversationId: String) async throws {
        try await submit(feedbackType: "dislike", messageContent: "", originalContent: originalContent)
        updateLocalState(messageId: messageId, type: .dislike)
    }
    
    func submitEdit(messageId: String, originalContent: String, editedContent: String, conversationId: String) async throws {
        try await submit(feedbackType: "edit", messageContent: editedContent, originalContent: originalContent)
        updateLocalState(messageId: messageId, type: .edit)
        
        let correction = Correction(
            originalText: originalContent,
            correctedText: editedContent,
            category: .style,
            context: "user_edit"
        )
        await LearningService.shared.recordCorrection(correction)
    }
    
    func submitComment(messageId: String, originalContent: String, comment: String, conversationId: String) async throws {
        try await submit(feedbackType: "comment", messageContent: "", originalContent: originalContent, comment: comment)
        updateLocalState(messageId: messageId, type: .comment)
    }
    
    func getFeedbackState(for messageId: String) -> FeedbackState {
        return feedbackHistory[messageId] ?? FeedbackState()
    }
    
    private func updateLocalState(messageId: String, type: FeedbackType) {
        var state = feedbackHistory[messageId] ?? FeedbackState()
        
        switch type {
        case .like:
            state.setLiked()
        case .dislike:
            state.setDisliked()
        case .edit:
            state.edited = true
        case .comment:
            state.commented = true
        case .report:
            break
        }
        
        feedbackHistory[messageId] = state
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

