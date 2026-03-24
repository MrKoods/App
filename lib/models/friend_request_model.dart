import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a friend request between two users.
/// Status can be: 'pending', 'accepted', or 'declined'.
class FriendRequest {
  final String id;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String receiverEmail;
  final String status;
  final DateTime? createdAt;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.receiverEmail,
    required this.status,
    this.createdAt,
  });

  factory FriendRequest.fromFirestore(String id, Map<String, dynamic> data) {
    return FriendRequest(
      id: id,
      senderId: (data['senderId'] ?? '').toString(),
      senderEmail: (data['senderEmail'] ?? '').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      receiverEmail: (data['receiverEmail'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
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
