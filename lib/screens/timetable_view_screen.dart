import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/timetable_provider.dart';
import '../models/timetable_entry.dart';

class TimetableViewScreen extends StatefulWidget {
  const TimetableViewScreen({super.key});

  @override
  State<TimetableViewScreen> createState() => _TimetableViewScreenState();
}

class _TimetableViewScreenState extends State<TimetableViewScreen>
    with SingleTickerProviderStateMixin {
  String? selectedDay;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _isPushEnabled = false;

  final List<String> _availableDays = const [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  final List<String> _dayShort = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    selectedDay = _availableDays.first;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableProvider>().loadDefaultTimetable().then((_) {
        _loadPushSettings();
      });
    });
  }

  Future<void> _loadPushSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = context.read<TimetableProvider>();
    final currentId = '${provider.selectedSemester}_${provider.selectedGroup}_${provider.selectedSubGroup}';
    final semester = prefs.getString('notified_semester');
    final group = prefs.getString('notified_group');
    final subGroup = prefs.getString('notified_subgroup');
    final notifiedId = (semester != null && group != null && subGroup != null)
        ? '${semester}_${group}_$subGroup'
        : null;
    
    setState(() {
      _isPushEnabled = notifiedId == currentId;
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _selectDay(String day) {
    if (day == selectedDay) return;
    _animController.reverse().then((_) {
      setState(() => selectedDay = day);
      _animController.forward();
    });
  }

  String _extractClassType(String name, String lec) {
    final lower = '$name $lec'.toLowerCase();
    if (lower.contains('lecture+tutorial')) return 'Lecture + Tutorial';
    if (lower.contains('lecture')) return 'Lecture';
    if (lower.contains('practical') ||
        lower.contains('lab') ||
        lower.contains('byod')) return 'Practical / Lab';
    if (lower.contains('tutorial')) return 'Tutorial';
    if (lower.contains('workshop')) return 'Workshop';
    return 'Class';
  }

  Color _getClassTypeColor(String type) {
    switch (type) {
      case 'Lecture':
        return const Color(0xFF6C63FF);
      case 'Practical / Lab':
        return const Color(0xFFFF6B9D);
      case 'Tutorial':
        return const Color(0xFF00D4AA);
      case 'Lecture + Tutorial':
        return const Color(0xFF4ECDC4);
      case 'Workshop':
        return const Color(0xFFFFB347);
      default:
        return Colors.grey;
    }
  }

  IconData _getClassTypeIcon(String type) {
    switch (type) {
      case 'Lecture':
        return Icons.school_rounded;
      case 'Practical / Lab':
        return Icons.science_rounded;
      case 'Tutorial':
        return Icons.menu_book_rounded;
      case 'Lecture + Tutorial':
        return Icons.cast_for_education_rounded;
      case 'Workshop':
        return Icons.build_rounded;
      default:
        return Icons.class_rounded;
    }
  }

  String _cleanLecturer(String lecturer) {
    String clean = lecturer;
    final types = [
      'Lecture+Tutorial', 'Lecture', 'Tutorial', 'Workshop', 'Practical', 'Lab', 'BYOD'
    ];
    for (var t in types) {
      clean = clean.replaceAll(RegExp(t, caseSensitive: false), '').trim();
    }
    while (clean.endsWith(',') || clean.endsWith('-')) {
      clean = clean.substring(0, clean.length - 1).trim();
    }
    return clean.isEmpty ? 'Unknown Lecturer' : clean;
  }

  String _cleanModuleName(String name) {
    String clean = name;
    for (var t in ['Practical BYOD', 'Practical', 'BYOD']) {
      clean = clean.replaceAll(RegExp(t, caseSensitive: false), '').trim();
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final grouped = provider.groupedByDay;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final dayClasses = (grouped[selectedDay] ?? [])
        .where((m) => m.moduleName.isNotEmpty || m.moduleCode.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: isDark ? const Color(0xFF252535) : Colors.white,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded,
                  color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),

            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
              title: Text(
                'My Timetable',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2D1B69), const Color(0xFF252535)]
                        : [const Color(0xFF4A44CC), const Color(0xFF9C96FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // Day Selector pinned below the app bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _DayHeaderDelegate(
              availableDays: _availableDays,
              dayShort: _dayShort,
              selectedDay: selectedDay,
              grouped: grouped,
              isDark: isDark,
              primary: primary,
              onDaySelected: _selectDay,
            ),
          ),
        ],
        body: grouped.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy_rounded,
                        size: 64,
                        color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 16),
                    Text(
                      'No classes found.',
                      style: TextStyle(
                        fontSize: 18,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              )
            : FadeTransition(
                opacity: _fadeAnim,
                child: dayClasses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.wb_sunny_rounded,
                                  size: 48, color: primary.withOpacity(0.6)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Free Day! 🎉',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No classes scheduled today',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: dayClasses.length,
                        itemBuilder: (context, i) {
                          final module = dayClasses[i];
                          final type = _extractClassType(
                              module.moduleName, module.lecturer);
                          final typeColor = _getClassTypeColor(type);
                          final typeIcon = _getClassTypeIcon(type);
                          final cName = _cleanModuleName(
                              module.moduleName.isEmpty
                                  ? module.moduleCode
                                  : module.moduleName);
                          final cLecturer =
                              _cleanLecturer(module.lecturer);
                          return _ClassCard(
                            module: module,
                            type: type,
                            typeColor: typeColor,
                            typeIcon: typeIcon,
                            moduleName: cName,
                            lecturer: cLecturer,
                            isDark: isDark,
                            index: i,
                            onEditTime: () =>
                                _editTime(context, module, provider),
                          );
                        },
                      ),
              ),
      ),
    );
  }

  Future<void> _editTime(BuildContext context, TimetableEntry entry,
      TimetableProvider provider) async {
    TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: _parseTime(entry.startTime),
      helpText: 'Select Start Time',
    );
    if (start == null) return;

    TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: _parseTime(entry.endTime),
      helpText: 'Select End Time',
    );
    if (end == null) return;

    final updated = TimetableEntry(
      id: entry.id,
      semester: entry.semester,
      group: entry.group,
      subGroup: entry.subGroup,
      day: entry.day,
      startTime:
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      endTime:
          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
      moduleCode: entry.moduleCode,
      moduleName: entry.moduleName,
      venue: entry.venue,
      lecturer: entry.lecturer,
    );

    await provider.updateEntry(updated);
  }

  TimeOfDay _parseTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(
          hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return TimeOfDay.now();
    }
  }
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> availableDays;
  final List<String> dayShort;
  final String? selectedDay;
  final Map<String, List<TimetableEntry>> grouped;
  final bool isDark;
  final Color primary;
  final ValueChanged<String> onDaySelected;

  _DayHeaderDelegate({
    required this.availableDays,
    required this.dayShort,
    required this.selectedDay,
    required this.grouped,
    required this.isDark,
    required this.primary,
    required this.onDaySelected,
  });

  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) =>
      oldDelegate.selectedDay != selectedDay ||
      oldDelegate.isDark != isDark ||
      oldDelegate.grouped != grouped;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 80, // Explicitly match min/maxExtent to fix geometry error
      color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(availableDays.length, (i) {
            final day = availableDays[i];
            final short = dayShort[i];
            final isSelected = day == selectedDay;
            final hasClasses = (grouped[day] ?? [])
                .where((m) => m.moduleName.isNotEmpty || m.moduleCode.isNotEmpty)
                .isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(right: i == availableDays.length - 1 ? 0 : 12),
              child: GestureDetector(
            onTap: () => onDaySelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isSelected
                    ? primary
                    : (isDark ? const Color(0xFF252535) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    short,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                  if (hasClasses && !isSelected)
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  ),
);
}
}

