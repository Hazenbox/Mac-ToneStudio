import Foundation
import os.log

actor EmotionService {
    
    static let shared = EmotionService()
    
    // MARK: - Navarasa Emotion Mapping
    
    private let emotionKeywords: [NavarasaType: [String]] = [
        .shringara: [
            "love", "romance", "beautiful", "charming", "elegant", "attractive",
            "affection", "desire", "passion", "intimate", "tender", "warmth",
            "adore", "devotion", "sweetheart", "beloved", "darling", "fondness"
        ],
        .hasya: [
            "funny", "laugh", "humor", "comedy", "joke", "hilarious", "amusing",
            "witty", "playful", "fun", "entertainment", "cheerful", "lighthearted",
            "comical", "silly", "giggle", "humorous", "merry", "jovial"
        ],
        .karuna: [
            "sad", "sorry", "sympathy", "compassion", "pity", "tragedy", "grief",
            "sorrow", "unfortunate", "regret", "condolence", "empathy", "melancholy",
            "heartbreak", "distress", "lament", "mourn", "woe", "anguish"
        ],
        .raudra: [
            "angry", "rage", "fury", "outrage", "frustration", "annoyed", "irritated",
            "aggressive", "hostile", "fierce", "violent", "indignant", "resentment",
            "wrath", "temper", "infuriate", "enraged", "irate", "livid"
        ],
        .vira: [
            "brave", "courage", "hero", "champion", "victory", "triumph", "bold",
            "confident", "powerful", "strong", "fearless", "valiant", "warrior",
            "determined", "resilient", "unstoppable", "conquer", "mighty", "gallant"
        ],
        .bhayanaka: [
            "fear", "scary", "danger", "threat", "warning", "risk", "caution",
            "worry", "concern", "alarm", "panic", "dread", "terror", "anxiety",
            "frightening", "ominous", "peril", "hazard", "menace"
        ],
        .bibhatsa: [
            "disgust", "repulsive", "gross", "vile", "revolting", "unpleasant",
            "offensive", "distasteful", "nauseating", "repugnant", "loathsome",
            "abhorrent", "detestable", "sickening", "hideous", "contempt"
        ],
        .adbhuta: [
            "amazing", "wonderful", "incredible", "wow", "astonishing", "miraculous",
            "extraordinary", "fantastic", "marvelous", "spectacular", "awesome",
            "stunning", "breathtaking", "phenomenal", "magical", "surprising",
            "unbelievable", "impressive", "remarkable", "mind-blowing"
        ],
        .shanta: [
            "peace", "calm", "serene", "tranquil", "relaxed", "gentle", "quiet",
            "harmony", "balanced", "mindful", "zen", "meditative", "soothing",
            "composed", "content", "placid", "still", "restful", "mellow"
        ]
    ]
    
    private let emotionDescriptions: [NavarasaType: String] = [
        .shringara: "love, beauty, and devotion",
        .hasya: "humor and joy",
        .karuna: "compassion and sorrow",
        .raudra: "anger and intensity",
        .vira: "heroism and courage",
        .bhayanaka: "fear and caution",
        .bibhatsa: "disgust and aversion",
        .adbhuta: "wonder and amazement",
        .shanta: "peace and serenity"
    ]
    
    // MARK: - Detection
    
    func detectEmotion(in text: String) -> EmotionResult {
        let lowercased = text.lowercased()
        var scores: [NavarasaType: Int] = [:]
        var matchedKeywords: [NavarasaType: [String]] = [:]
        
        for (emotion, keywords) in emotionKeywords {
            var count = 0
            var matches: [String] = []
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    count += 1
                    matches.append(keyword)
                }
            }
            if count > 0 {
                scores[emotion] = count
                matchedKeywords[emotion] = matches
            }
        }
        
        guard !scores.isEmpty else {
            return EmotionResult(
                primary: .shanta,
                secondary: nil,
                confidence: 0.5,
                allScores: [:],
                matchedKeywords: [:]
            )
        }
        
        let sorted = scores.sorted { $0.value > $1.value }
        let primary = sorted[0].key
        let secondary = sorted.count > 1 ? sorted[1].key : nil
        
        let maxScore = sorted[0].value
        let totalWords = text.split(separator: " ").count
        let confidence = min(1.0, Double(maxScore) / Double(max(1, totalWords / 10)))
        
        return EmotionResult(
            primary: primary,
            secondary: secondary,
            confidence: confidence,
            allScores: scores,
            matchedKeywords: matchedKeywords
        )
    }
    
    func getEmotionDescription(_ emotion: NavarasaType) -> String {
        emotionDescriptions[emotion] ?? "neutral expression"
    }
    
    func getSuggestedTone(for emotion: NavarasaType) -> TonePreset {
        switch emotion {
        case .shringara:
            return TonePreset(warmth: 9, detail: 7, formality: 5, energy: 6)
        case .hasya:
            return TonePreset(warmth: 8, detail: 5, formality: 3, energy: 9)
        case .karuna:
            return TonePreset(warmth: 10, detail: 6, formality: 6, energy: 3)
        case .raudra:
            return TonePreset(warmth: 3, detail: 8, formality: 7, energy: 9)
        case .vira:
            return TonePreset(warmth: 6, detail: 7, formality: 6, energy: 10)
        case .bhayanaka:
            return TonePreset(warmth: 5, detail: 8, formality: 8, energy: 4)
        case .bibhatsa:
            return TonePreset(warmth: 3, detail: 6, formality: 7, energy: 5)
        case .adbhuta:
            return TonePreset(warmth: 8, detail: 8, formality: 4, energy: 9)
        case .shanta:
            return TonePreset(warmth: 7, detail: 5, formality: 5, energy: 3)
        }
    }
}

