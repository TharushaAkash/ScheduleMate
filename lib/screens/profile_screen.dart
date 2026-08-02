import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/theme_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/gpa_provider.dart';
import '../services/backup_service.dart';
import '../services/database_helper.dart';
import '../services/report_service.dart';

/// -------------------------------------------------------------------------
/// Design tokens
/// -------------------------------------------------------------------------
class _Space {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
}

class _Radius {
  static const card = 28.0;
  static const chip = 14.0;
  static const pill = 100.0;
  static const button = 18.0;
}

/// Accent hues used to give each settings row its own identity instead of
/// repeating the same primary tint three times in a row.
class _Accent {
  static const theme = Color(0xFF7C6CFF);
  static const lock = Color(0xFF00C2A8);
  static const reminder = Color(0xFFFF9F43);
  static const backup = Color(0xFF4C8DFF);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _studentIdController = TextEditingController();
  final _studentNameController = TextEditingController();
  late AnimationController _animController;
  int _notificationTime = 30;
  bool _useBiometrics = true;
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _animController.forward();
    _loadProfileData();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _studentIdController.dispose();
    _studentNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentIdController.text = prefs.getString('student_id') ?? '';
      _studentNameController.text = prefs.getString('student_name') ?? '';
      _notificationTime = prefs.getInt('notification_time') ?? 30;
      _useBiometrics = prefs.getBool('use_biometrics') ?? false;
    });
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_id', _studentIdController.text.trim());
    await prefs.setString('student_name', _studentNameController.text.trim());
    await prefs.setInt('notification_time', _notificationTime);
    await prefs.setBool('use_biometrics', _useBiometrics);
    if (mounted) {
      Provider.of<TimetableProvider>(context, listen: false).scheduleReminders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Profile saved successfully!'),
            ],
          ),
          backgroundColor: const Color(0xFF00D4AA),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _getInitials() {
    final name = _studentNameController.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  static String _fmtTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _fmtNotificationTime(int minutes) => minutes >= 60 ? '1 hour before' : '$minutes min before';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final backupService = Provider.of<BackupService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07070C) : const Color(0xFFF6F5FB),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF12121C), const Color(0xFF07070C)]
                : [const Color(0xFFF2F1F9), const Color(0xFFE8E5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  _ProfileHeroBanner(isDark: isDark),
                  Padding(
                    padding: const EdgeInsets.only(top: 112), // 168 - 56 overlap
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _Space.lg),
                      child: _Reveal(
                        controller: _animController,
                        interval: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
                        child: _ProfileIdentityCard(
                          isDark: isDark,
                          primary: primary,
                          backupService: backupService,
                          initials: _getInitials(),
                          displayName: _studentNameController.text,
                          studentId: _studentIdController.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _Space.lg),
                      child: _Reveal(
                        controller: _animController,
                        interval: const Interval(0.1, 0.6, curve: Curves.easeOutCubic),
                        child: _QuickStatusRow(
                          isDark: isDark,
                          themeIsDark: themeProvider.isDarkMode,
                          appLockOn: _useBiometrics,
                          reminderLabel: _notificationTime >= 60 ? '1h' : '${_notificationTime}m',
                          backupSynced: backupService.isSignedIn,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _Space.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Reveal(
                            controller: _animController,
                            interval: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
                            child: const _SectionHeader(
                              eyebrow: 'ACCOUNT',
                              title: 'Personal Information',
                              icon: Icons.badge_rounded,
                            ),
                          ),
                    const SizedBox(height: _Space.md),
                    _Reveal(
                      controller: _animController,
                      interval: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
                      child: _ModernTextField(
                        controller: _studentNameController,
                        label: 'Full Name',
                        hint: 'e.g. John Doe',
                        icon: Icons.person_rounded,
                        accent: _Accent.theme,
                        isDark: isDark,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: _Space.md),
                    _Reveal(
                      controller: _animController,
                      interval: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
                      child: _ModernTextField(
                        controller: _studentIdController,
                        label: 'Student ID',
                        hint: 'e.g. IT 24 1011 10',
                        icon: Icons.fingerprint_rounded,
                        accent: _Accent.lock,
                        isDark: isDark,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: _Space.xl),
                    _Reveal(
                      controller: _animController,
                      interval: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
                      child: const _SectionHeader(
                        eyebrow: 'PREFERENCES',
                        title: 'App Settings',
                        icon: Icons.tune_rounded,
                      ),
                    ),
                    const SizedBox(height: _Space.md),
                    _Reveal(
                      controller: _animController,
                      interval: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
                      child: _GlassCard(
                        isDark: isDark,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          children: [
                            _SettingsTile(
                              isDark: isDark,
                              accent: _Accent.theme,
                              icon: themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              title: 'Dark Mode',
                              subtitle: themeProvider.isDarkMode ? 'Currently dark' : 'Currently light',
                              trailing: Switch.adaptive(
                                value: themeProvider.isDarkMode,
                                onChanged: (_) => themeProvider.toggleTheme(),
                                activeColor: _Accent.theme,
                              ),
                            ),
                            _SettingsDivider(isDark: isDark),
                            _SettingsTile(
                              isDark: isDark,
                              accent: _Accent.lock,
                              icon: Icons.fingerprint_rounded,
                              title: 'App Lock',
                              subtitle: 'Require authentication on startup',
                              trailing: Switch.adaptive(
                                value: _useBiometrics,
                                onChanged: (val) async {
                                  setState(() {
                                    _useBiometrics = val;
                                  });
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('use_biometrics', val);
                                },
                                activeColor: _Accent.lock,
                              ),
                            ),
                            _SettingsDivider(isDark: isDark),
                            _SettingsTile(
                              isDark: isDark,
                              accent: _Accent.reminder,
                              icon: Icons.access_time_rounded,
                              title: 'Remind me before',
                              subtitle: _fmtNotificationTime(_notificationTime),
                              trailing: _ReminderPicker(
                                isDark: isDark,
                                accent: _Accent.reminder,
                                value: _notificationTime,
                                onChanged: (val) => setState(() => _notificationTime = val),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: _Space.xl),
                    Consumer<BackupService>(
                      builder: (context, backupService, _) {
                        return _Reveal(
                          controller: _animController,
                          interval: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader(
                                eyebrow: 'SYNC',
                                title: 'Google Drive Backup',
                                icon: Icons.cloud_rounded,
                              ),
                              const SizedBox(height: _Space.md),
                              _GlassCard(
                                isDark: isDark,
                                child: !backupService.isSignedIn
                                    ? Column(
                                        children: [
                                          Icon(Icons.cloud_off_rounded, size: 34, color: (isDark ? Colors.white : Colors.black).withOpacity(0.25)),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Not connected',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Connect to back up and restore your data anytime.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.black45),
                                          ),
                                          const SizedBox(height: 18),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 52,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _showSignInInstructions(context, backupService),
                                              icon: Image.asset('assets/google_logo.png', height: 22),
                                              label: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w700)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                                                foregroundColor: isDark ? Colors.white : Colors.black87,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(_Radius.button),
                                                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: _Accent.backup, width: 2),
                                                ),
                                                child: CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor: _Accent.backup.withOpacity(0.12),
                                                  backgroundImage: backupService.currentUser?.photoUrl != null
                                                      ? NetworkImage(backupService.currentUser!.photoUrl!)
                                                      : null,
                                                  child: backupService.currentUser?.photoUrl == null
                                                      ? Icon(Icons.person_rounded, color: _Accent.backup)
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: _Space.md),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      backupService.currentUser?.displayName ?? 'Signed In',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      backupService.currentUser?.email ?? '',
                                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              InkWell(
                                                borderRadius: BorderRadius.circular(10),
                                                onTap: () async {
                                                  await backupService.signOut();
                                                  await DatabaseHelper.instance.clearRooms();
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Icon(Icons.logout_rounded, size: 19, color: Colors.redAccent.withOpacity(0.85)),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: _Space.lg),
                                          _SettingsDivider(isDark: isDark, inset: false),
                                          const SizedBox(height: _Space.lg),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _ActionButton(
                                                  isDark: isDark,
                                                  accent: _Accent.backup,
                                                  icon: Icons.cloud_upload_rounded,
                                                  label: 'Backup',
                                                  caption: _fmtTime(backupService.lastBackupTime),
                                                  onPressed: () async {
                                                    try {
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backing up to Drive...')));
                                                      await backupService.backupDatabase();
                                                      if (context.mounted) {
                                                        showDialog(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(24),
                                                              side: BorderSide(color: Colors.green.withOpacity(0.5), width: 1.5),
                                                            ),
                                                            title: Column(
                                                              children: [
                                                                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
                                                                const SizedBox(height: 16),
                                                                Text('Backup Successful', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                                                              ],
                                                            ),
                                                            content: Text(
                                                              'Your data has been securely backed up to Google Drive. You can restore it anytime.',
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
                                                            ),
                                                            actionsAlignment: MainAxisAlignment.center,
                                                            actions: [
                                                              ElevatedButton(
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: Colors.green,
                                                                  foregroundColor: Colors.white,
                                                                  elevation: 0,
                                                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                ),
                                                                onPressed: () => Navigator.pop(ctx),
                                                                child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                          content: Text('Backup Failed: $e'),
                                                          backgroundColor: Colors.red,
                                                        ));
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: _Space.sm + 2),
                                              Expanded(
                                                child: _ActionButton(
                                                  isDark: isDark,
                                                  accent: _Accent.backup,
                                                  icon: Icons.cloud_download_rounded,
                                                  label: 'Restore',
                                                  caption: _fmtTime(backupService.lastRestoreTime),
                                                  onPressed: () async {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (c) => AlertDialog(
                                                        backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                        title: const Text('Restore Backup'),
                                                        content: const Text('This will overwrite all local data with the cloud backup. Do you want to continue?'),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(c, true),
                                                            child: const Text('Restore', style: TextStyle(color: Colors.redAccent)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true) {
                                                      try {
                                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restoring from Drive...')));
                                                        await backupService.restoreDatabase();
                                                        if (context.mounted) {
                                                          Provider.of<GpaProvider>(context, listen: false).loadSemesters();
                                                          Provider.of<TimetableProvider>(context, listen: false).loadDefaultTimetable();
                                                          _loadProfileData();
                                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                                            content: Text('Restore Successful!'),
                                                          ));
                                                        }
                                                      } catch (e) {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                            content: Text('Restore Failed: $e'),
                                                            backgroundColor: Colors.red,
                                                          ));
                                                        }
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: _Space.xl),
                    _Reveal(
                      controller: _animController,
                      interval: const Interval(0.45, 0.95, curve: Curves.easeOutCubic),
                      child: Consumer<GpaProvider>(
                        builder: (context, gpaProvider, _) {
                          return Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _PrimaryButton(
                                  label: 'Save Profile',
                                  icon: Icons.save_rounded,
                                  backgroundColor: primary,
                                  onPressed: _saveProfileData,
                                ),
                              ),
                              const SizedBox(width: _Space.sm + 2),
                              Expanded(
                                flex: 2,
                                child: _PrimaryButton(
                                  label: 'Result Sheet',
                                  icon: Icons.download_rounded,
                                  backgroundColor: const Color(0xFF00D4AA),
                                  outlined: true,
                                  onPressed: gpaProvider.semesters.isEmpty
                                      ? null
                                      : () => ReportService.generateAndDownloadResultSheet(
                                            context: context,
                                            studentName: _studentNameController.text.trim(),
                                            studentId: _studentIdController.text.trim(),
                                            semesters: gpaProvider.semesters,
                                            cumulativeGpa: gpaProvider.cumulativeGpa,
                                          ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: _Space.xxl),
                    _Reveal(
                      controller: _animController,
                      interval: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
                      child: const _SectionHeader(
                        eyebrow: 'INFO',
                        title: 'About ScheduleMate',
                        icon: Icons.info_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: _Space.md),
                    _Reveal(
                      controller: _animController,
                      interval: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
                      child: _GlassCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primary, primary.withOpacity(0.6)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [BoxShadow(color: primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
                                  ),
                                  child: const Icon(Icons.calendar_month_rounded, size: 28, color: Colors.white),
                                ),
                                const SizedBox(width: _Space.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ScheduleMate',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(_Radius.pill),
                                        ),
                                        child: Text(
                                          'v$_appVersion',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: _Space.lg),
                            Text(
                              'A smart and beautiful way to manage your university timetable and track your GPA effortlessly. Built with ❤️ for students.',
                              style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white70 : Colors.black87, height: 1.55),
                            ),
                            const SizedBox(height: _Space.lg),
                            _SettingsDivider(isDark: isDark, inset: false),
                            const SizedBox(height: _Space.md),
                            Row(
                              children: [
                                Icon(Icons.developer_mode_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                                const SizedBox(width: _Space.sm),
                                Text(
                                  'Developed by',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45),
                                ),
                                const Spacer(),
                                Text('Tharusha Akash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primary)),
                              ],
                            ),
                            const SizedBox(height: _Space.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: _IconTextButton(
                                    isDark: isDark,
                                    icon: Icons.copy_rounded,
                                    label: 'Copy Link',
                                    filled: false,
                                    onPressed: () {
                                      Clipboard.setData(const ClipboardData(text: 'https://sourceforge.net/projects/schedulemate/'));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Row(
                                            children: [
                                              Icon(Icons.check_circle_rounded, color: Colors.white),
                                              SizedBox(width: 8),
                                              Text('Link copied!'),
                                            ],
                                          ),
                                          backgroundColor: primary,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: _Space.sm + 2),
                                Expanded(
                                  child: _IconTextButton(
                                    isDark: isDark,
                                    icon: Icons.ios_share_rounded,
                                    label: 'Share',
                                    filled: true,
                                    color: primary,
                                    onPressed: () {
                                      Share.share('Check out ScheduleMate! Manage your timetable and track your GPA easily: https://sourceforge.net/projects/schedulemate/');
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: _Space.xxl),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
  }

  Future<void> _showSignInInstructions(BuildContext context, BackupService backupService) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.security_rounded, color: Colors.green, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Important Notice',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To use the cloud backup and rooms features properly, you MUST grant Google Drive permissions.',
              style: TextStyle(fontSize: 14, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '⚠️ When the Google permission screen appears, please ensure you check ALL the boxes (Select All).',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Why?',
              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'The app needs permission to create a specific folder in your Drive to save backups and manage class rooms. It will only access files it creates, not your personal files.',
              style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white54 : Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      try {
        await backupService.signIn();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-in failed: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    }
  }
}

/// -------------------------------------------------------------------------
/// Fades + slides a child in on a slice of a shared AnimationController,
/// giving each section its own staggered entrance instead of one flat fade.
/// -------------------------------------------------------------------------
class _Reveal extends StatelessWidget {
  final AnimationController controller;
  final Interval interval;
  final Widget child;

  const _Reveal({required this.controller, required this.interval, required this.child});

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: controller, curve: interval);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        return Opacity(
          opacity: curved.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// -------------------------------------------------------------------------
/// Short gradient banner behind the floating identity card.
/// -------------------------------------------------------------------------
class _ProfileHeroBanner extends StatelessWidget {
  final bool isDark;
  const _ProfileHeroBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Container(
      height: 168 + topPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF32206E), const Color(0xFF1B1B2A)]
              : [const Color(0xFF6C63FF), const Color(0xFFA79CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30 + topPadding,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07)),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -30,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
            ),
          ),
          const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 12, left: 20),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'Profile',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating card that overlaps the banner — avatar, name and id together.
class _ProfileIdentityCard extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final BackupService backupService;
  final String initials;
  final String displayName;
  final String studentId;

  const _ProfileIdentityCard({
    required this.isDark,
    required this.primary,
    required this.backupService,
    required this.initials,
    required this.displayName,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = backupService.isSignedIn && backupService.currentUser?.photoUrl != null;
    final name = backupService.isSignedIn && backupService.currentUser?.displayName != null
        ? backupService.currentUser!.displayName!
        : (displayName.isNotEmpty ? displayName : 'Your Profile');

    return _GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [primary, primary.withOpacity(0.4)]),
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.12),
                image: hasPhoto
                    ? DecorationImage(image: NetworkImage(backupService.currentUser!.photoUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: hasPhoto
                  ? null
                  : Center(
                      child: Text(
                        initials,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: _Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (studentId.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(_Radius.pill),
                    ),
                    child: Text(
                      studentId,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: primary),
                    ),
                  )
                else
                  Text(
                    'Add your student ID below',
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.black38),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of small at-a-glance status chips (purely presentational).
class _QuickStatusRow extends StatelessWidget {
  final bool isDark;
  final bool themeIsDark;
  final bool appLockOn;
  final String reminderLabel;
  final bool backupSynced;

  const _QuickStatusRow({
    required this.isDark,
    required this.themeIsDark,
    required this.appLockOn,
    required this.reminderLabel,
    required this.backupSynced,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _Space.sm),
      child: Row(
        children: [
          Expanded(
            child: _StatusChip(
              isDark: isDark,
              accent: _Accent.theme,
              icon: themeIsDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              label: themeIsDark ? 'Dark' : 'Light',
            ),
          ),
          const SizedBox(width: _Space.sm),
          Expanded(
            child: _StatusChip(
              isDark: isDark,
              accent: _Accent.lock,
              icon: Icons.fingerprint_rounded,
              label: appLockOn ? 'Locked' : 'Unlocked',
            ),
          ),
          const SizedBox(width: _Space.sm),
          Expanded(
            child: _StatusChip(
              isDark: isDark,
              accent: _Accent.reminder,
              icon: Icons.access_time_rounded,
              label: reminderLabel,
            ),
          ),
          const SizedBox(width: _Space.sm),
          Expanded(
            child: _StatusChip(
              isDark: isDark,
              accent: _Accent.backup,
              icon: backupSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              label: backupSynced ? 'Synced' : 'Offline',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final IconData icon;
  final String label;

  const _StatusChip({required this.isDark, required this.accent, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF161622) : Colors.white).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Shared glass-morphism card shell
/// -------------------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({required this.isDark, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_Radius.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF161622) : Colors.white).withOpacity(0.85),
            borderRadius: BorderRadius.circular(_Radius.card),
            border: Border.all(color: Colors.white.withOpacity(isDark ? 0.1 : 0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.35 : 0.06), blurRadius: 30, offset: const Offset(0, 12)),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Settings row with a color-coded icon badge so each row reads distinctly.
class _SettingsTile extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.isDark,
    required this.accent,
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: _Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: isDark ? Colors.white : Colors.black87)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black38)),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  final bool isDark;
  final bool inset;
  const _SettingsDivider({required this.isDark, this.inset = true});

  @override
  Widget build(BuildContext context) {
    return Divider(color: Colors.grey.withOpacity(isDark ? 0.13 : 0.18), height: 1);
  }
}

/// Pill-styled dropdown for the reminder-time setting.
class _ReminderPicker extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final int value;
  final ValueChanged<int> onChanged;

  const _ReminderPicker({required this.isDark, required this.accent, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_Radius.pill),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF252535) : Colors.white,
          borderRadius: BorderRadius.circular(_Radius.chip),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
          icon: Icon(Icons.expand_more_rounded, color: accent, size: 18),
          items: const [
            DropdownMenuItem(value: 5, child: Text('5 min')),
            DropdownMenuItem(value: 15, child: Text('15 min')),
            DropdownMenuItem(value: 30, child: Text('30 min')),
            DropdownMenuItem(value: 45, child: Text('45 min')),
            DropdownMenuItem(value: 60, child: Text('1 hour')),
          ],
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

/// Backup / Restore square action button with a caption underneath.
class _ActionButton extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.isDark,
    required this.accent,
    required this.icon,
    required this.label,
    required this.caption,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: accent.withOpacity(isDark ? 0.14 : 0.09),
        foregroundColor: accent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_Radius.chip),
          side: BorderSide(color: accent.withOpacity(0.25)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 5),
          Text(caption, style: TextStyle(fontSize: 10, color: accent.withOpacity(0.7))),
        ],
      ),
    );
  }
}

/// Full-width primary call-to-action button.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback? onPressed;
  final bool outlined;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          label: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: backgroundColor,
            disabledForegroundColor: Colors.grey,
            side: BorderSide(color: onPressed == null ? Colors.grey.shade300 : backgroundColor.withOpacity(0.4), width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_Radius.button)),
          ),
        ),
      );
    }
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_Radius.button)),
        ),
      ),
    );
  }
}

/// Small icon+label button used in the About card (filled or outline).
class _IconTextButton extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final bool filled;
  final Color? color;
  final VoidCallback onPressed;

  const _IconTextButton({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_Radius.chip)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : Colors.black87,
        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_Radius.chip)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final IconData icon;

  const _SectionHeader({required this.eyebrow, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: primary.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(icon, size: 19, color: isDark ? Colors.white : Colors.black87),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accent;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accent,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B27) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
        cursorColor: accent,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black45),
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accent, size: 18),
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: accent.withOpacity(0.6), width: 1.4),
          ),
        ),
      ),
    );
  }
}