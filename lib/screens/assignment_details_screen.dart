import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/assignment_model.dart';
import '../providers/assignment_provider.dart';
import 'add_assignment_screen.dart';

// ── Color Palette — same as TimetableUploadScreen._Palette ──────────────
const _bgColor       = Color(0xFF0F1028);  // _Palette.bgDark
const _surfaceColor  = Color(0xFF1A1B3A);
const _primary       = Color(0xFF7C5CFF);  // _Palette.primary
const _teal          = Color(0xFF00D4AA);  // _Palette.accent
const _danger        = Color(0xFFFF5C74);
const _warning       = Color(0xFFFFB347);
const _textPrimary   = Colors.white;
const _textSecondary = Color(0xFF8A8D9F);

class AssignmentDetailsScreen extends StatelessWidget {
  final String assignmentId;
  const AssignmentDetailsScreen({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Consumer<AssignmentProvider>(
        builder: (context, provider, _) {
          final assignment = provider.assignments.firstWhere(
            (a) => a.id == assignmentId,
            orElse: () => Assignment(id: '', title: 'Not Found', moduleCode: '', moduleName: '', milestones: []),
          );
          if (assignment.id.isEmpty) {
            return const Center(child: Text('Assignment not found', style: TextStyle(color: Colors.white)));
          }

          final accent = assignment.isFullyCompleted ? _teal : _primary;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, assignment, accent, provider),
              SliverToBoxAdapter(child: _buildBody(context, assignment, provider, accent)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar(BuildContext context, Assignment assignment, Color accent, AssignmentProvider provider) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 220,
      backgroundColor: _bgColor,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: _textPrimary),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AddAssignmentScreen(existingAssignment: assignment),
          )),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: _danger),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: _surfaceColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('Delete Task?', style: GoogleFonts.poppins(color: _textPrimary, fontWeight: FontWeight.w700)),
                content: Text('This will permanently delete this assignment and all its milestones.', style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins(color: _textSecondary))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.poppins(color: _danger, fontWeight: FontWeight.w700))),
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
        titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: Text(assignment.moduleCode, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 6),
            Text(assignment.title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        background: Stack(
          children: [
            // Dot grid
            Positioned.fill(
              child: Opacity(
                opacity: 0.4,
                child: SvgPicture.string(
                  '''<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
                    <defs>
                      <pattern id="d" x="0" y="0" width="28" height="28" patternUnits="userSpaceOnUse">
                        <circle cx="14" cy="14" r="1" fill="#ffffff" fill-opacity="0.1"/>
                      </pattern>
                    </defs>
                    <rect width="400" height="300" fill="url(#d)"/>
                  </svg>''',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Glow orbs — exact same as TimetableUploadScreen
            Positioned(top: -120, right: -100, child: Container(width: 320, height: 320,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: _primary.withOpacity(0.16),
                boxShadow: [BoxShadow(color: _primary.withOpacity(0.16), blurRadius: 150)]))),
            Positioned(top: 60, left: -140, child: Container(width: 260, height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: const Color(0xFF5B8CFF).withOpacity(0.10),
                boxShadow: [BoxShadow(color: const Color(0xFF5B8CFF).withOpacity(0.10), blurRadius: 150)]))),
            // SVG decorative clipboard icon
            Positioned(
              right: 10, top: 30,
              child: Opacity(
                opacity: 0.65,
                child: SvgPicture.string(
                  '''<svg width="130" height="130" viewBox="0 0 130 130" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <rect x="25" y="30" width="80" height="90" rx="12" fill="${_svgHex(accent)}" fill-opacity="0.12" stroke="${_svgHex(accent)}" stroke-opacity="0.5" stroke-width="1.5"/>
                    <rect x="45" y="20" width="40" height="22" rx="8" fill="${_svgHex(accent)}" fill-opacity="0.2" stroke="${_svgHex(accent)}" stroke-opacity="0.5" stroke-width="1.5"/>
                    <circle cx="65" cy="31" r="3.5" fill="#09090E" stroke="${_svgHex(accent)}" stroke-opacity="0.7" stroke-width="1.5"/>
                    <line x1="38" y1="58" x2="92" y2="58" stroke="${_svgHex(accent)}" stroke-opacity="0.5" stroke-width="1.5" stroke-linecap="round" stroke-dasharray="5 3"/>
                    <line x1="38" y1="72" x2="92" y2="72" stroke="${_svgHex(accent)}" stroke-opacity="0.5" stroke-width="1.5" stroke-linecap="round"/>
                    <line x1="38" y1="86" x2="70" y2="86" stroke="${_svgHex(accent)}" stroke-opacity="0.5" stroke-width="1.5" stroke-linecap="round"/>
                    <circle cx="44" cy="104" r="9" fill="#22D3A6" fill-opacity="0.15" stroke="#22D3A6" stroke-opacity="0.6" stroke-width="1.5"/>
                    <path d="M39 104 l4 4 l8-9" stroke="#22D3A6" stroke-opacity="0.9" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
                  </svg>''',
                  width: 130, height: 130,
                ),
              ),
            ),
            // Blur gradient
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, _bgColor.withOpacity(0.6)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, Assignment assignment, AssignmentProvider provider, Color accent) {
    final total     = assignment.milestones.length;
    final completed = assignment.milestones.where((m) => m.isCompleted).length;
    final overdue   = assignment.milestones.where((m) => !m.isCompleted && m.deadline.isBefore(DateTime.now())).length;
    final inProg    = total - completed - overdue;

    DateTime? endDate = assignment.milestones.isNotEmpty
      ? assignment.milestones.map((e) => e.deadline).reduce((a, b) => a.isAfter(b) ? a : b)
      : null;

    String timeLeft = 'N/A';
    Color timeColor = _textSecondary;
    if (endDate != null) {
      if (assignment.isFullyCompleted) {
        timeLeft = 'Completed'; timeColor = _teal;
      } else {
        final diff = endDate.difference(DateTime.now());
        if (diff.isNegative) { timeLeft = 'Overdue!'; timeColor = _danger; }
        else { timeLeft = '${diff.inDays}d ${diff.inHours % 24}h'; timeColor = diff.inDays < 3 ? _warning : _primary; }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats Row ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _statCard('Total', total, _primary)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Done', completed, _teal)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Active', inProg, _warning)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Overdue', overdue, _danger)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Progress Card ────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: _surfaceColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Stack(
                  children: [
                    // Inline SVG pattern
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SvgPicture.string(
                          '''<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%">
                            <defs>
                              <pattern id="g" width="36" height="36" patternUnits="userSpaceOnUse">
                                <circle cx="18" cy="18" r="0.9" fill="#ffffff" fill-opacity="0.09"/>
                                <path d="M 36 0 L 0 36" stroke="#ffffff" stroke-width="0.3" stroke-opacity="0.04"/>
                              </pattern>
                            </defs>
                            <rect width="100%" height="100%" fill="url(#g)"/>
                            <circle cx="90%" cy="30%" r="60" fill="${_svgHex(accent)}" fill-opacity="0.06"/>
                          </svg>''',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Overall Progress', style: GoogleFonts.poppins(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                                  Text(assignment.isFullyCompleted ? 'Project complete 🎉' : 'Keep going!', style: GoogleFonts.poppins(color: _textSecondary, fontSize: 11)),
                                ],
                              ),
                              Container(
                                width: 60, height: 60,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CircularProgressIndicator(
                                      value: assignment.progress,
                                      strokeWidth: 5,
                                      backgroundColor: Colors.white.withOpacity(0.07),
                                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                                    ),
                                    Center(child: Text('${(assignment.progress * 100).toInt()}%',
                                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: accent))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: assignment.progress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withOpacity(0.07),
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(height: 1, color: Colors.white.withOpacity(0.05)),
                          const SizedBox(height: 16),
                          // Date row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _dateInfo('Start', assignment.createdAt),
                              _vertDiv(),
                              _dateInfo('End', endDate),
                              _vertDiv(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Time Left', style: GoogleFonts.poppins(fontSize: 10, color: _textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(timeLeft, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: timeColor)),
                                ],
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
          const SizedBox(height: 28),

          // ── Milestones Header ─────────────────────────────────────────────
          Row(
            children: [
              SvgPicture.string(
                '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z" stroke="#6C5CE7" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                  <line x1="4" y1="22" x2="4" y2="15" stroke="#6C5CE7" stroke-width="2" stroke-linecap="round"/>
                </svg>''',
                width: 22, height: 22,
              ),
              const SizedBox(width: 8),
              Text('Milestones', style: GoogleFonts.poppins(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const Spacer(),
              Text('${assignment.milestones.length} total', style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Milestone Timeline ────────────────────────────────────────────
          ...List.generate(assignment.milestones.length, (i) {
            final m       = assignment.milestones[i];
            final isLast  = i == assignment.milestones.length - 1;
            final overdue = !m.isCompleted && m.deadline.isBefore(DateTime.now());
            final mAccent = m.isCompleted ? _teal : (overdue ? _danger : _primary);

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline column
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final p = Provider.of<AssignmentProvider>(context, listen: false);
                            p.toggleMilestone(assignment.id, m.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mAccent.withOpacity(m.isCompleted ? 1.0 : 0.12),
                              border: Border.all(color: mAccent, width: 2),
                              boxShadow: [BoxShadow(color: mAccent.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)],
                            ),
                            child: m.isCompleted
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : (overdue ? const Icon(Icons.priority_high, size: 14, color: _danger) : null),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [mAccent.withOpacity(0.4), Colors.white.withOpacity(0.05)],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Card
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: m.isCompleted
                                ? _teal.withOpacity(0.06)
                                : (overdue ? _danger.withOpacity(0.06) : _surfaceColor.withOpacity(0.9)),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: mAccent.withOpacity(0.3), width: 1.5),
                            ),
                            child: Stack(
                              children: [
                                // small corner glow
                                Positioned(top: -10, right: -10, child: Container(width: 50, height: 50,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: mAccent.withOpacity(0.1)))),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(m.title,
                                              style: GoogleFonts.poppins(
                                                fontSize: 15, fontWeight: FontWeight.w700,
                                                color: mAccent,
                                                decoration: m.isCompleted ? TextDecoration.lineThrough : null,
                                                decorationColor: _teal,
                                              ),
                                            ),
                                          ),
                                          // status chip
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: mAccent.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              m.isCompleted ? 'Done' : (overdue ? 'Overdue' : 'Pending'),
                                              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: mAccent),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          SvgPicture.string(
                                            '''<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                                              <rect x="2" y="3" width="12" height="11" rx="2" stroke="${_svgHex(mAccent)}" stroke-opacity="0.8" stroke-width="1.3"/>
                                              <line x1="2" y1="7" x2="14" y2="7" stroke="${_svgHex(mAccent)}" stroke-opacity="0.8" stroke-width="1.3"/>
                                              <line x1="6" y1="1" x2="6" y2="5" stroke="${_svgHex(mAccent)}" stroke-opacity="0.8" stroke-width="1.3" stroke-linecap="round"/>
                                              <line x1="10" y1="1" x2="10" y2="5" stroke="${_svgHex(mAccent)}" stroke-opacity="0.8" stroke-width="1.3" stroke-linecap="round"/>
                                            </svg>''',
                                            width: 13, height: 13,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '${m.deadline.day}/${m.deadline.month}/${m.deadline.year}  ${m.deadline.hour.toString().padLeft(2,'0')}:${m.deadline.minute.toString().padLeft(2,'0')}',
                                            style: GoogleFonts.poppins(fontSize: 11, color: mAccent.withOpacity(0.8),
                                              fontWeight: overdue ? FontWeight.w600 : FontWeight.normal),
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
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _statCard(String title, int val, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(val.toString(), style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(title, style: GoogleFonts.poppins(fontSize: 9, color: _textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateInfo(String label, DateTime? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: _textSecondary)),
        const SizedBox(height: 3),
        Text(date != null ? '${date.day}/${date.month}/${date.year}' : 'N/A',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: _textPrimary)),
      ],
    );
  }

  Widget _vertDiv() => Container(width: 1, height: 32, color: Colors.white.withOpacity(0.08));

  static String _svgHex(Color c) => '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
}
