import 'package:flutter/foundation.dart';
import 'package:blockblast/data/services/hive_service.dart';
import 'package:blockblast/domain/models/user_progress.dart';

class ProgressRepository extends ChangeNotifier {
  ProgressRepository({required this.hiveService});

  final HiveService hiveService;

  Future<UserProgress> getProgress() async {
    final box = hiveService.progressBox;
    final currentLevel = box.get('currentLevel', defaultValue: 1) as int;
    final highestScore = box.get('highestScore', defaultValue: 0) as int;
    final unlockedLevels = box.get('unlockedLevels', defaultValue: 1) as int;
    
    final rawBestScore = box.get('bestScore', defaultValue: <dynamic, dynamic>{});
    final Map<int, int> bestScore = (rawBestScore as Map).map(
      (k, v) => MapEntry(k as int, v as int),
    );

    final rawBestTime = box.get('bestTimeSeconds', defaultValue: <dynamic, dynamic>{});
    final Map<int, int> bestTimeSeconds = (rawBestTime as Map).map(
      (k, v) => MapEntry(k as int, v as int),
    );

    return UserProgress(
      currentLevel: currentLevel,
      highestScore: highestScore,
      unlockedLevels: unlockedLevels,
      bestScore: bestScore,
      bestTimeSeconds: bestTimeSeconds,
    );
  }

  Future<void> saveProgress(UserProgress progress) async {
    final box = hiveService.progressBox;
    await box.put('currentLevel', progress.currentLevel);
    await box.put('highestScore', progress.highestScore);
    await box.put('unlockedLevels', progress.unlockedLevels);
    await box.put('bestScore', progress.bestScore);
    await box.put('bestTimeSeconds', progress.bestTimeSeconds);
    notifyListeners();
  }

  Future<void> saveLevelCompletion({
    required int levelNumber,
    required int score,
    required int elapsedSeconds,
  }) async {
    final current = await getProgress();
    final newUnlocked = levelNumber >= current.unlockedLevels 
        ? levelNumber + 1 
        : current.unlockedLevels;

    final newCurrentLevel = levelNumber >= current.currentLevel 
        ? levelNumber + 1 
        : current.currentLevel;

    final newHighestScore = score > current.highestScore ? score : current.highestScore;

    final newBestScore = Map<int, int>.from(current.bestScore);
    if (!newBestScore.containsKey(levelNumber) || score > newBestScore[levelNumber]!) {
      newBestScore[levelNumber] = score;
    }

    final newBestTime = Map<int, int>.from(current.bestTimeSeconds);
    if (!newBestTime.containsKey(levelNumber) || elapsedSeconds < newBestTime[levelNumber]!) {
      newBestTime[levelNumber] = elapsedSeconds;
    }

    final updated = current.copyWith(
      currentLevel: newCurrentLevel,
      highestScore: newHighestScore,
      unlockedLevels: newUnlocked,
      bestScore: newBestScore,
      bestTimeSeconds: newBestTime,
    );

    await saveProgress(updated);
  }
}
