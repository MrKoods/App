import 'completion_reward_summary.dart';

class TaskCompletionResult {
  final int durationSeconds;
  final CompletionRewardSummary? rewardSummary;

  const TaskCompletionResult({
    required this.durationSeconds,
    this.rewardSummary,
  });
}