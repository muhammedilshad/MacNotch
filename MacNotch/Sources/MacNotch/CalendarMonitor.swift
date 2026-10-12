import AppKit
import EventKit

/// Today's remaining calendar events, shown in the expanded notch.
final class CalendarMonitor: ObservableObject {
    static let shared = CalendarMonitor()

    struct Event: Identifiable, Equatable {
        var id: String
        var title: String
        var start: Date
        var end: Date
        var isAllDay: Bool
        var color: NSColor
        /// Zoom, Google Meet, Teams, Webex or FaceTime link found in the event.
        var meetingURL: URL?
    }

    enum Access { case unknown, granted, denied }

    @Published private(set) var events: [Event] = []
    @Published private(set) var access: Access = .unknown

    /// Called when a meeting reminder is due.
    var onReminder: ((Event) -> Void)?
    private var reminded: Set<String> = []
    private var snoozedUntil: [String: Date] = [:]

    /// The next event that hasn't ended yet, ignoring all-day events.
    var nextEvent: Event? {
        let now = Date()
        return events.first { !$0.isAllDay && $0.end > now }
    }

    private let store = EKEventStore()
    private var started = false
    private var timer: Timer?

    func start() {
        guard !started else { return }
        started = true

        let completion: (Bool, Error?) -> Void = { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.access = granted ? .granted : .denied
                self?.refresh()
            }
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: completion)
        } else {
            store.requestAccess(to: .event, completion: completion)
        }

        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        // Drops finished events and rolls over at midnight.
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
            self?.checkReminders()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        guard access == .granted else {
            if !events.isEmpty { events = [] }
            return
        }
        let calendar = Calendar.current
        let now = Date()
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }

        let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        let upcoming = store.events(matching: predicate)
            .filter { $0.isAllDay || $0.endDate > now }
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            .map { event in
                Event(id: event.eventIdentifier ?? UUID().uuidString,
                      title: event.title ?? "Untitled",
                      start: event.startDate,
                      end: event.endDate,
                      isAllDay: event.isAllDay,
                      color: event.calendar?.color ?? .systemBlue,
                      meetingURL: Self.meetingURL(in: event))
            }
        if upcoming != events { events = upcoming }
    }

    // MARK: Reminders

    private static func key(_ event: Event) -> String { "\(event.id)|\(event.start.timeIntervalSince1970)" }

    private func checkReminders() {
        let lead = TimeInterval(AppSettings.shared.reminderMinutes * 60)
        guard lead > 0 else { return }
        let now = Date()
        for event in events where !event.isAllDay {
            let key = Self.key(event)
            if let snoozed = snoozedUntil[key] {
                guard now >= snoozed, event.end > now else { continue }
                snoozedUntil[key] = nil
                onReminder?(event)
            } else if !reminded.contains(key), event.start.timeIntervalSince(now) <= lead, event.start > now.addingTimeInterval(-60) {
                reminded.insert(key)
                onReminder?(event)
            }
        }
    }

    func snooze(_ event: Event, minutes: Int = 5) {
        snoozedUntil[Self.key(event)] = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    func join(_ event: Event) {
        if let url = event.meetingURL { NSWorkspace.shared.open(url) }
    }

    func openInCalendar(_ event: Event) {
        NSWorkspace.shared.open(URL(string: "ical://")!)
    }

    private static let meetingPattern = try? NSRegularExpression(
        pattern: #"https?://[^\s<>"]*(zoom\.us|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|webex\.com|whereby\.com|facetime\.apple\.com|chime\.aws)[^\s<>"]*"#,
        options: [.caseInsensitive])

    private static func meetingURL(in event: EKEvent) -> URL? {
        let candidates = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }
        for text in candidates {
            let range = NSRange(text.startIndex..., in: text)
            if let match = meetingPattern?.firstMatch(in: text, range: range), let swiftRange = Range(match.range, in: text) {
                return URL(string: String(text[swiftRange]))
            }
        }
        return nil
    }

    /// "in 12 min", "now", "ends in 20 min".
    static func countdown(to event: Event, from now: Date = Date()) -> String {
        if event.start > now { return "in \(TimeText.duration(event.start.timeIntervalSince(now)))" }
        return "now · ends in \(TimeText.duration(event.end.timeIntervalSince(now)))"
    }
}
