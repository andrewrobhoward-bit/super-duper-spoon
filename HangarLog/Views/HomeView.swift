import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Entry.dateTime, order: .reverse) private var entries: [Entry]

    private var totalSpotted: Int { entries.filter { $0.mode == .spotted }.count }
    private var totalFlown: Int { entries.filter { $0.mode == .flown }.count }
    private var uniqueRegistrations: Int { Set(entries.map { $0.registration.uppercased() }).count }

    private var entriesThisMonth: Int {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.dateTime, equalTo: .now, toGranularity: .month) }.count
    }

    private var recentFirsts: [Entry] {
        Array(entries.filter { $0.isFirstForRegistration }.prefix(10))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    metricRow(title: "Total Spotted", value: totalSpotted)
                    metricRow(title: "Total Flown", value: totalFlown)
                    metricRow(title: "Unique Registrations", value: uniqueRegistrations)
                    metricRow(title: "Entries This Month", value: entriesThisMonth)
                }

                Section("Recent Firsts") {
                    if recentFirsts.isEmpty {
                        Text("No first sightings yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentFirsts) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.registration.uppercased())
                                        .font(.headline)
                                    Text("\(entry.mode.title) • \(DateFormatter.entryDateTime.string(from: entry.dateTime))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if !entry.locationName.isEmpty {
                                        Text(entry.locationName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hangar")
        }
    }

    private func metricRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
        }
    }
}
