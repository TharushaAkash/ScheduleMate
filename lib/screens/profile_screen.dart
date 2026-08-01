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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _studentIdController = TextEditingController();
  final _studentNameController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _slideAnim;
  int _notificationTime = 30;
  bool _useBiometrics = true;
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final backupService = Provider.of<BackupService>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF252535) : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2D1B69), const Color(0xFF1E1E2E)]
                        : [const Color(0xFF6C63FF), const Color(0xFF9C96FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                          image: backupService.isSignedIn && backupService.currentUser?.photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(backupService.currentUser!.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: backupService.isSignedIn && backupService.currentUser?.photoUrl != null
                            ? null
                            : Center(
                                child: Text(
                                  _getInitials(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        backupService.isSignedIn && backupService.currentUser?.displayName != null
                            ? backupService.currentUser!.displayName!
                            : (_studentNameController.text.isNotEmpty ? _studentNameController.text : 'Your Profile'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_studentIdController.text.isNotEmpty)
                        Text(
                          _studentIdController.text,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(_slideAnim),
              child: FadeTransition(
                opacity: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(title: 'Personal Information', icon: Icons.person_rounded),
                      const SizedBox(height: 16),
                      _ModernTextField(
                        controller: _studentNameController,
                        label: 'Full Name',
                        hint: 'e.g. John Doe',
                        icon: Icons.badge_rounded,
                        isDark: isDark,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _ModernTextField(
                        controller: _studentIdController,
                        label: 'Student ID',
                        hint: 'e.g. IT 24 1011 10',
                        icon: Icons.fingerprint_rounded,
                        isDark: isDark,
                        onChanged: (_) => setState(() {}),
                      ),

                      const SizedBox(height: 32),
                      _SectionHeader(title: 'App Settings', icon: Icons.settings_rounded),
                      const SizedBox(height: 16),
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) {
                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF252535) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            themeProvider.isDarkMode
                                                ? Icons.dark_mode_rounded
                                                : Icons.light_mode_rounded,
                                            color: primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Dark Mode',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                themeProvider.isDarkMode ? 'Currently dark' : 'Currently light',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white54 : Colors.black38,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch.adaptive(
                                          value: themeProvider.isDarkMode,
                                          onChanged: (_) => themeProvider.toggleTheme(),
                                          activeColor: primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Divider(color: Colors.grey.withOpacity(0.2), height: 1),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.fingerprint_rounded,
                                            color: primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'App Lock',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                'Require authentication on startup',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white54 : Colors.black38,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch.adaptive(
                                          value: _useBiometrics,
                                          onChanged: (val) async {
                                            setState(() {
                                              _useBiometrics = val;
                                            });
                                            final prefs = await SharedPreferences.getInstance();
                                            await prefs.setBool('use_biometrics', val);
                                          },
                                          activeColor: primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Divider(color: Colors.grey.withOpacity(0.2), height: 1),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.access_time_rounded,
                                            color: primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            'Remind me before',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _notificationTime,
                                            dropdownColor: isDark ? const Color(0xFF252535) : Colors.white,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                            icon: Icon(Icons.arrow_drop_down_rounded, color: primary),
                                            items: const [
                                              DropdownMenuItem(value: 5, child: Text('5 min')),
                                              DropdownMenuItem(value: 15, child: Text('15 min')),
                                              DropdownMenuItem(value: 30, child: Text('30 min')),
                                              DropdownMenuItem(value: 45, child: Text('45 min')),
                                              DropdownMenuItem(value: 60, child: Text('1 hour')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _notificationTime = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      Consumer<BackupService>(
                        builder: (context, backupService, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader(title: 'Google Drive Backup', icon: Icons.cloud_done_rounded),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF252535) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    if (!backupService.isSignedIn)
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showSignInInstructions(context, backupService),
                                          icon: Image.asset('assets/google_logo.png', height: 24),
                                          label: const Text('Sign in with Google'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black87,
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      )
                                    else
                                      Column(
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 24,
                                                backgroundImage: backupService.currentUser?.photoUrl != null
                                                    ? NetworkImage(backupService.currentUser!.photoUrl!)
                                                    : null,
                                                child: backupService.currentUser?.photoUrl == null
                                                    ? const Icon(Icons.person)
                                                    : null,
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      backupService.currentUser?.displayName ?? 'Signed In',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                    Text(
                                                      backupService.currentUser?.email ?? '',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: isDark ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                                                onPressed: () async {
                                                  await backupService.signOut();
                                                  await DatabaseHelper.instance.clearRooms();
                                                },
                                                tooltip: 'Sign Out',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () async {
                                                    try {
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backing up to Drive...')));
                                                      await backupService.backupDatabase();
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                                        content: Text('Backup Successful!'),
                                                        backgroundColor: Colors.green,
                                                      ));
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                        content: Text('Backup Failed: $e'),
                                                        backgroundColor: Colors.red,
                                                      ));
                                                    }
                                                  },
                                                  icon: const Icon(Icons.cloud_upload_rounded),
                                                  label: const Text('Backup'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: isDark ? const Color(0xFF333344) : Colors.grey[200],
                                                    foregroundColor: isDark ? Colors.white : Colors.black87,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () async {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (c) => AlertDialog(
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
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restoring from Drive...')));
                                                        await backupService.restoreDatabase();
                                                        Provider.of<GpaProvider>(context, listen: false).loadSemesters();
                                                        Provider.of<TimetableProvider>(context, listen: false).loadDefaultTimetable();
                                                        _loadProfileData();
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                                          content: Text('Restore Successful!'),
                                                          backgroundColor: Colors.green,
                                                        ));
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                          content: Text('Restore Failed: $e'),
                                                          backgroundColor: Colors.red,
                                                        ));
                                                      }
                                                    }
                                                  },
                                                  icon: const Icon(Icons.cloud_download_rounded),
                                                  label: const Text('Restore'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: isDark ? const Color(0xFF333344) : Colors.grey[200],
                                                    foregroundColor: isDark ? Colors.white : Colors.black87,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Download Result Sheet
                      Consumer<GpaProvider>(
                        builder: (context, gpaProvider, _) {
                          return SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: gpaProvider.semesters.isEmpty
                                  ? null
                                  : () => ReportService.generateAndDownloadResultSheet(
                                        context: context,
                                        studentName: _studentNameController.text.trim(),
                                        studentId: _studentIdController.text.trim(),
                                        semesters: gpaProvider.semesters,
                                        cumulativeGpa: gpaProvider.cumulativeGpa,
                                      ),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text(
                                'Download Result Sheet',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00D4AA),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _saveProfileData,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text(
                            'Save Profile',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _SectionHeader(title: 'About ScheduleMate', icon: Icons.info_outline_rounded),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF252535) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(Icons.calendar_month_rounded, size: 32, color: primary),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ScheduleMate',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        'Version $_appVersion',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'A smart and beautiful way to manage your university timetable and track your GPA effortlessly. Built with ❤️ for students.',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Divider(color: Colors.grey.withOpacity(0.2), height: 1),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Icon(Icons.developer_mode_rounded, size: 20, color: primary),
                                const SizedBox(width: 12),
                                Text(
                                  'Developer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Tharusha Akash',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
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
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    label: const Text('Copy Link'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? const Color(0xFF333344) : Colors.grey[200],
                                      foregroundColor: isDark ? Colors.white : Colors.black87,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Share.share('Check out ScheduleMate! Manage your timetable and track your GPA easily: https://sourceforge.net/projects/schedulemate/');
                                    },
                                    icon: const Icon(Icons.share_rounded, size: 18),
                                    label: const Text('Share'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _showSignInInstructions(BuildContext context, BackupService backupService) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF252535) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Colors.green),
            const SizedBox(width: 10),
            Text('Important Notice', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To use the cloud backup and rooms features properly, you MUST grant Google Drive permissions.',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '⚠️ When the Google permission screen appears, please ensure you check ALL the boxes (Select All).',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Why?',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'The app needs permission to create a specific folder in your Drive to save backups and manage class rooms. It will only access files it creates, not your personal files.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
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
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252535) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primary, size: 18),
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
