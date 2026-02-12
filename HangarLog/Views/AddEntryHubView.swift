import SwiftUI

struct AddEntryHubView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink(destination: EntryFormView(mode: .spotted)) {
                    addCard(title: "Add Spotting", subtitle: "Log a new plane sighting", systemImage: "eye")
                }

                NavigationLink(destination: EntryFormView(mode: .flown)) {
                    addCard(title: "Add Flight", subtitle: "Log a flight you took", systemImage: "airplane")
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add")
        }
    }

    private func addCard(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
