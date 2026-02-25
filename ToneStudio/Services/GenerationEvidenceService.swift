import Foundation
import os.log

actor GenerationEvidenceService {
    
    static let shared = GenerationEvidenceService()
    
    // MARK: - Properties
    
    private var currentEvidence: GenerationEvidence?
    private var evidenceHistory: [String: GenerationEvidence] = [:]
    
    // MARK: - Evidence Tracking
    
    func startTracking(for messageId: String) {
        currentEvidence = GenerationEvidence(messageId: messageId)
        Logger.evidence.debug("Started tracking evidence for message: \(messageId)")
    }
    
    func recordKnowledgeUsed(_ knowledge: KnowledgeUsed) {
        currentEvidence?.knowledgeUsed.append(knowledge)
    }
    
    func recordLearningApplied(_ learning: LearningApplied) {
        currentEvidence?.learningsApplied.append(learning)
    }
    
    func recordSemanticMatch(_ match: SemanticMatch) {
        currentEvidence?.semanticMatches.append(match)
    }
    
    func recordAutoFix(_ fix: AutoFixApplied) {
        currentEvidence?.autoFixesApplied.append(fix)
    }
    
    func recordSafetyCheck(_ check: SafetyCheckResult) {
        currentEvidence?.safetyChecks.append(check)
    }
    
    func setContext(_ context: GenerationContext) {
        currentEvidence?.contextUsed = context
    }
    
    func setEmotionDetected(_ emotion: EmotionResult) {
        currentEvidence?.emotionDetected = emotion
    }
    
    func finishTracking() -> GenerationEvidence? {
        guard var evidence = currentEvidence else {
            return nil
        }
        
        evidence.completedAt = Date()
        evidenceHistory[evidence.messageId] = evidence
        
        Logger.evidence.info("Finished tracking evidence for message: \(evidence.messageId)")
        Logger.evidence.debug("""
            Evidence summary: \
            \(evidence.knowledgeUsed.count) knowledge items, \
            \(evidence.learningsApplied.count) learnings, \
            \(evidence.autoFixesApplied.count) auto-fixes
            """)
        
        let result = evidence
        currentEvidence = nil
        return result
    }
    
    func getEvidence(for messageId: String) -> GenerationEvidence? {
        evidenceHistory[messageId]
    }
    
    // MARK: - Evidence Analysis
    
    func buildEvidenceSummary(_ evidence: GenerationEvidence) -> EvidenceSummary {
        var influences: [String] = []
        
        // Knowledge influences
        for knowledge in evidence.knowledgeUsed {
            switch knowledge.type {
            case .avoidWord:
                influences.append("avoided '\(knowledge.term)' (\(knowledge.category))")
            case .preferredWord:
                influences.append("used preferred term '\(knowledge.term)'")
            case .brandGuideline:
                influences.append("applied brand guideline: \(knowledge.term)")
            case .channelRule:
                influences.append("followed channel rule: \(knowledge.term)")
            }
        }
        
        // Learning influences
        for learning in evidence.learningsApplied {
            influences.append("applied your correction: '\(learning.original)' → '\(learning.corrected)'")
        }
        
        // Auto-fix influences
        for fix in evidence.autoFixesApplied {
            influences.append("auto-fixed: '\(fix.original)' → '\(fix.replacement)' (\(fix.category))")
        }
        
        // Safety influences
        for check in evidence.safetyChecks {
            if check.triggered {
                influences.append("safety check triggered: \(check.domain.rawValue)")
            }
        }
        
        return EvidenceSummary(
            totalInfluences: influences.count,
            knowledgeCount: evidence.knowledgeUsed.count,
            learningsCount: evidence.learningsApplied.count,
            autoFixCount: evidence.autoFixesApplied.count,
            safetyTriggered: evidence.safetyChecks.contains { $0.triggered },
            influences: influences,
            emotionDetected: evidence.emotionDetected?.description
        )
    }
}

// MARK: - Models

