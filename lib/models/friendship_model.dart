import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an accepted friendship between two users.
/// A friendship is stored as two symmetric documents:
///   - one where userId = A and friendId = B
///   - one where userId = B and friendId = A
class Friendship {
  final String id;
  final String userId;
  final String friendId;
  final String friendEmail;
  final DateTime? createdAt;

  const Friendship({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendEmail,
    this.createdAt,
  });

  factory Friendship.fromFirestore(String id, Map<String, dynamic> data) {
    return Friendship(
      id: id,
      userId: (data['userId'] ?? '').toString(),
      friendId: (data['friendId'] ?? '').toString(),
      friendEmail: (data['friendEmail'] ?? '').toString(),
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
