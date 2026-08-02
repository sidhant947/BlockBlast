import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blockblast/data/repositories/progress_repository.dart';
import 'package:blockblast/domain/models/game_level.dart';
import 'package:blockblast/domain/use_cases/block_blast_rules.dart';
import 'package:blockblast/domain/use_cases/level_generator.dart';

class GameViewModelState {
  final GameLevel? level;
  final List<List<int>> board;
  final List<BlockShape?> availablePieces;
  final List<int> pieceColors;
  final int score;
  final int comboCount;
  final int totalClears;
  final bool isComplete;
  final bool isGameOver;
  final bool isLoading;
  final bool isRandomMode;
  final String? randomDifficulty;
  final String? error;

  final int lastClearedLines;
  final int lastMoveScore;

  final Set<int> clearingRows;
  final Set<int> clearingCols;
  final bool isAnimating;

  GameViewModelState({
    this.level,
    this.board = const [],
    this.availablePieces = const [],
    this.pieceColors = const [],
    this.score = 0,
    this.comboCount = 0,
    this.totalClears = 0,
    this.isComplete = false,
    this.isGameOver = false,
    this.isLoading = false,
    this.isRandomMode = false,
    this.randomDifficulty,
    this.error,
    this.lastClearedLines = 0,
    this.lastMoveScore = 0,
    this.clearingRows = const {},
    this.clearingCols = const {},
    this.isAnimating = false,
  });

  GameViewModelState copyWith({
    GameLevel? level,
    List<List<int>>? board,
    List<BlockShape?>? availablePieces,
    List<int>? pieceColors,
    int? score,
    int? comboCount,
    int? totalClears,
    bool? isComplete,
    bool? isGameOver,
    bool? isLoading,
    bool? isRandomMode,
    String? randomDifficulty,
    String? error,
    int? lastClearedLines,
    int? lastMoveScore,
    Set<int>? clearingRows,
    Set<int>? clearingCols,
    bool? isAnimating,
  }) {
    return GameViewModelState(
      level: level ?? this.level,
      board: board ?? this.board,
      availablePieces: availablePieces ?? this.availablePieces,
      pieceColors: pieceColors ?? this.pieceColors,
      score: score ?? this.score,
      comboCount: comboCount ?? this.comboCount,
      totalClears: totalClears ?? this.totalClears,
      isComplete: isComplete ?? this.isComplete,
      isGameOver: isGameOver ?? this.isGameOver,
      isLoading: isLoading ?? this.isLoading,
      isRandomMode: isRandomMode ?? this.isRandomMode,
      randomDifficulty: randomDifficulty ?? this.randomDifficulty,
      error: error,
      lastClearedLines: lastClearedLines ?? this.lastClearedLines,
      lastMoveScore: lastMoveScore ?? this.lastMoveScore,
      clearingRows: clearingRows ?? this.clearingRows,
      clearingCols: clearingCols ?? this.clearingCols,
      isAnimating: isAnimating ?? this.isAnimating,
    );
  }
}

class GameViewModel extends StateNotifier<GameViewModelState> {
  GameViewModel({
    required this.progressRepository,
    required this.levelGenerator,
  }) : super(GameViewModelState());

  final ProgressRepository progressRepository;
  final LevelGenerator levelGenerator;

