import Foundation
import CoreLocation
import UIKit

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

func normalizeRegistration(_ registration: String) -> String {
    registration
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: " ", with: "")
        .uppercased()
}

func registrationInsight(for registration: String, entries: [Entry], excluding entryID: UUID? = nil) -> RegistrationInsight {
    let normalized = normalizeRegistration(registration)
    guard !normalized.isEmpty else { return .empty }

    let matches = entries
        .filter { entry in
            (entryID == nil || entry.id != entryID) && normalizeRegistration(entry.registration) == normalized
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
    let normalizedReg = normalizeRegistration(registration)
    let normalizedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    guard !normalizedReg.isEmpty, !normalizedLocation.isEmpty else { return false }

    return entries.contains { entry in
        guard entryID == nil || entry.id != entryID else { return false }
        let regMatches = normalizeRegistration(entry.registration) == normalizedReg
        let locationMatches = entry.locationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedLocation
        let timeDelta = abs(entry.dateTime.timeIntervalSince(dateTime))
        return regMatches && locationMatches && timeDelta <= 2 * 60 * 60
    }
}

enum ValidationError: Error, LocalizedError {
    case invalidRegistration
    case invalidLatitude
    case invalidLongitude

    var errorDescription: String? {
        switch self {
        case .invalidRegistration:
            return "Please provide a valid registration."
        case .invalidLatitude:
            return "Latitude must be a number between -90 and 90."
        case .invalidLongitude:
            return "Longitude must be a number between -180 and 180."
        }
    }
}

func validateCoordinates(latitudeText: String, longitudeText: String) throws -> (Double?, Double?) {
    let trimmedLat = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedLon = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)

    let latitude = trimmedLat.isEmpty ? nil : Double(trimmedLat)
    let longitude = trimmedLon.isEmpty ? nil : Double(trimmedLon)

    if !trimmedLat.isEmpty, latitude == nil || (latitude ?? 0) < -90 || (latitude ?? 0) > 90 {
        throw ValidationError.invalidLatitude
    }
    if !trimmedLon.isEmpty, longitude == nil || (longitude ?? 0) < -180 || (longitude ?? 0) > 180 {
        throw ValidationError.invalidLongitude
    }

    return (latitude, longitude)
}

func topRegistration(entries: [Entry]) -> (String, Int)? {
    let map = entries.reduce(into: [String: Int]()) { partialResult, entry in
        let reg = normalizeRegistration(entry.registration)
        guard !reg.isEmpty else { return }
        partialResult[reg, default: 0] += 1
    }

    return map.max { lhs, rhs in lhs.value < rhs.value }
}

func entryStreakDays(entries: [Entry]) -> Int {
    let calendar = Calendar.current
    let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.dateTime) })
    guard !uniqueDays.isEmpty else { return 0 }

    var streak = 0
    var cursor = calendar.startOfDay(for: .now)
    while uniqueDays.contains(cursor) {
        streak += 1
        guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
        cursor = previous
    }

    return streak
}

func entriesInCurrentYear(_ entries: [Entry]) -> [Entry] {
    let calendar = Calendar.current
    return entries.filter { calendar.isDate($0.dateTime, equalTo: .now, toGranularity: .year) }
}

func entriesInCurrentMonth(_ entries: [Entry]) -> [Entry] {
    let calendar = Calendar.current
    return entries.filter { calendar.isDate($0.dateTime, equalTo: .now, toGranularity: .month) }
}

func documentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
}

func saveJPEGData(_ data: Data) throws -> String {
    let filename = "photo-\(UUID().uuidString).jpg"
    let url = documentsDirectory().appendingPathComponent(filename)
    try data.write(to: url)
    return filename
}

func loadImage(for filename: String) -> UIImage? {
    let url = documentsDirectory().appendingPathComponent(filename)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
}

func deletePhoto(named filename: String) {
    let url = documentsDirectory().appendingPathComponent(filename)
    try? FileManager.default.removeItem(at: url)
}

func parseCSVRows(_ csv: String) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var value = ""
    var isQuoted = false
    let chars = Array(csv)
    var index = 0

    while index < chars.count {
        let char = chars[index]

        if char == "\"" {
            if isQuoted, index + 1 < chars.count, chars[index + 1] == "\"" {
                value.append("\"")
                index += 1
            } else {
                isQuoted.toggle()
            }
        } else if char == ",", !isQuoted {
            row.append(value)
            value = ""
        } else if char == "\n", !isQuoted {
            row.append(value)
            rows.append(row)
            row = []
            value = ""
        } else if char != "\r" {
            value.append(char)
        }

        index += 1
    }

    if !value.isEmpty || !row.isEmpty {
        row.append(value)
        rows.append(row)
    }

    return rows
}

final class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastCoordinate: CLLocationCoordinate2D?
    @Published var lastError: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastCoordinate = locations.last?.coordinate
        lastError = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }
}
