# ScheduleMate — GPA & Timetable Manager (Flutter)

ScheduleMate is a student productivity app built with Flutter. It helps students calculate semester and cumulative GPA, import their timetable from faculty HTML exports, and schedule weekly class reminders.

## Why this app exists
Many students need a simple way to:
- track grades and GPA,
- import a timetable from an HTML export,
- keep class reminders in one place.

ScheduleMate combines GPA tracking, timetable import, and local notifications into a single Flutter app.

## Key features
- Automatic semester and cumulative GPA calculation
- Timetable import from HTML export files
- Timetable view grouped by day
- Weekly notification reminders for scheduled classes

## Technology stack
- Dart + Flutter
- Material 3 UI
- SQLite persistence via `sqflite`
- State management with `provider`
- HTML parsing using `package:html`

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/TharushaAkash/ScheduleMate.git
   cd ScheduleMate
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

If the repository does not yet contain native folders, generate them first:
```bash
flutter create --project-name gpa_timetable_app . --overwrite
flutter pub get
flutter run
```

## Android setup
For Android 12+ exact alarm reminders, add the following to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

## Project structure
- `lib/main.dart` — app entry point, theme, provider setup
- `lib/models/` — data models for courses, semesters, and timetable entries
- `lib/providers/` — state management for GPA, timetable, and other app data
- `lib/services/` — database helper, timetable parser, notifications
- `lib/screens/` — UI screens for home, GPA, timetable upload, and timetable view

## Timetable parser
The timetable parser in `lib/services/timetable_parser.dart` supports two formats:
1. Flat HTML tables with header rows
2. Grid-style schedules using weekdays and time slots

### Customization notes
If the parser does not recognize your export, update its mapping rules:
- inspect the exported HTML structure,
- verify header names and table layout,
- adjust the parser selectors in `timetable_parser.dart`.

## Usage
1. Add a new semester.
2. Enter modules, credit hours, and grades.
3. Import your faculty timetable HTML file.
4. Select your Year / Semester / Group.
5. Enable reminders for your timetable.

## Developer notes
- Update the grade-point scale in `lib/models/course.dart` if needed.
- The timetable parser is flexible but may require adjustments for different HTML formats.
- Notifications are managed by `lib/services/notification_service.dart`.

## Troubleshooting
- If timetable import fails, check the HTML export format and adapt the parser.
- If notifications are not delivered, verify Android notification permissions and alarm support.

## Future improvements
- Add edit support for semesters and grades
- Add reminder lead-time settings
- Cache the last imported timetable
- Support multiple timetable parser profiles

## Contributing
- Fork the repo
- Create a feature branch
- Submit a PR with focused changes
- Include a sanitized HTML example when adding parser support for a new format

## License
Add your preferred license information here.

---

Need help customizing this README further or translating it into Sinhala? I can do that too.