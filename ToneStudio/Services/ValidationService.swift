import Foundation
import OSLog

actor ValidationService {
    
    static let shared = ValidationService()
    
    private let rulesService = WordingRulesService.shared
    private let safetyService = SafetyGateService.shared
    private let intentClassifier = IntentClassifierService.shared
    
    private init() {}
    
    // MARK: - Public API
    
    /// Full validation (always runs complete checks)
    func validate(_ text: String) async -> ValidationResult {
        return await validateWithConfig(text, config: .full)
    }
    
    /// Intent-aware validation (adjusts checks based on detected intent)
    func validateWithIntent(_ text: String, prompt: String? = nil) async -> ValidationResult {
        let classificationText = prompt ?? text
        let classification = await intentClassifier.classify(classificationText)
        
        Logger.validation.info("Intent: \(classification.intent.rawValue) (confidence: \(classification.confidence))")
        
        // Skip validation for general chat
        if await intentClassifier.shouldSkipValidation(for: classification.intent) {
            Logger.validation.debug("Skipping validation for intent: \(classification.intent.rawValue)")
            return ValidationResult(
                passed: true,
                score: 100,
                violations: [],
                autoFixes: [],
                processingTimeMs: 0,
                skippedReason: "intent: \(classification.intent.rawValue)"
            )
        }
        
        let config = await intentClassifier.getValidationConfig(for: classification.intent)
        return await validateWithConfig(text, config: config, intent: classification.intent)
    }
    
    /// Validation with custom configuration
    func validateWithConfig(_ text: String, config: ValidationConfig, intent: MessageIntent? = nil) async -> ValidationResult {
        let startTime = Date()
        
        async let rulesTask = rulesService.loadRules()
        let _ = try? await rulesTask
        
        var violations: [Violation] = []
        var autoFixes: [AutoFix] = []
        
        // Avoid words check (if enabled)
        if config.checkAvoidWords {
            let wordViolations = await rulesService.checkText(text)
            violations.append(contentsOf: wordViolations)
        }
        
        // Auto-fixes (if enabled)
        if config.applyAutoFixes {
            autoFixes = await rulesService.getAutoFixes(for: text)
        }
        
        // Safety check (always run for content generation)
        if config.checkAvoidWords || intent == .contentGeneration {
            let safetyResult = await safetyService.classify(text)
            for classification in safetyResult.classifications {
                if classification.level >= .moderate {
                    let violation = Violation(
                        severity: classification.level == .critical ? .error : .warning,
                        rule: "safety_\(classification.domain.rawValue)",
                        text: classification.matchedPatterns.joined(separator: ", "),
                        suggestion: classification.suggestedDisclaimer ?? "review content for safety",
                        category: "safety: \(classification.domain.displayName)",
                        autoFixable: false
                    )
                    violations.append(violation)
                }
            }
        }
        
        // Readability check (if enabled)
        if config.checkReadability {
            let readabilityGrade = calculateFleschKincaidGrade(text)
            if readabilityGrade > AppConstants.targetReadabilityGrade {
                let violation = Violation(
                    severity: config.strictMode ? .warning : .info,
                    rule: "readability",
                    text: "text readability",
                    suggestion: "simplify text to grade \(Int(AppConstants.targetReadabilityGrade)) level (current: grade \(Int(readabilityGrade)))",
                    category: "readability",
                    autoFixable: false
                )
                violations.append(violation)
            }
        }
        
        // Calculate score (higher penalty in strict mode)
        let score = calculateScore(violations: violations, textLength: text.count, strictMode: config.strictMode)
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        
        let threshold = config.strictMode ? 95 : AppConstants.trustScoreMinimum
        
        Logger.validation.info("Validated \(text.count) chars in \(elapsed)ms: score=\(score), violations=\(violations.count), config=\(config.strictMode ? "strict" : "standard")")
        
        return ValidationResult(
            passed: score >= threshold,
            score: score,
            violations: violations,
            autoFixes: autoFixes,
            processingTimeMs: elapsed,
            skippedReason: nil
        )
    }
    
    func validateQuick(_ text: String) async -> (Int, Int) {
        async let rulesTask = rulesService.loadRules()
        let _ = try? await rulesTask
        
        let violations = await rulesService.checkText(text)
        let errorCount = violations.filter { $0.severity == .error }.count
        let warningCount = violations.filter { $0.severity == .warning }.count
        
        return (errorCount, warningCount)
    }
    
    /// Validate for specific channel with its guidelines
    func validateForChannel(_ text: String, channel: ContentChannelType) async -> ChannelAwareValidationResult {
        let baseResult = await validate(text)
        let channelResult = await ChannelGuidelinesService.shared.validateContent(text, for: channel)
        let preset = await ChannelGuidelinesService.shared.getWarmthDetailPreset(for: channel)
        
        var allIssues = baseResult.violations.map { $0.suggestion }
        allIssues.append(contentsOf: channelResult.issues)
        
        return ChannelAwareValidationResult(
            baseValidation: baseResult,
            channelValidation: channelResult,
            suggestedWarmth: preset.warmth,
            suggestedDetail: preset.detail,
            channel: channel
        )
    }
    
    func getViolationsWithPositions(_ text: String) async -> [Violation] {
        async let rulesTask = rulesService.loadRules()
        let _ = try? await rulesTask
        
        return await rulesService.checkText(text)
    }
    
    // MARK: - Readability (Flesch-Kincaid)
    
    /// Calculates Flesch Reading Ease score (0-100, higher = easier to read)
    /// Target: 60-70 for general audience (Grade 8-9)
    func calculateReadabilityScore(_ text: String) -> Double {
        let sentences = countSentences(text)
        let words = countWords(text)
        let syllables = countSyllables(text)
        
        guard sentences > 0, words > 0 else { return 100 }
        
        // Flesch Reading Ease formula
        let averageSentenceLength = Double(words) / Double(sentences)
        let averageSyllablesPerWord = Double(syllables) / Double(words)
        
        let fleschReadingEase = 206.835 - (1.015 * averageSentenceLength) - (84.6 * averageSyllablesPerWord)
        return min(100, max(0, fleschReadingEase))
    }
    
    /// Calculates Flesch-Kincaid Grade Level (US school grade)
    /// Target: Grade 8 (equivalent to 13-14 year old reading level)
    func calculateFleschKincaidGrade(_ text: String) -> Double {
        let sentences = countSentences(text)
        let words = countWords(text)
        let syllables = countSyllables(text)
        
        guard sentences > 0, words > 0 else { return 0 }
        
        // Flesch-Kincaid Grade Level formula
        let averageSentenceLength = Double(words) / Double(sentences)
        let averageSyllablesPerWord = Double(syllables) / Double(words)
        
        let gradeLevel = (0.39 * averageSentenceLength) + (11.8 * averageSyllablesPerWord) - 15.59
        return max(0, gradeLevel)
    }
    
    /// Returns detailed readability analysis
    func getReadabilityAnalysis(_ text: String) -> ReadabilityAnalysis {
        let sentences = countSentences(text)
        let words = countWords(text)
        let syllables = countSyllables(text)
        let complexWords = countComplexWords(text)
        
        let fleschReadingEase = calculateReadabilityScore(text)
        let fleschKincaidGrade = calculateFleschKincaidGrade(text)
        let gunningFogIndex = calculateGunningFogIndex(sentences: sentences, words: words, complexWords: complexWords)
        
        let targetGrade = AppConstants.targetReadabilityGrade
        let meetsTarget = fleschKincaidGrade <= targetGrade
        
        var suggestions: [String] = []
        if !meetsTarget {
            if Double(words) / Double(max(1, sentences)) > 20 {
                suggestions.append("shorten sentences (aim for 15-20 words per sentence)")
            }
            if Double(syllables) / Double(max(1, words)) > 1.5 {
                suggestions.append("use simpler words with fewer syllables")
            }
            if Double(complexWords) / Double(max(1, words)) > 0.1 {
                suggestions.append("reduce complex words (3+ syllables)")
            }
        }
        
        return ReadabilityAnalysis(
            fleschReadingEase: fleschReadingEase,
            fleschKincaidGrade: fleschKincaidGrade,
            gunningFogIndex: gunningFogIndex,
            targetGrade: targetGrade,
            meetsTarget: meetsTarget,
            sentenceCount: sentences,
            wordCount: words,
            syllableCount: syllables,
            complexWordCount: complexWords,
            averageSentenceLength: Double(words) / Double(max(1, sentences)),
            averageSyllablesPerWord: Double(syllables) / Double(max(1, words)),
            suggestions: suggestions
        )
    }
    
    /// Legacy method for backward compatibility
    func getReadabilityGrade(_ text: String) -> Double {
        return calculateFleschKincaidGrade(text)
    }
    
    // Gunning Fog Index - alternative readability metric
    private func calculateGunningFogIndex(sentences: Int, words: Int, complexWords: Int) -> Double {
        guard sentences > 0, words > 0 else { return 0 }
        
        let averageSentenceLength = Double(words) / Double(sentences)
        let percentComplexWords = Double(complexWords) / Double(words) * 100
        
        return 0.4 * (averageSentenceLength + percentComplexWords)
    }
    
    private func countComplexWords(_ text: String) -> Int {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        return words.filter { word in
            !word.isEmpty && countSyllablesInWord(word) >= 3
        }.count
    }
    
    // MARK: - Private Helpers
    
    private func calculateScore(violations: [Violation], textLength: Int, strictMode: Bool = false) -> Int {
        var score = 100
        
        let errorPenalty = strictMode ? 20 : 15
        let warningPenalty = strictMode ? 8 : 5
        let infoPenalty = strictMode ? 3 : 2
        
        for violation in violations {
            switch violation.severity {
            case .error:
                score -= errorPenalty
            case .warning:
                score -= warningPenalty
            case .info:
                score -= infoPenalty
            }
        }
        
        return max(0, score)
    }
    
    private func countSentences(_ text: String) -> Int {
        let pattern = "[.!?]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 1 }
        let range = NSRange(text.startIndex..., in: text)
        return max(1, regex.numberOfMatches(in: text, range: range))
    }
    
    private func countWords(_ text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    private func countSyllables(_ text: String) -> Int {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var totalSyllables = 0
        
        for word in words where !word.isEmpty {
            totalSyllables += countSyllablesInWord(word)
        }
        
        return max(1, totalSyllables)
    }
    
    private func countSyllablesInWord(_ word: String) -> Int {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var previousWasVowel = false
        
        let cleanWord = word.filter { $0.isLetter }
        
        for char in cleanWord {
            let isVowel = vowels.contains(char)
            if isVowel && !previousWasVowel {
                count += 1
            }
            previousWasVowel = isVowel
        }
        
        if cleanWord.hasSuffix("e") && count > 1 {
            count -= 1
        }
        
        return max(1, count)
    }
}

// MARK: - Readability Analysis Model

struct ReadabilityAnalysis: Codable {
    let fleschReadingEase: Double       // 0-100 (higher = easier)
    let fleschKincaidGrade: Double      // US school grade level
    let gunningFogIndex: Double         // Alternative metric
    let targetGrade: Double             // Target grade (8.0)
    let meetsTarget: Bool               // Whether content meets target
    let sentenceCount: Int
    let wordCount: Int
    let syllableCount: Int
    let complexWordCount: Int           // Words with 3+ syllables
    let averageSentenceLength: Double
    let averageSyllablesPerWord: Double
    let suggestions: [String]           // Improvement suggestions
    
    var gradeDescription: String {
        let grade = fleschKincaidGrade
        if grade <= 5 { return "grade 5 (very easy)" }
        if grade <= 6 { return "grade 6 (easy)" }
        if grade <= 7 { return "grade 7 (fairly easy)" }
        if grade <= 8 { return "grade 8 (standard)" }
        if grade <= 9 { return "grade 9 (fairly difficult)" }
        if grade <= 10 { return "grade 10 (difficult)" }
        if grade <= 12 { return "grade 11-12 (very difficult)" }
        return "college level (advanced)"
    }
    
    var readabilityCategory: String {
        let score = fleschReadingEase
        if score >= 90 { return "very easy" }
        if score >= 80 { return "easy" }
        if score >= 70 { return "fairly easy" }
        if score >= 60 { return "standard" }
        if score >= 50 { return "fairly difficult" }
        if score >= 30 { return "difficult" }
        return "very difficult"
    }
}

// MARK: - Channel-Aware Validation Result

struct ChannelAwareValidationResult {
    let baseValidation: ValidationResult
    let channelValidation: ChannelValidationResult
    let suggestedWarmth: Int
    let suggestedDetail: Int
    let channel: ContentChannelType
    
    var overallPassed: Bool {
        baseValidation.passed && channelValidation.passed
    }
    
    var allIssues: [String] {
        var issues = baseValidation.violations.map { $0.suggestion }
        issues.append(contentsOf: channelValidation.issues)
        return issues
    }
    
    var allWarnings: [String] {
        channelValidation.warnings
    }
    
    var summary: String {
        if overallPassed {
            return "content meets \(channel.displayName) guidelines"
        }
        let issueCount = baseValidation.violations.count + channelValidation.issues.count
        return "\(issueCount) issue(s) found for \(channel.displayName)"
    }
}

