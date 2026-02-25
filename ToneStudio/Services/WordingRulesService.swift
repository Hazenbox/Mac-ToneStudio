import Foundation
import OSLog

actor WordingRulesService {
    
    static let shared = WordingRulesService()
    
    private var avoidWords: [AvoidWord] = []
    private var preferredWords: [PreferredWord] = []
    private var autoFixRules: [AutoFixRule] = []
    
    private var avoidWordSet: Set<String> = []
    private var autoFixMap: [String: AutoFixRule] = [:]
    
    private var isLoaded = false
    private var lastSyncTime: Date?
    
    private let cacheKey = "wordingRulesCache"
    private let cacheDirectory: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("ToneStudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public API
    
    func loadRules() async throws {
        if isLoaded { return }
        
        if let cached = loadFromCache() {
            applyRulesData(cached)
            Logger.rules.info("Loaded \(self.avoidWords.count) avoid words, \(self.preferredWords.count) preferred words from cache")
        }
        
        loadBundledRules()
        isLoaded = true
        
        Logger.rules.info("Rules loaded: \(self.avoidWords.count) avoid, \(self.preferredWords.count) preferred, \(self.autoFixRules.count) auto-fix")
    }
    
    func getAvoidWords(category: AvoidWordCategory? = nil) -> [AvoidWord] {
        guard let category = category else { return avoidWords }
        return avoidWords.filter { $0.category == category }
    }
    
    func getPreferredWords(category: PreferredWordCategory? = nil) -> [PreferredWord] {
        guard let category = category else { return preferredWords }
        return preferredWords.filter { $0.category == category }
    }
    
    func getAutoFixRules(category: AutoFixCategory? = nil) -> [AutoFixRule] {
        guard let category = category else { return autoFixRules }
        return autoFixRules.filter { $0.category == category }
    }
    
    func checkText(_ text: String) -> [Violation] {
        let startTime = Date()
        var violations: [Violation] = []
        let words = extractWords(from: text)
        let lowerText = text.lowercased()
        
        for word in words {
            let lowerWord = word.lowercased()
            
            for avoidWord in avoidWords {
                if lowerWord == avoidWord.word || lowerText.contains(avoidWord.word) {
                    if let range = lowerText.range(of: avoidWord.word) {
                        let start = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)
                        let end = lowerText.distance(from: lowerText.startIndex, to: range.upperBound)
                        
                        let hasAutoFix = autoFixMap[avoidWord.word] != nil
                        
                        let violation = Violation(
                            severity: avoidWord.severity,
                            rule: "avoid_word_\(avoidWord.category.rawValue)",
                            text: avoidWord.word,
                            suggestion: avoidWord.suggestion ?? "consider removing or rephrasing",
                            category: avoidWord.category.displayName,
                            position: Violation.TextRange(start: start, end: end),
                            autoFixable: hasAutoFix
                        )
                        violations.append(violation)
                        break
                    }
                }
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        Logger.rules.debug("Checked text (\(text.count) chars) in \(elapsed)ms, found \(violations.count) violations")
        
        return violations
    }
    
    func getAutoFixes(for text: String) -> [AutoFix] {
        var fixes: [AutoFix] = []
        let lowerText = text.lowercased()
        
        for rule in autoFixRules {
            let searchText = rule.caseSensitive ? text : lowerText
            let searchPattern = rule.caseSensitive ? rule.original : rule.original.lowercased()
            
            if rule.wholeWord {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: searchPattern))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: rule.caseSensitive ? [] : .caseInsensitive),
                   regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                    
                    let violation = Violation(
                        severity: .info,
                        rule: "auto_fix_\(rule.category.rawValue)",
                        text: rule.original,
                        suggestion: "replace with '\(rule.replacement)'",
                        category: rule.category.displayName,
                        autoFixable: true
                    )
                    
                    let fix = AutoFix(
                        original: rule.original,
                        replacement: rule.replacement,
                        confidence: rule.confidence,
                        rule: rule.category.displayName,
                        violation: violation
                    )
                    fixes.append(fix)
                }
            } else if searchText.contains(searchPattern) {
                let violation = Violation(
                    severity: .info,
                    rule: "auto_fix_\(rule.category.rawValue)",
                    text: rule.original,
                    suggestion: "replace with '\(rule.replacement)'",
                    category: rule.category.displayName,
                    autoFixable: true
                )
                
                let fix = AutoFix(
                    original: rule.original,
                    replacement: rule.replacement,
                    confidence: rule.confidence,
                    rule: rule.category.displayName,
                    violation: violation
                )
                fixes.append(fix)
            }
        }
        
        return fixes
    }
    
    func applyFix(_ fix: AutoFix, to text: String) -> String {
        let rule = autoFixRules.first { $0.original.lowercased() == fix.original.lowercased() }
        
        if let rule = rule, rule.wholeWord {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: fix.original))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: rule.caseSensitive ? [] : .caseInsensitive) {
                return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: fix.replacement)
            }
        }
        
        return text.replacingOccurrences(of: fix.original, with: fix.replacement, options: .caseInsensitive)
    }
    
    func applyAllFixes(to text: String) -> AutoFixPreview {
        var result = text
        var appliedFixes: [AutoFix] = []
        
        let fixes = getAutoFixes(for: text)
        for fix in fixes {
            let before = result
            result = applyFix(fix, to: result)
            if result != before {
                appliedFixes.append(fix)
            }
        }
        
        return AutoFixPreview(
            originalContent: text,
            fixedContent: result,
            appliedFixes: appliedFixes,
            isPending: true
        )
    }
    
    // MARK: - Sync
    
    func syncFromServer() async throws {
        Logger.rules.info("Syncing rules from server...")
        lastSyncTime = Date()
    }
    
    func getLastSyncTime() -> Date? {
        return lastSyncTime
    }
    
    func needsSync() -> Bool {
        guard let lastSync = lastSyncTime else { return true }
        return Date().timeIntervalSince(lastSync) > AppConstants.cacheTTLKnowledge
    }
    
    // MARK: - Private Helpers
    
    private func extractWords(from text: String) -> [String] {
        let pattern = "\\b\\w+\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
    
    private func applyRulesData(_ data: WordingRulesData) {
        self.avoidWords = data.avoidWords
        self.preferredWords = data.preferredWords
        self.autoFixRules = data.autoFixRules
        
        self.avoidWordSet = Set(data.avoidWords.map { $0.word })
        self.autoFixMap = Dictionary(uniqueKeysWithValues: data.autoFixRules.map { ($0.original.lowercased(), $0) })
    }
    
    private func loadFromCache() -> WordingRulesData? {
        let cacheFile = cacheDirectory.appendingPathComponent("rules.json")
        guard let data = try? Data(contentsOf: cacheFile),
              let rules = try? JSONDecoder().decode(WordingRulesData.self, from: data) else {
            return nil
        }
        return rules
    }
    
    private func saveToCache(_ rules: WordingRulesData) {
        let cacheFile = cacheDirectory.appendingPathComponent("rules.json")
        guard let data = try? JSONEncoder().encode(rules) else { return }
        try? data.write(to: cacheFile)
    }
    
    private func loadBundledRules() {
        avoidWords = DefaultWordingRules.avoidWords
        preferredWords = DefaultWordingRules.preferredWords
        autoFixRules = DefaultWordingRules.autoFixRules
        
        avoidWordSet = Set(avoidWords.map { $0.word })
        autoFixMap = Dictionary(uniqueKeysWithValues: autoFixRules.map { ($0.original.lowercased(), $0) })
    }
}

