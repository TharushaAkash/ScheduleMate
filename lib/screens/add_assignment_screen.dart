import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'home_screen.dart';
import '../models/assignment_model.dart';
import '../providers/assignment_provider.dart';
import '../providers/timetable_provider.dart';

class AddAssignmentScreen extends StatefulWidget {
  final Assignment? existingAssignment;

  const AddAssignmentScreen({super.key, this.existingAssignment});

  @override
  State<AddAssignmentScreen> createState() => _AddAssignmentScreenState();
}

class _AddAssignmentScreenState extends State<AddAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  String? _selectedModule;
  List<Milestone> _milestones = [];
  bool _isGeneratingAI = false;

  Future<void> _showAIGenerateDialog() async {
    final promptController = TextEditingController();
    String pdfText = '';
    String pdfName = '';
    DateTime? targetDeadline;
    
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1B3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 10),
                  Text('AI Task Breakdown', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Describe your assignment. The AI will break it down into manageable milestones via n8n automation.',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: promptController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'e.g., Final year project on Network Security. I have 2 weeks to complete it.',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF0F1028),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      FilePickerResult? result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                      if (result != null) {
                        try {
                          setDialogState(() => _isGeneratingAI = true);
                          final file = File(result.files.single.path!);
                          final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());
                          String text = PdfTextExtractor(document).extractText();
                          document.dispose();
                          
                          setDialogState(() {
                            pdfName = result.files.single.name;
                            pdfText = text;
                            _isGeneratingAI = false;
                          });
                        } catch (e) {
                          setDialogState(() => _isGeneratingAI = false);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to read PDF')));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, size: 20, color: pdfName.isNotEmpty ? const Color(0xFF6C5CE7) : Colors.white70),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              pdfName.isNotEmpty ? pdfName : 'Attach Assignment PDF (Optional)',
                              style: GoogleFonts.poppins(color: pdfName.isNotEmpty ? Colors.white : Colors.white70, fontSize: 12, fontWeight: pdfName.isNotEmpty ? FontWeight.w600 : FontWeight.normal),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pdfName.isNotEmpty)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF6C5CE7), size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => targetDeadline = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 20, color: targetDeadline != null ? const Color(0xFF6C5CE7) : Colors.white70),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              targetDeadline != null ? 'Target Deadline: ${targetDeadline!.toIso8601String().split('T')[0]}' : 'Set Target Deadline (Optional)',
                              style: GoogleFonts.poppins(color: targetDeadline != null ? Colors.white : Colors.white70, fontSize: 12, fontWeight: targetDeadline != null ? FontWeight.w600 : FontWeight.normal),
                            ),
                          ),
                          if (targetDeadline != null)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF6C5CE7), size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: _isGeneratingAI ? null : () async {
                    if (promptController.text.trim().isEmpty && pdfText.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a description or upload a PDF.')));
                      return;
                    }
                    setDialogState(() => _isGeneratingAI = true);
                    
                    try {
                      String textResult = '';
                      
                      final todayStr = DateTime.now().toIso8601String().split('T')[0];
                      final deadlineStr = targetDeadline != null ? '\nIMPORTANT: The overall target deadline for this assignment is ${targetDeadline!.toIso8601String().split('T')[0]}. If the prompt or PDF does not specify exact dates, use this target deadline to logically space out the milestones.' : '\nIf no specific dates are given in the prompt, space them out logically starting from today.';
                      
                      final promptText = '''
You are an AI task planner. Today's date is $todayStr.
Break down the following project/assignment into 3 to 5 logical milestones.
For beginners, include initial planning steps like sketching UI, drawing ER diagrams, documentation, setup, etc.
Analyze any specific dates or deadlines mentioned in the assignment description. Assign an exact deadline date for each milestone in YYYY-MM-DD format based on the prompt's instructions.$deadlineStr
Return ONLY a valid JSON object in this exact format, with no markdown formatting or extra text:
{"milestones": [{"title": "Step name here", "description": "Short description of what to do", "deadline_date": "2024-05-20", "subtasks": [{"title": "Subtask 1", "hours": 4}, {"title": "Subtask 2", "hours": 2}]}]}

Assignment description: ${promptController.text}
${pdfText.isNotEmpty ? '\nExtracted PDF Content for context:\n$pdfText' : ''}
''';
                      
                      if (pdfText.isNotEmpty) {
                        // GROQ API for File Uploads
                        final groqKey = dotenv.env['GROQ_API_KEY'] ?? '';
                        final endpoint = 'https://api.groq.com/openai/v1/chat/completions';
                        
                        final response = await http.post(
                          Uri.parse(endpoint),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $groqKey',
                          },
                          body: json.encode({
                            'model': 'llama-3.3-70b-versatile',
                            'messages': [{'role': 'user', 'content': promptText}],
                            'response_format': {'type': 'json_object'}
                          }),
                        );
                        
                        if (response.statusCode == 200) {
                          final data = json.decode(response.body);
                          textResult = data['choices'][0]['message']['content'];
                        } else {
                          print('Groq API Error: ${response.body}');
                          throw Exception('Groq API Failed');
                        }
                      } else {
                        // GEMINI API for Prompts without file
                        final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? ''; 
                        final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$geminiKey';
                        
                        final response = await http.post(
                          Uri.parse(endpoint),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'contents': [{'parts': [{'text': promptText}]}],
                            'generationConfig': {'responseMimeType': 'application/json'}
                          }),
                        );
                        
                        if (response.statusCode == 200) {
                          final data = json.decode(response.body);
                          textResult = data['candidates'][0]['content']['parts'][0]['text'];
                        } else {
                          print('Gemini API Error: ${response.body}');
                          throw Exception('Gemini API Failed');
                        }
                      }
                      
                      final jsonData = json.decode(textResult);
                      final List milestonesData = jsonData['milestones'] ?? [];
                        
                        setState(() {
                          for (var m in milestonesData) {
                            List<SubTask> parsedSubTasks = [];
                            if (m['subtasks'] != null) {
                              for (var s in m['subtasks']) {
                                parsedSubTasks.add(SubTask(
                                  title: s['title'] ?? 'Subtask',
                                  estimatedHours: s['hours'] ?? 0,
                                ));
                              }
                            }
                            DateTime parsedDate;
                            try {
                              parsedDate = DateTime.parse(m['deadline_date']);
                            } catch (e) {
                              parsedDate = DateTime.now().add(const Duration(days: 1));
                            }
                            
                            _milestones.add(Milestone(
                              title: m['title'] ?? 'Generated Task',
                              description: m['description'] ?? '',
                              deadline: parsedDate,
                              subtasks: parsedSubTasks,
                            ));
                          }
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasks generated successfully!')));
                    } catch (e) {
                      print('Exception: $e');
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error generating tasks. Please try again.')));
                    } finally {
                      setDialogState(() => _isGeneratingAI = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isGeneratingAI
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Generate', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingAssignment != null) {
      _titleController = TextEditingController(text: widget.existingAssignment!.title);
      _selectedModule = widget.existingAssignment!.moduleCode;
      _milestones = List.from(widget.existingAssignment!.milestones);
    } else {
      _titleController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _addMilestone() {
    setState(() {
      _milestones.add(Milestone(
        title: '',
        deadline: DateTime.now().add(const Duration(days: 1)),
      ));
    });
  }

  Future<void> _pickDateTime(int index) async {
    final current = _milestones[index].deadline;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 4)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C5CE7),
            surface: Color(0xFF161622),
          ),
        ),
        child: child!,
      ),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C5CE7),
              surface: Color(0xFF161622),
            ),
          ),
          child: child!,
        ),
      );

      if (time != null) {
        setState(() {
          _milestones[index].deadline = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _saveAssignment() {
    if (_formKey.currentState!.validate()) {
      if (_selectedModule == null || _selectedModule!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a module')),
        );
        return;
      }
      
      if (_milestones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one milestone deadline')),
        );
        return;
      }

      // Check if all milestones have titles
      for (var m in _milestones) {
        if (m.title.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a title for all milestones')),
          );
          return;
        }
      }

      final provider = Provider.of<AssignmentProvider>(context, listen: false);
      
      if (widget.existingAssignment != null) {
        final updated = Assignment(
          id: widget.existingAssignment!.id,
          title: _titleController.text.trim(),
          moduleCode: _selectedModule!,
          moduleName: '',
          milestones: _milestones,
          createdAt: widget.existingAssignment!.createdAt,
        );
        provider.updateAssignment(updated);
      } else {
        final newAssignment = Assignment(
          title: _titleController.text.trim(),
          moduleCode: _selectedModule!,
          moduleName: '',
          milestones: _milestones,
        );
        provider.addAssignment(newAssignment);
      }
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 3)), // 3 is Assignments tab
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Design Tokens ──
    const bgColor       = Color(0xFF080B1A);
    const surfaceColor  = Color(0xFF151829);
    const cardColor     = Color(0xFF111427);
    const primaryAccent = Color(0xFF7C5CFF);
    const secondaryBlue = Color(0xFF3B82F6);
    const teal          = Color(0xFF00D4AA);
    const textPrimary   = Colors.white;
    const textSecondary = Color(0xFF8A8D9F);
    const dangerRed     = Color(0xFFFF5C74);

    // Extract modules from TimetableProvider
    final timetableProvider = Provider.of<TimetableProvider>(context);
    List<String> moduleCodes = [];
    for (var entry in timetableProvider.currentTimetable) {
      if (entry.moduleCode.isNotEmpty && !moduleCodes.contains(entry.moduleCode)) {
        moduleCodes.add(entry.moduleCode);
      }
    }
    if (moduleCodes.isEmpty) moduleCodes = ['General', 'Other'];
    if (_selectedModule != null && !moduleCodes.contains(_selectedModule)) {
      moduleCodes.add(_selectedModule!);
    }

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.existingAssignment != null ? 'Edit Task' : 'New Task',
          style: GoogleFonts.poppins(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 18),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _saveAssignment,
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [primaryAccent, secondaryBlue]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: primaryAccent.withOpacity(0.45), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text('Save', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Ambient Orbs ──
          Positioned(top: -80, right: -60, child: Container(width: 260, height: 260,
            decoration: BoxDecoration(shape: BoxShape.circle, color: primaryAccent.withOpacity(0.15),
              boxShadow: [BoxShadow(color: primaryAccent.withOpacity(0.15), blurRadius: 130)]))),
          Positioned(top: 200, left: -100, child: Container(width: 200, height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle, color: secondaryBlue.withOpacity(0.08),
              boxShadow: [BoxShadow(color: secondaryBlue.withOpacity(0.08), blurRadius: 130)]))),

          SafeArea(
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: primaryAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: primaryAccent.withOpacity(0.25)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.description_rounded, size: 14, color: primaryAccent),
                              const SizedBox(width: 6),
                              Text('PROJECT DETAILS', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: primaryAccent, letterSpacing: 1)),
                            ]),
                          ),
                          const SizedBox(height: 20),
                          
                          // ── Title Input ──
                          Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: TextFormField(
                              controller: _titleController,
                              style: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText: 'Assignment Title',
                                labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
                                hintText: 'e.g., Final Year Project',
                                hintStyle: GoogleFonts.poppins(color: textSecondary.withOpacity(0.4)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(18),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.only(left: 12, right: 8),
                                  child: Icon(Icons.assignment_outlined, color: primaryAccent, size: 20),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // ── Module Selection ──
                          Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedModule,
                              dropdownColor: cardColor,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
                              style: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText: 'Module Code',
                                labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(18),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.only(left: 12, right: 8),
                                  child: Icon(Icons.class_outlined, color: secondaryBlue, size: 20),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                              ),
                              items: moduleCodes.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                              onChanged: (val) => setState(() => _selectedModule = val),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // ── Milestones Header ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Section badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: secondaryBlue.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: secondaryBlue.withOpacity(0.25)),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.flag_rounded, size: 14, color: secondaryBlue),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'MILESTONES',
                                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: secondaryBlue, letterSpacing: 1),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ]),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Break down into deadlines',
                                      style: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: _showAIGenerateDialog,
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [const Color(0xFF00D4AA).withOpacity(0.2), const Color(0xFF00D4AA).withOpacity(0.1)]),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFF00D4AA).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF00D4AA)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'AI Split',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF00D4AA),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _addMilestone,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [primaryAccent.withOpacity(0.2), primaryAccent.withOpacity(0.1)]),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: primaryAccent.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.add_rounded, size: 18, color: primaryAccent),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Add Step',
                                            style: GoogleFonts.poppins(
                                              color: primaryAccent,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ── Milestones List ──
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final m = _milestones[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Milestone Number Badge
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: secondaryBlue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: GoogleFonts.poppins(
                                            color: secondaryBlue,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Title Input
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: m.title,
                                        style: GoogleFonts.poppins(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                                        decoration: InputDecoration(
                                          hintText: 'Milestone Name',
                                          hintStyle: GoogleFonts.poppins(color: textSecondary.withOpacity(0.5), fontWeight: FontWeight.normal),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                          border: InputBorder.none,
                                        ),
                                        onChanged: (val) => m.title = val,
                                      ),
                                    ),
                                    // Delete Button
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline_rounded, color: dangerRed.withOpacity(0.8), size: 22),
                                      onPressed: () {
                                        setState(() => _milestones.removeAt(index));
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // DateTime Picker Button
                                GestureDetector(
                                  onTap: () => _pickDateTime(index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_month_rounded, color: primaryAccent, size: 20),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${m.deadline.day.toString().padLeft(2, '0')}/${m.deadline.month.toString().padLeft(2, '0')}/${m.deadline.year}   •   ${m.deadline.hour.toString().padLeft(2, '0')}:${m.deadline.minute.toString().padLeft(2, '0')}',
                                          style: GoogleFonts.poppins(
                                            color: textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.edit_rounded, color: textSecondary, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                if (m.description.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    m.description,
                                    style: GoogleFonts.poppins(color: textSecondary, fontSize: 13, height: 1.5),
                                  ),
                                ],
                                
                                if (m.subtasks.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: bgColor.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.format_list_bulleted_rounded, color: textSecondary, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Subtasks Generated by AI',
                                              style: GoogleFonts.poppins(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        ...m.subtasks.map((s) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.radio_button_unchecked_rounded, color: textSecondary.withOpacity(0.4), size: 18),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(s.title, style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500)),
                                                    if (s.estimatedHours > 0) ...[
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          Icon(Icons.access_time_rounded, color: teal, size: 12),
                                                          const SizedBox(width: 4),
                                                          Text('${s.estimatedHours}h estimated', style: GoogleFonts.poppins(color: teal, fontSize: 11, fontWeight: FontWeight.w500)),
                                                        ],
                                                      ),
                                                    ]
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )).toList(),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                        childCount: _milestones.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



