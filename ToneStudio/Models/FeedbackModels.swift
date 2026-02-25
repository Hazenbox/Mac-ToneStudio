import Foundation

// MARK: - Feedback Type

enum FeedbackType: String, Codable {
    case like           // Thumbs up
    case dislike        // Thumbs down
    case edit           // User edited the response
    case comment        // Text feedback
    case report         // Report issue
}

// MARK: - Feedback Payload

struct FeedbackPayload: Codable {
    let type: FeedbackType
    let originalContent: String
    let modifiedContent: String?
    let comment: String?
    let messageId: String
    let conversationId: String
    let ecosystem: String
    let channel: String
    let timestamp: Date
    
    init(type: FeedbackType, originalContent: String, modifiedContent: String? = nil,
         comment: String? = nil, messageId: String, conversationId: String,
         ecosystem: String = AppConstants.feedbackEcosystem,
         channel: String = AppConstants.feedbackChannel) {
        self.type = type
        self.originalContent = originalContent
        self.modifiedContent = modifiedContent
        self.comment = comment
        self.messageId = messageId
        self.conversationId = conversationId
        self.ecosystem = ecosystem
        self.channel = channel
        self.timestamp = Date()
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "originalContent": originalContent,
            "messageId": messageId,
            "conversationId": conversationId,
            "ecosystem": ecosystem,
            "channel": channel,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
        
        if let modifiedContent = modifiedContent {
            dict["modifiedContent"] = modifiedContent
        }
        if let comment = comment {
            dict["comment"] = comment
        }
        
        return dict
    }
}

// MARK: - Correction Model (for Learning Service)

struct Correction: Codable, Identifiable {
    let id: UUID
    let originalText: String
    let correctedText: String
    let category: CorrectionCategory
    let context: String?
    let createdAt: Date
    var appliedCount: Int
    
    init(id: UUID = UUID(), originalText: String, correctedText: String,
         category: CorrectionCategory, context: String? = nil) {
        self.id = id
        self.originalText = originalText
        self.correctedText = correctedText
        self.category = category
        self.context = context
        self.createdAt = Date()
        self.appliedCount = 0
    }
}

enum CorrectionCategory: String, Codable {
    case spelling
    case grammar
    case tone
    case style
    case factual
    case formatting
    case other
}

// MARK: - Feedback Response

struct FeedbackResponse: Codable {
    let success: Bool
    let feedbackId: String?
    let error: String?
}

// MARK: - Feedback State

struct FeedbackState {
    var liked: Bool = false
    var disliked: Bool = false
    var edited: Bool = false
    var commented: Bool = false
    
    mutating func setLiked() {
        liked = true
        disliked = false
    }
    
    mutating func setDisliked() {
        liked = false
        disliked = true
    }
    
    mutating func reset() {
        liked = false
        disliked = false
        edited = false
        commented = false
    }
}
