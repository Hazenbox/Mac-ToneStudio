import Foundation

enum AppConstants {
    // MARK: - API
    nonisolated(unsafe) static let rewriteBaseURL = "https://majestic-mockingbird-289.eu-west-1.convex.site"
    nonisolated(unsafe) static let rewriteEndpoint = "/api/rewrite"
    nonisolated(unsafe) static let feedbackEndpoint = "/api/feedback"
    nonisolated(unsafe) static let requestTimeoutSeconds: TimeInterval = 15
    
    // MARK: - Feedback
    nonisolated(unsafe) static let feedbackEcosystem = "mac-tonestudio"
    nonisolated(unsafe) static let feedbackChannel = "editor"
    nonisolated(unsafe) static let feedbackPersona = "professional"
    
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
