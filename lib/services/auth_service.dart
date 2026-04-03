import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _rememberMeKey = 'remember_me';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SIGN UP
  Future<String?> signUp(String email, String password) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      String uid = userCredential.user!.uid;

      // Create user document in Firestore
      await _firestore.collection('users').doc(uid).set({
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

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // LOGIN
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> setRememberMePreference(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  Future<bool> getRememberMePreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? true;
  }

  // Keep auth session persisted on web. Mobile platforms persist by default.
  Future<void> initializeAuthPersistence() async {
    if (!kIsWeb) return;

    await _auth.setPersistence(Persistence.LOCAL);
  }

  // FORGOT PASSWORD
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}
