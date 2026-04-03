import 'dart:async';

import 'package:flutter/material.dart';

import '../models/completion_reward_summary.dart';
import '../models/focus_preset_model.dart';
import '../models/preset_model.dart';
import '../models/task_completion_result.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../services/focus_lock_service.dart';
import '../widgets/task_tile.dart';
import 'checklist_complete_screen.dart';
import 'share_checklist_screen.dart';

class ListScreen extends StatefulWidget {
  final List<Task> tasks;
  final ValueChanged<int>? onNavigateTab;

  const ListScreen({super.key, required this.tasks, this.onNavigateTab});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FocusLockService _focusLockService = FocusLockService.instance;
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _savingOrder = false;
  bool _isOpeningCompletionScreen = false;

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  static const List<String> _dayOptions = [
    'Any',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String get _todayName {
    const List<String> days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[DateTime.now().weekday - 1];
  }

  @override
  void initState() {
    super.initState();
    _syncTimer(widget.tasks);
  }

  @override
  void didUpdateWidget(covariant ListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer(widget.tasks);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer(List<Task> tasks) {
    final bool hasRunningTask = tasks.any(
      (task) => task.isInProgress && task.startTime != null,
    );

    if (hasRunningTask && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
        });
      });
    }

    if (!hasRunningTask && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  FocusPreset? _focusPresetForTask(Task task) {
    final String? modeId = task.focusModeId;
    if (modeId == null || modeId.isEmpty) {
      return null;
    }

    for (final FocusPreset preset in FocusLibrary.presets) {
      if (preset.id == modeId) {
        return preset;
      }
    }

    return null;
  }

  String? _focusModeLabel(Task task) {
    return _focusPresetForTask(task)?.title;
  }

  Future<void> _handleStartTask(Task task) async {
    final bool resumingPausedTask = task.isPaused;
    final bool started = await _firestoreService.startTask(task: task);
    if (!mounted) return;

    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish your current task first.')),
      );
      return;
    }

    await _focusLockService.startSession(
      task: task.copyWith(
        status: 'inProgress',
        startTime: DateTime.now(),
        durationSeconds: task.durationSeconds,
        completed: false,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${task.taskName} ${resumingPausedTask ? 'resumed' : 'started'}',
        ),
      ),
    );
  }

  Future<void> _handleFinishTask(Task task) async {
    final result = await _firestoreService.finishTask(task: task);
    if (!mounted) return;

    final int durationSeconds = result.durationSeconds;
    final int minutes = (durationSeconds / 60).ceil();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${task.taskName} completed in $minutes min. +1 coin'),
      ),
    );

    await _openCompletionScreenIfNeeded(result.rewardSummary);
  }

  Future<void> _handleCheckboxChanged(Task task, List<Task> tasks) async {
    if (task.completed) return;

    if (task.isActive) {
      await _handleFinishTask(task);
      return;
    }

    final bool anotherTaskRunning = tasks.any(
      (t) => t.id != task.id && t.isActive,
    );

    if (anotherTaskRunning) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish your current task first.')),
      );
      return;
    }

    final result = await _firestoreService.completeTaskDirectly(task: task);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${task.taskName} completed. +1 coin')),
    );

    await _openCompletionScreenIfNeeded(result.rewardSummary);
  }

  Future<void> _handleAutoCompleteToken(
    Task task,
    List<Task> tasks,
    int tokens,
  ) async {
    if (task.completed) {
      return;
    }

    if (tokens <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No auto-complete tokens available.')),
      );
      return;
    }

    final bool anotherTaskRunning = tasks.any(
      (t) => t.id != task.id && t.isActive,
    );
    if (anotherTaskRunning) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish your current task first.')),
      );
      return;
    }

    try {
      final TaskCompletionResult result = await _firestoreService
          .autoCompleteTaskWithToken(task: task);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${task.taskName} auto-completed using token.')),
      );

      await _openCompletionScreenIfNeeded(result.rewardSummary);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not use auto-complete token.')),
      );
    }
  }

  Future<void> _openCompletionScreenIfNeeded(
    CompletionRewardSummary? summary,
  ) async {
    if (summary == null || _isOpeningCompletionScreen || !mounted) {
      return;
    }

    _isOpeningCompletionScreen = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChecklistCompleteScreen(
            summary: summary,
            onBackToHome: () => widget.onNavigateTab?.call(1),
            onViewRewards: () => widget.onNavigateTab?.call(3),
          ),
        ),
      );
    } finally {
      _isOpeningCompletionScreen = false;
    }
  }

  Future<void> _handleResetTask(Task task) async {
    await _firestoreService.resetTask(task: task);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${task.taskName} reset')));
  }

  int _orderValue(Task task) => task.sortOrder ?? (1 << 30);

  List<Task> _orderedTasks(List<Task> tasks) {
    final List<Task> ordered = [...tasks];
    ordered.sort((a, b) => _orderValue(a).compareTo(_orderValue(b)));
    return ordered;
  }

  Future<void> _reorderTasks(int oldIndex, int newIndex) async {
    if (_savingOrder) {
      return;
    }

    final List<Task> ordered = _orderedTasks(widget.tasks);
    if (oldIndex < 0 || oldIndex >= ordered.length) {
      return;
    }

    final int targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (targetIndex < 0 || targetIndex >= ordered.length) {
      return;
    }

    final Task moved = ordered.removeAt(oldIndex);
    ordered.insert(targetIndex, moved);

    setState(() {
      _savingOrder = true;
    });

    try {
      await _firestoreService.updateTaskSequence(ordered);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save task order.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingOrder = false;
        });
      }
    }
  }

  Duration _elapsedForTask(Task task) {
    if (task.isPaused) {
      return Duration(seconds: task.durationSeconds);
    }

    if (!task.isInProgress || task.startTime == null) {
      return Duration(seconds: task.durationSeconds);
    }

    final Duration segment = _now.difference(task.startTime!);
    final int segmentSeconds = segment.isNegative ? 0 : segment.inSeconds;
    return Duration(seconds: task.durationSeconds + segmentSeconds);
  }

  bool _isPresetForToday(TaskPreset preset) =>
      preset.dayAssignment == 'Any' || preset.dayAssignment == _todayName;

  Future<void> _handleDeleteTask(Task task) async {
    // Show a quick confirmation so accidental taps don't delete immediately
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: const Text('Delete Task', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${task.taskName}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _firestoreService.deleteTask(task.id);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('"${task.taskName}" deleted')));
  }

  Future<void> _openFocusModePicker(Task task) async {
    String selectedModeId = task.focusModeId ?? '';

    final String? pickedModeId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (_, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focus Mode for "${task.taskName}"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    RadioGroup<String>(
                      groupValue: selectedModeId,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedModeId = value;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: FocusLibrary.presets
                            .map(
                              (preset) => RadioListTile<String>(
                                value: preset.id,
                                activeColor: _accentColor,
                                title: Text(
                                  preset.title,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  preset.suggestedSoundLabel,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        selectedModeId.isEmpty
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _accentColor,
                      ),
                      title: const Text(
                        'No Focus Mode',
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        setSheetState(() {
                          selectedModeId = '';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, selectedModeId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Save Focus Mode'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (pickedModeId == null) {
      return;
    }

    final String? nextFocusModeId = pickedModeId.isEmpty ? null : pickedModeId;
    await _firestoreService.updateTaskFocusMode(
      taskId: task.id,
      focusModeId: nextFocusModeId,
    );

    final String message = nextFocusModeId == null
        ? 'Focus mode cleared for ${task.taskName}'
        : 'Focus set to ${_focusModeLabel(task.copyWith(focusModeId: nextFocusModeId))}';

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmAndClearList() async {
    if (widget.tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your list is already empty.')),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: const Text('Clear List', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete all tasks from this list?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final int deletedCount = await _firestoreService
          .clearAllTasksForCurrentUser();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cleared $deletedCount task(s).')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to clear list. Please try again.'),
        ),
      );
    }
  }

  // Save preset dialog
  void _showSavePresetDialog(List<TaskPreset> presets) {
    final TextEditingController nameController = TextEditingController();
    String selectedDay = _todayName;
    bool replaceExisting = false;
    String? selectedPresetId = presets.isNotEmpty ? presets.first.id : null;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            TaskPreset? selectedPreset;
            if (selectedPresetId != null) {
              for (final TaskPreset preset in presets) {
                if (preset.id == selectedPresetId) {
                  selectedPreset = preset;
                  break;
                }
              }
            }

            return AlertDialog(
              backgroundColor: _surfaceColor,
              title: const Text(
                'Save as Preset',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (presets.isNotEmpty)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Replace existing preset',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: replaceExisting,
                      activeThumbColor: _accentColor,
                      activeTrackColor: _accentColor.withValues(alpha: 0.35),
                      onChanged: (value) {
                        setDialogState(() => replaceExisting = value);
                      },
                    ),
                  if (replaceExisting) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Select preset to replace',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedPresetId,
                      dropdownColor: _surfaceColor,
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      underline: Container(height: 1, color: Colors.white30),
                      items: presets
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text('${p.name} (${p.dayAssignment})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedPresetId = v);
                        }
                      },
                    ),
                  ] else ...[
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Preset name',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!replaceExisting) ...[
                    const Text(
                      'Assign to day',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedDay,
                      dropdownColor: _surfaceColor,
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      underline: Container(height: 1, color: Colors.white30),
                      items: _dayOptions
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedDay = v);
                      },
                    ),
                  ] else ...[
                    Text(
                      selectedPreset == null
                          ? 'Choose a preset to replace.'
                          : 'This will overwrite the saved tasks in "${selectedPreset.name}".',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '${widget.tasks.length} task(s) will be saved',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    if (replaceExisting) {
                      if (selectedPreset == null) {
                        return;
                      }

                      Navigator.pop(dialogContext);
                      await _firestoreService.updatePresetFromTasks(
                        presetId: selectedPreset.id,
                        name: selectedPreset.name,
                        dayAssignment: selectedPreset.dayAssignment,
                        tasks: _orderedTasks(widget.tasks),
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '"${selectedPreset.name}" updated with current list',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    final String name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(dialogContext);
                    await _firestoreService.savePresetFromTasks(
                      name: name,
                      dayAssignment: selectedDay,
                      tasks: _orderedTasks(widget.tasks),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"$name" saved as preset')),
                      );
                    }
                  },
                  child: Text(replaceExisting ? 'Replace' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Apply preset bottom sheet
  void _showApplyPresetSheet(TaskPreset preset) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preset.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      preset.dayAssignment,
                      style: const TextStyle(
                        color: _accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${preset.tasks.length} task(s) will be added to your list:',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              ...preset.tasks
                  .take(8)
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: _accentColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t.taskName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            t.category,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (preset.tasks.length > 8)
                Text(
                  '+ ${preset.tasks.length - 8} more...',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(height: 20),
              // Share button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share with a Friend'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFC857),
                    side: const BorderSide(
                      color: Color(0xFFFFC857),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShareChecklistScreen(preset: preset),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _showApplyPresetChoiceDialog(preset);
                  },
                  child: const Text(
                    'Apply Preset',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Ask user whether preset should add to current list or replace it.
  Future<void> _showApplyPresetChoiceDialog(TaskPreset preset) async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text(
          'Apply "${preset.name}"',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'How would you like to apply this preset?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'add'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentColor,
              side: const BorderSide(color: _accentColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Add to List'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'replace'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _secondaryAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Replace List',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    await _firestoreService.applyPreset(preset, wipeFirst: choice == 'replace');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          choice == 'replace'
              ? '"${preset.name}" replaced your list.'
              : '"${preset.name}" applied — ${preset.tasks.length} task(s) added',
        ),
      ),
    );
  }

  // Delete preset confirm
  Future<void> _confirmDeletePreset(TaskPreset preset) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: const Text(
          'Delete Preset',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete "${preset.name}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestoreService.deletePreset(preset.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('"${preset.name}" deleted')));
      }
    }
  }

  // Preset chip bar
  Widget _buildPresetBar(List<TaskPreset> presets) {
    final String today = _todayName;
    final List<TaskPreset> sorted = [...presets]
      ..sort((a, b) {
        final bool aT = a.dayAssignment == today || a.dayAssignment == 'Any';
        final bool bT = b.dayAssignment == today || b.dayAssignment == 'Any';
        if (aT && !bT) return -1;
        if (!aT && bT) return 1;
        return a.name.compareTo(b.name);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.bookmark_rounded, color: _accentColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Presets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.tasks.isEmpty
                    ? null
                    : () => _showSavePresetDialog(presets),
                icon: const Icon(Icons.save_alt, size: 15),
                label: const Text('Save current list'),
                style: TextButton.styleFrom(
                  foregroundColor: _secondaryAccent,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (presets.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'No presets yet. Add tasks, then tap "Save current list".',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
          )
        else
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final TaskPreset p = sorted[i];
                final bool isToday = _isPresetForToday(p);
                return GestureDetector(
                  onLongPress: () => _confirmDeletePreset(p),
                  child: ActionChip(
                    backgroundColor: isToday
                        ? _accentColor.withValues(alpha: 0.15)
                        : _surfaceColor,
                    side: BorderSide(
                      color: isToday
                          ? _accentColor.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            color: isToday ? _accentColor : Colors.white70,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isToday
                                ? _accentColor.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            p.dayAssignment == 'Any'
                                ? 'Any'
                                : p.dayAssignment.substring(0, 3),
                            style: TextStyle(
                              color: isToday ? _accentColor : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () => _showApplyPresetSheet(p),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncTimer(widget.tasks);

    final List<Task> sortedTasks = _orderedTasks(widget.tasks);

    return Container(
      color: _backgroundColor,
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: _firestoreService.watchUserData(),
        builder: (context, userSnap) {
          final Map<String, dynamic> userData =
              userSnap.data ?? const <String, dynamic>{};
          final int autoCompleteTaskTokens =
              (userData['autoCompleteTaskTokens'] as int?) ?? 0;

          return StreamBuilder<List<TaskPreset>>(
            stream: _firestoreService.watchPresets(),
            builder: (context, snap) {
              final List<TaskPreset> presets = snap.data ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text(
                          'My Checklist',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _confirmAndClearList,
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            size: 16,
                          ),
                          label: const Text('Clear List'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _todayName,
                          style: const TextStyle(
                            color: _accentColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      'Start one task, finish it, then move to the next.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPresetBar(presets),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Colors.white12, height: 1),
                  ),
                  Expanded(
                    child: sortedTasks.isEmpty
                        ? const Center(
                            child: Text(
                              'No tasks yet. Tap + to add one.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : ReorderableListView.builder(
                            onReorder: _reorderTasks,
                            buildDefaultDragHandles: false,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            itemCount: sortedTasks.length,
                            itemBuilder: (context, index) {
                              final Task task = sortedTasks[index];
                              return Padding(
                                key: ValueKey(task.id),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: TaskTile(
                                    task: task,
                                    onReset: task.completed
                                        ? () => _handleResetTask(task)
                                        : null,
                                    onCheckboxChanged: (_) =>
                                        _handleCheckboxChanged(
                                          task,
                                          widget.tasks,
                                        ),
                                    elapsedDuration: task.isActive
                                        ? _elapsedForTask(task)
                                        : null,
                                    onStart:
                                        (task.isNotStarted || task.isPaused)
                                        ? () => _handleStartTask(task)
                                        : null,
                                    onFinish: task.isActive
                                        ? () => _handleFinishTask(task)
                                        : null,
                                    onFocus: task.completed
                                        ? null
                                        : () => _openFocusModePicker(task),
                                    focusModeLabel: _focusModeLabel(task),
                                    onDelete: () => _handleDeleteTask(task),
                                    onAutoCompleteToken:
                                        (!task.completed && !task.isActive)
                                        ? () => _handleAutoCompleteToken(
                                            task,
                                            widget.tasks,
                                            autoCompleteTaskTokens,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
