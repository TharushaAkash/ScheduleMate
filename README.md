# GPA & Timetable App (Flutter)

A mobile app for tracking semester/cumulative GPA and building a personal
timetable from an uploaded full faculty timetable HTML file, with class
reminders 30 minutes before each session.

## Features
- **GPA tracker**: add semesters (Year + Semester), add modules with credit
  hours and grade, auto-computed semester GPA and running cumulative GPA
  (4.0 scale, editable in `lib/models/course.dart`).
- **Timetable from HTML upload**: pick an `.html` file, the app parses it,
  you choose your Year / Semester / Group, and your classes appear as cards
  grouped by day.
- **Reminders**: tapping the bell icon schedules a local notification 30
  minutes before every class in your selected timetable, repeating weekly.

## Setup
```bash
flutter create --project-name gpa_timetable_app . --overwrite   # if starting fresh
flutter pub get
flutter run
```
Android: no extra config needed beyond what `flutter create` scaffolds
(this project ships only `lib/` + `pubspec.yaml` — run `flutter create .`
in this folder first to generate the `android/`, `ios/` platform folders,
then copy these files in over the generated `lib/`).

For exact-time notifications on Android 12+, add to
`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

## ⚠️ Important: adapt the timetable parser to your real HTML file
I don't have your actual faculty timetable export, so
`lib/services/timetable_parser.dart` currently assumes the HTML contains a
`<table>` whose **first row is a header** with recognisable column names,
e.g.:

| Year | Semester | Group | Day | Start Time | End Time | Module Code | Module Name | Venue | Lecturer |
|---|---|---|---|---|---|---|---|---|---|

The parser matches headers by keyword (case-insensitive), so column order
doesn't matter. If your real file instead uses a **grid layout** (weekday
columns × time-slot rows, common in exported university timetables), a
rough fallback (`_parseGridFallback`) is included but you'll need to:
1. Open the real HTML in a text editor and check actual tag/class names.
2. Update the `querySelector`/`querySelectorAll` calls in
   `timetable_parser.dart` to match (e.g. specific `class="..."` attributes,
   `rowspan`/`colspan` handling if cells merge across time slots).
3. Make sure Year/Semester/Group values get attached to each entry —
   the grid fallback currently leaves `year = 0` since grids are usually
   per-page-per-group; you'll likely parse that from a page heading instead
   (e.g. `document.querySelector('h2').text`).

**Tip:** paste a snippet of the real HTML into Claude to get the exact
selectors filled in — a live sample makes this a 5-minute fix.

## Project structure
```
lib/
  models/          Course, Semester, TimetableEntry
  services/        DatabaseHelper (sqflite), TimetableParser (html), NotificationService
  providers/        GpaProvider, TimetableProvider (state management)
  screens/          HomeScreen, GpaScreen, TimetableUploadScreen, TimetableViewScreen
  main.dart
```

## Possible next steps
- Add semester/GPA edit (not just add/delete).
- Cache the last uploaded timetable so re-opening the app doesn't require
  re-uploading (already partly done — entries are saved to SQLite on
  selection; you'd just add a "load last saved timetable" path on startup).
- Let the user tweak the 30-minute lead time in settings.
- Handle multiple timetable HTML formats via a dropdown ("My uni uses format A/B").
