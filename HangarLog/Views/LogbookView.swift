import SwiftUI
import SwiftData

struct LogbookView: View {
    @Query(sort: \Entry.dateTime, order: .reverse) private var entries: [Entry]

    @State private var searchText = ""
    @State private var modeFilter: ModeFilter = .all
    @State private var dateFilter: DateRangeFilter = .all

    private var filteredEntries: [Entry] {
        entries.filter { entry in
            matchesMode(entry) && matchesDate(entry) && matchesSearch(entry)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Mode", selection: $modeFilter) {
                        ForEach(ModeFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Date", selection: $dateFilter) {
                        ForEach(DateRangeFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if filteredEntries.isEmpty {
                        ContentUnavailableView("No Entries", systemImage: "tray", description: Text("Try adjusting your search or filters."))
                    } else {
                        ForEach(filteredEntries) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(entry.registration.uppercased())
                                            .font(.headline)
                                        Spacer()
                                        Text(entry.mode.title)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.thinMaterial, in: Capsule())
                                    }
                                    Text(DateFormatter.entryDateTime.string(from: entry.dateTime))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(summaryLine(for: entry))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Logbook")
            .searchable(text: $searchText, prompt: "Reg, operator, type, location")
        }
    }

    private func matchesMode(_ entry: Entry) -> Bool {
        switch modeFilter {
        case .all: return true
        case .spotted: return entry.mode == .spotted
        case .flown: return entry.mode == .flown
        }
    }

    private func matchesDate(_ entry: Entry) -> Bool {
        let calendar = Calendar.current
        switch dateFilter {
        case .all:
            return true
        case .thisMonth:
            return calendar.isDate(entry.dateTime, equalTo: .now, toGranularity: .month)
        case .thisYear:
            return calendar.isDate(entry.dateTime, equalTo: .now, toGranularity: .year)
        }
    }

    private func matchesSearch(_ entry: Entry) -> Bool {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return true }

        let haystack = [
            entry.registration,
            entry.operator,
            entry.aircraftType,
            entry.locationName
        ].joined(separator: " ").lowercased()

        return haystack.contains(term)
    }

    private func summaryLine(for entry: Entry) -> String {
        var components: [String] = []
        if !entry.operator.isEmpty { components.append(entry.operator) }
        if !entry.aircraftType.isEmpty { components.append(entry.aircraftType) }
        if !entry.locationName.isEmpty { components.append(entry.locationName) }

        return components.isEmpty ? "No extra details" : components.joined(separator: " • ")
    }
}
