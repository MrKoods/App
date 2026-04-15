import 'dart:async';

import 'package:flutter/material.dart';

import '../models/focus_session.dart';
import '../models/task_model.dart';
import '../models/task_completion_result.dart';
import '../services/firestore_service.dart';
import '../services/focus_lock_service.dart';

class FocusLockScreen extends StatefulWidget {
  final Task task;
  final FocusSession session;
  final FocusLockService? focusLockService;
  final Future<void> Function(Task task)? onStopTask;
  final Future<int> Function(Task task)? onPauseTask;
  final Future<TaskCompletionResult> Function(Task task)? onCompleteTask;
  final ValueChanged<int>? onNavigateTab;

  const FocusLockScreen({
    super.key,
    required this.task,
    required this.session,
    this.focusLockService,
    this.onStopTask,
    this.onPauseTask,
    this.onCompleteTask,
    this.onNavigateTab,
  });

  @override
  State<FocusLockScreen> createState() => _FocusLockScreenState();
}

class _FocusLockScreenState extends State<FocusLockScreen> {
  FirestoreService? _firestoreService;
  late final FocusLockService _focusLockService;

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _surfaceAltColor = Color(0xFF101522);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  FirestoreService get _taskService => _firestoreService ??= FirestoreService();

  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _focusLockService = widget.focusLockService ?? FocusLockService.instance;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime get _startedAt => widget.task.startTime ?? widget.session.startedAt;

  Duration get _elapsed {
    final Duration carriedDuration = Duration(seconds: widget.task.durationSeconds);
    final Duration liveDuration = _now.difference(_startedAt);
    final int liveSeconds = liveDuration.isNegative ? 0 : liveDuration.inSeconds;
    return carriedDuration + Duration(seconds: liveSeconds);
  }

  String _formatElapsed(Duration value) {
    final String hours = value.inHours.toString().padLeft(2, '0');
    final String minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _returnToTaskList() {
    widget.onNavigateTab?.call(1);
  }

  Future<void> _handleStopTask() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      if (widget.onStopTask != null) {
        await widget.onStopTask!(widget.task);
      } else {
        await _taskService.resetTask(task: widget.task);
      }

      _returnToTaskList();
      await _focusLockService.stopSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.task.taskName} stopped')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to stop task')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handlePauseTask() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final int pausedSeconds = widget.onPauseTask != null
          ? await widget.onPauseTask!(widget.task)
          : await _taskService.pauseTask(task: widget.task);

      _returnToTaskList();
      await _focusLockService.stopSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.task.taskName} paused at ${_formatElapsed(Duration(seconds: pausedSeconds))}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pause task')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleCompleteTask() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final TaskCompletionResult result = widget.onCompleteTask != null
          ? await widget.onCompleteTask!(widget.task)
          : await _taskService.finishTask(task: widget.task);

      _returnToTaskList();
      await _focusLockService.completeSession();

      if (!mounted) {
        return;
      }

      final int durationSeconds = result.durationSeconds;
      final int minutes = (durationSeconds / 60).ceil();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.task.taskName} completed in $minutes min. +1 coin'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to complete task')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Focus lock is active until you pause, stop, or complete the task.')),
        );
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Focus lock is active',
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.task.taskName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Stay on this screen until you pause, stop, or complete the task.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _surfaceAltColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_clock, color: _secondaryAccent, size: 42),
                        const SizedBox(height: 20),
                        Text(
                          _formatElapsed(_elapsed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Running timer',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _handlePauseTask,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accentColor,
                          side: const BorderSide(color: _accentColor),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Pause Task'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _handleStopTask,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Stop Task'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : _handleCompleteTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _secondaryAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Complete Task'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}