import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'auth_screen.dart';
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      _processPdf(result.files.single.path!, result.files.single.name);
    }
  }

  Future<void> _processPdf(String path, String fileName) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await File(path).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText(layoutText: true);

      final lines = text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      List<Map<String, dynamic>> newMarks = [];

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains(_studentId!)) {
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
            moduleName = fileName.replaceAll('.pdf', '');
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

          newMarks.add({
            'moduleCode': moduleCode,
            'moduleName': moduleName,
            'marks': marksMap,
          });
        }
      }

      if (newMarks.isEmpty) {
        setState(() {
          _errorMessage =
              "Student ID $_studentId not found in the PDF.";
          _isLoading = false;
        });
      } else {
        await _saveMarksData(newMarks);
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('${newMarks.length} module(s) extracted!'),
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
      document.dispose();
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to process PDF: $e";
        _isLoading = false;
      });
    }
  }

  static const _moduleColors = [
    Color(0xFF6C63FF),
    Color(0xFF00D4AA),
    Color(0xFFFF6B9D),
    Color(0xFFFFB347),
    Color(0xFF4ECDC4),
    Color(0xFF45B7D1),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: isDark ? const Color(0xFF252535) : Colors.white,
            actions: [
              if (_savedMarks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded),
                    tooltip: 'Clear All',
                    onPressed: _clearMarks,
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'CA Marks',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0D3B2E), const Color(0xFF252535)]
                        : [const Color(0xFF00D4AA), const Color(0xFF00A080)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Student ID banner
                    if (_studentId == null || _studentId!.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.4), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Student ID is not set. Go to Profile to save it.',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: primary.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user_rounded,
                                color: primary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Fetching results for: ',
                              style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontSize: 13),
                            ),
                            Text(
                              _studentId!,
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Upload Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _uploadPdf,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(
                          _isLoading ? 'Processing...' : 'Upload Result PDF',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4AA),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_savedMarks.isEmpty && !_isLoading) ...[
                      const SizedBox(height: 60),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.description_outlined,
                                  size: 56, color: primary.withOpacity(0.6)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No marks uploaded yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a result PDF to see your CA marks here',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_savedMarks.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Results (${_savedMarks.length})',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._savedMarks.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final marks =
                            Map<String, dynamic>.from(item['marks']);
                        final color =
                            _moduleColors[index % _moduleColors.length];
                        return _MarkCard(
                          moduleCode: item['moduleCode'] ?? 'Unknown',
                          moduleName: item['moduleName'] ?? '',
                          marks: marks,
                          color: color,
                          isDark: isDark,
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
    );
  }
}

class _MarkCard extends StatefulWidget {
  final String moduleCode;
  final String moduleName;
  final Map<String, dynamic> marks;
  final Color color;
  final bool isDark;
  final VoidCallback onDelete;

  const _MarkCard({
    required this.moduleCode,
    required this.moduleName,
    required this.marks,
    required this.color,
    required this.isDark,
    required this.onDelete,
  });

  @override
  State<_MarkCard> createState() => _MarkCardState();
}

class _MarkCardState extends State<_MarkCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF252535) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: widget.color.withOpacity(widget.isDark ? 0.2 : 0.08),
                border: Border(
                  left: BorderSide(color: widget.color, width: 5),
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.moduleCode,
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.moduleName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: widget.isDark ? Colors.white54 : Colors.black38,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                  ),
                ],
              ),
            ),
            // Marks body
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: widget.marks.entries.map((e) {
                    final isHighlight = e.key.toLowerCase().contains('ca') ||
                        e.key.toLowerCase().contains('mark') ||
                        e.key.toLowerCase().contains('total');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              e.key,
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.isDark
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isHighlight
                                  ? widget.color.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              e.value.toString(),
                              style: TextStyle(
                                fontWeight: isHighlight
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14,
                                color: isHighlight
                                    ? widget.color
                                    : (widget.isDark
                                        ? Colors.white
                                        : Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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
