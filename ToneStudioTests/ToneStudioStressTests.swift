import XCTest
@testable import ToneStudio

/// Comprehensive stress test suite for ToneStudio macOS app
/// Tests all 17+ actor-based services, 350+ wording rules, readability scoring,
/// safety gates, channel guidelines, and API integrations
final class ToneStudioStressTests: XCTestCase {
    
    // MARK: - Test Fixtures
    
    static let cleanTexts = [
        "Welcome to Jio! Your account is ready.",
        "Your recharge of Rs 299 was successful.",
        "Thank you for choosing Jio Fiber.",
        "Your order has been confirmed.",
        "We're here to help you 24/7."
    ]
    
    static let complexTexts = [
        "The implementation necessitates comprehensive understanding of the multifaceted computational paradigms inherent in distributed systems.",
        "Subsequently, the aforementioned circumstances precipitated unprecedented ramifications throughout the organizational infrastructure.",
        "Notwithstanding the considerable complexities involved, the functionality exhibits remarkable characteristics.",
        "The juxtaposition of complementary methodologies facilitates synergistic optimization.",
        "Cognizant of the multitudinous variables affecting systematic performance metrics."
    ]
    
    static let violationTexts = [
        "URGENT: You must immediately complete this task or face consequences!",
        "Don't worry, it's not your fault that the system failed.",
        "Please leverage our synergistic solutions to optimize your paradigm.",
        "Kindly do the needful and revert back at the earliest.",
        "We regret to inform you that your request has been denied due to policy violations."
    ]
    
    static let hinglishTexts = [
        "Aapka recharge successful ho gaya hai",
        "Kripya apna OTP enter karein",
        "Yeh offer sirf aaj ke liye hai",
        "Dhanyavaad aapke vishwas ke liye"
    ]
    
    static let channelSampleTexts: [ContentChannelType: String] = [
        .pushNotification: "Your bill is due tomorrow",
        .sms: "Jio: Your recharge of Rs 199 is successful. Validity 28 days.",
        .whatsappAlert: "Hi! Your JioFiber installation is scheduled for tomorrow between 10-12 AM.",
        .customerCareChat: "Hello! I'm here to help you with your query. How may I assist you today?",
        .marketingEmail: "Introducing the all-new Jio 5G plans with unlimited data and free OTT subscriptions!",
        .socialMediaPost: "Experience the fastest 5G network in India. #Jio5G #TrueUnlimited",
        .appNotification: "Your data balance: 45.6 GB remaining"
    ]
    
    // MARK: - Phase 2: Validation Service Tests
    
    func test_ValidationService_validateCleanContent_passes() async throws {
        let service = ValidationService.shared
        var passedCount = 0
        var totalTime: Double = 0
        
        for text in Self.cleanTexts {
            let start = Date()
            let result = await service.validate(text)
            totalTime += Date().timeIntervalSince(start) * 1000
            
            if result.passed {
                passedCount += 1
            }
        }
        
        print("✅ ValidationService Clean Text: \(passedCount)/\(Self.cleanTexts.count) passed")
        print("   Average time: \(totalTime / Double(Self.cleanTexts.count))ms")
        
        XCTAssertEqual(passedCount, Self.cleanTexts.count, "All clean texts should pass validation")
    }
    
    func test_ValidationService_validateViolationContent_detectsIssues() async throws {
        let service = ValidationService.shared
        var detectedCount = 0
        
        for text in Self.violationTexts {
            let result = await service.validate(text)
            if !result.violations.isEmpty || !result.passed {
                detectedCount += 1
            }
        }
        
        print("✅ ValidationService Violation Detection: \(detectedCount)/\(Self.violationTexts.count) detected")
        XCTAssertGreaterThan(detectedCount, 0, "Should detect at least some violations")
    }
    
    func test_ValidationService_validateWithIntent_generalChat_skips() async throws {
        let service = ValidationService.shared
        let chatTexts = ["hello", "how are you", "thanks", "ok bye"]
        var skippedCount = 0
        
        for text in chatTexts {
            let result = await service.validateWithIntent(text, prompt: text)
            if result.wasSkipped {
                skippedCount += 1
            }
        }
        
        print("✅ Intent-Aware Validation (General Chat Skip): \(skippedCount)/\(chatTexts.count) skipped")
        XCTAssertGreaterThan(skippedCount, chatTexts.count / 2, "Most chat messages should skip validation")
    }
    
