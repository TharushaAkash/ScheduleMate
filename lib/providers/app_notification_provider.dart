import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class AppNotificationProvider extends ChangeNotifier {
  static final StreamController<void> updateStream = StreamController.broadcast();
  
  List<AppNotification> _notifications = [];
  bool _isDisposed = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  AppNotificationProvider() {
    loadNotifications();
    updateStream.stream.listen((_) {
      loadNotifications();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    // Reload prefs in case background isolate updated them
    await prefs.reload();
    final jsonList = prefs.getStringList('fcm_notifications') ?? [];
    _notifications = jsonList
        .map((e) => AppNotification.fromJson(jsonDecode(e)))
        .toList();
    // Sort newest first
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final jsonList = _notifications.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('fcm_notifications', jsonList);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> addNotification(AppNotification notification) async {
    await loadNotifications();
    _notifications.insert(0, notification);
    await _saveNotifications();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      await _saveNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    await _saveNotifications();
  }

  Future<void> deleteAll() async {
    _notifications.clear();
    await _saveNotifications();
  }

  // Helper method for background handlers to save without needing a provider instance
  static Future<void> saveMessageToPrefs(String id, String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final jsonList = prefs.getStringList('fcm_notifications') ?? [];
    
    final newNotif = AppNotification(
      id: id,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      isRead: false,
    );
    
    jsonList.add(jsonEncode(newNotif.toJson()));
    await prefs.setStringList('fcm_notifications', jsonList);
  }
}
