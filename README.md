<div align="center">
  <a href="https://sourceforge.net/projects/schedulemate/" target="_blank"><img src="readme-assets/app_icon.png" alt="ScheduleMate" width="120"></a>
  <h1>ScheduleMate</h1>
  <p><strong>Manage your academic life. Track grades. Never miss a class.</strong></p>
  <p>
    <a href="https://sourceforge.net/projects/schedulemate/" target="_blank">🚀 SourceForge</a> •
    <a href="#-features">✨ Features</a> •
    <a href="#%EF%B8%8F-quick-start-guide">📦 Getting Started</a> •
    <a href="#-contribution">🤝 Contributing</a>
  </p>

[![Download (Latest)](https://img.shields.io/sourceforge/dm/schedulemate.svg?label=Downloads)](https://sourceforge.net/projects/schedulemate/files/latest/download)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-green)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

---

**ScheduleMate** is a modern, student-focused Flutter application that brings your entire academic life into one place.
Track GPA in real-time, import faculty timetables from HTML exports, and stay on top of every class with intelligent reminders — all **completely offline**.

&nbsp; &nbsp;[![Download ScheduleMate](https://a.fsdn.com/con/app/sf-download-button)](https://sourceforge.net/projects/schedulemate/files/latest/download)

</div>


---

## 🖥️ App Preview

<div align="center">
  <img src="ss/Screenshot%202026-07-20%20162141.png" width="200" />
  <img src="ss/Screenshot%202026-07-20%20162219.png" width="200" />
  <img src="ss/Screenshot%202026-07-20%20162236.png" width="200" />
  <img src="ss/Screenshot%202026-07-20%20162254.png" width="200" />
  <img src="ss/Screenshot%202026-07-26%20092129.png" width="200" />
</div>

---

## ✨ Features

* 📊 **GPA Calculator** — Real-time semester GPA calculation with cumulative tracking and customizable grade point scales.
* 🗂️ **Structured GPA View** — Semesters are grouped by academic year, providing a clean and organized overview of your progress.
* 📄 **Result Sheet Generation** — Export a beautifully formatted PDF report of your academic performance and grades.
* 📅 **Smart Timetable Import** — Import schedules directly from faculty HTML exports with automatic parsing.
* 📝 **Exam Tracking** — Organize and keep track of your upcoming exam schedules effortlessly.
* 📚 **CA Marks Extraction** — Upload multiple PDFs at once to automatically extract and track your Continuous Assessment marks.
* 💬 **Collaborative Rooms** — Create and join study rooms, chat with peers, and share files seamlessly via Google Drive.
* ☁️ **Automatic Cloud Sync** — Seamlessly back up and restore your data using Google Drive integration with automatic room synchronization.
* 🏖️ **Holiday Integration** — Automatically detects and highlights special public holidays (Poya Days, Christmas, etc.) on your timetable.
* 🔔 **Class Reminders** — Weekly notification reminders with customizable lead times for Android 12+.
* 💾 **Offline First** — All data stored locally via SQLite — no internet connection required.
* 🗂️ **Organized by Day/Week** — View your timetable in a clean, structured layout organized by day and time slot with a sleek weekly calendar view.
* 🎨 **Premium UI Design** — Stunning modern interface featuring **Glassmorphism**, smooth animations, and Material 3 design guidelines.
* ⚙️ **Flexible Customization** — Adjust grade point scales and notification timings to fit your institution's system.

---

## ⚙️ Tech Stack

| Category              | Technologies                        |
| --------------------- | ----------------------------------- |
| **Language**          | Dart 3.x                            |
| **Framework**         | Flutter 3.x                         |
| **UI Design**         | Material Design 3                   |
| **State Management**  | Provider                            |
| **Database**          | SQLite, Firebase, Google Drive      |
| **HTML Parsing**      | `package:html`                      |
| **Notifications**     | `flutter_local_notifications`       |
| **Platform**          | Android (iOS support planned)       |

---

## 🧭 Quick Start Guide

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/TharushaAkash/ScheduleMate.git
cd ScheduleMate
```

### 2️⃣ Install Dependencies

```bash
flutter pub get
```

### 3️⃣ Generate Native Folders (if needed)

```bash
flutter create --project-name schedulemate . --overwrite
flutter pub get
```

### 4️⃣ Configure Android Permissions

Add the following to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

> [!NOTE]
> Exact alarm permissions are required for Android 12+ to schedule class reminder notifications.

### 5️⃣ Run the Application

```bash
flutter run
```

### 6️⃣ Start Managing Your Academic Life

1. Tap **"Add Semester"** → Enter name, year, and date range.
2. Add your courses — input name, credit hours, and grade.
3. Watch your **GPA calculate automatically** in real-time ✨
4. Export HTML from your Faculty Portal → **Upload in App** to import your timetable.
5. Toggle **Notifications** → Receive weekly class reminders 🔔

---

## 📁 Project Structure

```
ScheduleMate/
├── lib/
│   ├── main.dart                 # App entry point & theme setup
│   ├── models/                   # Data models
│   │   ├── course.dart
│   │   ├── semester.dart
│   │   └── timetable_entry.dart
│   ├── providers/                # State management
│   │   ├── gpa_provider.dart
│   │   ├── timetable_provider.dart
│   │   └── app_provider.dart
│   ├── services/                 # Business logic
│   │   ├── database_helper.dart
│   │   ├── timetable_parser.dart
│   │   └── notification_service.dart
│   └── screens/                  # UI Screens
│       ├── home_screen.dart
│       ├── gpa_screen.dart
│       ├── timetable_upload_screen.dart
│       └── timetable_view_screen.dart
├── android/
├── ios/
├── assets/
└── pubspec.yaml
```

---

## 🚧 Roadmap

- [ ] ✏️ Edit/Delete semesters and courses
- [x] ⏰ Customizable reminder lead times in settings UI
- [x] 💾 Auto-backup timetable cache
- [ ] 🎯 Multiple timetable parser profiles per institution
- [ ] 📊 GPA trend analytics & charts
- [x] 🌙 Dark mode support
- [ ] 🌍 Multi-language support (Sinhala, Tamil, English)
- [ ] 📤 Export GPA transcript as PDF

---

## 🤝 Contribution

We **welcome all kinds of contributions** — not just code!
Whether you're improving the UI, fixing bugs, adding features, or improving documentation — **your input makes ScheduleMate better for every student.**

### 💡 Ways You Can Contribute

* 🧩 **Code Improvements:** Fix bugs, optimize performance, or suggest new features via [GitHub Issues](https://github.com/TharushaAkash/ScheduleMate/issues).
* 🗂️ **Timetable Parser Profiles:** Help us support more faculty HTML export formats by contributing parser configurations.
* 🐛 **Bug Reports:** Found something that doesn't work? Open a detailed issue with steps to reproduce.
* 🧠 **Ideas & Feedback:** Share feature suggestions or general feedback in [GitHub Discussions](https://github.com/TharushaAkash/ScheduleMate/discussions).
* 🧾 **Documentation:** Improve readability, fix typos, or expand the project documentation.

### 🛠️ Getting Started

1. **Fork** the repository.
2. **Create a new branch** for your changes.
3. **Commit** your improvements with clear, descriptive messages.
4. **Submit a pull request** — we'll review and merge it!

> Follow the Dart style guide and add tests for new features where applicable.

> ❤️ Every contribution, big or small, is appreciated. Let's make ScheduleMate better for students everywhere — together!

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| **HTML import fails** | Check that format matches the parser; update selectors in `timetable_parser.dart` if needed |
| **Notifications don't show** | Verify Android permissions are granted; check exact alarm support on device |
| **GPA calculation wrong** | Update grade scale constants in `lib/models/course.dart` |
| **App crashes on startup** | Run `flutter clean` then `flutter pub get` |
| **SQLite errors** | Clear app data via device settings and reinstall |

---

## 📜 License

Licensed under the **MIT License**.
See the [LICENSE](LICENSE) file for full details.

---

## ⚠️ Disclaimer

This application is intended for **personal academic use only**.
Timetable HTML parsing depends on the structure of your institution's faculty portal export. Parser compatibility may vary.

---

<p align="center">
<b>Made with ❤️ by <a href="https://github.com/TharushaAkash">TharushaAkash</a> and contributors</b>
</p>
