import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Entry.dateTime, order: .reverse) private var entries: [Entry]

    private var topAircraftTypes: [(String, Int)] {
        topCounts(for: entries.map { $0.aircraftType })
    }

    private var topOperators: [(String, Int)] {
        topCounts(for: entries.map { $0.operator })
    }

    private var yearEntries: [Entry] { entriesInCurrentYear(entries) }
    private var monthEntries: [Entry] { entriesInCurrentMonth(entries) }

    var body: some View {
        NavigationStack {
            List {
                Section("Highlights") {
                    statLine("Entries This Year", value: "\(yearEntries.count)")
                    statLine("Entries This Month", value: "\(monthEntries.count)")
                    statLine("Unique Regs This Year", value: "\(Set(yearEntries.map { normalizeRegistration($0.registration) }).count)")
                    statLine("Current Streak", value: "\(entryStreakDays(entries: entries)) days")

                    if let topReg = topRegistration(entries: entries) {
                        statLine("Most Spotted Registration", value: "\(topReg.0) (\(topReg.1))")
                    }
                }

                Section("Top Aircraft Types") {
                    if topAircraftTypes.isEmpty {
                        Text("No aircraft type data yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(topAircraftTypes.enumerated()), id: \.offset) { index, item in
                            statRow(rank: index + 1, label: item.0, count: item.1)
                        }
                    }
                }

                Section("Top Operators") {
                    if topOperators.isEmpty {
                        Text("No operator data yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(topOperators.enumerated()), id: \.offset) { index, item in
                            statRow(rank: index + 1, label: item.0, count: item.1)
                        }
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    private func topCounts(for values: [String]) -> [(String, Int)] {
        let counts = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String: Int]()) { partialResult, item in
                partialResult[item, default: 0] += 1
            }

        return counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(10)
            .map { ($0.key, $0.value) }
    }

    private func statRow(rank: Int, label: String, count: Int) -> some View {
        HStack {
            Text("#\(rank)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 32)
            Text(label)
            Spacer()
            Text("\(count)")
                .fontWeight(.semibold)
        }
    }

    private func statLine(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}
