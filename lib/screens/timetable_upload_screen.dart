import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_screen.dart';
import '../providers/timetable_provider.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import 'timetable_view_screen.dart';
import 'exam_entry_dialog.dart';
import 'exam_type_screen.dart';


class TimetableUploadScreen extends StatefulWidget {
  const TimetableUploadScreen({super.key});

  @override
  State<TimetableUploadScreen> createState() => _TimetableUploadScreenState();
}

class _TimetableUploadScreenState extends State<TimetableUploadScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _fileName;
  String? _selectedSemester;
  String? _selectedGroup;
  String? _selectedSubGroup;

  List<Map<String, String>> _savedProfiles = [];
  String? _notifiedId;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadSavedProfiles();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfiles() async {
    final profiles = await DatabaseHelper.instance.getSavedTimetableProfiles();
    final prefs = await SharedPreferences.getInstance();
    final semester = prefs.getString('notified_semester');
    final group = prefs.getString('notified_group');
    final subGroup = prefs.getString('notified_subgroup');
    final notifiedId = (semester != null && group != null && subGroup != null)
        ? '${semester}_${group}_${subGroup}'
        : null;
    if (mounted) {
      setState(() {
        _savedProfiles = profiles;
        _notifiedId = notifiedId;
      });
    }
  }

  Future<void> _pickFile() async {
    AuthScreen.bypassNextLifecycleLock = true;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _loading = true);
    final bytes = result.files.single.bytes!;
    final htmlContent = utf8.decode(bytes, allowMalformed: true);

    if (!mounted) return;
    await context.read<TimetableProvider>().loadFromHtml(htmlContent);

    setState(() {
      _fileName = result.files.single.name;
      _selectedSemester = null;
      _selectedGroup = null;
      _selectedSubGroup = null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 140,
              backgroundColor: isDark ? const Color(0xFF252535) : Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Timetable',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF2D1B69), const Color(0xFF252535)]
                          : [const Color(0xFF6C63FF), const Color(0xFFB8B5FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Class timetable'),
                  Tab(text: 'Exam time table'),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _buildClassTab(context, isDark, primary, provider),
              _buildExamTab(context, isDark, primary, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassTab(BuildContext context, bool isDark, Color primary,
      TimetableProvider provider) {
    return SingleChildScrollView(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Upload Card
              _buildUploadCard(isDark, primary),
              const SizedBox(height: 24),

              if (_loading)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      CircularProgressIndicator(color: primary),
                      const SizedBox(height: 12),
                      Text('Parsing timetable...',
                          style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54)),
                    ],
                  ),
                ),

              if (!_loading && provider.hasParsedData) ...[
                const _SectionLabel(label: 'Configure Your Timetable'),
                const SizedBox(height: 16),
                _ModernDropdown(
                  label: 'Semester',
                  icon: Icons.school_rounded,
                  value: _selectedSemester,
                  items: provider.availableSemesters,
                  isDark: isDark,
                  onChanged: (v) => setState(() {
                    _selectedSemester = v;
                    _selectedGroup = null;
                    _selectedSubGroup = null;
                  }),
                ),
                if (_selectedSemester != null) ...[
                  const SizedBox(height: 16),
                  _ModernDropdown(
                    label: 'Group',
                    icon: Icons.group_rounded,
                    value: _selectedGroup,
                    items: provider.getAvailableGroups(_selectedSemester!),
                    isDark: isDark,
                    onChanged: (v) => setState(() {
                      _selectedGroup = v;
                      _selectedSubGroup = null;
                    }),
                  ),
                ],
                if (_selectedGroup != null) ...[
                  const SizedBox(height: 16),
                  _ModernDropdown(
                    label: 'Sub Group',
                    icon: Icons.people_rounded,
                    value: _selectedSubGroup,
                    items: provider.getAvailableSubGroups(
                        _selectedSemester!, _selectedGroup!),
                    isDark: isDark,
                    onChanged: (v) => setState(() => _selectedSubGroup = v),
                  ),
                  const SizedBox(height: 24),
                ],
                AnimatedOpacity(
                  opacity: _selectedSubGroup != null ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 300),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _selectedSubGroup == null
                          ? null
                          : () async {
                              await context
                                  .read<TimetableProvider>()
                                  .selectTimetable(_selectedSemester!,
                                      _selectedGroup!, _selectedSubGroup!);
                              await context
                                  .read<TimetableProvider>()
                                  .scheduleReminders();
                              if (!mounted) return;
                              await _loadSavedProfiles();
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const TimetableViewScreen()));
                            },
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: const Text(
                        'Build My Timetable',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
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
                ),
              ],

              if (_savedProfiles.isNotEmpty) ...[
                const SizedBox(height: 36),
                const _SectionLabel(label: 'Saved Timetables'),
                const SizedBox(height: 16),
                ..._savedProfiles.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  final currentId =
                      '${p['semester']}_${p['groupName']}_${p['subGroup']}';
                  return _SavedTimetableCard(
                    profile: p,
                    index: i,
                    isDark: isDark,
                    isNotified: _notifiedId == currentId,
                    onToggleNotification: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final isCurrentlyNotified = _notifiedId == currentId;
                      if (isCurrentlyNotified) {
                        await prefs.remove('notified_semester');
                        await prefs.remove('notified_group');
                        await prefs.remove('notified_subgroup');
                        await NotificationService.instance.cancelAll();
                        if (context.mounted) {
                          await context
                              .read<TimetableProvider>()
                              .loadNotifiedTimetable();
                        }
                        setState(() => _notifiedId = null);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.notifications_off_rounded,
                                    color: Colors.white),
                                SizedBox(width: 8),
                                Text('Notifications disabled.'),
                              ],
                            ),
                            backgroundColor: Colors.grey.shade800,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                          ));
                        }
                      } else {
                        await prefs.setString(
                            'notified_semester', p['semester']!);
                        await prefs.setString(
                            'notified_group', p['groupName']!);
                        await prefs.setString(
                            'notified_subgroup', p['subGroup']!);
                        if (context.mounted) {
                          await context
                              .read<TimetableProvider>()
                              .loadSavedTimetable(p['semester']!,
                                  p['groupName']!, p['subGroup']!);
                          await context
                              .read<TimetableProvider>()
                              .loadNotifiedTimetable();
                        }
                        // scheduleReminders() now returns exact alarm times
                        final summary = context.mounted
                            ? await context
                                .read<TimetableProvider>()
                                .scheduleReminders()
                            : null;
                        setState(() => _notifiedId = currentId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.alarm_on_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    summary ?? 'Notifications enabled!',
                                    style: const TextStyle(
                                        fontSize: 12, height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF6C63FF),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 6),
                          ));
                        }
                      }
                    },
                    onTap: () async {
                      await context
                          .read<TimetableProvider>()
                          .loadSavedTimetable(
                              p['semester']!, p['groupName']!, p['subGroup']!);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TimetableViewScreen()),
                      );
                    },
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: const Text('Delete Timetable'),
                          content: const Text(
                              'Are you sure you want to delete this saved timetable?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final prefs = await SharedPreferences.getInstance();
                        final notifiedSem =
                            prefs.getString('notified_semester');
                        final notifiedGrp = prefs.getString('notified_group');
                        if (notifiedSem == p['semester'] &&
                            notifiedGrp == p['groupName']) {
                          await prefs.remove('notified_semester');
                          await prefs.remove('notified_group');
                          await prefs.remove('notified_subgroup');
                          await NotificationService.instance.cancelAll();
                        }
                        await DatabaseHelper.instance.deleteTimetableProfile(
                            p['semester']!, p['groupName']!);
                        if (context.mounted) {
                          await context
                              .read<TimetableProvider>()
                              .loadNotifiedTimetable();
                        }
                        _loadSavedProfiles();
                      }
                    },
                  );
                }).toList(),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamTab(BuildContext context, bool isDark, Color primary,
      TimetableProvider provider) {
    // Group exams by type
    final Map<String, List<dynamic>> groupedExams = {};
    for (var exam in provider.examTimetable) {
      final type = exam.examType;
      groupedExams.putIfAbsent(type, () => []).add(exam);
    }

    return Stack(
      children: [
        if (provider.examTimetable.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy_rounded,
                    size: 64, color: isDark ? Colors.white24 : Colors.black12),
                const SizedBox(height: 16),
                Text('No exams added yet',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ExamEntryDialog(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Exam'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                )
              ],
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.all(20).copyWith(bottom: 100),
            itemCount: groupedExams.length,
            itemBuilder: (context, index) {
              final type = groupedExams.keys.elementAt(index);
              final exams = groupedExams[type]!;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExamTypeScreen(examType: type),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252535) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: primary.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.folder_shared_rounded, color: primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${exams.length} Exam${exams.length == 1 ? '' : 's'} Scheduled',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: primary, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        if (provider.examTimetable.isNotEmpty)
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const ExamEntryDialog(),
                );
              },
              backgroundColor: primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Exam',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadCard(bool isDark, Color primary) {
    return GestureDetector(
      onTap: _loading ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252535) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _fileName != null
                ? primary.withOpacity(0.5)
                : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.upload_file_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName ?? 'Upload Timetable',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fileName != null
                        ? 'Tap to change the file'
                        : 'Choose your HTML timetable file',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _fileName != null
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: _fileName != null ? const Color(0xFF00D4AA) : Colors.grey,
              size: _fileName != null ? 24 : 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _ModernDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _ModernDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.isDark,
    required this.onChanged,
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
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: isDark ? const Color(0xFF252535) : Colors.white,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
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
        items: items
            .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SavedTimetableCard extends StatelessWidget {
  final Map<String, String> profile;
  final int index;
  final bool isDark;
  final bool isNotified;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleNotification;

  const _SavedTimetableCard({
    required this.profile,
    required this.index,
    required this.isDark,
    required this.isNotified,
    required this.onTap,
    required this.onDelete,
    required this.onToggleNotification,
  });

  static const _colors = [
    Color(0xFF6C63FF),
    Color(0xFF00D4AA),
    Color(0xFFFF6B9D),
    Color(0xFFFFB347),
    Color(0xFF4ECDC4),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.schedule_rounded, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${profile['semester']} — ${profile['groupName']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile['subGroup'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isNotified
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    color: isNotified
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.white38 : Colors.black38),
                    size: 22,
                  ),
                  onPressed: onToggleNotification,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 22),
                  onPressed: onDelete,
                ),
                Icon(Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
