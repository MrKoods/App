import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a checklist (preset) shared from one user to another.
/// Status can be: 'pending', 'accepted', or 'declined'.
/// The [tasks] field is a snapshot of the preset's tasks at the time of sharing.
class SharedChecklist {
  final String id;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String checklistId;
  final String checklistTitle;
  final String status;
  final List<Map<String, dynamic>> tasks;
  final DateTime? createdAt;

  const SharedChecklist({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.checklistId,
    required this.checklistTitle,
    required this.status,
    required this.tasks,
    this.createdAt,
  });

  factory SharedChecklist.fromFirestore(String id, Map<String, dynamic> data) {
    final List<dynamic> rawTasks = (data['tasks'] as List<dynamic>?) ?? [];
    return SharedChecklist(
      id: id,
      senderId: (data['senderId'] ?? '').toString(),
      senderEmail: (data['senderEmail'] ?? '').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      checklistId: (data['checklistId'] ?? '').toString(),
      checklistTitle: (data['checklistTitle'] ?? 'Untitled').toString(),
      status: (data['status'] ?? 'pending').toString(),
      tasks: rawTasks
          .whereType<Map>()
          .map((t) => Map<String, dynamic>.from(t))
          .toList(),
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
