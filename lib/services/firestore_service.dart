import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/history_model.dart';
import '../models/preset_model.dart';
import '../models/task_model.dart';
import 'activity_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get userDoc =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get tasksCollection =>
      _firestore.collection('tasks');

    CollectionReference<Map<String, dynamic>> get historyCollection =>
      _firestore.collection('history');

    CollectionReference<Map<String, dynamic>> get presetsCollection =>
      _firestore.collection('presets');

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStream() {
    return userDoc.snapshots();
  }

  Stream<Map<String, dynamic>?> watchUserData() {
    return getUserStream().map((snapshot) => snapshot.data());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getTasksStream() {
    return tasksCollection.where('userId', isEqualTo: uid).snapshots();
  }

  Stream<List<Task>> watchTasks() {
    return getTasksStream().map((snapshot) {
      final List<Task> tasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc.id, doc.data()))
          .toList();

      tasks.sort((first, second) {
        final DateTime firstDate = first.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime secondDate = second.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return firstDate.compareTo(secondDate);
      });

      return tasks;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getHistoryStream() {
    return historyCollection
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<List<HistoryEntry>> watchHistory() {
    return getHistoryStream().map(
      (snapshot) => snapshot.docs
          .map((doc) => HistoryEntry.fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }

  Map<String, int> buildDailySummary({
    required List<Task> tasks,
    required List<HistoryEntry> historyItems,
    required Map<String, dynamic> userData,
  }) {
    final DateTime now = DateTime.now();
    final List<Task> todaysTasks = tasks.where((task) => _isSameDay(task.date, now)).toList();

    final int tasksCompletedToday = todaysTasks.where((task) => task.completed).length;
    final int totalFocusTimeSeconds = todaysTasks.fold<int>(
      0,
      (acc, task) => acc + task.durationSeconds,
    );

    final int coinsEarnedToday = historyItems
        .where((entry) => _isSameDay(entry.timestamp, now))
        .fold<int>(0, (acc, entry) => acc + _coinsFromHistory(entry.message));

    return <String, int>{
      'tasksCompletedToday': tasksCompletedToday,
      'totalFocusTimeSeconds': totalFocusTimeSeconds,
      'coinsEarnedToday': coinsEarnedToday,
      'currentStreak': _readInt(userData['currentStreak']),
    };
  }

  Future<void> addTask({
    required String taskName,
    required String category,
  }) async {
    final int sortOrder = DateTime.now().microsecondsSinceEpoch;

    await tasksCollection.add({
      'userId': uid,
      'taskName': taskName,
      'category': category,
      'status': 'notStarted',
      'startTime': null,
      'endTime': null,
      'durationSeconds': 0,
      'expectedDuration': 0,
      'date': DateTime.now().toIso8601String(),
      'completed': false,
      'focusModeId': null,
      'sortOrder': sortOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> startTask({required Task task}) async {
    final QuerySnapshot<Map<String, dynamic>> activeTaskSnapshot = await tasksCollection
        .where('userId', isEqualTo: uid)
      .where('status', whereIn: <String>['inProgress', 'paused'])
        .get();

    final bool hasAnotherTaskRunning = activeTaskSnapshot.docs.any((doc) => doc.id != task.id);

    if (hasAnotherTaskRunning) {
      return false;
    }

    final DateTime now = DateTime.now();
    final int carriedDurationSeconds = task.isPaused ? task.durationSeconds : 0;

    await tasksCollection.doc(task.id).update({
      'status': 'inProgress',
      'startTime': now,
      'endTime': null,
      'durationSeconds': carriedDurationSeconds,
      'completed': false,
      'date': now.toIso8601String(),
    });

    return true;
  }

  Future<int> pauseTask({required Task task}) async {
    final DocumentSnapshot<Map<String, dynamic>> taskSnapshot =
        await tasksCollection.doc(task.id).get();

    if (!taskSnapshot.exists) {
      return task.durationSeconds;
    }

    final Task latestTask = Task.fromFirestore(taskSnapshot.id, taskSnapshot.data()!);
    final DateTime now = DateTime.now();
    final DateTime segmentStart = latestTask.startTime ?? now;
    final int segmentSeconds = now.difference(segmentStart).inSeconds;
    final int totalDurationSeconds =
        (latestTask.durationSeconds + (segmentSeconds < 0 ? 0 : segmentSeconds));

    await tasksCollection.doc(task.id).update({
      'status': 'paused',
      'startTime': null,
      'endTime': null,
      'durationSeconds': totalDurationSeconds,
      'completed': false,
      'date': now.toIso8601String(),
    });

    await addHistory('${latestTask.taskName} paused');

    return totalDurationSeconds;
  }

  Future<int> finishTask({required Task task}) async {
    final DocumentSnapshot<Map<String, dynamic>> taskSnapshot =
        await tasksCollection.doc(task.id).get();

    if (!taskSnapshot.exists) {
      return 0;
    }

    final Task latestTask = Task.fromFirestore(taskSnapshot.id, taskSnapshot.data()!);
    final DateTime endTime = DateTime.now();
    final DateTime segmentStart = latestTask.startTime ?? endTime;
    final int segmentSeconds = endTime.difference(segmentStart).inSeconds;
    final int safeSegmentSeconds = segmentSeconds < 0 ? 0 : segmentSeconds;
    final int safeDurationSeconds = latestTask.durationSeconds + safeSegmentSeconds;

    await tasksCollection.doc(task.id).update({
      'status': 'completed',
      'startTime': latestTask.startTime ?? endTime,
      'endTime': endTime,
      'durationSeconds': safeDurationSeconds,
      'completed': true,
      'date': (latestTask.date ?? endTime).toIso8601String(),
    });

    await userDoc.update({
      'coins': FieldValue.increment(1),
    });

    await addHistory(
      '${latestTask.taskName} completed in ${_formatMinutes(safeDurationSeconds)}',
    );

    // Post task completion to activity feed
    await ActivityService().postActivity(
      type: 'task_completed',
      message: '${latestTask.taskName} completed in ${_formatMinutes(safeDurationSeconds)}',
    );

    await _updateDailyProgress(referenceDate: latestTask.date ?? endTime);

    return safeDurationSeconds;
  }

  Future<int> completeTaskDirectly({required Task task}) async {
    final DateTime now = DateTime.now();

    await tasksCollection.doc(task.id).update({
      'status': 'completed',
      'startTime': now,
      'endTime': now,
      'durationSeconds': 0,
      'completed': true,
      'date': now.toIso8601String(),
    });

    await userDoc.update({
      'coins': FieldValue.increment(1),
    });

    await addHistory('${task.taskName} completed in 0 minutes');
    await _updateDailyProgress(referenceDate: now);

    return 0;
  }

  Future<void> markTaskCompletedFromFocus({
    required Task task,
    required int focusedSeconds,
  }) async {
    final DateTime now = DateTime.now();

    await tasksCollection.doc(task.id).update({
      'status': 'completed',
      'startTime': task.startTime ?? now,
      'endTime': now,
      'durationSeconds': focusedSeconds < 0 ? 0 : focusedSeconds,
      'completed': true,
      'date': now.toIso8601String(),
    });

    await addHistory('${task.taskName} completed with a focus session');
    await _updateDailyProgress(referenceDate: now);
  }

  Future<void> resetTask({required Task task}) async {
    final DateTime now = DateTime.now();

    await tasksCollection.doc(task.id).update({
      'status': 'notStarted',
      'startTime': null,
      'endTime': null,
      'durationSeconds': 0,
      'completed': false,
      'date': now.toIso8601String(),
    });

    await addHistory('${task.taskName} reset');
  }

  Future<void> updateTaskFocusMode({
    required String taskId,
    String? focusModeId,
  }) async {
    await tasksCollection.doc(taskId).update({
      'focusModeId': (focusModeId == null || focusModeId.trim().isEmpty)
          ? null
          : focusModeId.trim(),
    });
  }

  Future<void> updateCoins(int newCoins) async {
    await userDoc.update({
      'coins': newCoins,
    });
  }

  Future<void> updateStreaks({
    required int currentStreak,
    required int longestStreak,
    required int perfectDays,
    required bool checklistCompletedToday,
    required bool rewardGivenToday,
    DateTime? lastChecklistDate,
  }) async {
    await userDoc.update({
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'perfectDays': perfectDays,
      'checklistCompletedToday': checklistCompletedToday,
      'rewardGivenToday': rewardGivenToday,
      'lastChecklistDate': lastChecklistDate?.toIso8601String(),
    });
  }

  Future<void> addHistory(String message) async {
    await historyCollection.add({
      'userId': uid,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateDailyProgress({required DateTime referenceDate}) async {
    final DocumentSnapshot<Map<String, dynamic>> userSnapshot = await userDoc.get();
    final Map<String, dynamic> userData = userSnapshot.data() ?? <String, dynamic>{};
    final DateTime? lastChecklistDate = _readDateTime(userData['lastChecklistDate']);
    final bool alreadyRewardedToday = _isSameDay(lastChecklistDate, referenceDate);

    final QuerySnapshot<Map<String, dynamic>> taskSnapshot =
        await tasksCollection.where('userId', isEqualTo: uid).get();

    final List<Task> todaysTasks = taskSnapshot.docs
        .map((doc) => Task.fromFirestore(doc.id, doc.data()))
        .where((task) => _isSameDay(task.date, referenceDate))
        .toList();

    final bool allCompleted =
        todaysTasks.isNotEmpty && todaysTasks.every((currentTask) => currentTask.completed);

    await userDoc.update({
      'checklistCompletedToday': allCompleted,
      'rewardGivenToday': alreadyRewardedToday,
    });

    if (!allCompleted || alreadyRewardedToday) {
      return;
    }

    int currentCoins = _readInt(userData['coins']);
    int currentStreak = 1;
    int longestStreak = _readInt(userData['longestStreak']);
    int perfectDays = _readInt(userData['perfectDays']) + 1;
    int bonusCoins = 1;

    final DateTime previousDay = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day - 1,
    );

    if (_isSameDay(lastChecklistDate, previousDay)) {
      currentStreak = _readInt(userData['currentStreak']) + 1;
    }

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    await addHistory('Daily checklist completed +1 coin');

    // Post daily checklist completion to activity feed
    await ActivityService().postActivity(
      type: 'checklist_completed',
      message: 'Completed daily checklist!',
    );

    if (currentStreak == 3) {
      bonusCoins += 1;
      await addHistory('3-day streak reward +1 coin');
      await ActivityService().postActivity(
        type: 'streak_milestone',
        message: 'Reached a 3-day streak! 🔥',
      );
    }

    if (currentStreak == 7) {
      bonusCoins += 2;
      await addHistory('7-day streak reward +2 coins');
      await ActivityService().postActivity(
        type: 'streak_milestone',
        message: 'Reached a 7-day streak! 🔥🔥',
      );
    }

    currentCoins += bonusCoins;

    await updateCoins(currentCoins);
    await updateStreaks(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      perfectDays: perfectDays,
      checklistCompletedToday: true,
      rewardGivenToday: true,
      lastChecklistDate: referenceDate,
    );
  }

  int _coinsFromHistory(String message) {
    final String value = message.toLowerCase();

    if (value.contains('completed in')) {
      return 1;
    }

    final RegExp matchExp = RegExp(r'\+(\d+)\s+coin');
    final RegExpMatch? match = matchExp.firstMatch(value);

    if (match == null) {
      return 0;
    }

    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isSameDay(DateTime? left, DateTime right) {
    if (left == null) {
      return false;
    }

    final DateTime localLeft = left.toLocal();
    final DateTime localRight = right.toLocal();

    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day;
  }

  DateTime? _readDateTime(dynamic value) {
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

  String _formatMinutes(int durationSeconds) {
    final int minutes = (durationSeconds / 60).ceil();
    return '$minutes minutes';
  }

  // ─── Presets ───────────────────────────────────────────────────────────────

  Stream<List<TaskPreset>> watchPresets() {
    return presetsCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final List<TaskPreset> presets = snapshot.docs
          .map((doc) => TaskPreset.fromFirestore(doc.id, doc.data()))
          .toList();
      presets.sort((a, b) => a.name.compareTo(b.name));
      return presets;
    });
  }

  /// Save multiple tasks for a specific date.
  /// Used when user adds multiple tasks at once with a selected date.
  Future<void> addMultipleTasks({
    required List<dynamic> taskInputs, // List of TaskInput objects from add_task_screen.dart
    required DateTime selectedDate,
  }) async {
    final WriteBatch batch = _firestore.batch();
    final int baseSortOrder = DateTime.now().microsecondsSinceEpoch;
    int sequenceOffset = 0;

    for (final dynamic input in taskInputs) {
      // Each taskInput has: controller (TextEditingController), category (String)
      final String taskName = input.controller.text.trim();
      final String category = input.category;

      if (taskName.isEmpty) {
        continue; // Skip empty tasks
      }

      final DocumentReference<Map<String, dynamic>> ref = tasksCollection.doc();
      batch.set(ref, {
        'userId': uid,
        'taskName': taskName,
        'category': category,
        'status': 'notStarted',
        'startTime': null,
        'endTime': null,
        'durationSeconds': 0,
        'expectedDuration': 0,
        'date': selectedDate.toIso8601String(),
        'completed': false,
        'focusModeId': null,
        'sortOrder': baseSortOrder + sequenceOffset,
        'createdAt': FieldValue.serverTimestamp(),
      });

      sequenceOffset += 1;
    }

    await batch.commit();
  }

  /// Save multiple tasks as a preset template.
  /// Used when user wants to save tasks as a reusable preset without adding them to the daily checklist.
  Future<void> savePreset({
    required String name,
    required List<dynamic> taskInputs, // List of TaskInput objects from add_task_screen.dart
    String dayAssignment = 'Any',
  }) async {
    // Convert TaskInput objects to task templates
    final List<Map<String, dynamic>> taskTemplates = [];

    int sequence = 0;
    for (final dynamic input in taskInputs) {
      final String taskName = input.controller.text.trim();
      final String category = input.category;

      if (taskName.isEmpty) {
        continue; // Skip empty tasks
      }

      taskTemplates.add({
        'taskName': taskName,
        'category': category,
        'focusModeId': null,
        'sequence': sequence,
      });

      sequence += 1;
    }

    if (taskTemplates.isEmpty) {
      throw Exception('Cannot save preset with no tasks');
    }

    await presetsCollection.add({
      'userId': uid,
      'name': name,
      'dayAssignment': dayAssignment,
      'tasks': taskTemplates,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Original savePreset method for backward compatibility.
  /// Kept for existing code that uses Task objects.
  Future<void> savePresetFromTasks({
    required String name,
    required String dayAssignment,
    required List<Task> tasks,
  }) async {
    final List<Task> orderedTasks = [...tasks]
      ..sort((a, b) {
        final int left = a.sortOrder ?? 1 << 30;
        final int right = b.sortOrder ?? 1 << 30;
        return left.compareTo(right);
      });

    final List<Map<String, dynamic>> taskTemplates = orderedTasks
        .asMap()
        .entries
        .map((entry) {
          final Task t = entry.value;
          return <String, dynamic>{
            'taskName': t.taskName,
            'category': t.category,
            'focusModeId': t.focusModeId,
            'sequence': entry.key,
          };
        })
        .toList();

    await presetsCollection.add({
      'userId': uid,
      'name': name,
      'dayAssignment': dayAssignment,
      'tasks': taskTemplates,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Overwrites an existing preset with a new snapshot of tasks.
  Future<void> updatePresetFromTasks({
    required String presetId,
    required String name,
    required String dayAssignment,
    required List<Task> tasks,
  }) async {
    final List<Task> orderedTasks = [...tasks]
      ..sort((a, b) {
        final int left = a.sortOrder ?? 1 << 30;
        final int right = b.sortOrder ?? 1 << 30;
        return left.compareTo(right);
      });

    final List<Map<String, dynamic>> taskTemplates = orderedTasks
        .asMap()
        .entries
        .map((entry) {
          final Task t = entry.value;
          return <String, dynamic>{
            'taskName': t.taskName,
            'category': t.category,
            'focusModeId': t.focusModeId,
            'sequence': entry.key,
          };
        })
        .toList();

    await presetsCollection.doc(presetId).update({
      'userId': uid,
      'name': name,
      'dayAssignment': dayAssignment,
      'tasks': taskTemplates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTask(String taskId) async {
    await tasksCollection.doc(taskId).delete();
  }

  Future<int> clearAllTasksForCurrentUser() async {
    final QuerySnapshot<Map<String, dynamic>> taskSnapshot =
        await tasksCollection.where('userId', isEqualTo: uid).get();

    if (taskSnapshot.docs.isEmpty) {
      return 0;
    }

    int deletedCount = 0;
    const int batchSize = 400;

    for (int start = 0; start < taskSnapshot.docs.length; start += batchSize) {
      final int end =
          (start + batchSize) > taskSnapshot.docs.length ? taskSnapshot.docs.length : (start + batchSize);
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> chunk =
          taskSnapshot.docs.sublist(start, end);

      final WriteBatch batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      deletedCount += chunk.length;
    }

    return deletedCount;
  }

  Future<void> deletePreset(String presetId) async {
    await presetsCollection.doc(presetId).delete();
  }

  Future<void> applyPreset(TaskPreset preset, {bool wipeFirst = false}) async {
    final WriteBatch batch = _firestore.batch();
    final List<TaskTemplate> orderedTemplates = [...preset.tasks]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final int baseSortOrder = wipeFirst ? 0 : DateTime.now().microsecondsSinceEpoch;

    if (wipeFirst) {
      final QuerySnapshot<Map<String, dynamic>> existingTasks =
          await tasksCollection.where('userId', isEqualTo: uid).get();
      for (final doc in existingTasks.docs) {
        batch.delete(doc.reference);
      }
    }

    for (int i = 0; i < orderedTemplates.length; i++) {
      final TaskTemplate template = orderedTemplates[i];
      final DocumentReference<Map<String, dynamic>> ref = tasksCollection.doc();
      batch.set(ref, {
        'userId': uid,
        'taskName': template.taskName,
        'category': template.category,
        'status': 'notStarted',
        'startTime': null,
        'endTime': null,
        'durationSeconds': 0,
        'expectedDuration': 0,
        'date': DateTime.now().toIso8601String(),
        'completed': false,
        'focusModeId': template.focusModeId,
        'sortOrder': baseSortOrder + i,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateTaskSequence(List<Task> orderedTasks) async {
    final WriteBatch batch = _firestore.batch();

    for (int i = 0; i < orderedTasks.length; i++) {
      final Task task = orderedTasks[i];
      batch.update(tasksCollection.doc(task.id), {'sortOrder': i});
    }

    await batch.commit();
  }
}