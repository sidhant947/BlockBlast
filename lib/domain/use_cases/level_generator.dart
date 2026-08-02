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
    final gridSize = 8;
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
    int targetScore = 500;
    int targetClears = 3;

    if (levelNumber == 1) {
      targetScore = 400;
      targetClears = 3;
    } else if (levelNumber == 2) {
      targetScore = 600;
      targetClears = 4;
      initialGrid[0][0] = 1 + random.nextInt(8);
      initialGrid[0][gridSize - 1] = 1 + random.nextInt(8);
      initialGrid[gridSize - 1][0] = 1 + random.nextInt(8);
      initialGrid[gridSize - 1][gridSize - 1] = 1 + random.nextInt(8);
    } else if (levelNumber == 3) {
      targetScore = 850;
      targetClears = 5;
      for (int i = 2; i < 6; i++) {
        initialGrid[i][i] = 1 + random.nextInt(8);
      }
    } else if (levelNumber == 4) {
      targetScore = 1100;
      targetClears = 6;
      initialGrid[3][3] = 1 + random.nextInt(8);
      initialGrid[3][4] = 1 + random.nextInt(8);
      initialGrid[4][3] = 1 + random.nextInt(8);
      initialGrid[4][4] = 1 + random.nextInt(8);
    } else if (levelNumber == 5) {
      targetScore = 1400;
      targetClears = 7;
      for (int i = 2; i <= 5; i++) {
        initialGrid[2][i] = 1 + random.nextInt(8);
        initialGrid[5][i] = 1 + random.nextInt(8);
        initialGrid[i][2] = 1 + random.nextInt(8);
        initialGrid[i][5] = 1 + random.nextInt(8);
      }
    } else if (levelNumber == 6) {
      targetScore = 1750;
      targetClears = 8;
      for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 2; j++) {
          initialGrid[i][j] = 1 + random.nextInt(8);
          initialGrid[gridSize - 1 - i][j] = 1 + random.nextInt(8);
          initialGrid[i][gridSize - 1 - j] = 1 + random.nextInt(8);
          initialGrid[gridSize - 1 - i][gridSize - 1 - j] = 1 + random.nextInt(8);
        }
      }
    } else if (levelNumber == 7) {
      targetScore = 2100;
      targetClears = 9;
      for (int r = 2; r < 6; r++) {
        for (int c = 2; c < 6; c++) {
          if ((r + c) % 2 == 0) {
            initialGrid[r][c] = 1 + random.nextInt(8);
          }
        }
      }
    } else if (levelNumber == 8) {
      targetScore = 2500;
      targetClears = 10;
      for (int i = 1; i < 7; i++) {
        initialGrid[i][1] = 1 + random.nextInt(8);
        initialGrid[i][6] = 1 + random.nextInt(8);
      }
      initialGrid[3][2] = 1 + random.nextInt(8);
      initialGrid[3][3] = 1 + random.nextInt(8);
      initialGrid[3][4] = 1 + random.nextInt(8);
      initialGrid[3][5] = 1 + random.nextInt(8);
    } else if (levelNumber == 9) {
      targetScore = 3000;
      targetClears = 11;
      for (int i = 0; i < gridSize; i++) {
        if (i != 3 && i != 4) {
          initialGrid[0][i] = 1 + random.nextInt(8);
          initialGrid[gridSize - 1][i] = 1 + random.nextInt(8);
        }
      }
    } else if (levelNumber == 10) {
      targetScore = 3500;
      targetClears = 12;
      for (int i = 1; i < 7; i++) {
        initialGrid[1][i] = 1 + random.nextInt(8);
        initialGrid[6][i] = 1 + random.nextInt(8);
        initialGrid[i][1] = 1 + random.nextInt(8);
        initialGrid[i][6] = 1 + random.nextInt(8);
      }
    } else if (levelNumber > 10) {
      targetScore = 3500 + ((levelNumber - 10) * 400);
      targetClears = 12 + ((levelNumber - 10) ~/ 2);
      final reflections = min(6, 2 + (levelNumber ~/ 4));
      int placed = 0;
      while (placed < reflections) {
        final r = random.nextInt(gridSize ~/ 2);
        final c = random.nextInt(gridSize ~/ 2);
        if (initialGrid[r][c] == 0) {
          final colorIdx = 1 + random.nextInt(8);
          initialGrid[r][c] = colorIdx;
          initialGrid[gridSize - 1 - r][c] = colorIdx;
          initialGrid[r][gridSize - 1 - c] = colorIdx;
          initialGrid[gridSize - 1 - r][gridSize - 1 - c] = colorIdx;
          placed++;
        }
      }
    } else {
      targetScore = 500;
      targetClears = 3;
    }

    return GameLevel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      targetScore: targetScore,
      targetClears: targetClears,
      initialGrid: initialGrid,
    );
  }
}
