import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/assignment_provider.dart';
import '../models/assignment_model.dart';
import 'add_assignment_screen.dart';
import 'assignment_details_screen.dart';

// ── Design Tokens ──────────────────────────────────────────────────────────
const _bg         = Color(0xFF080B1A);
const _surface    = Color(0xFF111427);
const _card       = Color(0xFF151829);
const _primary    = Color(0xFF7C5CFF);
const _blue       = Color(0xFF3B82F6);
const _teal       = Color(0xFF00D4AA);
const _danger     = Color(0xFFFF5C74);
const _warning    = Color(0xFFFFB347);
const _textPrimary   = Colors.white;
const _textSecondary = Color(0xFF8A8D9F);

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});
  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  int _filterIdx = 0; // 0=All, 1=Active, 2=Done
  final List<String> _filters = ['All', 'Active', 'Completed'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  List<Assignment> _filtered(List<Assignment> all) {
    if (_filterIdx == 1) return all.where((a) => !a.isFullyCompleted).toList();
    if (_filterIdx == 2) return all.where((a) => a.isFullyCompleted).toList();
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<AssignmentProvider>(
        builder: (context, provider, _) {
          final all      = provider.sortedAssignments;
          final filtered = _filtered(all);
          final active   = all.where((a) => !a.isFullyCompleted).length;
          final done     = all.where((a) => a.isFullyCompleted).length;
          final overdue  = all.where((a) {
            final nm = a.nextMilestone;
            return nm != null && nm.deadline.isBefore(DateTime.now());
          }).length;

          return Stack(
            children: [
              // ── Ambient blobs ──
              Positioned(top: -80, right: -80, child: _Blob(size: 300, color: _primary.withOpacity(0.18))),
              Positioned(top: 200, left: -100, child: _Blob(size: 240, color: _blue.withOpacity(0.10))),

              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Hero Header ──
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    expandedHeight: 240,
                    pinned: true,
                    elevation: 0,
                    surfaceTintColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      background: _HeroHeader(
                        active: active, done: done, overdue: overdue,
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(0),
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, _primary.withOpacity(0.3), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Filter Tabs ──
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FilterDelegate(
                      filters: _filters,
                      selected: _filterIdx,
                      onSelect: (i) => setState(() => _filterIdx = i),
                    ),
                  ),

                  // ── Content ──
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(fade: _fade, filterIdx: _filterIdx),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            return FadeTransition(
                              opacity: _fade,
                              child: _AssignmentCard(assignment: filtered[i], index: i),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),

              // ── FAB ──
              Positioned(
                bottom: 28, right: 20,
                child: _GlowFab(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssignmentScreen())),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Hero Header Widget ──────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final int active, done, overdue;
  const _HeroHeader({required this.active, required this.done, required this.overdue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _primary.withOpacity(0.3)),
                      ),
                      child: Text('PROJECT TRACKER',
                        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: _primary, letterSpacing: 1.5)),
                    ),
                    const SizedBox(height: 10),
                    Text('My Tasks',
                      style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w900, color: _textPrimary, letterSpacing: -1.5, height: 1)),
                    const SizedBox(height: 6),
                    Text(
                      overdue > 0
                        ? '$active active • $overdue need attention'
                        : active == 0 ? 'All caught up! Great work 🎉' : '$active active • $done completed',
                      style: GoogleFonts.poppins(
                        fontSize: 13, color: overdue > 0 ? _danger : _textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // Circular progress donut
              Consumer<AssignmentProvider>(
                builder: (_, provider, __) {
                  final all = provider.sortedAssignments;
                  final completedRatio = all.isEmpty ? 0.0 : done / all.length;
                  return SizedBox(
                    width: 72, height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: completedRatio,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: const AlwaysStoppedAnimation<Color>(_teal),
                          strokeCap: StrokeCap.round,
                        ),
                        Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(completedRatio * 100).toInt()}%',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w900, color: _teal)),
                            Text('done', style: GoogleFonts.poppins(fontSize: 8, color: _textSecondary)),
                          ],
                        )),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Summary chips
          Row(
            children: [
              _MiniChip(label: '$active Active', color: _blue),
              const SizedBox(width: 8),
              _MiniChip(label: '$done Done', color: _teal),
              if (overdue > 0) ...[
                const SizedBox(width: 8),
                _MiniChip(label: '$overdue Overdue', color: _danger),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label; final Color color;
  const _MiniChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// ── Filter Tabs ─────────────────────────────────────────────────────────────
class _FilterDelegate extends SliverPersistentHeaderDelegate {
  final List<String> filters;
  final int selected;
  final ValueChanged<int> onSelect;
  const _FilterDelegate({required this.filters, required this.selected, required this.onSelect});

  @override double get minExtent => 60;
  @override double get maxExtent => 60;
  @override bool shouldRebuild(_FilterDelegate old) => old.selected != selected;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: 60,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: _bg.withOpacity(0.85),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: List.generate(filters.length, (i) {
              final active = i == selected;
              return GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: active ? LinearGradient(colors: [_primary, _blue]) : null,
                    color: active ? null : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? Colors.transparent : Colors.white.withOpacity(0.08),
                    ),
                    boxShadow: active ? [BoxShadow(color: _primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] : [],
                  ),
                  child: Text(filters[i],
                    style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: active ? Colors.white : _textSecondary,
                    )),
                ),
              );
            }),
          ),
        ),
      ),
    ),
    );
  }
}

