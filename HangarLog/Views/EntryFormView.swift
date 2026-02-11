import SwiftUI
import SwiftData

struct EntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Entry.dateTime, order: .reverse) private var entries: [Entry]

    private let editingEntry: Entry?

    @State private var mode: EntryMode
    @State private var registration: String
    @State private var aircraftType: String
    @State private var operatorName: String
    @State private var dateTime: Date
    @State private var locationName: String
    @State private var latitudeText: String
    @State private var longitudeText: String
    @State private var flightNumber: String
    @State private var origin: String
    @State private var destination: String
    @State private var notes: String

    @State private var showDuplicateAlert = false

    init(mode: EntryMode, editingEntry: Entry? = nil) {
        self.editingEntry = editingEntry
        _mode = State(initialValue: editingEntry?.mode ?? mode)
        _registration = State(initialValue: editingEntry?.registration ?? "")
        _aircraftType = State(initialValue: editingEntry?.aircraftType ?? "")
        _operatorName = State(initialValue: editingEntry?.operator ?? "")
        _dateTime = State(initialValue: editingEntry?.dateTime ?? .now)
        _locationName = State(initialValue: editingEntry?.locationName ?? "")
        _latitudeText = State(initialValue: editingEntry?.latitude.map(String.init) ?? "")
        _longitudeText = State(initialValue: editingEntry?.longitude.map(String.init) ?? "")
        _flightNumber = State(initialValue: editingEntry?.flightNumber ?? "")
        _origin = State(initialValue: editingEntry?.origin ?? "")
        _destination = State(initialValue: editingEntry?.destination ?? "")
        _notes = State(initialValue: editingEntry?.notes ?? "")
    }

    private var trimmedRegistration: String {
        registration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var insight: RegistrationInsight {
        registrationInsight(for: trimmedRegistration, entries: entries, excluding: editingEntry?.id)
    }

    var body: some View {
        Form {
            Section("Entry") {
                Picker("Mode", selection: $mode) {
                    ForEach(EntryMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                TextField("Registration *", text: $registration)
                    .textInputAutocapitalization(.characters)

                if !trimmedRegistration.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Seen before: \(insight.count) times")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let lastDate = insight.lastSeenDate {
                            let location = insight.lastSeenLocation ?? "Unknown location"
                            Text("Last seen: \(DateFormatter.entryDateTime.string(from: lastDate)) • \(location)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DatePicker("Date & Time", selection: $dateTime)
            }

            Section("Details") {
                TextField("Aircraft Type", text: $aircraftType)
                TextField("Operator", text: $operatorName)
                TextField("Location", text: $locationName)
                TextField("Latitude", text: $latitudeText)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $longitudeText)
                    .keyboardType(.decimalPad)
            }

            if mode == .flown {
                Section("Flight") {
                    TextField("Flight Number", text: $flightNumber)
                    TextField("Origin", text: $origin)
                    TextField("Destination", text: $destination)
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle(editingEntry == nil ? "New \(mode.title)" : "Edit Entry")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    attemptSave()
                }
                .disabled(trimmedRegistration.isEmpty)
            }
        }
        .alert("Possible duplicate", isPresented: $showDuplicateAlert) {
            Button("Save Anyway", role: .destructive) {
                saveEntry(ignoreDuplicateCheck: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("An entry with the same registration and location exists within 2 hours. Save anyway?")
        }
    }

    private func attemptSave() {
        let duplicate = hasPotentialDuplicate(
            registration: trimmedRegistration,
            dateTime: dateTime,
            locationName: locationName,
            entries: entries,
            excluding: editingEntry?.id
        )

        if duplicate {
            showDuplicateAlert = true
        } else {
            saveEntry(ignoreDuplicateCheck: false)
        }
    }

    private func saveEntry(ignoreDuplicateCheck: Bool) {
        if !ignoreDuplicateCheck {
            let duplicate = hasPotentialDuplicate(
                registration: trimmedRegistration,
                dateTime: dateTime,
                locationName: locationName,
                entries: entries,
                excluding: editingEntry?.id
            )
            if duplicate {
                showDuplicateAlert = true
                return
            }
        }

        let firstForReg = registrationInsight(for: trimmedRegistration, entries: entries, excluding: editingEntry?.id).count == 0

        let lat = Double(latitudeText)
        let lon = Double(longitudeText)

        let target = editingEntry ?? Entry(mode: mode, registration: trimmedRegistration)
        target.mode = mode
        target.registration = trimmedRegistration
        target.aircraftType = aircraftType.trimmingCharacters(in: .whitespacesAndNewlines)
        target.operator = operatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.dateTime = dateTime
        target.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.latitude = lat
        target.longitude = lon
        target.flightNumber = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        target.origin = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        target.destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.isFirstForRegistration = firstForReg

        if editingEntry == nil {
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save entry: \(error)")
        }
    }
}
