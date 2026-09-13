import Foundation
import SwiftUI

/// Local persistence for the saved-details vault and call history (UserDefaults
/// JSON — enough for the demo; a later milestone can move to SQLite/SwiftData).
@MainActor
final class AppStore: ObservableObject {
    private let defaults: UserDefaults
    @Published var details: SavedDetails { didSet { save(details, key: Keys.details) } }
    @Published var history: [StoredCall] { didSet { save(history, key: Keys.history) } }
    /// Text-forward (Deaf / hard-of-hearing) mode: no spoken audio, text only.
    @Published var textForward: Bool { didSet { defaults.set(textForward, forKey: Keys.textForward) } }
    /// Automatically add a calendar event when a booking succeeds.
    @Published var autoAddToCalendar: Bool { didSet { defaults.set(autoAddToCalendar, forKey: Keys.autoCal) } }
    /// Let the agent see the user's calendar free/busy to pick open times.
    @Published var useCalendarAvailability: Bool { didSet { defaults.set(useCalendarAvailability, forKey: Keys.useAvail) } }

    private enum Keys {
        static let details = "speakeasy.details", history = "speakeasy.history", textForward = "speakeasy.textForward"
        static let autoCal = "speakeasy.autoCal", useAvail = "speakeasy.useAvail"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        details = AppStore.load(SavedDetails.self, key: Keys.details, defaults: defaults) ?? SavedDetails()
        history = AppStore.load([StoredCall].self, key: Keys.history, defaults: defaults) ?? []
        textForward = defaults.bool(forKey: Keys.textForward)
        autoAddToCalendar = defaults.object(forKey: Keys.autoCal) as? Bool ?? true
        useCalendarAvailability = defaults.bool(forKey: Keys.useAvail)
    }

    func addCall(_ call: StoredCall) {
        history.insert(call, at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
    }

    func hasCalendarEvent(_ id: String) -> Bool {
        (defaults.stringArray(forKey: "speakeasy.calendarEvents") ?? []).contains(id)
    }
    func recordCalendarEvent(_ id: String) {
        var ids = defaults.stringArray(forKey: "speakeasy.calendarEvents") ?? []
        if !ids.contains(id) { ids.append(id) }
        defaults.set(Array(ids.suffix(100)), forKey: "speakeasy.calendarEvents")
    }

    func clearHistory() { history = [] }

    // MARK: Persistence
    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
    private static func load<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
