import 'dart:io';
import 'dart:math';
import 'dart:ui';
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
import '../providers/app_notification_provider.dart';
import 'timetable_upload_screen.dart';
import 'ca_marks_screen.dart';
import '../services/backup_service.dart';
import 'announcements_screen.dart';
import 'gpa_insight_screen.dart';

// ---------------------------------------------------------------------------
// Shared design tokens — same premium palette used across the app
// ---------------------------------------------------------------------------
class _Palette {
  static const bgDark = Color(0xFF0F1028);
  static const bgLight = Color(0xFFF8F9FE);
  static const primary = Color(0xFF7C5CFF);
  static const secondary = Color(0xFF5B8CFF);
  static const accent = Color(0xFF00D4AA);
  static const cardDark = Color(0xFF1A1B3A);
}

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
    if (grade.startsWith('B')) return const Color(0xFF7C5CFF);
    if (grade.startsWith('C')) return const Color(0xFFFFB347);
    return const Color(0xFFFF6B9D);
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? _Palette.bgDark.withOpacity(0.96) : const Color(0xFFF8F7FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.transparent),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Consumer<AppNotificationProvider>(
                          builder: (context, notifProvider, _) {
                            if (notifProvider.notifications.isEmpty) return const SizedBox.shrink();
                            return TextButton.icon(
                              onPressed: () {
                                notifProvider.deleteAll();
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                              label: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.1),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Consumer<AppNotificationProvider>(
                      builder: (context, notifProvider, _) {
                        final notifications = notifProvider.notifications;
                        if (notifications.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                                const SizedBox(height: 16),
                                Text('No notifications yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black45)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notif = notifications[index];
                            final time = notif.timestamp;
                            final isToday = time.day == DateTime.now().day && time.month == DateTime.now().month && time.year == DateTime.now().year;
                            final dateStr = isToday
                              ? '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}'
                              : '${time.year}-${time.month.toString().padLeft(2,'0')}-${time.day.toString().padLeft(2,'0')}';

                            return _GlassPanel(
                              isDark: isDark,
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              padding: const EdgeInsets.all(16),
                              borderRadius: 20,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _Palette.primary.withOpacity(0.18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.campaign_rounded, color: _Palette.primary),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notif.title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.white54 : Colors.black45,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          notif.body,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendChart(List<Semester> semesters, bool isDark) {
    if (semesters.isEmpty || semesters.length < 2) return const SizedBox.shrink();

    final sorted = List.from(semesters)..sort((a, b) => (a as Semester).semesterNumber.compareTo((b as Semester).semesterNumber));

    List<FlSpot> spots = [];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].semesterGpa));
    }

    return _GlassPanel(
      isDark: isDark,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      height: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: _Palette.primary),
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
                            child: Text('S${sorted[value.toInt()].semesterNumber}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey)),
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
                        return Text(value.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey));
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
                    gradient: const LinearGradient(colors: [_Palette.primary, _Palette.secondary]),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: isDark ? _Palette.bgDark : Colors.white,
                          strokeWidth: 2,
                          strokeColor: _Palette.primary,
                        );
                      }
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_Palette.primary.withOpacity(0.2), _Palette.primary.withOpacity(0.0)],
                      ),
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

  Widget _buildDynamicGpaCard(GpaProvider provider, bool isDark) {
    final gpa = provider.cumulativeGpa;

    double trend = 0.0;
    if (provider.semesters.length > 1) {
      final sortedSemesters = List<Semester>.from(provider.semesters)
        ..sort((a, b) {
          if (a.year == b.year) return a.semesterNumber.compareTo(b.semesterNumber);
          return a.year.compareTo(b.year);
        });
      final prevSemesters = sortedSemesters.sublist(0, sortedSemesters.length - 1);
      final prevGpa = CumulativeGpaCalculator.calculate(prevSemesters);
      trend = gpa - prevGpa;
    }

    List<Color> gradientColors;
    String statusText;
    String rankText;

    if (gpa >= 3.7) {
      gradientColors = const [Color(0xFF2A2157), Color(0xFF110D24)];
      statusText = "Outstanding";
      rankText = "You're in the Top 5% of your batch! 👑";
    } else if (gpa >= 3.0) {
      gradientColors = const [Color(0xFF1B2E6B), Color(0xFF0A1230)];
      statusText = "Excellent";
      rankText = "You're in the Top 25% of your batch! ✨";
    } else if (gpa >= 2.7) {
      gradientColors = const [_Palette.accent, Color(0xFF16A085)];
      statusText = "Good";
      rankText = "You're in the Top 50% of your batch! 📈";
    } else if (gpa >= 2.5) {
      gradientColors = const [Color(0xFFE67E22), Color(0xFFD35400)];
      statusText = "Average";
      rankText = "Keep pushing! You can improve this! 💪";
    } else {
      gradientColors = const [Color(0xFFCC4444), Color(0xFF992D2D)];
      statusText = "Needs Work";
      rankText = "Time to focus! Let's bring this up! 🔥";
    }

    final isTrendPositive = trend >= 0;
    final trendColor = isTrendPositive ? const Color(0xFF00D4AA) : Colors.redAccent;
    final trendIcon = isTrendPositive ? Icons.arrow_upward : Icons.arrow_downward;
    final trendText = trend.abs().toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 14),
                          SizedBox(width: 6),
                          Text('CUMULATIVE GPA',
                              style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          gpa.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5, height: 1.0),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('/ 4.00', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.5))),
                        ),
                      ],
                    ),
                    if (provider.semesters.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0, left: 12.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: trendColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: trendColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(trendIcon, color: trendColor, size: 12),
                              const SizedBox(width: 4),
                              Text(trendText, style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${provider.semesters.length} semester${provider.semesters.length == 1 ? '' : 's'} recorded',
                  style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: gpa / 4.0,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF00FFCC)]),
                          borderRadius: BorderRadius.circular(2.5),
                          boxShadow: [BoxShadow(color: const Color(0xFF00D4AA).withOpacity(0.5), blurRadius: 6)],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(rankText,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 64,
                      width: 64,
                      child: CircularProgressIndicator(
                        value: gpa / 4.0,
                        strokeWidth: 3.5,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4AA)),
                      ),
                    ),
                    const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 28),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
              ),
            ],
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

    return _GlassPanel(
      isDark: isDark,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart, color: _Palette.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Semester Statistics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
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
              _buildStatItem('Highest GPA', highest, _Palette.accent, highestLabel, isDark),
              Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.grey.shade200),
              _buildStatItem('Average GPA', avg, _Palette.primary, '', isDark),
              Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.grey.shade200),
              _buildStatItem('Lowest GPA', lowest, const Color(0xFFFF6B9D), lowestLabel, isDark),
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
      {'icon': Icons.psychology_rounded, 'label': 'Insights', 'color': _Palette.primary},
      {'icon': Icons.emoji_events_outlined, 'label': 'Rankings', 'color': const Color(0xFFFFB347)},
      {'icon': Icons.calendar_month_outlined, 'label': 'Timetable', 'color': _Palette.secondary},
      {'icon': Icons.description_outlined, 'label': 'CA Marks', 'color': _Palette.accent},
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
                } else if (item['label'] == 'Insights') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GpaInsightScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item['label']} coming soon!'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item['icon'] as IconData,
                        color: item['color'] as Color,
                        size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(item['label'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
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

    final glowColor = isOngoing ? _Palette.accent : _Palette.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isOngoing
            ? const LinearGradient(
                colors: [Color(0xFF00D4AA), Color(0xFF11998E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [_Palette.primary, _Palette.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
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

    final bgColor = isDark ? _Palette.bgDark : _Palette.bgLight;

    final Map<int, List<Semester>> groupedSemesters = {};
    for (var sem in provider.semesters) {
      groupedSemesters.putIfAbsent(sem.year, () => []).add(sem);
    }
    final sortedYears = groupedSemesters.keys.toList()..sort();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70,
        title: Consumer<BackupService>(
          builder: (context, backupService, _) {
            final photoUrl = backupService.currentUser?.photoUrl;
            final displayName = backupService.currentUser?.displayName;

            // Get first name if display name has multiple words
            String firstName = '';
            if (displayName != null && displayName.isNotEmpty) {
              firstName = displayName.split(' ')[0];
            }

            final displayString = _studentName.isNotEmpty
                ? _studentName
                : (firstName.isNotEmpty ? firstName : 'Tharusha');

            return Row(
              children: [
                if (photoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [_Palette.primary, _Palette.secondary]),
                      ),
                      child: CircleAvatar(
                        radius: 19,
                        backgroundImage: NetworkImage(photoUrl),
                      ),
                    ),
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
                      '$displayString 👋',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          _GlassIconButton(
            icon: Icons.campaign_rounded,
            isDark: isDark,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
            },
          ),
          const SizedBox(width: 8),
          Consumer<AppNotificationProvider>(
            builder: (context, notifProvider, _) {
              final hasUnread = notifProvider.unreadCount > 0;
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _GlassIconButton(
                      icon: Icons.notifications_rounded,
                      isDark: isDark,
                      onTap: () {
                        notifProvider.markAllAsRead();
                        _showNotificationsSheet(context);
                      },
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: bgColor, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [_Palette.primary, _Palette.secondary]),
          boxShadow: [BoxShadow(color: _Palette.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddSemesterDialog(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Semester', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(
              top: -100,
              right: -100,
              child: _GlowOrb(color: _Palette.primary, size: 300, opacity: 0.14),
            ),
            Positioned(
              top: 260,
              left: -120,
              child: _GlowOrb(color: _Palette.secondary, size: 240, opacity: 0.10),
            ),
          ],
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildNextLectureCard(timetableProvider, isDark),
                    _buildDynamicGpaCard(provider, isDark),
                    _buildActionButtons(isDark),
                    _buildSemesterStats(provider.semesters, isDark),
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 12, bottom: 16, right: 20),
                      child: Row(
                        children: [
                          Text('My Semesters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          const Spacer(),
                          const Text('View All', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _Palette.secondary)),
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
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: _Palette.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(Icons.school_outlined, size: 48, color: _Palette.primary.withOpacity(0.6)),
                        ),
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
                        final year = sortedYears[index];
                        final yearSemesters = groupedSemesters[year]!;

                        return _GlassPanel(
                          isDark: isDark,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: EdgeInsets.zero,
                          borderRadius: 20,
                          child: Theme(
                            data: theme.copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: const RoundedRectangleBorder(side: BorderSide.none),
                              iconColor: isDark ? Colors.white70 : Colors.black54,
                              collapsedIconColor: isDark ? Colors.white70 : Colors.black54,
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [_Palette.primary, _Palette.secondary]),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    'Y$year',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Year $year',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (index == sortedYears.length - 1) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _Palette.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Latest', style: TextStyle(color: _Palette.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ]
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '${yearSemesters.length} Semester${yearSemesters.length == 1 ? '' : 's'}',
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13),
                                ),
                              ),
                              children: yearSemesters.map((semester) => _buildSemesterCard(context, semester, isDark, theme, provider)).toList(),
                            ),
                          ),
                        );
                      },
                      childCount: sortedYears.length,
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
        ],
      ),
    );
  }

  Widget _buildSemesterCard(BuildContext context, Semester semester, bool isDark, ThemeData theme, GpaProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          iconColor: isDark ? Colors.white70 : Colors.black54,
          collapsedIconColor: isDark ? Colors.white70 : Colors.black54,
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _Palette.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text('S${semester.semesterNumber}', style: const TextStyle(color: _Palette.secondary, fontWeight: FontWeight.bold, fontSize: 14))),
          ),
          title: Text(
            'Semester ${semester.semesterNumber}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Text('GPA: ${semester.semesterGpa.toStringAsFixed(2)}  •  ${semester.totalCredits.toStringAsFixed(1)} cr', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                semester.semesterGpa.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: semester.semesterGpa >= 3.25 ? const Color(0xFF00D4AA) : _Palette.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black45),
            ],
          ),
          children: [
            Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? Colors.white12 : null),
            ...semester.courses.map((c) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${c.moduleCode} — ${c.moduleName}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                        Text('${c.creditHours} credits', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getGradeColor(c.grade).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(c.grade, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _getGradeColor(c.grade))),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey),
                    onPressed: () => _showEditCourseDialog(context, semester.id!, c),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey),
                    onPressed: () => provider.deleteCourse(semester.id!, c.id!),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            )),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showAddCourseDialog(context, semester.id!),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _Palette.primary,
                        side: BorderSide(color: _Palette.primary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('PDFs', style: TextStyle(fontSize: 12)),
                      onPressed: () => _extractMultipleGradesFromPdfs(context, semester.id!),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _Palette.secondary,
                        side: BorderSide(color: _Palette.secondary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                    onPressed: () => provider.deleteSemester(semester.id!),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showAddSemesterDialog(BuildContext context) {
    int year = 1;
    int semesterNumber = 1;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    InputDecoration decor(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _Palette.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131524) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(
            builder: (ctx, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add Semester', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 24),
                DropdownButtonFormField<int>(
                  value: year,
                  decoration: decor('Year'),
                  dropdownColor: isDark ? const Color(0xFF1A1B3A) : Colors.white,
                  items: [1, 2, 3, 4]
                      .map((y) => DropdownMenuItem(value: y, child: Text('Year $y', style: TextStyle(color: isDark ? Colors.white : Colors.black87))))
                      .toList(),
                  onChanged: (v) => setState(() => year = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: semesterNumber,
                  decoration: decor('Semester'),
                  dropdownColor: isDark ? const Color(0xFF1A1B3A) : Colors.white,
                  items: [1, 2]
                      .map((s) => DropdownMenuItem(value: s, child: Text('Semester $s', style: TextStyle(color: isDark ? Colors.white : Colors.black87))))
                      .toList(),
                  onChanged: (v) => setState(() => semesterNumber = v!),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                      child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_Palette.primary, _Palette.secondary]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: _Palette.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<GpaProvider>().addSemester(year, semesterNumber);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context, int semesterId) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final creditController = TextEditingController(text: '4');
    String grade = 'A';
    bool isExtracting = false;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    InputDecoration decor(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _Palette.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131524) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(
            builder: (ctx, setState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add Module', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 16),
                  if (isExtracting)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _Palette.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _Palette.accent.withOpacity(0.3)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
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
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf_rounded, color: _Palette.accent, size: 20),
                              SizedBox(width: 8),
                              Text('Auto-fill from PDF', style: TextStyle(color: _Palette.accent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  TextField(
                    controller: codeController,
                    decoration: decor('Module Code'),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: decor('Module Name'),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: creditController,
                          decoration: decor('Credits'),
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: grade,
                          decoration: decor('Grade'),
                          dropdownColor: isDark ? const Color(0xFF1A1B3A) : Colors.white,
                          items: Course.gradePoints.keys
                              .map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(color: isDark ? Colors.white : Colors.black87))))
                              .toList(),
                          onChanged: (v) => setState(() => grade = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                        child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_Palette.primary, _Palette.secondary]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _Palette.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.trim().isEmpty) return;
                            context.read<GpaProvider>().addCourse(
                                  semesterId,
                                  Course(
                                    semesterId: semesterId,
                                    moduleCode: codeController.text.trim(),
                                    moduleName: nameController.text.trim(),
                                    creditHours: double.tryParse(creditController.text) ?? 3.0,
                                    grade: grade,
                                  ),
                                );
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showEditCourseDialog(BuildContext context, int semesterId, Course course) {
    final codeController = TextEditingController(text: course.moduleCode);
    final nameController = TextEditingController(text: course.moduleName);
    final creditController = TextEditingController(text: course.creditHours.toString());
    String grade = course.grade;

    if (!Course.gradePoints.containsKey(grade)) {
      grade = 'A';
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    InputDecoration decor(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _Palette.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131524) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(
            builder: (ctx, setState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Edit Module', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: codeController,
                    decoration: decor('Module Code'),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: decor('Module Name'),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: creditController,
                          decoration: decor('Credits'),
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: grade,
                          decoration: decor('Grade'),
                          dropdownColor: isDark ? const Color(0xFF1A1B3A) : Colors.white,
                          items: Course.gradePoints.keys
                              .map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(color: isDark ? Colors.white : Colors.black87))))
                              .toList(),
                          onChanged: (v) => setState(() => grade = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                        child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_Palette.primary, _Palette.secondary]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _Palette.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.trim().isEmpty) return;
                            context.read<GpaProvider>().updateCourse(
                                  semesterId,
                                  Course(
                                    id: course.id,
                                    semesterId: semesterId,
                                    moduleCode: codeController.text.trim(),
                                    moduleName: nameController.text.trim(),
                                    creditHours: double.tryParse(creditController.text) ?? course.creditHours,
                                    grade: grade,
                                  ),
                                );
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
    final result = await FilePicker.pickFiles(
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
    final result = await FilePicker.pickFiles(
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

// ---------------------------------------------------------------------------
// Reusable premium glass widgets
// ---------------------------------------------------------------------------

/// Frosted glass card/panel — used for the trend chart, stats, notification
/// tiles, and semester groups.
class _GlassPanel extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double borderRadius;
  final double? height;

  const _GlassPanel({
    required this.child,
    required this.isDark,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 20,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(padding: padding, child: child),
        ),
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
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
              ),
              child: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

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


