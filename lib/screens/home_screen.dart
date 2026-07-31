import 'package:flutter/material.dart';
import 'package:gpa_timetable_app/services/update_service.dart';

import 'gpa_screen.dart';
import 'timetable_upload_screen.dart';
import 'ca_marks_screen.dart';
import 'profile_screen.dart';
import 'rooms_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Check for updates on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.school_rounded, Icons.school_rounded, 'GPA'),
    _NavItem(Icons.calendar_month_rounded, Icons.calendar_month_rounded, 'Timetable'),
    _NavItem(Icons.folder_shared_rounded, Icons.folder_shared_rounded, 'Rooms'),
    _NavItem(Icons.description_rounded, Icons.description_rounded, 'CA Marks'),
    _NavItem(Icons.person_rounded, Icons.person_rounded, 'Profile'),
  ];

  List<Widget> get _pages => const [
    GpaScreen(),
    TimetableUploadScreen(),
    RoomsScreen(),
    CaMarksScreen(),
    ProfileScreen(),
  ];

  void _onNavTap(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final selected = i == _index;
                return Expanded(
                  child: _NavBarItem(
                    icon: item.icon,
                    label: item.label,
                    selected: selected,
                    onTap: () => _onNavTap(i),
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

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? primary.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: selected ? primary : (isDark ? Colors.white54 : Colors.grey),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? primary : (isDark ? Colors.white54 : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
