import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/announcement_parser.dart';
import '../services/database_helper.dart';
import '../services/lms_auth_service.dart';
import '../services/notification_service.dart';

/// A small in-app browser, already logged in to CourseWeb, so the user can
/// navigate to whichever page lists the announcements they care about
/// (e.g. a course's Announcements forum) and tap "Import" to pull that
/// page's posts into the app.
class LmsBrowserScreen extends StatefulWidget {
  final String startUrl;

  const LmsBrowserScreen({super.key, this.startUrl = LmsAuthService.dashboardUrl});

  @override
  State<LmsBrowserScreen> createState() => _LmsBrowserScreenState();
}

class _LmsBrowserScreenState extends State<LmsBrowserScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _importing = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageFinished: (url) => setState(() => _currentUrl = url),
          onUrlChange: (change) {
            if (change.url != null) setState(() => _currentUrl = change.url!);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.startUrl));
  }

  Future<void> _importCurrentPage() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      if (_currentUrl.contains('/login/')) {
        _showMessage('Session expired — please log in again.', isError: true);
        await LmsAuthService.instance.setLoggedIn(false);
        if (mounted) Navigator.of(context).pop('relogin');
        return;
      }

      final rawResult = await _controller
          .runJavaScriptReturningResult('document.documentElement.outerHTML');
      final htmlString = _decodeJsResult(rawResult);
      final found = AnnouncementParser.parse(htmlString, _currentUrl);

      if (found.isEmpty) {
        _showMessage(
            'No announcements found on this page. Try opening a course\'s Announcements forum, then Import.');
        return;
      }

      var newCount = 0;
      for (final a in found) {
        final inserted = await DatabaseHelper.instance.insertAnnouncementIfNew(a);
        if (inserted > 0) newCount++;
      }

      if (newCount > 0) {
        await NotificationService.instance.showAnnouncementsImportedNotification(newCount);
      }
      _showMessage(newCount > 0
          ? 'Imported $newCount new announcement${newCount == 1 ? '' : 's'}.'
          : 'No new announcements — everything here is already saved.');
    } catch (e) {
      _showMessage('Import failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  String _decodeJsResult(Object raw) {
    var s = raw.toString();
    // runJavaScriptReturningResult on Android returns a JSON-encoded string.
    if (s.startsWith('"') && s.endsWith('"')) {
      s = s
          .substring(1, s.length - 1)
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\\', '\\');
    }
    return s;
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse CourseWeb'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Dashboard',
            onPressed: () => _controller.loadRequest(Uri.parse(LmsAuthService.dashboardUrl)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1)
            LinearProgressIndicator(value: _progress, minHeight: 3),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importCurrentPage,
        icon: _importing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.download_rounded),
        label: Text(_importing ? 'Importing…' : 'Import this page'),
      ),
    );
  }
}
