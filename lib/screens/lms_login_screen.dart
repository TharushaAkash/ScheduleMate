import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/lms_auth_service.dart';

/// Shows the real CourseWeb login page (which redirects through Microsoft
/// O365) inside a WebView. We never touch the username/password fields —
/// the user logs in exactly like they would in a browser. Once the WebView
/// lands back on an authenticated courseweb.sliit.lk page, we pop back with
/// `true` so the caller can move on to fetching announcements.
class LmsLoginScreen extends StatefulWidget {
  const LmsLoginScreen({super.key});

  @override
  State<LmsLoginScreen> createState() => _LmsLoginScreenState();
}

class _LmsLoginScreenState extends State<LmsLoginScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageFinished: _onPageFinished,
        ),
      )
      ..loadRequest(Uri.parse(LmsAuthService.loginUrl));
  }

  Future<void> _onPageFinished(String url) async {
    if (_finishing) return;
    if (LmsAuthService.instance.looksLoggedIn(url) &&
        !url.contains('login.microsoftonline') &&
        !url.contains('login.live.com')) {
      _finishing = true;
      await LmsAuthService.instance.setLoggedIn(true);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in to CourseWeb'),
        actions: [
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
    );
  }
}
