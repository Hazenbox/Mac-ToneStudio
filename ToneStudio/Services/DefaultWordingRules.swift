import Foundation

enum DefaultWordingRules {
    
    // MARK: - Avoid Words (350+)
    
    static let avoidWords: [AvoidWord] = {
        var words: [AvoidWord] = []
        
        // Complex words (40)
        let complexWords = [
            ("utilize", "use"), ("leverage", "use"), ("synergy", "teamwork"),
            ("paradigm", "model"), ("bandwidth", "capacity"), ("optimize", "improve"),
            ("streamline", "simplify"), ("facilitate", "help"), ("implement", "do"),
            ("methodology", "method"), ("proliferate", "spread"), ("ameliorate", "improve"),
            ("disseminate", "share"), ("endeavor", "try"), ("elucidate", "explain"),
            ("expedite", "speed up"), ("heretofore", "until now"), ("henceforth", "from now"),
            ("notwithstanding", "despite"), ("aforementioned", "mentioned"),
            ("hereinafter", "from here"), ("therein", "in that"), ("whereby", "by which"),
            ("cognizant", "aware"), ("commensurate", "equal"), ("concatenate", "join"),
            ("delineate", "describe"), ("efficacious", "effective"), ("engender", "create"),
            ("epitomize", "represent"), ("exacerbate", "worsen"), ("extrapolate", "extend"),
            ("holistic", "complete"), ("incentivize", "encourage"), ("juxtapose", "compare"),
            ("multifaceted", "complex"), ("operationalize", "use"), ("proactive", "active"),
            ("scalable", "flexible"), ("synergize", "combine")
        ]
        words += complexWords.map { AvoidWord(word: $0.0, category: .complex, suggestion: $0.1) }
        
        // Robotic words (30)
        let roboticWords: [(String, String?)] = [
            ("auto-generated", nil), ("system generated", nil), ("do not reply", nil),
            ("noreply", nil), ("automated message", nil), ("this is a system message", nil),
            ("dear customer", "use their name"), ("dear user", "use their name"),
            ("valued customer", nil), ("to whom it may concern", nil),
            ("please be informed", nil), ("kindly note", nil), ("please note that", nil),
            ("this is to inform", nil), ("we regret to inform", nil),
            ("for your information", nil), ("as per our records", nil),
            ("as mentioned above", nil), ("please find attached", nil),
            ("enclosed herewith", nil), ("as discussed", nil), ("further to", nil),
            ("with reference to", nil), ("in this regard", nil), ("in lieu of", nil),
            ("at your earliest convenience", nil), ("do the needful", nil),
            ("revert back", "reply"), ("same", "it"), ("prepone", "reschedule earlier")
        ]
        words += roboticWords.map { AvoidWord(word: $0.0, category: .robotic, suggestion: $0.1) }
        
        // Fear-based words (40)
        let fearBasedWords: [String] = [
            "urgent", "hurry", "last chance", "final warning",
            "act now", "limited time", "expires soon",
            "don't miss", "running out", "only x left",
            "before it's too late", "deadline", "must act",
            "critical", "emergency", "immediate action required",
            "failure to", "will be terminated", "will be suspended",
            "will be blocked", "penalty", "fine",
            "legal action", "consequences", "risk",
            "warning", "alert", "danger", "threat",
            "loss", "lose", "miss out", "regret",
            "fear", "worry", "panic", "stress",
            "anxiety", "scared", "afraid"
        ]
        words += fearBasedWords.map { AvoidWord(word: $0, category: .fearBased) }
        
        // Bureaucratic words (30)
        let bureaucraticWords: [String] = [
            "terms and conditions apply", "pursuant to",
            "in accordance with", "subject to", "notwithstanding",
            "whereas", "hereby", "hereto", "thereof",
            "whereof", "aforesaid", "said", "such",
            "duly", "forthwith", "hereunder", "thereto",
            "viz", "inter alia", "ipso facto",
            "mutatis mutandis", "prima facie", "pro rata",
            "sine qua non", "status quo", "ultra vires",
            "bona fide", "de facto", "ex officio", "modus operandi"
        ]
        words += bureaucraticWords.map { AvoidWord(word: $0, category: .bureaucratic) }
        
        // Technical words (30)
        let technicalWords: [String] = [
            "backend", "api", "cache", "latency",
            "server", "database", "algorithm", "protocol",
            "infrastructure", "deployment", "repository",
            "endpoint", "authentication", "authorization",
            "encryption", "decryption", "middleware",
            "microservice", "container", "kubernetes",
            "docker", "ci/cd", "devops", "agile",
            "sprint", "scrum", "kanban", "jira",
            "confluence", "webhook"
        ]
        words += technicalWords.map { AvoidWord(word: $0, category: .technical) }
        
        // Shame-inducing words (35)
        let shameWords: [String] = [
            "you forgot", "your fault", "your mistake",
            "you failed", "you didn't", "you neglected",
            "you ignored", "you missed", "you should have",
            "why didn't you", "why haven't you", "you need to",
            "you must", "you have to", "it's your responsibility",
            "you're required", "you're obligated", "failure on your part",
            "your negligence", "your oversight", "your error",
            "incorrect", "wrong", "bad", "poor",
            "inadequate", "insufficient", "unacceptable",
            "disappointing", "unfortunate", "regrettable",
            "careless", "irresponsible", "negligent", "sloppy"
        ]
        words += shameWords.map { AvoidWord(word: $0, category: .shameInducing) }
        
        // Elitist words (30)
        let elitistWords: [String] = [
            "premium", "exclusive", "elite", "vip",
            "luxury", "privileged", "select", "chosen",
            "special access", "members only", "invitation only",
            "by invitation", "limited edition", "rare",
            "unique", "one of a kind", "bespoke", "curated",
            "handpicked", "artisanal", "boutique", "niche",
            "sophisticated", "refined", "distinguished",
            "prestigious", "upscale", "high-end",
            "first class", "world class"
        ]
        words += elitistWords.map { AvoidWord(word: $0, category: .elitist) }
        
        // Marketing jargon (30)
        let marketingWords: [String] = [
            "game-changing", "cutting-edge", "best-in-class",
            "world-class", "industry-leading", "revolutionary",
            "disruptive", "innovative", "next-generation",
            "state-of-the-art", "bleeding edge", "groundbreaking",
            "paradigm-shifting", "thought leader", "guru",
            "ninja", "rockstar", "wizard", "evangelist",
            "champion", "hero", "superstar", "ace",
            "maverick", "trailblazer", "pioneer",
            "visionary", "mastermind", "genius", "expert"
        ]
        words += marketingWords.map { AvoidWord(word: $0, category: .marketingJargon) }
        
        // American spelling (40)
        let americanSpellings = [
            ("color", "colour"), ("honor", "honour"), ("favor", "favour"),
            ("center", "centre"), ("theater", "theatre"), ("meter", "metre"),
            ("fiber", "fibre"), ("liter", "litre"), ("caliber", "calibre"),
            ("analyze", "analyse"), ("organize", "organise"), ("recognize", "recognise"),
            ("realize", "realise"), ("customize", "customise"), ("optimize", "optimise"),
            ("authorize", "authorise"), ("criticize", "criticise"), ("apologize", "apologise"),
            ("catalog", "catalogue"), ("dialog", "dialogue"), ("analog", "analogue"),
            ("program", "programme"), ("traveling", "travelling"), ("canceled", "cancelled"),
            ("labeled", "labelled"), ("modeled", "modelled"), ("counselor", "counsellor"),
            ("behavior", "behaviour"), ("neighbor", "neighbour"), ("defense", "defence"),
            ("offense", "offence"), ("license", "licence"), ("practice", "practise"),
            ("aging", "ageing"), ("judgment", "judgement"), ("acknowledgment", "acknowledgement"),
            ("enrollment", "enrolment"), ("fulfillment", "fulfilment"),
            ("installment", "instalment"), ("skillful", "skilful")
        ]
        words += americanSpellings.map { AvoidWord(word: $0.0, category: .americanSpelling, suggestion: $0.1) }
        
        // Incorrect format (25)
        let incorrectFormats = [
            ("pin number", "pin"), ("atm machine", "atm"), ("lcd display", "lcd"),
            ("hiv virus", "hiv"), ("isbn number", "isbn"), ("upi id", "upi"),
            ("pdf format", "pdf"), ("ram memory", "ram"), ("led diode", "led"),
            ("gps system", "gps"), ("sms message", "sms"), ("mms message", "mms"),
            ("emi installment", "emi"), ("ac current", "ac"), ("dc current", "dc"),
            ("vpn network", "vpn"), ("lan network", "lan"), ("wan network", "wan"),
            ("wifi wireless", "wifi"), ("dvd disc", "dvd"), ("cd disc", "cd"),
            ("pc computer", "pc"), ("cpu processor", "cpu"), ("gui interface", "gui"),
            ("rar archive", "rar")
        ]
        words += incorrectFormats.map { AvoidWord(word: $0.0, category: .incorrectFormat, suggestion: $0.1) }
        
        // Additional complex/jargon words to reach 350+ (25)
        let additionalComplexWords = [
            ("actualize", "achieve"), ("circling back", "following up"),
            ("deep dive", "detailed look"), ("drill down", "examine closely"),
            ("ecosystem", "environment"), ("evangelize", "promote"),
            ("granular", "detailed"), ("ideate", "brainstorm"),
            ("impactful", "effective"), ("iterate", "repeat"),
            ("learnings", "lessons"), ("leverage", "use"),
            ("mindshare", "attention"), ("move the needle", "make progress"),
            ("net-net", "bottom line"), ("on my radar", "aware of"),
            ("pain point", "problem"), ("pivot", "change direction"),
            ("reach out", "contact"), ("robust", "strong"),
            ("run it up the flagpole", "propose"), ("take offline", "discuss privately"),
            ("touch base", "check in"), ("value-add", "benefit"),
            ("vertical", "industry")
        ]
        words += additionalComplexWords.map { AvoidWord(word: $0.0, category: .complex, suggestion: $0.1) }
        
        return words
    }()
    
