import Foundation
import OSLog

actor SafetyGateService {
    
    static let shared = SafetyGateService()
    
    private var patterns: [SafetyPattern] = []
    private var emergencyResponses: [SafetyDomain: EmergencyInfo] = [:]
    private var disclaimers: [SafetyDomain: String] = [:]
    
    private init() {
        loadDefaultPatterns()
        loadEmergencyResponses()
        loadDisclaimers()
    }
    
    // MARK: - Public API
    
    func classify(_ text: String) async -> SafetyGateResult {
        let startTime = Date()
        var classifications: [SafetyClassification] = []
        let lowerText = text.lowercased()
        
        for pattern in patterns {
            if matchesPattern(lowerText, pattern: pattern) {
                let classification = SafetyClassification(
                    domain: pattern.domain,
                    level: pattern.level,
                    matchedPatterns: [pattern.pattern],
                    suggestedDisclaimer: disclaimers[pattern.domain]
                )
                classifications.append(classification)
            }
        }
        
        let (routing, modifications) = determineRouting(classifications: classifications)
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        
        let result = SafetyGateResult(
            routing: routing,
            classifications: classifications,
            modifications: modifications,
            blockedReason: routing == .blockAndLog ? "content violates safety guidelines" : nil,
            processingTimeMs: elapsed
        )
        
        if !classifications.isEmpty {
            Logger.safety.info("Safety gate: \(classifications.count) classifications, routing: \(routing.rawValue)")
        }
        
        return result
    }
    
    func getEmergencyResponse(for domain: SafetyDomain) -> EmergencyInfo? {
        return emergencyResponses[domain]
    }
    
    func getDisclaimer(for domain: SafetyDomain) -> String? {
        return disclaimers[domain]
    }
    
    func hasCriticalConcern(_ text: String) async -> Bool {
        let lowerText = text.lowercased()
        
        for pattern in patterns where pattern.level == .critical {
            if matchesPattern(lowerText, pattern: pattern) {
                Logger.safety.warning("Critical concern detected: \(pattern.description)")
                return true
            }
        }
        
        return false
    }
    
    func getCriticalDomains(_ text: String) async -> [SafetyDomain] {
        let lowerText = text.lowercased()
        var domains: Set<SafetyDomain> = []
        
        for pattern in patterns where pattern.level == .critical {
            if matchesPattern(lowerText, pattern: pattern) {
                domains.insert(pattern.domain)
            }
        }
        
        return Array(domains)
    }
    
    func requiresEmergencyResponse(_ text: String) async -> (Bool, EmergencyInfo?) {
        let result = await classify(text)
        
        if result.routing == .emergencyResponse {
            let domain = result.classifications.first(where: { $0.level == .critical })?.domain
            let emergencyInfo = domain.flatMap { emergencyResponses[$0] }
            return (true, emergencyInfo)
        }
        
        return (false, nil)
    }
    
    // MARK: - Private Methods
    
    private func matchesPattern(_ text: String, pattern: SafetyPattern) -> Bool {
        if pattern.isRegex {
            guard let regex = try? NSRegularExpression(pattern: pattern.pattern, options: .caseInsensitive) else {
                return false
            }
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, range: range) != nil
        } else {
            return text.contains(pattern.pattern.lowercased())
        }
    }
    
    private func determineRouting(classifications: [SafetyClassification]) -> (SafetyRouting, GenerationModifications) {
        guard !classifications.isEmpty else {
            return (.proceedNormal, .none)
        }
        
        let highestLevel = classifications.map { $0.level }.max() ?? .none
        let primaryDomain = classifications.max(by: { $0.level < $1.level })?.domain
        
        switch highestLevel {
        case .none:
            return (.proceedNormal, .none)
            
        case .low:
            return (.proceedNormal, GenerationModifications(maxWarmth: 8))
            
        case .moderate:
            let disclaimer = primaryDomain.flatMap { disclaimers[$0] }
            return (.proceedWithDisclaimer, GenerationModifications(
                maxWarmth: 6,
                requiredDisclaimer: disclaimer
            ))
            
        case .high:
            let disclaimer = primaryDomain.flatMap { disclaimers[$0] }
            return (.proceedModified, GenerationModifications(
                maxWarmth: 4,
                toneLock: "professional",
                blockNudging: true,
                requiredDisclaimer: disclaimer
            ))
            
        case .critical:
            if let domain = primaryDomain, let emergency = emergencyResponses[domain] {
                return (.emergencyResponse, GenerationModifications(
                    maxWarmth: 3,
                    toneLock: "supportive",
                    blockNudging: true,
                    emergencyInfo: emergency
                ))
            }
            return (.blockAndLog, .none)
        }
    }
    
    // MARK: - Default Data
    
    private func loadDefaultPatterns() {
        patterns = [
            // Mental Health - Critical
            SafetyPattern(pattern: "suicide", domain: .mentalHealth, level: .critical, description: "suicide mention"),
            SafetyPattern(pattern: "kill myself", domain: .mentalHealth, level: .critical, description: "self-harm intent"),
            SafetyPattern(pattern: "end my life", domain: .mentalHealth, level: .critical, description: "self-harm intent"),
            SafetyPattern(pattern: "want to die", domain: .mentalHealth, level: .critical, description: "suicidal ideation"),
            SafetyPattern(pattern: "self harm", domain: .mentalHealth, level: .critical, description: "self-harm"),
            SafetyPattern(pattern: "self-harm", domain: .mentalHealth, level: .critical, description: "self-harm"),
            SafetyPattern(pattern: "cutting myself", domain: .mentalHealth, level: .critical, description: "self-harm"),
            
            // Mental Health - High
            SafetyPattern(pattern: "depression", domain: .mentalHealth, level: .high, description: "mental health condition"),
            SafetyPattern(pattern: "anxiety disorder", domain: .mentalHealth, level: .high, description: "mental health condition"),
            SafetyPattern(pattern: "panic attack", domain: .mentalHealth, level: .moderate, description: "mental health symptom"),
            SafetyPattern(pattern: "bipolar", domain: .mentalHealth, level: .high, description: "mental health condition"),
            SafetyPattern(pattern: "schizophrenia", domain: .mentalHealth, level: .high, description: "mental health condition"),
            
            // Emergency - Critical
            SafetyPattern(pattern: "heart attack", domain: .emergency, level: .critical, description: "medical emergency"),
            SafetyPattern(pattern: "can't breathe", domain: .emergency, level: .critical, description: "breathing emergency"),
            SafetyPattern(pattern: "choking", domain: .emergency, level: .critical, description: "choking emergency"),
            SafetyPattern(pattern: "unconscious", domain: .emergency, level: .high, description: "medical emergency"),
            SafetyPattern(pattern: "ambulance", domain: .emergency, level: .high, description: "emergency services"),
            SafetyPattern(pattern: "emergency room", domain: .emergency, level: .high, description: "emergency medical"),
            
            // Health - Moderate to High
            SafetyPattern(pattern: "diagnose", domain: .health, level: .moderate, description: "medical diagnosis"),
            SafetyPattern(pattern: "prescription", domain: .health, level: .moderate, description: "medical prescription"),
            SafetyPattern(pattern: "medication", domain: .health, level: .low, description: "medication mention"),
            SafetyPattern(pattern: "cancer treatment", domain: .health, level: .high, description: "serious illness"),
            SafetyPattern(pattern: "diabetes treatment", domain: .health, level: .moderate, description: "chronic condition"),
            SafetyPattern(pattern: "cure for", domain: .health, level: .high, description: "cure claims"),
            SafetyPattern(pattern: "guaranteed cure", domain: .health, level: .critical, description: "false cure claims"),
            
            // Financial - Moderate to High
            SafetyPattern(pattern: "guaranteed returns", domain: .financial, level: .high, description: "investment promise"),
            SafetyPattern(pattern: "investment advice", domain: .financial, level: .moderate, description: "financial advice"),
            SafetyPattern(pattern: "double your money", domain: .financial, level: .high, description: "financial scam pattern"),
            SafetyPattern(pattern: "get rich quick", domain: .financial, level: .high, description: "scam pattern"),
            SafetyPattern(pattern: "financial guarantee", domain: .financial, level: .moderate, description: "financial promise"),
            SafetyPattern(pattern: "loan approval guaranteed", domain: .financial, level: .high, description: "false promise"),
            
            // Legal - Moderate
            SafetyPattern(pattern: "legal advice", domain: .legal, level: .moderate, description: "legal advice"),
            SafetyPattern(pattern: "sue", domain: .legal, level: .low, description: "legal action"),
            SafetyPattern(pattern: "lawsuit", domain: .legal, level: .moderate, description: "legal proceedings"),
            SafetyPattern(pattern: "court case", domain: .legal, level: .moderate, description: "legal proceedings"),
            
            // Privacy - Low to Moderate
            SafetyPattern(pattern: "aadhaar number", domain: .privacy, level: .moderate, description: "PII"),
            SafetyPattern(pattern: "pan number", domain: .privacy, level: .moderate, description: "PII"),
            SafetyPattern(pattern: "bank account number", domain: .privacy, level: .high, description: "financial PII"),
            SafetyPattern(pattern: "credit card number", domain: .privacy, level: .high, description: "financial PII"),
            SafetyPattern(pattern: "password", domain: .privacy, level: .moderate, description: "credentials"),
            SafetyPattern(pattern: "otp", domain: .privacy, level: .moderate, description: "authentication"),
            
            // Violence - High to Critical
            SafetyPattern(pattern: "kill", domain: .violence, level: .high, description: "violence"),
            SafetyPattern(pattern: "murder", domain: .violence, level: .critical, description: "violence"),
            SafetyPattern(pattern: "attack", domain: .violence, level: .moderate, description: "potential violence"),
            SafetyPattern(pattern: "weapon", domain: .violence, level: .moderate, description: "weapon mention"),
            SafetyPattern(pattern: "bomb", domain: .violence, level: .critical, description: "explosive"),
            SafetyPattern(pattern: "terrorist", domain: .violence, level: .critical, description: "terrorism"),
            
            // Substance - Low to Moderate
            SafetyPattern(pattern: "drugs", domain: .substance, level: .moderate, description: "substance"),
            SafetyPattern(pattern: "cocaine", domain: .substance, level: .high, description: "illegal substance"),
            SafetyPattern(pattern: "heroin", domain: .substance, level: .high, description: "illegal substance"),
            SafetyPattern(pattern: "alcohol addiction", domain: .substance, level: .moderate, description: "addiction"),
            
            // Gambling - Moderate
            SafetyPattern(pattern: "guaranteed win", domain: .gambling, level: .high, description: "gambling promise"),
            SafetyPattern(pattern: "betting tips", domain: .gambling, level: .moderate, description: "gambling advice"),
            SafetyPattern(pattern: "satta", domain: .gambling, level: .high, description: "illegal gambling"),
            
            // Minors - High
            SafetyPattern(pattern: "child abuse", domain: .minors, level: .critical, description: "child safety"),
            SafetyPattern(pattern: "minor", domain: .minors, level: .low, description: "minor mention"),
        ]
    }
    
    private func loadEmergencyResponses() {
        emergencyResponses = [
            .mentalHealth: EmergencyInfo(
                helplines: [
                    EmergencyInfo.Helpline(
                        name: "iCall",
                        number: "9152987821",
                        description: "psychosocial helpline by tata institute of social sciences",
                        available24x7: false
                    ),
                    EmergencyInfo.Helpline(
                        name: "Vandrevala Foundation",
                        number: "1860-2662-345",
                        description: "24/7 mental health support",
                        available24x7: true
                    ),
                    EmergencyInfo.Helpline(
                        name: "NIMHANS",
                        number: "080-46110007",
                        description: "national institute of mental health helpline",
                        available24x7: false
                    ),
                    EmergencyInfo.Helpline(
                        name: "Snehi",
                        number: "044-24640050",
                        description: "emotional support helpline",
                        available24x7: true
                    )
                ],
                resources: [
                    "reach out to a trusted friend or family member",
                    "contact a mental health professional",
                    "visit your nearest hospital emergency",
                    "call emergency services if in immediate danger"
                ],
                immediateMessage: "i'm here for you. what you're feeling is valid, and help is available. please reach out to one of these helplines - they're trained to support you through this."
            ),
            
            .emergency: EmergencyInfo(
                helplines: [
                    EmergencyInfo.Helpline(
                        name: "Emergency",
                        number: "112",
                        description: "national emergency number",
                        available24x7: true
                    ),
                    EmergencyInfo.Helpline(
                        name: "Ambulance",
                        number: "102",
                        description: "medical emergency",
                        available24x7: true
                    ),
                    EmergencyInfo.Helpline(
                        name: "Police",
                        number: "100",
                        description: "police emergency",
                        available24x7: true
                    ),
                    EmergencyInfo.Helpline(
                        name: "Fire",
                        number: "101",
                        description: "fire emergency",
                        available24x7: true
                    )
                ],
                resources: [
                    "call emergency services immediately",
                    "if safe, move to a secure location",
                    "alert people nearby who can help"
                ],
                immediateMessage: "this sounds like an emergency. please call 112 (emergency) or 102 (ambulance) immediately. your safety is the priority."
            ),
            
            .health: EmergencyInfo(
                helplines: [
                    EmergencyInfo.Helpline(
                        name: "Health Helpline",
                        number: "104",
                        description: "government health helpline",
                        available24x7: true
                    ),
                    EmergencyInfo.Helpline(
                        name: "COVID-19 Helpline",
                        number: "1075",
                        description: "covid-19 information",
                        available24x7: true
                    )
                ],
                resources: [
                    "consult a qualified healthcare professional",
                    "visit your nearest hospital or clinic",
                    "don't delay seeking medical attention"
                ],
                immediateMessage: "for health concerns, please consult a qualified healthcare professional. i can provide general information, but i cannot replace medical advice."
            ),
            
            .financial: EmergencyInfo(
                helplines: [
                    EmergencyInfo.Helpline(
                        name: "Cyber Crime",
                        number: "1930",
                        description: "financial fraud helpline",
                        available24x7: true
                    ),
                    EmergencyInfo.Helpline(
                        name: "RBI Helpline",
                        number: "14440",
                        description: "banking complaints",
                        available24x7: false
                    )
                ],
                resources: [
                    "report fraud to your bank immediately",
                    "file a complaint at cybercrime.gov.in",
                    "preserve all transaction records"
                ],
                immediateMessage: "if you suspect financial fraud, please report it immediately by calling 1930 (cyber crime helpline) and inform your bank."
            )
        ]
    }
    
    private func loadDisclaimers() {
        disclaimers = [
            .health: "this is general information only and not medical advice. please consult a qualified healthcare professional for personalized medical guidance.",
            .financial: "this is general information only and not financial advice. investments are subject to market risks. please consult a qualified financial advisor.",
            .legal: "this is general information only and not legal advice. please consult a qualified legal professional for specific legal matters.",
            .mentalHealth: "if you're in crisis or need immediate support, please reach out to a mental health professional or call a helpline.",
            .privacy: "please never share sensitive personal information like aadhaar, pan, bank details, or passwords in messages.",
            .gambling: "gambling involves financial risk. please gamble responsibly and be aware of applicable laws in your jurisdiction."
        ]
    }
}

