import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:microwins/models/task_model.dart';
import 'package:microwins/services/focus_lock_service.dart';

void main() {
  final FocusLockService service = FocusLockService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await service.resetForTesting();
    await service.initialize();
  });

  tearDown(() async {
    await service.resetForTesting();
  });

  Task buildTask({
    String id = 'task-1',
    String name = 'Deep Work',
    DateTime? startTime,
  }) {
    return Task(
      id: id,
      taskName: name,
      status: 'inProgress',
      startTime: startTime ?? DateTime(2026, 3, 29, 9),
      completed: false,
    );
  }

  test('startSession persists and restoreSession reloads active session', () async {
    final Task task = buildTask();

    await service.startSession(task: task);

    expect(service.isFocusLockActive, isTrue);
    expect(service.activeSession?.taskId, task.id);
    expect(service.activeSession?.taskName, task.taskName);

    await service.resetForTesting(clearPersistence: false);
    await service.initialize();

    expect(service.isFocusLockActive, isTrue);
    expect(service.activeSession?.taskId, task.id);
    expect(service.activeSession?.taskName, task.taskName);
    expect(service.activeSession?.startedAt, task.startTime);
  });

  test('stopSession clears active session and persistence', () async {
    await service.startSession(task: buildTask());

    await service.stopSession();
    await service.resetForTesting(clearPersistence: false);
    await service.initialize();

    expect(service.isFocusLockActive, isFalse);
    expect(service.activeSession, isNull);
  });

  test('completeSession clears active session and persistence', () async {
    await service.startSession(task: buildTask());

    await service.completeSession();
    await service.resetForTesting(clearPersistence: false);
    await service.initialize();

    expect(service.isFocusLockActive, isFalse);
    expect(service.activeSession, isNull);
  });
}