// ── Assignment Card ──────────────────────────────────────────────────────────
class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final int index;
  const _AssignmentCard({required this.assignment, required this.index});

  @override
  Widget build(BuildContext context) {
    final nm       = assignment.nextMilestone;
    final progress = assignment.progress;
    final total    = assignment.milestones.length;
    final doneC    = assignment.milestones.where((m) => m.isCompleted).length;
    final overdue  = assignment.milestones.where((m) => !m.isCompleted && m.deadline.isBefore(DateTime.now())).length;

    Color accent;
    String statusLabel;
    IconData statusIcon;

    if (assignment.isFullyCompleted) {
      accent = _teal; statusLabel = 'Completed'; statusIcon = Icons.check_circle_rounded;
    } else if (overdue > 0) {
      accent = _danger; statusLabel = 'Overdue'; statusIcon = Icons.error_rounded;
    } else if (nm != null && nm.deadline.difference(DateTime.now()).inHours <= 24) {
      accent = _warning; statusLabel = 'Due Soon'; statusIcon = Icons.schedule_rounded;
    } else {
      accent = _blue; statusLabel = 'Active'; statusIcon = Icons.play_circle_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AssignmentDetailsScreen(assignmentId: assignment.id),
          )),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_card, _surface],
              ),
              border: Border.all(color: accent.withOpacity(0.18), width: 1),
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8)),
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                // Top accent bar
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, accent.withOpacity(0.2)]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Module badge + Status chip
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accent.withOpacity(0.25)),
                            ),
                            child: Text(assignment.moduleCode,
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: accent, letterSpacing: 0.6)),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accent.withOpacity(0.20)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: accent),
                                const SizedBox(width: 5),
                                Text(statusLabel,
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Text(assignment.title,
                        style: GoogleFonts.poppins(
                          fontSize: 17, fontWeight: FontWeight.w800,
                          color: _textPrimary, letterSpacing: -0.5, height: 1.2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (assignment.moduleName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(assignment.moduleName,
                          style: GoogleFonts.poppins(fontSize: 11, color: _textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 14),
                      // Progress track
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: Colors.white.withOpacity(0.06),
                                valueColor: AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${(progress * 100).toInt()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w900, color: accent,
                              shadows: [Shadow(color: accent.withOpacity(0.6), blurRadius: 8)])),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Bottom row: next milestone + milestone count
                      Row(
                        children: [
                          Icon(Icons.flag_rounded, size: 14, color: _textSecondary.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              nm != null ? nm.title : 'All milestones complete ✓',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5, color: _textSecondary,
                                fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Text('$doneC/$total tasks',
                              style: GoogleFonts.poppins(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w600)),
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
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final Animation<double> fade;
  final int filterIdx;
  const _EmptyState({required this.fade, required this.filterIdx});

  @override
  Widget build(BuildContext context) {
    final msgs = [
      ['No Tasks Yet', 'Tap the + button to create your first project and get started.'],
      ['All Done!', 'No active tasks. You\'re crushing it! 🎉'],
      ['Nothing Completed Yet', 'Start completing tasks to see them here.'],
    ];

    return FadeTransition(
      opacity: fade,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primary.withOpacity(0.08),
                  border: Border.all(color: _primary.withOpacity(0.2), width: 1.5),
                ),
                child: Icon(
                  filterIdx == 1 ? Icons.celebration_rounded : filterIdx == 2 ? Icons.hourglass_empty_rounded : Icons.assignment_outlined,
                  size: 44, color: _primary.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(msgs[filterIdx][0],
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(msgs[filterIdx][1],
                style: GoogleFonts.poppins(fontSize: 14, color: _textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glow FAB ────────────────────────────────────────────────────────────────
class _GlowFab extends StatelessWidget {
  final VoidCallback onTap;
  const _GlowFab({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primary, _blue]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: _primary.withOpacity(0.55), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text('New Task', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
        ],
      ),
    ),
  );
}

// ── Blob ────────────────────────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  final double size; final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: color,
      boxShadow: [BoxShadow(color: color, blurRadius: size * 0.5)],
    ),
  );
}
