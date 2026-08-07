import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/assignment_provider.dart';
import '../models/assignment_model.dart';
import 'add_assignment_screen.dart';
import 'assignment_details_screen.dart';

// ── Color Palette — same as TimetableUploadScreen._Palette ──────────────
const _bgColor       = Color(0xFF0F1028);  // _Palette.bgDark
const _surfaceColor  = Color(0xFF1A1B3A);
const _primary       = Color(0xFF7C5CFF);  // _Palette.primary
const _secondary     = Color(0xFF5B8CFF);  // _Palette.secondary
const _teal          = Color(0xFF00D4AA);  // _Palette.accent
const _danger        = Color(0xFFFF5C74);
const _warning       = Color(0xFFFFB347);
const _textPrimary   = Colors.white;
const _textSecondary = Color(0xFF8A8D9F);

// ── SVG Assets ──────────────────────────────────────────────────────────────
const String _emptyStateSvg = '''
<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  <circle cx="100" cy="100" r="70" fill="#6C5CE7" fill-opacity="0.08" stroke="#6C5CE7" stroke-opacity="0.2" stroke-width="1.5"/>
  <circle cx="100" cy="100" r="50" fill="#6C5CE7" fill-opacity="0.06" stroke="#6C5CE7" stroke-opacity="0.15" stroke-width="1"/>
  <rect x="68" y="60" width="64" height="80" rx="10" fill="none" stroke="#6C5CE7" stroke-opacity="0.6" stroke-width="2"/>
  <rect x="82" y="50" width="36" height="22" rx="8" fill="none" stroke="#6C5CE7" stroke-opacity="0.6" stroke-width="2"/>
  <circle cx="100" cy="61" r="3.5" fill="#09090E" stroke="#6C5CE7" stroke-opacity="0.6" stroke-width="2"/>
  <line x1="78" y1="88"  x2="122" y2="88"  stroke="#6C5CE7" stroke-opacity="0.4" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="78" y1="103" x2="122" y2="103" stroke="#6C5CE7" stroke-opacity="0.4" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="78" y1="118" x2="104" y2="118" stroke="#6C5CE7" stroke-opacity="0.4" stroke-width="1.5" stroke-linecap="round"/>
  <circle cx="80" cy="132" r="7" fill="#22D3A6" fill-opacity="0.15" stroke="#22D3A6" stroke-opacity="0.6" stroke-width="1.5"/>
  <path d="M76 132 l3 3 l6-7" stroke="#22D3A6" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
</svg>
''';

const String _bgPatternSvg = '''
<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <pattern id="dots" x="0" y="0" width="30" height="30" patternUnits="userSpaceOnUse">
      <circle cx="15" cy="15" r="1" fill="#ffffff" fill-opacity="0.06"/>
    </pattern>
  </defs>
  <rect width="400" height="400" fill="url(#dots)"/>
</svg>
''';

