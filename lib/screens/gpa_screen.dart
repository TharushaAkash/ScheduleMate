import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import 'auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/course.dart';
import '../models/semester.dart';
import '../models/timetable_entry.dart';
import '../providers/gpa_provider.dart';
import '../providers/timetable_provider.dart';
import 'timetable_upload_screen.dart';
import 'ca_marks_screen.dart';
import '../services/backup_service.dart';

class GpaScreen extends StatefulWidget {
  const GpaScreen({super.key});

  @override
  State<GpaScreen> createState() => _GpaScreenState();
}

class _GpaScreenState extends State<GpaScreen> {
  String _studentName = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GpaProvider>().loadSemesters();
      context.read<TimetableProvider>().loadDefaultTimetable();
    });
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentName = prefs.getString('student_name') ?? '';
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return const Color(0xFF00D4AA);
    if (grade.startsWith('B')) return const Color(0xFF6C63FF);
    if (grade.startsWith('C')) return const Color(0xFFFFB347);
    return const Color(0xFFFF6B9D);
  }

  Widget _buildTrendChart(List<Semester> semesters, bool isDark) {
    if (semesters.isEmpty || semesters.length < 2) return const SizedBox.shrink();
    
    final sorted = List.from(semesters)..sort((a, b) => (a as Semester).semesterNumber.compareTo((b as Semester).semesterNumber));
    
    List<FlSpot> spots = [];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].semesterGpa));
    }

    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252535) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('GPA Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sorted.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('S${sorted[value.toInt()].semesterNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 0.5,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey));
                      },
                      reservedSize: 32,
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (sorted.length - 1).toDouble(),
                minY: max(0, spots.map((s) => s.y).reduce(min) - 0.5),
                maxY: 4.0,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: Theme.of(context).colorScheme.surface,
                          strokeWidth: 2,
                          strokeColor: Theme.of(context).colorScheme.primary,
                        );
                      }
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterStats(List<Semester> semesters, bool isDark) {
    if (semesters.isEmpty) return const SizedBox.shrink();
    
    double highest = semesters.map((s) => s.semesterGpa).reduce(max);
    double lowest = semesters.map((s) => s.semesterGpa).reduce(min);
    double avg = semesters.map((s) => s.semesterGpa).reduce((a, b) => a + b) / semesters.length;

    String highestLabel = semesters.firstWhere((s) => s.semesterGpa == highest).label;
    String lowestLabel = semesters.firstWhere((s) => s.semesterGpa == lowest).label;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252535) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Semester Statistics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text('All Semesters', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Highest GPA', highest, Colors.green, highestLabel, isDark),
              Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.grey.shade200),
              _buildStatItem('Average GPA', avg, const Color(0xFF6C63FF), '', isDark),
              Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.grey.shade200),
              _buildStatItem('Lowest GPA', lowest, Colors.red, lowestLabel, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color, String subtext, bool isDark) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(value.toStringAsFixed(2), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        if (subtext.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtext, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
        ]
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    final items = [
      {'icon': Icons.show_chart_rounded, 'label': 'Performance', 'color': const Color(0xFF6C63FF)},
      {'icon': Icons.emoji_events_outlined, 'label': 'Rankings', 'color': Colors.orange},
      {'icon': Icons.calendar_month_outlined, 'label': 'Timetable', 'color': Colors.purple},
      {'icon': Icons.description_outlined, 'label': 'CA Marks', 'color': Colors.blue},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (item['label'] == 'Timetable') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableUploadScreen()));
                } else if (item['label'] == 'CA Marks') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CaMarksScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item['label']} coming soon!'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252535) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                ),
                child: Column(
                  children: [
                    Icon(item['icon'] as IconData, 
                      color: item['color'] as Color? ?? Theme.of(context).colorScheme.primary, 
                      size: 24),
                    const SizedBox(height: 8),
                    Text(item['label'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  _NextLectureInfo? _getNextLecture(List<TimetableEntry> entries) {
    if (entries.isEmpty) return null;

    final now = DateTime.now();
    final nowInMinutes = now.hour * 60 + now.minute;

    // Rule: "ude 8.30 ta tiyenvanm ude 5n passe penna oni"
    // If before 5:00 AM (300 minutes), do not show today's 8:30 AM lecture yet.
    if (nowInMinutes < 300) {
      return null;
    }

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final todayName = weekdays[now.weekday - 1];

    // Rule: "heta tiyena eka ada enna baa" -> Only check TODAY's lectures!
    final todayEntries = entries
        .where((e) => e.day.trim().toLowerCase() == todayName.toLowerCase())
        .toList();
    if (todayEntries.isEmpty) return null;

    int parseMinutes(String timeStr) {
      try {
        final cleaned = timeStr.trim();
        final parts = cleaned.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return h * 60 + m;
      } catch (_) {
        return 0;
      }
    }

    todayEntries.sort((a, b) => parseMinutes(a.startTime).compareTo(parseMinutes(b.startTime)));

    for (final entry in todayEntries) {
      final startMin = parseMinutes(entry.startTime);
      final endMin = parseMinutes(entry.endTime);

      if (endMin > nowInMinutes) {
        final isOngoing = nowInMinutes >= startMin && nowInMinutes < endMin;
        return _NextLectureInfo(entry: entry, isOngoing: isOngoing);
      }
    }

    return null;
  }

  String _formatTime12h(String time24) {
    try {
      final parts = time24.trim().split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return time24;
    }
  }

  Widget _buildNextLectureCard(TimetableProvider timetableProvider, bool isDark) {
    final entriesToUse = timetableProvider.notifiedTimetable.isNotEmpty
        ? timetableProvider.notifiedTimetable
        : timetableProvider.currentTimetable;
    final info = _getNextLecture(entriesToUse);
    if (info == null) return const SizedBox.shrink();

    final entry = info.entry;
    final isOngoing = info.isOngoing;

    final startTimeFormatted = _formatTime12h(entry.startTime);
    final endTimeFormatted = _formatTime12h(entry.endTime);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isOngoing
            ? const LinearGradient(
                colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3B33C6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isOngoing ? const Color(0xFF11998E) : const Color(0xFF6C63FF)).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOngoing ? Icons.play_circle_filled_rounded : Icons.schedule_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOngoing ? 'ONGOING LECTURE' : 'NEXT LECTURE TODAY',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$startTimeFormatted - $endTimeFormatted',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entry.moduleCode.isNotEmpty)
            Text(
              entry.moduleCode,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            entry.moduleName.isNotEmpty ? entry.moduleName : 'Scheduled Class',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.2), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              if (entry.venue.isNotEmpty) ...[
                const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.venue,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (entry.lecturer.isNotEmpty) ...[
                if (entry.venue.isNotEmpty) const SizedBox(width: 12),
                const Icon(Icons.person_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.lecturer,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GpaProvider>();
    final timetableProvider = context.watch<TimetableProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        toolbarHeight: 70,
        title: Row(
          children: [
            Consumer<BackupService>(
              builder: (context, backupService, _) {
                final photoUrl = backupService.currentUser?.photoUrl;
                if (photoUrl != null) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(photoUrl),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_getGreeting()},',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.black45)),
                Text(
                  '${_studentName.isNotEmpty ? _studentName : 'Tharusha'} 👋',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSemesterDialog(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Semester', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildNextLectureCard(timetableProvider, isDark),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A44CC), Color(0xFF332D99)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A44CC).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cumulative GPA',
                                style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  provider.cumulativeGpa.toStringAsFixed(2),
                                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 12),
                                      SizedBox(width: 4),
                                      Text('0.17', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${provider.semesters.length} semester${provider.semesters.length == 1 ? '' : 's'} recorded',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            const SizedBox(height: 20),
                            Stack(
                              children: [
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: provider.cumulativeGpa / 4.0,
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text("You're in the Top 25% of your batch! 👑", 
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 75,
                                width: 75,
                                child: CircularProgressIndicator(
                                  value: provider.cumulativeGpa / 4.0,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Excellent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildActionButtons(isDark),
                _buildSemesterStats(provider.semesters, isDark),
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 12, bottom: 16, right: 20),
                  child: Row(
                    children: [
                      Text('My Semesters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const Spacer(),
                      Text('View All', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF9C96FF))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (provider.semesters.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 16),
                    Text('No semesters yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black45)),
                    const SizedBox(height: 8),
                    Text('Tap + to add your first semester', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.zero,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final semester = provider.semesters[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF252535) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.07), blurRadius: 16, offset: const Offset(0, 4))],
                      ),
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A44CC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(child: Text('S${semester.semesterNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  semester.label, 
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (index == 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A44CC).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Latest', style: TextStyle(color: Color(0xFF9C96FF), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ]
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('GPA: ${semester.semesterGpa.toStringAsFixed(2)}  •  ${semester.totalCredits.toStringAsFixed(1)} cr', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                semester.semesterGpa.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: semester.semesterGpa >= 3.25 ? const Color(0xFF4ADE80) : const Color(0xFF9C96FF),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                            ],
                          ),
                        children: [
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ...semester.courses.map((c) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${c.moduleCode} — ${c.moduleName}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                                      Text('${c.creditHours} credits', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getGradeColor(c.grade).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(c.grade, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _getGradeColor(c.grade))),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                  onPressed: () => provider.deleteCourse(semester.id!, c.id!),
                                ),
                              ],
                            ),
                          )),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Add'),
                                    onPressed: () => _showAddCourseDialog(context, semester.id!),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.colorScheme.primary,
                                      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text('PDFs'),
                                    onPressed: () => _extractMultipleGradesFromPdfs(context, semester.id!),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.colorScheme.secondary,
                                      side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  onPressed: () => provider.deleteSemester(semester.id!),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  childCount: provider.semesters.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: _buildTrendChart(provider.semesters, isDark),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSemesterDialog(BuildContext context) {
    int year = 1;
    int semesterNumber = 1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Semester'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: year,
                decoration: const InputDecoration(labelText: 'Year'),
                items: [1, 2, 3, 4]
                    .map((y) => DropdownMenuItem(value: y, child: Text('Year $y')))
                    .toList(),
                onChanged: (v) => setState(() => year = v!),
              ),
              DropdownButtonFormField<int>(
                value: semesterNumber,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: [1, 2]
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text('Semester $s')))
                    .toList(),
                onChanged: (v) => setState(() => semesterNumber = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<GpaProvider>().addSemester(year, semesterNumber);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context, int semesterId) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final creditController = TextEditingController(text: '4');
    String grade = 'A';
    bool isExtracting = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Module'),
        content: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isExtracting)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Auto-fill from PDF'),
                    onPressed: () async {
                      setState(() => isExtracting = true);
                      final extracted = await _extractSingleGradeFromPdf(context);
                      if (extracted != null) {
                        codeController.text = extracted.moduleCode;
                        nameController.text = extracted.moduleName;
                        if (Course.gradePoints.containsKey(extracted.grade)) {
                          grade = extracted.grade;
                        }
                      }
                      setState(() => isExtracting = false);
                    },
                  ),
                const Divider(),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Module Code'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Module Name'),
                ),
                TextField(
                  controller: creditController,
                  decoration: const InputDecoration(labelText: 'Credit Hours'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: grade,
                  decoration: const InputDecoration(labelText: 'Grade'),
                  items: Course.gradePoints.keys
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => grade = v!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              context.read<GpaProvider>().addCourse(
                    semesterId,
                    Course(
                      semesterId: semesterId,
                      moduleCode: codeController.text.trim(),
                      moduleName: nameController.text.trim(),
                      creditHours:
                          double.tryParse(creditController.text) ?? 3.0,
                      grade: grade,
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<Course?> _extractSingleGradeFromPdf(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id');

    if (studentId == null || studentId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set your Student ID in Profile first.')),
        );
      }
      return null;
    }

    AuthScreen.bypassNextLifecycleLock = true;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        final bytes = await File(result.files.single.path!).readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        final text = extractor.extractText(layoutText: true);
        final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

        String safeId = studentId.replaceAll(' ', '_');

        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains(studentId)) {
            String studentLine = lines[i].replaceAll(studentId, safeId);
            List<String> studentData = studentLine.split(RegExp(r'\s{2,}|\t')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            if (studentData.length <= 1) {
              studentData = studentLine.split(RegExp(r'\s+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            }

            String? grade;
            final validGrades = Course.gradePoints.keys.toList();
            for (int k = studentData.length - 1; k >= 0; k--) {
              if (validGrades.contains(studentData[k])) {
                grade = studentData[k];
                break;
              }
            }

            String moduleCode = "";
            String moduleName = "";
            for (int j = i - 1; j >= 0; j--) {
              final match = RegExp(r'([A-Za-z]{2,3}\s?\d{3,4})\s*(.*)').firstMatch(lines[j]);
              if (match != null) {
                moduleCode = match.group(1)!.trim();
                moduleName = match.group(2)!.trim();
                if (moduleName.startsWith('-')) {
                  moduleName = moduleName.substring(1).trim();
                }
                break;
              }
            }

            document.dispose();

            if (grade != null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Module details extracted! Please verify Credit Hours.')),
                );
              }
              return Course(
                semesterId: 0,
                moduleCode: moduleCode,
                moduleName: moduleName,
                creditHours: 4.0, 
                grade: grade,
              );
            }
          }
        }

        document.dispose();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No grades found in the PDF for your Student ID.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to process PDF: $e')),
          );
        }
      }
    }
    return null;
  }

  Future<void> _extractMultipleGradesFromPdfs(BuildContext context, int semesterId) async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id');

    if (studentId == null || studentId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set your Student ID in Profile first.')),
        );
      }
      return;
    }

    AuthScreen.bypassNextLifecycleLock = true;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      int addedCount = 0;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing PDFs...')),
        );
      }

      for (var file in result.files) {
        if (file.path == null) continue;
        
        try {
          final bytes = await File(file.path!).readAsBytes();
          final document = PdfDocument(inputBytes: bytes);
          final extractor = PdfTextExtractor(document);
          final text = extractor.extractText(layoutText: true);
          final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

          String safeId = studentId.replaceAll(' ', '_');
          Course? foundCourse;

          for (int i = 0; i < lines.length; i++) {
            if (lines[i].contains(studentId)) {
              String studentLine = lines[i].replaceAll(studentId, safeId);
              List<String> studentData = studentLine.split(RegExp(r'\s{2,}|\t')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (studentData.length <= 1) {
                studentData = studentLine.split(RegExp(r'\s+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              }

              String? grade;
              final validGrades = Course.gradePoints.keys.toList();
              for (int k = studentData.length - 1; k >= 0; k--) {
                if (validGrades.contains(studentData[k])) {
                  grade = studentData[k];
                  break;
                }
              }

              String moduleCode = "";
              String moduleName = "";
              for (int j = i - 1; j >= 0; j--) {
                final match = RegExp(r'([A-Za-z]{2,3}\s?\d{3,4})\s*(.*)').firstMatch(lines[j]);
                if (match != null) {
                  moduleCode = match.group(1)!.trim();
                  moduleName = match.group(2)!.trim();
                  if (moduleName.startsWith('-')) {
                    moduleName = moduleName.substring(1).trim();
                  }
                  break;
                }
              }

              if (grade != null) {
                foundCourse = Course(
                  semesterId: semesterId,
                  moduleCode: moduleCode.isEmpty ? "Unknown" : moduleCode,
                  moduleName: moduleName.isEmpty ? "Unknown Module" : moduleName,
                  creditHours: 4.0, 
                  grade: grade,
                );
                break;
              }
            }
          }

          document.dispose();

          if (foundCourse != null && context.mounted) {
            context.read<GpaProvider>().addCourse(semesterId, foundCourse);
            addedCount++;
          }
        } catch (e) {
          debugPrint('Failed to process PDF ${file.name}: $e');
        }
      }

      if (context.mounted) {
        if (addedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully added $addedCount module(s)!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No grades found matching your Student ID in the selected PDFs.'), backgroundColor: Colors.orange),
          );
        }
      }
    }
  }
}

class _NextLectureInfo {
  final TimetableEntry entry;
  final bool isOngoing;

  _NextLectureInfo({required this.entry, required this.isOngoing});
}
