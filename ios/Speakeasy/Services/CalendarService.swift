import Foundation
import EventKit

/// Creates a calendar event from a call result. Best-effort date parsing from a
/// free-text appointment string like "Tuesday 9:40am".
enum CalendarService {
    enum Result { case added, denied, failed }

    static func addEvent(title: String, notes: String, appointmentText: String) async -> Result {
        let store = EKEventStore()
        let granted: Bool
        do {
            granted = try await store.requestWriteOnlyAccessToEvents()
        } catch {
            return .failed
        }
        guard granted else { return .denied }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        let start = parseDate(appointmentText) ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        event.startDate = start
        event.endDate = start.addingTimeInterval(3600)
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            return .added
        } catch {
            return .failed
        }
    }

    /// Parse "Tuesday 9:40am" / "next Monday 10:30am" into the next such date.
    static func parseDate(_ text: String) -> Date? {
        let lower = text.lowercased()
        let names = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        var weekday: Int?
        for (name, idx) in names where lower.contains(name) { weekday = idx; break }

        var hour = 9, minute = 0
        if let (h, m) = parseTime(lower) { hour = h; minute = m }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let now = Date()

        guard let weekday else {
            // No weekday — default to tomorrow at the parsed time.
            let base = cal.date(byAdding: .day, value: 1, to: now)!
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base)
        }

        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = hour
        comps.minute = minute
        guard var next = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) else { return nil }
        if lower.contains("next") { next = cal.date(byAdding: .weekOfYear, value: 1, to: next) ?? next }
        return next
    }

    private static func parseTime(_ text: String) -> (Int, Int)? {
        guard let re = try? NSRegularExpression(pattern: #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = re.firstMatch(in: text, range: range) else { return nil }
        func group(_ i: Int) -> String? {
            guard let r = Range(match.range(at: i), in: text) else { return nil }
            return String(text[r])
        }
        var hour = Int(group(1) ?? "9") ?? 9
        let minute = Int(group(2) ?? "0") ?? 0
        let ampm = group(3) ?? "am"
        if ampm == "pm", hour < 12 { hour += 12 }
        if ampm == "am", hour == 12 { hour = 0 }
        return (hour, minute)
    }
}
