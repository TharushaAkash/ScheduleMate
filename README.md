# 📚 ScheduleMate — GPA & Timetable Manager

A powerful Flutter app designed to help students manage their academic life. Track GPA, organize timetables, and receive smart class reminders—all in one place.

---

## ✨ Features

- 📊 **GPA Calculator** – Automatic semester and cumulative GPA calculation
- 📅 **Smart Timetable Import** – Import from faculty HTML exports in seconds
- 📍 **Organized Schedule View** – View classes grouped by day of the week
- 🔔 **Notification Reminders** – Weekly notifications for scheduled classes
- 💾 **Offline-First** – SQLite persistence for reliable, offline access

---

## 🎯 Why ScheduleMate?

Managing your academic life can be overwhelming. ScheduleMate brings together everything you need:

- **Track Grades Efficiently** – Never lose sight of your GPA
- **Import Timetables Instantly** – No manual entry required
- **Stay on Top** – Get timely reminders for your classes
- **Simple & Intuitive** – Built for students, by students

---

## 🛠️ Technology Stack

| Technology | Purpose |
|-----------|---------|
| **Dart + Flutter** | Cross-platform mobile development |
| **Material 3 UI** | Modern, accessible interface |
| **SQLite** (`sqflite`) | Local data persistence |
| **Provider** | Efficient state management |
| **package:html** | HTML parsing for timetable import |

---

## 📦 Installation

### Prerequisites
- Flutter SDK (latest version)
- Dart SDK
- Android Studio / Xcode (for emulator/device)

### Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/TharushaAkash/ScheduleMate.git
   cd ScheduleMate
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Generate native folders (if needed):**
   ```bash
   flutter create --project-name schedulemate . --overwrite
   flutter pub get
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## 🔧 Android Configuration

For **Android 12+** notification support, add these permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

---

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point, theme & provider setup
├── models/                # Data models (Course, Semester, Timetable)
├── providers/             # State management (GPA, Timetable, UI state)
├── services/              # Database, parser, notifications
│   ├── database_helper.dart
│   ├── timetable_parser.dart
│   └── notification_service.dart
└── screens/               # UI screens (Home, GPA, Upload, Timetable)
```

---

## 🚀 Quick Start Guide

1. **Add a Semester**
   - Enter semester name, year, and starting date

2. **Add Courses**
   - Input course name, credit hours, and grade
   - App automatically calculates semester GPA

3. **Import Timetable**
   - Export your faculty timetable as HTML
   - Upload through the app
   - Select your Year / Semester / Group

4. **Enable Reminders**
   - Toggle notifications for your classes
   - Receive weekly reminders before each class

---

## 🧩 Timetable Parser

The parser (`lib/services/timetable_parser.dart`) supports:

✅ Flat HTML tables with header rows  
✅ Grid-style schedules (weekday × time slots)

### Custom Format Support

If your HTML export doesn't parse automatically:

1. Inspect the exported HTML structure
2. Verify header names and table layout
3. Update the parser selectors in `timetable_parser.dart`

---

## 🛠️ Customization

### Grade Point Scale
Update the grade scale in `lib/models/course.dart` to match your institution.

### Notification Timing
Modify lead-time settings in `lib/services/notification_service.dart`.

### UI Theme
Customize Material 3 theme in `lib/main.dart`.

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| **Timetable import fails** | Verify HTML format matches parser requirements; update selectors if needed |
| **Notifications not showing** | Check Android notification permissions and alarm support on device |
| **GPA calculation off** | Verify grade scale in `course.dart` matches your institution |
| **Duplicate courses** | Clear database and re-import timetable |

---

## 🚧 Future Roadmap

- ✏️ Edit support for semesters and grades
- ⏰ Customizable reminder lead-time settings
- 💾 Cache & restore last imported timetable
- 🎯 Multiple timetable parser profiles for different institutions
- 📊 GPA trend charts and analytics

---

## 🤝 Contributing

We love contributions! Here's how:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit your changes** (`git commit -m 'Add amazing feature'`)
4. **Push to the branch** (`git push origin feature/amazing-feature`)
5. **Open a Pull Request**

**When adding parser support for new HTML formats:**
- Include a sanitized HTML example in your PR
- Test thoroughly with different date/time formats

---

## 📝 License

This project is licensed under the MIT License. See `LICENSE` file for details.

---

## 💬 Support & Feedback

Have questions or suggestions? Feel free to:
- Open an [Issue](https://github.com/TharushaAkash/ScheduleMate/issues)
- Start a [Discussion](https://github.com/TharushaAkash/ScheduleMate/discussions)
- Contact the maintainer

---

**Made with ❤️ for students, by students.**
