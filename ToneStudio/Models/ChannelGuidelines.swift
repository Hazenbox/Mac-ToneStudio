import Foundation

// MARK: - Channel Guideline Model

struct ChannelGuideline: Codable, Identifiable {
    let id: String
    let channel: ContentChannelType
    let name: String
    let characterLimit: CharacterLimit?
    let warmth: Int
    let detail: Int
    let goals: [ContentGoalType]
    let rules: [String]
    let formatTemplate: String?
    let examples: [String]
    
    struct CharacterLimit: Codable {
        let min: Int?
        let max: Int
        let ideal: Int?
    }
}

// MARK: - Default Channel Guidelines (50+)

enum ChannelGuidelinesData {
    
    static let guidelines: [ChannelGuideline] = [
        // Quick Messages
        ChannelGuideline(
            id: "push_notification",
            channel: .pushNotification,
            name: "Push Notification",
            characterLimit: .init(min: 20, max: 100, ideal: 60),
            warmth: 7,
            detail: 2,
            goals: [.action, .alert, .engagement],
            rules: [
                "title: 5-10 words, body: 8-14 words",
                "action-driven language",
                "no fear-based messaging",
                "clear value proposition",
                "personalize when possible"
            ],
            formatTemplate: "title|body",
            examples: [
                "Your recharge is ready! | Complete now to enjoy uninterrupted service",
                "New episode streaming | Watch the latest episode of your favorite show"
            ]
        ),
        
        ChannelGuideline(
            id: "sms",
            channel: .sms,
            name: "SMS",
            characterLimit: .init(min: 30, max: 160, ideal: 120),
            warmth: 5,
            detail: 2,
            goals: [.confirmation, .alert, .information],
            rules: [
                "160 characters max",
                "clear and direct",
                "include necessary details",
                "avoid abbreviations that may confuse",
                "mandatory sender ID"
            ],
            formatTemplate: nil,
            examples: [
                "Your Jio recharge of Rs.299 is successful. Validity: 28 days. Enjoy unlimited calls and data!",
                "OTP for JioMart order: 123456. Valid for 10 mins. Don't share with anyone."
            ]
        ),
        
        ChannelGuideline(
            id: "whatsapp_alert",
            channel: .whatsappAlert,
            name: "WhatsApp Alert",
            characterLimit: .init(min: 50, max: 250, ideal: 150),
            warmth: 7,
            detail: 3,
            goals: [.confirmation, .information, .support],
            rules: [
                "conversational tone",
                "can use emojis sparingly",
                "clear call-to-action",
                "respect user's time",
                "template must be pre-approved"
            ],
            formatTemplate: nil,
            examples: [
                "Hi! Your JioMart order #12345 has been shipped. Track your order here: [link]",
                "Hello! Your JioFiber installation is scheduled for tomorrow between 10 AM - 12 PM."
            ]
        ),
        
        // Support & Chat
        ChannelGuideline(
            id: "customer_care_chat",
            channel: .customerCareChat,
            name: "Customer Care Chat",
            characterLimit: .init(min: 50, max: 500, ideal: 200),
            warmth: 8,
            detail: 6,
            goals: [.support, .information, .action],
            rules: [
                "empathetic and patient",
                "acknowledge the concern first",
                "provide clear solutions",
                "use customer's name when available",
                "end with confirmation and next steps"
            ],
            formatTemplate: nil,
            examples: [
                "Hi Rahul, I understand how frustrating slow speeds can be. Let me check your connection right away. Can you confirm your mobile number?",
                "I've resolved the billing issue. You'll receive a refund of Rs.199 within 3-5 working days. Anything else I can help with?"
            ]
        ),
        
        ChannelGuideline(
            id: "chatbot_faq",
            channel: .chatbotFaq,
            name: "Chatbot FAQ",
            characterLimit: .init(min: 30, max: 300, ideal: 150),
            warmth: 6,
            detail: 5,
            goals: [.information, .support],
            rules: [
                "concise and accurate",
                "offer follow-up options",
                "provide links when helpful",
                "graceful handoff to human when needed",
                "structured format for readability"
            ],
            formatTemplate: nil,
            examples: [
                "To activate international roaming:\n1. Open MyJio app\n2. Go to Add-ons\n3. Select International Roaming\n\nNeed more help? [Talk to an agent]"
            ]
        ),
        
        // Voice
        ChannelGuideline(
            id: "ivr_voice_menu",
            channel: .ivrVoiceMenu,
            name: "IVR Voice Menu",
            characterLimit: .init(min: 50, max: 300, ideal: 150),
            warmth: 6,
            detail: 5,
            goals: [.instructional, .information],
            rules: [
                "20-30 seconds per level max",
                "most common options first",
                "clear pronunciation",
                "repeat key information",
                "always offer agent option"
            ],
            formatTemplate: nil,
            examples: [
                "Welcome to Jio customer care. For recharge, press 1. For account balance, press 2. For internet issues, press 3. To speak to an agent, press 0."
            ]
        ),
        
        // Email
        ChannelGuideline(
            id: "marketing_email",
            channel: .marketingEmail,
            name: "Marketing Email",
            characterLimit: .init(min: 200, max: 1000, ideal: 400),
            warmth: 7,
            detail: 5,
            goals: [.engagement, .action, .information],
            rules: [
                "compelling subject line (5-7 words)",
                "clear hierarchy with headers",
                "single primary CTA",
                "mobile-responsive design",
                "unsubscribe option mandatory"
            ],
            formatTemplate: "subject|preheader|hero|body|cta|footer",
            examples: []
        ),
        
        ChannelGuideline(
            id: "transactional_email",
            channel: .transactionalEmail,
            name: "Transactional Email",
            characterLimit: .init(min: 150, max: 800, ideal: 350),
            warmth: 5,
            detail: 6,
            goals: [.confirmation, .information],
            rules: [
                "clear subject indicating transaction",
                "all relevant details upfront",
                "confirmation number prominent",
                "next steps if applicable",
                "support contact visible"
            ],
            formatTemplate: "subject|header|details|summary|support",
            examples: []
        ),
        
        // Marketing & Ads
        ChannelGuideline(
            id: "social_media_post",
            channel: .socialMediaPost,
            name: "Social Media Post",
            characterLimit: .init(min: 50, max: 280, ideal: 150),
            warmth: 6,
            detail: 4,
            goals: [.engagement, .information, .action],
            rules: [
                "platform-specific length",
                "hashtags where relevant",
                "visual-first thinking",
                "conversational and relatable",
                "engage with comments"
            ],
            formatTemplate: nil,
            examples: [
                "Streaming cricket? Make sure your Jio is ready for the match! Check your data balance in MyJio app #JioTrue5G #Cricket"
            ]
        ),
        
        ChannelGuideline(
            id: "digital_ads",
            channel: .digitalAds,
            name: "Digital Ads",
            characterLimit: .init(min: 15, max: 90, ideal: 50),
            warmth: 5,
            detail: 3,
            goals: [.action],
            rules: [
                "headline: 5-9 words",
                "strong value proposition",
                "clear CTA button text",
                "avoid superlatives",
                "A/B test variations"
            ],
            formatTemplate: "headline|description|cta",
            examples: [
                "Headline: Unlimited 5G Data. For Everyone.\nCTA: Get Started"
            ]
        ),
        
        // In-App
        ChannelGuideline(
            id: "app_notification",
            channel: .appNotification,
            name: "App Notification",
            characterLimit: .init(min: 30, max: 150, ideal: 80),
            warmth: 6,
            detail: 4,
            goals: [.information, .action, .engagement],
            rules: [
                "title: 2-5 words",
                "body: 10-18 words",
                "contextual and timely",
                "deep link to relevant screen",
                "respect notification preferences"
            ],
            formatTemplate: "title|body",
            examples: [
                "Data running low | You have 500MB left. Recharge now?"
            ]
        ),
        
        ChannelGuideline(
            id: "onboarding_screen",
            channel: .onboardingScreen,
            name: "Onboarding Screen",
            characterLimit: .init(min: 50, max: 150, ideal: 80),
            warmth: 7,
            detail: 5,
            goals: [.instructional, .engagement],
            rules: [
                "one concept per screen",
                "visual-first design",
                "progress indicator",
                "skip option available",
                "benefit-focused copy"
            ],
            formatTemplate: "headline|subhead|cta",
            examples: [
                "Welcome to JioTV | Watch 600+ live channels, anytime, anywhere. | Get Started"
            ]
        ),
        
        // Internal
        ChannelGuideline(
            id: "internal_announcement",
            channel: .internalAnnouncement,
            name: "Internal Announcement",
            characterLimit: .init(min: 200, max: 800, ideal: 400),
            warmth: 6,
            detail: 6,
            goals: [.information, .instructional],
            rules: [
                "clear subject line",
                "context before details",
                "action items highlighted",
                "relevant stakeholders tagged",
                "deadline if applicable"
            ],
            formatTemplate: nil,
            examples: []
        ),
        
        ChannelGuideline(
            id: "training_module",
            channel: .trainingModule,
            name: "Training Module",
            characterLimit: .init(min: 300, max: 2000, ideal: 800),
            warmth: 8,
            detail: 7,
            goals: [.instructional, .engagement],
            rules: [
                "clear learning objectives",
                "chunked content (5-7 min modules)",
                "interactive elements",
                "knowledge checks",
                "practical examples"
            ],
            formatTemplate: "objective|content|summary|quiz",
            examples: []
        ),
        
        // Editor (default for native app)
        ChannelGuideline(
            id: "editor",
            channel: .editor,
            name: "Editor",
            characterLimit: nil,
            warmth: 7,
            detail: 5,
            goals: [.action, .information],
            rules: [
                "adapt to user's selected text",
                "maintain original intent",
                "improve clarity and tone",
                "follow Jio voice guidelines",
                "suggest but don't override"
            ],
            formatTemplate: nil,
            examples: []
        )
    ]
    