  void loadLevel(int levelNumber) {
    state = state.copyWith(isLoading: true);
    try {
      final level = levelGenerator.generate(levelNumber);
      _setupLevel(level, isRandom: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load level: $e');
    }
  }

  void loadRandomLevel(String difficulty) {
    state = state.copyWith(isLoading: true);
    try {
      final seed = DateTime.now().millisecondsSinceEpoch;
      final level = levelGenerator.generateRandom(gridSize: 8, seed: seed);
      _setupLevel(level, isRandom: true, difficulty: difficulty);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to generate level: $e');
    }
  }

  void _setupLevel(GameLevel level, {required bool isRandom, String? difficulty}) {
    final board = List.generate(
      level.gridSize,
      (r) => List<int>.from(level.initialGrid[r]),
    );

    final pieces = _generate3Pieces();
    final colors = _generate3Colors();

    state = GameViewModelState(
      level: level,
      board: board,
      availablePieces: pieces,
      pieceColors: colors,
      score: 0,
      comboCount: 0,
      totalClears: 0,
      isComplete: false,
      isGameOver: false,
      isLoading: false,
      isRandomMode: isRandom,
      randomDifficulty: difficulty,
    );
  }

  List<BlockShape> _generate3Pieces() {
    final random = Random();
    return List.generate(3, (_) {
      return BlockShape.allShapes[random.nextInt(BlockShape.allShapes.length)];
    });
  }

  List<int> _generate3Colors() {
    final random = Random();
    return List.generate(3, (_) => random.nextInt(8));
  }

  bool placePiece(int pieceIndex, int startRow, int startCol) {
    if (state.isComplete || state.isGameOver || state.isAnimating) return false;
    final piece = state.availablePieces[pieceIndex];
    if (piece == null) return false;

    if (!BlockBlastRules.canPlacePiece(state.board, piece, startRow, startCol)) {
      return false;
    }

    final newBoard = List.generate(
      state.board.length,
      (r) => List<int>.from(state.board[r]),
    );

    final colorIdx = state.pieceColors[pieceIndex] + 1;
    int placedBlocks = 0;

    for (int r = 0; r < piece.rows; r++) {
      for (int c = 0; c < piece.cols; c++) {
        if (piece.matrix[r][c] == 1) {
          newBoard[startRow + r][startCol + c] = colorIdx;
          placedBlocks++;
        }
      }
    }

    final completedRows = BlockBlastRules.getCompletedRows(newBoard);
    final completedCols = BlockBlastRules.getCompletedCols(newBoard);

    final clearedLines = completedRows.length + completedCols.length;
    int currentCombo = state.comboCount;

    if (clearedLines > 0) {
      currentCombo += 1;
    } else {
      currentCombo = 0;
    }

    final linePoints = clearedLines * 100 * (1 + clearedLines ~/ 2);
    final comboBonus = currentCombo * 50;
    final moveScore = placedBlocks * 10 + linePoints + comboBonus;
    final newScore = state.score + moveScore;

    final newPieces = List<BlockShape?>.from(state.availablePieces);
    newPieces[pieceIndex] = null;

    final newPieceColors = List<int>.from(state.pieceColors);

    if (newPieces.every((p) => p == null)) {
      final freshPieces = _generate3Pieces();
      final freshColors = _generate3Colors();
      for (int i = 0; i < 3; i++) {
        newPieces[i] = freshPieces[i];
        newPieceColors[i] = freshColors[i];
      }
    }

    final newTotalClears = state.totalClears + clearedLines;

    bool isComplete = false;
    final level = state.level;
    if (level != null && !state.isRandomMode) {
      if (newScore >= level.targetScore || newTotalClears >= level.targetClears) {
        isComplete = true;
      }
    }

    if (clearedLines > 0) {
      state = state.copyWith(
        board: newBoard,
        availablePieces: newPieces,
        pieceColors: newPieceColors,
        score: newScore,
        comboCount: currentCombo,
        totalClears: newTotalClears,
        isComplete: false,
        isGameOver: false,
        lastClearedLines: clearedLines,
        lastMoveScore: moveScore,
        clearingRows: completedRows.toSet(),
        clearingCols: completedCols.toSet(),
        isAnimating: true,
      );

      Timer(const Duration(milliseconds: 380), () {
        final clearedBoard = List.generate(
          newBoard.length,
          (r) => List<int>.from(newBoard[r]),
        );
        for (final r in completedRows) {
          for (int c = 0; c < clearedBoard.length; c++) {
            clearedBoard[r][c] = 0;
          }
        }
        for (final c in completedCols) {
          for (int r = 0; r < clearedBoard.length; r++) {
            clearedBoard[r][c] = 0;
          }
        }

        bool isGameOver = false;
        if (!isComplete && !BlockBlastRules.canAnyPieceBePlaced(clearedBoard, newPieces)) {
          isGameOver = true;
        }

        state = state.copyWith(
          board: clearedBoard,
          isComplete: isComplete,
          isGameOver: isGameOver,
          clearingRows: const {},
          clearingCols: const {},
          isAnimating: false,
        );
      });
    } else {
      bool isGameOver = false;
      if (!isComplete && !BlockBlastRules.canAnyPieceBePlaced(newBoard, newPieces)) {
        isGameOver = true;
      }

      state = state.copyWith(
        board: newBoard,
        availablePieces: newPieces,
        pieceColors: newPieceColors,
        score: newScore,
        comboCount: currentCombo,
        totalClears: newTotalClears,
        isComplete: isComplete,
        isGameOver: isGameOver,
        lastClearedLines: clearedLines,
        lastMoveScore: moveScore,
      );
    }

    return true;
  }

  void resetLevel() {
    if (state.level != null) {
      _setupLevel(state.level!, isRandom: state.isRandomMode, difficulty: state.randomDifficulty);
    }
  }

  Future<void> completeLevel() async {
    if (state.level != null && !state.isRandomMode) {
      await progressRepository.saveLevelCompletion(
        levelNumber: state.level!.levelNumber,
        score: state.score,
        elapsedSeconds: 0,
      );
    }
  }
}
