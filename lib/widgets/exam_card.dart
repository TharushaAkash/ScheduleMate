import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Map<String, String> _getCleanDateAndTime(String rawDate, String rawTime) {
    if (rawTime.isNotEmpty && rawDate.isNotEmpty) {
      return {'date': rawDate, 'time': rawTime};
    }

    String dateStr = rawDate;
    String timeStr = rawTime;

    final timeRangeRegex = RegExp(
      r'\b\d{1,2}[:.]\d{2}\s*(?:AM|PM|am|pm)?\s*(?:to|-|–|—|till|until)\s*\d{1,2}[:.]\d{2}\s*(?:AM|PM|am|pm)?\b',
      caseSensitive: false,
    );
    final singleTimeRegex = RegExp(
      r'\b\d{1,2}[:.]\d{2}\s*(?:AM|PM|am|pm)?\b',
      caseSensitive: false,
    );
    final amPmRegex = RegExp(r'\b\d{1,2}\s*(?:AM|PM|am|pm)\b', caseSensitive: false);

    if (timeStr.isEmpty && dateStr.isNotEmpty) {
      final match = timeRangeRegex.firstMatch(dateStr) ?? singleTimeRegex.firstMatch(dateStr) ?? amPmRegex.firstMatch(dateStr);
      if (match != null) {
        timeStr = match.group(0)!.trim();
        dateStr = dateStr.replaceRange(match.start, match.end, '').replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    } else if (dateStr.isEmpty && timeStr.isNotEmpty) {
      final match = timeRangeRegex.firstMatch(timeStr) ?? singleTimeRegex.firstMatch(timeStr) ?? amPmRegex.firstMatch(timeStr);
      if (match != null) {
        final extractedTime = match.group(0)!.trim();
        dateStr = timeStr.replaceRange(match.start, match.end, '').replaceAll(RegExp(r'\s+'), ' ').trim();
        timeStr = extractedTime;
      }
    }

    return {
      'date': dateStr,
      'time': timeStr,
    };
  }

  @override
  Widget build(BuildContext context) {
    const primaryAccent = Color(0xFF7C5CFF);
    const secondaryBlue = Color(0xFF3B82F6);
    const dateColor     = Color(0xFF6C5CE7);
    const timeColor     = Color(0xFFFF7675);
    const locationColor = Color(0xFF00B894);
    const seatColor     = Color(0xFF00CEC9);
    const sessionColor  = Color(0xFFFD79A8);

    final cardBg = isDark ? const Color(0xFF141728) : Colors.white;
    final cardBorder = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final textMain = isDark ? Colors.white : const Color(0xFF1E293B);

    final cleanDt = _getCleanDateAndTime(exam.date, exam.time);
    final displayDate = cleanDt['date'] ?? exam.date;
    final displayTime = cleanDt['time'] ?? exam.time;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row: Subject Code & Action Buttons ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (exam.subjectCode.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryAccent.withOpacity(0.2), secondaryBlue.withOpacity(0.2)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primaryAccent.withOpacity(0.4)),
                      ),
                      child: Text(
                        exam.subjectCode.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: primaryAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onEdit,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_rounded, size: 15, color: primaryAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5C74).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFFF5C74)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Subject Name ──
              Text(
                exam.subjectName.isNotEmpty ? exam.subjectName : 'Unnamed Exam',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 12),

              // ── COMPACT HIGHLIGHTED DATE & TIME BADGES ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Highlight Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [dateColor.withOpacity(0.18), dateColor.withOpacity(0.06)]
                              : [dateColor.withOpacity(0.10), dateColor.withOpacity(0.03)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: dateColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: dateColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.calendar_month_rounded, size: 14, color: dateColor),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DATE',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: dateColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  displayDate.isNotEmpty ? displayDate : 'N/A',
                                  maxLines: 2,
                                  softWrap: true,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textMain,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Time Highlight Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [timeColor.withOpacity(0.18), timeColor.withOpacity(0.06)]
                              : [timeColor.withOpacity(0.10), timeColor.withOpacity(0.03)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: timeColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: timeColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.schedule_rounded, size: 14, color: timeColor),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TIME',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: timeColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  displayTime.isNotEmpty ? displayTime : 'N/A',
                                  maxLines: 2,
                                  softWrap: true,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textMain,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (exam.location.isNotEmpty || exam.seatNo.isNotEmpty || exam.sessionNo.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06), height: 1),
                const SizedBox(height: 10),

                // ── Additional Chips: Location, Seat, Session ──
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (exam.location.isNotEmpty)
                      _CustomChip(
                        icon: Icons.location_on_rounded,
                        label: exam.location,
                        color: locationColor,
                        isDark: isDark,
                      ),
                    if (exam.seatNo.isNotEmpty)
                      _CustomChip(
                        icon: Icons.event_seat_rounded,
                        label: 'Seat: ${exam.seatNo}',
                        color: seatColor,
                        isDark: isDark,
                      ),
                    if (exam.sessionNo.isNotEmpty)
                      _CustomChip(
                        icon: Icons.confirmation_number_rounded,
                        label: exam.sessionNo.toLowerCase().contains('session')
                            ? exam.sessionNo
                            : 'Session: ${exam.sessionNo}',
                        color: sessionColor,
                        isDark: isDark,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _CustomChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.12) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? color.withOpacity(0.95) : color,
            ),
          ),
        ],
      ),
    );
  }
}
