import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:microwins/models/focus_session.dart';
import 'package:microwins/models/task_model.dart';
import 'package:microwins/screens/focus_lock_screen.dart';
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

  Task buildTask() {
    return Task(
      id: 'task-1',
      taskName: 'Locked task',
      status: 'inProgress',
      startTime: DateTime(2026, 3, 29, 9),
      completed: false,
    );
  }

  FocusSession buildSession() {
    return FocusSession(
      taskId: 'task-1',
      taskName: 'Locked task',
      startedAt: DateTime(2026, 3, 29, 9),
      isActive: true,
    );
  }

  testWidgets('back navigation is blocked while focus lock is active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FocusLockScreen(
                          task: buildTask(),
                          session: buildSession(),
                          focusLockService: service,
                          onStopTask: (_) async {},
                          onCompleteTask: (_) async => 60,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Focus lock is active'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Focus lock is active'), findsOneWidget);
    expect(
      find.text('Focus lock is active until you stop or complete the task.'),
      findsOneWidget,
    );
  });

  testWidgets('stop button clears active session', (tester) async {
    bool stopCalled = false;
    final Task task = buildTask();
    await service.startSession(task: task);

    await tester.pumpWidget(
      MaterialApp(
        home: FocusLockScreen(
          task: task,
          session: service.activeSession!,
          focusLockService: service,
          onStopTask: (_) async {
            stopCalled = true;
          },
          onCompleteTask: (_) async => 60,
        ),
      ),
    );

    await tester.tap(find.text('Stop Task'));
    await tester.pumpAndSettle();

    expect(stopCalled, isTrue);
    expect(service.isFocusLockActive, isFalse);
    expect(find.text('Locked task stopped'), findsOneWidget);
  });

  testWidgets('complete button clears active session', (tester) async {
    bool completeCalled = false;
    final Task task = buildTask();
    await service.startSession(task: task);

    await tester.pumpWidget(
      MaterialApp(
        home: FocusLockScreen(
          task: task,
          session: service.activeSession!,
          focusLockService: service,
          onStopTask: (_) async {},
          onCompleteTask: (_) async {
            completeCalled = true;
            return 120;
          },
        ),
      ),
    );

    await tester.tap(find.text('Complete Task'));
    await tester.pumpAndSettle();

    expect(completeCalled, isTrue);
    expect(service.isFocusLockActive, isFalse);
    expect(find.text('Locked task completed in 2 min. +1 coin'), findsOneWidget);
  });
}