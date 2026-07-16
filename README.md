# ScheduleMate — GPA & Timetable Manager (Flutter)

ScheduleMate is a mobile helper app for students: it calculates semester & cumulative GPA and builds a personal timetable by parsing a faculty-wide HTML timetable export. The app also schedules local reminders for classes (default: 30 minutes before each session).

## Quick highlights
- Add semesters and modules with credit hours and grades; semester GPA and cumulative GPA are calculated automatically.
- Upload a full-faculty HTML timetable and pick your Year / Semester / Group to extract only your classes.
- Schedule weekly local notifications for your classes (one tap to enable reminders for the selected timetable).

## Stack
- Language: Dart (Flutter)
- Framework: Flutter (Material 3)
- Data: SQLite via a small DatabaseHelper service (sqflite)
- State management: Provider
- HTML parsing: package:html (custom parser in `lib/services/timetable_parser.dart`)

## Features
- GPA tracker (add/delete semesters and modules; auto-calculation)
- Timetable importer from HTML (flat-table and a grid fallback heuristic)
- Local notifications for classes (repeat weekly)
- Lightweight: only `lib/` + `pubspec.yaml` shipped — run `flutter create .` to scaffold native folders

## Screenshots
(Replace these placeholders with real screenshots in the repo)
- Home / GPA overview
- Timetable upload screen
- Timetable view grouped by day
- Notification permission prompt

---

## Installation / Run (short path)
1. Clone the repo:
   ```bash
   git clone https://github.com/TharushaAkash/ScheduleMate.git
   cd ScheduleMate
   ```
2. If this folder only contains `lib/` + `pubspec.yaml` (as currently), generate native projects and then copy files:
   ```bash
   flutter create --project-name gpa_timetable_app . --overwrite
   flutter pub get
   flutter run
   ```
   Or open in your IDE (Android Studio / VS Code) and run on device/emulator.

### Android-specific
For exact-time notifications on Android 12+ add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

---

## Project structure (key files)
```
lib/
  main.dart                      App entry, theme & providers
  models/
    course.dart                   Course model, grade-points map
    semester.dart                 Semester container with courses
    timetable_entry.dart          TimetableEntry model
  providers/
    gpa_provider.dart             GPA state + DB sync
    timetable_provider.dart       Timetable selection + saved entries
    theme_provider.dart
    announcement_provider.dart
  services/
    database_helper.dart          SQLite helper (sqflite)
    timetable_parser.dart         HTML parser (flat-table + grid fallback)
    notification_service.dart     Local notification scheduling
  screens/
    home_screen.dart
    gpa_screen.dart
    timetable_upload_screen.dart
    timetable_view_screen.dart
```

How it fits together: on startup `main.dart` initializes the NotificationService and sets up Providers (GpaProvider, TimetableProvider). The Timetable flow parses uploaded HTML into `TimetableEntry` objects (models/timetable_entry.dart), the user filters by semester/group and entries are saved to SQLite via DatabaseHelper, and NotificationService schedules reminders using each entry's `notificationId`.

---

## Timetable parser — important notes & customization
The parser (lib/services/timetable_parser.dart) tries two strategies:
1. Flat data tables: looks for `<table>` elements with a header row where column names include keywords like `Year`, `Semester`, `Group`, `Day`, `Start Time`, `Module Code`, `Module Name`, `Venue`, `Lecturer`.
2. Grid fallback: for timetable exports that use a day×time grid (columns = weekdays, rows = timeslots). This fallback attempts to detect day columns and extract cell content, handling `rowspan` and nested detail tables in cells.

You must adapt the parser to your faculty's HTML if the defaults don't match:
- Open your exported HTML in a text editor and inspect the structure and class names.
- If the file uses a header row, check the header cell text and make sure keywords exist (or update `_mapHeaderColumns` keyword lists).
- If the file uses grid layout, update the selectors in `_parseGridFallback` to match the real tags/classes (e.g., `caption`, `table.detailed`, `td.detailed`, or custom `class=` values).
- Example of a typical flat-table header the parser expects (case-insensitive and order-insensitive):
  ```
  Year | Semester | Group | Day | Start Time | End Time | Module Code | Module Name | Venue | Lecturer
  ```
- If you'd like, paste a short snippet of your real HTML and the parser's selectors can be adjusted quickly.

---

## Data models (quick)
- Course (lib/models/course.dart)
  - Fields: id, semesterId, moduleCode, moduleName, creditHours, grade
  - Grade scale: static `gradePoints` map (edit this file to change the 4.0 scale).
- TimetableEntry (lib/models/timetable_entry.dart)
  - Fields: id, semester, group, subGroup, day, startTime (HH:mm), endTime (HH:mm), moduleCode, moduleName, venue, lecturer
  - `notificationId` computed from day+time+moduleCode for stable notification IDs.

---

## Usage (end-user)
1. Open app → add a Semester (Year + Semester number).
2. Add modules with credit hours and grade; semester GPA updates automatically.
3. Go to Timetable → Upload your faculty `.html` export.
4. Choose Year / Semester / Group and the app will show your classes grouped by day.
5. Tap the bell icon to schedule weekly reminders (default lead time: 30 minutes).

---

## Developer notes
- Theme/colors and app name are in `lib/main.dart`.
- Change grade-point mapping in `lib/models/course.dart` if your faculty uses a different scale or mapping.
- Timetable parser is intentionally tolerant but may require small selector tweaks for different universities — see comments in `timetable_parser.dart`.
- Notifications: make sure platform permissions and manifest entries are set (Android 12+ exact alarm & notifications).

---

## Testing & troubleshooting
- If timetable parsing returns no entries, inspect the uploaded HTML and:
  - Verify the presence of `<table>` elements and their header rows.
  - Try the grid fallback by checking if the file is grid-based (weekdays × time slots).
  - Add debug prints or log the parsed DOM in `timetable_parser.dart` to see which nodes were found.
- If notifications don't show:
  - Confirm proper notification permissions are granted.
  - Check the computed `notificationId` collisions (rare but possible if many different entries hash to same int).

---

## Roadmap / possible next steps
- Add semester/GPA edit (currently add/delete only).
- Add a settings screen to adjust reminder lead time.
- Cache the last uploaded timetable and auto-load it on startup.
- Offer multiple parser profiles (dropdown “My uni uses format A / B / C”).
- Improve UI for overlapping classes and multi-group lectures.

---

## Contributing
- Fork → feature branch → PR. Keep changes focused (parser fixes, DB improvements, UI polish).
- If adding parser support for a new HTML export, include a small anonymised example HTML snippet and tests.

---

## License & contact
- License: (add your preferred license here, e.g., MIT)
- Contact / Author: (add your name or preferred contact)

---

If you want, I can:
- produce a ready-to-commit README.md file (this exact content), or
- adapt the parser for a concrete HTML sample — paste a short (anonymised) snippet and I’ll provide exact selector edits you can apply.
