import Foundation

// MARK: - Ecosystem Types (14 total)
enum EcosystemType: String, Codable, CaseIterable {
    case connectivity   // Jio mobile, fiber, network
    case home           // JioFiber, home entertainment
    case entertainment  // JioCinema, JioTV, music
    case shopping       // JioMart, retail
    case finance        // JioPayments, banking
    case health         // JioHealthHub, wellness
    case business       // Enterprise, B2B
    case work           // Employee communications
    case government     // G2C services
    case education      // Learning platforms, courses
    case sports         // Sports content, live streaming
    case agriculture    // Farmer services, rural
    case energy         // Solar, clean energy
    case transport      // Mobility, logistics
    
    var displayName: String {
        switch self {
        case .connectivity: return "connectivity"
        case .home: return "home"
        case .entertainment: return "entertainment"
        case .shopping: return "shopping"
        case .finance: return "finance"
        case .health: return "health"
        case .business: return "business"
        case .work: return "work"
        case .government: return "government"
        case .education: return "education"
        case .sports: return "sports"
        case .agriculture: return "agriculture"
        case .energy: return "energy"
        case .transport: return "transport"
        }
    }
    
    var toneDescription: String {
        switch self {
        case .connectivity: return "fast, confident, always-on"
        case .home: return "warm, relaxed, familiar"
        case .entertainment: return "playful, expressive, energetic"
        case .shopping: return "cheerful, helpful, straight-talking"
        case .finance: return "calm, clear, trustworthy"
        case .health: return "caring, steady, informed"
        case .business: return "sharp, professional, future-focused"
        case .work: return "respectful, encouraging"
        case .government: return "formal, respectful, precise"
        case .education: return "encouraging, inclusive"
        case .sports: return "passionate, bold, energetic"
        case .agriculture: return "grounded, respectful, simple"
        case .energy: return "purposeful, forward-looking"
        case .transport: return "calm, clear, practical"
        }
    }
}

// MARK: - Channel Types (18 total)
enum ContentChannelType: String, Codable, CaseIterable {
    // Quick Messages
    case pushNotification = "push_notification"
    case sms
    case whatsappAlert = "whatsapp_alert"
    
    // Support & Chat
    case customerCareChat = "customer_care_chat"
    case whatsappSupport = "whatsapp_support"
    case chatbotFaq = "chatbot_faq"
    
    // Voice
    case ivrVoiceMenu = "ivr_voice_menu"
    case voiceAssistant = "voice_assistant"
    case voicePrompts = "voice_prompts"
    
    // Email
    case marketingEmail = "marketing_email"
    case transactionalEmail = "transactional_email"
    
    // Marketing & Ads
    case socialMediaPost = "social_media_post"
    case digitalAds = "digital_ads"
    case tvVideoAd = "tv_video_ad"
    
    // In-App & Web
    case appNotification = "app_notification"
    case onboardingScreen = "onboarding_screen"
    
    // Internal
    case internalAnnouncement = "internal_announcement"
    case trainingModule = "training_module"
    
    // Editor (native app specific)
    case editor
    
    // General chat (no specific content channel)
    case chat
    
    var displayName: String {
        switch self {
        case .pushNotification: return "push notification"
        case .sms: return "sms"
        case .whatsappAlert: return "whatsapp alert"
        case .customerCareChat: return "customer care chat"
        case .whatsappSupport: return "whatsapp support"
        case .chatbotFaq: return "chatbot faq"
        case .ivrVoiceMenu: return "ivr voice menu"
        case .voiceAssistant: return "voice assistant"
        case .voicePrompts: return "voice prompts"
        case .marketingEmail: return "marketing email"
        case .transactionalEmail: return "transactional email"
        case .socialMediaPost: return "social media post"
        case .digitalAds: return "digital ads"
        case .tvVideoAd: return "tv/video ad"
        case .appNotification: return "app notification"
        case .onboardingScreen: return "onboarding screen"
        case .internalAnnouncement: return "internal announcement"
        case .trainingModule: return "training module"
        case .editor: return "editor"
        case .chat: return "chat"
        }
    }
    
