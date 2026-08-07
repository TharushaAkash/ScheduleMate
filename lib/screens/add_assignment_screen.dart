import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/assignment_model.dart';
import '../providers/assignment_provider.dart';
import '../providers/gpa_provider.dart';

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
    const bgColor = Color(0xFF09090E);
    const surfaceColor = Color(0xFF161622);
    const primaryAccent = Color(0xFF6C5CE7);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF8A8D9F);

    // Extract modules from GPA Provider to link assignments to real modules
    final gpaProvider = Provider.of<GpaProvider>(context);
    List<String> moduleCodes = [];
    for (var sem in gpaProvider.semesters) {
      for (var mod in sem.courses) {
        if (!moduleCodes.contains(mod.moduleCode)) {
          moduleCodes.add(mod.moduleCode);
        }
      }
    }
    // Also allow some defaults just in case
    if (moduleCodes.isEmpty) moduleCodes = ['General', 'Other'];
    if (_selectedModule != null && !moduleCodes.contains(_selectedModule)) {
      moduleCodes.add(_selectedModule!);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.existingAssignment != null ? 'Edit Task' : 'New Task',
          style: GoogleFonts.poppins(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveAssignment,
            child: Text(
              'Save',
              style: GoogleFonts.poppins(
                color: primaryAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Assignment Details
                    Text(
                      'Project Details',
                      style: GoogleFonts.poppins(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Assignment Title',
                        labelStyle: const TextStyle(color: textSecondary),
                        hintText: 'e.g., Final Year Project',
                        hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.assignment_outlined, color: textSecondary),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedModule,
                      dropdownColor: surfaceColor,
                      style: const TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Module Code',
                        labelStyle: const TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.class_outlined, color: textSecondary),
                      ),
                      items: moduleCodes.map((code) {
                        return DropdownMenuItem(
                          value: code,
                          child: Text(code),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedModule = val),
                    ),

                    const SizedBox(height: 40),
                    
                    // Milestones Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Milestones',
                          style: GoogleFonts.poppins(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: _addMilestone,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add, size: 16, color: primaryAccent),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Step',
                                  style: GoogleFonts.poppins(
                                    color: primaryAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Break down your assignment into smaller deadlines (e.g. Document, UI Design, Final Code).',
                      style: GoogleFonts.poppins(color: textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            // Milestones List
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
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: primaryAccent.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.poppins(
                                      color: primaryAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: m.title,
                                  style: const TextStyle(color: textPrimary, fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Milestone Title',
                                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (val) => m.title = val,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setState(() => _milestones.removeAt(index));
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _pickDateTime(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, color: textSecondary, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${m.deadline.day}/${m.deadline.month}/${m.deadline.year} at ${m.deadline.hour.toString().padLeft(2, '0')}:${m.deadline.minute.toString().padLeft(2, '0')}',
                                    style: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.edit_calendar_rounded, color: primaryAccent, size: 18),
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
    );
  }
}
