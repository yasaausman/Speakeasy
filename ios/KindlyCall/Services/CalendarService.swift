import Foundation
import EventKit

/// Creates a calendar event from a call result. Best-effort date parsing from a
/// free-text appointment string like "Tuesday 9:40am".
enum CalendarService {
    enum Result { case added, denied, failed }

    static func addEvent(
        title: String,
        notes: String,
        appointmentText: String,
        confirmedDate: Date? = nil,
        location: String? = nil,
        phoneToReschedule: String? = nil
    ) async -> Result {
        guard let start = confirmedDate ?? parseDate(appointmentText), start > Date() else { return .failed }
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
        // Enrich notes with a tap-to-call reschedule number.
        var fullNotes = notes
        if let phone = phoneToReschedule, !phone.isEmpty {
            fullNotes += "\n\nTo change or cancel, call \(phone)."
        }
        fullNotes += "\n\nBooked with KindlyCall."
        event.notes = fullNotes
        if let location, !location.isEmpty { event.location = location }
        // tel: URL makes the event's link tap-to-call.
        if let phone = phoneToReschedule?.filter({ $0.isNumber || $0 == "+" }), !phone.isEmpty {
            event.url = URL(string: "tel:\(phone)")
        }
        event.startDate = start
        event.endDate = start.addingTimeInterval(3600)
        // Reminders: a day before and an hour before.
        event.addAlarm(EKAlarm(relativeOffset: -86_400))
        event.addAlarm(EKAlarm(relativeOffset: -3_600))
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            return .added
        } catch {
            return .failed
        }
    }

    /// Only accept an explicit ISO timestamp with an offset. Relative weekdays and
    /// natural-language dates need the user to review a date in the calendar sheet.
    static func parseDate(_ text: String) -> Date? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"#, options: .regularExpression) != nil else { return nil }
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: value) { return date }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: value)
    }
}
