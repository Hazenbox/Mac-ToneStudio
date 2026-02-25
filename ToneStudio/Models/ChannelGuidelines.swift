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

// MARK: - Channel Guidelines Service

actor ChannelGuidelinesService {
    
    static let shared = ChannelGuidelinesService()
    
    private let guidelines: [ChannelGuideline]
    
    private init() {
        guidelines = ChannelGuidelinesData.guidelines
    }
    
    func getGuideline(for channel: ContentChannelType) -> ChannelGuideline? {
        guidelines.first { $0.channel == channel }
    }
    
    func getAllGuidelines() -> [ChannelGuideline] {
        guidelines
    }
    
    func validateContent(_ content: String, for channel: ContentChannelType) -> ChannelValidationResult {
        guard let guideline = getGuideline(for: channel) else {
            return ChannelValidationResult(passed: true, issues: [])
        }
        
        var issues: [String] = []
        
        if let limit = guideline.characterLimit {
            let length = content.count
            if length > limit.max {
                issues.append("content exceeds \(limit.max) character limit (\(length) characters)")
            }
            if let min = limit.min, length < min {
                issues.append("content is below minimum \(min) characters (\(length) characters)")
            }
        }
        
        return ChannelValidationResult(
            passed: issues.isEmpty,
            issues: issues
        )
    }
    
    func getFormattedRules(for channel: ContentChannelType) -> String {
        guard let guideline = getGuideline(for: channel) else { return "" }
        return guideline.rules.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }
}

struct ChannelValidationResult {
    let passed: Bool
    let issues: [String]
}
