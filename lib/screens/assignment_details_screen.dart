import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/assignment_model.dart';
import '../providers/assignment_provider.dart';
import 'add_assignment_screen.dart';

class AssignmentDetailsScreen extends StatelessWidget {
  final String assignmentId;

  const AssignmentDetailsScreen({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF09090E);
    const surfaceColor = Color(0xFF161622);
    const primaryAccent = Color(0xFF6C5CE7);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF8A8D9F);
    const successColor = Color(0xFF22D3A6);

    return Scaffold(
      backgroundColor: bgColor,
      body: Consumer<AssignmentProvider>(
        builder: (context, provider, child) {
          final assignment = provider.assignments.firstWhere(
            (a) => a.id == assignmentId,
            orElse: () => Assignment(
              id: '',
              title: 'Not Found',
              moduleCode: '',
              moduleName: '',
              milestones: [],
            ),
          );

          if (assignment.id.isEmpty) {
            return const Center(child: Text('Assignment not found'));
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: bgColor,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: textPrimary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddAssignmentScreen(existingAssignment: assignment),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: surfaceColor,
                          title: const Text('Delete Task?', style: TextStyle(color: textPrimary)),
                          content: const Text('Are you sure you want to delete this assignment?', style: TextStyle(color: textSecondary)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        provider.deleteAssignment(assignment.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 20, right: 24),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          assignment.moduleCode,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primaryAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        assignment.title,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  background: Stack(
                    children: [
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: assignment.isFullyCompleted 
                                ? successColor.withOpacity(0.15) 
                                : primaryAccent.withOpacity(0.15),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                          child: const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Bar
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Overall Progress',
                                  style: GoogleFonts.poppins(
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${(assignment.progress * 100).toInt()}%',
                                  style: GoogleFonts.poppins(
                                    color: assignment.isFullyCompleted ? successColor : primaryAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: assignment.progress,
                                minHeight: 8,
                                backgroundColor: bgColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  assignment.isFullyCompleted ? successColor : primaryAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      Text(
                        'Milestones',
                        style: GoogleFonts.poppins(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              // Milestones Timeline
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final m = assignment.milestones[index];
                      final isLast = index == assignment.milestones.length - 1;
                      final isOverdue = m.deadline.isBefore(DateTime.now()) && !m.isCompleted;

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline Line & Dot
                            SizedBox(
                              width: 32,
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      provider.toggleMilestone(assignment.id, m.id);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: m.isCompleted
                                            ? successColor
                                            : (isOverdue ? Colors.redAccent.withOpacity(0.2) : surfaceColor),
                                        border: Border.all(
                                          color: m.isCompleted
                                              ? successColor
                                              : (isOverdue ? Colors.redAccent : textSecondary.withOpacity(0.3)),
                                          width: 2,
                                        ),
                                      ),
                                      child: m.isCompleted
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: textSecondary.withOpacity(0.2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Milestone Content
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 24),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isOverdue ? Colors.redAccent.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.title,
                                        style: GoogleFonts.poppins(
                                          color: m.isCompleted ? textSecondary : textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          decoration: m.isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month_rounded,
                                            size: 14,
                                            color: isOverdue ? Colors.redAccent : textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${m.deadline.day}/${m.deadline.month}/${m.deadline.year} ${m.deadline.hour.toString().padLeft(2, '0')}:${m.deadline.minute.toString().padLeft(2, '0')}',
                                            style: GoogleFonts.poppins(
                                              color: isOverdue ? Colors.redAccent : textSecondary,
                                              fontSize: 12,
                                              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: assignment.milestones.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}