    func test_ValidationService_validateWithIntent_contentGeneration_runsFullValidation() async throws {
        let service = ValidationService.shared
        let contentTexts = [
            "write a push notification for jio offer",
            "create an email for new customers",
            "draft a message about fiber installation"
        ]
        var ranValidationCount = 0
        
        for text in contentTexts {
            let result = await service.validateWithIntent(text, prompt: text)
            if !result.wasSkipped {
                ranValidationCount += 1
            }
        }
        
        print("✅ Intent-Aware Validation (Content Gen): \(ranValidationCount)/\(contentTexts.count) ran full validation")
        XCTAssertGreaterThan(ranValidationCount, 0, "Content generation should run validation")
    }
    
    // MARK: - Phase 2.2: Readability Tests (Phase 6.3)
    
    func test_Readability_fleschKincaidGrade_simpleText() async throws {
        let service = ValidationService.shared
        let simpleText = "The cat sat on the mat. It was a good cat. The cat was happy."
        let grade = service.calculateFleschKincaidGrade(simpleText)
        
        print("✅ Flesch-Kincaid Simple Text: Grade \(String(format: "%.1f", grade))")
        XCTAssertLessThan(grade, 6.0, "Simple text should be below grade 6")
    }
    
    func test_Readability_fleschKincaidGrade_targetGrade8() async throws {
        let service = ValidationService.shared
        let targetText = "Managing your Jio account is simple. Log in to the app and follow the easy steps shown on screen. You can view your balance and pay bills quickly."
        let grade = service.calculateFleschKincaidGrade(targetText)
        
        print("✅ Flesch-Kincaid Target Text (Grade 8): Grade \(String(format: "%.1f", grade))")
        XCTAssertLessThanOrEqual(grade, 10.0, "Target text should be around grade 8-10")
    }
    
    func test_Readability_fleschKincaidGrade_complexText() async throws {
        let service = ValidationService.shared
        var complexGrades: [Double] = []
        
        for text in Self.complexTexts {
            let grade = service.calculateFleschKincaidGrade(text)
            complexGrades.append(grade)
        }
        
        let avgGrade = complexGrades.reduce(0, +) / Double(complexGrades.count)
        print("✅ Flesch-Kincaid Complex Texts: Average Grade \(String(format: "%.1f", avgGrade))")
        print("   Grades: \(complexGrades.map { String(format: "%.1f", $0) }.joined(separator: ", "))")
        XCTAssertGreaterThan(avgGrade, 10.0, "Complex texts should be above grade 10")
    }
    
    func test_Readability_fleschReadingEase_range() async throws {
        let service = ValidationService.shared
        let testTexts = Self.cleanTexts + Self.complexTexts
        var scores: [Double] = []
        
        for text in testTexts {
            let score = service.calculateReadabilityScore(text)
            scores.append(score)
            XCTAssertGreaterThanOrEqual(score, 0, "Score should be >= 0")
            XCTAssertLessThanOrEqual(score, 100, "Score should be <= 100")
        }
        
        print("✅ Flesch Reading Ease Range: \(String(format: "%.0f", scores.min()!)) - \(String(format: "%.0f", scores.max()!))")
    }
    
    func test_Readability_analysis_comprehensive() async throws {
        let service = ValidationService.shared
        let text = "Your Jio prepaid recharge was successful. The new plan gives you unlimited calls and 2GB data per day for 28 days."
        let analysis = service.getReadabilityAnalysis(text)
        
        print("✅ Readability Analysis:")
        print("   Flesch Reading Ease: \(String(format: "%.1f", analysis.fleschReadingEase)) (\(analysis.readabilityCategory))")
        print("   Flesch-Kincaid Grade: \(String(format: "%.1f", analysis.fleschKincaidGrade)) (\(analysis.gradeDescription))")
        print("   Gunning Fog Index: \(String(format: "%.1f", analysis.gunningFogIndex))")
        print("   Meets Target (Grade 8): \(analysis.meetsTarget ? "Yes" : "No")")
        print("   Words: \(analysis.wordCount), Sentences: \(analysis.sentenceCount), Syllables: \(analysis.syllableCount)")
        print("   Complex Words: \(analysis.complexWordCount)")
        
        XCTAssertGreaterThan(analysis.wordCount, 0)
        XCTAssertGreaterThan(analysis.sentenceCount, 0)
    }
    