struct GenerationEvidence: Codable {
    let messageId: String
    var knowledgeUsed: [KnowledgeUsed]
    var learningsApplied: [LearningApplied]
    var semanticMatches: [SemanticMatch]
    var autoFixesApplied: [AutoFixApplied]
    var safetyChecks: [SafetyCheckResult]
    var contextUsed: GenerationContext?
    var emotionDetected: EmotionResult?
    var startedAt: Date
    var completedAt: Date?
    
    init(messageId: String) {
        self.messageId = messageId
        self.knowledgeUsed = []
        self.learningsApplied = []
        self.semanticMatches = []
        self.autoFixesApplied = []
        self.safetyChecks = []
        self.contextUsed = nil
        self.emotionDetected = nil
        self.startedAt = Date()
        self.completedAt = nil
    }
}

struct KnowledgeUsed: Codable {
    let type: KnowledgeType
    let term: String
    let category: String
    let confidence: Double
    
    enum KnowledgeType: String, Codable {
        case avoidWord
        case preferredWord
        case brandGuideline
        case channelRule
    }
}

struct LearningApplied: Codable {
    let correctionId: String
    let original: String
    let corrected: String
    let appliedAt: Date
}

struct SemanticMatch: Codable {
    let query: String
    let matchedContent: String
    let similarity: Double
    let source: String
}

struct AutoFixApplied: Codable {
    let ruleId: String
    let original: String
    let replacement: String
    let category: String
}

struct SafetyCheckResult: Codable {
    let domain: SafetyDomain
    let triggered: Bool
    let level: SafetyLevel
    let action: String
}

struct EvidenceSummary {
    let totalInfluences: Int
    let knowledgeCount: Int
    let learningsCount: Int
    let autoFixCount: Int
    let safetyTriggered: Bool
    let influences: [String]
    let emotionDetected: String?
    
    var briefDescription: String {
        var parts: [String] = []
        if knowledgeCount > 0 {
            parts.append("\(knowledgeCount) brand rules")
        }
        if learningsCount > 0 {
            parts.append("\(learningsCount) your corrections")
        }
        if autoFixCount > 0 {
            parts.append("\(autoFixCount) auto-fixes")
        }
        if safetyTriggered {
            parts.append("safety filter")
        }
        
        guard !parts.isEmpty else {
            return "generated fresh"
        }
        
        return "influenced by: " + parts.joined(separator: ", ")
    }
}

// MARK: - EmotionResult Codable Extension

extension EmotionResult: Codable {
    enum CodingKeys: String, CodingKey {
        case primary, secondary, confidence, allScores, matchedKeywords
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primary = try container.decode(NavarasaType.self, forKey: .primary)
        secondary = try container.decodeIfPresent(NavarasaType.self, forKey: .secondary)
        confidence = try container.decode(Double.self, forKey: .confidence)
        
        let scoresDict = try container.decode([String: Int].self, forKey: .allScores)
        allScores = Dictionary(uniqueKeysWithValues: scoresDict.compactMap { key, value in
            guard let emotion = NavarasaType(rawValue: key) else { return nil }
            return (emotion, value)
        })
        
        let keywordsDict = try container.decode([String: [String]].self, forKey: .matchedKeywords)
        matchedKeywords = Dictionary(uniqueKeysWithValues: keywordsDict.compactMap { key, value in
            guard let emotion = NavarasaType(rawValue: key) else { return nil }
            return (emotion, value)
        })
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(primary, forKey: .primary)
        try container.encodeIfPresent(secondary, forKey: .secondary)
        try container.encode(confidence, forKey: .confidence)
        
        let scoresDict = Dictionary(uniqueKeysWithValues: allScores.map { ($0.key.rawValue, $0.value) })
        try container.encode(scoresDict, forKey: .allScores)
        
        let keywordsDict = Dictionary(uniqueKeysWithValues: matchedKeywords.map { ($0.key.rawValue, $0.value) })
        try container.encode(keywordsDict, forKey: .matchedKeywords)
    }
}