    var defaultWarmth: Int {
        switch self {
        case .pushNotification: return 7
        case .sms: return 5
        case .whatsappAlert: return 5
        case .customerCareChat: return 8
        case .whatsappSupport: return 8
        case .chatbotFaq: return 6
        case .ivrVoiceMenu: return 6
        case .voiceAssistant: return 7
        case .voicePrompts: return 6
        case .marketingEmail: return 7
        case .transactionalEmail: return 5
        case .socialMediaPost: return 6
        case .digitalAds: return 5
        case .tvVideoAd: return 8
        case .appNotification: return 6
        case .onboardingScreen: return 7
        case .internalAnnouncement: return 6
        case .trainingModule: return 8
        case .editor: return 7
        case .chat: return 8
        }
    }
    
    var defaultDetail: Int {
        switch self {
        case .pushNotification: return 2
        case .sms: return 2
        case .whatsappAlert: return 2
        case .customerCareChat: return 6
        case .whatsappSupport: return 6
        case .chatbotFaq: return 5
        case .ivrVoiceMenu: return 5
        case .voiceAssistant: return 4
        case .voicePrompts: return 4
        case .marketingEmail: return 5
        case .transactionalEmail: return 6
        case .socialMediaPost: return 4
        case .digitalAds: return 3
        case .tvVideoAd: return 4
        case .appNotification: return 4
        case .onboardingScreen: return 5
        case .internalAnnouncement: return 6
        case .trainingModule: return 7
        case .editor: return 5
        case .chat: return 5
        }
    }
    
    var targetLength: String {
        switch self {
        case .pushNotification: return "title: 5-10 words / body: 8-14 words"
        case .sms: return "12-20 words"
        case .whatsappAlert: return "15-25 words"
        case .customerCareChat: return "20-50 words"
        case .whatsappSupport: return "20-50 words"
        case .chatbotFaq: return "30-60 words"
        case .ivrVoiceMenu: return "20-30 seconds per level"
        case .voiceAssistant: return "15-30 words"
        case .voicePrompts: return "15-25 spoken words"
        case .marketingEmail: return "120-250 words"
        case .transactionalEmail: return "120-220 words"
        case .socialMediaPost: return "20-45 words"
        case .digitalAds: return "5-9 words"
        case .tvVideoAd: return "6-12 words per line"
        case .appNotification: return "title: 2-5 words + body: 10-18 words"
        case .onboardingScreen: return "30-60 words"
        case .internalAnnouncement: return "150-250 words"
        case .trainingModule: return "varies by content"
        case .editor: return "as needed"
        case .chat: return "as needed"
        }
    }
}

// MARK: - Navarasa Emotion Types (9 total)
enum NavarasaType: String, Codable, CaseIterable {
    case shringara  // Joy, Love, Gratitude
    case hasya      // Humor, Playfulness
    case karuna     // Compassion, Empathy
    case raudra     // Frustration, Anger (calm response)
    case vira       // Courage, Pride, Ambition
    case bhayanaka  // Fear, Anxiety (reassuring response)
    case bibhatsa   // Disgust, Want to cancel (respectful)
    case adbhuta    // Wonder, Curiosity
    case shanta     // Peace, Calm, Neutral
    
    var displayName: String {
        switch self {
        case .shringara: return "joy/love"
        case .hasya: return "humor"
        case .karuna: return "compassion"
        case .raudra: return "frustration"
        case .vira: return "courage"
        case .bhayanaka: return "fear/anxiety"
        case .bibhatsa: return "disgust"
        case .adbhuta: return "wonder"
        case .shanta: return "peace/neutral"
        }
    }
    
    var responseGuidance: String {
        switch self {
        case .shringara: return "match the joy, be warm, playful, personal"
        case .hasya: return "lean into it, but don't try too hard, stay human"
        case .karuna: return "be gentle, supportive and sincere, don't overwhelm"
        case .raudra: return "stay calm, acknowledge, be solution-focused, never defensive"
        case .vira: return "be bold, direct and empowering, speak with purpose"
        case .bhayanaka: return "be steady, factual and reassuring, never dramatic"
        case .bibhatsa: return "acknowledge and respect the distance, give users control"
        case .adbhuta: return "spark the imagination, be vivid, uplifting and open-ended"
        case .shanta: return "respect the quiet, be minimal, clear and non-intrusive"
        }
    }
}

