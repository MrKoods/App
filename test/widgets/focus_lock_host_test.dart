import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:microwins/models/task_model.dart';
import 'package:microwins/services/focus_lock_service.dart';
import 'package:microwins/widgets/focus_lock_host.dart';

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

  Task buildTask({required String status}) {
    return Task(
      id: 'task-1',
      taskName: 'Locked task',
      status: status,
      startTime: DateTime(2026, 3, 29, 9),
      completed: status == 'completed',
    );
  }

  testWidgets('shows overlay for active session and removes it when task is no longer running',
      (tester) async {
    final StreamController<List<Task>> controller = StreamController<List<Task>>.broadcast();
    await service.startSession(task: buildTask(status: 'inProgress'));

    await tester.pumpWidget(
      MaterialApp(
        home: FocusLockHost(
          focusLockService: service,
          taskStream: controller.stream,
          focusScreenBuilder: (task, session) => Material(
            child: Center(child: Text('LOCK:${task.taskName}')),
          ),
          child: const Scaffold(body: Center(child: Text('HOME'))),
        ),
      ),
    );

    controller.add(<Task>[buildTask(status: 'inProgress')]);
    await tester.pump();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('LOCK:Locked task'), findsOneWidget);

    controller.add(<Task>[buildTask(status: 'completed')]);
    await tester.pump();
    await tester.pump();

    expect(find.text('LOCK:Locked task'), findsNothing);
    expect(service.isFocusLockActive, isFalse);

    await controller.close();
  });

  testWidgets('restores locked overlay on app resume without pushing duplicate routes', (tester) async {
    final StreamController<List<Task>> controller = StreamController<List<Task>>.broadcast();
    await service.startSession(task: buildTask(status: 'inProgress'));
    service.clearInMemorySessionForTesting();

    await tester.pumpWidget(
      MaterialApp(
        home: FocusLockHost(
          focusLockService: service,
          taskStream: controller.stream,
          focusScreenBuilder: (task, session) => Material(
            child: Center(child: Text('LOCK:${task.taskName}')),
          ),
          child: const Scaffold(body: Center(child: Text('HOME'))),
        ),
      ),
    );

    controller.add(<Task>[buildTask(status: 'inProgress')]);
    await tester.pump();

    expect(find.text('LOCK:Locked task'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    controller.add(<Task>[buildTask(status: 'inProgress')]);
    await tester.pump();

    expect(find.text('LOCK:Locked task'), findsOneWidget);
    expect(find.byType(Navigator), findsOneWidget);

    await controller.close();
  });
}