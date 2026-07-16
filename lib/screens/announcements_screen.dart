import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/announcement.dart';
import '../providers/announcement_provider.dart';
import 'lms_browser_screen.dart';
import 'lms_login_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<AnnouncementProvider>();
      await p.init();
      if (p.isLoggedIn) {
        await p.autoFetchAnnouncements();
      }
    });
  }

  Future<void> _connectOrFetch() async {
    final provider = context.read<AnnouncementProvider>();
    if (!provider.isLoggedIn) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LmsLoginScreen()),
      );
      if (ok != true) return;
      await provider.setLoggedIn(true);
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LmsBrowserScreen()),
    );

    if (result == 'relogin' && mounted) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LmsLoginScreen()),
      );
      if (ok == true) await provider.setLoggedIn(true);
    }

    if (mounted) await provider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          Consumer<AnnouncementProvider>(
            builder: (context, p, _) {
              if (!p.isLoggedIn) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) async {
                  if (v == 'mark_all') await p.markAllRead();
                  if (v == 'delete_all') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete All Announcements?'),
                        content: const Text('Are you sure you want to remove all announcements?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete All', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await p.deleteAll();
                    }
                  }
                  if (v == 'logout') await p.logout();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'mark_all', child: Text('Mark all as read')),
                  PopupMenuItem(value: 'delete_all', child: Text('Delete all', style: TextStyle(color: Colors.redAccent))),
                  PopupMenuItem(value: 'logout', child: Text('Log out of CourseWeb')),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<AnnouncementProvider>(
        builder: (context, p, _) {
          if (p.isLoading && p.announcements.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!p.isLoggedIn) {
            return _ConnectPrompt(onConnect: _connectOrFetch);
          }
          if (p.announcements.isEmpty) {
            return _EmptyState(onFetch: _connectOrFetch);
          }
          return RefreshIndicator(
            onRefresh: () => p.autoFetchAnnouncements(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: p.announcements.length,
              itemBuilder: (context, i) => _AnnouncementCard(
                announcement: p.announcements[i],
                isDark: isDark,
                primary: primary,
                onTap: () async {
                  await p.markRead(p.announcements[i]);
                  final url = p.announcements[i].sourceUrl;
                  if (url.isNotEmpty && context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => LmsBrowserScreen(startUrl: url)),
                    );
                    if (context.mounted) await p.refresh();
                  }
                },
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete Announcement?'),
                      content: const Text('Are you sure you want to remove this announcement?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await p.delete(p.announcements[i]);
                  }
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: Consumer<AnnouncementProvider>(
        builder: (context, p, _) {
          if (!p.isLoggedIn) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              if (p.isLoggedIn) {
                await p.autoFetchAnnouncements();
              } else {
                _connectOrFetch();
              }
            },
            backgroundColor: primary,
            icon: const Icon(Icons.sync_rounded, color: Colors.white),
            label: const Text('Fetch new', style: TextStyle(color: Colors.white)),
          );
        },
      ),
    );
  }
}

class _ConnectPrompt extends StatelessWidget {
  final VoidCallback onConnect;
  const _ConnectPrompt({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.campaign_rounded, size: 44, color: primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Connect to CourseWeb',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log in with your SLIIT O365 account to bring in your course announcements.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Log in to CourseWeb', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onFetch;
  const _EmptyState({required this.onFetch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'No announcements yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "Fetch now" to automatically pull the latest announcements from CourseWeb.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onFetch,
              icon: Icon(Icons.sync_rounded, color: primary),
              label: Text('Fetch now', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.isDark,
    required this.primary,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !announcement.isRead;
    return Dismissible(
      key: ValueKey(announcement.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete Announcement?'),
            content: const Text('Are you sure you want to remove this announcement?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252535) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.campaign_rounded, color: primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                announcement.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            if (unread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8, right: 8, top: 4),
                                decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 22),
                              color: Colors.redAccent.withOpacity(0.8),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: onDelete,
                            ),
                          ],
                        ),
                        if (announcement.courseLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            announcement.courseLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (announcement.snippet.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            announcement.snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                        ],
                        if (announcement.author.isNotEmpty || announcement.dateText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            [announcement.author, announcement.dateText]
                                .where((s) => s.isNotEmpty)
                                .join(' • '),
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                          ),
                        ],
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