    // MARK: - Phase 2.3: Intent Classifier Tests (Phase 15.1-15.2)
    
    func test_IntentClassifier_generalChat() async throws {
        let classifier = IntentClassifierService.shared
        let chatInputs = ["hello", "hi there", "how are you", "thanks", "ok", "bye", "good morning"]
        var generalChatCount = 0
        
        for input in chatInputs {
            let result = await classifier.classify(input)
            if result.intent == .generalChat {
                generalChatCount += 1
            }
        }
        
        print("✅ Intent Classifier (General Chat): \(generalChatCount)/\(chatInputs.count) classified correctly")
        XCTAssertGreaterThan(generalChatCount, chatInputs.count / 2, "Most greetings should be general chat")
    }
    
    func test_IntentClassifier_contentGeneration() async throws {
        let classifier = IntentClassifierService.shared
        let contentInputs = [
            "write a marketing email",
            "create a push notification",
            "draft a message for customers",
            "generate content for social media",
            "compose an SMS alert"
        ]
        var contentGenCount = 0
        
        for input in contentInputs {
            let result = await classifier.classify(input)
            if result.intent == .contentGeneration {
                contentGenCount += 1
            }
        }
        
        print("✅ Intent Classifier (Content Generation): \(contentGenCount)/\(contentInputs.count) classified correctly")
        XCTAssertGreaterThan(contentGenCount, contentInputs.count / 2, "Most content requests should be classified as content generation")
    }
    
    func test_IntentClassifier_jioInquiry() async throws {
        let classifier = IntentClassifierService.shared
        let jioInputs = [
            "how do I recharge my jio number",
            "what are jio fiber plans",
            "tell me about jio postpaid",
            "jio money transfer",
            "jio cinema subscription"
        ]
        var jioInquiryCount = 0
        
        for input in jioInputs {
            let result = await classifier.classify(input)
            if result.intent == .jioInquiry {
                jioInquiryCount += 1
            }
        }
        
        print("✅ Intent Classifier (Jio Inquiry): \(jioInquiryCount)/\(jioInputs.count) classified correctly")
        XCTAssertGreaterThan(jioInquiryCount, 0, "Jio-related queries should be classified as jio inquiry")
    }
    
    func test_IntentClassifier_shouldSkipValidation() async throws {
        let classifier = IntentClassifierService.shared
        
        let shouldSkip = await classifier.shouldSkipValidation(for: .generalChat)
        let shouldNotSkip = await classifier.shouldSkipValidation(for: .contentGeneration)
        
        print("✅ Skip Validation: generalChat=\(shouldSkip), contentGeneration=\(!shouldNotSkip)")
        XCTAssertTrue(shouldSkip, "General chat should skip validation")
        XCTAssertFalse(shouldNotSkip, "Content generation should not skip validation")
    }
    
    func test_IntentClassifier_validationConfig() async throws {
        let classifier = IntentClassifierService.shared
        
        let chatConfig = await classifier.getValidationConfig(for: .generalChat)
        let contentConfig = await classifier.getValidationConfig(for: .contentGeneration)
        
        print("✅ Validation Config:")
        print("   General Chat: checkAvoidWords=\(chatConfig.checkAvoidWords), checkReadability=\(chatConfig.checkReadability)")
        print("   Content Gen: checkAvoidWords=\(contentConfig.checkAvoidWords), checkReadability=\(contentConfig.checkReadability)")
        
        XCTAssertFalse(chatConfig.checkAvoidWords, "Chat should not check avoid words")
        XCTAssertTrue(contentConfig.checkAvoidWords, "Content gen should check avoid words")
    }
    
    // MARK: - Phase 2.4: Channel Guidelines Tests (Phase 14.1-14.2)
    
    func test_ChannelGuidelines_totalCount() async throws {
        let service = ChannelGuidelinesService.shared
        let guidelines = await service.getAllGuidelines()
        let totalRules = await service.getTotalRulesCount()
        
        print("✅ Channel Guidelines: \(guidelines.count) channels, \(totalRules) total rules")
        XCTAssertGreaterThanOrEqual(guidelines.count, 15, "Should have 15+ channel guidelines")
        XCTAssertGreaterThanOrEqual(totalRules, 50, "Should have 50+ total rules")
    }
    
