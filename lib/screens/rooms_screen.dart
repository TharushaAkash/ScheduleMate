import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../models/room_model.dart';
import '../services/database_helper.dart';
import '../services/google_drive_room_service.dart';
import 'room_details_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _service = GoogleDriveRoomService.instance;

  List<RoomModel> _rooms = [];
  bool _isLoading = true;
  bool _isSignedIn = false;

  static const _bg = Color(0xFF09090E);
  static const _card = Color(0xFF161622);
  static const _accent = Color(0xFF6C5CE7);
  static const _sub = Color(0xFF8A8D9F);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    final user = await _service.signInSilently();
    _isSignedIn = user != null;
    await _loadRooms(); // Always load local rooms so they can see them, but require sign-in to interact
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _manualSignIn() async {
    setState(() => _isLoading = true);
    final user = await _service.signIn();
    _isSignedIn = user != null;
    if (_isSignedIn) await _loadRooms();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadRooms() async {

    // Load from local DB (now correctly synced for this user)
    final rooms = await DatabaseHelper.instance.getRooms();
    if (mounted) setState(() => _rooms = rooms);
  }

  // ─── Create Room ────────────────────────────────────────────────────────────

  Future<void> _createRoom() async {
    final nameCtrl = TextEditingController();
    final roomName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create New Room',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Room Name',
            labelStyle: TextStyle(color: Colors.grey.shade400),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade800),
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _accent),
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _sub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (roomName == null || roomName.isEmpty) return;
    setState(() => _isLoading = true);

    final roomId = await _service.createRoom(roomName);
    if (roomId != null) {
      // Fetch join code from Firestore
      final roomData = await _service.getRoom(roomId);
      final joinCode = roomData?['joinCode'] as String? ?? roomId;

      final room =
          RoomModel(roomId: roomId, roomName: roomName, isCreator: true, joinCode: joinCode);
      await DatabaseHelper.instance.insertRoom(room);
      await _loadRooms();

      if (mounted) {
        _showRoomCreatedDialog(roomId, roomName, joinCode);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create room. Try again.')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showRoomCreatedDialog(String roomId, String roomName, String joinCode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.green),
            ),
            const SizedBox(width: 12),
            const Text('Room Created!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this 6-digit code with your students:',
                style: TextStyle(color: _sub, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withOpacity(0.4))),
              child: Center(
                child: Text(
                  joinCode,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: joinCode));
              ScaffoldMessenger.of(ctx)
                  .showSnackBar(const SnackBar(content: Text('Code copied!')));
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy_rounded, color: _accent, size: 18),
            label: const Text('Copy & Close', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  // ─── Join Room ──────────────────────────────────────────────────────────────

  Future<void> _joinRoom() async {
    final codeCtrl = TextEditingController();
    final joinCode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Join Room',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: codeCtrl,
          style: const TextStyle(
              color: Colors.white, fontSize: 16),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Room Code (Drive Folder ID)',
            labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade800),
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _accent),
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _sub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (joinCode == null || joinCode.trim().isEmpty) return;
    setState(() => _isLoading = true);

    String code = joinCode.trim();
    if (code.startsWith('http')) {
      final match = RegExp(r'(?:folders\/|id=)([a-zA-Z0-9_-]+)').firstMatch(code);
      if (match != null && match.group(1) != null) {
        code = match.group(1)!;
      }
    }

    final result = await _service.joinRoom(code);
    if (result != null) {
      final room = RoomModel(
          roomId: result['roomId']!,
          roomName: result['roomName']!,
          isCreator: false);
      await DatabaseHelper.instance.insertRoom(room);
      await _loadRooms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Joined "${result['roomName']}"!')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Invalid room code. Check the code and try again.')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Room Card Colors / Icons ────────────────────────────────────────────────

  static const _colors = [
    Color(0xFF5B45FF),
    Color(0xFF28C76F),
    Color(0xFFFF9F43),
    Color(0xFF00CFE8),
    Color(0xFFEA5455),
  ];

  static const _icons = [
    Icons.folder_rounded,
    Icons.menu_book_rounded,
    Icons.science_rounded,
    Icons.code_rounded,
    Icons.design_services_rounded,
  ];

  Color _roomColor(String name) => _colors[name.length % _colors.length];
  IconData _roomIcon(String name) => _icons[name.length % _icons.length];

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
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
                color: _accent.withOpacity(0.15),
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.2), blurRadius: 120, spreadRadius: 60)],
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
                boxShadow: [BoxShadow(color: const Color(0xFF00D4AA).withOpacity(0.15), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
          
          RefreshIndicator(
            onRefresh: _loadRooms,
            color: _accent,
            backgroundColor: _card,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // Modern Header
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  expandedHeight: 140,
                  pinned: true,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    title: const Text(
                      'Class Rooms',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Colors.white,
                      ),
                    ),
                    background: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16, right: 24),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: _service.currentUser != null
                              ? Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _accent.withOpacity(0.5), width: 2),
                                    boxShadow: [
                                      BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 12)
                                    ]
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: _service.currentUser?.photoUrl != null
                                        ? NetworkImage(_service.currentUser!.photoUrl!)
                                        : null,
                                    backgroundColor: _card,
                                    child: _service.currentUser?.photoUrl == null
                                        ? const Icon(Icons.person, size: 20, color: _sub)
                                        : null,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Body content
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 140), // Space for floating bar
                  sliver: _isLoading
                      ? const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(color: _accent, strokeWidth: 3),
                          ),
                        )
                      : !_isSignedIn
                          ? SliverFillRemaining(child: _buildSignInPrompt())
                          : _rooms.isEmpty
                              ? SliverFillRemaining(child: _buildEmptyState())
                              : _buildRoomList(),
                ),
              ],
            ),
          ),
          
          // Floating Action Bar (Glassmorphism)
          if (_isSignedIn && !_isLoading)
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: _buildFloatingActionBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
            ]
          ),
          child: Row(
            children: [
              Expanded(
                child: _GlassButton(
                  icon: Icons.sensor_door_rounded,
                  label: 'Join Room',
                  color: const Color(0xFF00D4AA),
                  onTap: _joinRoom,
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white.withOpacity(0.2)),
              Expanded(
                child: _GlassButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Create',
                  color: _accent,
                  onTap: _createRoom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: _accent.withOpacity(0.15), blurRadius: 40, spreadRadius: 10),
              ],
            ),
            child: const Icon(Icons.lock_person_rounded, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 32),
          const Text(
            'Authentication Required',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in to your account to view,\njoin, or create class rooms.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _manualSignIn,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign In with Google', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Icon(Icons.folder_open_rounded, size: 72, color: Colors.white.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Rooms Found',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'You haven\'t joined or created any rooms yet.\nGet started using the menu below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.5), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final room = _rooms[i];
            final color = _roomColor(room.roomName);
            final icon = _roomIcon(room.roomName);

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 500 + (i * 100)),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 40 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _card.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RoomDetailsScreen(room: room)),
                            );
                            _loadRooms();
                          },
                          onLongPress: () => _confirmRemoveRoom(room),
                          highlightColor: color.withOpacity(0.1),
                          splashColor: color.withOpacity(0.15),
                          child: Stack(
                            children: [
                              // Abstract glowing orb inside card
                              Positioned(
                                right: -40,
                                bottom: -40,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withOpacity(0.15),
                                    boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 40)],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    // 3D looking Icon Box
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [color.withOpacity(0.9), color.withOpacity(0.6)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Icon(icon, color: Colors.white, size: 30),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            room.roomName,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: room.isCreator ? _accent.withOpacity(0.2) : const Color(0xFF00D4AA).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: room.isCreator ? _accent.withOpacity(0.3) : const Color(0xFF00D4AA).withOpacity(0.3)),
                                                ),
                                                child: Text(
                                                  room.isCreator ? 'Admin' : 'Member',
                                                  style: TextStyle(
                                                    color: room.isCreator ? _accent : const Color(0xFF00D4AA), 
                                                    fontSize: 11, 
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                room.isCreator ? 'Host' : 'Joined',
                                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.7), size: 24),
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
              ),
            );
          },
          childCount: _rooms.length,
        ),
      ),
    );
  }

  Future<void> _confirmRemoveRoom(RoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(room.isCreator ? Icons.delete_forever_rounded : Icons.exit_to_app_rounded, color: Colors.redAccent),
            ),
            const SizedBox(width: 16),
            Text(room.isCreator ? 'Delete Room' : 'Leave Room', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        content: Text(
          room.isCreator
              ? 'Are you sure you want to delete "${room.roomName}"?\nThis will permanently remove the room and all its files for everyone.'
              : 'Are you sure you want to leave "${room.roomName}"?',
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5, fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(room.isCreator ? 'Delete' : 'Leave', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (room.isCreator) {
        await _service.deleteRoom(room.roomId);
      } else {
        await _service.leaveRoom(room.roomId);
      }
      await DatabaseHelper.instance.deleteRoom(room.roomId);
      _loadRooms();
    }
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
