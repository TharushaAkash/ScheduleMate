import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/semester.dart';

class ReportService {
  // ─── Colors (non-const since PdfColor constructor is not const) ─────────────
  static final _primary        = PdfColor(108, 99, 255);
  static final _primaryDark    = PdfColor(74, 68, 204);

  static final _accentGreen    = PdfColor(0, 212, 170);
  static final _accentRed      = PdfColor(255, 107, 157);
  static final _accentOrange   = PdfColor(230, 126, 34);
  static final _accentTeal     = PdfColor(26, 188, 156);
  static final _textWhite      = PdfColor(255, 255, 255);
  static final _textLightPurple= PdfColor(200, 200, 255);
  static final _textSubtle     = PdfColor(180, 180, 220);
  static final _bgCard         = PdfColor(240, 240, 252);
  static final _bgLight        = PdfColor(245, 245, 255);
  static final _rowAlt         = PdfColor(248, 247, 255);
  static final _tableHeader    = PdfColor(230, 228, 255);
  static final _textDarkBlue   = PdfColor(50, 50, 100);
  static final _textMidBlue    = PdfColor(80, 80, 150);
  static final _textSubBlue    = PdfColor(120, 120, 160);
  static final _divider        = PdfColor(220, 218, 240);
  static final _footerText     = PdfColor(160, 158, 200);
  static final _transparentPurple = PdfColor(108, 99, 255, 80);
  static final _transparentTeal   = PdfColor(0, 212, 170, 50);
  static final _transparentWhite  = PdfColor(255, 255, 255, 30);
  static final _semiBluePurple    = PdfColor(200, 200, 255, 180);