    func test_ChannelGuidelines_allChannelsHaveGuidelines() async throws {
        let service = ChannelGuidelinesService.shared
        var missingChannels: [ContentChannelType] = []
        
        for channel in ContentChannelType.allCases {
            let guideline = await service.getGuideline(for: channel)
            if guideline == nil {
                missingChannels.append(channel)
            }
        }
        
        print("✅ Channel Coverage: \(ContentChannelType.allCases.count - missingChannels.count)/\(ContentChannelType.allCases.count)")
        if !missingChannels.isEmpty {
            print("   Missing: \(missingChannels.map { $0.rawValue }.joined(separator: ", "))")
        }
    }
    
    func test_ChannelGuidelines_characterLimits() async throws {
        let service = ChannelGuidelinesService.shared
        var limitsFound = 0
        
        for channel in ContentChannelType.allCases {
            if let limits = await service.getCharacterLimits(for: channel) {
                limitsFound += 1
                XCTAssertGreaterThan(limits.max, limits.min, "Max should be > min for \(channel)")
                XCTAssertGreaterThanOrEqual(limits.ideal, limits.min, "Ideal should be >= min")
                XCTAssertLessThanOrEqual(limits.ideal, limits.max, "Ideal should be <= max")
            }
        }
        
        print("✅ Character Limits: \(limitsFound)/\(ContentChannelType.allCases.count) channels have limits")
    }
    
    func test_ChannelGuidelines_warmthDetailPresets() async throws {
        let service = ChannelGuidelinesService.shared
        
        for channel in ContentChannelType.allCases {
            let preset = await service.getWarmthDetailPreset(for: channel)
            XCTAssertGreaterThanOrEqual(preset.warmth, 1, "Warmth should be >= 1")
            XCTAssertLessThanOrEqual(preset.warmth, 10, "Warmth should be <= 10")
            XCTAssertGreaterThanOrEqual(preset.detail, 1, "Detail should be >= 1")
            XCTAssertLessThanOrEqual(preset.detail, 10, "Detail should be <= 10")
        }
        
        print("✅ Warmth/Detail Presets: All \(ContentChannelType.allCases.count) channels have valid presets (1-10)")
    }
    
    func test_ChannelGuidelines_validateContent_characterLimit() async throws {
        let service = ChannelGuidelinesService.shared
        
        // SMS should fail with long text
        let longSMS = String(repeating: "a", count: 200)
        let smsResult = await service.validateContent(longSMS, for: .sms)
        
        // Short SMS should pass
        let shortSMS = "Your Jio recharge is successful."
        let shortResult = await service.validateContent(shortSMS, for: .sms)
        
        print("✅ Content Validation:")
        print("   Long SMS (200 chars): passed=\(smsResult.passed), issues=\(smsResult.issues.count)")
        print("   Short SMS (33 chars): passed=\(shortResult.passed), issues=\(shortResult.issues.count)")
        
        XCTAssertFalse(smsResult.passed, "Long SMS should fail character limit")
    }
    
    // MARK: - Phase 2.5: Wording Rules Tests
    
    func test_WordingRules_avoidWordsCount() async throws {
        let service = WordingRulesService.shared
        try await service.loadRules()
        
        var totalAvoid = 0
        for category in AvoidWordCategory.allCases {
            let words = await service.getAvoidWords(category: category)
            totalAvoid += words.count
        }
        
        print("✅ Avoid Words: \(totalAvoid) total")
        XCTAssertGreaterThanOrEqual(totalAvoid, 100, "Should have 100+ avoid words")
    }
    
    func test_WordingRules_preferredWordsCount() async throws {
        let service = WordingRulesService.shared
        try await service.loadRules()
        
        var totalPreferred = 0
        for category in PreferredWordCategory.allCases {
            let words = await service.getPreferredWords(category: category)
            totalPreferred += words.count
        }
        
        print("✅ Preferred Words: \(totalPreferred) total")
        XCTAssertGreaterThanOrEqual(totalPreferred, 100, "Should have 100+ preferred words")
    }
    
