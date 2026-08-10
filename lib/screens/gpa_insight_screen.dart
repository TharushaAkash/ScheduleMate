import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gpa_provider.dart';
import '../models/course.dart';
import '../models/semester.dart';

class _Palette {
  static const bgDark = Color(0xFF0F1028);
  static const bgLight = Color(0xFFF8F9FE);
  static const primary = Color(0xFF7C5CFF);
  static const secondary = Color(0xFF5B8CFF);
  static const accent = Color(0xFF00D4AA);
  static const cardDark = Color(0xFF1A1B3A);
}

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

class GpaInsightScreen extends StatefulWidget {
  const GpaInsightScreen({super.key});

  @override
  State<GpaInsightScreen> createState() => _GpaInsightScreenState();
}

class _GpaInsightScreenState extends State<GpaInsightScreen> {
  // What-If State
  final List<Course> _hypotheticalCourses = [];
  
  // Target State
  final TextEditingController _targetGpaController = TextEditingController();
  final TextEditingController _remainingCreditsController = TextEditingController(text: "15");
  
  double? _requiredGpa;

  @override
  void dispose() {
    _targetGpaController.dispose();
    _remainingCreditsController.dispose();
    super.dispose();
  }

  void _addHypotheticalCourse() {
    setState(() {
      _hypotheticalCourses.add(Course(
        semesterId: -1,
        moduleCode: 'HYP${_hypotheticalCourses.length + 1}',
        moduleName: 'Hypothetical Module',
        creditHours: 3.0,
        grade: 'A',
      ));
    });
  }

  void _removeHypotheticalCourse(int index) {
    setState(() {
      _hypotheticalCourses.removeAt(index);
    });
  }

  void _calculateTarget() {
    final targetGpa = double.tryParse(_targetGpaController.text);
    final remainingCredits = double.tryParse(_remainingCreditsController.text);
    
    if (targetGpa == null || remainingCredits == null || remainingCredits <= 0) {
      setState(() { _requiredGpa = null; });
      return;
    }

    final provider = context.read<GpaProvider>();
    double totalCredits = 0.0;
    double totalPoints = 0.0;
    
    for (final s in provider.semesters) {
      totalCredits += s.totalCredits;
      totalPoints += s.totalQualityPoints;
    }

    final totalFutureCredits = totalCredits + remainingCredits;
    final requiredTotalPoints = targetGpa * totalFutureCredits;
    final neededPoints = requiredTotalPoints - totalPoints;
    
    setState(() {
      _requiredGpa = neededPoints / remainingCredits;
    });
  }

