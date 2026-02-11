import Foundation

struct RegistrationInsight {
    let count: Int
    let lastSeenDate: Date?
    let lastSeenLocation: String?

    static let empty = RegistrationInsight(count: 0, lastSeenDate: nil, lastSeenLocation: nil)
}

enum DateRangeFilter: String, CaseIterable, Identifiable {
    case thisMonth
    case thisYear
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisMonth: return "This Month"
        case .thisYear: return "This Year"
        case .all: return "All"
        }
    }
}

enum ModeFilter: String, CaseIterable, Identifiable {
    case all
    case spotted
    case flown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .spotted: return "Spotted"
        case .flown: return "Flown"
        }
    }
}
