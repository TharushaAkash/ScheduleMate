import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/semester.dart';

class ReportService {
  static final _primaryDark = PdfColor(30, 58, 95); // #1E3A5F
  static final _bgWhite = PdfColor(255, 255, 255);
  static final _bgLight = PdfColor(248, 249, 250);
  static final _borderGray = PdfColor(230, 230, 235);
  static final _dividerGray = PdfColor(240, 240, 245);
  static final _textDark = PdfColor(40, 40, 40);
  static final _textSubtle = PdfColor(100, 100, 100);
  static final _textWhite = PdfColor(255, 255, 255);
  static final _accentGreen = PdfColor(10, 180, 90);
  static final _accentBlue = PdfColor(30, 100, 220);
  static final _accentOrange = PdfColor(230, 126, 34);
  static final _accentRed = PdfColor(220, 50, 50);

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
            backgroundColor: const Color(0xFF1E3A5F),
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
      // Slanted Banner
      final bannerPath = PdfPath();
      final bannerTopW = pageWidth * 0.65;
      final bannerBotW = bannerTopW - 40;
      bannerPath.addLine(const Offset(0, 0), Offset(bannerTopW, 0));
      bannerPath.addLine(Offset(bannerTopW, 0), Offset(bannerBotW, 110));
      bannerPath.addLine(Offset(bannerBotW, 110), const Offset(0, 110));
      bannerPath.closeFigure();
      page.graphics.drawPath(bannerPath, brush: PdfSolidBrush(_primaryDark));
      
      // Shadow-like corner (slight accent)
      final shadowPath = PdfPath();
      shadowPath.addLine(Offset(bannerTopW, 0), Offset(bannerTopW + 10, 0));
      shadowPath.addLine(Offset(bannerTopW + 10, 0), Offset(bannerBotW + 10, 110));
      shadowPath.addLine(Offset(bannerBotW + 10, 110), Offset(bannerBotW, 110));
      shadowPath.closeFigure();
      page.graphics.drawPath(shadowPath, brush: PdfSolidBrush(PdfColor(200, 200, 200, 100)));

      // Logo Box
      _drawRoundedRect(page, 16, 16, 70, 70, _bgWhite, radius: 4);
      try {
        final ByteData data = await rootBundle.load('readme-assets/app_icon.png');
        final Uint8List imageBytes = data.buffer.asUint8List();
        final PdfBitmap image = PdfBitmap(imageBytes);
        page.graphics.drawImage(image, const Rect.fromLTWH(21, 21, 60, 60));
      } catch (e) {
        page.graphics.drawString(
          'SM',
          PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(_primaryDark),
          bounds: const Rect.fromLTWH(30, 36, 46, 40),
        );
      }

