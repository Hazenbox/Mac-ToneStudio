import Foundation
import OSLog

// MARK: - Message Intent

enum MessageIntent: String, Codable {
    case generalChat            // Casual conversation
    case contentGeneration      // Writing/editing request
    case jioInquiry            // Questions about Jio products/services
    case safetyResponse        // Safety-related query requiring special handling
    case compliance            // Compliance/validation request
    case feedback              // User providing feedback
    
    var requiresValidation: Bool {
        switch self {
        case .contentGeneration, .compliance:
            return true
        case .generalChat, .jioInquiry, .safetyResponse, .feedback:
            return false
        }
    }
    
    var validationLevel: ValidationLevel {
        switch self {
        case .contentGeneration:
            return .full
        case .compliance:
            return .strict
        case .generalChat, .jioInquiry:
            return .minimal
        case .safetyResponse, .feedback:
            return .none
        }
    }
}

enum ValidationLevel: String, Codable {
    case none       // No validation
    case minimal    // Basic checks only
    case standard   // Standard validation
    case full       // Full validation with trust score
    case strict     // Strict validation for compliance
}

// MARK: - Intent Classification Result

struct IntentClassificationResult: Codable {
    let intent: MessageIntent
    let confidence: Double
    let keywords: [String]
    let suggestedValidationLevel: ValidationLevel
    
    var isHighConfidence: Bool {
        confidence >= 0.8
    }
}

// MARK: - Intent Classifier Service

actor IntentClassifierService {
    
    static let shared = IntentClassifierService()
    
    private let contentGenerationKeywords: Set<String> = [
        "write", "rewrite", "rephrase", "edit", "improve", "fix",
        "create", "draft", "compose", "generate", "make",
        "change", "modify", "update", "revise", "polish",
        "simplify", "shorten", "expand", "summarize", "paraphrase",
        "professional", "formal", "casual", "friendly", "tone"
    ]
    
    private let jioInquiryKeywords: Set<String> = [
        "jio", "recharge", "plan", "data", "balance", "validity",
        "fiber", "sim", "number", "tariff", "offer", "pack",
        "internet", "speed", "network", "coverage", "signal",
        "app", "myji", "jiocinem", "jiotv", "jiomart", "jiomeet"
    ]
    
    private let complianceKeywords: Set<String> = [
        "validate", "check", "compliance", "verify", "review",
        "trust", "score", "issues", "violations", "rules",
        "guidelines", "standards", "brand", "voice"
    ]
    
    private let feedbackKeywords: Set<String> = [
        "thanks", "thank you", "helpful", "great", "good",
        "bad", "wrong", "incorrect", "fix", "issue", "problem",
        "feedback", "suggestion", "comment"
    ]
    
    private init() {}
    
    // MARK: - Public API
    
    func classify(_ text: String) -> IntentClassificationResult {
        let lowerText = text.lowercased()
        let words = Set(extractWords(from: lowerText))
        
        let scores: [(MessageIntent, Double, [String])] = [
            classifyContentGeneration(words: words, text: lowerText),
            classifyJioInquiry(words: words, text: lowerText),
            classifyCompliance(words: words, text: lowerText),
            classifyFeedback(words: words, text: lowerText)
        ]
        
        let best = scores.max(by: { $0.1 < $1.1 }) ?? (.generalChat, 0.5, [])
        
        let intent: MessageIntent
        let confidence: Double
        let keywords: [String]
        
        if best.1 >= 0.3 {
            intent = best.0
            confidence = best.1
            keywords = best.2
        } else {
            intent = .generalChat
            confidence = 0.5
            keywords = []
        }
        
        Logger.intent.debug("Classified intent: \(intent.rawValue), confidence: \(confidence)")
        
        return IntentClassificationResult(
            intent: intent,
            confidence: confidence,
            keywords: keywords,
            suggestedValidationLevel: intent.validationLevel
        )
    }
    
    func shouldSkipValidation(for intent: MessageIntent) -> Bool {
        return !intent.requiresValidation
    }
    
    func getValidationConfig(for intent: MessageIntent) -> ValidationConfig {
        switch intent.validationLevel {
        case .none:
            return ValidationConfig(
                checkAvoidWords: false,
                checkReadability: false,
                calculateTrustScore: false,
                applyAutoFixes: false
            )
        case .minimal:
            return ValidationConfig(
                checkAvoidWords: true,
                checkReadability: false,
                calculateTrustScore: false,
                applyAutoFixes: false
            )
        case .standard:
            return ValidationConfig(
                checkAvoidWords: true,
                checkReadability: true,
                calculateTrustScore: true,
                applyAutoFixes: true
            )
        case .full, .strict:
            return ValidationConfig(
                checkAvoidWords: true,
                checkReadability: true,
                calculateTrustScore: true,
                applyAutoFixes: true,
                strictMode: intent.validationLevel == .strict
            )
        }
    }
    
    // MARK: - Private Classification Methods
    
    private func classifyContentGeneration(words: Set<String>, text: String) -> (MessageIntent, Double, [String]) {
        let matches = words.intersection(contentGenerationKeywords)
        let score = Double(matches.count) / 3.0
        
        var bonus = 0.0
        if text.contains("please") || text.contains("can you") || text.contains("could you") {
            bonus += 0.1
        }
        if text.contains("voice and tone") || text.contains("jio voice") {
            bonus += 0.3
        }
        
        return (.contentGeneration, min(1.0, score + bonus), Array(matches))
    }
    
    private func classifyJioInquiry(words: Set<String>, text: String) -> (MessageIntent, Double, [String]) {
        let matches = words.intersection(jioInquiryKeywords)
        let score = Double(matches.count) / 2.0
        
        var bonus = 0.0
        if text.contains("how") || text.contains("what") || text.contains("?") {
            bonus += 0.15
        }
        
        return (.jioInquiry, min(1.0, score + bonus), Array(matches))
    }
    
    private func classifyCompliance(words: Set<String>, text: String) -> (MessageIntent, Double, [String]) {
        let matches = words.intersection(complianceKeywords)
        let score = Double(matches.count) / 2.0
        
        var bonus = 0.0
        if text.contains("validate") || text.contains("compliance") {
            bonus += 0.3
        }
        
        return (.compliance, min(1.0, score + bonus), Array(matches))
    }
    
    private func classifyFeedback(words: Set<String>, text: String) -> (MessageIntent, Double, [String]) {
        let matches = words.intersection(feedbackKeywords)
        let score = Double(matches.count) / 2.0
        
        return (.feedback, min(1.0, score), Array(matches))
    }
    
    private func extractWords(from text: String) -> [String] {
        let pattern = "\\b\\w+\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}

// MARK: - Validation Config

struct ValidationConfig {
    var checkAvoidWords: Bool
    var checkReadability: Bool
    var calculateTrustScore: Bool
    var applyAutoFixes: Bool
    var strictMode: Bool
    
    init(checkAvoidWords: Bool = true, checkReadability: Bool = true,
         calculateTrustScore: Bool = true, applyAutoFixes: Bool = true,
         strictMode: Bool = false) {
        self.checkAvoidWords = checkAvoidWords
        self.checkReadability = checkReadability
        self.calculateTrustScore = calculateTrustScore
        self.applyAutoFixes = applyAutoFixes
        self.strictMode = strictMode
    }
    
    static let full = ValidationConfig()
    static let minimal = ValidationConfig(checkReadability: false, calculateTrustScore: false, applyAutoFixes: false)
    static let none = ValidationConfig(checkAvoidWords: false, checkReadability: false, calculateTrustScore: false, applyAutoFixes: false)
}

