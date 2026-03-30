import 'package:cloud_firestore/cloud_firestore.dart';

class TaskTemplate {
  final String taskName;
  final String category;
  final String? focusModeId;

  const TaskTemplate({
    required this.taskName,
    required this.category,
    this.focusModeId,
  });

  Map<String, dynamic> toMap() => {
        'taskName': taskName,
        'category': category,
        'focusModeId': focusModeId,
      };

  factory TaskTemplate.fromMap(Map<String, dynamic> data) {
    final String rawFocusModeId = (data['focusModeId'] ?? '').toString().trim();

    return TaskTemplate(
      taskName: (data['taskName'] ?? '').toString(),
      category: (data['category'] ?? 'Personal').toString(),
      focusModeId: rawFocusModeId.isEmpty ? null : rawFocusModeId,
    );
  }
}

class TaskPreset {
  final String id;
  final String userId;
  final String name;
  final List<TaskTemplate> tasks;
  final String dayAssignment;
  final DateTime? createdAt;

  const TaskPreset({
    required this.id,
    required this.userId,
    required this.name,
    required this.tasks,
    this.dayAssignment = 'Any',
    this.createdAt,
  });

  factory TaskPreset.fromFirestore(String id, Map<String, dynamic> data) {
    final List<dynamic> rawTasks = (data['tasks'] as List<dynamic>?) ?? [];
    return TaskPreset(
      id: id,
      userId: (data['userId'] ?? '').toString(),
      name: (data['name'] ?? 'Unnamed Preset').toString(),
      tasks: rawTasks
          .whereType<Map>()
          .map((t) => TaskTemplate.fromMap(Map<String, dynamic>.from(t)))
          .toList(),
      dayAssignment: (data['dayAssignment'] ?? 'Any').toString(),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
