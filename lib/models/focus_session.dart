class FocusSession {
  final String taskId;
  final String taskName;
  final DateTime startedAt;
  final bool isActive;

  const FocusSession({
    required this.taskId,
    required this.taskName,
    required this.startedAt,
    required this.isActive,
  });

  FocusSession copyWith({
    String? taskId,
    String? taskName,
    DateTime? startedAt,
    bool? isActive,
  }) {
    return FocusSession(
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      startedAt: startedAt ?? this.startedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'taskId': taskId,
      'taskName': taskName,
      'startedAt': startedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    return FocusSession(
      taskId: (map['taskId'] ?? '').toString(),
      taskName: (map['taskName'] ?? '').toString(),
      startedAt: _parseDateTime(map['startedAt']) ?? DateTime.now(),
      isActive: map['isActive'] != false,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}