// ═══════════════════════════════════════════════════════════════════════════
//  ASSIGNMENTS SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});
  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      floatingActionButton: _buildFab(context),
      body: Stack(
        children: [
          // ── Dot-grid background pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: SvgPicture.string(_bgPatternSvg, fit: BoxFit.cover),
            ),
          ),
          // ── Glow orbs — exact same as TimetableUploadScreen
          _blob(top: -120, right: -100, size: 320, color: _primary.withOpacity(0.16), blur: 150),
          _blob(top: 140, left: -140, size: 260, color: _secondary.withOpacity(0.10), blur: 150),

          Consumer<AssignmentProvider>(
            builder: (context, provider, _) {
              final assignments  = provider.sortedAssignments;
              final pendingCount = assignments.where((a) => !a.isFullyCompleted).length;
              final overdueCount = assignments.where((a) {
                final nm = a.nextMilestone;
                return nm != null && nm.deadline.isBefore(DateTime.now());
              }).length;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHeader(pendingCount, overdueCount),
                  if (assignments.isEmpty)
                    _buildEmptyState()
                  else ...[
                    if (overdueCount > 0) _buildOverdueBanner(overdueCount),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => FadeTransition(
                            opacity: _fade,
                            child: _AssignmentCard(assignment: assignments[i]),
                          ),
                          childCount: assignments.length,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  Widget _blob({double? top, double? bottom, double? left, double? right, required double size, required Color color, required double blur}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color, blurRadius: blur, spreadRadius: blur * 0.4)],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.5), blurRadius: 24, spreadRadius: 2)],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssignmentScreen())),
        backgroundColor: _primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Task', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
      ),
    );
  }

  Widget _buildHeader(int pending, int overdue) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 160,
      pinned: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tasks', style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1.2, color: _textPrimary, height: 1)),
                  const SizedBox(height: 4),
                  Text(
                    pending == 0 ? 'All caught up 🎉' : '$pending active · ${overdue > 0 ? "$overdue overdue" : "on track"}',
                    style: GoogleFonts.poppins(fontSize: 10, color: overdue > 0 ? _danger : _textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            SvgPicture.string(
              '''<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
                <rect x="10" y="14" width="28" height="30" rx="5" fill="#7C5CFF" fill-opacity="0.15" stroke="#7C5CFF" stroke-width="1.5"/>
                <rect x="18" y="9" width="12" height="10" rx="4" fill="#7C5CFF" fill-opacity="0.3" stroke="#7C5CFF" stroke-width="1.5"/>
                <circle cx="24" cy="14" r="1.5" fill="#0F1028" stroke="#7C5CFF" stroke-width="1.5"/>
                <line x1="15" y1="26" x2="33" y2="26" stroke="#7C5CFF" stroke-width="1.5" stroke-linecap="round"/>
                <line x1="15" y1="32" x2="33" y2="32" stroke="#7C5CFF" stroke-width="1.5" stroke-linecap="round"/>
                <line x1="15" y1="38" x2="24" y2="38" stroke="#7C5CFF" stroke-width="1.5" stroke-linecap="round"/>
              </svg>''',
              width: 36, height: 36,
            ),
          ],
        ),
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _buildOverdueBanner(int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _danger.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  SvgPicture.string(
                    '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M12 9v4M12 17h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" stroke="#FF5C74" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>''',
                    width: 20, height: 20,
                  ),
                  const SizedBox(width: 10),
                  Text('$count assignment${count > 1 ? "s have" : " has"} overdue milestones!',
                    style: GoogleFonts.poppins(color: _danger, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.string(_emptyStateSvg, width: 140, height: 140),
              const SizedBox(height: 28),
              Text('No Assignments Yet', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text('Tap + to add your first project', style: GoogleFonts.poppins(fontSize: 14, color: _textSecondary)),
              const SizedBox(height: 32),
              SvgPicture.string(
                '''<svg width="60" height="60" viewBox="0 0 60 60" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M30 10 Q30 35 30 45" stroke="#7C5CFF" stroke-opacity="0.5" stroke-width="2" stroke-dasharray="4 3" stroke-linecap="round"/>
                  <path d="M22 37 L30 47 L38 37" stroke="#7C5CFF" stroke-opacity="0.7" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
                </svg>''',
                width: 50, height: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ASSIGNMENT CARD  — Premium redesign
// ═══════════════════════════════════════════════════════════════════════════
class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final nm       = assignment.nextMilestone;
    final progress = assignment.progress;
    final total    = assignment.milestones.length;
    final doneC    = assignment.milestones.where((m) => m.isCompleted).length;
    bool urgent    = false;
    Color accent;

    if (assignment.isFullyCompleted) {
      accent = _teal;
    } else if (nm == null) {
      accent = _secondary;
    } else {
      final h = nm.deadline.difference(DateTime.now()).inHours;
      if (h < 0)        { accent = _danger;  urgent = true; }
      else if (h <= 24) { accent = _danger;  urgent = true; }
      else if (h <= 72) { accent = _warning; }
      else              { accent = _secondary; }
    }

    final String statusLabel = assignment.isFullyCompleted
        ? 'Completed' : urgent ? 'Urgent' : 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.22), blurRadius: 30, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AssignmentDetailsScreen(assignmentId: assignment.id),
              )),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _surfaceColor.withOpacity(0.95),
                      _surfaceColor.withOpacity(0.78),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.20), width: 1.2),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Left gradient accent stripe ──
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [accent, accent.withOpacity(0.2)],
                          ),
                        ),
                      ),

                      // ── Card body ──
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // ── Row 1: module badge + status pill ──
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(color: accent.withOpacity(0.28)),
                                    ),
                                    child: Text(assignment.moduleCode,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10, fontWeight: FontWeight.w800,
                                        color: accent, letterSpacing: 0.8)),
                                  ),
                                  const Spacer(),
                                  // Status pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: accent.withOpacity(0.22)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 5, height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle, color: accent,
                                            boxShadow: [BoxShadow(color: accent.withOpacity(0.9), blurRadius: 5)],
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(statusLabel,
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5, fontWeight: FontWeight.w700, color: accent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 9),

                              // ── Title ──
                              Text(assignment.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 15.5, fontWeight: FontWeight.w800,
                                  color: _textPrimary, letterSpacing: -0.4, height: 1.2),
                                maxLines: 1, overflow: TextOverflow.ellipsis),

                              const SizedBox(height: 5),

                              // ── Next milestone + count ──
                              Row(
                                children: [
                                  SvgPicture.string(
                                    '''<svg viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
                                      <circle cx="7" cy="7" r="5.5" stroke="${_svgHex(urgent ? _danger : _textSecondary)}" stroke-width="1.2"/>
                                      <path d="M7 4.5v2.8l1.8 1.1" stroke="${_svgHex(urgent ? _danger : _textSecondary)}" stroke-width="1.2" stroke-linecap="round"/>
                                    </svg>''',
                                    width: 13, height: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      nm != null ? 'Next: ${nm.title}' : 'All milestones done ✓',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11, color: urgent ? _danger : _textSecondary,
                                        fontWeight: urgent ? FontWeight.w600 : FontWeight.w400),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('$doneC / $total',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5, fontWeight: FontWeight.w600,
                                        color: _textSecondary)),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // ── Glowing gradient progress track ──
                              Row(
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.07),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        FractionallySizedBox(
                                          widthFactor: progress.clamp(0.0, 1.0),
                                          child: Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [accent.withOpacity(0.6), accent],
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [BoxShadow(color: accent.withOpacity(0.55), blurRadius: 8)],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Text('${(progress * 100).toInt()}%',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5, fontWeight: FontWeight.w900,
                                      color: accent,
                                      shadows: [Shadow(color: accent.withOpacity(0.7), blurRadius: 8)],
                                    )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _svgHex(Color c) => '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
}
