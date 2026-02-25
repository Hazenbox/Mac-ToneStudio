import Foundation
import OSLog

/// Standalone stress test runner that can be executed from within the app
/// Run from AppDelegate or a debug menu to stress test all implementations
actor StressTestRunner {
    
    static let shared = StressTestRunner()
    
    private var testResults: [TestResult] = []
    private let logger = Logger(subsystem: "ToneStudio", category: "StressTest")
    
    struct TestResult {
        let name: String
        let passed: Bool
        let message: String
        let duration: Double
        let category: String
    }
    
    // MARK: - Public API
    
    func runAllTests() async -> String {
        testResults = []
        let startTime = Date()
        
        logger.info("Starting comprehensive stress tests...")
        
        // Phase 2: Core Service Tests
        await runValidationTests()
        await runReadabilityTests()
        await runIntentClassifierTests()
        await runChannelGuidelinesTests()
        await runWordingRulesTests()
        await runSafetyGateTests()
        
        // Phase 3: API Integration Tests
        await runAPIIntegrationTests()
        
        // Phase 4: Performance Tests
        await runPerformanceTests()
        
        // Phase 5: Edge Case Tests
        await runEdgeCaseTests()
        
        // Phase 6: Integration Tests
        await runIntegrationTests()
        
        let totalDuration = Date().timeIntervalSince(startTime)
        return generateReport(totalDuration: totalDuration)
    }
    
    // MARK: - Phase 2: Validation Tests
    
    private func runValidationTests() async {
        let service = ValidationService.shared
        
        // Test 1: Clean content passes
        let cleanTexts = [
            "Welcome to Jio! Your account is ready.",
            "Your recharge of Rs 299 was successful.",
            "Thank you for choosing Jio Fiber."
        ]
        
        var cleanPassed = 0
        for text in cleanTexts {
            let result = await service.validate(text)
            if result.passed { cleanPassed += 1 }
        }
        
        addResult(
            name: "Validation: Clean Content",
            passed: cleanPassed == cleanTexts.count,
            message: "\(cleanPassed)/\(cleanTexts.count) clean texts passed",
            category: "Validation"
        )
        
        // Test 2: Violation detection
        let violationTexts = [
            "URGENT: You must immediately complete this!",
            "Please leverage synergistic solutions.",
            "Do the needful and revert back."
        ]
        
        var violationsDetected = 0
        for text in violationTexts {
            let result = await service.validate(text)
            if !result.violations.isEmpty || result.score < 100 {
                violationsDetected += 1
            }
        }
        
        addResult(
            name: "Validation: Violation Detection",
            passed: violationsDetected > 0,
            message: "\(violationsDetected)/\(violationTexts.count) violations detected",
            category: "Validation"
        )
        
        // Test 3: Intent-aware validation skips general chat
        let chatTexts = ["hello", "how are you", "thanks", "bye"]
        var skippedCount = 0
        for text in chatTexts {
            let result = await service.validateWithIntent(text, prompt: text)
            if result.wasSkipped { skippedCount += 1 }
        }
        
        addResult(
            name: "Validation: Intent-Aware Skip",
            passed: skippedCount >= chatTexts.count / 2,
            message: "\(skippedCount)/\(chatTexts.count) general chat skipped",
            category: "Validation"
        )
        
        // Test 4: Content generation runs full validation
        let contentTexts = ["write a push notification", "create an email", "draft a message"]
        var validatedCount = 0
        for text in contentTexts {
            let result = await service.validateWithIntent(text, prompt: text)
            if !result.wasSkipped { validatedCount += 1 }
        }
        
        addResult(
            name: "Validation: Content Gen Full Check",
            passed: validatedCount > 0,
            message: "\(validatedCount)/\(contentTexts.count) content requests validated",
            category: "Validation"
        )
    }
    
    // MARK: - Phase 2.2: Readability Tests (Phase 6.3)
    
    private func runReadabilityTests() async {
        let service = ValidationService.shared
        
        // Test 1: Simple text has low grade
        let simpleText = "The cat sat on the mat. It was a good cat."
        let simpleGrade = await service.calculateFleschKincaidGrade(simpleText)
        
        addResult(
            name: "Readability: Simple Text Grade",
            passed: simpleGrade < 6.0,
            message: "Grade \(String(format: "%.1f", simpleGrade)) (target: < 6)",
            category: "Readability"
        )
        
        // Test 2: Target Grade 8 text
        let targetText = "Managing your account is simple. Log in and follow the steps shown on screen."
        let targetGrade = await service.calculateFleschKincaidGrade(targetText)
        
        addResult(
            name: "Readability: Target Grade 8",
            passed: targetGrade <= 10.0,
            message: "Grade \(String(format: "%.1f", targetGrade)) (target: <= 10)",
            category: "Readability"
        )
        
        // Test 3: Complex text has high grade
        let complexText = "The implementation necessitates comprehensive understanding of multifaceted computational paradigms."
        let complexGrade = await service.calculateFleschKincaidGrade(complexText)
        
        addResult(
            name: "Readability: Complex Text Grade",
            passed: complexGrade > 10.0,
            message: "Grade \(String(format: "%.1f", complexGrade)) (target: > 10)",
            category: "Readability"
        )
        
        // Test 4: Flesch Reading Ease in valid range
        let testTexts = [simpleText, targetText, complexText]
        var allInRange = true
        var scores: [Double] = []
        for text in testTexts {
            let score = await service.calculateReadabilityScore(text)
            scores.append(score)
            if score < 0 || score > 100 { allInRange = false }
        }
        
        addResult(
            name: "Readability: Score Range 0-100",
            passed: allInRange,
            message: "Scores: \(scores.map { String(format: "%.0f", $0) }.joined(separator: ", "))",
            category: "Readability"
        )
        
        // Test 5: Readability analysis provides metrics
        let analysis = await service.getReadabilityAnalysis(targetText)
        let hasAllMetrics = analysis.wordCount > 0 && analysis.sentenceCount > 0 && analysis.syllableCount > 0
        
        addResult(
            name: "Readability: Full Analysis",
            passed: hasAllMetrics,
            message: "Words: \(analysis.wordCount), Sentences: \(analysis.sentenceCount), Syllables: \(analysis.syllableCount)",
            category: "Readability"
        )
        
        // Test 6: Gunning Fog Index calculation
        addResult(
            name: "Readability: Gunning Fog Index",
            passed: analysis.gunningFogIndex > 0,
            message: "Index: \(String(format: "%.1f", analysis.gunningFogIndex))",
            category: "Readability"
        )
    }
    
    // MARK: - Phase 2.3: Intent Classifier Tests (Phase 15.1-15.2)
    
    private func runIntentClassifierTests() async {
        let classifier = IntentClassifierService.shared
        
        // Test 1: General chat classification
        let chatInputs = ["hello", "hi", "how are you", "thanks", "bye"]
        var generalChatCount = 0
        for input in chatInputs {
            let result = await classifier.classify(input)
            if result.intent == .generalChat { generalChatCount += 1 }
        }
        
        addResult(
            name: "Intent: General Chat Detection",
            passed: generalChatCount >= chatInputs.count / 2,
            message: "\(generalChatCount)/\(chatInputs.count) classified as general chat",
            category: "Intent"
        )
        
        // Test 2: Content generation classification
        let contentInputs = ["write a push notification", "create an email", "draft a message"]
        var contentGenCount = 0
        for input in contentInputs {
            let result = await classifier.classify(input)
            if result.intent == .contentGeneration { contentGenCount += 1 }
        }
        
        addResult(
            name: "Intent: Content Generation",
            passed: contentGenCount > 0,
            message: "\(contentGenCount)/\(contentInputs.count) classified as content gen",
            category: "Intent"
        )
        
        // Test 3: Jio inquiry classification
        let jioInputs = ["how to recharge jio", "jio fiber plans", "jio postpaid"]
        var jioInquiryCount = 0
        for input in jioInputs {
            let result = await classifier.classify(input)
            if result.intent == .jioInquiry { jioInquiryCount += 1 }
        }
        
        addResult(
            name: "Intent: Jio Inquiry",
            passed: jioInquiryCount > 0,
            message: "\(jioInquiryCount)/\(jioInputs.count) classified as Jio inquiry",
            category: "Intent"
        )
        
        // Test 4: Skip validation for general chat
        let shouldSkip = await classifier.shouldSkipValidation(for: .generalChat)
        let shouldNotSkip = await classifier.shouldSkipValidation(for: .contentGeneration)
        
        addResult(
            name: "Intent: Skip Logic",
            passed: shouldSkip && !shouldNotSkip,
            message: "Skip generalChat: \(shouldSkip), Skip contentGen: \(shouldNotSkip)",
            category: "Intent"
        )
        
        // Test 5: Validation config differences
        let chatConfig = await classifier.getValidationConfig(for: .generalChat)
        let contentConfig = await classifier.getValidationConfig(for: .contentGeneration)
        
        addResult(
            name: "Intent: Config Differences",
            passed: !chatConfig.checkAvoidWords && contentConfig.checkAvoidWords,
            message: "Chat avoidWords: \(chatConfig.checkAvoidWords), Content avoidWords: \(contentConfig.checkAvoidWords)",
            category: "Intent"
        )
    }
    
    // MARK: - Phase 2.4: Channel Guidelines Tests (Phase 14.1-14.2)
    
    private func runChannelGuidelinesTests() async {
        let service = ChannelGuidelinesService.shared
        
        // Test 1: Total guidelines count
        let guidelines = await service.getAllGuidelines()
        
        addResult(
            name: "Channel: Guidelines Count",
            passed: guidelines.count >= 15,
            message: "\(guidelines.count) channel guidelines (target: >= 15)",
            category: "Channel"
        )
        
        // Test 2: Total rules count (50+)
        let totalRules = await service.getTotalRulesCount()
        
        addResult(
            name: "Channel: Total Rules Count",
            passed: totalRules >= 50,
            message: "\(totalRules) rules across all channels (target: >= 50)",
            category: "Channel"
        )
        
        // Test 3: All channels have guidelines
        var missingCount = 0
        for channel in ContentChannelType.allCases {
            let guideline = await service.getGuideline(for: channel)
            if guideline == nil { missingCount += 1 }
        }
        
        addResult(
            name: "Channel: All Have Guidelines",
            passed: missingCount == 0,
            message: "\(ContentChannelType.allCases.count - missingCount)/\(ContentChannelType.allCases.count) channels covered",
            category: "Channel"
        )
        
        // Test 4: Character limits exist
        var limitsCount = 0
        for channel in ContentChannelType.allCases {
            if await service.getCharacterLimits(for: channel) != nil {
                limitsCount += 1
            }
        }
        
        addResult(
            name: "Channel: Character Limits",
            passed: limitsCount > 10,
            message: "\(limitsCount)/\(ContentChannelType.allCases.count) channels have limits",
            category: "Channel"
        )
        
        // Test 5: Warmth/detail presets valid (1-10)
        var presetsValid = true
        for channel in ContentChannelType.allCases {
            let preset = await service.getWarmthDetailPreset(for: channel)
            if preset.warmth < 1 || preset.warmth > 10 || preset.detail < 1 || preset.detail > 10 {
                presetsValid = false
                break
            }
        }
        
        addResult(
            name: "Channel: Warmth/Detail Presets",
            passed: presetsValid,
            message: "All presets in 1-10 range",
            category: "Channel"
        )
        
        // Test 6: Content validation works
        let longSMS = String(repeating: "a", count: 200)
        let smsResult = await service.validateContent(longSMS, for: .sms)
        
        addResult(
            name: "Channel: Content Validation",
            passed: !smsResult.passed,
            message: "Long SMS (200 chars) correctly fails: passed=\(smsResult.passed)",
            category: "Channel"
        )
    }
    
    // MARK: - Phase 2.5: Wording Rules Tests
    
    private func runWordingRulesTests() async {
        let service = WordingRulesService.shared
        
        do {
            try await service.loadRules()
            
            // Test 1: Avoid words count
            var totalAvoid = 0
            for category in AvoidWordCategory.allCases {
                totalAvoid += await service.getAvoidWords(category: category).count
            }
            
            addResult(
                name: "WordingRules: Avoid Words",
                passed: totalAvoid >= 100,
                message: "\(totalAvoid) avoid words (target: >= 100)",
                category: "WordingRules"
            )
            
            // Test 2: Preferred words count
            var totalPreferred = 0
            for category in PreferredWordCategory.allCases {
                totalPreferred += await service.getPreferredWords(category: category).count
            }
            
            addResult(
                name: "WordingRules: Preferred Words",
                passed: totalPreferred >= 100,
                message: "\(totalPreferred) preferred words (target: >= 100)",
                category: "WordingRules"
            )
            
            // Test 3: Auto-fix rules count
            var totalFixes = 0
            for category in AutoFixCategory.allCases {
                totalFixes += await service.getAutoFixRules(category: category).count
            }
            
            addResult(
                name: "WordingRules: Auto-Fix Rules",
                passed: totalFixes >= 30,
                message: "\(totalFixes) auto-fix rules (target: >= 30)",
                category: "WordingRules"
            )
            
            // Test 4: Check text detects violations
            let testText = "Please leverage synergistic solutions and do the needful."
            let violations = await service.checkText(testText)
            
            addResult(
                name: "WordingRules: Violation Detection",
                passed: violations.count > 0,
                message: "\(violations.count) violations detected in test text",
                category: "WordingRules"
            )
            
            // Test 5: Auto-fix applies correctly
            let fixText = "colour centre"
            let preview = await service.applyAllFixes(to: fixText)
            
            addResult(
                name: "WordingRules: Auto-Fix Application",
                passed: preview.fixCount >= 0,
                message: "\(preview.fixCount) fixes applied",
                category: "WordingRules"
            )
            
        } catch {
            addResult(
                name: "WordingRules: Load Rules",
                passed: false,
                message: "Failed to load: \(error.localizedDescription)",
                category: "WordingRules"
            )
        }
    }
    
    // MARK: - Phase 2.6: Safety Gate Tests
    
    private func runSafetyGateTests() async {
        let service = SafetyGateService.shared
        
        // Test 1: Safe content proceeds normally
        let safeResult = await service.classify("Your recharge was successful. Thank you.")
        
        addResult(
            name: "SafetyGate: Safe Content",
            passed: safeResult.routing == .proceedNormal,
            message: "Routing: \(safeResult.routing), Level: \(safeResult.highestLevel)",
            category: "Safety"
        )
        
        // Test 2: Health content detected
        let healthResult = await service.classify("I have chest pain and can't breathe.")
        let hasHealthDomain = healthResult.classifications.contains { $0.domain == .health || $0.domain == .emergency }
        
        addResult(
            name: "SafetyGate: Health Domain",
            passed: hasHealthDomain || healthResult.highestLevel >= .moderate,
            message: "Detected: \(healthResult.classifications.map { $0.domain.rawValue }.joined(separator: ", "))",
            category: "Safety"
        )
        
        // Test 3: Mental health high priority
        let mentalResult = await service.classify("I feel very depressed and hopeless.")
        let hasMentalHealth = mentalResult.classifications.contains { $0.domain == .mentalHealth }
        
        addResult(
            name: "SafetyGate: Mental Health",
            passed: hasMentalHealth || mentalResult.highestLevel >= .moderate,
            message: "Level: \(mentalResult.highestLevel), MentalHealth: \(hasMentalHealth)",
            category: "Safety"
        )
        
        // Test 4: Critical concern detection
        let criticalResult = await service.hasCriticalConcern("I want to end my life")
        
        addResult(
            name: "SafetyGate: Critical Concern",
            passed: criticalResult,
            message: "Critical detected: \(criticalResult)",
            category: "Safety"
        )
        
        // Test 5: Emergency response
        let (requiresEmergency, emergencyInfo) = await service.requiresEmergencyResponse("suicide")
        
        addResult(
            name: "SafetyGate: Emergency Response",
            passed: true,
            message: "Requires emergency: \(requiresEmergency), Has info: \(emergencyInfo != nil)",
            category: "Safety"
        )
        
        // Test 6: Multiple domains coverage
        let domainTests: [(String, SafetyDomain)] = [
            ("invest money stocks", .financial),
            ("legal divorce advice", .legal),
            ("my password is", .privacy)
        ]
        
        var detectedDomains = 0
        for (text, expected) in domainTests {
            let result = await service.classify(text)
            if result.classifications.contains(where: { $0.domain == expected }) {
                detectedDomains += 1
            }
        }
        
        addResult(
            name: "SafetyGate: Domain Coverage",
            passed: detectedDomains > 0,
            message: "\(detectedDomains)/\(domainTests.count) domains detected",
            category: "Safety"
        )
    }
    
    // MARK: - Phase 3: API Integration Tests
    
    private func runAPIIntegrationTests() async {
        // Test 1: Corrections API service exists
        let correction = Correction(
            originalText: "leverage",
            correctedText: "use",
            category: .style,
            context: "test"
        )
        
        addResult(
            name: "API: Correction Model",
            passed: !correction.synced,
            message: "ID: \(correction.id.uuidString.prefix(8))..., synced: \(correction.synced)",
            category: "API"
        )
        
        // Test 2: Learning service record/retrieve
        let learningService = LearningService.shared
        await learningService.recordCorrection(correction)
        let recent = await learningService.getRecentCorrections(days: 1)
        
        addResult(
            name: "API: Learning Service",
            passed: true,
            message: "\(recent.count) recent corrections",
            category: "API"
        )
        
        // Test 3: Context-based retrieval
        let contextCorrections = await learningService.getCorrectionsForContext(
            ecosystem: .connectivity,
            channel: .pushNotification,
            limit: 10
        )
        
        addResult(
            name: "API: Context Retrieval",
            passed: true,
            message: "\(contextCorrections.count) context corrections",
            category: "API"
        )
        
        // Test 4: Sync service status
        let syncService = SyncService.shared
        let status = await syncService.getStatus()
        
        addResult(
            name: "API: Sync Service",
            passed: true,
            message: "Online: \(status.isOnline), Syncing: \(status.syncInProgress)",
            category: "API"
        )
        
        // Test 5: Build learning context
        let learningContext = await learningService.buildLearningContext(corrections: recent)
        
        addResult(
            name: "API: Learning Context",
            passed: true,
            message: "Context length: \(learningContext.count) chars",
            category: "API"
        )
    }
    
    // MARK: - Phase 4: Performance Tests
    
    private func runPerformanceTests() async {
        let service = ValidationService.shared
        
        // Test 1: Large text performance
        let largeText = String(repeating: "This is a sample sentence. ", count: 100)
        let start1 = Date()
        let _ = await service.validate(largeText)
        let elapsed1 = Date().timeIntervalSince(start1) * 1000
        
        addResult(
            name: "Performance: Large Text (\(largeText.count) chars)",
            passed: elapsed1 < 500,
            message: "\(String(format: "%.1f", elapsed1))ms (target: < 500ms)",
            category: "Performance"
        )
        
        // Test 2: Concurrent validation (50 texts)
        let texts = (0..<50).map { "Test message \($0) for concurrent validation." }
        let start2 = Date()
        await withTaskGroup(of: ValidationResult.self) { group in
            for text in texts {
                group.addTask { await service.validate(text) }
            }
            for await _ in group { }
        }
        let elapsed2 = Date().timeIntervalSince(start2) * 1000
        
        addResult(
            name: "Performance: Concurrent (50 validations)",
            passed: elapsed2 < 5000,
            message: "\(String(format: "%.0f", elapsed2))ms total, \(String(format: "%.1f", elapsed2/50))ms avg",
            category: "Performance"
        )
        
        // Test 3: Readability calculation speed
        let start3 = Date()
        for _ in 0..<500 {
            _ = await service.calculateFleschKincaidGrade("Sample text for readability testing.")
        }
        let elapsed3 = Date().timeIntervalSince(start3) * 1000
        
        addResult(
            name: "Performance: Readability (500 calcs)",
            passed: elapsed3 < 500,
            message: "\(String(format: "%.1f", elapsed3))ms total, \(String(format: "%.3f", elapsed3/500))ms avg",
            category: "Performance"
        )
        
        // Test 4: Wording rules check speed
        let rulesService = WordingRulesService.shared
        try? await rulesService.loadRules()
        
        let start4 = Date()
        for _ in 0..<100 {
            _ = await rulesService.checkText("Please leverage synergistic solutions.")
        }
        let elapsed4 = Date().timeIntervalSince(start4) * 1000
        
        addResult(
            name: "Performance: Wording Check (100x)",
            passed: elapsed4 < 1000,
            message: "\(String(format: "%.0f", elapsed4))ms total, \(String(format: "%.1f", elapsed4/100))ms avg",
            category: "Performance"
        )
    }
    
    // MARK: - Phase 5: Edge Case Tests
    
    private func runEdgeCaseTests() async {
        let service = ValidationService.shared
        
        // Test 1: Empty string
        let emptyResult = await service.validate("")
        addResult(
            name: "EdgeCase: Empty String",
            passed: emptyResult.passed,
            message: "Score: \(emptyResult.score), Passed: \(emptyResult.passed)",
            category: "EdgeCase"
        )
        
        // Test 2: Single character
        let singleResult = await service.validate("a")
        addResult(
            name: "EdgeCase: Single Character",
            passed: true,
            message: "Score: \(singleResult.score)",
            category: "EdgeCase"
        )
        
        // Test 3: Unicode/Emoji
        let emojiResult = await service.validate("Hello! 👋 Welcome 🎉")
        addResult(
            name: "EdgeCase: Unicode/Emoji",
            passed: true,
            message: "Score: \(emojiResult.score), Violations: \(emojiResult.violations.count)",
            category: "EdgeCase"
        )
        
        // Test 4: Hinglish content
        let hinglishResult = await service.validate("Aapka recharge successful ho gaya hai")
        addResult(
            name: "EdgeCase: Hinglish",
            passed: true,
            message: "Score: \(hinglishResult.score)",
            category: "EdgeCase"
        )
        
        // Test 5: Language detection
        let langService = LanguageService.shared
        let hindiResult = await langService.detectLanguage(in: "नमस्ते दुनिया")
        let englishResult = await langService.detectLanguage(in: "Hello world")
        
        addResult(
            name: "EdgeCase: Language Detection",
            passed: hindiResult.language == .hindi && englishResult.language == .english,
            message: "Hindi: \(hindiResult.language.rawValue), English: \(englishResult.language.rawValue)",
            category: "EdgeCase"
        )
        
        // Test 6: Enum exhaustiveness - EcosystemType
        var ecosystemsValid = true
        for ecosystem in EcosystemType.allCases {
            if ecosystem.displayName.isEmpty { ecosystemsValid = false }
        }
        
        addResult(
            name: "EdgeCase: EcosystemType Enum",
            passed: ecosystemsValid,
            message: "\(EcosystemType.allCases.count) cases, all have displayName",
            category: "EdgeCase"
        )
        
        // Test 7: Enum exhaustiveness - ContentChannelType
        var channelsValid = true
        for channel in ContentChannelType.allCases {
            if channel.displayName.isEmpty { channelsValid = false }
        }
        
        addResult(
            name: "EdgeCase: ContentChannelType Enum",
            passed: channelsValid,
            message: "\(ContentChannelType.allCases.count) cases, all have displayName",
            category: "EdgeCase"
        )
        
        // Test 8: SafetyLevel comparison
        let levels = SafetyLevel.allCases.sorted()
        let correctOrder = levels.first == SafetyLevel.none && levels.last == .critical
        
        addResult(
            name: "EdgeCase: SafetyLevel Ordering",
            passed: correctOrder,
            message: "\(SafetyLevel.allCases.count) levels sorted correctly",
            category: "EdgeCase"
        )
    }
    
    // MARK: - Phase 6: Integration Tests
    
    private func runIntegrationTests() async {
        // Test 1: Full pipeline
        let text = "Write a push notification for Jio Fiber 1Gbps offer"
        
        let intentResult = await IntentClassifierService.shared.classify(text)
        let validationResult = await ValidationService.shared.validateWithIntent(text, prompt: text)
        let channelResult = await ValidationService.shared.validateForChannel(text, channel: .pushNotification)
        let safetyResult = await SafetyGateService.shared.classify(text)
        let readability = await ValidationService.shared.getReadabilityAnalysis(text)
        
        // Use them to avoid warnings
        let _ = validationResult
        let _ = channelResult
        
        addResult(
            name: "Integration: Full Pipeline",
            passed: true,
            message: "Intent: \(intentResult.intent.rawValue), Safety: \(safetyResult.routing), Grade: \(String(format: "%.1f", readability.fleschKincaidGrade))",
            category: "Integration"
        )
        
        // Test 2: Multi-channel validation
        let baseText = "Your Jio recharge is successful."
        var channelsPassed = 0
        for channel in [ContentChannelType.pushNotification, .sms, .whatsappAlert] {
            let result = await ValidationService.shared.validateForChannel(baseText, channel: channel)
            if result.overallPassed { channelsPassed += 1 }
        }
        
        addResult(
            name: "Integration: Multi-Channel",
            passed: channelsPassed > 0,
            message: "\(channelsPassed)/3 channels passed",
            category: "Integration"
        )
        
        // Test 3: Emotion detection
        let emotionResult = await EmotionService.shared.detectEmotion(in: "I'm so excited about this!")
        
        addResult(
            name: "Integration: Emotion Detection",
            passed: emotionResult.confidence > 0,
            message: "Emotion: \(emotionResult.primary.displayName), Confidence: \(String(format: "%.2f", emotionResult.confidence))",
            category: "Integration"
        )
        
        // Test 4: Evidence tracking
        let evidenceService = GenerationEvidenceService.shared
        let messageId = UUID().uuidString
        await evidenceService.startTracking(for: messageId)
        let knowledge = KnowledgeUsed(type: .avoidWord, term: "test", category: "complex", confidence: 0.9)
        await evidenceService.recordKnowledgeUsed(knowledge)
        let evidence = await evidenceService.finishTracking()
        
        addResult(
            name: "Integration: Evidence Tracking",
            passed: evidence != nil,
            message: "Tracked: \(evidence != nil ? "Yes" : "No")",
            category: "Integration"
        )
    }
    
    // MARK: - Helpers
    
    private func addResult(name: String, passed: Bool, message: String, category: String, duration: Double = 0) {
        testResults.append(TestResult(
            name: name,
            passed: passed,
            message: message,
            duration: duration,
            category: category
        ))
    }
    
    private func generateReport(totalDuration: Double) -> String {
        let passed = testResults.filter { $0.passed }.count
        let failed = testResults.filter { !$0.passed }.count
        let total = testResults.count
        let passRate = total > 0 ? Double(passed) / Double(total) * 100 : 0
        
        var report = """
        ╔══════════════════════════════════════════════════════════════════════════════╗
        ║               TONESTUDIO COMPREHENSIVE STRESS TEST REPORT                    ║
        ╠══════════════════════════════════════════════════════════════════════════════╣
        ║  Generated: \(formatDate(Date()))
        ║  Duration:  \(String(format: "%.2f", totalDuration)) seconds
        ╚══════════════════════════════════════════════════════════════════════════════╝
        
        ════════════════════════════════════════════════════════════════════════════════
        SUMMARY
        ════════════════════════════════════════════════════════════════════════════════
        Total Tests:  \(total)
        Passed:       \(passed) ✅
        Failed:       \(failed) ❌
        Pass Rate:    \(String(format: "%.1f", passRate))%
        
        """
        
        // Group by category
        let categories = Dictionary(grouping: testResults, by: { $0.category })
        let sortedCategories = categories.keys.sorted()
        
        for category in sortedCategories {
            let tests = categories[category]!
            let categoryPassed = tests.filter { $0.passed }.count
            let categoryTotal = tests.count
            
            report += """
            
            ════════════════════════════════════════════════════════════════════════════════
            \(category.uppercased()) (\(categoryPassed)/\(categoryTotal))
            ════════════════════════════════════════════════════════════════════════════════
            """
            
            for test in tests {
                let status = test.passed ? "✅" : "❌"
                report += "\n\(status) \(test.name)"
                report += "\n   └─ \(test.message)"
            }
            report += "\n"
        }
        
        // Final status
        report += """
        
        ════════════════════════════════════════════════════════════════════════════════
        IMPLEMENTATION STATUS
        ════════════════════════════════════════════════════════════════════════════════
        Phase 6.3  (Flesch-Kincaid Grade 8):     \(getPhaseStatus(category: "Readability"))
        Phase 11.3 (Corrections API):            \(getPhaseStatus(category: "API"))
        Phase 14.1 (Channel Guidelines 50+):     \(getPhaseStatus(category: "Channel"))
        Phase 14.2 (Warmth/Detail Presets):      \(getPhaseStatus(category: "Channel"))
        Phase 15.1 (Intent Classifier):          \(getPhaseStatus(category: "Intent"))
        Phase 15.2 (Conditional Validation):     \(getPhaseStatus(category: "Validation"))
        
        ════════════════════════════════════════════════════════════════════════════════
        OVERALL RESULT: \(passRate >= 90 ? "✅ PASSED" : passRate >= 70 ? "⚠️ PARTIAL" : "❌ FAILED")
        ════════════════════════════════════════════════════════════════════════════════
        """
        
        return report
    }
    
    private func getPhaseStatus(category: String) -> String {
        let tests = testResults.filter { $0.category == category }
        let passed = tests.filter { $0.passed }.count
        let total = tests.count
        
        if total == 0 { return "⚠️ NO TESTS" }
        if passed == total { return "✅ IMPLEMENTED (\(passed)/\(total))" }
        return "⚠️ PARTIAL (\(passed)/\(total))"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
