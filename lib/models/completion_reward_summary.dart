class CompletionRewardSummary {
  final bool rewardGranted;
  final bool wasAlreadyClaimedToday;
  final int coinsEarned;
  final int xpEarned;
  final int oldXp;
  final int newXp;
  final int oldLevel;
  final int newLevel;
  final bool didLevelUp;
  final int streak;
  final int perfectDays;
  final List<String> unlockedBadges;
  final List<String> unlockedTitles;
  final DateTime completionDate;
  final String message;

  const CompletionRewardSummary({
    required this.rewardGranted,
    required this.wasAlreadyClaimedToday,
    required this.coinsEarned,
    required this.xpEarned,
    required this.oldXp,
    required this.newXp,
    required this.oldLevel,
    required this.newLevel,
    required this.didLevelUp,
    required this.streak,
    required this.perfectDays,
    required this.unlockedBadges,
    required this.unlockedTitles,
    required this.completionDate,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rewardGranted': rewardGranted,
      'wasAlreadyClaimedToday': wasAlreadyClaimedToday,
      'coinsEarned': coinsEarned,
      'xpEarned': xpEarned,
      'oldXp': oldXp,
      'newXp': newXp,
      'oldLevel': oldLevel,
      'newLevel': newLevel,
      'didLevelUp': didLevelUp,
      'streak': streak,
      'perfectDays': perfectDays,
      'unlockedBadges': unlockedBadges,
      'unlockedTitles': unlockedTitles,
      'completionDate': completionDate.toIso8601String(),
      'message': message,
    };
  }
}