import AppIntents
import Foundation

/// Shortcuts, Spotlight, and automations. Each intent acts on the running
/// Ember; the system launches Ember first when it is not running.

struct PauseEmberIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Ember"
    static let description = IntentDescription("True color on every screen for a while, then Ember eases back in.")

    @Parameter(title: "Hours", default: 1, inclusiveRange: (0.25, 12))
    var hours: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Pause Ember for \(\.$hours) hours")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try AppModel.running().pause(hours: hours)
        return .result()
    }
}

struct ResumeEmberIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Ember"
    static let description = IntentDescription("End a pause and return to the light for this time of day.")

    @MainActor
    func perform() async throws -> some IntentResult {
        try AppModel.running().resume()
        return .result()
    }
}

struct SetEmberIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Ember On or Off"
    static let description = IntentDescription("Off leaves the screen unmodified until you turn Ember back on.")

    @Parameter(title: "On", default: true)
    var on: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Turn Ember \(\.$on)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try AppModel.running().enabled = on
        return .result()
    }
}

struct SetNightLightIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Ember Night Light"
    static let description = IntentDescription("How warm and dim the screen goes at night.")

    @Parameter(title: "Night light", default: .standard)
    var strength: NightStrength

    static var parameterSummary: some ParameterSummary {
        Summary("Set Ember night light to \(\.$strength)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try AppModel.running().strength = strength
        return .result()
    }
}

extension NightStrength: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Night Light"
    static let caseDisplayRepresentations: [NightStrength: DisplayRepresentation] = [
        .gentle: DisplayRepresentation(title: "Gentle", subtitle: "Warm, still easy to read"),
        .standard: DisplayRepresentation(title: "Standard", subtitle: "Warm and dim"),
        .deep: DisplayRepresentation(title: "Deep", subtitle: "Very warm, very dim"),
    ]
}

struct EmberShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PauseEmberIntent(),
            phrases: ["Pause \(.applicationName)", "True color with \(.applicationName)"],
            shortTitle: "Pause",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: ResumeEmberIntent(),
            phrases: ["Resume \(.applicationName)"],
            shortTitle: "Resume",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: SetNightLightIntent(),
            phrases: ["Set \(.applicationName) night light", "Change \(.applicationName) night light"],
            shortTitle: "Night Light",
            systemImageName: "moon"
        )
    }
}

enum EmberIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notRunning

    var localizedStringResource: LocalizedStringResource {
        "Ember is not running. Open Ember and try again."
    }
}
