import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a post in the activity feed.
/// Types: 'task_completed', 'checklist_completed', 'streak_milestone',
///        'reward_redeemed', 'checklist_shared'
class ActivityPost {
  final String id;
  final String userId;
  final String userEmail;
  final String type;
  final String message;
  final DateTime? timestamp;

  const ActivityPost({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.type,
    required this.message,
    this.timestamp,
  });

  factory ActivityPost.fromFirestore(String id, Map<String, dynamic> data) {
    return ActivityPost(
      id: id,
      userId: (data['userId'] ?? '').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      timestamp: _parseDateTime(data['timestamp']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
