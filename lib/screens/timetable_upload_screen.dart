import 'dart:convert';
import 'dart:ui';

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

// ---------------------------------------------------------------------------
// Shared design tokens
// ---------------------------------------------------------------------------
class _Palette {
  static const bgDark = Color(0xFF0F1028);
  static const bgLight = Color(0xFFF8F9FE);
  static const primary = Color(0xFF7C5CFF);
  static const secondary = Color(0xFF5B8CFF);
  static const accent = Color(0xFF00D4AA);
}

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
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart));
    _animController.forward();
    _loadSavedProfiles();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfiles() async {
    if (mounted) {
      await context.read<TimetableProvider>().loadExamTimetable();
    }
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
    final result = await FilePicker.pickFiles(
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

    // Premium color palette
    final bgColor = isDark ? _Palette.bgDark : _Palette.bgLight;
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);
    final primaryColor = _Palette.primary;
    final accentColor = _Palette.secondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient glow layer for a premium, "alive" feel
          if (isDark) ...[
            Positioned(
              top: -120,
              right: -100,
              child: _GlowOrb(color: primaryColor, size: 320, opacity: 0.16),
            ),
            Positioned(
              top: 140,
              left: -140,
              child: _GlowOrb(color: accentColor, size: 260, opacity: 0.10),
            ),
          ],

          DefaultTabController(
            length: 2,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 230,
                  backgroundColor: isDark
                      ? const Color(0xFF0F1028).withOpacity(0.9)
                      : Colors.white.withOpacity(0.9),
                  surfaceTintColor: Colors.transparent,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 20, top: 8),
                      child: _GlassIconButton(
                        icon: Icons.notifications_none_rounded,
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ),
                  ],
                  flexibleSpace: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(left: 24, bottom: 84, right: 72),
                        title: FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (rect) => const LinearGradient(
                                    colors: [Colors.white, Color(0xFFDCD3FF)],
                                  ).createShader(rect),
                                  child: const Text(
                                    'My Timetable',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Organize your classes and exam schedules',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(64),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: _SegmentedTabBar(isDark: isDark),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _buildClassTab(context, isDark, primaryColor, accentColor, cardColor, borderColor, provider),
                  _buildExamTab(context, isDark, primaryColor, accentColor, cardColor, borderColor, provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassTab(BuildContext context, bool isDark, Color primary, Color accent, Color cardColor, Color borderColor, TimetableProvider provider) {
    return SingleChildScrollView(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildUploadCard(isDark, primary, accent, cardColor, borderColor),
                const SizedBox(height: 32),

                if (_loading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: primary),
                          const SizedBox(height: 16),
                          Text('Parsing timetable data...',
                              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),

                if (!_loading && provider.hasParsedData) ...[
                  const _SectionLabel(label: 'Configure Your Timetable'),
                  const SizedBox(height: 20),
                  _ModernDropdown(
                    label: 'Semester',
                    icon: Icons.school_rounded,
                    value: _selectedSemester,
                    items: provider.availableSemesters,
                    isDark: isDark,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    primary: primary,
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
                      icon: Icons.group_work_rounded,
                      value: _selectedGroup,
                      items: provider.getAvailableGroups(_selectedSemester!),
                      isDark: isDark,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primary: primary,
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
                      icon: Icons.people_alt_rounded,
                      value: _selectedSubGroup,
                      items: provider.getAvailableSubGroups(_selectedSemester!, _selectedGroup!),
                      isDark: isDark,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primary: primary,
                      onChanged: (v) => setState(() => _selectedSubGroup = v),
                    ),
                    const SizedBox(height: 32),
                  ],
                  _PressableScale(
                    enabled: _selectedSubGroup != null,
                    onTap: _selectedSubGroup == null
                        ? null
                        : () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => _LoadingDialog(isDark: isDark, primary: primary),
                            );

                            await context.read<TimetableProvider>().selectTimetable(_selectedSemester!, _selectedGroup!, _selectedSubGroup!);
                            await context.read<TimetableProvider>().scheduleReminders();
                            if (!mounted) return;
                            await _loadSavedProfiles();

                            Navigator.of(context).pop(); // Close dialog
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimetableViewScreen()));
                          },
                    child: AnimatedOpacity(
                      opacity: _selectedSubGroup != null ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_Palette.primary, _Palette.secondary]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _selectedSubGroup != null ? [
                            BoxShadow(color: primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))
                          ] : [],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Build My Timetable',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                if (_savedProfiles.isNotEmpty) ...[
                  const SizedBox(height: 48),
                  const _SectionLabel(label: 'Saved Timetables'),
                  const SizedBox(height: 20),
                  ..._savedProfiles.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final currentId = '${p['semester']}_${p['groupName']}_${p['subGroup']}';
                    return _SavedTimetableCard(
                      profile: p,
                      index: i,
                      isDark: isDark,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primary: primary,
                      isNotified: _notifiedId == currentId,
                      onToggleNotification: () => _toggleNotification(p, currentId),
                      onTap: () => _loadAndNavigate(p),
                      onDelete: () => _deleteProfile(p, currentId),
                    );
                  }).toList(),
                  const SizedBox(height: 60),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleNotification(Map<String, String> p, String currentId) async {
    final prefs = await SharedPreferences.getInstance();
    final isCurrentlyNotified = _notifiedId == currentId;
    if (isCurrentlyNotified) {
      await prefs.remove('notified_semester');
      await prefs.remove('notified_group');
      await prefs.remove('notified_subgroup');
      await NotificationService.instance.cancelAll();
      if (mounted) await context.read<TimetableProvider>().loadNotifiedTimetable();
      setState(() => _notifiedId = null);
      if (mounted) _showToast('Notifications disabled.', Icons.notifications_off_rounded, Colors.grey.shade800);
    } else {
      await prefs.setString('notified_semester', p['semester']!);
      await prefs.setString('notified_group', p['groupName']!);
      await prefs.setString('notified_subgroup', p['subGroup']!);
      if (mounted) {
        await context.read<TimetableProvider>().loadSavedTimetable(p['semester']!, p['groupName']!, p['subGroup']!);
        await context.read<TimetableProvider>().loadNotifiedTimetable();
      }
      final summary = mounted ? await context.read<TimetableProvider>().scheduleReminders() : null;
      setState(() => _notifiedId = currentId);
      if (mounted) _showToast(summary ?? 'Notifications enabled!', Icons.alarm_on_rounded, const Color(0xFF7C5CFF));
    }
  }

  void _showToast(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(24),
    ));
  }

  Future<void> _loadAndNavigate(Map<String, String> p) async {
    await context.read<TimetableProvider>().loadSavedTimetable(p['semester']!, p['groupName']!, p['subGroup']!);
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableViewScreen()));
  }

  Future<void> _deleteProfile(Map<String, String> p, String currentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this saved timetable?', style: TextStyle(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      final notifiedSem = prefs.getString('notified_semester');
      final notifiedGrp = prefs.getString('notified_group');
      if (notifiedSem == p['semester'] && notifiedGrp == p['groupName']) {
        await prefs.remove('notified_semester');
        await prefs.remove('notified_group');
        await prefs.remove('notified_subgroup');
        await NotificationService.instance.cancelAll();
      }
      await DatabaseHelper.instance.deleteTimetableProfile(p['semester']!, p['groupName']!);
      if (mounted) await context.read<TimetableProvider>().loadNotifiedTimetable();
      _loadSavedProfiles();
    }
  }

  Widget _buildExamTab(BuildContext context, bool isDark, Color primary, Color accent, Color cardColor, Color borderColor, TimetableProvider provider) {
    final Map<String, List<dynamic>> groupedExams = {};
    for (var exam in provider.examTimetable) {
      groupedExams.putIfAbsent(exam.examType, () => []).add(exam);
    }

    return Stack(
      children: [
        if (provider.examTimetable.isEmpty)
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PulsingIcon(
                    icon: Icons.event_busy_rounded,
                    color: primary,
                  ),
                  const SizedBox(height: 24),
                  Text('No exams added yet', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 32),
                  _PressableScale(
                    enabled: true,
                    onTap: () => showDialog(context: context, builder: (_) => const ExamEntryDialog()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_Palette.primary, _Palette.secondary]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Add Exam', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.all(24).copyWith(bottom: 120),
            itemCount: groupedExams.length,
            itemBuilder: (context, index) {
              final type = groupedExams.keys.elementAt(index);
              final exams = groupedExams[type]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _GlassCard(
                  isDark: isDark,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamTypeScreen(examType: type))),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [primary.withOpacity(0.15), accent.withOpacity(0.15)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.folder_special_rounded, color: primary, size: 28),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(type, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 6),
                            Text('${exams.length} Exam${exams.length == 1 ? '' : 's'} Scheduled', style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black26),
                    ],
                  ),
                ),
              );
            },
          ),
        if (provider.examTimetable.isNotEmpty)
          Positioned(
            bottom: 32,
            right: 24,
            child: _PressableScale(
              enabled: true,
              onTap: () => showDialog(context: context, builder: (_) => const ExamEntryDialog()),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, accent]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Add Exam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadCard(bool isDark, Color primary, Color accent, Color cardColor, Color borderColor) {
    return _PressableScale(
      enabled: !_loading,
      onTap: _loading ? null : _pickFile,
      child: _GlassCard(
        isDark: isDark,
        cardColor: cardColor,
        borderColor: _fileName != null ? primary.withOpacity(0.5) : borderColor,
        onTap: null, // handled by _PressableScale wrapper
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName ?? 'Upload Timetable',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fileName != null ? 'Tap to change file' : 'Choose your HTML timetable file',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _fileName != null ? const Color(0xFF00D4AA).withOpacity(0.1) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _fileName != null ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
                color: _fileName != null ? const Color(0xFF00D4AA) : (isDark ? Colors.white54 : Colors.black45),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable pieces
// ---------------------------------------------------------------------------

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowOrb({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
        boxShadow: [BoxShadow(color: color.withOpacity(opacity), blurRadius: 150)],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
              ),
              child: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium pill-style segmented control wired to the surrounding
/// DefaultTabController — visually replaces the stock TabBar without
/// altering the TabController / TabBarView wiring.
class _SegmentedTabBar extends StatelessWidget {
  final bool isDark;
  const _SegmentedTabBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
      ),
      child: TabBar(
        padding: const EdgeInsets.all(4),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [_Palette.primary, _Palette.secondary],
          ),
          boxShadow: [
            BoxShadow(color: _Palette.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorAnimation: TabIndicatorAnimation.elastic,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        splashBorderRadius: BorderRadius.circular(16),
        tabs: const [
          Tab(text: 'Class Timetable'),
          Tab(text: 'Exam Timetable'),
        ],
      ),
    );
  }
}

/// Adds a subtle tactile "press" scale effect around any tappable child
/// without changing the wrapped widget's own onTap wiring elsewhere.
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  const _PressableScale({required this.child, required this.onTap, required this.enabled});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed && widget.enabled ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Gentle looping pulse used for the exam-tab empty state icon.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.08)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: widget.color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(widget.icon, size: 48, color: widget.color.withOpacity(0.5)),
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
          decoration: BoxDecoration(color: const Color(0xFF7C5CFF), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.3),
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
  final Color cardColor;
  final Color borderColor;
  final Color primary;
  final ValueChanged<String?> onChanged;

  const _ModernDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        icon: Icon(Icons.expand_more_rounded, color: isDark ? Colors.white54 : Colors.black45),
        dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(icon, color: primary.withOpacity(0.8), size: 22),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SavedTimetableCard extends StatelessWidget {
  final Map<String, String> profile;
  final int index;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color primary;
  final bool isNotified;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleNotification;

  const _SavedTimetableCard({
    required this.profile,
    required this.index,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.primary,
    required this.isNotified,
    required this.onTap,
    required this.onDelete,
    required this.onToggleNotification,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> presetColors = const [
      Color(0xFF7C5CFF), // Primary Purple
      Color(0xFF00D4AA), // Teal
      Color(0xFFFF5C74), // Pink/Red
      Color(0xFFFACC15), // Yellow
      Color(0xFF38BDF8), // Light Blue
    ];
    final itemColor = presetColors[index % presetColors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Dismissible(
        key: Key('${profile['semester']}_${profile['groupName']}_${profile['subGroup']}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.9), borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
        ),
        confirmDismiss: (_) async {
          onDelete();
          return false; // Handled by dialog in onDelete
        },
        child: _GlassCard(
          isDark: isDark,
          cardColor: cardColor,
          borderColor: isNotified ? itemColor.withOpacity(0.5) : borderColor,
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [itemColor.withOpacity(0.25), itemColor.withOpacity(0.1)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: itemColor.withOpacity(0.3)),
                ),
                child: Icon(Icons.calendar_month_rounded, color: itemColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile['semester']}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile['groupName']} • ${profile['subGroup'] ?? ''}',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isNotified ? primary.withOpacity(0.1) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isNotified ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                    color: isNotified ? primary : (isDark ? Colors.white38 : Colors.black38),
                    size: 22,
                  ),
                  onPressed: onToggleNotification,
                  tooltip: isNotified ? 'Disable Reminders' : 'Enable Reminders',
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const _GlassCard({
    required this.child,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 20, offset: const Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              highlightColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
              splashColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  final bool isDark;
  final Color primary;

  const _LoadingDialog({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 24),
            DefaultTextStyle(
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
              child: const Text('Building Timetable...'),
            ),
          ],
        ),
      ),
    );
  }
}


