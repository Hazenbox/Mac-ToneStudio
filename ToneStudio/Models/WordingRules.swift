import Foundation

// MARK: - Rule Severity

enum RuleSeverity: String, Codable, CaseIterable {
    case error      // Must fix - fear-based, shame-inducing
    case warning    // Should fix - complex, robotic, bureaucratic
    case info       // Suggestion - technical terms, style improvements
    
    var weight: Double {
        switch self {
        case .error: return 1.0
        case .warning: return 0.5
        case .info: return 0.25
        }
    }
}

// MARK: - Avoid Word Categories (10 total)

enum AvoidWordCategory: String, Codable, CaseIterable {
    case complex            // utilize, leverage, synergy, paradigm
    case robotic            // auto-generated, system generated, do not reply
    case fearBased          // urgent, hurry, last chance, final warning
    case bureaucratic       // terms and conditions apply, pursuant to
    case technical          // backend, API, cache, latency
    case shameInducing      // you forgot, your fault, your mistake
    case elitist            // premium, exclusive, elite, VIP
    case marketingJargon    // game-changing, cutting-edge, best-in-class
    case americanSpelling   // color->colour, center->centre
    case incorrectFormat    // PIN number, ATM machine
    
    var displayName: String {
        switch self {
        case .complex: return "complex words"
        case .robotic: return "robotic language"
        case .fearBased: return "fear-based"
        case .bureaucratic: return "bureaucratic"
        case .technical: return "technical jargon"
        case .shameInducing: return "shame-inducing"
        case .elitist: return "elitist"
        case .marketingJargon: return "marketing jargon"
        case .americanSpelling: return "american spelling"
        case .incorrectFormat: return "incorrect format"
        }
    }
    
    var defaultSeverity: RuleSeverity {
        switch self {
        case .fearBased, .shameInducing:
            return .error
        case .complex, .robotic, .bureaucratic, .elitist, .marketingJargon:
            return .warning
        case .technical, .americanSpelling, .incorrectFormat:
            return .info
        }
    }
    
    var description: String {
        switch self {
        case .complex:
            return "complex words that can be simplified"
        case .robotic:
            return "robotic, impersonal language"
        case .fearBased:
            return "fear-based messaging that creates anxiety"
        case .bureaucratic:
            return "bureaucratic, legal-sounding language"
        case .technical:
            return "technical jargon not meant for users"
        case .shameInducing:
            return "language that blames or shames the user"
        case .elitist:
            return "elitist language that excludes people"
        case .marketingJargon:
            return "overused marketing buzzwords"
        case .americanSpelling:
            return "american spelling (use british for india)"
        case .incorrectFormat:
            return "redundant or incorrect format"
        }
    }
}

// MARK: - Preferred Word Categories (6 total)

enum PreferredWordCategory: String, Codable, CaseIterable {
    case careConnection     // thank you, appreciate, always with you
    case actionProgress     // start, ready, keep going, almost done
    case claritySafety      // you're safe, all okay, safe to continue
    case fixingResolution   // checking this, all fixed, done
    case communityFirst     // growth with purpose, made in india
    case learningDiscovery  // see what's new, trending now
    
    var displayName: String {
        switch self {
        case .careConnection: return "care & connection"
        case .actionProgress: return "action & progress"
        case .claritySafety: return "clarity & safety"
        case .fixingResolution: return "fixing & resolution"
        case .communityFirst: return "community first"
        case .learningDiscovery: return "learning & discovery"
        }
    }
    
    var emotionalGoal: String {
        switch self {
        case .careConnection:
            return "show empathy and build trust"
        case .actionProgress:
            return "motivate and show momentum"
        case .claritySafety:
            return "reassure and reduce anxiety"
        case .fixingResolution:
            return "acknowledge and resolve issues"
        case .communityFirst:
            return "celebrate indian identity and values"
        case .learningDiscovery:
            return "spark curiosity and engagement"
        }
    }
}

// MARK: - Avoid Word Model

struct AvoidWord: Codable, Identifiable, Hashable {
    let id: UUID
    let word: String
    let category: AvoidWordCategory
    let severity: RuleSeverity
    let suggestion: String?
    let context: String?
    
    init(id: UUID = UUID(), word: String, category: AvoidWordCategory, 
         severity: RuleSeverity? = nil, suggestion: String? = nil, context: String? = nil) {
        self.id = id
        self.word = word.lowercased()
        self.category = category
        self.severity = severity ?? category.defaultSeverity
        self.suggestion = suggestion
        self.context = context
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
    
    static func == (lhs: AvoidWord, rhs: AvoidWord) -> Bool {
        lhs.word == rhs.word
    }
}

// MARK: - Preferred Word Model

struct PreferredWord: Codable, Identifiable, Hashable {
    let id: UUID
    let word: String
    let category: PreferredWordCategory
    let emotionalGoal: String
    let usageExample: String?
    
