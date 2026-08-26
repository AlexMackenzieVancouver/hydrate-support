import Foundation
import EventKit

/// Action items become real reminders, with real due dates, in the app the
/// user already checks.
///
/// This is the free-tier delivery and the one that proves the thesis: the
/// meeting *causes* a record to exist somewhere the user actually works
/// (E-3, E-7). It never touches the network — `leavesTheDevice` is false, and
/// the Privacy Ledger says so.
public actor RemindersDelivery: DeliveryTarget {
    public nonisolated let id = "target.reminders"
    public nonisolated let displayName = "Reminders"
    public nonisolated let leavesTheDevice = false
    public nonisolated let requiredTier: Tier = .free

    private let store: EKEventStore
    private let listName: String

    public init(store: EKEventStore = EKEventStore(), listName: String = "Earshot") {
        self.store = store
        self.listName = listName
    }

    public func preview(_ payload: DeliveryPayload) async throws -> DeliveryPreview {
        let lines = payload.acceptedActions.map { action -> String in
            var line = action.text
            if let due = action.dueDate {
                line += " · due \(due.formatted(date: .abbreviated, time: .omitted))"
            }
            return line
        }
        return DeliveryPreview(
            lines: lines,
            destination: "\(listName) list in Reminders, on this iPhone",
            networkWarning: nil
        )
    }

    public func deliver(_ payload: DeliveryPayload) async throws -> DeliveryResult {
        guard try await store.requestFullAccessToReminders() else {
            throw DeliveryError.permissionDenied("Earshot needs access to Reminders to put your action items there.")
        }

        let calendar = try list()
        var externalIDs: [UUID: String] = [:]

        for action in payload.acceptedActions {
            let reminder = EKReminder(eventStore: store)
            reminder.calendar = calendar
            reminder.title = action.text
            // The deep link is what makes the round-trip legible from the other
            // side: tapping through from Reminders lands on the moment in the
            // transcript this came from.
            reminder.notes = Self.notes(for: action, payload: payload)

            if let due = action.dueDate {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day], from: due
                )
            }

            try store.save(reminder, commit: false)
            externalIDs[action.id] = reminder.calendarItemIdentifier
        }

        try store.commit()

        return DeliveryResult(
            itemCount: payload.acceptedActions.count,
            payloadSummary: "\(payload.acceptedActions.count) action item(s) added to the \(listName) list. Stayed on this iPhone.",
            externalIDs: externalIDs
        )
    }

    /// F-19's other half: when the user ticks the reminder off in Reminders,
    /// the action item closes here too. Called on `EKEventStoreChanged`, not on
    /// a poll — see RFC §4.
    public func completedExternalIDs(from externalIDs: [String]) -> [String] {
        externalIDs.filter { identifier in
            guard let item = store.calendarItem(withIdentifier: identifier) as? EKReminder else {
                return false
            }
            return item.isCompleted
        }
    }

    private func list() throws -> EKCalendar {
        let existing = store.calendars(for: .reminder).first { $0.title == listName }
        if let existing { return existing }

        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = listName
        calendar.source = store.defaultCalendarForNewReminders()?.source
        guard calendar.source != nil else {
            throw DeliveryError.destinationUnavailable("No Reminders account is set up on this iPhone.")
        }
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    private static func notes(for action: DeliverableAction, payload: DeliveryPayload) -> String {
        var lines = ["From \"\(payload.title)\" · \(payload.date.formatted(date: .abbreviated, time: .shortened))"]
        if let who = action.assignee { lines.append("Owner: \(who)") }
        lines.append("earshot://note/\(payload.noteID.uuidString)")
        return lines.joined(separator: "\n")
    }
}
