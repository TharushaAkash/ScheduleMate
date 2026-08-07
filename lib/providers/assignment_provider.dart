import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/assignment_model.dart';
import '../services/notification_service.dart';

class AssignmentProvider with ChangeNotifier {
  List<Assignment> _assignments = [];

  List<Assignment> get assignments => _assignments;

  /// Get assignments sorted by the closest upcoming milestone
  List<Assignment> get sortedAssignments {
    final list = List<Assignment>.from(_assignments);
    list.sort((a, b) {
      final aNext = a.nextMilestone;
      final bNext = b.nextMilestone;
      
      // If both are fully completed, sort by creation date (newest first)
      if (aNext == null && bNext == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      
      // If one is completed and the other isn't, put the uncompleted one first
      if (aNext == null) return 1;
      if (bNext == null) return -1;
      
      // Sort by closest deadline
      return aNext.deadline.compareTo(bNext.deadline);
    });
    return list;
  }

  AssignmentProvider() {
    loadAssignments();
  }

  Future<void> loadAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('assignments_data');
    if (data != null) {
      final List<dynamic> decoded = json.decode(data);
      _assignments = decoded.map((item) => Assignment.fromMap(item)).toList();
      notifyListeners();
    }
  }

  Future<void> saveAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_assignments.map((a) => a.toMap()).toList());
    await prefs.setString('assignments_data', encoded);
    notifyListeners();
    _syncNotifications();
  }

  void _syncNotifications() {
    // 1. We could track which notifications were scheduled, but it's simpler 
    // to just re-schedule pending ones. We must be careful not to cancel all
    // because timetable uses cancelAll() too, unless we only cancel specific IDs.
    // For milestones, we'll use a unique ID based on the milestone ID string hash.
    for (var assignment in _assignments) {
      for (var milestone in assignment.milestones) {
        // Generate a positive integer ID for flutter_local_notifications
        final notificationId = (milestone.id.hashCode & 0x7FFFFFFF) % 100000 + 300000;
        
        if (milestone.isCompleted || milestone.deadline.isBefore(DateTime.now())) {
          // Cancel it if it's done or passed
          NotificationService.instance.cancelNotification(notificationId);
        } else {
          // Schedule it
          NotificationService.instance.scheduleAssignmentReminder(
            notificationId,
            'Deadline Approaching: ${assignment.moduleCode}',
            'Milestone "${milestone.title}" is due soon!',
            milestone.deadline,
          );
        }
      }
    }
  }

  Future<void> addAssignment(Assignment assignment) async {
    _assignments.add(assignment);
    await saveAssignments();
  }

  Future<void> updateAssignment(Assignment assignment) async {
    final index = _assignments.indexWhere((a) => a.id == assignment.id);
    if (index != -1) {
      _assignments[index] = assignment;
      await saveAssignments();
    }
  }

  Future<void> deleteAssignment(String id) async {
    final index = _assignments.indexWhere((a) => a.id == id);
    if (index != -1) {
      // Cancel all notifications for this assignment before deleting
      for (var m in _assignments[index].milestones) {
        final notificationId = (m.id.hashCode & 0x7FFFFFFF) % 100000 + 300000;
        NotificationService.instance.cancelNotification(notificationId);
      }
      _assignments.removeAt(index);
      await saveAssignments();
    }
  }

  Future<void> toggleMilestone(String assignmentId, String milestoneId) async {
    final assignmentIndex = _assignments.indexWhere((a) => a.id == assignmentId);
    if (assignmentIndex != -1) {
      final assignment = _assignments[assignmentIndex];
      final milestoneIndex = assignment.milestones.indexWhere((m) => m.id == milestoneId);
      if (milestoneIndex != -1) {
        assignment.milestones[milestoneIndex].isCompleted = !assignment.milestones[milestoneIndex].isCompleted;
        await saveAssignments();
      }
    }
  }
}
