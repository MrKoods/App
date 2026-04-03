import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get userDoc =>
      _firestore.collection('users').doc(uid);

  Future<void> createUserDocument(String email) async {
    await userDoc.set({
      'email': email,
      'coins': 0,
      'xp': 0,
      'level': 1,
      'currentStreak': 0,
      'longestStreak': 0,
      'perfectDays': 0,
      'totalCompletedDays': 0,
      'unlockedBadges': <String>[],
      'unlockedTitles': <String>[],
      'checklistCompletedToday': false,
      'rewardGivenToday': false,
      'lastChecklistDate': null,
      'streakFreezeCount': 0,
      'missedDayPassCount': 0,
      'autoCompleteTaskTokens': 0,
      'streakShieldDays': 0,
      'doubleXpTomorrow': false,
      'doubleCoinsTomorrow': false,
      'skipTodayTokens': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateChecklistCompleted(bool value) async {
    await userDoc.update({'checklistCompletedToday': value});
  }

  Future<void> updateRewardGiven(bool value) async {
    await userDoc.update({'rewardGivenToday': value});
  }

  Future<void> updateStreak({
    required int currentStreak,
    required int longestStreak,
    required int perfectDays,
  }) async {
    await userDoc.update({
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'perfectDays': perfectDays,
    });
  }
}