    static func getGuideline(for channel: ContentChannelType) -> ChannelGuideline? {
        guidelines.first { $0.channel == channel }
    }
    
    static func getGuidelines(for goals: [ContentGoalType]) -> [ChannelGuideline] {
        guidelines.filter { guideline in
            goals.contains { guideline.goals.contains($0) }
        }
    }
}

// MARK: - Extended Channel Rules (50+ rules total across all channels)

enum ExtendedChannelRules {
    
    // Push Notification Rules (5 rules)
    static let pushNotificationRules = [
        "title: 5-10 words, body: 8-14 words",
        "action-driven language with clear benefit",
        "no fear-based or urgency manipulation",
        "personalize with user's name when available",
        "deep link to relevant app section"
    ]
    
    // SMS Rules (6 rules)
    static let smsRules = [
        "strict 160 character limit (or 320 for UCS-2)",
        "clear, direct message - no fluff",
        "include all necessary transaction details",
        "avoid abbreviations that confuse rural users",
        "mandatory sender ID (JIO/JIOMRT/etc)",
        "comply with TRAI DND regulations"
    ]
    
    // WhatsApp Rules (6 rules)
    static let whatsappRules = [
        "conversational, friendly tone",
        "use emojis sparingly and appropriately",
        "clear call-to-action with button or link",
        "template must be pre-approved by WhatsApp",
        "respond within 24-hour session window",
        "offer opt-out option for promotional messages"
    ]
    
