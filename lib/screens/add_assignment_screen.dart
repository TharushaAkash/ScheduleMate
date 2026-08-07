import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
      
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Modern Palette Matching Timetable ──
    const bgColor       = Color(0xFF0F1028);
    const surfaceColor  = Color(0xFF1A1B3A);
    const primaryAccent = Color(0xFF7C5CFF);
    const secondaryBlue = Color(0xFF5B8CFF);
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
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _saveAssignment,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primaryAccent, primaryAccent.withOpacity(0.8)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: primaryAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Center(
                    child: Text(
                      'Save',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Background Glow Orbs ──
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryAccent.withOpacity(0.16),
                boxShadow: [BoxShadow(color: primaryAccent.withOpacity(0.16), blurRadius: 150)],
              ),
            ),
          ),
          Positioned(
            top: 200, left: -140,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secondaryBlue.withOpacity(0.10),
                boxShadow: [BoxShadow(color: secondaryBlue.withOpacity(0.10), blurRadius: 150)],
              ),
            ),
          ),

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
                          Text(
                            'Project Details',
                            style: GoogleFonts.poppins(
                              color: textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // ── Title Input ──
                          Container(
                            decoration: BoxDecoration(
                              color: surfaceColor.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: TextFormField(
                              controller: _titleController,
                              style: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText: 'Assignment Title',
                                labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
                                hintText: 'e.g., Final Year Project',
                                hintStyle: GoogleFonts.poppins(color: textSecondary.withOpacity(0.5)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(20),
                                prefixIcon: const Icon(Icons.assignment_outlined, color: primaryAccent),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // ── Module Selection ──
                          Container(
                            decoration: BoxDecoration(
                              color: surfaceColor.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedModule,
                              dropdownColor: surfaceColor,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
                              style: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText: 'Module Code',
                                labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(20),
                                prefixIcon: const Icon(Icons.class_outlined, color: primaryAccent),
                              ),
                              items: moduleCodes.map((code) {
                                return DropdownMenuItem(
                                  value: code,
                                  child: Text(code),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedModule = val),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // ── Milestones Header ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Milestones',
                                    style: GoogleFonts.poppins(
                                      color: textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Break down into smaller deadlines',
                                    style: GoogleFonts.poppins(color: textSecondary, fontSize: 12),
                                  ),
                                ],
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
                              color: surfaceColor.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Milestone Number Badge
                                    Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [primaryAccent, primaryAccent.withOpacity(0.7)]),
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: primaryAccent.withOpacity(0.4), blurRadius: 6)],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
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
                                      color: bgColor.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_month_rounded, color: secondaryBlue, size: 20),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${m.deadline.day.toString().padLeft(2, '0')}/${m.deadline.month.toString().padLeft(2, '0')}/${m.deadline.year}   •   ${m.deadline.hour.toString().padLeft(2, '0')}:${m.deadline.minute.toString().padLeft(2, '0')}',
                                          style: GoogleFonts.poppins(
                                            color: textPrimary,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.edit_rounded, color: textSecondary, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
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
