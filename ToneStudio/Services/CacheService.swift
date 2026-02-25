import Foundation
import OSLog

actor CacheService<Value: Codable> {
    
    private struct CacheEntry: Codable {
        let value: Value
        let timestamp: Date
        let ttl: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
        
        var isStale: Bool {
            Date().timeIntervalSince(timestamp) > ttl * 0.8
        }
        
        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
    }
    
    private var cache: [String: CacheEntry] = [:]
    private let maxSize: Int
    private let defaultTTL: TimeInterval
    private let staleTime: TimeInterval
    private var hitCount: Int = 0
    private var missCount: Int = 0
    
    init(maxSize: Int = 100, ttl: TimeInterval = 300, staleTime: TimeInterval? = nil) {
        self.maxSize = maxSize
        self.defaultTTL = ttl
        self.staleTime = staleTime ?? (ttl * 0.8)
    }
    
    // MARK: - Public API
    
    func get(_ key: String) -> Value? {
        guard let entry = cache[key], !entry.isExpired else {
            missCount += 1
            Logger.cache.debug("Cache miss for key: \(key)")
            return nil
        }
        
        hitCount += 1
        Logger.cache.debug("Cache hit for key: \(key), age: \(entry.age)s")
        return entry.value
    }
    
    func set(_ key: String, value: Value, ttl: TimeInterval? = nil) {
        let entry = CacheEntry(
            value: value,
            timestamp: Date(),
            ttl: ttl ?? defaultTTL
        )
        
        if cache.count >= maxSize {
            evictOldest()
        }
        
        cache[key] = entry
        Logger.cache.debug("Cached value for key: \(key), ttl: \(entry.ttl)s")
    }
    
    func getOrFetch(_ key: String, fetch: @escaping () async throws -> Value) async throws -> Value {
        if let existing = get(key) {
            if let entry = cache[key], entry.isStale {
                Task {
                    if let fresh = try? await fetch() {
                        await self.set(key, value: fresh)
                    }
                }
            }
            return existing
        }
        
        let value = try await fetch()
        set(key, value: value)
        return value
    }
    
    func remove(_ key: String) {
        cache.removeValue(forKey: key)
    }
    
    func clear() {
        cache.removeAll()
        hitCount = 0
        missCount = 0
        Logger.cache.info("Cache cleared")
    }
    
    func getStats() -> CacheStats {
        let validEntries = cache.values.filter { !$0.isExpired }
        let staleEntries = cache.values.filter { $0.isStale && !$0.isExpired }
        
        return CacheStats(
            totalEntries: cache.count,
            validEntries: validEntries.count,
            staleEntries: staleEntries.count,
            hitCount: hitCount,
            missCount: missCount,
            hitRate: hitCount + missCount > 0 ? Double(hitCount) / Double(hitCount + missCount) : 0
        )
    }
    
    // MARK: - Private
    
    private func evictOldest() {
        guard let oldest = cache.min(by: { $0.value.timestamp < $1.value.timestamp }) else { return }
        cache.removeValue(forKey: oldest.key)
        Logger.cache.debug("Evicted oldest entry: \(oldest.key)")
    }
}

// MARK: - Cache Stats

struct CacheStats {
    let totalEntries: Int
    let validEntries: Int
    let staleEntries: Int
    let hitCount: Int
    let missCount: Int
    let hitRate: Double
    
    var description: String {
        String(format: "entries: %d (valid: %d, stale: %d), hit rate: %.1f%%",
               totalEntries, validEntries, staleEntries, hitRate * 100)
    }
}

// MARK: - Shared Cache Instances

enum SharedCaches {
    static let knowledge = CacheService<WordingRulesData>(
        maxSize: 10,
        ttl: AppConstants.cacheTTLKnowledge
    )
    
    static let enforcement = CacheService<ValidationResult>(
        maxSize: 50,
        ttl: AppConstants.cacheTTLEnforcement
    )
    
    static let userProfile = CacheService<UserProfile>(
        maxSize: 5,
        ttl: AppConstants.cacheTTLUserProfile
    )
}