    // Customer Care Chat Rules (7 rules)
    static let customerCareRules = [
        "acknowledge concern before providing solution",
        "use customer's name throughout conversation",
        "empathetic language without over-apologizing",
        "provide clear, step-by-step solutions",
        "confirm resolution before closing",
        "offer additional help proactively",
        "escalate complex issues to specialist"
    ]
    
    // Chatbot FAQ Rules (6 rules)
    static let chatbotRules = [
        "structured responses with clear formatting",
        "offer 2-3 follow-up options",
        "graceful handoff to human when confused",
        "never promise what system can't deliver",
        "maintain context across conversation",
        "admit limitations honestly"
    ]
    
    // IVR Voice Rules (7 rules)
    static let ivrRules = [
        "20-30 seconds maximum per menu level",
        "most common options listed first (1, 2)",
        "clear pronunciation for all demographics",
        "repeat key numbers and selections",
        "always offer 'speak to agent' (usually 0)",
        "avoid technical jargon in voice prompts",
        "support multiple languages based on user preference"
    ]
    
    // Voice Assistant Rules (5 rules)
    static let voiceAssistantRules = [
        "natural conversational flow",
        "confirm understanding before action",
        "brief responses (15-30 words)",
        "ask clarifying questions when ambiguous",
        "support interruptions gracefully"
    ]
    
    // Marketing Email Rules (8 rules)
    static let marketingEmailRules = [
        "subject line: 5-7 words, avoid spam triggers",
        "preheader text complements subject",
        "single primary CTA, secondary optional",
        "mobile-responsive design mandatory",
        "clear unsubscribe link in footer",
        "personalization beyond just name",
        "A/B test subject lines for optimization",
        "send time optimization based on user behavior"
    ]
    
    // Transactional Email Rules (6 rules)
    static let transactionalEmailRules = [
        "clear subject indicating transaction type",
        "confirmation/reference number prominent",
        "all relevant details in structured format",
        "next steps clearly outlined",
        "support contact visible and accessible",
        "no promotional content in critical alerts"
    ]
    
