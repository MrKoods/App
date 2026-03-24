import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a reaction on an activity post.
/// Types: 'like', 'clap', 'fire', 'goodjob'
class Reaction {
  final String id;
  final String postId;
  final String userId;
  final String reactionType;
  final DateTime? timestamp;

  const Reaction({
    required this.id,
    required this.postId,
    required this.userId,
    required this.reactionType,
    this.timestamp,
  });

  factory Reaction.fromFirestore(String id, Map<String, dynamic> data) {
    return Reaction(
      id: id,
      postId: (data['postId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      reactionType: (data['reactionType'] ?? '').toString(),
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
