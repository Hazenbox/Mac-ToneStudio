import Foundation
import OSLog

/// Service to apply proper sentence casing to text.
/// Capitalizes first letter of sentences and the pronoun "I".
actor SentenceCaseService {
    
    static let shared = SentenceCaseService()
    
    private init() {}
    
    // Brand names that should preserve their casing
    private let brandNames: Set<String> = [
        "jio", "myjio", "jiofiber", "jioairfiber", "jiomart", "jiocinema",
        "jiotv", "jiosaavn", "jiocloud", "jiomeet", "jiopay", "jiomoney",
        "jiopos", "jioswitch", "reliance", "relianceone"
    ]
    
    // Proper casing for brand names
    private let brandCasing: [String: String] = [
        "jio": "Jio",
        "myjio": "MyJio",
        "jiofiber": "JioFiber",
        "jioairfiber": "JioAirFiber",
        "jiomart": "JioMart",
        "jiocinema": "JioCinema",
        "jiotv": "JioTV",
        "jiosaavn": "JioSaavn",
        "jiocloud": "JioCloud",
        "jiomeet": "JioMeet",
        "jiopay": "JioPay",
        "jiomoney": "JioMoney",
        "jiopos": "JioPos",
        "jioswitch": "JioSwitch",
        "reliance": "Reliance",
        "relianceone": "RelianceOne"
    ]
    
    /// Apply proper sentence casing to text.
    /// - Parameter text: The input text (possibly all lowercase)
    /// - Returns: Text with proper sentence capitalization
    func applySentenceCase(to text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = text
        
        // Step 1: Capitalize first character of the text
        result = capitalizeFirstCharacter(of: result)
        
        // Step 2: Capitalize after sentence-ending punctuation
        result = capitalizeAfterPunctuation(in: result)
        
        // Step 3: Capitalize standalone "i" pronoun
        result = capitalizeIPronoun(in: result)
        
        // Step 4: Fix brand name casing
        result = fixBrandCasing(in: result)
        
        return result
    }
    
    // MARK: - Private Helpers
    
    private func capitalizeFirstCharacter(of text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + String(text.dropFirst())
    }
    
    /// Capitalize the first letter after sentence-ending punctuation (. ? !)
    private func capitalizeAfterPunctuation(in text: String) -> String {
        // Match: punctuation followed by space(s) and a lowercase letter
        let pattern = "([.?!])\\s+([a-z])"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        
        var result = text
        let nsRange = NSRange(result.startIndex..., in: result)
        
        // Find all matches and replace from end to start to preserve indices
        let matches = regex.matches(in: result, options: [], range: nsRange)
        
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3,
                  let letterRange = Range(match.range(at: 2), in: result) else {
                continue
            }
            
            let lowercaseLetter = String(result[letterRange])
            result.replaceSubrange(letterRange, with: lowercaseLetter.uppercased())
        }
        
        return result
    }
    
    /// Capitalize the pronoun "i" when it appears as a standalone word
    private func capitalizeIPronoun(in text: String) -> String {
        // Match: standalone "i" surrounded by word boundaries
        // Also handle: i'm, i'll, i've, i'd
        let patterns = [
            "\\bi\\b",           // standalone i
            "\\bi'm\\b",         // i'm
            "\\bi'll\\b",        // i'll
            "\\bi've\\b",        // i've
            "\\bi'd\\b"          // i'd
        ]
        
        var result = text
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: nsRange)
            
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let matched = String(result[range])
                
                // Only fix if it's lowercase
                if matched.first?.isLowercase == true {
                    let replacement: String
                    switch matched.lowercased() {
                    case "i": replacement = "I"
                    case "i'm": replacement = "I'm"
                    case "i'll": replacement = "I'll"
                    case "i've": replacement = "I've"
                    case "i'd": replacement = "I'd"
                    default: replacement = matched
                    }
                    result.replaceSubrange(range, with: replacement)
                }
            }
        }
        
        return result
    }
    
    /// Fix brand name casing to ensure proper capitalization
    private func fixBrandCasing(in text: String) -> String {
        var result = text
        
        for (lowercase, proper) in brandCasing {
            // Use word boundary matching to avoid partial replacements
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: lowercase))\\b"
            
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            
            let nsRange = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: nsRange,
                withTemplate: proper
            )
        }
        
        return result
    }
}