    // Social Media Rules (7 rules)
    static let socialMediaRules = [
        "platform-specific character limits",
        "2-3 relevant hashtags maximum",
        "visual content takes priority",
        "conversational and relatable tone",
        "respond to comments within 2 hours",
        "avoid controversial topics and politics",
        "credit user-generated content"
    ]
    
    // Digital Ads Rules (6 rules)
    static let digitalAdsRules = [
        "headline: 5-9 impactful words",
        "clear and honest value proposition",
        "CTA button text: 2-4 action words",
        "no superlatives without proof",
        "comply with platform ad policies",
        "A/B test creative variations"
    ]
    
    // TV/Video Ad Rules (5 rules)
    static let tvAdRules = [
        "6-12 words per subtitle/text line",
        "visual storytelling over heavy text",
        "brand mention in first 3 seconds",
        "clear CTA in final frame",
        "audio and text must align"
    ]
    
    // App Notification Rules (6 rules)
    static let appNotificationRules = [
        "title: 2-5 words, body: 10-18 words",
        "contextual and timely delivery",
        "deep link to relevant app screen",
        "respect user notification preferences",
        "no duplicate or spam notifications",
        "action buttons for quick response"
    ]
    
    // Onboarding Rules (6 rules)
    static let onboardingRules = [
        "one concept per screen only",
        "visual illustration takes 60% of space",
        "progress indicator always visible",
        "skip option available from screen 1",
        "benefit-focused, not feature-focused",
        "maximum 5 screens total"
    ]
    
    // Internal Announcement Rules (5 rules)
    static let internalAnnouncementRules = [
        "clear subject with [ACTION REQUIRED] if needed",
        "context before detailed information",
        "action items highlighted/bulleted",
        "relevant stakeholders @mentioned",
        "deadline in bold if time-sensitive"
    ]
    
    // Training Module Rules (6 rules)
    static let trainingModuleRules = [
        "clear learning objectives upfront",
        "5-7 minute modules maximum",
        "interactive elements every 2 minutes",
        "knowledge check at module end",
        "practical, relatable examples",
        "summary of key takeaways"
    ]
    
    // Editor Rules (5 rules)
    static let editorRules = [
        "maintain original message intent",
        "improve clarity without changing meaning",
        "follow Jio Voice and Tone guidelines",
        "suggest alternatives, don't override",
        "preserve technical accuracy"
    ]
    
    // Universal Rules (applied to all channels)
    static let universalRules = [
        "use gender-neutral language",
        "avoid jargon unless audience-appropriate",
        "write at Grade 8 reading level",
        "be culturally sensitive to Indian diversity",
        "proofread for spelling and grammar",
        "never use fear or shame tactics",
        "respect user's time and attention",
        "be honest and transparent always"
    ]
}

// MARK: - Channel Guidelines Service (Enhanced)

