import SwiftUI
import SwiftData
import PhotosUI

struct EntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Entry.dateTime, order: .reverse) private var entries: [Entry]

    @StateObject private var locationFetcher = LocationFetcher()

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
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingPhotoData: [Data] = []
    @State private var existingPhotoFilenames: [String]

    @State private var showDuplicateAlert = false
    @State private var validationMessage: String?

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
        _existingPhotoFilenames = State(initialValue: editingEntry?.photoFilenames ?? [])
    }

    private var trimmedRegistration: String {
        normalizeRegistration(registration)
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

                Button("Use Current Location") {
                    locationFetcher.requestLocation()
                }

                TextField("Latitude", text: $latitudeText)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $longitudeText)
                    .keyboardType(.decimalPad)

                if let error = locationFetcher.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if mode == .flown {
                Section("Flight") {
                    TextField("Flight Number", text: $flightNumber)
                    TextField("Origin", text: $origin)
                    TextField("Destination", text: $destination)
                }
            }

            Section("Photos") {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 8, matching: .images) {
                    Label("Add Photos", systemImage: "photo.on.rectangle")
                }

                if !existingPhotoFilenames.isEmpty || !pendingPhotoData.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(existingPhotoFilenames, id: \.self) { filename in
                                if let image = loadImage(for: filename) {
                                    previewImage(image)
                                }
                            }
                            ForEach(Array(pendingPhotoData.enumerated()), id: \.offset) { _, data in
                                if let image = UIImage(data: data) {
                                    previewImage(image)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
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
                    Task {
                        await attemptSave()
                    }
                }
                .disabled(trimmedRegistration.isEmpty)
            }
        }
        .onChange(of: locationFetcher.lastCoordinate) { _, newValue in
            if let coordinate = newValue {
                latitudeText = String(format: "%.6f", coordinate.latitude)
                longitudeText = String(format: "%.6f", coordinate.longitude)
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                var loaded: [Data] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(data)
                    }
                }
                pendingPhotoData = loaded
            }
        }
        .alert("Possible duplicate", isPresented: $showDuplicateAlert) {
            Button("Save Anyway", role: .destructive) {
                Task {
                    await saveEntry(ignoreDuplicateCheck: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("An entry with the same registration and location exists within 2 hours. Save anyway?")
        }
        .alert("Validation", isPresented: Binding(get: {
            validationMessage != nil
        }, set: { newValue in
            if !newValue { validationMessage = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private func previewImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func attemptSave() async {
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
            await saveEntry(ignoreDuplicateCheck: false)
        }
    }

    private func saveEntry(ignoreDuplicateCheck: Bool) async {
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

        guard !trimmedRegistration.isEmpty else {
            validationMessage = ValidationError.invalidRegistration.localizedDescription
            return
        }

        do {
            let (lat, lon) = try validateCoordinates(latitudeText: latitudeText, longitudeText: longitudeText)
            let firstForReg = registrationInsight(for: trimmedRegistration, entries: entries, excluding: editingEntry?.id).count == 0

            var newPhotoFilenames: [String] = []
            for data in pendingPhotoData {
                let filename = try saveJPEGData(data)
                newPhotoFilenames.append(filename)
            }

            let mergedPhotoFilenames = existingPhotoFilenames + newPhotoFilenames

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
            target.photoFilenames = mergedPhotoFilenames

            if editingEntry == nil {
                modelContext.insert(target)
            }

            try modelContext.save()
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