      // Title Texts
      page.graphics.drawString(
        'ScheduleMate',
        PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_textWhite),
        bounds: const Rect.fromLTWH(100, 24, 300, 30),
      );
      page.graphics.drawString(
        'Academic Result Sheet\nBachelor of Information Technology\nFaculty of Technology',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        brush: PdfSolidBrush(PdfColor(220, 220, 220)),
        bounds: const Rect.fromLTWH(100, 52, 300, 50),
        format: PdfStringFormat(lineSpacing: 4),
      );

      // GPA Box
      final gpaBoxW = pageWidth * 0.3;
      final gpaBoxX = pageWidth - gpaBoxW;
      _drawRoundedRect(page, gpaBoxX, 16, gpaBoxW, 80, _bgLight, border: _borderGray, radius: 6);
      page.graphics.drawString(
        'Overall GPA',
        PdfStandardFont(PdfFontFamily.helvetica, 9),
        brush: PdfSolidBrush(_textSubtle),
        bounds: Rect.fromLTWH(gpaBoxX + 16, 26, gpaBoxW - 32, 14),
      );
      page.graphics.drawString(
        cumulativeGpa.toStringAsFixed(2),
        PdfStandardFont(PdfFontFamily.helvetica, 28, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_primaryDark),
        bounds: Rect.fromLTWH(gpaBoxX + 14, 42, 70, 30),
      );
      page.graphics.drawString(
        '/ 4.00',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        brush: PdfSolidBrush(_textSubtle),
        bounds: Rect.fromLTWH(gpaBoxX + 70, 56, 40, 18),
      );

      String gpaStatus;
      PdfColor statusColor;
      if (cumulativeGpa >= 3.7) {
        gpaStatus = 'OUTSTANDING'; statusColor = _accentGreen;
      } else if (cumulativeGpa >= 3.0) {
        gpaStatus = 'EXCELLENT'; statusColor = _accentGreen;
      } else if (cumulativeGpa >= 2.7) {
        gpaStatus = 'GOOD'; statusColor = _accentBlue;
      } else if (cumulativeGpa >= 2.5) {
        gpaStatus = 'AVERAGE'; statusColor = _accentOrange;
      } else {
        gpaStatus = 'NEEDS WORK'; statusColor = _accentRed;
      }

      _drawRoundedRect(page, gpaBoxX + 16, 76, 70, 16, statusColor, radius: 4);
      page.graphics.drawString(
        gpaStatus,
        PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_textWhite),
        bounds: Rect.fromLTWH(gpaBoxX + 16, 78, 70, 12),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      double y = 130;

      // ── STUDENT INFO CARD ─────────────────────────────────────────────────
      final totalModules = semesters.fold<int>(0, (s, sem) => s + sem.courses.length);
      final totalCredits = semesters.fold<double>(0, (s, sem) => s + sem.totalCredits);
      final yearStr = (semesters.isNotEmpty) ? "Year ${semesters.last.year}" : "N/A";

      _drawRoundedRect(page, 0, y, pageWidth, 70, _bgWhite, border: _borderGray, radius: 8);
      
      // Profile Icon
      page.graphics.drawEllipse(
        Rect.fromLTWH(16, y + 15, 40, 40),
        brush: PdfSolidBrush(_primaryDark),
      );
      // Simple custom profile path inside circle
      page.graphics.drawEllipse(
        Rect.fromLTWH(28, y + 22, 16, 16),
        brush: PdfSolidBrush(_bgWhite),
      );
      final bodyPath = PdfPath();
      bodyPath.addArc(Rect.fromLTWH(20, y + 40, 32, 20), 180, 180);
      page.graphics.drawPath(bodyPath, brush: PdfSolidBrush(_bgWhite));

      // Info Texts
      page.graphics.drawString(
        studentName.isNotEmpty ? studentName : 'Student',
        PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_textDark),
        bounds: Rect.fromLTWH(70, y + 16, 160, 20),
      );
      page.graphics.drawString(
        'Student ID: ${studentId.isNotEmpty ? studentId : "N/A"}',
        PdfStandardFont(PdfFontFamily.helvetica, 9),
        brush: PdfSolidBrush(_textSubtle),
        bounds: Rect.fromLTWH(70, y + 36, 160, 14),
      );
      page.graphics.drawString(
        'Year: $yearStr',
        PdfStandardFont(PdfFontFamily.helvetica, 9),
        brush: PdfSolidBrush(_textSubtle),
        bounds: Rect.fromLTWH(70, y + 50, 160, 14),
      );

      // Stats
      final statTitles = ['Completed\nSemesters', 'Total Modules', 'Total Credits', 'Overall Grade'];
      final statValues = [
        '${semesters.length}',
        '$totalModules',
        totalCredits.toStringAsFixed(1),
        gpaStatus.substring(0, 1) + gpaStatus.substring(1).toLowerCase()
      ];

      final statW = (pageWidth - 240) / 4;
      for (int i = 0; i < 4; i++) {
        final sx = 240 + (i * statW);
        // Vertical divider
        if (i > 0) {
          page.graphics.drawLine(
            PdfPen(_borderGray, width: 1),
            Offset(sx, y + 15),
            Offset(sx, y + 55),
          );
        }
        
        // Draw stat
        page.graphics.drawString(
          statTitles[i],
          PdfStandardFont(PdfFontFamily.helvetica, 7),
          brush: PdfSolidBrush(_textSubtle),
          bounds: Rect.fromLTWH(sx + (i == 0 ? 0 : 4), y + 14, statW - 4, 20),
          format: PdfStringFormat(alignment: PdfTextAlignment.center, lineSpacing: 2),
        );
        page.graphics.drawString(
          statValues[i],
          PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(_textDark),
          bounds: Rect.fromLTWH(sx + (i == 0 ? 0 : 4), y + 38, statW - 4, 16),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
      }

      y += 90;

      // ── PER-SEMESTER SECTIONS ────────────────────────────────────────────
      final sortedSemesters = List<Semester>.from(semesters)
        ..sort((a, b) {
          if (a.year == b.year) return a.semesterNumber.compareTo(b.semesterNumber);
          return a.year.compareTo(b.year);
        });

      PdfPage currentPage = page;

      for (final sem in sortedSemesters) {
        final neededH = 34 + 20 + 20 * sem.courses.length + 10;
        if (y + neededH > pageHeight - 40) {
          currentPage = doc.pages.add();
          y = 36;
        }

        // Draw Semester Box Border
        _drawRoundedRect(currentPage, 0, y, pageWidth, neededH - 10, _bgWhite, border: _borderGray, radius: 6);

        // Slanted Semester Header
        final semHeadW = 160.0;
        final semSlant = 20.0;
        final semPath = PdfPath();
        final r = 6.0;
        
        semPath.addArc(Rect.fromLTWH(0, y, r * 2, r * 2), 180, 90);
        semPath.addLine(Offset(r, y), Offset(semHeadW, y));
        semPath.addLine(Offset(semHeadW, y), Offset(semHeadW - semSlant, y + 26));
        semPath.addLine(Offset(semHeadW - semSlant, y + 26), Offset(0, y + 26));
        semPath.addLine(Offset(0, y + 26), Offset(0, y + r));
        semPath.closeFigure();
        
        currentPage.graphics.drawPath(semPath, brush: PdfSolidBrush(_primaryDark));

        currentPage.graphics.drawString(
          sem.label.toUpperCase(),
          PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(_textWhite),
          bounds: Rect.fromLTWH(12, y + 7, semHeadW - 20, 14),
        );

        // Header right side text
        currentPage.graphics.drawString(
          'GPA: ${sem.semesterGpa.toStringAsFixed(2)}   |   Credits: ${sem.totalCredits.toStringAsFixed(1)}   |   ${sem.courses.length} Modules',
          PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(_textDark),
          bounds: Rect.fromLTWH(160, y + 7, pageWidth - 170, 14),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );

        y += 34;

        // Table header row
        final colW = [70.0, pageWidth - 70 - 60 - 60 - 60, 60.0, 60.0, 60.0];
        final headers = ['Code', 'Module Name', 'Credits', 'Grade', 'Points'];
        double xPos = 0;
        for (int h = 0; h < headers.length; h++) {
          currentPage.graphics.drawString(
            headers[h],
            PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
            brush: PdfSolidBrush(_textDark),
            bounds: Rect.fromLTWH(xPos + 12, y, colW[h] - 8, 14),
          );
          xPos += colW[h];
        }
        y += 18;

        // Module rows
        currentPage.graphics.drawLine(
          PdfPen(_borderGray, width: 1),
          Offset(0, y),
          Offset(pageWidth, y),
        );
        y += 4;

        for (int cIdx = 0; cIdx < sem.courses.length; cIdx++) {
          final course = sem.courses[cIdx];
          
          PdfColor gradeColor;
          if (course.grade.startsWith('A')) {
            gradeColor = _accentGreen;
          } else if (course.grade.startsWith('B')) {
            gradeColor = _accentBlue;
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
                8,
                style: isGrade ? PdfFontStyle.bold : PdfFontStyle.regular,
              ),
              brush: PdfSolidBrush(isGrade ? gradeColor : _textSubtle),
              bounds: Rect.fromLTWH(xPos + 12, y, colW[c] - 8, 14),
            );
            xPos += colW[c];
          }

          y += 16;
          // Divider between rows
          if (cIdx < sem.courses.length - 1) {
             currentPage.graphics.drawLine(
              PdfPen(_dividerGray, width: 0.5),
              Offset(10, y),
              Offset(pageWidth - 10, y),
            );
            y += 4;
          }
        }
        
        y += 24; // Space before next block
      }

      // ── FOOTER SUMMARY ────────────────────────────────────────────────────
      if (y + 80 > pageHeight - 36) {
        currentPage = doc.pages.add();
        y = 36;
      }
      
      _drawRoundedRect(currentPage, 0, y, pageWidth, 60, _bgWhite, border: _borderGray, radius: 8);

      // Trophy Icon Box
      currentPage.graphics.drawEllipse(
        Rect.fromLTWH(16, y + 10, 40, 40),
        brush: PdfSolidBrush(_primaryDark),
      );
      // Mock trophy drawing
      final tPen = PdfPen(_bgWhite, width: 1.5);
      currentPage.graphics.drawLine(tPen, Offset(30, y + 18), Offset(42, y + 18));
      currentPage.graphics.drawRectangle(pen: tPen, bounds: Rect.fromLTWH(32, y + 18, 8, 8));
      currentPage.graphics.drawLine(tPen, Offset(36, y + 26), Offset(36, y + 32));
      currentPage.graphics.drawLine(tPen, Offset(30, y + 32), Offset(42, y + 32));

      currentPage.graphics.drawString(
        'Summary',
        PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(_primaryDark),
        bounds: Rect.fromLTWH(68, y + 16, 120, 14),
      );
      currentPage.graphics.drawString(
        'Academic Performance Overview',
        PdfStandardFont(PdfFontFamily.helvetica, 8),
        brush: PdfSolidBrush(_textSubtle),
        bounds: Rect.fromLTWH(68, y + 32, 160, 12),
      );

      final totalCreditsAttempted = totalCredits; // Simplify logic
      double totalQualityPoints = semesters.fold(0, (s, sem) => s + sem.courses.fold(0, (cs, c) => cs + c.qualityPoints));

      // Right Stats
      final statWFoot = (pageWidth - 200) / 3;
      final fTitles = ['Total Points Obtained', 'Total Credits', 'Average GPA'];
      final fVals1 = [totalQualityPoints.toStringAsFixed(0), totalCreditsAttempted.toStringAsFixed(1), cumulativeGpa.toStringAsFixed(2)];
      final fVals2 = [' / ${(totalCreditsAttempted * 4.0).toStringAsFixed(0)}', '', ' / 4.00'];

      for (int i = 0; i < 3; i++) {
        final sx = 200 + (i * statWFoot);
        if (i > 0) {
          currentPage.graphics.drawLine(
            PdfPen(_borderGray, width: 1),
            Offset(sx, y + 15),
            Offset(sx, y + 45),
          );
        }
        currentPage.graphics.drawString(
          fTitles[i],
          PdfStandardFont(PdfFontFamily.helvetica, 8),
          brush: PdfSolidBrush(_textSubtle),
          bounds: Rect.fromLTWH(sx + 8, y + 16, statWFoot - 16, 12),
        );
        currentPage.graphics.drawString(
          fVals1[i],
          PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
          brush: PdfSolidBrush(_primaryDark),
          bounds: Rect.fromLTWH(sx + 8, y + 32, 30, 16),
        );
        if (fVals2[i].isNotEmpty) {
           currentPage.graphics.drawString(
            fVals2[i],
            PdfStandardFont(PdfFontFamily.helvetica, 9),
            brush: PdfSolidBrush(_textSubtle),
            bounds: Rect.fromLTWH(sx + 8 + (fVals1[i].length * 7.5), y + 35, 40, 16),
          );
        }
      }

      // ── SAVE ────────────────────────────────────────────────────────────
      final bytes = await doc.save();
      doc.dispose();

      final dir = await getTemporaryDirectory();
      final safeName = (studentName.isNotEmpty ? studentName : 'Student')
          .replaceAll(RegExp(r'[^\w]'), '_');
      final file = File('${dir.path}/${safeName}_ResultSheet_${DateTime.now().year}.pdf');
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

  static void _drawRoundedRect(
    PdfPage page,
    double x,
    double y,
    double w,
    double h,
    PdfColor color, {
    double radius = 8,
    PdfColor? border,
  }) {
    final r = radius.clamp(0.0, (w < h ? w : h) / 2);
    final path = PdfPath();
    path.addArc(Rect.fromLTWH(x, y, r * 2, r * 2), 180, 90);
    path.addArc(Rect.fromLTWH(x + w - r * 2, y, r * 2, r * 2), 270, 90);
    path.addArc(Rect.fromLTWH(x + w - r * 2, y + h - r * 2, r * 2, r * 2), 0, 90);
    path.addArc(Rect.fromLTWH(x, y + h - r * 2, r * 2, r * 2), 90, 90);
    path.closeFigure();
    
    page.graphics.drawPath(path, 
      brush: PdfSolidBrush(color),
      pen: border != null ? PdfPen(border, width: 1) : null,
    );
  }
}
