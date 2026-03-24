import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/friend_request_model.dart';
import '../models/friendship_model.dart';

/// Handles all Firestore operations for the friend system.
class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;
  String get currentEmail => _auth.currentUser?.email ?? '';

  // ─── Search ────────────────────────────────────────────────────────────────

  /// Searches for users whose email starts with [query].
  /// Excludes the current user from results.
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String query) async {
    if (query.trim().isEmpty) return [];

    final String trimmed = query.trim().toLowerCase();

    // Firestore prefix search using range query
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: trimmed)
        .where('email', isLessThan: '${trimmed}z')
        .limit(20)
        .get();

    return snap.docs
        .where((doc) => doc.id != uid)
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .toList();
  }

  // ─── Friend Requests ───────────────────────────────────────────────────────

  /// Sends a friend request from the current user to [receiverId].
  /// Returns an error string if the request could not be sent, null on success.
  Future<String?> sendFriendRequest({
    required String receiverId,
    required String receiverEmail,
  }) async {
    // Cannot add yourself
    if (receiverId == uid) return 'You cannot send a request to yourself.';

    // Check for existing pending request in either direction
    final QuerySnapshot<Map<String, dynamic>> existing = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: uid)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) return 'Friend request already sent.';

    // Check reverse direction too
    final QuerySnapshot<Map<String, dynamic>> reverse = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: receiverId)
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (reverse.docs.isNotEmpty) {
      return 'This user has already sent you a friend request.';
    }

    // Check if already friends
    final QuerySnapshot<Map<String, dynamic>> alreadyFriends = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: uid)
        .where('friendId', isEqualTo: receiverId)
        .get();

    if (alreadyFriends.docs.isNotEmpty) return 'You are already friends.';

    await _firestore.collection('friend_requests').add({
      'senderId': uid,
      'senderEmail': currentEmail,
      'receiverId': receiverId,
      'receiverEmail': receiverEmail,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return null; // success
  }

  /// Accepts a pending friend request.
  /// Creates symmetric friendship docs for both users.
  Future<void> acceptFriendRequest(FriendRequest request) async {
    final WriteBatch batch = _firestore.batch();

    // Update the request status
    batch.update(
      _firestore.collection('friend_requests').doc(request.id),
      {'status': 'accepted'},
    );

    // Create friendship: current user → sender
    final DocumentReference<Map<String, dynamic>> myRef =
        _firestore.collection('friends').doc();
    batch.set(myRef, {
      'userId': uid,
      'friendId': request.senderId,
      'friendEmail': request.senderEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create friendship: sender → current user
    final DocumentReference<Map<String, dynamic>> theirRef =
        _firestore.collection('friends').doc();
    batch.set(theirRef, {
      'userId': request.senderId,
      'friendId': uid,
      'friendEmail': currentEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Declines a pending friend request.
  Future<void> declineFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'declined',
    });
  }

  // ─── Streams ───────────────────────────────────────────────────────────────

  /// Stream of accepted friendships for the current user.
  Stream<List<Friendship>> watchFriends() {
    return _firestore
        .collection('friends')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Friendship.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Stream of pending incoming friend requests for the current user.
  Stream<List<FriendRequest>> watchIncomingRequests() {
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendRequest.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Stream of pending outgoing friend requests sent by the current user.
  Stream<List<FriendRequest>> watchOutgoingRequests() {
    return _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendRequest.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// One-time fetch of the current user's friend IDs.
  Future<List<String>> getFriendIds() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: uid)
        .get();
    return snap.docs
        .map((doc) => (doc.data()['friendId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
  }
}
