import Foundation
import OSLog

actor AutoFixService {
    
    static let shared = AutoFixService()
    
    private let rulesService = WordingRulesService.shared
    
    private init() {}
    
    // MARK: - Public API
    
    func detectFixes(in text: String) async -> [AutoFix] {
        try? await rulesService.loadRules()
        return await rulesService.getAutoFixes(for: text)
    }
    
    func applyFix(_ fix: AutoFix, to text: String) async -> String {
        return await rulesService.applyFix(fix, to: text)
    }
    
    func applyAllFixes(to text: String) async -> AutoFixPreview {
        try? await rulesService.loadRules()
        return await rulesService.applyAllFixes(to: text)
    }
    
    func previewFix(_ fix: AutoFix, in text: String) -> AutoFixPreview {
        var result = text
        
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: fix.original))\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: fix.replacement
            )
        }
        
        return AutoFixPreview(
            originalContent: text,
            fixedContent: result,
            appliedFixes: [fix],
            isPending: true
        )
    }
    
    func getFixes(for violations: [Violation]) async -> [AutoFix] {
        let allFixes = await rulesService.getAutoFixRules()
        var fixes: [AutoFix] = []
        
        for violation in violations where violation.autoFixable {
            if let rule = allFixes.first(where: { $0.original.lowercased() == violation.text.lowercased() }) {
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
    
    func getFixCount(for text: String) async -> Int {
        let fixes = await detectFixes(in: text)
        return fixes.count
    }
    
    func applyFixesWithTracking(to text: String) async -> (String, [AutoFix]) {
        let preview = await applyAllFixes(to: text)
        return (preview.fixedContent, preview.appliedFixes)
    }
}

// MARK: - AutoFix Preview Helpers

extension AutoFixPreview {
    
    var hasChanges: Bool {
        originalContent != fixedContent
    }
    
    func getDiff() -> [(range: Range<String.Index>, type: DiffType, text: String)] {
        var diffs: [(Range<String.Index>, DiffType, String)] = []
        
        for fix in appliedFixes {
            if let range = originalContent.range(of: fix.original, options: .caseInsensitive) {
                diffs.append((range, .removed, fix.original))
            }
            if let range = fixedContent.range(of: fix.replacement, options: .caseInsensitive) {
                diffs.append((range, .added, fix.replacement))
            }
        }
        
        return diffs
    }
    
    enum DiffType {
        case removed
        case added
        case unchanged
    }
}

// MARK: - Category Statistics

struct AutoFixCategoryStats {
    let category: AutoFixCategory
    let count: Int
    let examples: [AutoFix]
}

extension AutoFixService {
    
    func getStatsByCategory(for text: String) async -> [AutoFixCategoryStats] {
        let fixes = await detectFixes(in: text)
        var categoryMap: [AutoFixCategory: [AutoFix]] = [:]
        
        for fix in fixes {
            let rule = await rulesService.getAutoFixRules().first { $0.original.lowercased() == fix.original.lowercased() }
            let category = rule?.category ?? .simpleAlternative
            categoryMap[category, default: []].append(fix)
        }
        
        return categoryMap.map { category, fixes in
            AutoFixCategoryStats(
                category: category,
                count: fixes.count,
                examples: Array(fixes.prefix(3))
            )
        }.sorted { $0.count > $1.count }
    }
}
