import Foundation
import os.log

actor SyncService {
    
    static let shared = SyncService()
    
    // MARK: - Properties
    
    private var lastSyncTime: Date?
    private var syncInProgress = false
    private var observers: [() async -> Void] = []
    
    private let syncInterval: TimeInterval = 5 * 60  // 5 minutes
    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "ToneStudio.lastSyncTime"
    
    // MARK: - Initialization
    
    init() {
        loadLastSyncTimeSync()
    }
    
    private nonisolated func loadLastSyncTimeSync() {
        Task { await loadLastSyncTime() }
    }
    
    private func loadLastSyncTime() {
        if let timestamp = userDefaults.object(forKey: lastSyncKey) as? Double {
            lastSyncTime = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    private func saveLastSyncTime() {
        lastSyncTime = Date()
        userDefaults.set(lastSyncTime?.timeIntervalSince1970, forKey: lastSyncKey)
    }
    
    // MARK: - Public API
    
    func startBackgroundSync() {
        Logger.sync.info("Starting background sync service")
        scheduleNextSync()
    }
    
    func stopBackgroundSync() {
        Logger.sync.info("Stopping background sync service")
    }
    
    func syncNow() async -> SyncResult {
        guard !syncInProgress else {
            Logger.sync.debug("Sync already in progress, skipping")
            return SyncResult(success: false, message: "sync already in progress", updatedItems: 0)
        }
        
        syncInProgress = true
        defer { syncInProgress = false }
        
        Logger.sync.info("Starting manual sync")
        
        var totalUpdated = 0
        var errors: [String] = []
        
        // Sync wording rules
        do {
            let rulesUpdated = try await syncWordingRules()
            totalUpdated += rulesUpdated
            Logger.sync.info("Synced \(rulesUpdated) wording rules")
        } catch {
            Logger.sync.error("Failed to sync wording rules: \(error.localizedDescription)")
            errors.append("wording rules: \(error.localizedDescription)")
        }
        
        // Sync channel guidelines
        do {
            let guidelinesUpdated = try await syncChannelGuidelines()
            totalUpdated += guidelinesUpdated
            Logger.sync.info("Synced \(guidelinesUpdated) channel guidelines")
        } catch {
            Logger.sync.error("Failed to sync channel guidelines: \(error.localizedDescription)")
            errors.append("channel guidelines: \(error.localizedDescription)")
        }
        
        // Sync safety patterns
        do {
            let patternsUpdated = try await syncSafetyPatterns()
            totalUpdated += patternsUpdated
            Logger.sync.info("Synced \(patternsUpdated) safety patterns")
        } catch {
            Logger.sync.error("Failed to sync safety patterns: \(error.localizedDescription)")
            errors.append("safety patterns: \(error.localizedDescription)")
        }
        
        // Upload pending corrections
        do {
            let correctionsUploaded = try await uploadPendingCorrections()
            Logger.sync.info("Uploaded \(correctionsUploaded) corrections")
        } catch {
            Logger.sync.error("Failed to upload corrections: \(error.localizedDescription)")
            errors.append("corrections upload: \(error.localizedDescription)")
        }
        
        saveLastSyncTime()
        notifyObservers()
        
        let success = errors.isEmpty
        let message = success ? "sync completed successfully" : "sync completed with errors: \(errors.joined(separator: ", "))"
        
        Logger.sync.info("Sync completed: \(totalUpdated) items updated, success: \(success)")
        
        return SyncResult(success: success, message: message, updatedItems: totalUpdated)
    }
    
    func getStatus() -> SyncStatus {
        SyncStatus(
            lastSyncTime: lastSyncTime,
            isOnline: isNetworkAvailable(),
            syncInProgress: syncInProgress
        )
    }
    
    func addObserver(_ callback: @escaping () async -> Void) {
        observers.append(callback)
    }
    
    // MARK: - Private Sync Methods
    
    private func scheduleNextSync() {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(syncInterval * 1_000_000_000))
            await performScheduledSync()
        }
    }
    
    private func performScheduledSync() async {
        guard isNetworkAvailable() else {
            Logger.sync.debug("Network unavailable, skipping scheduled sync")
            scheduleNextSync()
            return
        }
        
        _ = await syncNow()
        scheduleNextSync()
    }
    
    private func syncWordingRules() async throws -> Int {
        guard let apiKey = loadAPIKey() else {
            throw SyncError.missingAPIKey
        }
        
        guard let url = URL(string: "\(AppConstants.rewriteBaseURL)\(AppConstants.knowledgeEndpoint)/wording-rules") else {
            throw SyncError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 304 {
                return 0
            }
            throw SyncError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let rules = try JSONDecoder().decode(WordingRulesData.self, from: data)
        
        // Update local cache
        let totalCount = rules.avoidWords.count + rules.preferredWords.count + rules.autoFixRules.count
        
        return totalCount
    }
    
    private func syncChannelGuidelines() async throws -> Int {
        // For now, channel guidelines are bundled. This is a placeholder for server sync.
        return 0
    }
    
    private func syncSafetyPatterns() async throws -> Int {
        // Safety patterns are bundled for now. This is a placeholder for server sync.
        return 0
    }
    
    private func uploadPendingCorrections() async throws -> Int {
        guard let apiKey = loadAPIKey() else {
            throw SyncError.missingAPIKey
        }
        
        guard let url = URL(string: "\(AppConstants.rewriteBaseURL)\(AppConstants.correctionsEndpoint)") else {
            throw SyncError.invalidURL
        }
        
        let corrections = await LearningService.shared.getPendingCorrections()
        
        guard !corrections.isEmpty else {
            return 0
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["corrections": corrections.map { $0.toDictionary() }]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SyncError.uploadFailed
        }
        
        await LearningService.shared.markCorrectionsSynced(corrections)
        
        return corrections.count
    }
    
    private func notifyObservers() {
        for observer in observers {
            Task {
                await observer()
            }
        }
    }
    
    private func isNetworkAvailable() -> Bool {
        // Simple check - in production, use NWPathMonitor
        return true
    }
    
    private func loadAPIKey() -> String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let key = config["API_KEY"] as? String else {
            return nil
        }
        return key
    }
}

