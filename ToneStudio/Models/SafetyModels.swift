import Foundation

// MARK: - Safety Domain

enum SafetyDomain: String, Codable, CaseIterable {
    case health         // Medical advice, health claims
    case mentalHealth   // Mental health, suicide, self-harm
    case financial      // Investment advice, financial promises
    case legal          // Legal advice, disclaimers needed
    case privacy        // Personal data, PII
    case emergency      // Crisis situations, urgent help
    case violence       // Violence, threats, harm
    case substance      // Drugs, alcohol, tobacco
    case gambling       // Betting, gambling
    case minors         // Content involving children
    case political      // Political content
    case religious      // Religious content
    
    var displayName: String {
        switch self {
        case .health: return "health"
        case .mentalHealth: return "mental health"
        case .financial: return "financial"
        case .legal: return "legal"
        case .privacy: return "privacy"
        case .emergency: return "emergency"
        case .violence: return "violence"
        case .substance: return "substance"
        case .gambling: return "gambling"
        case .minors: return "minors"
        case .political: return "political"
        case .religious: return "religious"
        }
    }
    
    var requiresDisclaimer: Bool {
        switch self {
        case .health, .financial, .legal:
            return true
        default:
            return false
        }
    }
}

// MARK: - Safety Level

enum SafetyLevel: String, Codable, CaseIterable, Comparable {
    case none       // No safety concerns
    case low        // Minor concerns, proceed with care
    case moderate   // Notable concerns, add disclaimers
    case high       // Significant concerns, modify response
    case critical   // Block or emergency response
    
    var weight: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
    
    static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.weight < rhs.weight
    }
}

// MARK: - Safety Routing

enum SafetyRouting: String, Codable {
    case proceedNormal          // No modifications needed
    case proceedWithDisclaimer  // Add appropriate disclaimer
    case proceedModified        // Modify tone/content
    case emergencyResponse      // Use pre-defined emergency response
    case blockAndLog            // Block the request entirely
    
    var description: String {
        switch self {
        case .proceedNormal:
            return "proceed normally"
        case .proceedWithDisclaimer:
            return "add disclaimer"
        case .proceedModified:
            return "modify response"
        case .emergencyResponse:
            return "emergency response"
        case .blockAndLog:
            return "blocked"
        }
    }
}

// MARK: - Safety Classification

struct SafetyClassification: Codable {
    let domain: SafetyDomain
    let level: SafetyLevel
    let confidence: Double      // 0-1
    let matchedPatterns: [String]
    let suggestedDisclaimer: String?
    
    init(domain: SafetyDomain, level: SafetyLevel, confidence: Double = 1.0,
         matchedPatterns: [String] = [], suggestedDisclaimer: String? = nil) {
        self.domain = domain
        self.level = level
        self.confidence = min(1.0, max(0.0, confidence))
        self.matchedPatterns = matchedPatterns
        self.suggestedDisclaimer = suggestedDisclaimer
    }
}

// MARK: - Generation Modifications

struct GenerationModifications: Codable {
    var maxWarmth: Int?             // Limit warmth for sensitive topics
    var toneLock: String?           // Force specific tone
    var blockNudging: Bool          // Prevent persuasive language
    var requiredDisclaimer: String? // Disclaimer to add
    var emergencyInfo: EmergencyInfo?
    
    init(maxWarmth: Int? = nil, toneLock: String? = nil, blockNudging: Bool = false,
         requiredDisclaimer: String? = nil, emergencyInfo: EmergencyInfo? = nil) {
        self.maxWarmth = maxWarmth
        self.toneLock = toneLock
        self.blockNudging = blockNudging
        self.requiredDisclaimer = requiredDisclaimer
        self.emergencyInfo = emergencyInfo
    }
    
    static let none = GenerationModifications()
}

// MARK: - Emergency Info

struct EmergencyInfo: Codable {
    let helplines: [Helpline]
    let resources: [String]
    let immediateMessage: String
    
    struct Helpline: Codable {
        let name: String
        let number: String
        let description: String
        let available24x7: Bool
    }
}

// MARK: - Safety Gate Result

struct SafetyGateResult: Codable {
    let routing: SafetyRouting
    let classifications: [SafetyClassification]
    let modifications: GenerationModifications
    let blockedReason: String?
    let processingTimeMs: Double
    
    var highestLevel: SafetyLevel {
        classifications.map { $0.level }.max() ?? .none
    }
    
    var primaryDomain: SafetyDomain? {
        classifications.max(by: { $0.level < $1.level })?.domain
    }
    
    var shouldProceed: Bool {
        routing != .blockAndLog
    }
    
    var requiresModification: Bool {
        routing == .proceedModified || routing == .proceedWithDisclaimer
    }
    
    static let safe = SafetyGateResult(
        routing: .proceedNormal,
        classifications: [],
        modifications: .none,
        blockedReason: nil,
        processingTimeMs: 0
    )
}

// MARK: - Safety Pattern

struct SafetyPattern: Codable {
    let pattern: String
    let domain: SafetyDomain
    let level: SafetyLevel
    let isRegex: Bool
    let description: String
    
    init(pattern: String, domain: SafetyDomain, level: SafetyLevel,
         isRegex: Bool = false, description: String = "") {
        self.pattern = pattern
        self.domain = domain
        self.level = level
        self.isRegex = isRegex
        self.description = description
    }
}