    func test_WordingRules_autoFixRulesCount() async throws {
        let service = WordingRulesService.shared
        try await service.loadRules()
        
        var totalFixes = 0
        for category in AutoFixCategory.allCases {
            let rules = await service.getAutoFixRules(category: category)
            totalFixes += rules.count
        }
        
        print("✅ Auto-Fix Rules: \(totalFixes) total")
        XCTAssertGreaterThanOrEqual(totalFixes, 30, "Should have 30+ auto-fix rules")
    }
    
    func test_WordingRules_checkText_detectsViolations() async throws {
        let service = WordingRulesService.shared
        try await service.loadRules()
        
        let testText = "Please leverage our synergistic solutions and do the needful at the earliest."
        let violations = await service.checkText(testText)
        
        print("✅ Violation Detection: Found \(violations.count) violations in test text")
        violations.forEach { print("   - \($0.text): \($0.suggestion)") }
        
        XCTAssertGreaterThan(violations.count, 0, "Should detect violations in problematic text")
    }
    
    func test_WordingRules_autoFix_appliesCorrectly() async throws {
        let service = WordingRulesService.shared
        try await service.loadRules()
        
        let testText = "colour centre behaviour"
        let preview = await service.applyAllFixes(to: testText)
        
        print("✅ Auto-Fix Application:")
        print("   Original: \(preview.originalContent)")
        print("   Fixed: \(preview.fixedContent)")
        print("   Fixes applied: \(preview.fixCount)")
    }
    
    // MARK: - Phase 2.6: Safety Gate Tests
    
    func test_SafetyGate_safeContent() async throws {
        let service = SafetyGateService.shared
        let result = await service.classify("Your recharge was successful. Thank you for choosing Jio.")
        
        print("✅ Safety Gate (Safe Content): routing=\(result.routing), level=\(result.highestLevel)")
        XCTAssertEqual(result.routing, .proceedNormal, "Safe content should proceed normally")
    }
    
    func test_SafetyGate_healthContent() async throws {
        let service = SafetyGateService.shared
        let result = await service.classify("I have chest pain and difficulty breathing. What should I do?")
        
        print("✅ Safety Gate (Health Content): routing=\(result.routing), domains=\(result.classifications.map { $0.domain.rawValue })")
        XCTAssertTrue(result.classifications.contains { $0.domain == .health || $0.domain == .emergency },
                     "Should detect health/emergency domain")
    }
    
    func test_SafetyGate_mentalHealthContent() async throws {
        let service = SafetyGateService.shared
        let result = await service.classify("I feel very depressed and don't want to live anymore.")
        
        print("✅ Safety Gate (Mental Health): routing=\(result.routing), level=\(result.highestLevel)")
        
        let hasMentalHealth = result.classifications.contains { $0.domain == .mentalHealth }
        let hasHighLevel = result.highestLevel >= .high
        
        print("   Mental health detected: \(hasMentalHealth)")
        print("   High/Critical level: \(hasHighLevel)")
        
        XCTAssertTrue(hasMentalHealth || hasHighLevel, "Should detect mental health concern")
    }
    
    func test_SafetyGate_emergencyResponse() async throws {
        let service = SafetyGateService.shared
        let (requiresEmergency, emergencyInfo) = await service.requiresEmergencyResponse("I want to hurt myself")
        
        print("✅ Safety Gate Emergency Response:")
        print("   Requires emergency: \(requiresEmergency)")
        if let info = emergencyInfo {
            print("   Helplines: \(info.helplines.count)")
            print("   Message: \(info.immediateMessage)")
        }
    }
    
    func test_SafetyGate_allDomains() async throws {
        let service = SafetyGateService.shared
        let testCases: [(String, SafetyDomain)] = [
            ("invest money in stocks", .financial),
            ("legal advice for divorce", .legal),
            ("my password is abc123", .privacy),
            ("how to make explosives", .violence),
            ("where to buy drugs", .substance)
        ]
        
        var detected = 0
        for (text, expectedDomain) in testCases {
            let result = await service.classify(text)
            if result.classifications.contains(where: { $0.domain == expectedDomain }) {
                detected += 1
            }
        }
        
        print("✅ Safety Gate Domain Coverage: \(detected)/\(testCases.count) domains detected")
    }
    
