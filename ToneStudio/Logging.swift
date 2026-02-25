import OSLog

nonisolated extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.upen.ToneStudio"

    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let selection = Logger(subsystem: subsystem, category: "selection")
    static let tooltip = Logger(subsystem: subsystem, category: "tooltip")
    static let rewrite = Logger(subsystem: subsystem, category: "rewrite")
    static let accessibility = Logger(subsystem: subsystem, category: "accessibility")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let editor = Logger(subsystem: subsystem, category: "editor")
    static let feedback = Logger(subsystem: subsystem, category: "feedback")
    static let services = Logger(subsystem: subsystem, category: "services")
    
    // Content Trust System
    static let rules = Logger(subsystem: subsystem, category: "rules")
    static let validation = Logger(subsystem: subsystem, category: "validation")
    static let safety = Logger(subsystem: subsystem, category: "safety")
    static let learning = Logger(subsystem: subsystem, category: "learning")
    static let cache = Logger(subsystem: subsystem, category: "cache")
    static let intent = Logger(subsystem: subsystem, category: "intent")
}
