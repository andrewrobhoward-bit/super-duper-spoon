# HangarLog (iOS)

HangarLog is a SwiftUI + SwiftData iOS app for logging plane sightings and flights.

## Features in this MVP

- Offline-first local storage using SwiftData.
- Track **Spotted** and **Flown** entries.
- Required registration field with live insight:
  - Seen-before count
  - Last seen date/location
- Save-time logic:
  - Computes `isFirstForRegistration`
  - Duplicate warning for same registration + location within 2 hours
- Tab-based app structure:
  - **Hangar**: high-level totals + recent firsts
  - **Logbook**: searchable list + mode/date filters
  - **Add**: quick entry options
  - **Stats**: top aircraft types and operators
  - **Settings**: CSV export + delete all data
- Entry detail view with edit/delete.

## Project structure

```text
HangarLog.xcodeproj/
  project.pbxproj
HangarLog/
  HangarLogApp.swift
  ContentView.swift
  Models/
    Entry.swift
    EntryInsights.swift
  Views/
    AddEntryHubView.swift
    EntryDetailView.swift
    EntryFormView.swift
    HomeView.swift
    LogbookView.swift
    SettingsView.swift
    StatsView.swift
    ViewSupport.swift
  Resources/
    Assets.xcassets/
      Contents.json
      AppIcon.appiconset/
        Contents.json
```

## Build and run (Xcode)

1. Open `HangarLog.xcodeproj` in Xcode 15+.
2. Select the `HangarLog` scheme.
3. Choose an iOS 17+ simulator (or a connected device).
4. Press **Run**.

## Notes

- The app uses generated Info.plist settings from project build settings.
- Storage is local to device/simulator (SwiftData store).

## Next features

- Photo attachments per entry.
- Better coordinate capture (Core Location picker/map).
- Optional backup/restore import workflow.
- Richer stats and charts.