    // MARK: - Preferred Words (350+)
    
    static let preferredWords: [PreferredWord] = {
        var words: [PreferredWord] = []
        
        // Care & Connection (60)
        let careWords = [
            "thank you", "thanks", "appreciate", "grateful", "always with you",
            "we're here", "here for you", "by your side", "together", "with you",
            "support", "help", "assist", "care", "value", "respect", "understand",
            "listen", "hear", "feel", "empathize", "connect", "belong", "welcome",
            "warm", "friendly", "kind", "gentle", "patient", "thoughtful",
            "considerate", "attentive", "responsive", "available", "accessible",
            "reliable", "trustworthy", "dependable", "consistent", "committed",
            "dedicated", "devoted", "loyal", "faithful", "genuine", "authentic",
            "sincere", "honest", "transparent", "open", "clear", "straightforward",
            "simple", "easy", "effortless", "seamless", "smooth", "comfortable",
            "convenient", "hassle-free"
        ]
        words += careWords.map { PreferredWord(word: $0, category: .careConnection) }
        
        // Action & Progress (50)
        let actionWords = [
            "start", "begin", "launch", "go", "ready", "set", "let's",
            "keep going", "continue", "move forward", "progress", "advance",
            "grow", "improve", "enhance", "upgrade", "update", "refresh",
            "almost done", "nearly there", "getting close", "making progress",
            "on track", "moving ahead", "step by step", "one step closer",
            "next step", "next level", "achievement", "milestone", "success",
            "accomplish", "complete", "finish", "done", "achieved", "reached",
            "unlocked", "earned", "gained", "won", "celebrated", "rewarded",
            "quick", "fast", "instant", "immediate", "now", "today", "soon",
            "easy", "simple"
        ]
        words += actionWords.map { PreferredWord(word: $0, category: .actionProgress) }
        
        // Clarity & Safety (50)
        let clarityWords = [
            "you're safe", "all okay", "everything's fine", "no worries",
            "safe to continue", "secure", "protected", "verified", "confirmed",
            "checked", "validated", "approved", "authorized", "allowed",
            "permitted", "enabled", "active", "working", "functioning",
            "operational", "running", "connected", "online", "available",
            "ready", "set up", "configured", "complete", "successful",
            "clear", "understood", "got it", "noted", "recorded", "saved",
            "stored", "backed up", "restored", "recovered", "resolved",
            "fixed", "corrected", "updated", "improved", "enhanced",
            "optimized", "streamlined", "simplified", "organized"
        ]
        words += clarityWords.map { PreferredWord(word: $0, category: .claritySafety) }
        
        // Fixing & Resolution (50)
        let fixingWords = [
            "checking this", "looking into it", "investigating", "reviewing",
            "analyzing", "examining", "assessing", "evaluating", "testing",
            "verifying", "confirming", "validating", "troubleshooting",
            "diagnosing", "identifying", "finding", "locating", "discovering",
            "all fixed", "resolved", "sorted", "handled", "addressed",
            "taken care of", "dealt with", "managed", "completed", "done",
            "finished", "concluded", "wrapped up", "closed", "settled",
            "working on it", "in progress", "being processed", "under review",
            "being handled", "being addressed", "being resolved", "being fixed",
            "solution found", "issue resolved", "problem solved", "error corrected",
            "bug fixed", "glitch removed", "restored", "recovered", "back to normal"
        ]
        words += fixingWords.map { PreferredWord(word: $0, category: .fixingResolution) }
        
        // Community First (50)
        let communityWords = [
            "growth with purpose", "made in india", "for india", "by indians",
            "indian", "desi", "swadeshi", "local", "homegrown", "indigenous",
            "bharatiya", "community", "together", "united", "collective",
            "shared", "common", "public", "social", "cultural", "traditional",
            "heritage", "values", "family", "friends", "neighbors", "society",
            "nation", "country", "pride", "celebration", "festival", "occasion",
            "namaste", "dhanyavaad", "shukriya", "welcome", "jai hind",
            "vande mataram", "incredible india", "digital india", "make in india",
            "startup india", "skill india", "clean india", "fit india",
            "ayushman bharat", "jan dhan", "aadhaar", "upi", "bhim"
        ]
        words += communityWords.map { PreferredWord(word: $0, category: .communityFirst) }
        
        // Learning & Discovery (50)
        let learningWords = [
            "see what's new", "discover", "explore", "find", "learn",
            "trending now", "popular", "featured", "recommended", "suggested",
            "for you", "personalized", "customized", "tailored", "curated",
            "handpicked", "selected", "chosen", "best", "top",
            "new", "latest", "fresh", "updated", "improved", "enhanced",
            "upgraded", "premium", "exclusive", "special", "limited",
            "try", "experience", "enjoy", "benefit", "gain", "get",
            "receive", "access", "unlock", "earn", "win", "save",
            "free", "bonus", "extra", "more", "additional", "plus",
            "tip", "trick"
        ]
        words += learningWords.map { PreferredWord(word: $0, category: .learningDiscovery) }
        
        // Additional Care & Connection words (20)
        let additionalCareWords = [
            "appreciate your patience", "happy to help", "glad to assist",
            "looking forward", "pleasure to serve", "delighted", "honored",
            "privilege", "cherish", "treasure", "celebrate", "embrace",
            "nurture", "foster", "encourage", "inspire", "motivate",
            "empower", "strengthen", "uplift"
        ]
        words += additionalCareWords.map { PreferredWord(word: $0, category: .careConnection) }
        
        // Additional Action & Progress words (20)
        let additionalActionWords = [
            "momentum", "breakthrough", "victory", "triumph", "conquer",
            "master", "excel", "thrive", "flourish", "prosper",
            "advance", "accelerate", "boost", "elevate", "rise",
            "soar", "climb", "ascend", "transform", "evolve"
        ]
        words += additionalActionWords.map { PreferredWord(word: $0, category: .actionProgress) }
        
        // Additional Clarity & Safety words (20)
        let additionalClarityWords = [
            "assured", "guaranteed", "certified", "authentic", "genuine",
            "legitimate", "official", "trusted", "credible", "accurate",
            "precise", "exact", "correct", "right", "proper",
            "appropriate", "suitable", "fitting", "aligned", "consistent"
        ]
        words += additionalClarityWords.map { PreferredWord(word: $0, category: .claritySafety) }
        
        return words
    }()
    
