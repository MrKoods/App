class XpProgressSnapshot {
  final int totalXp;
  final int level;
  final String rankTitle;
  final int currentXpWithinLevel;
  final int xpRequiredForNextLevel;
  final double progressPercent;

  const XpProgressSnapshot({
    required this.totalXp,
    required this.level,
    required this.rankTitle,
    required this.currentXpWithinLevel,
    required this.xpRequiredForNextLevel,
    required this.progressPercent,
  });
}

class XpProgressionService {
  static const List<int> _thresholds = <int>[
    0,
    100,
    250,
    450,
    700,
    1000,
    1400,
    1900,
    2500,
    3200,
  ];

  static const List<String> _rankTitles = <String>[
    'Beginner',
    'Getting Started',
    'Consistent',
    'Focused',
    'Locked In',
    'Disciplined',
    'Momentum',
    'Elite',
    'Unstoppable',
    'Legend',
  ];

  static int levelFromXp(int xp) {
    final int safeXp = xp < 0 ? 0 : xp;

    for (int i = _thresholds.length - 1; i >= 0; i--) {
      if (safeXp >= _thresholds[i]) {
        return i + 1;
      }
    }

    return 1;
  }

  static String rankTitleFromLevel(int level) {
    final int safeLevel = level.clamp(1, _rankTitles.length);
    return _rankTitles[safeLevel - 1];
  }

  static XpProgressSnapshot fromXp(int xp) {
    final int safeXp = xp < 0 ? 0 : xp;
    final int level = levelFromXp(safeXp);
    final String rankTitle = rankTitleFromLevel(level);

    final int levelIndex = level - 1;
    final bool isMaxLevel = level >= _thresholds.length;
    final int currentLevelFloor = _thresholds[levelIndex];

    if (isMaxLevel) {
      return XpProgressSnapshot(
        totalXp: safeXp,
        level: level,
        rankTitle: rankTitle,
        currentXpWithinLevel: safeXp - currentLevelFloor,
        xpRequiredForNextLevel: 0,
        progressPercent: 1,
      );
    }

    final int nextThreshold = _thresholds[levelIndex + 1];
    final int xpRequiredForNextLevel = nextThreshold - currentLevelFloor;
    final int currentXpWithinLevel = safeXp - currentLevelFloor;
    final double progressPercent = xpRequiredForNextLevel <= 0
        ? 1
        : (currentXpWithinLevel / xpRequiredForNextLevel).clamp(0, 1);

    return XpProgressSnapshot(
      totalXp: safeXp,
      level: level,
      rankTitle: rankTitle,
      currentXpWithinLevel: currentXpWithinLevel,
      xpRequiredForNextLevel: xpRequiredForNextLevel,
      progressPercent: progressPercent,
    );
  }
}
