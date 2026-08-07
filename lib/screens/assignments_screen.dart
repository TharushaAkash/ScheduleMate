import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/assignment_provider.dart';
import '../models/assignment_model.dart';
import 'add_assignment_screen.dart';
import 'assignment_details_screen.dart';

// ── Color Palette ──────────────────────────────────────────────────────────
const _bgColor       = Color(0xFF09090E);
const _surfaceColor  = Color(0xFF161622);
const _primary       = Color(0xFF6C5CE7);
const _teal          = Color(0xFF22D3A6);
const _danger        = Color(0xFFFF5C74);
const _warning       = Color(0xFFFFB020);
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
              opacity: 0.5,
              child: SvgPicture.string(_bgPatternSvg, fit: BoxFit.cover),
            ),
          ),
          // ── Glowing blobs
          _blob(top: -160, left: -100, size: 380, color: _primary.withOpacity(0.18), blur: 130),
          _blob(bottom: 40, right: -130, size: 320, color: _teal.withOpacity(0.12), blur: 110),
          _blob(top: 250, right: 0, size: 200, color: _warning.withOpacity(0.08), blur: 90),

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
            // Left: title + subtitle
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
            // Right: SVG icon
            SvgPicture.string(
              '''<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
                <rect x="10" y="14" width="28" height="30" rx="5" fill="#6C5CE7" fill-opacity="0.15" stroke="#6C5CE7" stroke-width="1.5"/>
                <rect x="18" y="9" width="12" height="10" rx="4" fill="#6C5CE7" fill-opacity="0.3" stroke="#6C5CE7" stroke-width="1.5"/>
                <circle cx="24" cy="14" r="1.5" fill="#09090E" stroke="#6C5CE7" stroke-width="1.5"/>
                <line x1="15" y1="26" x2="33" y2="26" stroke="#6C5CE7" stroke-width="1.5" stroke-linecap="round"/>
                <line x1="15" y1="32" x2="33" y2="32" stroke="#6C5CE7" stroke-width="1.5" stroke-linecap="round"/>
                <line x1="15" y1="38" x2="24" y2="38" stroke="#6C5CE7" stroke-width="1.5" stroke-linecap="round"/>
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
              // SVG dashed arrow pointing down toward FAB
              SvgPicture.string(
                '''<svg width="60" height="60" viewBox="0 0 60 60" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M30 10 Q30 35 30 45" stroke="#6C5CE7" stroke-opacity="0.5" stroke-width="2" stroke-dasharray="4 3" stroke-linecap="round"/>
                  <path d="M22 37 L30 47 L38 37" stroke="#6C5CE7" stroke-opacity="0.7" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
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
//  ASSIGNMENT CARD
// ═══════════════════════════════════════════════════════════════════════════
class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final nm = assignment.nextMilestone;
    Color accent;
    bool urgent = false;

    if (assignment.isFullyCompleted) {
      accent = _teal;
    } else if (nm == null) {
      accent = _primary;
    } else {
      final h = nm.deadline.difference(DateTime.now()).inHours;
      if (h < 0) {
        accent = _danger; urgent = true;
      } else if (h <= 24) {
        accent = _danger; urgent = true;
      } else if (h <= 72) {
        accent = _warning;
      } else {
        accent = _primary;
      }
    }

    final progress = assignment.progress;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.12), blurRadius: 24, spreadRadius: 0, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: _surfaceColor.withOpacity(0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
            ),
            child: Stack(
              children: [
                // ── Subtle SVG pattern inside card ──
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Opacity(
                      opacity: 0.3,
                      child: SvgPicture.string(
                        '''<svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
                          <defs>
                            <pattern id="p" width="20" height="20" patternUnits="userSpaceOnUse">
                              <circle cx="10" cy="10" r="0.8" fill="#ffffff" fill-opacity="0.15"/>
                            </pattern>
                          </defs>
                          <rect width="100%" height="100%" fill="url(#p)"/>
                        </svg>''',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                // ── Glow corner accent ──
                Positioned(
                  top: -20, right: -20,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withOpacity(0.15),
                    ),
                  ),
                ),
                // ── Main content ──
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AssignmentDetailsScreen(assignmentId: assignment.id),
                    )),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Module badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: accent.withOpacity(0.4)),
                                ),
                                child: Text(assignment.moduleCode,
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.5)),
                              ),
                              const Spacer(),
                              // Status dot
                              _statusBadge(urgent, assignment.isFullyCompleted, accent),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(assignment.title,
                            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary, letterSpacing: -0.3),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SvgPicture.string(
                                '''<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                                  <circle cx="8" cy="8" r="6.5" stroke="${_svgHex(urgent ? _danger : _textSecondary)}" stroke-width="1.3"/>
                                  <path d="M8 5v3.5l2 1.5" stroke="${_svgHex(urgent ? _danger : _textSecondary)}" stroke-width="1.3" stroke-linecap="round"/>
                                </svg>''',
                                width: 14, height: 14,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  nm != null ? 'Next: ${nm.title}' : 'All milestones done ✓',
                                  style: GoogleFonts.poppins(fontSize: 12, color: urgent ? _danger : _textSecondary,
                                    fontWeight: urgent ? FontWeight.w600 : FontWeight.normal),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Progress bar with label
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: Colors.white.withOpacity(0.07),
                                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('${(progress * 100).toInt()}%',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool urgent, bool done, Color accent) {
    String label;
    if (done) {
      label = 'Done';
    } else if (urgent) {
      label = 'Urgent';
    } else {
      label = 'Active';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
        ],
      ),
    );
  }

  String _svgHex(Color c) => '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
}
