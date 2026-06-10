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

    // MARK: - Home / Story selection

    static let homeTitle = LocalizedString(
        it: "Scegli la tua missione",
        en: "Choose your mission")

    static let missionDurationPlaceholder = LocalizedString(it: "~ 45 min", en: "~ 45 min")

    static let storyCouncilSealTitle = LocalizedString(
        it: "Il Sigillo del Concilio",
        en: "The Seal of the Council")
    static let storyCouncilSealSubtitle = LocalizedString(
        it: "Un documento segreto del Concilio di Trento è scomparso. Sei l'unico che può ritrovarlo.",
        en: "A secret document from the Council of Trento has vanished. You are the only one who can find it.")
    static let storyCouncilSealBriefing = LocalizedString(
        it: "Agente, un documento di vitale importanza è scomparso dagli archivi segreti del Concilio di Trento. Le nostre fonti indicano che è ancora nascosto da qualche parte in città. Dovrai muoverti con cautela e risolvere gli indizi che ti condurranno al sigillo. La città è la tua mappa.",
        en: "Agent, a document of vital importance has disappeared from the secret archives of the Council of Trento. Our sources indicate it is still hidden somewhere in the city. You will need to move carefully and solve the clues that lead you to the seal. The city is your map.")

    static let storyOperationAdigeTitle = LocalizedString(
        it: "Operazione Adige",
        en: "Operation Adige")
    static let storyOperationAdigeSubtitle = LocalizedString(
        it: "Sei un agente sotto copertura. Il microchip deve essere recuperato prima dell'alba.",
        en: "You are an undercover agent. The microchip must be recovered before dawn.")
    static let storyOperationAdigeBriefing = LocalizedString(
        it: "Agente, il microchip è stato rubato. Hai poche ore per recuperarlo prima che cada nelle mani sbagliate. I tuoi contatti hanno lasciato indizi nascosti nei luoghi chiave della città. Segui la pista e non farti vedere.",
        en: "Agent, the microchip has been stolen. You have only a few hours to recover it before it falls into the wrong hands. Your contacts have left clues hidden at key locations across the city. Follow the trail and stay out of sight.")

    static let storyBaseOmegaTitle = LocalizedString(
        it: "Base Omega",
        en: "Base Omega")
    static let storyBaseOmegaSubtitle = LocalizedString(
        it: "Una base militare segreta si nasconde sotto Trento. Trova l'accesso prima che sia troppo tardi.",
        en: "A secret military base lies beneath Trento. Find the access point before it's too late.")
    static let storyBaseOmegaBriefing = LocalizedString(
        it: "Agente, le intercettazioni confermano l'esistenza di Base Omega, un'installazione militare segreta nascosta sotto il centro di Trento. L'accesso è protetto da una serie di codici nascosti nei monumenti della città. Trova i codici, trova la base.",
        en: "Agent, intercepted communications confirm the existence of Base Omega, a secret military installation hidden beneath the centre of Trento. Access is protected by a series of codes hidden within the city's landmarks. Find the codes, find the base.")

    // MARK: - Setup screen

    static let setupTitle = LocalizedString(
        it: "Configura la missione",
        en: "Configure mission")

    static let setupSectionAge = LocalizedString(it: "Età", en: "Age")
    static let setupAgePlaceholder = LocalizedString(it: "Età", en: "Age")
    static let setupGroupMode = LocalizedString(it: "Modalità gruppo", en: "Group mode")
    static let setupGroupMinAgePlaceholder = LocalizedString(it: "Età minima", en: "Min age")
    static let setupGroupMaxAgePlaceholder = LocalizedString(it: "Età massima", en: "Max age")
    static let setupAgeFieldHint = LocalizedString(it: "es. 10", en: "e.g. 10")
    static let keyboardDone = LocalizedString(it: "Fatto", en: "Done")

    static let setupSectionDuration = LocalizedString(it: "Durata", en: "Duration")
    static let setupDurationFormat = LocalizedString(it: "~ %d min", en: "~ %d min")

    static let setupSectionEnigmas = LocalizedString(it: "Tipi di enigma", en: "Enigma types")
    static let setupPhotoEnigmas = LocalizedString(
        it: "Abilita enigmi fotografici",
        en: "Enable photo enigmas")
    static let setupPhotoEnigmasFooter = LocalizedString(
        it: "Richiede l'accesso alla fotocamera. Abilita sfide visive con indovinelli.",
        en: "Requires camera access. Enables visual puzzle challenges.")
    static let setupCameraDeniedTitle = LocalizedString(
        it: "Fotocamera non disponibile",
        en: "Camera unavailable")
    static let setupCameraDeniedMessage = LocalizedString(
        it: "Per abilitare gli enigmi fotografici devi concedere l'accesso alla fotocamera dalle Impostazioni.",
        en: "To enable photo enigmas you must grant camera access in Settings.")

    static let setupSectionZone = LocalizedString(it: "Zona", en: "Zone")
    static let setupChooseZone = LocalizedString(
        it: "Scegli zona di partenza",
        en: "Choose starting area")

    static let setupStartMission = LocalizedString(it: "Inizia missione", en: "Start mission")

    // MARK: - Map screen

    static let mapTitle = LocalizedString(it: "Seleziona zona", en: "Select zone")
    static let mapCheckpointsCountFormat = LocalizedString(
        it: "%d checkpoint disponibili",
        en: "%d checkpoints available")
    static let mapDiameterFormat = LocalizedString(
        it: "Diametro: %.1f km",
        en: "Diameter: %.1f km")
    static let mapDiameterDisclaimer = LocalizedString(
        it: "L'area operativa deve restare entro 4 km. Zooma per restringere la tua zona.",
        en: "Mission area must stay within 4 km. Zoom in to narrow your zone.")
    static let mapConfirmArea = LocalizedString(
        it: "Conferma zona",
        en: "Confirm zone")
    static let mapCancel = LocalizedString(it: "Annulla", en: "Cancel")
    static let mapGPSDeniedTitle = LocalizedString(
        it: "GPS richiesto",
        en: "GPS required")
    static let mapGPSDeniedMessage = LocalizedString(
        it: "Il GPS è necessario per giocare ad A.I.D.A. Senza l'accesso alla posizione, la missione non può partire.",
        en: "GPS is required to play A.I.D.A. Without location access, the mission cannot start.")
    static let mapOpenSettings = LocalizedString(it: "Apri Impostazioni", en: "Open Settings")

    static let zoneBuonconsiglio = LocalizedString(
        it: "Castello del Buonconsiglio",
        en: "Buonconsiglio Castle")
    static let zonePiazzaDuomo = LocalizedString(it: "Piazza Duomo", en: "Piazza Duomo")
    static let zonePiazzaFiera = LocalizedString(it: "Piazza Fiera", en: "Piazza Fiera")
    static let zoneSantaMariaMaggiore = LocalizedString(
        it: "Santa Maria Maggiore",
        en: "Santa Maria Maggiore")
    static let zonePiazzaVenezia = LocalizedString(it: "Piazza Venezia", en: "Piazza Venezia")

    // MARK: - Briefing

    static let briefingTitle = LocalizedString(it: "Briefing", en: "Briefing")
    static let briefingListen = LocalizedString(
        it: "Ascolta il briefing",
        en: "Listen to the briefing")
    static let briefingPause = LocalizedString(it: "Pausa", en: "Pause")
    static let briefingResume = LocalizedString(it: "Riprendi", en: "Resume")
    static let briefingReady = LocalizedString(
        it: "Ho capito, sono pronto",
        en: "Got it, I'm ready")

    // MARK: - Call

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

    // MARK: - Audio navigation

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

    // MARK: - Developer mode

    static let developerTitle = LocalizedString(it: "Sviluppatore", en: "Developer")
    static let developerClose = LocalizedString(it: "Chiudi", en: "Close")
    static let developerNoMission = LocalizedString(
        it: "Nessuna missione attiva. Avvia una missione per iniziare il monitoraggio.",
        en: "No active mission. Start a mission to begin monitoring.")
    static let developerExport = LocalizedString(it: "Esporta CSV", en: "Export CSV")
    static let developerStatSpeed = LocalizedString(it: "Velocità (m/s)", en: "Speed (m/s)")
    static let developerStatCadence = LocalizedString(it: "Cadenza (spm)", en: "Cadence (spm)")
    static let developerStatPitch = LocalizedString(it: "Inclinazione (°)", en: "Pitch (°)")
    static let developerStatPlaceholder = LocalizedString(it: "—", en: "—")
    static let developerAcquiringGPS = LocalizedString(
        it: "Acquisizione GPS…",
        en: "Acquiring GPS…")

    // MARK: - Chat

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

    // MARK: - Active call

    static let activeCallStatusConnecting = LocalizedString(it: "Connessione…", en: "Connecting…")
    static let activeCallStatusSpeaking = LocalizedString(it: "Sta parlando…", en: "Speaking…")
    static let activeCallStatusListening = LocalizedString(it: "In linea", en: "On the line")
    static let activeCallSpeaker = LocalizedString(it: "Altoparlante", en: "Speaker")
    static let activeCallMute = LocalizedString(it: "Muto", en: "Mute")
    static let activeCallHangUp = LocalizedString(it: "Riaggancia", en: "Hang up")
    static let activeCallMinimize = LocalizedString(it: "Riduci", en: "Minimize")
    static let activeCallReturnBanner = LocalizedString(
        it: "Tocca per tornare alla chiamata",
        en: "Tap to return to call")
    static let activeCallRecallBanner = LocalizedString(
        it: "Tocca per richiamare A.I.D.A.",
        en: "Tap to call A.I.D.A. again")

    static let abandonMissionTitle = LocalizedString(
        it: "Abbandonare la missione?",
        en: "Abandon the mission?")
    static let abandonMissionMessage = LocalizedString(
        it: "Se esci ora, la chiamata terminerà e la missione verrà interrotta.",
        en: "If you leave now, the call will end and the mission will be interrupted.")
    static let abandonMissionConfirm = LocalizedString(it: "Abbandona", en: "Abandon")
    static let abandonMissionCancel = LocalizedString(it: "Annulla", en: "Cancel")

    /// Scripted agent lines spoken + shown as chat bubbles during the simulated call.
    /// Swappable: replace this source with a live API stream later.
    static let activeCallScript: [LocalizedString] = [
        LocalizedString(
            it: "Agente, mi senti? Bene. Da questo momento sarò la tua guida sul campo.",
            en: "Agent, can you hear me? Good. From now on I'll be your guide in the field."),
        LocalizedString(
            it: "La tua missione è già iniziata. Tieni il telefono con te e segui le mie istruzioni.",
            en: "Your mission has already begun. Keep your phone with you and follow my instructions."),
        LocalizedString(
            it: "Dirigiti verso la zona che hai selezionato. Ti avviserò quando sarai vicino al primo punto.",
            en: "Head toward the area you selected. I'll alert you when you're near the first checkpoint."),
        LocalizedString(
            it: "Resta vigile. Osserva ciò che ti circonda e non dare nulla per scontato.",
            en: "Stay alert. Observe your surroundings and take nothing for granted."),
        LocalizedString(
            it: "Se hai bisogno di me, sono qui. Buona fortuna, agente.",
            en: "If you need me, I'm here. Good luck, agent.")
    ]
}
