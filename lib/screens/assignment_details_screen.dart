import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/assignment_model.dart';
import '../providers/assignment_provider.dart';
import 'add_assignment_screen.dart';

// ── Design Tokens ──────────────────────────────────────────────────────────
const _bg         = Color(0xFF080B1A);
const _surface    = Color(0xFF111427);
const _card       = Color(0xFF151829);
const _primary    = Color(0xFF7C5CFF);
const _blue       = Color(0xFF3B82F6);
const _teal       = Color(0xFF00D4AA);
const _danger     = Color(0xFFFF5C74);
const _warning    = Color(0xFFFFB347);
const _white      = Colors.white;
const _grey       = Color(0xFF8A8D9F);

class AssignmentDetailsScreen extends StatelessWidget {
  final String assignmentId;
  const AssignmentDetailsScreen({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<AssignmentProvider>(
        builder: (context, provider, _) {
          final assignment = provider.assignments.firstWhere(
            (a) => a.id == assignmentId,
            orElse: () => Assignment(id: '', title: 'Not Found', moduleCode: '', moduleName: '', milestones: []),
          );
          if (assignment.id.isEmpty) {
            return const Center(child: Text('Assignment not found', style: TextStyle(color: _white)));
          }
          return Stack(
            children: [
              Positioned(top: -80, right: -60, child: _Orb(size: 260, color: _primary.withOpacity(0.15))),
              Positioned(top: 180, left: -100, child: _Orb(size: 200, color: _blue.withOpacity(0.08))),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(context, assignment, provider),
                  SliverToBoxAdapter(child: _buildBody(context, assignment)),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, Assignment a, AssignmentProvider p) {
    final accent = a.isFullyCompleted ? _teal : _primary;
    return SliverAppBar(
      pinned: true, expandedHeight: 200, backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _white.withOpacity(0.06), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 18),
        ),
      ),
      actions: [
        _AppBarBtn(icon: Icons.edit_rounded, color: _white,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddAssignmentScreen(existingAssignment: a)))),
        _AppBarBtn(icon: Icons.delete_outline_rounded, color: _danger, onTap: () async {
          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            backgroundColor: _card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Delete Task?', style: GoogleFonts.poppins(color: _white, fontWeight: FontWeight.w700)),
            content: Text('This action cannot be undone.', style: GoogleFonts.poppins(color: _grey, fontSize: 13)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins(color: _grey))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.poppins(color: _danger, fontWeight: FontWeight.w700))),
            ],
          ));
          if (ok == true) { p.deleteAssignment(a.id); if (context.mounted) Navigator.pop(context); }
        }),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(24, 0, 80, 18),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: accent.withOpacity(0.18), borderRadius: BorderRadius.circular(8), border: Border.all(color: accent.withOpacity(0.35))),
              child: Text(a.moduleCode, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: accent, letterSpacing: 0.8)),
            ),
            const SizedBox(height: 5),
            Text(a.title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900, color: _white, letterSpacing: -0.5, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (a.description.isNotEmpty)
              Text(a.description, style: GoogleFonts.poppins(fontSize: 9, color: _grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Assignment a) {
    final total = a.milestones.length;
    final done  = a.milestones.where((m) => m.isCompleted).length;
    final od    = a.milestones.where((m) => !m.isCompleted && m.deadline.isBefore(DateTime.now())).length;
    final act   = total - done - od;
    final prog  = a.progress;

    DateTime? endDate = a.milestones.isNotEmpty ? a.milestones.map((e) => e.deadline).reduce((x, y) => x.isAfter(y) ? x : y) : null;
    String timeLeft = 'N/A'; Color timeColor = _grey;
    if (endDate != null) {
      if (a.isFullyCompleted) { timeLeft = 'Completed'; timeColor = _teal; }
      else {
        final d = endDate.difference(DateTime.now());
        if (d.isNegative) { timeLeft = 'Overdue!'; timeColor = _danger; }
        else { timeLeft = '${d.inDays}d ${d.inHours % 24}h'; timeColor = d.inDays < 3 ? _warning : _blue; }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),

        // ── Stats Grid ──
        Row(children: [
          Expanded(child: _StatTile('Total', total, _primary, Icons.layers_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatTile('Done', done, _teal, Icons.check_circle_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatTile('Active', act, _warning, Icons.bolt_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatTile('Overdue', od, _danger, Icons.error_outline_rounded)),
        ]),

        const SizedBox(height: 20),

        // ── Progress Card ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _white.withOpacity(0.06)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.bar_chart_rounded, color: _primary, size: 18),
                  const SizedBox(width: 6),
                  Text('Overall Progress', style: GoogleFonts.poppins(color: _white, fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                const SizedBox(height: 2),
                Text(a.isFullyCompleted ? 'Project complete 🎉' : 'Keep going! You\'re on track.', style: GoogleFonts.poppins(color: _grey, fontSize: 11)),
              ]),
              SizedBox(width: 56, height: 56, child: Stack(fit: StackFit.expand, children: [
                CircularProgressIndicator(value: prog, strokeWidth: 5, strokeCap: StrokeCap.round,
                  backgroundColor: _white.withOpacity(0.06), valueColor: AlwaysStoppedAnimation(a.isFullyCompleted ? _teal : _primary)),
                Center(child: Text('${(prog * 100).toInt()}%', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: a.isFullyCompleted ? _teal : _primary))),
              ])),
            ]),
            const SizedBox(height: 16),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
              value: prog, minHeight: 6, backgroundColor: _white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(a.isFullyCompleted ? _teal : _primary),
            )),
            const SizedBox(height: 18),
            Container(height: 1, color: _white.withOpacity(0.04)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _DateChip('Start', a.createdAt, Icons.calendar_today_rounded),
              Container(width: 1, height: 28, color: _white.withOpacity(0.06)),
              _DateChip('End', endDate, Icons.event_available_rounded),
              Container(width: 1, height: 28, color: _white.withOpacity(0.06)),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined, size: 11, color: _grey),
                  const SizedBox(width: 3),
                  Text('Time Left', style: GoogleFonts.poppins(fontSize: 9, color: _grey)),
                ]),
                const SizedBox(height: 2),
                Text(timeLeft, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: timeColor)),
              ]),
            ]),
          ]),
        ),

        const SizedBox(height: 28),

        // ── Milestones Section ──
        Row(children: [
          Icon(Icons.flag_rounded, color: _primary, size: 22),
          const SizedBox(width: 8),
          Text('Milestones', style: GoogleFonts.poppins(color: _white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Text('$done/$total done', style: GoogleFonts.poppins(color: _grey, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 16),

        ...List.generate(a.milestones.length, (i) {
          final m = a.milestones[i];
          final isLast = i == a.milestones.length - 1;
          final mOverdue = !m.isCompleted && m.deadline.isBefore(DateTime.now());
          final mAccent = m.isCompleted ? _teal : (mOverdue ? _danger : _blue);
          return _MilestoneCard(m: m, isLast: isLast, assignment: a, mAccent: mAccent, overdue: mOverdue);
        }),
      ]),
    );
  }
}