actor ChannelGuidelinesService {
    
    static let shared = ChannelGuidelinesService()
    
    private let guidelines: [ChannelGuideline]
    private let channelRulesMap: [ContentChannelType: [String]]
    
    private init() {
        guidelines = ChannelGuidelinesData.guidelines
        
        // Map channels to their extended rules
        channelRulesMap = [
            .pushNotification: ExtendedChannelRules.pushNotificationRules,
            .sms: ExtendedChannelRules.smsRules,
            .whatsappAlert: ExtendedChannelRules.whatsappRules,
            .whatsappSupport: ExtendedChannelRules.whatsappRules,
            .customerCareChat: ExtendedChannelRules.customerCareRules,
            .chatbotFaq: ExtendedChannelRules.chatbotRules,
            .ivrVoiceMenu: ExtendedChannelRules.ivrRules,
            .voiceAssistant: ExtendedChannelRules.voiceAssistantRules,
            .voicePrompts: ExtendedChannelRules.voiceAssistantRules,
            .marketingEmail: ExtendedChannelRules.marketingEmailRules,
            .transactionalEmail: ExtendedChannelRules.transactionalEmailRules,
            .socialMediaPost: ExtendedChannelRules.socialMediaRules,
            .digitalAds: ExtendedChannelRules.digitalAdsRules,
            .tvVideoAd: ExtendedChannelRules.tvAdRules,
            .appNotification: ExtendedChannelRules.appNotificationRules,
            .onboardingScreen: ExtendedChannelRules.onboardingRules,
            .internalAnnouncement: ExtendedChannelRules.internalAnnouncementRules,
            .trainingModule: ExtendedChannelRules.trainingModuleRules,
            .editor: ExtendedChannelRules.editorRules
        ]
    }
    
    func getGuideline(for channel: ContentChannelType) -> ChannelGuideline? {
        guidelines.first { $0.channel == channel }
    }
    
    func getAllGuidelines() -> [ChannelGuideline] {
        guidelines
    }
    
    func getExtendedRules(for channel: ContentChannelType) -> [String] {
        var rules = channelRulesMap[channel] ?? []
        rules.append(contentsOf: ExtendedChannelRules.universalRules)
        return rules
    }
    
    func getTotalRulesCount() -> Int {
        var total = ExtendedChannelRules.universalRules.count
        for rules in channelRulesMap.values {
            total += rules.count
        }
        return total
    }
    
    func validateContent(_ content: String, for channel: ContentChannelType) -> ChannelValidationResult {
        guard let guideline = getGuideline(for: channel) else {
            return ChannelValidationResult(passed: true, issues: [], warnings: [], characterInfo: nil)
        }
        
        var issues: [String] = []
        var warnings: [String] = []
        var characterInfo: CharacterInfo? = nil
        
        let length = content.count
        
        // Character limit validation
        if let limit = guideline.characterLimit {
            characterInfo = CharacterInfo(
                current: length,
                min: limit.min,
                max: limit.max,
                ideal: limit.ideal
            )
            
            if length > limit.max {
                issues.append("content exceeds \(limit.max) character limit (\(length) characters)")
            }
            if let min = limit.min, length < min {
                warnings.append("content is below recommended minimum \(min) characters (\(length) characters)")
            }
            if let ideal = limit.ideal, length > ideal * 120 / 100 {
                warnings.append("content exceeds ideal length of \(ideal) characters")
            }
        }
        
        // Word count check for voice channels
        if channel == .ivrVoiceMenu || channel == .voiceAssistant || channel == .voicePrompts {
            let wordCount = content.split(separator: " ").count
            if wordCount > 50 {
                warnings.append("voice content may be too long (\(wordCount) words)")
            }
        }
        
        // Sentence check for notifications
        if channel == .pushNotification || channel == .appNotification {
            let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.isEmpty }
            if sentences.count > 2 {
                warnings.append("notifications should be 1-2 sentences max")
            }
        }
        
        return ChannelValidationResult(
            passed: issues.isEmpty,
            issues: issues,
            warnings: warnings,
            characterInfo: characterInfo
        )
    }
    
    func getFormattedRules(for channel: ContentChannelType) -> String {
        let rules = getExtendedRules(for: channel)
        return rules.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }
    
    func getWarmthDetailPreset(for channel: ContentChannelType) -> (warmth: Int, detail: Int) {
        guard let guideline = getGuideline(for: channel) else {
            return (warmth: 7, detail: 5)  // Default
        }
        return (warmth: guideline.warmth, detail: guideline.detail)
    }
    
    func getCharacterLimits(for channel: ContentChannelType) -> ChannelGuideline.CharacterLimit? {
        getGuideline(for: channel)?.characterLimit
    }
    
    func getAvailableGoals(for channel: ContentChannelType) -> [ContentGoalType] {
        getGuideline(for: channel)?.goals ?? [.information]
    }
    
    func getFormatTemplate(for channel: ContentChannelType) -> String? {
        getGuideline(for: channel)?.formatTemplate
    }
    
    func getExamples(for channel: ContentChannelType) -> [String] {
        getGuideline(for: channel)?.examples ?? []
    }
}

// MARK: - Validation Result Models

struct ChannelValidationResult {
    let passed: Bool
    let issues: [String]
    let warnings: [String]
    let characterInfo: CharacterInfo?
    
    init(passed: Bool, issues: [String], warnings: [String] = [], characterInfo: CharacterInfo? = nil) {
        self.passed = passed
        self.issues = issues
        self.warnings = warnings
        self.characterInfo = characterInfo
    }
}

struct CharacterInfo {
    let current: Int
    let min: Int?
    let max: Int
    let ideal: Int?
    
    var percentageUsed: Double {
        return Double(current) / Double(max) * 100
    }
    
    var status: CharacterStatus {
        if current > max { return .exceeded }
        if let ideal = ideal, current > ideal { return .overIdeal }
        if let min = min, current < min { return .belowMin }
        return .good
    }
    
    enum CharacterStatus {
        case belowMin
        case good
        case overIdeal
        case exceeded
    }
}
