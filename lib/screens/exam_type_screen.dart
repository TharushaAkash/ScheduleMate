import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    final typeExams = provider.examTimetable
        .where((e) => e.examType == examType)
        .toList();

    const bgColorDark = Color(0xFF080B1A);
    const bgColorLight = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: isDark ? bgColorDark : bgColorLight,
      appBar: AppBar(
        title: Text(
          examType,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF0F172A)),
      ),
      body: typeExams.isEmpty
          ? Center(
              child: Text(
                'No exams found for $examType',
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16).copyWith(bottom: 100),
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
