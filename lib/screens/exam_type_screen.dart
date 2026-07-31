import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../widgets/exam_card.dart';
import 'exam_entry_dialog.dart';

class ExamTypeScreen extends StatelessWidget {
  final String examType;

  const ExamTypeScreen({super.key, required this.examType});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    // Filter exams by type
    final typeExams = provider.examTimetable
        .where((e) => e.examType == examType)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(examType),
        backgroundColor: isDark ? const Color(0xFF252535) : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: typeExams.isEmpty
          ? Center(
              child: Text(
                'No exams found for $examType',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20).copyWith(bottom: 100),
              itemCount: typeExams.length,
              itemBuilder: (context, index) {
                final exam = typeExams[index];
                return ExamCard(
                  exam: exam,
                  isDark: isDark,
                  primary: primary,
                  onEdit: () {
                    showDialog(
                      context: context,
                      builder: (_) => ExamEntryDialog(entry: exam),
                    );
                  },
                  onDelete: () {
                    provider.deleteExamEntry(exam.id!);
                  },
                );
              },
            ),
    );
  }
}
