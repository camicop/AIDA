import Foundation

enum Language: String, CaseIterable {
    case italian
    case english

    var bcp47: String {
        switch self {
        case .italian: return "it-IT"
        case .english: return "en-GB"
        }
    }

    var preferredVoiceName: String? {
        switch self {
        case .italian: return nil
        case .english: return "Kate"
        }
    }

    var displayName: String {
        switch self {
        case .italian: return "Italiano"
        case .english: return "English"
        }
    }

    var code: String {
        switch self {
        case .italian: return "IT"
        case .english: return "EN"
        }
    }
}

final class LocalizationManager {
    static let shared = LocalizationManager()

    var currentLanguage: Language = .italian

    private init() {}
}

struct LocalizedString {
    let it: String
    let en: String

    var current: String {
        switch LocalizationManager.shared.currentLanguage {
        case .italian: return it
        case .english: return en
        }
    }
}

enum L10n {
    static let appName = LocalizedString(it: "A.I.D.A.", en: "A.I.D.A.")

    static let homeTitle = LocalizedString(
        it: "Scegli la tua missione",
        en: "Choose your mission")

    static let missionExplorativeTitle = LocalizedString(it: "Esplorativo", en: "Exploration")
    static let missionExplorativeSubtitle = LocalizedString(
        it: "Scopri angoli nascosti della città a passo lento.",
        en: "Discover hidden corners of the city at a slow pace.")
    static let missionExplorativeDuration = LocalizedString(it: "45 min", en: "45 min")

    static let missionRunTitle = LocalizedString(it: "Corsa", en: "Run")
    static let missionRunSubtitle = LocalizedString(
        it: "Una missione dinamica con tappe a ritmo sostenuto.",
        en: "A dynamic mission with fast-paced waypoints.")
    static let missionRunDuration = LocalizedString(it: "30 min", en: "30 min")

    static let onboardingTitle = LocalizedString(
        it: "Configura la tua avventura",
        en: "Set up your adventure")
    static let onboardingStart = LocalizedString(it: "Inizia", en: "Start")
    static let onboardingMandatoryTag = LocalizedString(
        it: "  •  obbligatorio",
        en: "  •  required")

    static let permissionGPSTitle = LocalizedString(it: "Posizione", en: "Location")
    static let permissionGPSDescription = LocalizedString(
        it: "Indispensabile per guidarti tra le tappe della missione.",
        en: "Required to guide you between mission waypoints.")
    static let permissionMicrophoneTitle = LocalizedString(it: "Microfono", en: "Microphone")
    static let permissionMicrophoneDescription = LocalizedString(
        it: "Per parlare con l'agente AI durante l'avventura.",
        en: "To talk with the AI agent during the adventure.")
    static let permissionCameraTitle = LocalizedString(it: "Fotocamera", en: "Camera")
    static let permissionCameraDescription = LocalizedString(
        it: "Per scattare foto agli indizi e ai luoghi visitati.",
        en: "To capture clues and visited locations.")
    static let permissionHealthKitTitle = LocalizedString(it: "HealthKit", en: "HealthKit")
    static let permissionHealthKitDescription = LocalizedString(
        it: "Adatta il ritmo della missione al tuo stato di forma.",
        en: "Adapts the mission pace to your fitness level.")

    static let briefingTitle = LocalizedString(it: "Briefing", en: "Briefing")
    static let briefingText = LocalizedString(
        it: """
        Benvenuto, agente.
        La città cambia volto al tramonto, e oggi avremo bisogno di te per esplorare un quartiere segnato da strane coincidenze. Le tue tappe ti porteranno tra strade poco battute, dove ogni indizio è parte di una storia più grande. Resta in ascolto, segui le indicazioni e prendi nota di tutto ciò che ti sembra fuori posto. L'avventura comincia adesso.
        """,
        en: """
        Welcome, agent.
        The city changes its face at dusk, and today we need you to explore a neighborhood marked by strange coincidences. Your waypoints will lead you through quiet streets, where every clue is part of a bigger story. Stay alert, follow the directions, and take note of anything that feels out of place. The adventure begins now.
        """)
    static let briefingListen = LocalizedString(
        it: "Ascolta il briefing",
        en: "Listen to the briefing")
    static let briefingPause = LocalizedString(it: "Pausa", en: "Pause")
    static let briefingResume = LocalizedString(it: "Riprendi", en: "Resume")
    static let briefingReady = LocalizedString(
        it: "Ho capito, sono pronto",
        en: "Got it, I'm ready")

    static let callIncoming = LocalizedString(
        it: "Chiamata in arrivo…",
        en: "Incoming call…")
    static let callAnswer = LocalizedString(it: "Rispondi", en: "Answer")
    static let callPreferChat = LocalizedString(
        it: "Non posso parlare, preferisco chattare",
        en: "I can't talk, I'd rather chat")
    static let callTestNavigation = LocalizedString(
        it: "Test Navigazione (GPS/Aptica)",
        en: "Test Navigation (GPS/Haptics)")

    static let audioNavigationStatus = LocalizedString(it: "In ascolto…", en: "Listening…")
    static let audioNavigationSampleSpeech = LocalizedString(
        it: "Procedi dritto per cinquanta metri, poi gira a sinistra. Quando senti il segnale, fermati e ascolta.",
        en: "Walk straight for fifty meters, then turn left. When you hear the signal, stop and listen.")
    static let audioNavigationDistancePlaceholder = LocalizedString(
        it: "Distanza: --",
        en: "Distance: --")
    static let audioNavigationDistanceFormat = LocalizedString(
        it: "Distanza: %.1f m",
        en: "Distance: %.1f m")
    static let audioNavigationDebugSimulator = LocalizedString(
        it: "Debug Simulator",
        en: "Debug Simulator")
    static let audioNavigationTargetReached = LocalizedString(
        it: "Obiettivo raggiunto!",
        en: "Target reached!")

    static let chatTitle = LocalizedString(it: "Chat con A.I.D.A.", en: "Chat with A.I.D.A.")
    static let chatPlaceholder = LocalizedString(
        it: "Scrivi ad A.I.D.A.…",
        en: "Write to A.I.D.A.…")
    static let chatAgentGreeting = LocalizedString(
        it: "Ciao, agente. Sono A.I.D.A. Sei pronto a partire?",
        en: "Hello, agent. I'm A.I.D.A. Are you ready to go?")
    static let chatAgentReply = LocalizedString(
        it: "Ricevuto. Resta in attesa di istruzioni…",
        en: "Got it. Stand by for instructions…")
}
