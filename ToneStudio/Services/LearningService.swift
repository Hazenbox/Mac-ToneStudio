import Foundation
import OSLog

actor LearningService {
    
    static let shared = LearningService()
    
    private var corrections: [Correction] = []
    private var avoidPatterns: Set<String> = []
    private var preferredPatterns: [String: String] = [:]
    
    private let cacheDirectory: URL
    private let correctionsFile: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("ToneStudio", isDirectory: true)
        correctionsFile = cacheDirectory.appendingPathComponent("corrections.json")
        
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        loadCorrectionsSync()
    }
    
    private nonisolated func loadCorrectionsSync() {
        Task { await loadCorrections() }
    }
    
    // MARK: - Public API
    
    func recordCorrection(_ correction: Correction) {
        if !corrections.contains(where: { $0.originalText == correction.originalText && $0.correctedText == correction.correctedText }) {
            corrections.append(correction)
            saveCorrections()
            
            preferredPatterns[correction.originalText.lowercased()] = correction.correctedText
            
            Logger.learning.info("Recorded correction: '\(correction.originalText)' → '\(correction.correctedText)'")
        }
    }
    
    func applyLearnings(to text: String) -> String {
        var result = text
        
        for (original, corrected) in preferredPatterns {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: original))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: corrected)
            }
        }
        
        return result
    }
    
    func getCorrections(limit: Int = 100) -> [Correction] {
        return Array(corrections.prefix(limit))
    }
    
    func getRecentCorrections(days: Int = 7) -> [Correction] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return corrections.filter { $0.createdAt >= cutoff }
    }
    
    func getCorrectionsForContext(ecosystem: String? = nil, channel: String? = nil, limit: Int = 50) -> [Correction] {
        var filtered = corrections
        
        if let ecosystem = ecosystem {
            filtered = filtered.filter { $0.ecosystem == ecosystem || $0.ecosystem == nil }
        }
        
        if let channel = channel {
            filtered = filtered.filter { $0.channel == channel || $0.channel == nil }
        }
        
        let sorted = filtered.sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(limit))
    }
    
    func getCorrectionsForContext(ecosystem: EcosystemType, channel: ContentChannelType, limit: Int = 50) -> [Correction] {
        return getCorrectionsForContext(ecosystem: ecosystem.rawValue, channel: channel.rawValue, limit: limit)
    }
    
    func buildLearningContext(corrections: [Correction]) -> String {
        guard !corrections.isEmpty else { return "" }
        
        var context = "based on previous feedback:\n"
        
        for correction in corrections.prefix(10) {
            context += "- avoid: \"\(correction.originalText)\" → prefer: \"\(correction.correctedText)\"\n"
        }
        
        return context
    }
    
    func addAvoidPattern(_ pattern: String) {
        avoidPatterns.insert(pattern.lowercased())
        Logger.learning.info("Added avoid pattern: '\(pattern)'")
    }
    
    func shouldAvoid(_ text: String) -> Bool {
        let lowerText = text.lowercased()
        return avoidPatterns.contains { lowerText.contains($0) }
    }
    
    func getLearningsApplied(to text: String) -> LearningsApplied {
        var correctionsApplied: [Correction] = []
        var avoidPatternsMatched: [String] = []
        
        let lowerText = text.lowercased()
        
        for correction in corrections {
            if lowerText.contains(correction.originalText.lowercased()) {
                correctionsApplied.append(correction)
            }
        }
        
        for pattern in avoidPatterns {
            if lowerText.contains(pattern) {
                avoidPatternsMatched.append(pattern)
            }
        }
        
        return LearningsApplied(
            corrections: correctionsApplied,
            avoidPatterns: avoidPatternsMatched
        )
    }
    
    func syncWithServer() async throws {
        Logger.learning.info("Syncing corrections with server...")
    }
    
    func getPendingCorrections() -> [Correction] {
        corrections.filter { !$0.synced }
    }
    
    func markCorrectionsSynced(_ synced: [Correction]) {
        for syncedCorrection in synced {
            if let index = corrections.firstIndex(where: { $0.id == syncedCorrection.id }) {
                corrections[index].synced = true
            }
        }
        saveCorrections()
        Logger.learning.info("Marked \(synced.count) corrections as synced")
    }
    
    func clearAllCorrections() {
        corrections = []
        preferredPatterns = [:]
        avoidPatterns = []
        saveCorrections()
        Logger.learning.info("Cleared all corrections")
    }
    
    // MARK: - Private
    
    private func loadCorrections() {
        guard let data = try? Data(contentsOf: correctionsFile),
              let loaded = try? JSONDecoder().decode([Correction].self, from: data) else {
            return
        }
        
        self.corrections = loaded
        for correction in self.corrections {
            self.preferredPatterns[correction.originalText.lowercased()] = correction.correctedText
        }
        
        Logger.learning.info("Loaded \(self.corrections.count) corrections from cache")
    }
    
    private func saveCorrections() {
        guard let data = try? JSONEncoder().encode(corrections) else { return }
        try? data.write(to: correctionsFile)
    }
}

// MARK: - Learnings Applied Result

struct LearningsApplied: Codable {
    let corrections: [Correction]
    let avoidPatterns: [String]
    
    var totalCount: Int {
        corrections.count + avoidPatterns.count
    }
    
    var isEmpty: Bool {
        corrections.isEmpty && avoidPatterns.isEmpty
    }
}

