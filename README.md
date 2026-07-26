# <img src="android/app/src/main/res/mipmap-hdpi/ic_launcher.png" width="50" height="50" alt="ScheduleMate Icon"> ScheduleMate

> A powerful Flutter app designed to help students manage their academic life with ease.

<div align="center">

[![Download ScheduleMate](https://a.fsdn.com/con/app/sf-download-button)](https://sourceforge.net/projects/schedulemate/files/latest/download)
<br>
[![Download ScheduleMate](https://img.shields.io/sourceforge/dt/schedulemate.svg)](https://sourceforge.net/projects/schedulemate/files/latest/download)

<br>

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=for-the-badge)

[Features](#-features) • [Installation](#-installation) • [Documentation](#-documentation) • [Contributing](#-contributing)

</div>

---

## 🌟 About ScheduleMate

ScheduleMate is your personal academic companion. Manage GPA calculations, organize timetables, and never miss a class with intelligent reminders—all in one intuitive app.

Perfect for students who want to:
- 📊 Track grades and calculate GPA automatically
- 📅 Import timetables from faculty HTML exports
- 🔔 Receive smart class reminders
- 💾 Access everything offline

---

## 📸 Screenshots

<div align="center">
  <img src="ss/Screenshot%202026-07-20%20162141.png" width="220" />
  <img src="ss/Screenshot%202026-07-20%20162219.png" width="220" />
  <img src="ss/Screenshot%202026-07-20%20162236.png" width="220" />
  <img src="ss/Screenshot%202026-07-20%20162254.png" width="220" />
  <img src="ss/Screenshot%202026-07-26%20092129.png" width="220" />
</div>

---

## ✨ Key Features

<table>
<tr>
<td width="50%">

### 📊 GPA Calculator
- Real-time semester GPA calculation
- Cumulative GPA tracking
- Customizable grade point scale
- Visual grade analytics

### 📅 Smart Timetable
- Import from HTML exports
- Automatic schedule parsing
- Organized by day/week
- Easy course management

</td>
<td width="50%">

### 🔔 Notifications
- Weekly class reminders
- Customizable lead times
- Android 12+ support
- Smart notification management

### 💾 Offline First
- SQLite local storage
- No internet required
- Fast performance
- Reliable data persistence

</td>
</tr>
</table>

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter + Dart |
| **UI Design** | Material 3 |
| **State Management** | Provider |
| **Database** | SQLite (`sqflite`) |
| **Parsing** | HTML (`package:html`) |
| **Notifications** | Flutter Local Notifications |

---

## 📦 Installation

### Prerequisites
```bash
Flutter SDK (latest)
Dart SDK
Android Studio / Xcode
```

### Quick Setup

**1️⃣ Clone Repository**
```bash
git clone https://github.com/TharushaAkash/ScheduleMate.git
cd ScheduleMate
```

**2️⃣ Install Dependencies**
```bash
flutter pub get
```

**3️⃣ Generate Native Folders (if needed)**
```bash
flutter create --project-name schedulemate . --overwrite
flutter pub get
```

**4️⃣ Run Application**
```bash
flutter run
```

### Android Configuration

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

---

## 📂 Project Structure

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
│   └── app/src/main/res/
│       ├── mipmap-hdpi/
│       ├── mipmap-mdpi/
│       ├── mipmap-xhdpi/
│       ├── mipmap-xxhdpi/
│       └── mipmap-xxxhdpi/
├── ios/
└── pubspec.yaml
```

---

## 🚀 Quick Start

### Step 1: Create Semester
```
Tap "Add Semester" → Enter Name, Year, Date
```

### Step 2: Add Courses
```
Input Course Name → Credit Hours → Grade
Watch GPA calculate automatically ✨
```

### Step 3: Import Timetable
```
Export HTML from Faculty Portal → Upload in App
Select Year/Semester/Group
```

### Step 4: Enable Reminders
```
Toggle Notifications → Get Weekly Class Reminders 🔔
```

---

## 📖 Documentation

### Timetable Parser

Supports two HTML formats:
- ✅ Flat tables with header rows
- ✅ Grid-style schedules (weekday × time)

**Custom Format?**
1. Inspect exported HTML structure
2. Update selectors in `lib/services/timetable_parser.dart`
3. Test with your export

### Customization Guide

**Grade Point Scale**
```dart
// lib/models/course.dart
const gradeScale = {
  'A': 4.0,
  'A-': 3.7,
  'B+': 3.3,
  // ... customize as needed
};
```

**Notification Lead Time**
```dart
// lib/services/notification_service.dart
const reminderMinutesBefore = 15; // Adjust timing
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| **HTML import fails** | Check format matches parser; update selectors if needed |
| **Notifications don't show** | Verify Android permissions; check alarm support |
| **GPA calculation wrong** | Update grade scale in `course.dart` |
| **App crashes on startup** | Run `flutter clean` then `flutter pub get` |
| **SQLite errors** | Delete app data and reinstall |

---

## 🚧 Roadmap

- [ ] ✏️ Edit/Delete semesters and courses
- [ ] ⏰ Customizable reminder lead times
- [ ] 💾 Auto-backup timetable cache
- [ ] 🎯 Multiple parser profiles per institution
- [ ] 📊 GPA trend analytics & charts
- [ ] 🌙 Dark mode support
- [ ] 🌍 Multi-language support (Sinhala, Tamil, etc.)
- [ ] 📤 Export GPA transcript

---

## 🤝 Contributing

Contributions are welcome! Follow these steps:

```bash
# 1. Fork the repository
git clone https://github.com/YOUR-USERNAME/ScheduleMate.git

# 2. Create feature branch
git checkout -b feature/amazing-feature

# 3. Make changes and commit
git commit -m "Add amazing feature"

# 4. Push to branch
git push origin feature/amazing-feature

# 5. Open Pull Request
```

**Guidelines:**
- Follow Dart style guide
- Add tests for new features
- Include sanitized HTML examples for parser updates
- Write clear commit messages

---

## 📝 Code Style

```dart
// Use meaningful variable names
final gpaCalculator = GPACalculator();

// Proper async/await
Future<void> importTimetable() async {
  final result = await parser.parse(htmlContent);
  // ...
}

// Null safety
String? courseCode;
```

---

## 📄 License

This project is licensed under the **MIT License** - see [LICENSE](LICENSE) file for details.

---

## 💬 Support

Have questions? We're here to help!

- 📬 **Issues:** [GitHub Issues](https://github.com/TharushaAkash/ScheduleMate/issues)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/TharushaAkash/ScheduleMate/discussions)
- 📧 **Email:** tharushaakasha22@gmail.com

---

## 🙏 Acknowledgments

- Flutter & Dart community
- Material Design guidelines
- All contributors and users

---

<div align="center">

**Made with ❤️ for students, by students**

⭐ If you find this helpful, please star the repository!

[⬆ Back to top](#-schedulemate)

</div>