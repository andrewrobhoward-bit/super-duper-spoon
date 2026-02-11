import Foundation

extension DateFormatter {
    static let entryDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let entryDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

func registrationInsight(for registration: String, entries: [Entry], excluding entryID: UUID? = nil) -> RegistrationInsight {
    let normalized = registration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !normalized.isEmpty else { return .empty }

    let matches = entries
        .filter { entry in
            (entryID == nil || entry.id != entryID) && entry.registration.uppercased() == normalized
        }
        .sorted { $0.dateTime > $1.dateTime }

    return RegistrationInsight(
        count: matches.count,
        lastSeenDate: matches.first?.dateTime,
        lastSeenLocation: matches.first?.locationName.isEmpty == true ? nil : matches.first?.locationName
    )
}

func hasPotentialDuplicate(
    registration: String,
    dateTime: Date,
    locationName: String,
    entries: [Entry],
    excluding entryID: UUID? = nil
) -> Bool {
    let normalizedReg = registration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let normalizedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    guard !normalizedReg.isEmpty, !normalizedLocation.isEmpty else { return false }

    return entries.contains { entry in
        guard entryID == nil || entry.id != entryID else { return false }
        let regMatches = entry.registration.uppercased() == normalizedReg
        let locationMatches = entry.locationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedLocation
        let timeDelta = abs(entry.dateTime.timeIntervalSince(dateTime))
        return regMatches && locationMatches && timeDelta <= 2 * 60 * 60
    }
}
