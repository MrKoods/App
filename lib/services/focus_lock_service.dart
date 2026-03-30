import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_session.dart';
import '../models/task_model.dart';

class FocusLockService extends ChangeNotifier {
  FocusLockService._();

  static final FocusLockService instance = FocusLockService._();
  static const String _activeSessionKey = 'focus_lock.active_session';
  static const MethodChannel _platformChannel = MethodChannel('microwins/focus_lock');

  SharedPreferences? _prefs;
  FocusSession? _activeSession;
  bool _isTransitioningSession = false;

  FocusSession? get activeSession => _activeSession;
  bool get isFocusLockActive => _activeSession?.isActive == true;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await restoreSession();
  }

  Future<void> restoreSession() async {
    _prefs ??= await SharedPreferences.getInstance();

    final String? encodedSession = _prefs!.getString(_activeSessionKey);
    if (encodedSession == null || encodedSession.isEmpty) {
      if (_activeSession != null) {
        _activeSession = null;
        notifyListeners();
      }

      // Ensure native lock states are reset when there is no persisted session.
      await _stopLockTaskMode();
      await _exitImmersiveMode();
      return;
    }

    try {
      final Object? decoded = jsonDecode(encodedSession);
      if (decoded is! Map<String, dynamic>) {
        await _clearStoredSession(notify: true);
        return;
      }

      final FocusSession restored = FocusSession.fromMap(decoded);
      if (restored.taskId.isEmpty || restored.taskName.isEmpty) {
        await _clearStoredSession(notify: true);
        return;
      }

      _activeSession = restored;
      await _enterImmersiveMode();
      await _startLockTaskMode();
      notifyListeners();
    } catch (_) {
      await _clearStoredSession(notify: true);
    }
  }

  Future<void> startSession({required Task task}) async {
    await _waitForTransitionToFinish();

    final FocusSession? current = _activeSession;
    if (current != null && current.isActive && current.taskId != task.id) {
      // Keep the existing active session as the single source of truth.
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();

    _isTransitioningSession = true;
    _activeSession = FocusSession(
      taskId: task.id,
      taskName: task.taskName,
      startedAt: task.startTime ?? DateTime.now(),
      isActive: true,
    );

    try {
      await _prefs!.setString(
        _activeSessionKey,
        jsonEncode(_activeSession!.toMap()),
      );

      await _enterImmersiveMode();
      await _startLockTaskMode();
      notifyListeners();
    } finally {
      _isTransitioningSession = false;
    }
  }

  Future<void> stopSession() async {
    await _clearStoredSession(notify: true);
  }

  Future<void> completeSession() async {
    await _clearStoredSession(notify: true);
  }

  Future<void> syncWithTask(Task task) async {
    final FocusSession? current = _activeSession;
    if (current == null || current.taskId != task.id) {
      return;
    }

    if (!task.isInProgress) {
      await _clearStoredSession(notify: true);
      return;
    }

    final DateTime syncedStartedAt = task.startTime ?? current.startedAt;
    final FocusSession updated = current.copyWith(
      taskName: task.taskName,
      startedAt: syncedStartedAt,
      isActive: true,
    );

    if (updated.taskName == current.taskName &&
        updated.startedAt == current.startedAt &&
        updated.isActive == current.isActive) {
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();
    _activeSession = updated;
    await _prefs!.setString(_activeSessionKey, jsonEncode(updated.toMap()));
    notifyListeners();
  }

  Future<void> _clearStoredSession({required bool notify}) async {
    await _waitForTransitionToFinish();

    _prefs ??= await SharedPreferences.getInstance();

    _isTransitioningSession = true;
    try {
      _activeSession = null;
      await _prefs!.remove(_activeSessionKey);
      await _stopLockTaskMode();
      await _exitImmersiveMode();

      if (notify) {
        notifyListeners();
      }
    } finally {
      _isTransitioningSession = false;
    }
  }

  Future<void> _waitForTransitionToFinish() async {
    while (_isTransitioningSession) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _enterImmersiveMode() async {
    await _invokeNativeMethod('enterImmersiveMode');
  }

  Future<void> _exitImmersiveMode() async {
    await _invokeNativeMethod('exitImmersiveMode');
  }

  Future<void> _startLockTaskMode() async {
    await _invokeNativeBoolMethod('startLockTaskMode');
  }

  Future<void> _stopLockTaskMode() async {
    await _invokeNativeBoolMethod('stopLockTaskMode');
  }

  Future<void> _invokeNativeMethod(String method) async {
    if (kIsWeb) {
      return;
    }

    try {
      await _platformChannel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Non-Android platforms may not implement this channel.
    } on PlatformException {
      // Ignore platform failures to keep focus session flow resilient.
    } catch (_) {
      // Best-effort native call: ignore any unexpected runtime failures.
    }
  }

  Future<bool> _invokeNativeBoolMethod(String method) async {
    if (kIsWeb) {
      return false;
    }

    try {
      final bool? result = await _platformChannel.invokeMethod<bool>(method);
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  Future<void> resetForTesting({bool clearPersistence = true}) async {
    if (clearPersistence) {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_activeSessionKey);
    }

    _activeSession = null;
    _prefs = null;
    notifyListeners();
  }

  @visibleForTesting
  void clearInMemorySessionForTesting() {
    _activeSession = null;
    notifyListeners();
  }
}