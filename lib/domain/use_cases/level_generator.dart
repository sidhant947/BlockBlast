import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:blockblast/domain/models/game_level.dart';

class LevelGenerator {
  final Map<int, GameLevel> _cache = {};
  final Set<int> _generating = {};

  GameLevel generate(int levelNumber) {
    GameLevel level;
    if (_cache.containsKey(levelNumber)) {
      level = _cache.remove(levelNumber)!;
    } else {
      level = _generateInternal(levelNumber);
    }
    _generating.remove(levelNumber);
    
    _pregenerateNext(levelNumber + 1);
    return level;
  }

  GameLevel _generateInternal(int levelNumber) {
    final random = Random(levelNumber * 7919);
    int gridSize = 8;
    if (levelNumber == 1 || levelNumber == 2) {
      gridSize = 6;
    } else if (levelNumber > 10) {
      gridSize = (levelNumber % 3 == 0) ? 10 : ((levelNumber % 3 == 1) ? 6 : 8);
    }
    return _generateLevelWithSeed(levelNumber, gridSize, random);
  }

  void _pregenerateNext(int startLevel) {
    for (int i = 0; i < 3; i++) {
      final levelNumber = startLevel + i;
      if (!_cache.containsKey(levelNumber) && !_generating.contains(levelNumber)) {
        _generating.add(levelNumber);
        compute(_isolateGenerate, levelNumber).then((level) {
          _cache[levelNumber] = level;
          _generating.remove(levelNumber);
        }).catchError((e) {
          _generating.remove(levelNumber);
        });
      }
    }
  }

  static GameLevel _isolateGenerate(int levelNumber) {
    return LevelGenerator()._generateInternal(levelNumber);
  }

  GameLevel generateRandom({required int gridSize, required int seed}) {
    final random = Random(seed);
    return _generateLevelWithSeed(-1, gridSize, random);
  }

  GameLevel _generateLevelWithSeed(int levelNumber, int gridSize, Random random) {
    final initialGrid = List.generate(gridSize, (_) => List<int>.filled(gridSize, 0));
    int targetScore = 1200;
    int targetClears = 5;

    if (levelNumber == 1) {
      targetScore = 600;
      targetClears = 4;
      initialGrid[1][1] = 9;
      initialGrid[1][4] = 9;
      initialGrid[4][1] = 10;
      initialGrid[4][4] = 10;
    } else if (levelNumber == 2) {
      targetScore = 900;
      targetClears = 5;
      initialGrid[0][0] = 9;
      initialGrid[0][gridSize - 1] = 9;
      initialGrid[gridSize - 1][0] = 9;
      initialGrid[gridSize - 1][gridSize - 1] = 9;
      initialGrid[2][2] = 10;
      initialGrid[3][3] = 10;
    } else if (levelNumber == 3) {
      targetScore = 1300;
      targetClears = 6;
      for (int i = 1; i < gridSize - 1; i++) {
        initialGrid[i][i] = (i % 2 == 0) ? 9 : 10;
      }
    } else if (levelNumber == 4) {
      targetScore = 1700;
      targetClears = 7;
      final mid = gridSize ~/ 2;
      initialGrid[mid - 1][mid - 1] = 9;
      initialGrid[mid - 1][mid] = 10;
      initialGrid[mid][mid - 1] = 10;
      initialGrid[mid][mid] = 9;
    } else if (levelNumber == 5) {
      targetScore = 2200;
      targetClears = 8;
      for (int i = 1; i < gridSize - 1; i++) {
        initialGrid[1][i] = (i % 2 == 0) ? 9 : 10;
        initialGrid[gridSize - 2][i] = (i % 2 == 0) ? 10 : 9;
      }
    } else if (levelNumber > 5 && levelNumber <= 10) {
      targetScore = 2200 + ((levelNumber - 5) * 450);
      targetClears = 8 + (levelNumber - 5);
      final reflections = min(4, 2 + (levelNumber ~/ 3));
      int placed = 0;
      while (placed < reflections) {
        final r = random.nextInt(gridSize ~/ 2);
        final c = random.nextInt(gridSize ~/ 2);
        if (initialGrid[r][c] == 0) {
          final blockVal = (placed % 2 == 0) ? 9 : 10;
          initialGrid[r][c] = blockVal;
          initialGrid[gridSize - 1 - r][c] = blockVal;
          initialGrid[r][gridSize - 1 - c] = blockVal;
          initialGrid[gridSize - 1 - r][gridSize - 1 - c] = blockVal;
          placed++;
        }
      }
    } else if (levelNumber > 10) {
      targetScore = 3800 + ((levelNumber - 10) * 500);
      targetClears = 12 + ((levelNumber - 10) ~/ 2);
      final reflections = min(6, 2 + (levelNumber ~/ 4));
      int placed = 0;
      while (placed < reflections) {
        final r = random.nextInt(gridSize ~/ 2);
        final c = random.nextInt(gridSize ~/ 2);
        if (initialGrid[r][c] == 0) {
          final blockVal = (placed % 2 == 0) ? 9 : 10;
          initialGrid[r][c] = blockVal;
          initialGrid[gridSize - 1 - r][c] = blockVal;
          initialGrid[r][gridSize - 1 - c] = blockVal;
          initialGrid[gridSize - 1 - r][gridSize - 1 - c] = blockVal;
          placed++;
        }
      }
    }

    int frozenCount = 0;
    int gemCount = 0;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (initialGrid[r][c] == 9) frozenCount++;
        if (initialGrid[r][c] == 10) gemCount++;
      }
    }

    return GameLevel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      targetScore: targetScore,
      targetClears: targetClears,
      targetFrozen: frozenCount,
      targetGems: gemCount,
      initialGrid: initialGrid,
    );
  }
}
