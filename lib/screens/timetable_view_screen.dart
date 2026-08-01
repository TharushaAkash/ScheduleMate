import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/timetable_provider.dart';
import '../models/timetable_entry.dart';
import '../services/holiday_service.dart';

class TimetableViewScreen extends StatefulWidget {
  const TimetableViewScreen({super.key});

  @override
  State<TimetableViewScreen> createState() => _TimetableViewScreenState();
}

class _TimetableViewScreenState extends State<TimetableViewScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _currentWeekStart;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late ScrollController _dayScrollController;

  final List<String> _availableDays = const [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  final List<String> _dayShort = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Map<String, String> _holidays = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _currentWeekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    double initialScroll = (_selectedDate.weekday - 1) * 66.0;
    if (_selectedDate.weekday > 3) initialScroll -= 66.0;
    if (initialScroll < 0) initialScroll = 0;
    
    _dayScrollController = ScrollController(initialScrollOffset: initialScroll);
    
    _loadHolidays();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableProvider>().loadDefaultTimetable().then((_) {
        _loadPushSettings();
      });
    });
  }

  Future<void> _loadPushSettings() async {
  }

  @override
  void dispose() {
    _animController.dispose();
    _dayScrollController.dispose();
    super.dispose();
  }

  void _selectDate(DateTime date) {
    if (date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day) return;
    _animController.reverse().then((_) {
      setState(() => _selectedDate = date);
      _animController.forward();
    });
  }

  void _nextWeek() {
    _animController.reverse().then((_) {
      setState(() {
        _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
        _selectedDate = _selectedDate.add(const Duration(days: 7));
      });
      _animController.forward();
    });
  }

  void _prevWeek() {
    _animController.reverse().then((_) {
      setState(() {
        _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
      });
      _animController.forward();
    });
  }

  Future<void> _loadHolidays() async {
    final service = HolidayService();
    final cached = await service.loadCached();
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _holidays = cached;
      });
    }
    
    final latest = await service.fetchLatest();
    if (mounted && latest.isNotEmpty) {
      setState(() {
        _holidays = latest;
      });
    }
  }

  String? _getHoliday(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return _holidays[key];
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

    final dayName = _availableDays[_selectedDate.weekday - 1];
    final holiday = _getHoliday(_selectedDate);

    final dayClasses = (grouped[dayName] ?? [])
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
          SliverPersistentHeader(
            pinned: true,
            delegate: _DayHeaderDelegate(
              currentWeekStart: _currentWeekStart,
              selectedDate: _selectedDate,
              grouped: grouped,
              isDark: isDark,
              primary: primary,
              scrollController: _dayScrollController,
              onDateSelected: _selectDate,
              onPrevWeek: _prevWeek,
              onNextWeek: _nextWeek,
              dayShort: _dayShort,
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
                child: holiday != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.celebration_rounded,
                                  size: 48, color: Colors.redAccent.withOpacity(0.8)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Holiday! 🎉',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              holiday,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : dayClasses.isEmpty
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
  final DateTime currentWeekStart;
  final DateTime selectedDate;
  final Map<String, List<TimetableEntry>> grouped;
  final bool isDark;
  final Color primary;
  final ScrollController scrollController;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final List<String> dayShort;

  _DayHeaderDelegate({
    required this.currentWeekStart,
    required this.selectedDate,
    required this.grouped,
    required this.isDark,
    required this.primary,
    required this.scrollController,
    required this.onDateSelected,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.dayShort,
  });

  @override
  double get minExtent => 140;
  @override
  double get maxExtent => 140;

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) =>
      oldDelegate.selectedDate != selectedDate ||
      oldDelegate.currentWeekStart != currentWeekStart ||
      oldDelegate.isDark != isDark ||
      oldDelegate.grouped != grouped;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 140,
          color: (isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF)).withOpacity(0.85),
          child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white70 : Colors.black54),
                  onPressed: onPrevWeek,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(currentWeekStart),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white70 : Colors.black54),
                  onPressed: onNextWeek,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(7, (i) {
                  final date = currentWeekStart.add(Duration(days: i));
                  final isSelected = date.year == selectedDate.year &&
                      date.month == selectedDate.month &&
                      date.day == selectedDate.day;

                  final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][date.weekday - 1];
                  final hasClasses = (grouped[dayName] ?? [])
                      .where((m) => m.moduleName.isNotEmpty || m.moduleCode.isNotEmpty)
                      .isNotEmpty;

                  return Padding(
                    padding: EdgeInsets.only(right: i == 6 ? 0 : 12),
                    child: GestureDetector(
                      onTap: () => onDateSelected(date),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 54,
                        height: 70,
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayShort[date.weekday - 1],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white.withOpacity(0.9)
                                    : (isDark ? Colors.white54 : Colors.black54),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            if (hasClasses && !isSelected)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: primary,
                                  shape: BoxShape.circle,
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
          ),
          const SizedBox(height: 8),
        ],
      ),
    )));
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF252535) : Colors.white).withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(isDark ? 0.05 : 0.4), width: 1.5),
            ),
            child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
      ))),
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
