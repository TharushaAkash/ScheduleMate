import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/room_model.dart';
import '../services/google_drive_room_service.dart';

class RoomDetailsScreen extends StatefulWidget {
  final RoomModel room;
  const RoomDetailsScreen({super.key, required this.room});

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  final _service = GoogleDriveRoomService.instance;

  int _tab = 1;
  bool _isUploading = false;
  bool _isGridView = false;
  String? _currentFolderId;
  String _currentFolderName = '';
  final List<_BreadCrumb> _breadcrumbs = [];
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  
  final _chatCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  Stream<List<RoomMessage>>? _chatStream;
  Future<List<RoomFile>>? _filesFuture;
  
  final List<RoomMessage> _optimisticMessages = [];

  static const _bg = Color(0xFF13131A);
  static const _card = Color(0xFF1C1C26);
  static const _accent = Color(0xFF5B45FF);
  static const _sub = Color(0xFF8A8D9F);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()));
    _refreshFiles();
    if (_tab == 3) {
      _chatStream = _service.messagesStream(widget.room.roomId);
    }
  }

  void _refreshFiles() {
    setState(() {
      _filesFuture = _service.getFiles(widget.room.roomId, parentId: _currentFolderId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  // ─── Navigation ──────────────────────────────────────────────────────────────
  void _openFolder(RoomFile folder) {
    _breadcrumbs.add(_BreadCrumb(_currentFolderId, _currentFolderName));
    setState(() {
      _currentFolderId = folder.id;
      _currentFolderName = folder.name;
      _searchCtrl.clear();
    });
    _refreshFiles();
  }

  void _navigateTo(int breadcrumbIndex) {
    final crumb = _breadcrumbs[breadcrumbIndex];
    _breadcrumbs.removeRange(breadcrumbIndex, _breadcrumbs.length);
    setState(() {
      _currentFolderId = crumb.folderId;
      _currentFolderName = crumb.name;
      _searchCtrl.clear();
    });
    _refreshFiles();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────
  Future<void> _addLink() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Share a Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Paste any shareable link (Google Drive, OneDrive, YouTube, etc.)', style: TextStyle(color: _sub, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Display Name',
              labelStyle: TextStyle(color: Colors.grey.shade400),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _accent), borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: urlCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'URL / Link',
              labelStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.link_rounded, color: _sub, size: 20),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _accent), borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _sub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Share', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != true) return;
    final name = nameCtrl.text.trim();
    final url = urlCtrl.text.trim();
    if (name.isEmpty || url.isEmpty) return;
    setState(() => _isUploading = true);
    final success = await _service.addLink(widget.room.roomId, name, url, parentId: _currentFolderId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Link shared!' : 'Failed to share link.')));
    }
    setState(() => _isUploading = false);
    if (success) _refreshFiles();
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: const TextStyle(color: _sub),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800), borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _accent), borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _sub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final folderId = await _service.createFolder(widget.room.roomId, name, parentId: _currentFolderId);
    if (folderId != null) _refreshFiles();
  }

  // Upload a file directly to Supabase Storage
  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final pickedFile = result.files.single;
    final file = File(pickedFile.path!);
    final fileName = pickedFile.name;

    setState(() => _isUploading = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading "$fileName"...')),
      );
    }

    final success = await _service.uploadFile(
      widget.room.roomId,
      file,
      fileName,
      parentId: _currentFolderId,
    );

    setState(() => _isUploading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '✅ "$fileName" uploaded!' : '❌ Upload failed. Try again.'),
      ));
    }
    if (success) _refreshFiles();
  }
  void _showUploadMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Upload File
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.upload_file_rounded, color: Colors.green),
            ),
            title: const Text('Upload File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('PDF, DOCX, images, zip, any file...', style: TextStyle(color: _sub, fontSize: 12)),
            onTap: () { Navigator.pop(context); _uploadFile(); },
          ),
          // Share a link
          ListTile(
            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.link_rounded, color: Colors.blue)),
            title: const Text('Share a Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Google Drive, OneDrive, YouTube...', style: TextStyle(color: _sub, fontSize: 12)),
            onTap: () { Navigator.pop(context); _addLink(); },
          ),
          // Create Folder
          ListTile(
            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.create_new_folder_rounded, color: Colors.orange)),
            title: const Text('Create Folder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () { Navigator.pop(context); _createFolder(); },
          ),
        ]),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  String _formatDate(DateTime? d) => d == null ? '' : DateFormat('MMM dd, yyyy').format(d);

  Map<String, dynamic> _fileTypeInfo(RoomFile f) {
    if (f.isFolder) return {'icon': Icons.folder_rounded, 'color': _accent, 'ext': 'FOLDER'};
    final n = f.name.toLowerCase();
    if (n.endsWith('.pdf')) return {'icon': Icons.picture_as_pdf_rounded, 'color': Colors.red, 'ext': 'PDF'};
    if (n.endsWith('.docx') || n.endsWith('.doc')) return {'icon': Icons.description_rounded, 'color': Colors.blue, 'ext': 'DOCX'};
    if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg')) return {'icon': Icons.image_rounded, 'color': Colors.green, 'ext': 'IMG'};
    if (n.endsWith('.zip') || n.endsWith('.rar')) return {'icon': Icons.folder_zip_rounded, 'color': Colors.orange, 'ext': 'ZIP'};
    return {'icon': Icons.insert_drive_file_rounded, 'color': Colors.grey, 'ext': 'FILE'};
  }

  Future<void> _openFile(RoomFile file) async {
    if (file.isFolder) { _openFolder(file); return; }
    _showFileActions(file);
  }

  void _showFileActions(RoomFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final info = _fileTypeInfo(file);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // File name header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: (info['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(info['icon'] as IconData, color: info['color'] as Color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      file.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              const Divider(color: Color(0xFF2C2C3E), height: 24),

              // Open
              if (file.url != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.open_in_new_rounded, color: _accent),
                  ),
                  title: const Text('Open', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    file.storagePath != null ? 'View file in browser' : 'Opens the shared link',
                    style: const TextStyle(color: _sub, fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse(file.url!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),

              // Download (Only for uploaded files)
              if (file.storagePath != null && file.url != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.download_rounded, color: Colors.green),
                  ),
                  title: const Text('Download', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Directly download to your device', style: TextStyle(color: _sub, fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(context);
                    // Open webViewLink for Google Drive
                    final uri = Uri.parse(file.url!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),

              // Copy Link
              if (file.url != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.copy_rounded, color: Colors.blue),
                  ),
                  title: const Text('Copy Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Copy the file URL to clipboard', style: TextStyle(color: _sub, fontSize: 12)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: file.url!));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🔗 Link copied to clipboard!')),
                    );
                  },
                ),

              // Delete (admin/creator only or file owner)
              if (widget.room.isCreator || file.isOwnedByMe)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  ),
                  title: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(file);
                  },
                ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_breadcrumbs.isNotEmpty) {
              _navigateTo(_breadcrumbs.length - 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _currentFolderName.isNotEmpty ? _currentFolderName : widget.room.roomName,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
          
          SafeArea(
            child: Column(children: [
              // Breadcrumb
        if (_breadcrumbs.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              GestureDetector(
                onTap: () => _navigateTo(0),
                child: const Text('Root', style: TextStyle(color: _accent, fontSize: 13)),
              ),
              ..._breadcrumbs.asMap().entries.skip(1).map((e) => Row(children: [
                const Icon(Icons.chevron_right_rounded, size: 16, color: _sub),
                GestureDetector(
                  onTap: () => _navigateTo(e.key),
                  child: Text(e.value.name.isEmpty ? 'Root' : e.value.name, style: const TextStyle(color: _accent, fontSize: 13)),
                ),
              ])),
              const Icon(Icons.chevron_right_rounded, size: 16, color: _sub),
              Text(_currentFolderName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

        // Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            _tabBtn(0, 'Overview', Icons.info_outline_rounded),
            _tabBtn(1, 'Files', Icons.folder_open_rounded),
            _tabBtn(3, 'Chat', Icons.chat_bubble_outline_rounded),
            if (widget.room.isCreator) _tabBtn(2, 'Members', Icons.people_outline_rounded),
          ]),
        ),

        // Content
        Expanded(child: _buildContent()),

          if (_isUploading)
            Container(
              color: _bg, padding: const EdgeInsets.all(12),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
                SizedBox(width: 12),
                Text('Uploading...', style: TextStyle(color: Colors.white)),
              ]),
            ),
        ]),
      ),
      ],
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: _isUploading ? null : _showUploadMenu,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Add'),
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _tabBtn(int i, String label, IconData icon) {
    final sel = _tab == i;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (i == 1 && _tab != 1) {
            _filesFuture = _service.getFiles(widget.room.roomId, parentId: _currentFolderId);
          }
          if (i == 3 && _tab != 3) {
            _chatStream = _service.messagesStream(widget.room.roomId);
          }
          _tab = i;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: sel ? null : Border.all(color: const Color(0xFF2C2C3E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: sel ? Colors.white : _sub),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: sel ? Colors.white : _sub, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_tab == 0) return _buildOverview();
    if (_tab == 1) return _buildFiles();
    if (_tab == 2) return _buildMembers();
    if (_tab == 3) return _buildChat();
    return const SizedBox();
  }

  // ─── Overview Tab ────────────────────────────────────────────────────────────
  Widget _buildOverview() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _service.getRoom(widget.room.roomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }

        final roomData = snapshot.data;
        final joinCode = roomData?['joinCode'] ?? widget.room.joinCode ?? 'Loading...';

        return ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.info_outline_rounded, color: _accent),
                SizedBox(width: 12),
                Text('Room Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
              const SizedBox(height: 20),
              const Text('Room Name', style: TextStyle(color: _sub, fontSize: 13)),
              const SizedBox(height: 6),
              Text(widget.room.roomName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Your Role', style: TextStyle(color: _sub, fontSize: 13)),
              const SizedBox(height: 6),
              Text(widget.room.isCreator ? 'Admin / Host' : 'Member', style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 20),
              const Text('Join Code', style: TextStyle(color: _sub, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.qr_code_rounded, color: _sub, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      joinCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: _sub, size: 18),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    onPressed: () {
                      if (joinCode == 'Loading...') return;
                      Clipboard.setData(ClipboardData(text: joinCode));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join Code copied!')));
                    },
                  ),
                ]),
              ),
            ]),
          ),
        ]);
      },
    );
  }

  // ─── Files Tab ───────────────────────────────────────────────────────────────
  Widget _buildFiles() {
    return Column(children: [
      // Search + view toggle
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Row(children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(22)),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search files...',
                  hintStyle: TextStyle(color: _sub, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: _sub, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _viewToggleBtn(Icons.grid_view_rounded, true),
          const SizedBox(width: 8),
          _viewToggleBtn(Icons.format_list_bulleted_rounded, false),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<RoomFile>>(
          future: _filesFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _accent));
            }
            final files = (snap.data ?? [])
                .where((f) => _searchQuery.isEmpty || f.name.toLowerCase().contains(_searchQuery))
                .toList();

            if (files.isEmpty) {
              return Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.folder_open_rounded, size: 64, color: _sub.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text(_searchQuery.isEmpty ? 'No files here yet.' : 'No files match your search.',
                      style: const TextStyle(color: _sub, fontSize: 16)),
                ]),
              );
            }
            return _isGridView ? _buildGrid(files) : _buildList(files);
          },
        ),
      ),
    ]);
  }

  Widget _viewToggleBtn(IconData icon, bool isGrid) {
    final sel = _isGridView == isGrid;
    return Container(
      width: 40, height: 44,
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: IconButton(
        icon: Icon(icon, size: 18, color: sel ? _accent : _sub),
        onPressed: () => setState(() => _isGridView = isGrid),
      ),
    );
  }

  Widget _buildList(List<RoomFile> files) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      itemCount: files.length,
      itemBuilder: (ctx, i) {
        final f = files[i];
        final info = _fileTypeInfo(f);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: (info['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(info['icon'] as IconData, color: info['color'] as Color),
            ),
            title: Text(f.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              f.isFolder ? 'Folder' : 'Shared by ${f.addedByName ?? 'Unknown'} • ${_formatDate(f.createdAt)}',
              style: const TextStyle(color: _sub, fontSize: 12),
            ),
            trailing: f.isFolder
                ? const Icon(Icons.chevron_right_rounded, color: _sub)
                : const Icon(Icons.more_vert_rounded, color: _sub),
            onTap: () => _openFile(f),
            onLongPress: () => _showFileActions(f),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<RoomFile> files) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85),
      itemCount: files.length,
      itemBuilder: (ctx, i) {
        final f = files[i];
        final info = _fileTypeInfo(f);
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openFile(f),
          onLongPress: () => _showFileActions(f),
          child: Container(
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: (info['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(info['icon'] as IconData, color: info['color'] as Color, size: 26),
              ),
              const Spacer(),
              Text(f.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(f.isFolder ? 'Folder' : 'Link', style: const TextStyle(color: _sub, fontSize: 11)),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(RoomFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete File?', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${f.name}"? This cannot be undone.', style: const TextStyle(color: _sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteFile(widget.room.roomId, f);
      _refreshFiles();
    }
  }

  // ─── Members Tab ─────────────────────────────────────────────────────────────
  Widget _buildMembers() {
    return StreamBuilder<List<RoomMember>>(
      stream: _service.membersStream(widget.room.roomId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final members = snap.data ?? [];
        if (members.isEmpty) {
          return const Center(child: Text('No members found.', style: TextStyle(color: _sub)));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          itemCount: members.length,
          itemBuilder: (ctx, i) {
            final m = members[i];
            final isMe = m.uid == _service.currentUser?.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: m.photoUrl != null ? NetworkImage(m.photoUrl!) : null,
                  backgroundColor: _accent.withOpacity(0.2),
                  child: m.photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                title: Text('${m.displayName}${isMe ? ' (You)' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(m.email ?? '', style: const TextStyle(color: _sub, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: m.role == 'admin' ? _accent.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(m.role.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: m.role == 'admin' ? _accent : _sub)),
                  ),
                  if (widget.room.isCreator && !isMe) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
                      onPressed: () => _confirmRemoveMember(m),
                    ),
                  ],
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRemoveMember(RoomMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Remove Member?', style: TextStyle(color: Colors.white)),
        content: Text('Remove ${m.displayName} from this room?', style: const TextStyle(color: _sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) await _service.removeMember(widget.room.roomId, m.uid);
  }

  // ─── Chat Tab ──────────────────────────────────────────────────────────────
  Widget _buildChat() {
    return Column(
      children: [
        // Chat header bar
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _card.withOpacity(0.85),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chat_rounded, color: _accent, size: 16),
                  ),
                  const SizedBox(width: 12),
                  const Text('Room Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  if (widget.room.isCreator)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 16),
                      label: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                      onPressed: _confirmClearChat,
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: CustomPaint(
              painter: _WhatsAppPatternPainter(color: Colors.white.withValues(alpha: 0.05)),
              child: StreamBuilder<List<RoomMessage>>(
                stream: _chatStream,
                builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _accent));
              }
              final streamMessages = snap.data ?? [];
              final List<RoomMessage> messages = List.from(streamMessages);
              
              if (messages.isNotEmpty) {
                final newOptimistic = _optimisticMessages.where((opt) => 
                  !messages.any((m) => m.senderId == opt.senderId && m.text == opt.text && m.createdAt.difference(opt.createdAt).inSeconds.abs() < 20)
                ).toList();
                messages.addAll(newOptimistic);
              } else {
                messages.addAll(_optimisticMessages);
              }
              
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 64, color: _sub.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      const Text('No messages yet. Say hi!', style: TextStyle(color: _sub, fontSize: 16)),
                    ],
                  ),
                );
              }

              // Auto-scroll to bottom
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_chatScrollCtrl.hasClients) {
                  _chatScrollCtrl.jumpTo(_chatScrollCtrl.position.maxScrollExtent);
                }
              });

              return ListView.builder(
                controller: _chatScrollCtrl,
                padding: const EdgeInsets.all(20),
                itemCount: messages.length,
                itemBuilder: (ctx, i) {
                  final msg = messages[i];
                  final isMe = msg.senderId == _service.currentUser?.id;
                  
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12, top: i == 0 ? 8 : 0),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: msg.senderPhotoUrl != null ? NetworkImage(msg.senderPhotoUrl!) : null,
                            backgroundColor: _accent.withOpacity(0.2),
                            child: msg.senderPhotoUrl == null ? const Icon(Icons.person, size: 14, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? _accent.withOpacity(0.85)
                                      : _card.withOpacity(0.8),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 18),
                                  ),
                                  border: Border.all(
                                    color: isMe ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          msg.senderName,
                                          style: TextStyle(color: _accent.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    Text(
                                      msg.text,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('hh:mm a').format(msg.createdAt.toLocal()),
                                      style: TextStyle(color: isMe ? Colors.white60 : _sub, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: msg.senderPhotoUrl != null ? NetworkImage(msg.senderPhotoUrl!) : null,
                            backgroundColor: _accent.withOpacity(0.2),
                            child: msg.senderPhotoUrl == null ? const Icon(Icons.person, size: 14, color: Colors.white) : null,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
        // Glass Chat Input Area
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: _card.withOpacity(0.9),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: TextField(
                          controller: _chatCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          maxLines: 4,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: _sub, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B5CFF), Color(0xFF5B45FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () async {
                          final text = _chatCtrl.text;
                          if (text.trim().isEmpty) return;
                          _chatCtrl.clear();
                          final me = _service.currentUser;
                          if (me != null) {
                            setState(() {
                              _optimisticMessages.add(RoomMessage(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                text: text,
                                senderId: me.id,
                                senderName: me.displayName,
                                senderPhotoUrl: me.photoUrl,
                                createdAt: DateTime.now(),
                              ));
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_chatScrollCtrl.hasClients) {
                                _chatScrollCtrl.animateTo(
                                  _chatScrollCtrl.position.maxScrollExtent + 100,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                          }
                          await _service.sendMessage(widget.room.roomId, text);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: _card.withOpacity(0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30)],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent),
                      ),
                      const SizedBox(width: 16),
                      const Text('Clear Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Are you sure you want to delete all messages? This action cannot be undone and will affect everyone in the room.',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clearing chat...')));
      setState(() {
        _optimisticMessages.clear();
      });
      await _service.clearChat(widget.room.roomId);
    }
  }
}

class _BreadCrumb {
  final String? folderId;
  final String name;
  const _BreadCrumb(this.folderId, this.name);
}

class _WhatsAppPatternPainter extends CustomPainter {
  final Color color;
  _WhatsAppPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final double step = 60;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        // Draw subtle pattern elements
        if ((x + y) % (step * 2) == 0) {
          // A tiny circle
          canvas.drawCircle(Offset(x + step / 2, y + step / 2), 2.5, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth=1.2);
        } else {
          // A tiny cross/plus
          final cx = x + step / 2;
          final cy = y + step / 2;
          canvas.drawLine(Offset(cx - 3, cy), Offset(cx + 3, cy), paint);
          canvas.drawLine(Offset(cx, cy - 3), Offset(cx, cy + 3), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
