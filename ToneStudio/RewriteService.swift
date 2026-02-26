import Foundation
import OSLog

actor RewriteService {

    enum RewriteError: LocalizedError {
        case noApiKey
        case serverError(statusCode: Int, body: String)
        case emptyResponse
        case networkError(Error)
        case safetyBlocked(message: String)

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
            case .safetyBlocked(let message):
                return message
            }
        }
    }

    private struct RewriteResponse: Codable {
        let success: Bool
        let data: RewriteData?
        let error: String?
        
        struct RewriteData: Codable {
            let rewritten: String
            let trustScore: TrustScoreResponse?
            let evidence: GenerationEvidenceResponse?
        }
        
        struct TrustScoreResponse: Codable {
            let overall: Int?
            let breakdown: [String: Int]?
            let certified: Bool?
            let totalViolations: Int?
            let autoFixableCount: Int?
        }
        
        struct GenerationEvidenceResponse: Codable {
            let avoidWordsMatched: [String]?
            let preferredWordsUsed: [String]?
            let autoFixRulesCount: Int?
            let correctionsCount: Int?
        }
    }
    
    struct RewriteResult {
        let text: String
        let trustScore: TrustScore?
        let evidence: APIGenerationEvidence?
    }
    
    private var currentContext: GenerationContext = .default

    func setContext(_ context: GenerationContext) {
        currentContext = context
    }
    
    func rewrite(text: String, prompt: String? = nil, isChat: Bool = false) async throws -> String {
        let result = try await rewriteWithContext(text: text, prompt: prompt, isChat: isChat)
        return result.text
    }
    
    func rewriteWithContext(text: String, prompt: String? = nil, context: GenerationContext? = nil, isChat: Bool = false) async throws -> RewriteResult {
        let apiKey = KeychainHelper.load() ?? ""
        let ctx = context ?? currentContext

        var request = URLRequest(url: URL(string: AppConstants.rewriteBaseURL + AppConstants.rewriteEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.requestTimeoutSeconds
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        var body: [String: Any] = [
            "text": text,
            "isChat": isChat,
            "ecosystem": ctx.ecosystem.rawValue,
            "channel": ctx.channel.rawValue,
            "warmth": ctx.warmth,
            "detail": ctx.detail,
            "goal": ctx.goal.rawValue,
            "emotion": ctx.emotion.rawValue,
            "language": ctx.language.rawValue,
            "region": ctx.region.rawValue,
            "persona": ctx.persona ?? AppConstants.defaultPersona
        ]
        
        if let prompt = prompt, !prompt.isEmpty {
            body["prompt"] = prompt
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        Logger.rewrite.info("Sending rewrite request (\(text.count) chars, ecosystem: \(ctx.ecosystem.rawValue), channel: \(ctx.channel.rawValue))")

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

        let trustScore = decoded.data?.trustScore.map { response in
            TrustScore(
                overall: response.overall ?? 0,
                breakdown: TrustScoreBreakdown(from: response.breakdown ?? [:]),
                certified: response.certified ?? false,
                totalViolations: response.totalViolations ?? 0,
                autoFixableCount: response.autoFixableCount ?? 0
            )
        }
        
        let evidence = decoded.data?.evidence.map { response in
            APIGenerationEvidence(
                avoidWordsMatched: response.avoidWordsMatched ?? [],
                preferredWordsUsed: response.preferredWordsUsed ?? [],
                autoFixRulesCount: response.autoFixRulesCount ?? 0,
                correctionsCount: response.correctionsCount ?? 0
            )
        }

        Logger.rewrite.info("Rewrite success (\(rewrittenText.count) chars, trust: \(trustScore?.overall ?? -1))")
        return RewriteResult(text: rewrittenText, trustScore: trustScore, evidence: evidence)
    }
}

// MARK: - Trust Score Models

struct TrustScore: Codable {
    let overall: Int                    // 0-100
    let breakdown: TrustScoreBreakdown
    let certified: Bool                 // true if score >= 90
    let totalViolations: Int
    let autoFixableCount: Int
    
    var certification: String {
        if overall >= AppConstants.trustScoreCertified {
            return "certified"
        } else if overall >= AppConstants.trustScoreWarning {
            return "review_recommended"
        } else {
            return "issues_found"
        }
    }
}

struct TrustScoreBreakdown: Codable {
    var genderNeutrality: Int       // 0-100
    var inclusivity: Int            // 0-100
    var culturalSensitivity: Int    // 0-100
    var accessibility: Int          // 0-100
    var compliance: Int             // 0-100
    var styleConsistency: Int       // 0-100
    var brandAlignment: Int         // 0-100
    var readability: Int            // 0-100 (Grade 8 target)
    var avoidWords: Int?            // 0-100
    
    init(genderNeutrality: Int = 100, inclusivity: Int = 100, culturalSensitivity: Int = 100,
         accessibility: Int = 100, compliance: Int = 100, styleConsistency: Int = 100,
         brandAlignment: Int = 100, readability: Int = 100, avoidWords: Int? = nil) {
        self.genderNeutrality = genderNeutrality
        self.inclusivity = inclusivity
        self.culturalSensitivity = culturalSensitivity
        self.accessibility = accessibility
        self.compliance = compliance
        self.styleConsistency = styleConsistency
        self.brandAlignment = brandAlignment
        self.readability = readability
        self.avoidWords = avoidWords
    }
    
    init(from dictionary: [String: Int]) {
        self.genderNeutrality = dictionary["genderNeutrality"] ?? 100
        self.inclusivity = dictionary["inclusivity"] ?? 100
        self.culturalSensitivity = dictionary["culturalSensitivity"] ?? 100
        self.accessibility = dictionary["accessibility"] ?? 100
        self.compliance = dictionary["compliance"] ?? 100
        self.styleConsistency = dictionary["styleConsistency"] ?? 100
        self.brandAlignment = dictionary["brandAlignment"] ?? 100
        self.readability = dictionary["readability"] ?? 100
        self.avoidWords = dictionary["avoidWords"]
    }
}

struct APIGenerationEvidence: Codable {
    let avoidWordsMatched: [String]
    let preferredWordsUsed: [String]
    let autoFixRulesCount: Int
    let correctionsCount: Int
}
