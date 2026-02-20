import Foundation

enum AppConstants {
    nonisolated(unsafe) static let rewriteBaseURL = "https://tone-studio-delta.vercel.app"
    nonisolated(unsafe) static let rewriteEndpoint = "/api/rewrite"
    nonisolated(unsafe) static let minSelectionLength = 3
    nonisolated(unsafe) static let maxSelectionLength = 50_000
    nonisolated(unsafe) static let requestTimeoutSeconds: TimeInterval = 10
    nonisolated(unsafe) static let debounceInterval: TimeInterval = 0.3
    nonisolated(unsafe) static let clipboardRestoreDelay: TimeInterval = 0.2
    nonisolated(unsafe) static let clipboardReadDelay: UInt32 = 50_000
    nonisolated(unsafe) static let permissionPollInterval: TimeInterval = 2.0
    nonisolated(unsafe) static let keychainServiceName = "com.upen.ToneStudio"
    nonisolated(unsafe) static let keychainApiKeyAccount = "rewrite-api-key"
}
