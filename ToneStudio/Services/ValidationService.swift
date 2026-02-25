import Foundation
import OSLog

actor ValidationService {
    
    static let shared = ValidationService()
    
    private let rulesService = WordingRulesService.shared
    private let safetyService = SafetyGateService.shared
    
    private init() {}
    
    // MARK: - Public API
    
    func validate(_ text: String) async -> ValidationResult {
        let startTime = Date()
        
        async let rulesTask = rulesService.loadRules()
        let _ = try? await rulesTask
        
        var violations: [Violation] = []
        var autoFixes: [AutoFix] = []
        
        let wordViolations = await rulesService.checkText(text)
        violations.append(contentsOf: wordViolations)
        
        autoFixes = await rulesService.getAutoFixes(for: text)
        
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
        
        let readabilityScore = calculateReadabilityScore(text)
        if readabilityScore < 60 {
            let violation = Violation(
                severity: .info,
                rule: "readability",
                text: "text readability",
                suggestion: "consider simplifying the text for better readability (grade \(Int(readabilityScore / 10)) target: grade 8)",
                category: "readability",
                autoFixable: false
            )
            violations.append(violation)
        }
        
        let score = calculateScore(violations: violations, textLength: text.count)
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        
        Logger.validation.info("Validated \(text.count) chars in \(elapsed)ms: score=\(score), violations=\(violations.count)")
        
        return ValidationResult(
            passed: score >= AppConstants.trustScoreMinimum,
            score: score,
            violations: violations,
            autoFixes: autoFixes,
            processingTimeMs: elapsed
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
    
    func getViolationsWithPositions(_ text: String) async -> [Violation] {
        async let rulesTask = rulesService.loadRules()
        let _ = try? await rulesTask
        
        return await rulesService.checkText(text)
    }
    
    // MARK: - Readability
    
    func calculateReadabilityScore(_ text: String) -> Double {
        let sentences = countSentences(text)
        let words = countWords(text)
        let syllables = countSyllables(text)
        
        guard sentences > 0, words > 0 else { return 100 }
        
        let fleschKincaid = 206.835 - (1.015 * Double(words) / Double(sentences)) - (84.6 * Double(syllables) / Double(words))
        return min(100, max(0, fleschKincaid))
    }
    
    func getReadabilityGrade(_ text: String) -> Double {
        let score = calculateReadabilityScore(text)
        if score >= 90 { return 5 }
        if score >= 80 { return 6 }
        if score >= 70 { return 7 }
        if score >= 60 { return 8 }
        if score >= 50 { return 9 }
        if score >= 40 { return 10 }
        if score >= 30 { return 11 }
        return 12
    }
    
    // MARK: - Private Helpers
    
    private func calculateScore(violations: [Violation], textLength: Int) -> Int {
        var score = 100
        
        for violation in violations {
            switch violation.severity {
            case .error:
                score -= 15
            case .warning:
                score -= 5
            case .info:
                score -= 2
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

