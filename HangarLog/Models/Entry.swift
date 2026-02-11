import Foundation
import SwiftData

enum EntryMode: String, Codable, CaseIterable, Identifiable {
    case spotted
    case flown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spotted: return "Spotted"
        case .flown: return "Flown"
        }
    }
}

@Model
final class Entry {
    var id: UUID
    var mode: EntryMode
    var registration: String
    var aircraftType: String
    var `operator`: String
    var dateTime: Date
    var locationName: String
    var latitude: Double?
    var longitude: Double?
    var flightNumber: String
    var origin: String
    var destination: String
    var notes: String
    var isFirstForRegistration: Bool

    init(
        id: UUID = UUID(),
        mode: EntryMode,
        registration: String,
        aircraftType: String = "",
        operator: String = "",
        dateTime: Date = .now,
        locationName: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        flightNumber: String = "",
        origin: String = "",
        destination: String = "",
        notes: String = "",
        isFirstForRegistration: Bool = false
    ) {
        self.id = id
        self.mode = mode
        self.registration = registration
        self.aircraftType = aircraftType
        self.operator = `operator`
        self.dateTime = dateTime
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.flightNumber = flightNumber
        self.origin = origin
        self.destination = destination
        self.notes = notes
        self.isFirstForRegistration = isFirstForRegistration
    }
}
