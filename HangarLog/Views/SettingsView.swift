import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Entry.dateTime, order: .reverse) private var entries: [Entry]

    @State private var csvURL: URL?
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("Data") {
                    Button("Export CSV") {
                        exportCSV()
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
            .alert("Delete all entries?", isPresented: $showDeleteConfirmation) {
                Button("Delete All", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all HangarLog entries.")
            }
        }
    }

    private func exportCSV() {
        let header = "id,mode,registration,aircraftType,operator,dateTime,locationName,latitude,longitude,flightNumber,origin,destination,notes,isFirstForRegistration"

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
                String(entry.isFirstForRegistration)
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

    private func csvEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func deleteAllData() {
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
