import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
                      Positioned(
                        right: -30,
                        top: 20,
                        child: Transform.rotate(
                          angle: 0.2,
                          child: Opacity(
                            opacity: 0.8,
                            child: SvgPicture.string(
                              '''<svg width="200" height="200" viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
                                  <rect x="50" y="40" width="100" height="130" rx="15" fill="#6C5CE7" fill-opacity="0.1" stroke="#6C5CE7" stroke-width="2"/>
                                  <rect x="75" y="25" width="50" height="30" rx="10" fill="#6C5CE7" fill-opacity="0.3" stroke="#6C5CE7" stroke-width="2"/>
                                  <circle cx="100" cy="40" r="5" fill="#09090E" stroke="#6C5CE7" stroke-width="2"/>
                                  
                                  <path d="M 70 80 L 130 80" stroke="#6C5CE7" stroke-width="2" stroke-linecap="round"/>
                                  <path d="M 70 100 L 130 100" stroke="#6C5CE7" stroke-width="2" stroke-linecap="round"/>
                                  <path d="M 70 120 L 100 120" stroke="#6C5CE7" stroke-width="2" stroke-linecap="round"/>
                                  
                                  <circle cx="70" cy="145" r="10" fill="#22D3A6" fill-opacity="0.2" stroke="#22D3A6" stroke-width="2"/>
                                  <path d="M 65 145 L 68 148 L 75 140" stroke="#22D3A6" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                                </svg>''',
                              width: 180,
                              height: 180,
                            ),
                          ),
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
                      // Stats Row
                      Builder(
                        builder: (context) {
                          final total = assignment.milestones.length;
                          final completed = assignment.milestones.where((m) => m.isCompleted).length;
                          final overdue = assignment.milestones.where((m) => !m.isCompleted && m.deadline.isBefore(DateTime.now())).length;
                          final inProgress = total - completed - overdue;
                          
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatCard('Total', total, primaryAccent),
                              _buildStatCard('Completed', completed, successColor),
                              _buildStatCard('In Progress', inProgress, const Color(0xFFFFB020)),
                              _buildStatCard('Overdue', overdue, const Color(0xFFFF5C74)),
                            ],
                          );
                        }
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Progress Bar & Project Dates
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              // Abstract SVG Pattern Background
                              Positioned.fill(
                                child: SvgPicture.string(
                                  '''<svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
                                      <defs>
                                        <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
                                          <circle cx="20" cy="20" r="1" fill="#ffffff" fill-opacity="0.1"/>
                                          <path d="M 40 0 L 0 40" fill="none" stroke="#ffffff" stroke-width="0.5" stroke-opacity="0.03"/>
                                        </pattern>
                                        <linearGradient id="fade" x1="0" y1="0" x2="0" y2="1">
                                          <stop offset="0%" stop-color="#161622" stop-opacity="0.8"/>
                                          <stop offset="100%" stop-color="#161622" stop-opacity="1"/>
                                        </linearGradient>
                                      </defs>
                                      <rect width="100%" height="100%" fill="url(#grid)" />
                                      <rect width="100%" height="100%" fill="url(#fade)" />
                                    </svg>''',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Overall Progress',
                                  style: GoogleFonts.poppins(
                                    color: textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (assignment.isFullyCompleted ? successColor : primaryAccent).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${(assignment.progress * 100).toInt()}%',
                                    style: GoogleFonts.poppins(
                                      color: assignment.isFullyCompleted ? successColor : primaryAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: assignment.progress,
                                minHeight: 10,
                                backgroundColor: bgColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  assignment.isFullyCompleted ? successColor : primaryAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Divider(color: Colors.white.withOpacity(0.05)),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                DateTime? endDate;
                                if (assignment.milestones.isNotEmpty) {
                                  endDate = assignment.milestones.map((e) => e.deadline).reduce((a, b) => a.isAfter(b) ? a : b);
                                }
                                
                                String timeLeft = 'N/A';
                                Color timeColor = textSecondary;
                                if (endDate != null) {
                                  if (assignment.isFullyCompleted) {
                                    timeLeft = 'Completed';
                                    timeColor = successColor;
                                  } else {
                                    final diff = endDate.difference(DateTime.now());
                                    if (diff.isNegative) {
                                      timeLeft = 'Deadline Passed';
                                      timeColor = const Color(0xFFFF5C74);
                                    } else {
                                      timeLeft = '${diff.inDays}d ${diff.inHours % 24}h remaining';
                                      timeColor = diff.inDays < 3 ? const Color(0xFFFFB020) : primaryAccent;
                                    }
                                  }
                                }

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildDateInfo('Start Date', assignment.createdAt),
                                    Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
                                    _buildDateInfo('End Date', endDate),
                                    Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Time Left', style: GoogleFonts.poppins(fontSize: 10, color: textSecondary)),
                                        const SizedBox(height: 4),
                                        Text(
                                          timeLeft,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: timeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }
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
                ),
              ),
              
              // Milestones Heading
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: primaryAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Milestones',
                        style: GoogleFonts.poppins(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

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
                                    color: m.isCompleted
                                        ? successColor.withOpacity(0.05)
                                        : (isOverdue ? Colors.redAccent.withOpacity(0.05) : surfaceColor),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: m.isCompleted
                                          ? successColor.withOpacity(0.3)
                                          : (isOverdue ? Colors.redAccent.withOpacity(0.4) : primaryAccent.withOpacity(0.2)),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.title,
                                        style: GoogleFonts.poppins(
                                          color: m.isCompleted ? successColor : (isOverdue ? Colors.redAccent : textPrimary),
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
                                            color: m.isCompleted ? successColor.withOpacity(0.7) : (isOverdue ? Colors.redAccent : textSecondary),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${m.deadline.day}/${m.deadline.month}/${m.deadline.year} ${m.deadline.hour.toString().padLeft(2, '0')}:${m.deadline.minute.toString().padLeft(2, '0')}',
                                            style: GoogleFonts.poppins(
                                              color: m.isCompleted ? successColor.withOpacity(0.7) : (isOverdue ? Colors.redAccent : textSecondary),
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

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: const Color(0xFF8A8D9F),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, DateTime? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF8A8D9F))),
        const SizedBox(height: 4),
        Text(
          date != null ? '${date.day}/${date.month}/${date.year}' : 'N/A',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