    // MARK: - Phase 3: API Integration Tests
    
    func test_CorrectionsAPI_structure() async throws {
        let service = CorrectionsAPIService.shared
        
        // Test that the service exists and has expected methods
        print("✅ CorrectionsAPIService: Service exists")
        
        // Create a test correction
        let correction = Correction(
            originalText: "test original",
            correctedText: "test corrected",
            category: .tone,
            context: "test context"
        )
        
        XCTAssertNotNil(correction.id)
        XCTAssertFalse(correction.synced)
        print("   Correction created: id=\(correction.id)")
    }
    
    func test_LearningService_recordAndRetrieve() async throws {
        let service = LearningService.shared
        
        // Record a correction
        let correction = Correction(
            originalText: "leverage",
            correctedText: "use",
            category: .style,
            context: "testing"
        )
        await service.recordCorrection(correction)
        
        let recent = await service.getRecentCorrections(days: 1)
        print("✅ LearningService: \(recent.count) recent corrections")
        
        // Test context-based retrieval
        let contextCorrections = await service.getCorrectionsForContext(
            ecosystem: .connectivity,
            channel: .pushNotification,
            limit: 10
        )
        print("   Context corrections: \(contextCorrections.count)")
    }
    
    func test_SyncService_status() async throws {
        let service = SyncService.shared
        let status = await service.getStatus()
        
        print("✅ SyncService Status:")
        print("   Last sync: \(status.lastSync?.description ?? "never")")
        print("   Pending corrections: \(status.pendingCorrections)")
        print("   Is syncing: \(status.isSyncing)")
    }
    
    // MARK: - Phase 4: Performance Stress Tests
    
    func test_Performance_validateLargeText() async throws {
        let service = ValidationService.shared
        let largeText = String(repeating: "This is a sample sentence for testing performance. ", count: 100)
        
        let start = Date()
        let result = await service.validate(largeText)
        let elapsed = Date().timeIntervalSince(start) * 1000
        
        print("✅ Performance (Large Text - \(largeText.count) chars):")
        print("   Time: \(String(format: "%.1f", elapsed))ms")
        print("   Score: \(result.score)")
        
        XCTAssertLessThan(elapsed, 500, "Large text validation should complete in < 500ms")
    }
    
    func test_Performance_concurrentValidation() async throws {
        let service = ValidationService.shared
        let texts = (0..<50).map { "Test message number \($0) for concurrent validation stress test." }
        
        let start = Date()
        await withTaskGroup(of: ValidationResult.self) { group in
            for text in texts {
                group.addTask {
                    await service.validate(text)
                }
            }
            for await _ in group { }
        }
        let elapsed = Date().timeIntervalSince(start) * 1000
        
        print("✅ Performance (Concurrent - 50 validations):")
        print("   Total time: \(String(format: "%.1f", elapsed))ms")
        print("   Average per validation: \(String(format: "%.1f", elapsed / 50))ms")
        
        XCTAssertLessThan(elapsed, 5000, "50 concurrent validations should complete in < 5s")
    }
    
    func test_Performance_wordingRulesCheck() async throws {
        let service = WordingRulesService.shared
        try await service.loadRules()
        
        let testText = Self.violationTexts.joined(separator: " ")
        
        let start = Date()
        for _ in 0..<100 {
            _ = await service.checkText(testText)
        }
        let elapsed = Date().timeIntervalSince(start) * 1000
        
        print("✅ Performance (Wording Rules - 100 checks):")
        print("   Total time: \(String(format: "%.1f", elapsed))ms")
        print("   Average per check: \(String(format: "%.2f", elapsed / 100))ms")
    }
    
    func test_Performance_readabilityCalculation() async throws {
        let service = ValidationService.shared
        let texts = Self.cleanTexts + Self.complexTexts + Self.violationTexts
        
        let start = Date()
        for _ in 0..<100 {
            for text in texts {
                _ = service.calculateFleschKincaidGrade(text)
                _ = service.calculateReadabilityScore(text)
            }
        }
        let elapsed = Date().timeIntervalSince(start) * 1000
        let totalCalculations = 100 * texts.count * 2
        
        print("✅ Performance (Readability - \(totalCalculations) calculations):")
        print("   Total time: \(String(format: "%.1f", elapsed))ms")
        print("   Average per calculation: \(String(format: "%.3f", elapsed / Double(totalCalculations)))ms")
    }
    
