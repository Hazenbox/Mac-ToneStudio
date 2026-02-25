import Foundation

enum AppConstants {
    // MARK: - API
    nonisolated(unsafe) static let rewriteBaseURL = "https://majestic-mockingbird-289.eu-west-1.convex.site"
    nonisolated(unsafe) static let rewriteEndpoint = "/api/rewrite"
    nonisolated(unsafe) static let feedbackEndpoint = "/api/feedback"
    nonisolated(unsafe) static let correctionsEndpoint = "/api/corrections"
    nonisolated(unsafe) static let knowledgeEndpoint = "/api/knowledge"
    nonisolated(unsafe) static let requestTimeoutSeconds: TimeInterval = 15
    
    // MARK: - Generation Context Defaults
    nonisolated(unsafe) static let defaultEcosystem: EcosystemType = .connectivity
    nonisolated(unsafe) static let defaultChannel: ContentChannelType = .editor
    nonisolated(unsafe) static let defaultPersona = "professional"
    nonisolated(unsafe) static let defaultWarmth: Int = 7
    nonisolated(unsafe) static let defaultDetail: Int = 2
    nonisolated(unsafe) static let defaultEmotion: NavarasaType = .shanta
    nonisolated(unsafe) static let defaultLanguage: SupportedLanguage = .english
    nonisolated(unsafe) static let defaultRegion: IndianRegion = .panIndia
    nonisolated(unsafe) static let defaultGoal: ContentGoalType = .action
    
    // MARK: - Feedback (Legacy - use Generation Context defaults)
    nonisolated(unsafe) static let feedbackEcosystem = "mac-tonestudio"
    nonisolated(unsafe) static let feedbackChannel = "editor"
    nonisolated(unsafe) static let feedbackPersona = "professional"
    
    // MARK: - Cache TTLs (seconds)
    nonisolated(unsafe) static let cacheTTLKnowledge: TimeInterval = 5 * 60       // 5 minutes
    nonisolated(unsafe) static let cacheTTLEnforcement: TimeInterval = 10 * 60    // 10 minutes
    nonisolated(unsafe) static let cacheTTLExamples: TimeInterval = 15 * 60       // 15 minutes
    nonisolated(unsafe) static let cacheTTLCorrections: TimeInterval = 5 * 60     // 5 minutes
    nonisolated(unsafe) static let cacheTTLUserProfile: TimeInterval = 5 * 60     // 5 minutes
    
    // MARK: - Trust Score Thresholds
    nonisolated(unsafe) static let trustScoreMinimum: Int = 90
    nonisolated(unsafe) static let trustScoreCertified: Int = 90
    nonisolated(unsafe) static let trustScoreWarning: Int = 70
    
    // MARK: - Readability
    nonisolated(unsafe) static let targetReadabilityGrade: Double = 8.0
    
    // MARK: - Text Selection
    nonisolated(unsafe) static let minSelectionLength = 3
    nonisolated(unsafe) static let maxSelectionLength = 50_000
    nonisolated(unsafe) static let debounceInterval: TimeInterval = 0.35
    nonisolated(unsafe) static let clipboardRestoreDelay: TimeInterval = 0.2
    nonisolated(unsafe) static let clipboardReadDelay: UInt32 = 250_000
    
    // MARK: - Tooltip
    nonisolated(unsafe) static let miniIconAutoHideDelay: TimeInterval = 3.5
    nonisolated(unsafe) static let miniIconSize: CGFloat = 44
    nonisolated(unsafe) static let noSelectionAutoHideDelay: TimeInterval = 2.0
    
    // MARK: - Editor Window
    nonisolated(unsafe) static let editorWindowWidth: CGFloat = 500
    nonisolated(unsafe) static let editorWindowHeight: CGFloat = 420
    nonisolated(unsafe) static let editorCornerRadius: CGFloat = 16
    nonisolated(unsafe) static let editorPadding: CGFloat = 20
    
    // MARK: - Permissions
    nonisolated(unsafe) static let permissionPollInterval: TimeInterval = 2.0
    
    // MARK: - Keychain
    nonisolated(unsafe) static let keychainServiceName = "com.upen.ToneStudio"
    nonisolated(unsafe) static let keychainApiKeyAccount = "rewrite-api-key"
}
