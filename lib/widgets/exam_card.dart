import 'package:flutter/material.dart';
import '../models/exam_timetable_entry.dart';

class ExamCard extends StatelessWidget {
  final ExamTimetableEntry exam;
  final bool isDark;
  final Color primary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExamCard({
    super.key,
    required this.exam,
    required this.isDark,
    required this.primary,
    required this.onEdit,
    required this.onDelete,
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
              Container(width: 6, color: Colors.orangeAccent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              exam.subjectName.isNotEmpty
                                  ? exam.subjectName
                                  : 'Unnamed Exam',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                color: primary,
                                onPressed: onEdit,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_rounded, size: 18),
                                color: Colors.redAccent,
                                onPressed: onDelete,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          )
                        ],
                      ),
                      if (exam.subjectCode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          exam.subjectCode,
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
                          if (exam.date.isNotEmpty)
                            _ExamInfoChip(
                              icon: Icons.calendar_today_rounded,
                              label: exam.date,
                              isDark: isDark,
                              color: Colors.blueAccent,
                            ),
                          if (exam.time.isNotEmpty)
                            _ExamInfoChip(
                              icon: Icons.access_time_rounded,
                              label: exam.time,
                              isDark: isDark,
                              color: Colors.orangeAccent,
                            ),
                          if (exam.location.isNotEmpty)
                            _ExamInfoChip(
                              icon: Icons.location_on_rounded,
                              label: exam.location,
                              isDark: isDark,
                              color: Colors.green,
                            ),
                          if (exam.seatNo.isNotEmpty)
                            _ExamInfoChip(
                              icon: Icons.event_seat_rounded,
                              label: 'Seat: ${exam.seatNo}',
                              isDark: isDark,
                              color: Colors.purpleAccent,
                            ),
                          if (exam.sessionNo.isNotEmpty)
                            _ExamInfoChip(
                              icon: Icons.confirmation_number_rounded,
                              label: exam.sessionNo,
                              isDark: isDark,
                              color: Colors.pinkAccent,
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

class _ExamInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color color;

  const _ExamInfoChip(
      {required this.icon, required this.label, required this.isDark, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? color.withOpacity(0.9) : color.withOpacity(0.9),
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
