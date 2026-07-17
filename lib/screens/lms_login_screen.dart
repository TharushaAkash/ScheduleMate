import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
  late final InAppWebViewController _controller;
  double _progress = 0;
  bool _finishing = false;
  String? _errorMessage;

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

  Future<void> _openInExternalBrowser() async {
    final uri = Uri.parse(LmsAuthService.loginUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in to CourseWeb'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in browser',
            onPressed: _openInExternalBrowser,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _errorMessage = null);
              _controller.reload();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1)
            LinearProgressIndicator(value: _progress, minHeight: 3),
          if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () {
                          setState(() => _errorMessage = null);
                          _controller.reload();
                        },
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _openInExternalBrowser,
                        child: const Text('Open in browser'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(LmsAuthService.loginUrl)),
                onWebViewCreated: (controller) => _controller = controller,
                onLoadStart: (controller, url) => setState(() => _errorMessage = null),
                onLoadStop: (controller, url) {
                  if (url != null) _onPageFinished(url.toString());
                },
                onProgressChanged: (controller, progress) {
                  setState(() => _progress = progress / 100);
                },
                onReceivedError: (controller, request, error) {
                  setState(() {
                    _errorMessage = '${error.type}: ${error.description}';
                  });
                },
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                },
              ),
            ),
        ],
      ),
    );
  }
}
