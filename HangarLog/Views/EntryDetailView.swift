import SwiftUI
import SwiftData

struct EntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Entry.dateTime, order: .reverse) private var entries: [Entry]

    let entry: Entry

    @State private var showDeleteConfirmation = false

    private var insight: RegistrationInsight {
        registrationInsight(for: entry.registration, entries: entries, excluding: entry.id)
    }

    var body: some View {
        List {
            Section("Summary") {
                row("Mode", entry.mode.title)
                row("Registration", entry.registration.uppercased())
                row("Date", DateFormatter.entryDateTime.string(from: entry.dateTime))
                row("Location", valueOrDash(entry.locationName))
                row("Seen", "\(insight.count + 1) times")

                if let lastDate = insight.lastSeenDate {
                    row("Last Seen", DateFormatter.entryDateTime.string(from: lastDate))
                }
                if let lastLocation = insight.lastSeenLocation {
                    row("Last Seen Location", lastLocation)
                }
            }

            Section("Aircraft") {
                row("Type", valueOrDash(entry.aircraftType))
                row("Operator", valueOrDash(entry.operator))
            }

            if entry.mode == .flown {
                Section("Flight") {
                    row("Flight Number", valueOrDash(entry.flightNumber))
                    row("Origin", valueOrDash(entry.origin))
                    row("Destination", valueOrDash(entry.destination))
                }
            }

            Section("Coordinates") {
                row("Latitude", entry.latitude.map(String.init) ?? "-")
                row("Longitude", entry.longitude.map(String.init) ?? "-")
            }

            if !entry.photoFilenames.isEmpty {
                Section("Photos") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(entry.photoFilenames, id: \.self) { filename in
                                if let image = loadImage(for: filename) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Notes") {
                Text(valueOrDash(entry.notes))
                    .foregroundStyle(entry.notes.isEmpty ? .secondary : .primary)
            }

            Section {
                NavigationLink("Edit Entry") {
                    EntryFormView(mode: entry.mode, editingEntry: entry)
                }
                Button("Delete Entry", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(entry.registration.uppercased())
        .alert("Delete this entry?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                entry.photoFilenames.forEach(deletePhoto(named:))
                modelContext.delete(entry)
                do {
                    try modelContext.save()
                    dismiss()
                } catch {
                    assertionFailure("Failed to delete entry: \(error)")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    private func valueOrDash(_ value: String) -> String {
        value.isEmpty ? "-" : value
    }
}
