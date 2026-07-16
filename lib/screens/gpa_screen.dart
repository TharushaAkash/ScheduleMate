import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/course.dart';
import '../models/semester.dart';
import '../providers/gpa_provider.dart';

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
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
              Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Semester Statistics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Highest GPA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              Text(highest.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lowest GPA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              Text(lowest.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Average GPA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              Text(avg.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GpaProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_getGreeting()},',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black45)),
            Text(
              _studentName.isNotEmpty ? _studentName : 'Student',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87),
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
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF4A44CC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cumulative GPA',
                                style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Text(
                              provider.cumulativeGpa.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${provider.semesters.length} semester${provider.semesters.length == 1 ? '' : 's'} recorded',
                              style: const TextStyle(fontSize: 12, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 80,
                            width: 80,
                            child: CircularProgressIndicator(
                              value: provider.cumulativeGpa / 4.0,
                              strokeWidth: 7,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const Icon(Icons.school_rounded, color: Colors.white, size: 30),
                        ],
                      )
                    ],
                  ),
                ),
                _buildSemesterStats(provider.semesters, isDark),
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 12, bottom: 8, right: 20),
                  child: Row(
                    children: [
                      Container(width: 4, height: 20, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      Text('My Semesters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
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
                      child: ExpansionTile(
                        shape: const RoundedRectangleBorder(side: BorderSide.none),
                        leading: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF4A44CC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('S${semester.semesterNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ),
                        title: Text(semester.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                        subtitle: Text('GPA: ${semester.semesterGpa.toStringAsFixed(2)}  •  ${semester.totalCredits.toStringAsFixed(1)} cr', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () => provider.deleteSemester(semester.id!),
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
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add Module'),
                                onPressed: () => _showAddCourseDialog(context, semester.id!),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                  side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                        ],
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
    final creditController = TextEditingController(text: '3');
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
                creditHours: 3.0, 
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
}
