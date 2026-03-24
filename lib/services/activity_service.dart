import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity_post_model.dart';
import '../models/reaction_model.dart';
import '../models/shared_checklist_model.dart';
import '../models/preset_model.dart';

/// Handles activity feed, reactions, and checklist sharing.
class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;
  String get currentEmail => _auth.currentUser?.email ?? '';

  // ─── Activity Feed ─────────────────────────────────────────────────────────

  /// Posts an activity from the current user.
  /// [type] examples: 'task_completed', 'checklist_completed',
  ///   'streak_milestone', 'reward_redeemed', 'checklist_shared'
  Future<void> postActivity({
    required String type,
    required String message,
  }) async {
    await _firestore.collection('activity_feed').add({
      'userId': uid,
      'userEmail': currentEmail,
      'type': type,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches a one-time list of activity posts from the current user
  /// and their friends. Returns posts sorted by newest first (up to 50).
  Future<List<ActivityPost>> fetchFeed(List<String> friendIds) async {
    // Firestore whereIn supports up to 30 values; trim if needed
    final List<String> authorIds = [uid, ...friendIds].take(30).toList();

    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('activity_feed')
        .where('userId', whereIn: authorIds)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    return snap.docs
        .map((doc) => ActivityPost.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  // ─── Reactions ─────────────────────────────────────────────────────────────

  /// Adds a reaction of [reactionType] to [postId].
  /// Prevents duplicate reactions of the same type from the same user.
  Future<void> addReaction({
    required String postId,
    required String reactionType,
  }) async {
    // Check if this user already reacted with this type on this post
    final QuerySnapshot<Map<String, dynamic>> existing = await _firestore
        .collection('reactions')
        .where('postId', isEqualTo: postId)
        .where('userId', isEqualTo: uid)
        .where('reactionType', isEqualTo: reactionType)
        .get();

    if (existing.docs.isNotEmpty) return; // already reacted

    await _firestore.collection('reactions').add({
      'postId': postId,
      'userId': uid,
      'reactionType': reactionType,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Removes the current user's reaction of [reactionType] from [postId].
  Future<void> removeReaction({
    required String postId,
    required String reactionType,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('reactions')
        .where('postId', isEqualTo: postId)
        .where('userId', isEqualTo: uid)
        .where('reactionType', isEqualTo: reactionType)
        .get();

    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  /// Watches all reactions for a specific post.
  Stream<List<Reaction>> watchReactions(String postId) {
    return _firestore
        .collection('reactions')
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Reaction.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  // ─── Checklist Sharing ─────────────────────────────────────────────────────

  /// Shares a [preset] with [receiverId].
  /// Returns an error string on failure or null on success.
  Future<String?> shareChecklist({
    required TaskPreset preset,
    required String receiverId,
  }) async {
    // Don't share with yourself
    if (receiverId == uid) return 'Cannot share with yourself.';

    // Check for existing pending share of the same checklist to the same user
    final QuerySnapshot<Map<String, dynamic>> existing = await _firestore
        .collection('shared_checklists')
        .where('senderId', isEqualTo: uid)
        .where('receiverId', isEqualTo: receiverId)
        .where('checklistId', isEqualTo: preset.id)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) {
      return 'You already shared this checklist with that friend.';
    }

    // Snapshot the tasks at time of sharing
    final List<Map<String, dynamic>> taskSnapshots = preset.tasks
        .map((t) => {'taskName': t.taskName, 'category': t.category})
        .toList();

    await _firestore.collection('shared_checklists').add({
      'senderId': uid,
      'senderEmail': currentEmail,
      'receiverId': receiverId,
      'checklistId': preset.id,
      'checklistTitle': preset.name,
      'status': 'pending',
      'tasks': taskSnapshots,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Post an activity for the share
    await postActivity(
      type: 'checklist_shared',
      message: 'Shared checklist "${preset.name}"',
    );

    return null; // success
  }

  /// Stream of pending shared checklists where the current user is the receiver.
  Stream<List<SharedChecklist>> watchIncomingSharedChecklists() {
    return _firestore
        .collection('shared_checklists')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SharedChecklist.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Stream of shared checklists sent by the current user.
  Stream<List<SharedChecklist>> watchOutgoingSharedChecklists() {
    return _firestore
        .collection('shared_checklists')
        .where('senderId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SharedChecklist.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Declines a shared checklist request.
  Future<void> declineSharedChecklist(String shareId) async {
    await _firestore
        .collection('shared_checklists')
        .doc(shareId)
        .update({'status': 'declined'});
  }

  /// Accepts a shared checklist: copies its tasks into the receiver's task list,
  /// then marks the share as accepted.
  ///
  /// If [wipeFirst] is true, all of the receiver's existing tasks are deleted
  /// before the shared tasks are added (i.e. "replace" mode).
  Future<void> acceptSharedChecklist(
    SharedChecklist share, {
    bool wipeFirst = false,
  }) async {
    final WriteBatch batch = _firestore.batch();

    // Wipe existing tasks if the user chose "replace" mode
    if (wipeFirst) {
      final QuerySnapshot<Map<String, dynamic>> existing = await _firestore
          .collection('tasks')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }
    }

    // Copy each shared task into the receiver's tasks collection
    for (final taskData in share.tasks) {
      final DocumentReference<Map<String, dynamic>> taskRef =
          _firestore.collection('tasks').doc();
      batch.set(taskRef, {
        'userId': uid,
        'taskName': (taskData['taskName'] ?? '').toString(),
        'category': (taskData['category'] ?? 'Personal').toString(),
        'status': 'notStarted',
        'startTime': null,
        'endTime': null,
        'durationSeconds': 0,
        'expectedDuration': 0,
        'date': DateTime.now().toIso8601String(),
        'completed': false,
        'sharedFromUserId': share.senderId,
        'templateSourceId': share.checklistId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Mark the share as accepted
    batch.update(
      _firestore.collection('shared_checklists').doc(share.id),
      {'status': 'accepted'},
    );

    await batch.commit();
  }
}
