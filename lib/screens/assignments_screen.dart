import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/assignment_provider.dart';
import '../models/assignment_model.dart';
import 'add_assignment_screen.dart';
import 'assignment_details_screen.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF09090E);
    const surfaceColor = Color(0xFF161622);
    const primaryAccent = Color(0xFF6C5CE7);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF8A8D9F);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddAssignmentScreen(),
            ),
          );
        },
        backgroundColor: primaryAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'New Task',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Animated / Glowing Background Blobs
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryAccent.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: primaryAccent.withOpacity(0.2),
                    blurRadius: 120,
                    spreadRadius: 60,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            right: -150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D4AA).withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4AA).withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          Consumer<AssignmentProvider>(
            builder: (context, provider, child) {
              final assignments = provider.sortedAssignments;
              final pendingCount =
                  assignments.where((a) => !a.isFullyCompleted).length;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Modern Header
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    expandedHeight: 140,
                    pinned: true,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      title: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tasks',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pendingCount == 0
                                ? 'All caught up! 🎉'
                                : '$pendingCount tasks in progress',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (assignments.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.task_alt_rounded,
                              size: 64,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Assignments Yet',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to add your first project.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return FadeTransition(
                          opacity: _fadeAnim,
                          child: _AssignmentCard(assignment: assignments[index]),
                        );
                      },
                      childCount: assignments.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;

  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    const surfaceColor = Color(0xFF161622);
    const dangerColor = Color(0xFFFF5C74);
    const warningColor = Color(0xFFFFB020);
    const successColor = Color(0xFF22D3A6);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF8A8D9F);

    final nextMilestone = assignment.nextMilestone;
    bool isUrgent = false;
    bool isWarning = false;
    Color glowColor = Colors.transparent;

    if (nextMilestone != null) {
      final hoursLeft = nextMilestone.deadline.difference(DateTime.now()).inHours;
      if (hoursLeft < 0) {
        // Overdue
        isUrgent = true;
        glowColor = dangerColor;
      } else if (hoursLeft <= 24) {
        // Due within 24h
        isUrgent = true;
        glowColor = dangerColor;
      } else if (hoursLeft <= 72) {
        // Due within 3 days
        isWarning = true;
        glowColor = warningColor;
      } else {
        glowColor = successColor;
      }
    }

    if (assignment.isFullyCompleted) {
      glowColor = successColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isUrgent || isWarning || assignment.isFullyCompleted)
              ? glowColor.withOpacity(0.4)
              : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          if (isUrgent || assignment.isFullyCompleted)
            BoxShadow(
              color: glowColor.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignmentDetailsScreen(assignmentId: assignment.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Progress Indicator
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: assignment.progress,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          color: assignment.isFullyCompleted ? successColor : glowColor,
                          strokeWidth: 4,
                        ),
                        Center(
                          child: assignment.isFullyCompleted
                              ? const Icon(Icons.check_rounded, color: successColor)
                              : Text(
                                  '${(assignment.progress * 100).toInt()}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: glowColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            assignment.moduleCode,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: glowColor == Colors.transparent
                                  ? textSecondary
                                  : glowColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          assignment.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              size: 14,
                              color: isUrgent ? dangerColor : textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                nextMilestone != null
                                    ? 'Next: ${nextMilestone.title}'
                                    : 'All Milestones Completed',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isUrgent ? dangerColor : textSecondary,
                                  fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
