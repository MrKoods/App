import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryEntry {
  final String id;
  final String userId;
  final String message;
  final DateTime? timestamp;

  HistoryEntry({
    required this.id,
    required this.userId,
    required this.message,
    this.timestamp,
  });

  factory HistoryEntry.fromFirestore(String id, Map<String, dynamic> data) {
    return HistoryEntry(
      id: id,
      userId: (data['userId'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      timestamp: _parseDateTime(data['timestamp']),
    );
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
}