// MARK: - Content Goal Types (7 total)
enum ContentGoalType: String, Codable, CaseIterable {
    case action         // Drive immediate action
    case alert          // Urgent notification
    case support        // Help and assistance
    case instructional  // Step-by-step guidance
    case engagement     // Build relationship
    case confirmation   // Acknowledge transaction
    case information    // Share updates
    
    var displayName: String {
        switch self {
        case .action: return "action"
        case .alert: return "alert"
        case .support: return "support"
        case .instructional: return "instructional"
        case .engagement: return "engagement"
        case .confirmation: return "confirmation"
        case .information: return "information"
        }
    }
}

// MARK: - Supported Languages (15 total)
enum SupportedLanguage: String, Codable, CaseIterable {
    case english
    case hindi
    case hinglish   // Hindi-English mix
    case tamil
    case telugu
    case kannada
    case malayalam
    case marathi
    case gujarati
    case bengali
    case punjabi
    case odia
    case assamese
    case urdu
    case konkani
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Indian Regions (12 total)
enum IndianRegion: String, Codable, CaseIterable {
    case panIndia = "pan_india"     // Neutral, all-India
    case north                       // UP, Uttarakhand, HP, J&K
    case south                       // TN, KA, KL, AP, TS
    case east                        // WB, Bihar, Jharkhand, Odisha
    case west                        // MH, Gujarat, Goa, Rajasthan
    case northeast                   // Assam, Meghalaya, etc.
    case delhi                       // Delhi NCR
    case mumbai                      // Mumbai metro
    case bangalore                   // Bangalore metro
    case chennai                     // Chennai metro
    case kolkata                     // Kolkata metro
    case hyderabad                   // Hyderabad metro
    
    var displayName: String {
        switch self {
        case .panIndia: return "pan india"
        default: return rawValue
        }
    }
}

// MARK: - User Age Group
enum AgeGroup: String, Codable {
    case digitalConfident = "digital_confident"
    case digitalCautious = "digital_cautious"
}

// MARK: - Literacy Level
enum LiteracyLevel: String, Codable {
    case low
    case high
}

// MARK: - User Profile
struct UserProfile: Codable {
    var ageGroup: AgeGroup
    var region: IndianRegion
    var language: SupportedLanguage
    var literacyLevel: LiteracyLevel
    
    static let `default` = UserProfile(
        ageGroup: .digitalConfident,
        region: .panIndia,
        language: .english,
        literacyLevel: .high
    )
}

// MARK: - Timing Context
struct TimingContext: Codable {
    var timeOfDay: TimeOfDay
    var dayOfWeek: DayType
    var festival: String?
    var specialEvent: String?
    
    enum TimeOfDay: String, Codable {
        case morning, afternoon, evening, lateNight = "late_night"
    }
    
    enum DayType: String, Codable {
        case weekday, weekend
    }
    
    static var current: TimingContext {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())
        
        let timeOfDay: TimeOfDay
        switch hour {
        case 5..<12: timeOfDay = .morning
        case 12..<17: timeOfDay = .afternoon
        case 17..<21: timeOfDay = .evening
        default: timeOfDay = .lateNight
        }
        
        let dayType: DayType = (weekday == 1 || weekday == 7) ? .weekend : .weekday
        
        return TimingContext(timeOfDay: timeOfDay, dayOfWeek: dayType)
    }
}

// MARK: - Generation Context
struct GenerationContext: Codable {
    var ecosystem: EcosystemType
    var channel: ContentChannelType
    var warmth: Int             // 1-10
    var detail: Int             // 1-10
    var goal: ContentGoalType
    var emotion: NavarasaType
    var language: SupportedLanguage
    var region: IndianRegion
    var userProfile: UserProfile
    var timing: TimingContext
    var persona: String?
    
    static let `default` = GenerationContext(
        ecosystem: .connectivity,
        channel: .editor,
        warmth: 7,
        detail: 2,
        goal: .action,
        emotion: .shanta,
        language: .english,
        region: .panIndia,
        userProfile: .default,
        timing: .current,
        persona: "professional"
    )
    
    func toDictionary() -> [String: Any] {
        return [
            "ecosystem": ecosystem.rawValue,
            "channel": channel.rawValue,
            "warmth": warmth,
            "detail": detail,
            "goal": goal.rawValue,
            "emotion": emotion.rawValue,
            "language": language.rawValue,
            "region": region.rawValue,
            "persona": persona ?? "professional"
        ]
    }
}