// MARK: - Models

struct SyncResult {
    let success: Bool
    let message: String
    let updatedItems: Int
}

struct SyncStatus {
    let lastSyncTime: Date?
    let isOnline: Bool
    let syncInProgress: Bool
    
    var lastSyncDescription: String {
        guard let lastSync = lastSyncTime else {
            return "never synced"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
    
    var statusText: String {
        if syncInProgress {
            return "syncing..."
        }
        if !isOnline {
            return "offline"
        }
        return "online"
    }
}

enum SyncError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not configured"
        case .invalidURL:
            return "Invalid sync URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let statusCode):
            return "Server error: \(statusCode)"
        case .uploadFailed:
            return "Failed to upload data"
        }
    }
}

// MARK: - Offline Support

actor OfflineManager {
    
    static let shared = OfflineManager()
    
    private let userDefaults = UserDefaults.standard
    private let offlineModeKey = "ToneStudio.offlineMode"
    private let pendingActionsKey = "ToneStudio.pendingActions"
    
    var isOfflineMode: Bool {
        userDefaults.bool(forKey: offlineModeKey)
    }
    
    func setOfflineMode(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: offlineModeKey)
        Logger.sync.info("Offline mode \(enabled ? "enabled" : "disabled")")
    }
    
    func queueAction(_ action: OfflineAction) {
        var actions = getPendingActions()
        actions.append(action)
        savePendingActions(actions)
        Logger.sync.debug("Queued offline action: \(action.type)")
    }
    
    func getPendingActions() -> [OfflineAction] {
        guard let data = userDefaults.data(forKey: pendingActionsKey) else {
            return []
        }
        return (try? JSONDecoder().decode([OfflineAction].self, from: data)) ?? []
    }
    
    func processQueuedActions() async {
        let actions = getPendingActions()
        guard !actions.isEmpty else { return }
        
        Logger.sync.info("Processing \(actions.count) queued offline actions")
        
        var remaining: [OfflineAction] = []
        
        for action in actions {
            let success = await processAction(action)
            if !success {
                remaining.append(action)
            }
        }
        
        savePendingActions(remaining)
    }
    
    private func processAction(_ action: OfflineAction) async -> Bool {
        switch action.type {
        case "feedback":
            // Process feedback action
            return true
        case "correction":
            // Process correction action
            return true
        default:
            return false
        }
    }
    
    private func savePendingActions(_ actions: [OfflineAction]) {
        if let data = try? JSONEncoder().encode(actions) {
            userDefaults.set(data, forKey: pendingActionsKey)
        }
    }
}

struct OfflineAction: Codable {
    let id: String
    let type: String
    let payload: [String: String]
    let timestamp: Date
}