    init(id: UUID = UUID(), word: String, category: PreferredWordCategory,
         emotionalGoal: String? = nil, usageExample: String? = nil) {
        self.id = id
        self.word = word.lowercased()
        self.category = category
        self.emotionalGoal = emotionalGoal ?? category.emotionalGoal
        self.usageExample = usageExample
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
    
    static func == (lhs: PreferredWord, rhs: PreferredWord) -> Bool {
        lhs.word == rhs.word
    }
}

// MARK: - Auto-Fix Rule Model

struct AutoFixRule: Codable, Identifiable, Hashable {
    let id: UUID
    let original: String
    let replacement: String
    let category: AutoFixCategory
    let confidence: Double      // 0-1, higher = safer to auto-apply
    let caseSensitive: Bool
    let wholeWord: Bool
    
    init(id: UUID = UUID(), original: String, replacement: String, 
         category: AutoFixCategory, confidence: Double = 0.9,
         caseSensitive: Bool = false, wholeWord: Bool = true) {
        self.id = id
        self.original = original
        self.replacement = replacement
        self.category = category
        self.confidence = min(1.0, max(0.0, confidence))
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(original)
        hasher.combine(replacement)
    }
    
    static func == (lhs: AutoFixRule, rhs: AutoFixRule) -> Bool {
        lhs.original == rhs.original && lhs.replacement == rhs.replacement
    }
}

enum AutoFixCategory: String, Codable, CaseIterable {
    case genderNeutral      // chairman -> chairperson
    case simpleAlternative  // utilize -> use
    case britishSpelling    // color -> colour
    case formatCorrection   // PIN number -> PIN
    case inclusiveLanguage  // disabled -> person with disability
    
    var displayName: String {
        switch self {
        case .genderNeutral: return "gender-neutral"
        case .simpleAlternative: return "simpler alternative"
        case .britishSpelling: return "british spelling"
        case .formatCorrection: return "format correction"
        case .inclusiveLanguage: return "inclusive language"
        }
    }
}

// MARK: - Violation Model

struct Violation: Codable, Identifiable {
    let id: UUID
    let severity: RuleSeverity
    let rule: String
    let text: String
    let suggestion: String
    let category: String
    let position: TextRange?
    let autoFixable: Bool
    
    struct TextRange: Codable {
        let start: Int
        let end: Int
    }
    
    init(id: UUID = UUID(), severity: RuleSeverity, rule: String, text: String,
         suggestion: String, category: String, position: TextRange? = nil, autoFixable: Bool = false) {
        self.id = id
        self.severity = severity
        self.rule = rule
        self.text = text
        self.suggestion = suggestion
        self.category = category
        self.position = position
        self.autoFixable = autoFixable
    }
}

// MARK: - Auto-Fix Model

struct AutoFix: Codable, Identifiable {
    let id: UUID
    let original: String
    let replacement: String
    let confidence: Double
    let rule: String
    let violation: Violation
    
    init(id: UUID = UUID(), original: String, replacement: String, 
         confidence: Double, rule: String, violation: Violation) {
        self.id = id
        self.original = original
        self.replacement = replacement
        self.confidence = confidence
        self.rule = rule
        self.violation = violation
    }
}

// MARK: - Auto-Fix Preview

struct AutoFixPreview: Codable {
    let originalContent: String
    let fixedContent: String
    let appliedFixes: [AutoFix]
    var isPending: Bool
    
    var fixCount: Int {
        appliedFixes.count
    }
}

// MARK: - Validation Result

struct ValidationResult: Codable {
    let passed: Bool
    let score: Int              // 0-100
    let violations: [Violation]
    let autoFixes: [AutoFix]
    let processingTimeMs: Double
    
    var errorCount: Int {
        violations.filter { $0.severity == .error }.count
    }
    
    var warningCount: Int {
        violations.filter { $0.severity == .warning }.count
    }
    
    var infoCount: Int {
        violations.filter { $0.severity == .info }.count
    }
    
    var autoFixableCount: Int {
        violations.filter { $0.autoFixable }.count
    }
    
    static let perfect = ValidationResult(
        passed: true,
        score: 100,
        violations: [],
        autoFixes: [],
        processingTimeMs: 0
    )
}

// MARK: - Wording Rules Container

struct WordingRulesData: Codable {
    let avoidWords: [AvoidWord]
    let preferredWords: [PreferredWord]
    let autoFixRules: [AutoFixRule]
    let version: String
    let lastUpdated: Date
    
    init(avoidWords: [AvoidWord] = [], preferredWords: [PreferredWord] = [],
         autoFixRules: [AutoFixRule] = [], version: String = "1.0.0") {
        self.avoidWords = avoidWords
        self.preferredWords = preferredWords
        self.autoFixRules = autoFixRules
        self.version = version
        self.lastUpdated = Date()
    }
}
