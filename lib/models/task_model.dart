import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String userId;
  final String taskName;
  final String category;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final int expectedDuration;
  final DateTime? date;
  final bool completed;
  final String? focusModeId;
  final int? sortOrder;
  final String? coinAwardedDate; // Format: 'YYYY-MM-DD' - tracks if coin was already awarded today

  Task({
    required this.id,
    String? userId,
    String? taskName,
    String? title,
    String? category,
    String? status,
    this.startTime,
    this.endTime,
    int? durationSeconds,
    int? duration,
    int? expectedDuration,
    this.date,
    bool? completed,
    bool? isCompleted,
    this.focusModeId,
    this.sortOrder,
    this.coinAwardedDate,
  })  : userId = userId ?? '',
        taskName = taskName ?? title ?? '',
        category = category ?? 'Personal',
        status = _normalizeStatus(
          status ?? ((completed ?? isCompleted ?? false) ? 'completed' : 'notStarted'),
        ),
        durationSeconds = durationSeconds ?? duration ?? 0,
        expectedDuration = expectedDuration ?? 0,
        completed = completed ?? isCompleted ?? false;

  String get title => taskName;
  bool get isCompleted => completed;
  bool get isNotStarted => status == 'notStarted';
  bool get isInProgress => status == 'inProgress';
  bool get isPaused => status == 'paused';
  bool get isActive => isInProgress || isPaused;
  bool get isDone => status == 'completed';

  int get duration => durationSeconds;

  Task copyWith({
    String? id,
    String? userId,
    String? taskName,
    String? category,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    int? expectedDuration,
    DateTime? date,
    bool? completed,
    String? focusModeId,
    int? sortOrder,
    String? coinAwardedDate,
    bool clearStartTime = false,
    bool clearEndTime = false,
    bool clearFocusModeId = false,
    bool clearCoinAwardedDate = false,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskName: taskName ?? this.taskName,
      category: category ?? this.category,
      status: status ?? this.status,
      startTime: clearStartTime ? null : startTime ?? this.startTime,
      endTime: clearEndTime ? null : endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      expectedDuration: expectedDuration ?? this.expectedDuration,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      focusModeId: clearFocusModeId ? null : focusModeId ?? this.focusModeId,
      sortOrder: sortOrder ?? this.sortOrder,
      coinAwardedDate: clearCoinAwardedDate ? null : coinAwardedDate ?? this.coinAwardedDate,
    );
  }

  factory Task.fromFirestore(String id, Map<String, dynamic> data) {
    return Task(
      id: id,
      userId: (data['userId'] ?? '').toString(),
      taskName: (data['taskName'] ?? data['title'] ?? '').toString(),
      category: (data['category'] ?? 'Personal').toString(),
      status: (data['status'] ?? 'notStarted').toString(),
      startTime: _parseDateTime(data['startTime']),
      endTime: _parseDateTime(data['endTime']),
      durationSeconds: _parseInt(data['durationSeconds'] ?? data['duration']),
      expectedDuration: _parseInt(data['expectedDuration']),
      date: _parseDateTime(data['date']),
      completed: data['completed'] == true,
      focusModeId: _parseFocusModeId(data['focusModeId']),
      sortOrder: _parseNullableInt(data['sortOrder']),
      coinAwardedDate: data['coinAwardedDate']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'taskName': taskName,
      'category': category,
      'status': status,
      'startTime': startTime,
      'endTime': endTime,
      'durationSeconds': durationSeconds,
      'expectedDuration': expectedDuration,
      'date': date?.toIso8601String(),
      'completed': completed,
      'focusModeId': focusModeId,
      'sortOrder': sortOrder,
      'coinAwardedDate': coinAwardedDate,
    };
  }

  static String _normalizeStatus(String value) {
    switch (value) {
      case 'in progress':
      case 'inProgress':
        return 'inProgress';
      case 'paused':
        return 'paused';
      case 'completed':
        return 'completed';
      default:
        return 'notStarted';
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static String? _parseFocusModeId(dynamic value) {
    if (value == null) {
      return null;
    }

    final String parsed = value.toString().trim();
    if (parsed.isEmpty) {
      return null;
    }

    return parsed;
  }
}
