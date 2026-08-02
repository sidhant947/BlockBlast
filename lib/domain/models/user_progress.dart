class UserProgress {
  const UserProgress({
    required this.currentLevel,
    required this.highestScore,
    required this.unlockedLevels,
    required this.bestScore,
    required this.bestTimeSeconds,
  });

  final int currentLevel;
  final int highestScore;
  final int unlockedLevels;
  final Map<int, int> bestScore;
  final Map<int, int> bestTimeSeconds;

  UserProgress copyWith({
    int? currentLevel,
    int? highestScore,
    int? unlockedLevels,
    Map<int, int>? bestScore,
    Map<int, int>? bestTimeSeconds,
  }) {
    return UserProgress(
      currentLevel: currentLevel ?? this.currentLevel,
      highestScore: highestScore ?? this.highestScore,
      unlockedLevels: unlockedLevels ?? this.unlockedLevels,
      bestScore: bestScore ?? this.bestScore,
      bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
    );
  }

}