  static Future<void> generateAndDownloadResultSheet({
    required BuildContext context,
    required String studentName,
    required List<Semester> semesters,
    required String studentId,
    required double cumulativeGpa,
  }) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Generating Result Sheet...'),
              ],
            ),
            backgroundColor: const Color(0xFF6C63FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final doc = PdfDocument();
      doc.pageSettings.size = PdfPageSize.a4;
      doc.pageSettings.margins = PdfMargins()
        ..left = 36
        ..right = 36
        ..top = 36
        ..bottom = 36;

      final page = doc.pages.add();
      final pageWidth  = page.getClientSize().width;
      final pageHeight = page.getClientSize().height;

      // ── HEADER ──────────────────────────────────────────────────────────────
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(_primaryDark),
        bounds: Rect.fromLTWH(0, 0, pageWidth, 116),
      );

      // Decorative circles
      page.graphics.drawEllipse(
        const Rect.fromLTWH(400, -35, 150, 150),
        brush: PdfSolidBrush(_transparentPurple),
      );
      page.graphics.drawEllipse(
        const Rect.fromLTWH(445, 60, 100, 100),
        brush: PdfSolidBrush(_transparentTeal),
      );

      // Logo image
      try {
        final ByteData data = await rootBundle.load('assets/icon/app_icon.png');
        final Uint8List imageBytes = data.buffer.asUint8List();
        final PdfBitmap image = PdfBitmap(imageBytes);
        page.graphics.drawImage(image, const Rect.fromLTWH(14, 18, 62, 62));
      } catch (e) {
        // Fallback to text if image fails
        page.graphics.drawRectangle(
          brush: PdfSolidBrush(_transparentWhite),
          bounds: const Rect.fromLTWH(14, 18, 62, 62),
        );
        page.graphics.drawString(
          'SM',
          PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(_textWhite),
          bounds: const Rect.fromLTWH(22, 30, 46, 40),
        );
      }

      page.graphics.drawString(
        'ScheduleMate',
        PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_textWhite),
        bounds: Rect.fromLTWH(88, 20, pageWidth - 110, 30),
      );
      page.graphics.drawString(
        'Academic Result Sheet',
        PdfStandardFont(PdfFontFamily.helvetica, 11),
        brush: PdfSolidBrush(_textLightPurple),
        bounds: Rect.fromLTWH(88, 52, pageWidth - 110, 20),
      );

      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/'
          '${now.month.toString().padLeft(2, '0')}/${now.year}';
      page.graphics.drawString(
        'Generated: $dateStr',
        PdfStandardFont(PdfFontFamily.helvetica, 9),
        brush: PdfSolidBrush(_textSubtle),
        bounds: Rect.fromLTWH(88, 74, pageWidth - 110, 18),
      );

      double y = 132;

      // ── STUDENT INFO CARD ─────────────────────────────────────────────────
      _drawRoundedRect(page, 0, y, pageWidth, 72, _bgLight);

      page.graphics.drawString(
        studentName.isNotEmpty ? studentName : 'Student',
        PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_textDarkBlue),
        bounds: Rect.fromLTWH(14, y + 10, pageWidth - 180, 24),
      );
      page.graphics.drawString(
        'Student ID: ${studentId.isNotEmpty ? studentId : "N/A"}',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        brush: PdfSolidBrush(_textSubBlue),
        bounds: Rect.fromLTWH(14, y + 38, 240, 18),
      );
      page.graphics.drawString(
        'Faculty of Technology',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        brush: PdfSolidBrush(_textSubBlue),
        bounds: Rect.fromLTWH(14, y + 54, 200, 16),
      );

      // GPA badge
      _drawRoundedRect(page, pageWidth - 158, y + 8, 154, 56, _primary);
      page.graphics.drawString(
        'Cumulative GPA',
        PdfStandardFont(PdfFontFamily.helvetica, 8),
        brush: PdfSolidBrush(_semiBluePurple),
        bounds: Rect.fromLTWH(pageWidth - 150, y + 14, 144, 14),
      );
      page.graphics.drawString(
        cumulativeGpa.toStringAsFixed(2),
        PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_textWhite),
        bounds: Rect.fromLTWH(pageWidth - 150, y + 28, 100, 30),
      );
      page.graphics.drawString(
        '/ 4.00',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        brush: PdfSolidBrush(_textLightPurple),
        bounds: Rect.fromLTWH(pageWidth - 94, y + 38, 90, 18),
      );

      y += 88;

      // ── SUMMARY STATS ROW ────────────────────────────────────────────────
      final totalModules = semesters.fold<int>(0, (s, sem) => s + sem.courses.length);
      final totalCredits = semesters.fold<double>(0, (s, sem) => s + sem.totalCredits);

      String gpaStatus;
      PdfColor statusColor;
      if (cumulativeGpa >= 3.7) {
        gpaStatus = 'Outstanding'; statusColor = _accentGreen;
      } else if (cumulativeGpa >= 3.0) {
        gpaStatus = 'Excellent'; statusColor = _primary;
      } else if (cumulativeGpa >= 2.7) {
        gpaStatus = 'Good'; statusColor = _accentTeal;
      } else if (cumulativeGpa >= 2.5) {
        gpaStatus = 'Average'; statusColor = _accentOrange;
      } else {
        gpaStatus = 'Needs Work'; statusColor = _accentRed;
      }

      final statsItems = [
        ['Semesters', '${semesters.length}'],
        ['Total Modules', '$totalModules'],
        ['Total Credits', totalCredits.toStringAsFixed(1)],
        ['Status', gpaStatus],
      ];

      final statW = (pageWidth - 12) / 4;
      for (int i = 0; i < statsItems.length; i++) {
        final sx = i * (statW + 4);
        final isLast = i == 3;
        _drawRoundedRect(page, sx, y, statW, 52, isLast ? statusColor : _bgCard);
        page.graphics.drawString(
          statsItems[i][0],
          PdfStandardFont(PdfFontFamily.helvetica, 8),
          brush: PdfSolidBrush(isLast ? _semiBluePurple : _textSubBlue),
          bounds: Rect.fromLTWH(sx + 8, y + 8, statW - 16, 14),
        );
        page.graphics.drawString(
          statsItems[i][1],
          PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(isLast ? _textWhite : _textDarkBlue),
          bounds: Rect.fromLTWH(sx + 8, y + 26, statW - 16, 22),
        );
      }

      y += 64;

      // ── PER-SEMESTER SECTIONS ────────────────────────────────────────────
      final sortedSemesters = List<Semester>.from(semesters)
        ..sort((a, b) {
          if (a.year == b.year) return a.semesterNumber.compareTo(b.semesterNumber);
          return a.year.compareTo(b.year);
        });

      PdfPage currentPage = page;

      for (final sem in sortedSemesters) {
        final neededH = 36 + 22 + 22 * sem.courses.length + 28;
        if (y + neededH > pageHeight - 40) {
          currentPage = doc.pages.add();
          y = 20;
        }

        // Semester header bar
        _drawRoundedRect(currentPage, 0, y, pageWidth, 32, _primaryDark);
        currentPage.graphics.drawString(
          sem.label,
          PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(_textWhite),
          bounds: Rect.fromLTWH(10, y + 8, 240, 18),
        );
        currentPage.graphics.drawString(
          'GPA: ${sem.semesterGpa.toStringAsFixed(2)}   |   Credits: ${sem.totalCredits.toStringAsFixed(1)}   |   ${sem.courses.length} modules',
          PdfStandardFont(PdfFontFamily.helvetica, 9),
          brush: PdfSolidBrush(_textLightPurple),
          bounds: Rect.fromLTWH(260, y + 10, pageWidth - 270, 16),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        y += 36;

        // Table header row
        _drawRoundedRect(currentPage, 0, y, pageWidth, 22, _tableHeader);
        final colW = [84.0, pageWidth - 84 - 52 - 52 - 60, 52.0, 52.0, 60.0];
        final headers = ['Code', 'Module Name', 'Credits', 'Grade', 'Pts'];
        double xPos = 0;
        for (int h = 0; h < headers.length; h++) {
          currentPage.graphics.drawString(
            headers[h],
            PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
            brush: PdfSolidBrush(_textMidBlue),
            bounds: Rect.fromLTWH(xPos + 6, y + 5, colW[h] - 8, 14),
          );
          xPos += colW[h];
        }
        y += 22;

        // Module rows
        bool alt = false;
        for (final course in sem.courses) {
          if (y + 22 > pageHeight - 40) {
            currentPage = doc.pages.add();
            y = 20;
          }
          if (alt) {
            currentPage.graphics.drawRectangle(
              brush: PdfSolidBrush(_rowAlt),
              bounds: Rect.fromLTWH(0, y, pageWidth, 22),
            );
          }

          PdfColor gradeColor;
          if (course.grade.startsWith('A')) {
            gradeColor = _accentGreen;
          } else if (course.grade.startsWith('B')) {
            gradeColor = _primary;
          } else if (course.grade.startsWith('C')) {
            gradeColor = _accentOrange;
          } else {
            gradeColor = _accentRed;
          }

          xPos = 0;
          final rowData = [
            course.moduleCode,
            course.moduleName,
            course.creditHours.toStringAsFixed(1),
            course.grade,
            course.qualityPoints.toStringAsFixed(2),
          ];
          for (int c = 0; c < rowData.length; c++) {
            final isGrade = c == 3;
            currentPage.graphics.drawString(
              rowData[c],
              PdfStandardFont(
                PdfFontFamily.helvetica,
                9,
                style: isGrade ? PdfFontStyle.bold : PdfFontStyle.regular,
              ),
              brush: PdfSolidBrush(isGrade ? gradeColor : _textDarkBlue),
              bounds: Rect.fromLTWH(xPos + 6, y + 4, colW[c] - 8, 14),
            );
            xPos += colW[c];
          }

          currentPage.graphics.drawLine(
            PdfPen(_divider, width: 0.5),
            Offset(0, y + 22),
            Offset(pageWidth, y + 22),
          );
          y += 22;
          alt = !alt;
        }

        // GPA progress bar for this semester
        y += 4;
        if (y + 14 > pageHeight - 40) {
          currentPage = doc.pages.add();
          y = 20;
        }
        currentPage.graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(220, 218, 255)),
          bounds: Rect.fromLTWH(0, y, pageWidth, 6),
        );
        currentPage.graphics.drawRectangle(
          brush: PdfSolidBrush(_primary),
          bounds: Rect.fromLTWH(0, y, (sem.semesterGpa / 4.0) * pageWidth, 6),
        );
        y += 18;
      }

      // ── SUMMARY TABLE ────────────────────────────────────────────────────
      if (y + 60 > pageHeight - 40) {
        currentPage = doc.pages.add();
        y = 20;
      }
      y += 8;

      _drawRoundedRect(currentPage, 0, y, pageWidth, 28, _primaryDark);
      currentPage.graphics.drawString(
        '  Semester GPA Summary',
        PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_textWhite),
        bounds: Rect.fromLTWH(8, y + 6, 220, 18),
      );
      y += 32;

      for (final sem in sortedSemesters) {
        if (y + 24 > pageHeight - 40) {
          currentPage = doc.pages.add();
          y = 20;
        }
        _drawRoundedRect(currentPage, 0, y, pageWidth, 22, _bgCard);
        currentPage.graphics.drawString(
          sem.label,
          PdfStandardFont(PdfFontFamily.helvetica, 9),
          brush: PdfSolidBrush(_textMidBlue),
          bounds: Rect.fromLTWH(10, y + 5, 200, 14),
        );
        currentPage.graphics.drawString(
          '${sem.courses.length} modules  •  ${sem.totalCredits.toStringAsFixed(1)} credits  •  GPA: ${sem.semesterGpa.toStringAsFixed(2)}',
          PdfStandardFont(PdfFontFamily.helvetica, 9),
          brush: PdfSolidBrush(_primary),
          bounds: Rect.fromLTWH(pageWidth - 260, y + 5, 256, 14),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        y += 24;
      }

      // Final cumulative GPA row
      y += 8;
      if (y + 38 > pageHeight - 20) {
        currentPage = doc.pages.add();
        y = 20;
      }
      _drawRoundedRect(currentPage, 0, y, pageWidth, 38, _primary);
      currentPage.graphics.drawString(
        '  FINAL CUMULATIVE GPA',
        PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_textWhite),
        bounds: Rect.fromLTWH(10, y + 10, 200, 18),
      );
      currentPage.graphics.drawString(
        '${cumulativeGpa.toStringAsFixed(2)} / 4.00  ─  $gpaStatus',
        PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_textWhite),
        bounds: Rect.fromLTWH(pageWidth - 226, y + 10, 222, 18),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );

      // ── FOOTER ─────────────────────────────────────────────────────────
      final lastPage = doc.pages[doc.pages.count - 1];
      final lastH = lastPage.getClientSize().height;
      lastPage.graphics.drawLine(
        PdfPen(PdfColor(200, 198, 240), width: 0.5),
        Offset(0, lastH - 26),
        Offset(pageWidth, lastH - 26),
      );
      lastPage.graphics.drawString(
        'Generated by ScheduleMate  •  $dateStr  •  Unofficial Academic Record',
        PdfStandardFont(PdfFontFamily.helvetica, 8),
        brush: PdfSolidBrush(_footerText),
        bounds: Rect.fromLTWH(0, lastH - 20, pageWidth, 16),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // ── SAVE ────────────────────────────────────────────────────────────
      final bytes = await doc.save();
      doc.dispose();

      final dir = await getTemporaryDirectory();
      final safeName = (studentName.isNotEmpty ? studentName : 'Student')
          .replaceAll(RegExp(r'[^\w]'), '_');
      final file = File('${dir.path}/${safeName}_ResultSheet_${now.year}.pdf');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'ScheduleMate Academic Result Sheet',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Draws a filled rectangle with slightly rounded corners using a PdfPath.
  static void _drawRoundedRect(
    PdfPage page,
    double x,
    double y,
    double w,
    double h,
    PdfColor color, {
    double radius = 8,
  }) {
    final r = radius.clamp(0.0, (w < h ? w : h) / 2);
    final path = PdfPath();
    // Top-left arc
    path.addArc(Rect.fromLTWH(x, y, r * 2, r * 2), 180, 90);
    // Top-right arc
    path.addArc(Rect.fromLTWH(x + w - r * 2, y, r * 2, r * 2), 270, 90);
    // Bottom-right arc
    path.addArc(Rect.fromLTWH(x + w - r * 2, y + h - r * 2, r * 2, r * 2), 0, 90);
    // Bottom-left arc
    path.addArc(Rect.fromLTWH(x, y + h - r * 2, r * 2, r * 2), 90, 90);
    path.closeFigure();
    page.graphics.drawPath(path, brush: PdfSolidBrush(color));
  }
}
