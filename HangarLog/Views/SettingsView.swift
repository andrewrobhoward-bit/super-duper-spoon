import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Entry.dateTime, order: .reverse) private var entries: [Entry]

    @State private var csvURL: URL?
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showImporter = false
    @State private var importSummary: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Data") {
                    Button("Export CSV") {
                        exportCSV()
                    }

                    Button("Import CSV") {
                        showImporter = true
                    }

                    Button("Delete All Data", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showShareSheet) {
                if let csvURL {
                    ShareSheet(activityItems: [csvURL])
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .text]) { result in
                switch result {
                case .success(let fileURL):
                    importCSV(from: fileURL)
                case .failure(let error):
                    importSummary = "Import failed: \(error.localizedDescription)"
                }
            }
            .alert("Delete all entries?", isPresented: $showDeleteConfirmation) {
                Button("Delete All", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all HangarLog entries.")
            }
            .alert("Import Summary", isPresented: Binding(get: {
                importSummary != nil
            }, set: { newValue in
                if !newValue { importSummary = nil }
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importSummary ?? "")
            }
        }
    }

    private func exportCSV() {
        let header = "id,mode,registration,aircraftType,operator,dateTime,locationName,latitude,longitude,flightNumber,origin,destination,notes,isFirstForRegistration,photoFilenames"

        let rows = entries.map { entry in
            [
                entry.id.uuidString,
                entry.mode.rawValue,
                entry.registration,
                entry.aircraftType,
                entry.operator,
                ISO8601DateFormatter().string(from: entry.dateTime),
                entry.locationName,
                entry.latitude.map(String.init) ?? "",
                entry.longitude.map(String.init) ?? "",
                entry.flightNumber,
                entry.origin,
                entry.destination,
                entry.notes,
                String(entry.isFirstForRegistration),
                entry.photoFilenames.joined(separator: "|")
            ]
            .map(csvEscaped)
            .joined(separator: ",")
        }

        let csvString = ([header] + rows).joined(separator: "\n")
        let fileName = "HangarLog-Export-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            csvURL = url
            showShareSheet = true
        } catch {
            assertionFailure("Failed to export CSV: \(error)")
        }
    }

    private func importCSV(from url: URL) {
        do {
            let csv = try String(contentsOf: url)
            let rows = parseCSVRows(csv)
            guard let header = rows.first else {
                importSummary = "No rows found in CSV file."
                return
            }

            let keyedRows = rows.dropFirst().map { values -> [String: String] in
                var map: [String: String] = [:]
                for (index, key) in header.enumerated() where index < values.count {
                    map[key] = values[index]
                }
                return map
            }

            var imported = 0
            var skipped = 0

            for row in keyedRows {
                guard let modeRaw = row["mode"],
                      let mode = EntryMode(rawValue: modeRaw),
                      let registration = row["registration"],
                      let dateString = row["dateTime"],
                      let date = ISO8601DateFormatter().date(from: dateString) else {
                    skipped += 1
                    continue
                }

                let normalizedRegistration = normalizeRegistration(registration)
                let location = row["locationName"] ?? ""
                let duplicate = entries.contains {
                    normalizeRegistration($0.registration) == normalizedRegistration &&
                    $0.mode == mode &&
                    abs($0.dateTime.timeIntervalSince(date)) < 1 &&
                    $0.locationName == location
                }
                if duplicate {
                    skipped += 1
                    continue
                }

                let entry = Entry(
                    mode: mode,
                    registration: normalizedRegistration,
                    aircraftType: row["aircraftType"] ?? "",
                    operator: row["operator"] ?? "",
                    dateTime: date,
                    locationName: location,
                    latitude: Double(row["latitude"] ?? ""),
                    longitude: Double(row["longitude"] ?? ""),
                    flightNumber: row["flightNumber"] ?? "",
                    origin: row["origin"] ?? "",
                    destination: row["destination"] ?? "",
                    notes: row["notes"] ?? "",
                    isFirstForRegistration: (row["isFirstForRegistration"] ?? "false") == "true",
                    photoFilenames: (row["photoFilenames"] ?? "").split(separator: "|").map(String.init)
                )

                modelContext.insert(entry)
                imported += 1
            }

            try modelContext.save()
            importSummary = "Imported \(imported) entries. Skipped \(skipped) rows."
        } catch {
            importSummary = "Import failed: \(error.localizedDescription)"
        }
    }

    private func csvEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func deleteAllData() {
        entries.flatMap(\.photoFilenames).forEach(deletePhoto(named:))
        do {
            try modelContext.delete(model: Entry.self)
            try modelContext.save()
        } catch {
            assertionFailure("Failed to delete data: \(error)")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
