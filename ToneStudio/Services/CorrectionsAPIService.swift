import Foundation
import os.log

actor CorrectionsAPIService {
    
    static let shared = CorrectionsAPIService()
    
    // MARK: - Types
    
    struct CorrectionRequest: Encodable {
        let originalText: String
        let correctedText: String
        let category: String
        let context: String?
        let ecosystem: String
        let channel: String
        let deviceId: String
        let timestamp: String
    }
    
    struct BatchCorrectionRequest: Encodable {
        let corrections: [CorrectionRequest]
    }
    
    struct CorrectionResponse: Decodable {
        let success: Bool
        let correctionId: String?
        let message: String?
        let error: String?
    }
    
    struct BatchCorrectionResponse: Decodable {
        let success: Bool
        let processed: Int
        let failed: Int
        let errors: [String]?
    }
    
    enum CorrectionError: LocalizedError {
        case serverError(statusCode: Int, body: String)
        case networkError(Error)
        case invalidResponse
        case notAuthenticated
        
        var errorDescription: String? {
            switch self {
            case .serverError(let code, let body):
                return "Server error (\(code)): \(body)"
            case .networkError(let error):
                return error.localizedDescription
            case .invalidResponse:
                return "Invalid server response"
            case .notAuthenticated:
                return "Not authenticated"
            }
        }
    }
    
    // MARK: - Properties
    
    private let deviceId: String
    private let dateFormatter: ISO8601DateFormatter
    
    private init() {
        self.deviceId = Self.getOrCreateDeviceId()
        self.dateFormatter = ISO8601DateFormatter()
    }
    
    // MARK: - Public API
    
    /// Submit a single correction to the backend
    func submitCorrection(_ correction: Correction) async throws -> String {
        let apiKey = KeychainHelper.load() ?? ""
        
        guard let url = URL(string: AppConstants.rewriteBaseURL + AppConstants.correctionsEndpoint) else {
            throw CorrectionError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.requestTimeoutSeconds
        
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        
        let correctionRequest = CorrectionRequest(
            originalText: correction.originalText,
            correctedText: correction.correctedText,
            category: correction.category.rawValue,
            context: correction.context,
            ecosystem: AppConstants.feedbackEcosystem,
            channel: AppConstants.feedbackChannel,
            deviceId: deviceId,
            timestamp: dateFormatter.string(from: correction.createdAt)
        )
        
        request.httpBody = try JSONEncoder().encode(correctionRequest)
        
        Logger.learning.info("Submitting correction: '\(correction.originalText)' → '\(correction.correctedText)'")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw CorrectionError.invalidResponse
        }
        
        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Logger.learning.error("Correction API error \(http.statusCode): \(bodyText)")
            throw CorrectionError.serverError(statusCode: http.statusCode, body: bodyText)
        }
        
        let decoded = try JSONDecoder().decode(CorrectionResponse.self, from: data)
        
        guard decoded.success, let correctionId = decoded.correctionId else {
            throw CorrectionError.serverError(statusCode: 400, body: decoded.error ?? "Unknown error")
        }
        
        Logger.learning.info("Correction submitted successfully: \(correctionId)")
        return correctionId
    }
    
    /// Submit multiple corrections in batch
    func submitCorrections(_ corrections: [Correction]) async throws -> BatchCorrectionResponse {
        guard !corrections.isEmpty else {
            return BatchCorrectionResponse(success: true, processed: 0, failed: 0, errors: nil)
        }
        
        let apiKey = KeychainHelper.load() ?? ""
        
        guard let url = URL(string: AppConstants.rewriteBaseURL + AppConstants.correctionsEndpoint + "/batch") else {
            throw CorrectionError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.requestTimeoutSeconds * 2  // Longer timeout for batch
        
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        
        let correctionRequests = corrections.map { correction in
            CorrectionRequest(
                originalText: correction.originalText,
                correctedText: correction.correctedText,
                category: correction.category.rawValue,
                context: correction.context,
                ecosystem: AppConstants.feedbackEcosystem,
                channel: AppConstants.feedbackChannel,
                deviceId: deviceId,
                timestamp: dateFormatter.string(from: correction.createdAt)
            )
        }
        
        let batchRequest = BatchCorrectionRequest(corrections: correctionRequests)
        request.httpBody = try JSONEncoder().encode(batchRequest)
        
        Logger.learning.info("Submitting batch of \(corrections.count) corrections")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw CorrectionError.invalidResponse
        }
        
        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Logger.learning.error("Batch correction API error \(http.statusCode): \(bodyText)")
            throw CorrectionError.serverError(statusCode: http.statusCode, body: bodyText)
        }
        
        let decoded = try JSONDecoder().decode(BatchCorrectionResponse.self, from: data)
        
        Logger.learning.info("Batch corrections submitted: \(decoded.processed) processed, \(decoded.failed) failed")
        
        return decoded
    }
    
    /// Fetch corrections from server (for sync)
    func fetchCorrections(since: Date? = nil) async throws -> [Correction] {
        let apiKey = KeychainHelper.load() ?? ""
        
        var urlString = AppConstants.rewriteBaseURL + AppConstants.correctionsEndpoint
        if let since = since {
            urlString += "?since=\(dateFormatter.string(from: since))"
        }
        
        guard let url = URL(string: urlString) else {
            throw CorrectionError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.requestTimeoutSeconds
        
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        
        Logger.learning.info("Fetching corrections from server")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw CorrectionError.invalidResponse
        }
        
        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw CorrectionError.serverError(statusCode: http.statusCode, body: bodyText)
        }
        
        struct FetchResponse: Decodable {
            let corrections: [ServerCorrection]
        }
        
        struct ServerCorrection: Decodable {
            let id: String
            let originalText: String
            let correctedText: String
            let category: String
            let context: String?
            let createdAt: String
        }
        
        let decoded = try JSONDecoder().decode(FetchResponse.self, from: data)
        
        let corrections = decoded.corrections.compactMap { serverCorrection -> Correction? in
            guard let category = CorrectionCategory(rawValue: serverCorrection.category) else {
                return nil
            }
            
            let date = dateFormatter.date(from: serverCorrection.createdAt) ?? Date()
            
            return Correction(
                id: UUID(uuidString: serverCorrection.id) ?? UUID(),
                originalText: serverCorrection.originalText,
                correctedText: serverCorrection.correctedText,
                category: category,
                context: serverCorrection.context,
                synced: true
            )
        }
        
        Logger.learning.info("Fetched \(corrections.count) corrections from server")
        
        return corrections
    }
    
    /// Sync local corrections with server
    func syncCorrections() async throws -> SyncResult {
        // Get pending (unsynced) corrections
        let pendingCorrections = await LearningService.shared.getPendingCorrections()
        
        var uploadedCount = 0
        var downloadedCount = 0
        var errors: [String] = []
        
        // Upload pending corrections
        if !pendingCorrections.isEmpty {
            do {
                let result = try await submitCorrections(pendingCorrections)
                uploadedCount = result.processed
                
                // Mark as synced
                await LearningService.shared.markCorrectionsSynced(pendingCorrections)
            } catch {
                errors.append("Upload failed: \(error.localizedDescription)")
            }
        }
        
        // Download new corrections from server
        do {
            let serverCorrections = try await fetchCorrections()
            
            for correction in serverCorrections {
                await LearningService.shared.recordCorrection(correction)
            }
            downloadedCount = serverCorrections.count
        } catch {
            errors.append("Download failed: \(error.localizedDescription)")
        }
        
        let success = errors.isEmpty
        
        return SyncResult(
            success: success,
            message: success ? "sync completed" : errors.joined(separator: "; "),
            updatedItems: uploadedCount + downloadedCount
        )
    }
    
    // MARK: - Private
    
    private static func getOrCreateDeviceId() -> String {
        let key = "ToneStudio.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
