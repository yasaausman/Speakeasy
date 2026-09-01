import Foundation
import SwiftUI

/// Local persistence for the saved-details vault and call history (UserDefaults
/// JSON — enough for the demo; a later milestone can move to SQLite/SwiftData).
@MainActor
final class AppStore: ObservableObject {
    @Published var details: SavedDetails { didSet { save(details, key: Keys.details) } }
    @Published var history: [StoredCall] { didSet { save(history, key: Keys.history) } }
    /// Text-forward (Deaf / hard-of-hearing) mode: no spoken audio, text only.
    @Published var textForward: Bool { didSet { UserDefaults.standard.set(textForward, forKey: Keys.textForward) } }

    private enum Keys { static let details = "speakeasy.details", history = "speakeasy.history", textForward = "speakeasy.textForward" }

    init() {
        details = AppStore.load(SavedDetails.self, key: Keys.details) ?? SavedDetails()
        history = AppStore.load([StoredCall].self, key: Keys.history) ?? []
        textForward = UserDefaults.standard.bool(forKey: Keys.textForward)
    }

    func addCall(_ call: StoredCall) {
        history.insert(call, at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
    }

    func clearHistory() { history = [] }

    // MARK: Persistence
    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
