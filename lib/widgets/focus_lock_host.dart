import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/focus_session.dart';
import '../models/focus_preset_model.dart';
import '../models/task_model.dart';
import '../screens/focus_lock_screen.dart';
import '../services/firestore_service.dart';
import '../services/focus_lock_service.dart';

class FocusLockHost extends StatefulWidget {
  final Widget child;
  final FocusLockService? focusLockService;
  final Stream<List<Task>>? taskStream;
  final Widget Function(Task task, FocusSession session)? focusScreenBuilder;

  const FocusLockHost({
    super.key,
    required this.child,
    this.focusLockService,
    this.taskStream,
    this.focusScreenBuilder,
  });

  @override
  State<FocusLockHost> createState() => _FocusLockHostState();
}

class _FocusLockHostState extends State<FocusLockHost> with WidgetsBindingObserver {
  late final FocusLockService _focusLockService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  FirestoreService? _firestoreService;
  bool _isReconcilingSession = false;
  String? _activeAudioTaskId;
  String? _activeAudioAssetPath;

  FirestoreService get _taskService => _firestoreService ??= FirestoreService();

  @override
  void initState() {
    super.initState();
    _focusLockService = widget.focusLockService ?? FocusLockService.instance;
    // Keep app volume at normal level; source audio is already gain-boosted.
    unawaited(_audioPlayer.setVolume(1.0));
    unawaited(_audioPlayer.setReleaseMode(ReleaseMode.loop));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    unawaited(_stopFocusAudio());
    unawaited(_audioPlayer.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_focusLockService.restoreSession());
    }
  }

  Task? _findTaskById(List<Task> tasks, String taskId) {
    for (final Task task in tasks) {
      if (task.id == taskId) {
        return task;
      }
    }

    return null;
  }

  FocusSoundOption? _soundForTask(Task task) {
    final String? modeId = task.focusModeId;
    if (modeId == null || modeId.isEmpty) {
      return null;
    }

    for (final FocusPreset preset in FocusLibrary.presets) {
      if (preset.id == modeId) {
        return FocusLibrary.soundByLabel(preset.suggestedSoundLabel);
      }
    }

    return null;
  }

  Future<void> _playFocusAudio(Task task) async {
    final FocusSoundOption? sound = _soundForTask(task);
    if (sound == null) {
      await _stopFocusAudio();
      return;
    }

    final bool alreadyPlayingSameTrack =
        _activeAudioTaskId == task.id && _activeAudioAssetPath == sound.assetPath;
    if (alreadyPlayingSameTrack) {
      return;
    }

    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(sound.assetPath));
    _activeAudioTaskId = task.id;
    _activeAudioAssetPath = sound.assetPath;
  }

  Future<void> _stopFocusAudio() async {
    await _audioPlayer.stop();
    _activeAudioTaskId = null;
    _activeAudioAssetPath = null;
  }

  Future<void> _syncActiveTask(FocusSession session, Task? task) async {
    if (_isReconcilingSession) {
      return;
    }

    _isReconcilingSession = true;
    try {
      if (task == null) {
        // Task stream can be transiently empty during reconnect/startup.
        return;
      }

      if (!task.isInProgress) {
        await _stopFocusAudio();
        await _focusLockService.stopSession();
        return;
      }

      await _focusLockService.syncWithTask(task);
      await _playFocusAudio(task);
    } finally {
      _isReconcilingSession = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Stream<List<Task>> taskStream = widget.taskStream ?? _taskService.watchTasks();

    return AnimatedBuilder(
      animation: _focusLockService,
      builder: (context, _) {
        final FocusSession? session = _focusLockService.activeSession;
        if (session == null || !session.isActive) {
          unawaited(_stopFocusAudio());
          return widget.child;
        }

        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: StreamBuilder<List<Task>>(
                stream: taskStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final Task? activeTask = _findTaskById(snapshot.data!, session.taskId);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    unawaited(_syncActiveTask(session, activeTask));
                  });

                  if (activeTask == null || !activeTask.isInProgress) {
                    unawaited(_stopFocusAudio());
                    return const SizedBox.shrink();
                  }

                  if (widget.focusScreenBuilder != null) {
                    return widget.focusScreenBuilder!(activeTask, session);
                  }

                  return FocusLockScreen(
                    task: activeTask,
                    session: session,
                    focusLockService: _focusLockService,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}