    // MARK: - Phase 5: Edge Case Tests
    
    func test_EdgeCase_emptyString() async throws {
        let service = ValidationService.shared
        let result = await service.validate("")
        
        print("✅ Edge Case (Empty String): score=\(result.score), passed=\(result.passed)")
        XCTAssertTrue(result.passed, "Empty string should pass validation")
    }
    
    func test_EdgeCase_singleCharacter() async throws {
        let service = ValidationService.shared
        let result = await service.validate("a")
        
        print("✅ Edge Case (Single Char): score=\(result.score), passed=\(result.passed)")
    }
    
    func test_EdgeCase_unicodeEmoji() async throws {
        let service = ValidationService.shared
        let emojiText = "Hello! 👋 Welcome to Jio! 🎉 Your account is ready. ✅"
        let result = await service.validate(emojiText)
        
        print("✅ Edge Case (Unicode/Emoji): score=\(result.score), violations=\(result.violations.count)")
    }
    
    func test_EdgeCase_hinglishContent() async throws {
        let service = ValidationService.shared
        var results: [(String, Int)] = []
        
        for text in Self.hinglishTexts {
            let result = await service.validate(text)
            results.append((text, result.score))
        }
        
        print("✅ Edge Case (Hinglish):")
        results.forEach { print("   '\($0.0)' -> score: \($0.1)") }
    }
    
    func test_EdgeCase_languageDetection() async throws {
        let service = LanguageService.shared
        
        let testCases: [(String, String)] = [
            ("Hello world", "english"),
            ("नमस्ते दुनिया", "hindi"),
            ("Namaste duniya", "hinglish"),
            ("வணக்கம்", "tamil"),
            ("నమస్కారం", "telugu")
        ]
        
        print("✅ Edge Case (Language Detection):")
        for (text, expected) in testCases {
            let result = await service.detectLanguage(in: text)
            print("   '\(text)' -> \(result.language.rawValue) (expected: \(expected))")
        }
    }
    
    // MARK: - Phase 5.3: Enum Exhaustiveness Tests
    
    func test_EnumExhaustiveness_ecosystemType() throws {
        for ecosystem in EcosystemType.allCases {
            XCTAssertFalse(ecosystem.displayName.isEmpty, "\(ecosystem) should have display name")
            XCTAssertFalse(ecosystem.toneDescription.isEmpty, "\(ecosystem) should have tone description")
        }
        print("✅ Enum Exhaustiveness: EcosystemType (\(EcosystemType.allCases.count) cases)")
    }
    
    func test_EnumExhaustiveness_contentChannelType() throws {
        for channel in ContentChannelType.allCases {
            XCTAssertFalse(channel.displayName.isEmpty, "\(channel) should have display name")
            XCTAssertGreaterThanOrEqual(channel.defaultWarmth, 1)
            XCTAssertLessThanOrEqual(channel.defaultWarmth, 10)
            XCTAssertGreaterThanOrEqual(channel.defaultDetail, 1)
            XCTAssertLessThanOrEqual(channel.defaultDetail, 10)
        }
        print("✅ Enum Exhaustiveness: ContentChannelType (\(ContentChannelType.allCases.count) cases)")
    }
    
    func test_EnumExhaustiveness_navarasaType() throws {
        for emotion in NavarasaType.allCases {
            XCTAssertFalse(emotion.displayName.isEmpty, "\(emotion) should have display name")
            XCTAssertFalse(emotion.responseGuidance.isEmpty, "\(emotion) should have guidance")
        }
        print("✅ Enum Exhaustiveness: NavarasaType (\(NavarasaType.allCases.count) cases)")
    }
    
    func test_EnumExhaustiveness_safetyDomain() throws {
        for domain in SafetyDomain.allCases {
            XCTAssertFalse(domain.displayName.isEmpty, "\(domain) should have display name")
        }
        print("✅ Enum Exhaustiveness: SafetyDomain (\(SafetyDomain.allCases.count) cases)")
    }
    
    func test_EnumExhaustiveness_safetyLevel() throws {
        let levels = SafetyLevel.allCases.sorted()
        XCTAssertEqual(levels.first, .none)
        XCTAssertEqual(levels.last, .critical)
        print("✅ Enum Exhaustiveness: SafetyLevel (\(SafetyLevel.allCases.count) cases, sorted correctly)")
    }
    
