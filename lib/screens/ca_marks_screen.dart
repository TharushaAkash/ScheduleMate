import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'auth_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class CaMarksScreen extends StatefulWidget {
  const CaMarksScreen({super.key});

  @override
  State<CaMarksScreen> createState() => _CaMarksScreenState();
}

class _CaMarksScreenState extends State<CaMarksScreen>
    with SingleTickerProviderStateMixin {
  String? _studentId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _savedMarks = [];
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentId = prefs.getString('student_id');
      final savedJson = prefs.getString('saved_ca_marks');
      if (savedJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(savedJson);
          _savedMarks =
              decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (e) {
          _savedMarks = [];
        }
      }
    });
  }

  Future<void> _saveMarksData(List<Map<String, dynamic>> newMarks) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> updatedMarks = List.from(_savedMarks);
    for (var mark in newMarks) {
      int existingIndex = updatedMarks.indexWhere((m) =>
          m['moduleCode'] == mark['moduleCode'] &&
          m['moduleName'] == mark['moduleName']);
      if (existingIndex != -1) {
        updatedMarks[existingIndex] = mark;
      } else {
        updatedMarks.add(mark);
      }
    }
    await prefs.setString('saved_ca_marks', jsonEncode(updatedMarks));
    setState(() => _savedMarks = updatedMarks);
  }

  Future<void> _clearMarks() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Marks'),
        content: const Text('This will delete all saved CA marks. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_ca_marks');
      setState(() => _savedMarks = []);
    }
  }

  Future<void> _deleteMark(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> updatedMarks = List.from(_savedMarks);
    updatedMarks.removeAt(index);
    await prefs.setString('saved_ca_marks', jsonEncode(updatedMarks));
    setState(() => _savedMarks = updatedMarks);
  }

  Future<void> _uploadPdf() async {
    await _loadData();
    if (_studentId == null || _studentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Please set your Student ID in Profile first.')),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    AuthScreen.bypassNextLifecycleLock = true;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      _processPdfs(result.files);
    }
  }

  Future<void> _processPdfs(List<PlatformFile> files) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Map<String, dynamic>> allNewMarks = [];
      int notFoundCount = 0;

      for (var file in files) {
        if (file.path == null) continue;
        final bytes = await File(file.path!).readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        final text = extractor.extractText(layoutText: true);

        final lines = text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        bool foundInThisPdf = false;

        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains(_studentId!)) {
            foundInThisPdf = true;
            String safeId = _studentId!.replaceAll(' ', '_');
            String studentLine = lines[i].replaceAll(_studentId!, safeId);

            List<String> studentData = studentLine
                .split(RegExp(r'\s{2,}|\t'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            if (studentData.length <= 1) {
              studentData = studentLine
                  .split(RegExp(r'\s+'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }

            int idIndex = studentData.indexOf(safeId);
            if (idIndex != -1 && idIndex + 1 < studentData.length) {
              int nameStart = idIndex + 1;
              int nameEnd = nameStart;
              while (nameEnd < studentData.length &&
                  !RegExp(r'\d').hasMatch(studentData[nameEnd])) {
                nameEnd++;
              }
              if (nameEnd > nameStart + 1) {
                String mergedName =
                    studentData.sublist(nameStart, nameEnd).join(' ');
                studentData.replaceRange(nameStart, nameEnd, [mergedName]);
              }
            }

            List<String> headers = [];
            for (int j = i - 1; j >= 0; j--) {
              var pHeader = lines[j]
                  .split(RegExp(r'\s{2,}|\t'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (pHeader.length <= 1) {
                pHeader = lines[j]
                    .split(RegExp(r'\s+'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
              bool hasHeaderWords = pHeader.any((h) {
                final lower = h.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
                return [
                  'no','sno','id','reg','regno','name','mark','ca','index','student','total','grade'
                ].contains(lower);
              });
              if (hasHeaderWords && pHeader.length > 1) {
                String joined = pHeader.join(' ');
                joined = joined.replaceAll(
                    RegExp(r'(Reg|Registration)\s+No', caseSensitive: false),
                    'Reg_No');
                joined = joined.replaceAll(
                    RegExp(r'(Index|Student)\s+No', caseSensitive: false),
                    'Index_No');
                joined = joined.replaceAll(
                    RegExp(r'Student\s+Name', caseSensitive: false),
                    'Student_Name');
                joined = joined.replaceAll(
                    RegExp(r'CA\s+Mark(s?)', caseSensitive: false), 'CA_Mark');
                joined = joined.replaceAll(
                    RegExp(r'Final\s+Mark(s?)', caseSensitive: false),
                    'Final_Mark');
                headers = joined
                    .split(RegExp(r'\s+'))
                    .map((e) => e.replaceAll('_', ' ').trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                break;
              }
            }

            String moduleCode = "Unknown";
            String moduleName = "Module Name";
            for (int j = i - 1; j >= 0; j--) {
              final match =
                  RegExp(r'([A-Za-z]{2,3}\s?\d{3,4})\s*(.*)').firstMatch(lines[j]);
              if (match != null) {
                moduleCode = match.group(1)!.trim();
                moduleName = match.group(2)!.trim();
                if (moduleName.startsWith('-')) {
                  moduleName = moduleName.substring(1).trim();
                }
                break;
              }
            }

            if (moduleCode == "Unknown") {
              moduleName = file.name.replaceAll('.pdf', '');
            }

            Map<String, String> marksMap = {};
            if (studentData.isEmpty) {
              marksMap['Raw'] = lines[i];
            } else {
              for (int k = 0; k < studentData.length; k++) {
                String header =
                    k < headers.length ? headers[k] : "Col ${k + 1}";
                if (header.isEmpty) header = "Col ${k + 1}";
                String key = header;
                int counter = 1;
                while (marksMap.containsKey(key)) {
                  key = "$header ($counter)";
                  counter++;
                }
                marksMap[key] = studentData[k];
              }
            }

            allNewMarks.add({
              'moduleCode': moduleCode,
              'moduleName': moduleName,
              'marks': marksMap,
            });
          }
        }
        
        if (!foundInThisPdf) {
          notFoundCount++;
        }
        document.dispose();
      }

      if (allNewMarks.isEmpty) {
        setState(() {
          _errorMessage =
              "Student ID $_studentId not found in ${files.length == 1 ? 'the PDF' : 'any of the selected PDFs'}.";
          _isLoading = false;
        });
      } else {
        await _saveMarksData(allNewMarks);
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${allNewMarks.length} module(s) extracted!' +
                      (notFoundCount > 0 ? ' ($notFoundCount PDF(s) skipped)' : '')
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF00D4AA),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to parse PDF(s). Please try again.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0B1020);
    const surfaceColor = Color(0xFF111827);
    const surfaceLightColor = Color(0xFF161B2F);
    const primaryPurple = Color(0xFF6D5DF6);
    const tealColor = Color(0xFF14D8B4);
    const dangerColor = Color(0xFFFF5C74);
    const textPrimary = Color(0xFFFFFFFF);
    const textSecondary = Color(0xFFA8B0C5);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 140,
              backgroundColor: bgColor,
              surfaceTintColor: Colors.transparent,
              actions: [
                if (_savedMarks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: dangerColor),
                        tooltip: 'Clear All',
                        onPressed: _clearMarks,
                      ),
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 24, bottom: 20, right: 24),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CA Marks',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check your continuous assessment results',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), bgColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Card
                      if (_studentId == null || _studentId!.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF332310),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.orange.withOpacity(0.4), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Student ID is not set. Go to Profile to save it.',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange,
                                      fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: tealColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.fingerprint_rounded, color: tealColor, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fetching results for:',
                                      style: GoogleFonts.poppins(
                                          color: textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _studentId!,
                                      style: GoogleFonts.poppins(
                                        color: tealColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 28),

                      // Upload Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [tealColor, Color(0xFF0EA5E9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tealColor.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _uploadPdf,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isLoading)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                )
                              else
                                const Icon(Icons.upload_file_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                _isLoading ? 'Processing...' : 'Upload Result PDF',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: dangerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: dangerColor.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: dangerColor, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_errorMessage!,
                                    style: GoogleFonts.poppins(color: dangerColor, fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_savedMarks.isEmpty && !_isLoading) ...[
                        const SizedBox(height: 80),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20),
                                  ],
                                ),
                                child: const Icon(Icons.folder_open_rounded, size: 64, color: textSecondary),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No results found',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload a PDF to extract your continuous assessment marks',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_savedMarks.isNotEmpty) ...[
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                color: primaryPurple,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Results (${_savedMarks.length})',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: surfaceLightColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.filter_list_rounded, color: textSecondary, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ..._savedMarks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final marks = Map<String, dynamic>.from(item['marks']);
                          return _MarkCard(
                            moduleCode: item['moduleCode'] ?? 'Unknown',
                            moduleName: item['moduleName'] ?? '',
                            marks: marks,
                            onDelete: () => _deleteMark(index),
                          );
                        }).toList(),
                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkCard extends StatefulWidget {
  final String moduleCode;
  final String moduleName;
  final Map<String, dynamic> marks;
  final VoidCallback onDelete;

  const _MarkCard({
    required this.moduleCode,
    required this.moduleName,
    required this.marks,
    required this.onDelete,
  });

  @override
  State<_MarkCard> createState() => _MarkCardState();
}

class _MarkCardState extends State<_MarkCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    const surfaceColor = Color(0xFF111827);
    const surfaceLightColor = Color(0xFF161B2F);
    const primaryPurple = Color(0xFF6D5DF6);
    const textPrimary = Color(0xFFFFFFFF);
    const textSecondary = Color(0xFFA8B0C5);
    const dangerColor = Color(0xFFFF5C74);
    const successColor = Color(0xFF22D3A6);
    const highlightColor = Color(0xFF8B7CFF);

    // Try to find a 'total', 'ca', 'mark', or 'final' score.
    String scoreValue = '--';
    String finalKey = '';
    for (var key in widget.marks.keys) {
      final k = key.toLowerCase();
      if (k.contains('total') || k.contains('final') || k.contains('ca') || k.contains('mark') || k.contains('score')) {
        scoreValue = widget.marks[key].toString();
        finalKey = key;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131524),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryPurple.withOpacity(0.3)),
                    ),
                    child: Text(
                      widget.moduleCode,
                      style: GoogleFonts.poppins(
                        color: highlightColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.moduleName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F36),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: dangerColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: dangerColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Expanded Info Rows
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    ...widget.marks.entries.where((e) => e.key != finalKey).map((e) {
                      IconData iconData = Icons.info_outline_rounded;
                      if (e.key.toLowerCase().contains('reg') || e.key.toLowerCase().contains('id')) {
                        iconData = Icons.sell_rounded;
                      } else if (e.key.toLowerCase().contains('name') || e.key.toLowerCase().contains('student')) {
                        iconData = Icons.person_rounded;
                      } else if (e.key.toLowerCase().contains('no') || e.key.toLowerCase().contains('sno')) {
                        iconData = Icons.badge_rounded;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Row(
                          children: [
                            Icon(iconData, size: 18, color: primaryPurple.withOpacity(0.8)),
                            const SizedBox(width: 16),
                            Text(
                              e.key,
                              style: GoogleFonts.poppins(fontSize: 12, color: textSecondary),
                            ),
                            const Spacer(),
                            Text(
                              e.value.toString(),
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F36),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryPurple.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.star_rounded, color: highlightColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              finalKey.isNotEmpty ? finalKey : 'Marks Obtained',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [primaryPurple, highlightColor],
                            ).createShader(bounds),
                            child: Text(
                              scoreValue,
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (double.tryParse(scoreValue) != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '/ 100',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

