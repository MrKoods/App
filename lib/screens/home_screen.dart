import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/completion_reward_summary.dart';
import '../models/history_model.dart';
import '../models/task_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/focus_lock_service.dart';
import '../widgets/daily_summary_widget.dart';
import '../widgets/task_tile.dart';
import 'checklist_complete_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Task>? tasks;
  final int? coins;
  final ValueChanged<int>? onNavigateTab;

  const HomeScreen({super.key, this.tasks, this.coins, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final FocusLockService _focusLockService = FocusLockService.instance;
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _isOpeningCompletionScreen = false;
  bool _isDeletingAccount = false;

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _surfaceAltColor = Color(0xFF101522);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncTimer(List<Task> tasks) {
    final bool hasRunningTask = tasks.any(
      (task) => task.isInProgress && task.startTime != null,
    );

    if (hasRunningTask && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }

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

  Future<void> _handleStartTask(Task task) async {
    final bool started = await _firestoreService.startTask(task: task);

    if (!mounted) {
      return;
    }

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
        completed: false,
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${task.taskName} started')));
  }

  Future<void> _handleFinishTask(Task task) async {
    final result = await _firestoreService.finishTask(task: task);

    if (!mounted) {
      return;
    }

    final int durationSeconds = result.durationSeconds;
    final int minutes = (durationSeconds / 60).ceil();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${task.taskName} completed in $minutes min. +1 coin'),
      ),
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No auto-complete tokens available.')),
      );
      return;
    }

    final bool anotherTaskRunning = tasks.any(
      (currentTask) => currentTask.id != task.id && currentTask.isInProgress,
    );

    if (anotherTaskRunning) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish your current task first.')),
      );
      return;
    }

    try {
      final result = await _firestoreService.autoCompleteTaskWithToken(
        task: task,
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${task.taskName} auto-completed using token.')),
      );

      await _openCompletionScreenIfNeeded(result.rewardSummary);
    } catch (_) {
      if (!mounted) {
        return;
      }

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

    // Finishing from Home should take the user back to the main checklist tab.
    widget.onNavigateTab?.call(1);
  }

  Future<void> _handleResetTask(Task task) async {
    await _firestoreService.resetTask(task: task);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${task.taskName} reset')));
  }

  Future<void> _showDeleteAccountConfirmation() async {
    if (_isDeletingAccount) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to permanently delete your account? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) {
        return;
      }
      await deleteAccount(context);
    }
  }

  Future<void> deleteAccount(BuildContext context) async {
    if (_isDeletingAccount) {
      return;
    }

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('No signed-in user found.')),
        );
        return;
      }

      await _authService.deleteAccountForUser(user);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully.')),
      );

      Navigator.of(this.context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      final String message = e.code == 'requires-recent-login'
          ? 'For security, please log out and log back in before deleting your account.'
          : (e.message ?? 'Failed to delete account. Please try again.');

      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete account. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  int _taskPriority(Task task) {
    if (task.isInProgress) {
      return 0;
    }

    if (task.isNotStarted) {
      return 1;
    }

    return 2;
  }

  Duration _elapsedForTask(Task task) {
    if (task.isPaused) {
      return Duration(seconds: task.durationSeconds);
    }

    if (task.startTime == null) {
      return Duration(seconds: task.durationSeconds);
    }

    final Duration duration = _now.difference(task.startTime!);
    final int liveSeconds = duration.isNegative ? 0 : duration.inSeconds;
    return Duration(seconds: task.durationSeconds + liveSeconds);
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

  String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return 'Pending timestamp';
    }

    final DateTime local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: _accentColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 15),
      ),
    );
  }

  Widget _buildStatsCard({
    required int coins,
    required int currentStreak,
    required int longestStreak,
    required int perfectDays,
  }) {
    Widget statItem({
      required String label,
      required String value,
      required IconData icon,
      required Color color,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceAltColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_graph, color: _secondaryAccent, size: 22),
              SizedBox(width: 10),
              Text(
                'User Stats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              statItem(
                label: 'Coins',
                value: '$coins',
                icon: Icons.monetization_on,
                color: Colors.amber,
              ),
              const SizedBox(width: 12),
              statItem(
                label: 'Current streak',
                value: '$currentStreak',
                icon: Icons.local_fire_department,
                color: Colors.orangeAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              statItem(
                label: 'Longest streak',
                value: '$longestStreak',
                icon: Icons.emoji_events,
                color: Colors.lightBlueAccent,
              ),
              const SizedBox(width: 12),
              statItem(
                label: 'Perfect days',
                value: '$perfectDays',
                icon: Icons.star,
                color: Colors.greenAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Text(
            'No user is signed in.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _firestoreService.watchUserData(),
      builder: (context, userSnapshot) {
        final Map<String, dynamic> userData =
            userSnapshot.data ?? <String, dynamic>{};
        final int currentCoins =
            (userData['coins'] as num?)?.toInt() ?? widget.coins ?? 0;
        final int currentStreak =
            (userData['currentStreak'] as num?)?.toInt() ?? 0;
        final int longestStreak =
            (userData['longestStreak'] as num?)?.toInt() ?? 0;
        final int perfectDays = (userData['perfectDays'] as num?)?.toInt() ?? 0;
        final int autoCompleteTaskTokens =
            (userData['autoCompleteTaskTokens'] as num?)?.toInt() ?? 0;

        return StreamBuilder<List<Task>>(
          stream: _firestoreService.watchTasks(),
          initialData: widget.tasks ?? const <Task>[],
          builder: (context, taskSnapshot) {
            final List<Task> userTasks = taskSnapshot.data ?? const <Task>[];
            final List<Task> sortedTasks = [...userTasks]
              ..sort(
                (left, right) =>
                    _taskPriority(left).compareTo(_taskPriority(right)),
              );

            _syncTimer(userTasks);

            return StreamBuilder<List<HistoryEntry>>(
              stream: _firestoreService.watchHistory(),
              builder: (context, historySnapshot) {
                final List<HistoryEntry> historyItems =
                    historySnapshot.data ?? const <HistoryEntry>[];
                final Map<String, int> dailySummary = _firestoreService
                    .buildDailySummary(
                      tasks: userTasks,
                      historyItems: historyItems,
                      userData: userData,
                    );
                final List<HistoryEntry> recentHistory = historyItems
                    .take(6)
                    .toList();
                final int todaysTaskCount = userTasks
                    .where((task) => _isSameDay(task.date, DateTime.now()))
                    .length;

                return Container(
                  color: _backgroundColor,
                  child: NotificationListener<OverscrollIndicatorNotification>(
                    onNotification: (notification) {
                      notification.disallowIndicator();
                      return false;
                    },
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF162033), Color(0xFF0F1420)],
                          ),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Home',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentUser.email ?? 'Signed in user',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'The future belongs to those who prepare for it today.',
                                style: TextStyle(
                                  color: _accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isDeletingAccount
                                    ? null
                                    : _showDeleteAccountConfirmation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isDeletingAccount
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Delete Account'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildStatsCard(
                        coins: currentCoins,
                        currentStreak: currentStreak,
                        longestStreak: longestStreak,
                        perfectDays: perfectDays,
                      ),
                      const SizedBox(height: 20),
                      DailySummaryWidget(
                        tasksCompletedToday:
                            dailySummary['tasksCompletedToday'] ?? 0,
                        totalFocusTimeSeconds:
                            dailySummary['totalFocusTimeSeconds'] ?? 0,
                        coinsEarnedToday: dailySummary['coinsEarnedToday'] ?? 0,
                        currentStreak:
                            dailySummary['currentStreak'] ?? currentStreak,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Tasks'),
                      const SizedBox(height: 10),
                      if (sortedTasks.isEmpty)
                        _buildEmptyCard('No tasks found for this user.')
                      else
                        ...sortedTasks.map(
                          (task) => TaskTile(
                            task: task,
                            onReset: task.completed
                                ? () => _handleResetTask(task)
                                : null,
                            elapsedDuration: task.isActive
                                ? _elapsedForTask(task)
                                : null,
                            onStart: task.isNotStarted
                                ? () => _handleStartTask(task)
                                : null,
                            onFinish: task.isInProgress
                                ? () => _handleFinishTask(task)
                                : null,
                            onAutoCompleteToken:
                                (!task.completed && !task.isInProgress)
                                ? () => _handleAutoCompleteToken(
                                    task,
                                    userTasks,
                                    autoCompleteTaskTokens,
                                  )
                                : null,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Today\'s tasks: $todaysTaskCount',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Recent History'),
                      const SizedBox(height: 10),
                      if (recentHistory.isEmpty)
                        _buildEmptyCard('No history yet.')
                      else
                        ...recentHistory.map(
                          (entry) => Card(
                            color: _surfaceColor,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: _secondaryAccent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.history,
                                color: _secondaryAccent,
                              ),
                              title: Text(
                                entry.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                _formatTimestamp(entry.timestamp),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