  Widget _buildTrendAnalysis(bool isDark, GpaProvider provider) {
    if (provider.semesters.length < 2) {
      return const SizedBox.shrink();
    }
    
    final sorted = List<Semester>.from(provider.semesters)..sort((a, b) {
      if (a.year == b.year) return a.semesterNumber.compareTo(b.semesterNumber);
      return a.year.compareTo(b.year);
    });
    
    final lastGpa = sorted.last.semesterGpa;
    final prevGpa = sorted[sorted.length - 2].semesterGpa;
    final diff = lastGpa - prevGpa;
    
    String message = "";
    Color color = Colors.grey;
    IconData icon = Icons.info_outline;

    if (diff > 0.1) {
      message = "Great job! Your GPA is showing a solid upward trend. Keep applying the same study techniques.";
      color = _Palette.accent;
      icon = Icons.trending_up_rounded;
    } else if (diff > 0) {
      message = "You're steadily improving! Consistent effort is paying off.";
      color = _Palette.accent;
      icon = Icons.trending_up_rounded;
    } else if (diff > -0.1) {
      message = "Your GPA is stable. Try to identify areas for slight improvement to bump it up.";
      color = Colors.orangeAccent;
      icon = Icons.trending_flat_rounded;
    } else {
      message = "Your GPA dropped recently. Let's focus on identifying weak subjects and adjusting study habits.";
      color = Colors.redAccent;
      icon = Icons.trending_down_rounded;
    }

    return _GlassPanel(
      isDark: isDark,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trend Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text(message, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  /* Widget _buildWeakSubjects(bool isDark, GpaProvider provider) {
    final weakCourses = <Course>[];
    for (var s in provider.semesters) {
      for (var c in s.courses) {
        if (c.gradePoint < 3.0) { // Anything below B
          weakCourses.add(c);
        }
      }
    }
    
    if (weakCourses.isEmpty) {
      return _GlassPanel(
        isDark: isDark,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text("Amazing! You don't have any weak subjects. All your grades are B or above.", 
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            ),
          ],
        ),
      );
    }
    
    // Sort by lowest grade
    weakCourses.sort((a, b) => a.gradePoint.compareTo(b.gradePoint));

    return _GlassPanel(
      isDark: isDark,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Text('Subjects to Improve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          Text('These subjects have a grade below B. Focus on similar future modules.', 
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
          const SizedBox(height: 16),
          ...weakCourses.map((c) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('${c.moduleCode} - ${c.moduleName}', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(c.grade, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ))
        ],
      ),
    );
  } */

  Widget _buildTargetCalculator(bool isDark) {
    return _GlassPanel(
      isDark: isDark,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: _Palette.primary),
              const SizedBox(width: 8),
              Text('Target GPA Planner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _targetGpaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Target CGPA',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _remainingCreditsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Remaining Credits',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _calculateTarget,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Calculate Required GPA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          if (_requiredGpa != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _requiredGpa! > 4.0 
                    ? Colors.redAccent.withOpacity(0.15) 
                    : _Palette.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _requiredGpa! > 4.0 ? Colors.redAccent : _Palette.accent, width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    _requiredGpa! > 4.0 ? "Impossible Target" : "Required Average GPA",
                    style: TextStyle(fontWeight: FontWeight.bold, color: _requiredGpa! > 4.0 ? Colors.redAccent : _Palette.accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _requiredGpa!.toStringAsFixed(2),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _requiredGpa! > 4.0 ? Colors.redAccent : _Palette.accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _requiredGpa! > 4.0 
                        ? "You cannot reach this target even with straight A's (4.0) in all remaining credits."
                        : "You need to maintain this average GPA in your remaining credits to hit your target.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildWhatIfCalculator(bool isDark, GpaProvider provider) {
    double currentCredits = 0.0;
    double currentPoints = 0.0;
    
    for (final s in provider.semesters) {
      currentCredits += s.totalCredits;
      currentPoints += s.totalQualityPoints;
    }
    
    double hypotheticalCredits = currentCredits;
    double hypotheticalPoints = currentPoints;
    
    for (final c in _hypotheticalCourses) {
      hypotheticalCredits += c.creditHours;
      hypotheticalPoints += c.qualityPoints;
    }
    
    final currentGpa = currentCredits == 0 ? 0.0 : currentPoints / currentCredits;
    final predictedGpa = hypotheticalCredits == 0 ? 0.0 : hypotheticalPoints / hypotheticalCredits;
    final diff = predictedGpa - currentGpa;

    return _GlassPanel(
      isDark: isDark,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: _Palette.secondary),
                  const SizedBox(width: 8),
                  Text('What-If Simulator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              IconButton(
                onPressed: _addHypotheticalCourse,
                icon: const Icon(Icons.add_circle_outline, color: _Palette.secondary),
                tooltip: "Add Module",
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Add hypothetical grades to see how they impact your cumulative GPA.', 
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
          const SizedBox(height: 16),
          
          if (_hypotheticalCourses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Tap + to add a hypothetical module', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontStyle: FontStyle.italic)),
              ),
            ),
            
          ..._hypotheticalCourses.asMap().entries.map((entry) {
            int idx = entry.key;
            Course c = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      value: c.creditHours,
                      decoration: const InputDecoration(labelText: 'Credits', isDense: true, border: InputBorder.none),
                      items: [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0]
                          .map((v) => DropdownMenuItem(value: v, child: Text(v.toString())))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => c.creditHours = val);
                      },
                      dropdownColor: isDark ? _Palette.cardDark : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: c.grade,
                      decoration: const InputDecoration(labelText: 'Grade', isDense: true, border: InputBorder.none),
                      items: Course.gradePoints.keys
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => c.grade = val);
                      },
                      dropdownColor: isDark ? _Palette.cardDark : Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeHypotheticalCourse(idx),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  )
                ],
              ),
            );
          }),
          
          if (_hypotheticalCourses.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Current CGPA', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                    const SizedBox(height: 4),
                    Text(currentGpa.toStringAsFixed(2), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
                Icon(Icons.arrow_forward_rounded, color: isDark ? Colors.white38 : Colors.black38),
                Column(
                  children: [
                    Text('Predicted CGPA', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                    const SizedBox(height: 4),
                    Text(predictedGpa.toStringAsFixed(2), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: diff >= 0 ? _Palette.accent : Colors.redAccent)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: diff >= 0 ? _Palette.accent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(3)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: diff >= 0 ? _Palette.accent : Colors.redAccent),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _Palette.bgDark : _Palette.bgLight,
      body: Consumer<GpaProvider>(
        builder: (context, provider, child) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                floating: false,
                pinned: true,
                backgroundColor: isDark ? _Palette.bgDark : _Palette.bgLight,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    'GPA Insights',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  background: Stack(
                    children: [
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _Palette.primary.withOpacity(0.15),
                                Colors.transparent
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -20,
                        left: -40,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _Palette.accent.withOpacity(0.15),
                                Colors.transparent
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      if (provider.semesters.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text('Add some semesters and courses to get insights.', 
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else ...[
                        _buildTrendAnalysis(isDark, provider),
                        _buildWhatIfCalculator(isDark, provider),
                        _buildTargetCalculator(isDark),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}