// ── Small Widgets ──────────────────────────────────────────────────────────
class _AppBarBtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _white.withOpacity(0.06), borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: color, size: 18),
    ),
  );
}

class _Orb extends StatelessWidget {
  final double size; final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: size * 0.5)]));
}

class _StatTile extends StatelessWidget {
  final String label; final int val; final Color color; final IconData icon;
  const _StatTile(this.label, this.val, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.25))),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 15)),
      const SizedBox(height: 6),
      Text('$val', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: GoogleFonts.poppins(fontSize: 9, color: _grey, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _DateChip extends StatelessWidget {
  final String label; final DateTime? date; final IconData icon;
  const _DateChip(this.label, this.date, this.icon);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, size: 11, color: _grey), const SizedBox(width: 3), Text(label, style: GoogleFonts.poppins(fontSize: 9, color: _grey))]),
    const SizedBox(height: 2),
    Text(date != null ? '${date!.day}/${date!.month}/${date!.year}' : 'N/A', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: _white)),
  ]);
}

// ── Milestone Card ─────────────────────────────────────────────────────────
class _MilestoneCard extends StatefulWidget {
  final Milestone m; final bool isLast; final Assignment assignment; final Color mAccent; final bool overdue;
  const _MilestoneCard({required this.m, required this.isLast, required this.assignment, required this.mAccent, required this.overdue});
  @override State<_MilestoneCard> createState() => _MilestoneCardState();
}