// MARK: - Models

struct EmotionResult {
    let primary: NavarasaType
    let secondary: NavarasaType?
    let confidence: Double
    let allScores: [NavarasaType: Int]
    let matchedKeywords: [NavarasaType: [String]]
    
    var description: String {
        if let secondary = secondary {
            return "\(primary.rawValue) with hints of \(secondary.rawValue)"
        }
        return primary.rawValue
    }
}

struct TonePreset {
    let warmth: Int      // 1-10: cold to warm
    let detail: Int      // 1-10: concise to detailed
    let formality: Int   // 1-10: casual to formal
    let energy: Int      // 1-10: calm to energetic
    
    var summary: String {
        var parts: [String] = []
        if warmth >= 7 { parts.append("warm") }
        else if warmth <= 3 { parts.append("direct") }
        
        if detail >= 7 { parts.append("detailed") }
        else if detail <= 3 { parts.append("concise") }
        
        if formality >= 7 { parts.append("formal") }
        else if formality <= 3 { parts.append("casual") }
        
        if energy >= 7 { parts.append("energetic") }
        else if energy <= 3 { parts.append("calm") }
        
        return parts.isEmpty ? "balanced" : parts.joined(separator: ", ")
    }
}

// MARK: - Ecosystem Tone Presets

enum EcosystemTonePresets {
    
    static let presets: [EcosystemType: TonePreset] = [
        .connectivity: TonePreset(warmth: 7, detail: 6, formality: 5, energy: 6),
        .home: TonePreset(warmth: 8, detail: 5, formality: 4, energy: 5),
        .entertainment: TonePreset(warmth: 8, detail: 5, formality: 3, energy: 8),
        .shopping: TonePreset(warmth: 8, detail: 6, formality: 5, energy: 7),
        .finance: TonePreset(warmth: 6, detail: 8, formality: 8, energy: 4),
        .health: TonePreset(warmth: 9, detail: 7, formality: 6, energy: 5),
        .business: TonePreset(warmth: 5, detail: 7, formality: 9, energy: 5),
        .work: TonePreset(warmth: 7, detail: 6, formality: 6, energy: 5),
        .government: TonePreset(warmth: 5, detail: 8, formality: 9, energy: 3),
        .education: TonePreset(warmth: 8, detail: 7, formality: 5, energy: 6),
        .sports: TonePreset(warmth: 7, detail: 5, formality: 3, energy: 10),
        .agriculture: TonePreset(warmth: 8, detail: 6, formality: 4, energy: 5),
        .energy: TonePreset(warmth: 6, detail: 7, formality: 6, energy: 6),
        .transport: TonePreset(warmth: 6, detail: 6, formality: 5, energy: 5)
    ]
    
    static func preset(for ecosystem: EcosystemType) -> TonePreset {
        presets[ecosystem] ?? TonePreset(warmth: 7, detail: 6, formality: 5, energy: 6)
    }
    
    static func description(for ecosystem: EcosystemType) -> String {
        let preset = Self.preset(for: ecosystem)
        return preset.summary
    }
}
