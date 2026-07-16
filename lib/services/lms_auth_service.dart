import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Tracks whether the user has an active CourseWeb (Moodle) session inside
/// the app's WebView, and provides a way to log out (clear cookies).
///
/// We never see or store the user's Microsoft O365 password — login happens
/// entirely inside a normal WebView showing the real CourseWeb/Microsoft
/// pages, and we only remember "did the user complete login before" so the
/// UI can skip straight to the dashboard next time (the WebView's own
/// cookies, kept by the OS, decide whether that session is still valid).
class LmsAuthService {
  LmsAuthService._internal();
  static final LmsAuthService instance = LmsAuthService._internal();

  static const _loggedInKey = 'lms_logged_in';
  static const dashboardUrl = 'https://courseweb.sliit.lk/my/';
  static const loginUrl = 'https://courseweb.sliit.lk/login/index.php';

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, value);
  }

  Future<void> logout() async {
    await CookieManager.instance().deleteAllCookies();
    await setLoggedIn(false);
  }

  /// A URL is considered "logged in" once it lands on the dashboard
  /// (my/) or any authenticated courseweb.sliit.lk page that isn't the
  /// login form itself.
  bool looksLoggedIn(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !u.host.contains('sliit.lk')) return false;
    if (u.path.contains('/login/')) return false;
    return true;
  }
}
