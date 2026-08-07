import 'dart:convert';
import 'package:uuid/uuid.dart';

class Milestone {
  final String id;
  String title;
  DateTime deadline;
  bool isCompleted;

  Milestone({
    String? id,
    required this.title,
    required this.deadline,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      id: map['id'],
      title: map['title'],
      deadline: DateTime.parse(map['deadline']),
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class Assignment {
  final String id;
  String title;
  String moduleCode;
  String moduleName;
  String description;
  List<Milestone> milestones;
  DateTime createdAt;

  Assignment({
    String? id,
    required this.title,
    required this.moduleCode,
    required this.moduleName,
    this.description = '',
    required this.milestones,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Gets the closest upcoming milestone that is NOT completed.
  Milestone? get nextMilestone {
    final pending = milestones.where((m) => !m.isCompleted).toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.deadline.compareTo(b.deadline));
    return pending.first;
  }

  /// Calculates the completion percentage (0.0 to 1.0)
  double get progress {
    if (milestones.isEmpty) return 0.0;
    final completed = milestones.where((m) => m.isCompleted).length;
    return completed / milestones.length;
  }

  /// Checks if all milestones are completed
  bool get isFullyCompleted {
    if (milestones.isEmpty) return false;
    return milestones.every((m) => m.isCompleted);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'moduleCode': moduleCode,
      'moduleName': moduleName,
      'description': description,
      'milestones': milestones.map((x) => x.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'],
      title: map['title'],
      moduleCode: map['moduleCode'],
      moduleName: map['moduleName'] ?? '',
      description: map['description'] ?? '',
      milestones: List<Milestone>.from(
          (map['milestones'] ?? []).map((x) => Milestone.fromMap(x))),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Assignment.fromJson(String source) =>
      Assignment.fromMap(json.decode(source));
}
