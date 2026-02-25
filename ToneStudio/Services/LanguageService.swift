import Foundation
import os.log

actor LanguageService {
    
    static let shared = LanguageService()
    
    // MARK: - Properties
    
    private var currentLanguage: SupportedLanguage = .english
    private var currentRegion: IndianRegion = .panIndia
    
    // MARK: - Language Detection
    
    func detectLanguage(in text: String) -> LanguageDetectionResult {
        let lowercased = text.lowercased()
        
        // Check for Hinglish first (mixed Hindi-English)
        if isHinglish(text) {
            return LanguageDetectionResult(language: .hinglish, confidence: 0.85, mixedLanguages: [.hindi, .english])
        }
        
        // Check for Devanagari script (Hindi, Marathi, Sanskrit)
        if containsDevanagari(text) {
            let specifics = detectDevanagariSpecific(text)
            return LanguageDetectionResult(language: specifics, confidence: 0.9, mixedLanguages: [])
        }
        
        // Check for other Indian scripts
        if let detectedScript = detectIndianScript(text) {
            return LanguageDetectionResult(language: detectedScript, confidence: 0.9, mixedLanguages: [])
        }
        
        // Check for Hindi words in Roman script
        let hindiRomanScore = detectHindiRoman(lowercased)
        if hindiRomanScore > 0.3 {
            return LanguageDetectionResult(language: .hinglish, confidence: hindiRomanScore, mixedLanguages: [.hindi, .english])
        }
        
        // Default to English
        return LanguageDetectionResult(language: .english, confidence: 0.7, mixedLanguages: [])
    }
    
    private func isHinglish(_ text: String) -> Bool {
        let hasEnglish = text.range(of: "[a-zA-Z]", options: .regularExpression) != nil
        let hasHindiIndicators = hindiRomanWords.contains { text.lowercased().contains($0) }
        return hasEnglish && hasHindiIndicators
    }
    
    private func containsDevanagari(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0900...0x097F).contains(scalar.value)  // Devanagari Unicode range
        }
    }
    
    private func detectDevanagariSpecific(_ text: String) -> SupportedLanguage {
        let marathiIndicators = ["आहे", "करणे", "असे", "मला", "तुम्ही", "आम्ही"]
        for indicator in marathiIndicators {
            if text.contains(indicator) {
                return .marathi
            }
        }
        return .hindi
    }
    
    private func detectIndianScript(_ text: String) -> SupportedLanguage? {
        for scalar in text.unicodeScalars {
            let value = scalar.value
            
            // Tamil
            if (0x0B80...0x0BFF).contains(value) { return .tamil }
            
            // Telugu
            if (0x0C00...0x0C7F).contains(value) { return .telugu }
            
            // Kannada
            if (0x0C80...0x0CFF).contains(value) { return .kannada }
            
            // Malayalam
            if (0x0D00...0x0D7F).contains(value) { return .malayalam }
            
            // Bengali
            if (0x0980...0x09FF).contains(value) { return .bengali }
            
            // Gujarati
            if (0x0A80...0x0AFF).contains(value) { return .gujarati }
            
            // Gurmukhi (Punjabi)
            if (0x0A00...0x0A7F).contains(value) { return .punjabi }
            
            // Odia
            if (0x0B00...0x0B7F).contains(value) { return .odia }
            
            // Assamese (uses Bengali script with some differences)
            if (0x0980...0x09FF).contains(value) {
                if text.contains("ৰ") || text.contains("ৱ") {
                    return .assamese
                }
            }
        }
        return nil
    }
    
    private func detectHindiRoman(_ text: String) -> Double {
        var matches = 0
        for word in hindiRomanWords {
            if text.contains(word) {
                matches += 1
            }
        }
        return min(1.0, Double(matches) / 5.0)
    }
    
    // Common Hindi words written in Roman script
    private let hindiRomanWords = [
        "aap", "aapka", "kya", "hai", "hain", "nahi", "kaise", "kaisa",
        "mujhe", "mera", "tumhara", "acha", "theek", "bahut", "abhi",
        "kab", "kyun", "kahan", "yahan", "wahan", "kaun", "kisko",
        "apna", "humara", "unka", "uska", "iski", "jaldi", "dhanyawad",
        "namaste", "shukriya", "accha", "thik", "bilkul", "zaroor",
        "lekin", "aur", "ya", "toh", "bhi", "wala", "wali", "karna",
        "dena", "lena", "jana", "aana", "hona", "rakhna", "milna"
    ]
    
    // MARK: - Language Settings
    
    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
        Logger.services.info("Language set to: \(language.rawValue)")
    }
    
    func getLanguage() -> SupportedLanguage {
        currentLanguage
    }
    
    func setRegion(_ region: IndianRegion) {
        currentRegion = region
        Logger.services.info("Region set to: \(region.rawValue)")
    }
    
    func getRegion() -> IndianRegion {
        currentRegion
    }
    
    // MARK: - Language Info
    
    func getLanguageInfo(_ language: SupportedLanguage) -> LanguageInfo {
        languageInfoMap[language] ?? LanguageInfo(
            code: language.rawValue,
            nativeName: language.displayName,
            script: "Latin",
            speakers: "N/A",
            regions: []
        )
    }
    
    func getRegionInfo(_ region: IndianRegion) -> RegionInfo {
        regionInfoMap[region] ?? RegionInfo(
            primaryLanguages: [.english, .hindi],
            culturalNotes: "Pan-India context",
            formalityLevel: 5
        )
    }
    
    private let languageInfoMap: [SupportedLanguage: LanguageInfo] = [
        .english: LanguageInfo(code: "en", nativeName: "English", script: "Latin", speakers: "125M+", regions: [.panIndia]),
        .hindi: LanguageInfo(code: "hi", nativeName: "हिन्दी", script: "Devanagari", speakers: "600M+", regions: [.north, .delhi]),
        .hinglish: LanguageInfo(code: "hi-en", nativeName: "Hinglish", script: "Mixed", speakers: "350M+", regions: [.panIndia, .delhi, .mumbai]),
        .tamil: LanguageInfo(code: "ta", nativeName: "தமிழ்", script: "Tamil", speakers: "85M+", regions: [.south, .chennai]),
        .telugu: LanguageInfo(code: "te", nativeName: "తెలుగు", script: "Telugu", speakers: "95M+", regions: [.south, .hyderabad]),
        .kannada: LanguageInfo(code: "kn", nativeName: "ಕನ್ನಡ", script: "Kannada", speakers: "55M+", regions: [.south, .bangalore]),
        .malayalam: LanguageInfo(code: "ml", nativeName: "മലയാളം", script: "Malayalam", speakers: "40M+", regions: [.south]),
        .marathi: LanguageInfo(code: "mr", nativeName: "मराठी", script: "Devanagari", speakers: "95M+", regions: [.west, .mumbai]),
        .gujarati: LanguageInfo(code: "gu", nativeName: "ગુજરાતી", script: "Gujarati", speakers: "60M+", regions: [.west]),
        .bengali: LanguageInfo(code: "bn", nativeName: "বাংলা", script: "Bengali", speakers: "105M+", regions: [.east, .kolkata]),
        .punjabi: LanguageInfo(code: "pa", nativeName: "ਪੰਜਾਬੀ", script: "Gurmukhi", speakers: "35M+", regions: [.north]),
        .odia: LanguageInfo(code: "or", nativeName: "ଓଡ଼ିଆ", script: "Odia", speakers: "40M+", regions: [.east]),
        .assamese: LanguageInfo(code: "as", nativeName: "অসমীয়া", script: "Bengali", speakers: "15M+", regions: [.northeast]),
        .urdu: LanguageInfo(code: "ur", nativeName: "اردو", script: "Perso-Arabic", speakers: "70M+", regions: [.north, .hyderabad]),
        .konkani: LanguageInfo(code: "kok", nativeName: "कोंकणी", script: "Devanagari", speakers: "7M+", regions: [.west])
    ]
    
    private let regionInfoMap: [IndianRegion: RegionInfo] = [
        .panIndia: RegionInfo(primaryLanguages: [.english, .hindi], culturalNotes: "Neutral, all-India communication", formalityLevel: 5),
        .north: RegionInfo(primaryLanguages: [.hindi, .punjabi], culturalNotes: "Warm, family-oriented, direct", formalityLevel: 4),
        .south: RegionInfo(primaryLanguages: [.tamil, .telugu, .kannada, .malayalam], culturalNotes: "Respectful, traditional, relationship-focused", formalityLevel: 6),
        .east: RegionInfo(primaryLanguages: [.bengali, .odia], culturalNotes: "Cultural, artistic, intellectual", formalityLevel: 5),
        .west: RegionInfo(primaryLanguages: [.marathi, .gujarati], culturalNotes: "Business-oriented, pragmatic", formalityLevel: 5),
        .northeast: RegionInfo(primaryLanguages: [.assamese], culturalNotes: "Diverse cultures, nature-connected", formalityLevel: 4),
        .delhi: RegionInfo(primaryLanguages: [.hindi, .english, .hinglish], culturalNotes: "Urban, fast-paced, cosmopolitan", formalityLevel: 4),
        .mumbai: RegionInfo(primaryLanguages: [.hindi, .marathi, .hinglish], culturalNotes: "Fast, professional, multicultural", formalityLevel: 4),
        .bangalore: RegionInfo(primaryLanguages: [.kannada, .english], culturalNotes: "Tech-savvy, modern, startup culture", formalityLevel: 4),
        .chennai: RegionInfo(primaryLanguages: [.tamil, .english], culturalNotes: "Traditional yet progressive, IT hub", formalityLevel: 5),
        .kolkata: RegionInfo(primaryLanguages: [.bengali, .hindi], culturalNotes: "Intellectual, artistic, heritage-conscious", formalityLevel: 5),
        .hyderabad: RegionInfo(primaryLanguages: [.telugu, .urdu, .hindi], culturalNotes: "Historic, tech-forward, multicultural", formalityLevel: 5)
    ]
}

// MARK: - Models

struct LanguageDetectionResult {
    let language: SupportedLanguage
    let confidence: Double
    let mixedLanguages: [SupportedLanguage]
    
    var isCodeMixed: Bool {
        !mixedLanguages.isEmpty
    }
}

struct LanguageInfo {
    let code: String
    let nativeName: String
    let script: String
    let speakers: String
    let regions: [IndianRegion]
}

struct RegionInfo {
    let primaryLanguages: [SupportedLanguage]
    let culturalNotes: String
    let formalityLevel: Int  // 1-10
}