class _ClassCard extends StatelessWidget {
  final TimetableEntry module;
  final String type;
  final Color typeColor;
  final IconData typeIcon;
  final String moduleName;
  final String lecturer;
  final bool isDark;
  final int index;
  final VoidCallback onEditTime;

  const _ClassCard({
    required this.module,
    required this.type,
    required this.typeColor,
    required this.typeIcon,
    required this.moduleName,
    required this.lecturer,
    required this.isDark,
    required this.index,
    required this.onEditTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252535) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Color accent bar
              Container(
                width: 6,
                color: typeColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time + edit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Time chip
                          GestureDetector(
                            onTap: onEditTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_rounded,
                                      size: 14, color: typeColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${module.startTime} – ${module.endTime}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: typeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.edit_rounded,
                                      size: 12, color: typeColor.withOpacity(0.7)),
                                ],
                              ),
                            ),
                          ),
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon, size: 13, color: typeColor),
                                const SizedBox(width: 4),
                                Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Module name
                      Text(
                        moduleName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (module.moduleCode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          module.moduleCode,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white38 : Colors.black38,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Venue + Lecturer
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (module.venue.isNotEmpty)
                            _InfoChip(
                              icon: Icons.location_on_rounded,
                              label: module.venue,
                              isDark: isDark,
                            ),
                          if (lecturer.isNotEmpty &&
                              lecturer != 'Unknown Lecturer')
                            _InfoChip(
                              icon: Icons.person_rounded,
                              label: lecturer,
                              isDark: isDark,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _InfoChip(
      {required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF0EFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: isDark ? Colors.white54 : const Color(0xFF6C63FF)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF4A44CC),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
