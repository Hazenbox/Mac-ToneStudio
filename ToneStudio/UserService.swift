import Foundation
import OSLog

/// Manages user authentication with the Convex backend.
/// Performs silent auto-registration on first use.
actor UserService {
    
    enum AuthError: LocalizedError {
        case serverError(statusCode: Int, body: String)
        case networkError(Error)
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .serverError(let code, _):
                return "Authentication failed (\(code))"
            case .networkError(let error):
                return error.localizedDescription
            case .invalidResponse:
                return "Invalid server response"
            }
        }
    }
    
    private struct AuthRequest: Encodable {
        let deviceId: String
        let name: String
        let role: String
        let product: String
    }
    
    private struct AuthResponse: Decodable {
        let success: Bool
        let data: AuthData?
        let error: String?
        
        struct AuthData: Decodable {
            let userId: String
            let deviceId: String
        }
    }
    
    static let shared = UserService()
    
    private static let isAuthenticatedKey = "user_authenticated"
    private static let authenticateEndpoint = "/api/users/authenticate"
    
    private let deviceId: String
    
    private init() {
        self.deviceId = Self.getOrCreateDeviceId()
    }
    
    /// Ensures the user is authenticated with the backend.
    /// This is safe to call multiple times - it will only authenticate once.
    func ensureAuthenticated() async throws {
        if UserDefaults.standard.bool(forKey: Self.isAuthenticatedKey) {
            Logger.user.debug("User already authenticated")
            return
        }
        
        try await authenticate()
    }
    
    /// Force re-authenticate (useful if authentication was invalidated)
    func forceAuthenticate() async throws {
        UserDefaults.standard.removeObject(forKey: Self.isAuthenticatedKey)
        try await authenticate()
    }
    
    /// Returns the current device ID
    func getDeviceId() -> String {
        return deviceId
    }
    
    /// Check if user is authenticated (without making network call)
    func isAuthenticated() -> Bool {
        return UserDefaults.standard.bool(forKey: Self.isAuthenticatedKey)
    }
    
    private func authenticate() async throws {
        let apiKey = KeychainHelper.load() ?? ""
        
        var request = URLRequest(url: URL(string: AppConstants.rewriteBaseURL + Self.authenticateEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.requestTimeoutSeconds
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        
        let authRequest = AuthRequest(
            deviceId: deviceId,
            name: "Mac User",
            role: "marketing",
            product: "mac-tonestudio"
        )
        
        request.httpBody = try JSONEncoder().encode(authRequest)
        
        Logger.user.info("Authenticating user with deviceId: \(self.deviceId)")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Logger.user.error("Network error during authentication: \(error.localizedDescription)")
            throw AuthError.networkError(error)
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Logger.user.error("Authentication failed with status \(http.statusCode): \(bodyText)")
            throw AuthError.serverError(statusCode: http.statusCode, body: bodyText)
        }
        
        // Verify response structure
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard authResponse.success else {
            let errorMsg = authResponse.error ?? "Unknown error"
            Logger.user.error("Authentication failed: \(errorMsg)")
            throw AuthError.serverError(statusCode: http.statusCode, body: errorMsg)
        }
        
        // Mark as authenticated
        UserDefaults.standard.set(true, forKey: Self.isAuthenticatedKey)
        Logger.user.info("User authenticated successfully")
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

extension Logger {
    static let user = Logger(subsystem: "com.upen.ToneStudio", category: "user")
}