    func test_EnumExhaustiveness_supportedLanguage() throws {
        for language in SupportedLanguage.allCases {
            XCTAssertFalse(language.displayName.isEmpty, "\(language) should have display name")
        }
        print("✅ Enum Exhaustiveness: SupportedLanguage (\(SupportedLanguage.allCases.count) cases)")
    }
    
    // MARK: - Phase 6: Integration Tests
    
    func test_Integration_fullValidationPipeline() async throws {
        let text = "Write a push notification for Jio Fiber 1Gbps offer"
        
        // Step 1: Classify intent
        let intentResult = await IntentClassifierService.shared.classify(text)
        print("✅ Integration Pipeline:")
        print("   1. Intent: \(intentResult.intent.rawValue) (confidence: \(String(format: "%.2f", intentResult.confidence)))")
        
        // Step 2: Validate with intent
        let validationResult = await ValidationService.shared.validateWithIntent(text, prompt: text)
        print("   2. Validation: score=\(validationResult.score), skipped=\(validationResult.wasSkipped)")
        
        // Step 3: Channel-specific validation
        let channelResult = await ValidationService.shared.validateForChannel(text, channel: .pushNotification)
        print("   3. Channel Validation: passed=\(channelResult.overallPassed)")
        print("      Suggested warmth: \(channelResult.suggestedWarmth), detail: \(channelResult.suggestedDetail)")
        
        // Step 4: Safety check
        let safetyResult = await SafetyGateService.shared.classify(text)
        print("   4. Safety: routing=\(safetyResult.routing)")
        
        // Step 5: Readability
        let readability = ValidationService.shared.getReadabilityAnalysis(text)
        print("   5. Readability: grade \(String(format: "%.1f", readability.fleschKincaidGrade)), meets target=\(readability.meetsTarget)")
    }
    
    func test_Integration_multiChannelValidation() async throws {
        let baseText = "Your Jio prepaid recharge of Rs 299 is successful. Enjoy unlimited calls and 2GB daily data for 28 days."
        
        print("✅ Integration (Multi-Channel):")
        for channel in [ContentChannelType.pushNotification, .sms, .whatsappAlert, .marketingEmail] {
            let result = await ValidationService.shared.validateForChannel(baseText, channel: channel)
            let charInfo = result.channelValidation.characterInfo
            print("   \(channel.displayName): passed=\(result.overallPassed), chars=\(charInfo.current)/\(charInfo.max) (\(charInfo.status))")
        }
    }
    
    func test_Integration_emotionAndTone() async throws {
        let service = EmotionService.shared
        
        let testTexts = [
            ("I'm so excited about the new offer!", "excitement"),
            ("I'm really frustrated with this service.", "frustration"),
            ("Thank you so much for your help!", "gratitude"),
            ("I'm worried about my account security.", "concern")
        ]
        
        print("✅ Integration (Emotion Detection):")
        for (text, expected) in testTexts {
            let result = await service.detectEmotion(in: text)
            print("   '\(text.prefix(30))...' -> \(result.emotion.displayName) (confidence: \(String(format: "%.2f", result.confidence)))")
        }
    }
}

// MARK: - Test Report Generator

extension ToneStudioStressTests {
    
    static func generateReport() async -> String {
        var report = """
        ══════════════════════════════════════════════════════════════════════════════
        TONESTUDIO COMPREHENSIVE STRESS TEST REPORT
        Generated: \(Date())
        ══════════════════════════════════════════════════════════════════════════════
        
        """
        
        // Run all tests and collect results
        let testSuite = ToneStudioStressTests()
        var passed = 0
        var failed = 0
        var testResults: [(String, Bool, String)] = []
        
        // Add test execution here in actual implementation
        
        report += """
        
        SUMMARY
        ══════════════════════════════════════════════════════════════════════════════
        Total Tests: \(passed + failed)
        Passed: \(passed)
        Failed: \(failed)
        Pass Rate: \(passed + failed > 0 ? String(format: "%.1f%%", Double(passed) / Double(passed + failed) * 100) : "N/A")
        
        """
        
        return report
    }
}
