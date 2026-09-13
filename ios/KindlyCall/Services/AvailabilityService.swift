import Foundation
import EventKit

/// Reads the user's calendar free/busy and summarizes open times, so the agent
/// only requests slots the user is actually free for (feature #3).
enum AvailabilityService {
    /// A compact, human summary of free time over the next `days` days, e.g.
    /// "Mon: free after 2pm. Tue: 9am–12pm, 3pm–6pm. Wed: all day." Returns nil
    /// if access is denied or nothing useful can be computed.
    static func summary(days: Int = 7, dayStartHour: Int = 8, dayEndHour: Int = 20) async -> String? {
        let store = EKEventStore()
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        guard granted else { return nil }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let now = Date()
        guard let rangeEnd = cal.date(byAdding: .day, value: days, to: now) else { return nil }

        let predicate = store.predicateForEvents(withStart: now, end: rangeEnd, calendars: nil)
        let events = store.events(matching: predicate).filter { !$0.isAllDay }

        var lines: [String] = []
        let df = DateFormatter(); df.dateFormat = "EEE"; df.timeZone = .current

        for offset in 0..<days {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }
            guard let winStart = cal.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: day),
                  let winEnd = cal.date(bySettingHour: dayEndHour, minute: 0, second: 0, of: day) else { continue }
            let lower = max(winStart, offset == 0 ? now : winStart)
            if lower >= winEnd { continue }

            // Busy intervals within the window.
            let busy = events.compactMap { e -> (Date, Date)? in
                let s = max(e.startDate, lower), en = min(e.endDate, winEnd)
                return s < en ? (s, en) : nil
            }.sorted { $0.0 < $1.0 }

            // Free = window minus busy.
            var free: [(Date, Date)] = []
            var cursor = lower
            for (bs, be) in busy {
                if bs > cursor { free.append((cursor, bs)) }
                cursor = max(cursor, be)
            }
            if cursor < winEnd { free.append((cursor, winEnd)) }
            // Keep only reasonably-sized gaps (≥30 min).
            free = free.filter { $0.1.timeIntervalSince($0.0) >= 1800 }
            if free.isEmpty { continue }

            let name = df.string(from: day)
            let full = free.count == 1 && free[0].0 <= lower.addingTimeInterval(60) && free[0].1 >= winEnd.addingTimeInterval(-60)
            if full {
                lines.append("\(name): all day")
            } else {
                let spans = free.map { "\(hm($0.0))–\(hm($0.1))" }.joined(separator: ", ")
                lines.append("\(name): \(spans)")
            }
            if lines.count >= 5 { break }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "; ")
    }

    private static func hm(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "ha"; f.amSymbol = "am"; f.pmSymbol = "pm"; f.timeZone = .current
        return f.string(from: d).lowercased()
    }
}
