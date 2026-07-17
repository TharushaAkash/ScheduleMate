import 'package:flutter/foundation.dart';

import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/io_client.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/announcement.dart';
import '../services/announcement_parser.dart';
import '../services/database_helper.dart';
import '../services/lms_auth_service.dart';

class AnnouncementProvider extends ChangeNotifier {
  List<Announcement> announcements = [];
  bool isLoggedIn = false;
  bool isLoading = false;

  int get unreadCount => announcements.where((a) => !a.isRead).length;

  Future<void> init() async {
    isLoggedIn = await LmsAuthService.instance.isLoggedIn();
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    announcements = await DatabaseHelper.instance.getAnnouncements();
    isLoading = false;
    notifyListeners();
  }

  /// Automatically fetches the main announcements page using the saved session cookies.
  Future<bool> autoFetchAnnouncements() async {
    if (!isLoggedIn) return false;
    
    isLoading = true;
    notifyListeners();

    try {
      final url = 'https://courseweb.sliit.lk/course/view.php?id=25';
      final cookies = await CookieManager.instance().getCookies(url: WebUri(url));
      final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');

      // Bypass SSL errors since the emulator has certificate issues
      final httpClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final client = IOClient(httpClient);

      var response = await client.get(
        Uri.parse(url),
        headers: {
          'Cookie': cookieString,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        var htmlBody = response.body;
        var currentUrl = url;

        // If this is a course page, try to find the link to the actual Announcements forum
        if (url.contains('course/view.php')) {
          final doc = html_parser.parse(htmlBody);
          // Look for a link containing "forum/view.php" that might be the announcements
          final forumLinks = doc.querySelectorAll('a[href*="mod/forum/view.php"]');
          String? bestForumUrl;
          for (final link in forumLinks) {
            final text = link.text.toLowerCase();
            if (text.contains('announcement') || text.contains('notice')) {
              bestForumUrl = link.attributes['href'];
              break;
            }
          }
          bestForumUrl ??= forumLinks.isNotEmpty ? forumLinks.first.attributes['href'] : null;

          if (bestForumUrl != null) {
            // Fetch the actual forum page
            final forumResponse = await client.get(
              Uri.parse(bestForumUrl),
              headers: {
                'Cookie': cookieString,
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            );
            if (forumResponse.statusCode == 200) {
              htmlBody = forumResponse.body;
              currentUrl = bestForumUrl;
            }
          }
        }

        final found = AnnouncementParser.parse(htmlBody, currentUrl);
        var newCount = 0;
        for (final a in found.reversed) {
          final inserted = await DatabaseHelper.instance.insertAnnouncementIfNew(a);
          if (inserted > 0) newCount++;
        }
        
        if (newCount > 0) {
          announcements = await DatabaseHelper.instance.getAnnouncements();
        }
      }
    } catch (e) {
      debugPrint('Auto fetch error: $e');
    }

    isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> setLoggedIn(bool value) async {
    isLoggedIn = value;
    notifyListeners();
  }

  Future<void> markRead(Announcement a) async {
    if (a.id == null || a.isRead) return;
    a.isRead = true;
    await DatabaseHelper.instance.markAnnouncementRead(a.id!);
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await DatabaseHelper.instance.markAllAnnouncementsRead();
    for (final a in announcements) {
      a.isRead = true;
    }
    notifyListeners();
  }

  Future<void> delete(Announcement a) async {
    if (a.id == null) return;
    await DatabaseHelper.instance.deleteAnnouncement(a.id!);
    announcements.removeWhere((e) => e.id == a.id);
    notifyListeners();
  }

  Future<void> deleteAll() async {
    await DatabaseHelper.instance.clearAnnouncements();
    announcements.clear();
    notifyListeners();
  }

  Future<void> logout() async {
    await LmsAuthService.instance.logout();
    isLoggedIn = false;
    notifyListeners();
  }
}