    // MARK: - Auto-Fix Rules (80+)
    
    static let autoFixRules: [AutoFixRule] = {
        var rules: [AutoFixRule] = []
        
        // Gender-neutral (20)
        let genderNeutral = [
            ("chairman", "chairperson"), ("chairwoman", "chairperson"),
            ("mankind", "humanity"), ("manpower", "workforce"),
            ("man-made", "artificial"), ("manmade", "artificial"),
            ("businessman", "businessperson"), ("businesswoman", "businessperson"),
            ("policeman", "police officer"), ("policewoman", "police officer"),
            ("fireman", "firefighter"), ("firewoman", "firefighter"),
            ("stewardess", "flight attendant"), ("steward", "flight attendant"),
            ("mailman", "mail carrier"), ("postman", "postal worker"),
            ("salesman", "salesperson"), ("saleswoman", "salesperson"),
            ("spokesman", "spokesperson"), ("spokeswoman", "spokesperson")
        ]
        rules += genderNeutral.map { AutoFixRule(original: $0.0, replacement: $0.1, category: .genderNeutral) }
        
        // Simple alternatives (29) - "optimize" removed as it's in britishSpelling
        let simpleAlternatives = [
            ("utilize", "use"), ("leverage", "use"), ("facilitate", "help"),
            ("implement", "do"), ("streamline", "simplify"),
            ("endeavor", "try"), ("elucidate", "explain"), ("expedite", "speed up"),
            ("commence", "start"), ("terminate", "end"), ("ascertain", "find out"),
            ("ameliorate", "improve"), ("cognizant", "aware"), ("disseminate", "share"),
            ("endeavour", "try"), ("envisage", "imagine"), ("epitomize", "represent"),
            ("exacerbate", "worsen"), ("extrapolate", "extend"), ("incentivize", "encourage"),
            ("methodology", "method"), ("multifaceted", "complex"), ("operationalize", "use"),
            ("paradigm", "model"), ("proliferate", "spread"), ("proactive", "active"),
            ("synergy", "teamwork"), ("synergize", "combine"), ("bandwidth", "capacity")
        ]
        rules += simpleAlternatives.map { AutoFixRule(original: $0.0, replacement: $0.1, category: .simpleAlternative) }
        
        // British spelling (20)
        let britishSpelling = [
            ("color", "colour"), ("honor", "honour"), ("favor", "favour"),
            ("center", "centre"), ("theater", "theatre"), ("meter", "metre"),
            ("fiber", "fibre"), ("analyze", "analyse"), ("organize", "organise"),
            ("recognize", "recognise"), ("realize", "realise"), ("customize", "customise"),
            ("optimize", "optimise"), ("authorize", "authorise"), ("criticize", "criticise"),
            ("catalog", "catalogue"), ("dialog", "dialogue"), ("program", "programme"),
            ("behavior", "behaviour"), ("neighbor", "neighbour")
        ]
        rules += britishSpelling.map { AutoFixRule(original: $0.0, replacement: $0.1, category: .britishSpelling, confidence: 0.85) }
        
        // Format corrections (10)
        let formatCorrections = [
            ("pin number", "pin"), ("atm machine", "atm"), ("lcd display", "lcd"),
            ("isbn number", "isbn"), ("pdf format", "pdf"), ("ram memory", "ram"),
            ("led diode", "led"), ("gps system", "gps"), ("sms message", "sms"),
            ("vpn network", "vpn")
        ]
        rules += formatCorrections.map { AutoFixRule(original: $0.0, replacement: $0.1, category: .formatCorrection) }
        
        // Inclusive language (10)
        let inclusiveLanguage = [
            ("disabled person", "person with disability"),
            ("handicapped", "person with disability"),
            ("the blind", "people who are blind"),
            ("the deaf", "people who are deaf"),
            ("mentally ill", "person with mental health condition"),
            ("normal people", "people without disabilities"),
            ("suffers from", "has"), ("afflicted with", "has"),
            ("wheelchair bound", "wheelchair user"),
            ("victim of", "person who experienced")
        ]
        rules += inclusiveLanguage.map { AutoFixRule(original: $0.0, replacement: $0.1, category: .inclusiveLanguage, confidence: 0.8) }
        
        return rules
    }()
}