class _MilestoneCardState extends State<_MilestoneCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final hasExtra = widget.m.description.isNotEmpty || widget.m.subtasks.isNotEmpty;
    final a = widget.mAccent;

    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Timeline
      SizedBox(width: 36, child: Column(children: [
        GestureDetector(
          onTap: () => Provider.of<AssignmentProvider>(context, listen: false).toggleMilestone(widget.assignment.id, widget.m.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300), width: 28, height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: a.withOpacity(widget.m.isCompleted ? 1 : 0.12),
              border: Border.all(color: a, width: 2), boxShadow: [BoxShadow(color: a.withOpacity(0.3), blurRadius: 8)]),
            child: widget.m.isCompleted ? const Icon(Icons.check, size: 14, color: _white)
              : widget.overdue ? const Icon(Icons.priority_high, size: 14, color: _danger)
              : Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: a, shape: BoxShape.circle))),
          ),
        ),
        if (!widget.isLast) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [a.withOpacity(0.4), _white.withOpacity(0.03)]), borderRadius: BorderRadius.circular(2)))),
      ])),
      const SizedBox(width: 12),

      // Card body
      Expanded(child: Padding(
        padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 16),
        child: Container(
          decoration: BoxDecoration(
            color: widget.m.isCompleted ? _teal.withOpacity(0.05) : (widget.overdue ? _danger.withOpacity(0.05) : _card),
            borderRadius: BorderRadius.circular(18), border: Border.all(color: a.withOpacity(0.25)),
          ),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasExtra ? () => setState(() => _open = !_open) : null,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: a.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.receipt_long_rounded, color: a, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(widget.m.title, style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700, color: widget.m.isCompleted ? _grey : _white,
                      decoration: widget.m.isCompleted ? TextDecoration.lineThrough : null, decorationColor: _teal, height: 1.2))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(color: a.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: a.withOpacity(0.25))),
                      child: Text(widget.m.isCompleted ? 'Done' : (widget.overdue ? 'Overdue' : 'Pending'),
                        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: a))),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.calendar_today_rounded, size: 11, color: _grey.withOpacity(0.8)),
                    const SizedBox(width: 4),
                    Text('${widget.m.deadline.day}/${widget.m.deadline.month}/${widget.m.deadline.year}  •  ${widget.m.deadline.hour.toString().padLeft(2,'0')}:${widget.m.deadline.minute.toString().padLeft(2,'0')}',
                      style: GoogleFonts.poppins(fontSize: 11, color: widget.overdue && !widget.m.isCompleted ? _danger : _grey, fontWeight: FontWeight.w500)),
                  ]),
                ])),
                if (hasExtra) ...[const SizedBox(width: 6), Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _grey, size: 20)],
              ]),
            ),

            // Expanded content
            if (_open && hasExtra) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: _white.withOpacity(0.05)),
              const SizedBox(height: 14),

              if (widget.m.description.isNotEmpty) ...[
                Row(children: [Icon(Icons.notes_rounded, size: 15, color: a.withOpacity(0.8)), const SizedBox(width: 6),
                  Text('Description', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _white))]),
                const SizedBox(height: 6),
                Container(width: double.infinity, padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _white.withOpacity(0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: _white.withOpacity(0.04))),
                  child: Text(widget.m.description, style: GoogleFonts.poppins(fontSize: 12, color: _grey, height: 1.5))),
                const SizedBox(height: 14),
              ],

              if (widget.m.subtasks.isNotEmpty) ...[
                Row(children: [
                  Icon(Icons.checklist_rounded, size: 15, color: a.withOpacity(0.8)),
                  const SizedBox(width: 6),
                  Text('Subtasks', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _white)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: _white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
                    child: Text('${widget.m.subtasks.where((s) => s.isCompleted).length}/${widget.m.subtasks.length}',
                      style: GoogleFonts.poppins(fontSize: 10, color: _grey, fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 10),
                ...widget.m.subtasks.map((s) => GestureDetector(
                  onTap: () => Provider.of<AssignmentProvider>(context, listen: false).toggleSubtask(widget.assignment.id, widget.m.id, s.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _white.withOpacity(0.04))),
                    child: Row(children: [
                      Icon(s.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: s.isCompleted ? _teal : _grey.withOpacity(0.5), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title, style: GoogleFonts.poppins(fontSize: 12, color: s.isCompleted ? _grey : _white.withOpacity(0.9),
                          decoration: s.isCompleted ? TextDecoration.lineThrough : null)),
                        if (s.estimatedHours > 0)
                          Row(children: [Icon(Icons.access_time_rounded, color: _grey, size: 11), const SizedBox(width: 3),
                            Text('${s.estimatedHours}h', style: GoogleFonts.poppins(fontSize: 10, color: _grey))]),
                      ])),
                    ]),
                  ),
                )),
              ],
            ],
          ])),
        ),
      )),
    ]));
  }
}
