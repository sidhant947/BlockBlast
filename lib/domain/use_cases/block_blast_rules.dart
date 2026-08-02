import 'package:blockblast/domain/models/game_level.dart';

class BlockBlastRules {
  static bool canPlacePiece(
    List<List<int>> board,
    BlockShape piece,
    int startRow,
    int startCol,
  ) {
    final N = board.length;
    if (startRow < 0 || startCol < 0) return false;
    if (startRow + piece.rows > N || startCol + piece.cols > N) return false;

    for (int r = 0; r < piece.rows; r++) {
      for (int c = 0; c < piece.cols; c++) {
        if (piece.matrix[r][c] == 1) {
          if (board[startRow + r][startCol + c] != 0) {
            return false;
          }
        }
      }
    }
    return true;
  }

  static bool canAnyPieceBePlaced(
    List<List<int>> board,
    List<BlockShape?> pieces,
  ) {
    final N = board.length;
    for (final piece in pieces) {
      if (piece == null) continue;
      for (int r = 0; r <= N - piece.rows; r++) {
        for (int c = 0; c <= N - piece.cols; c++) {
          if (canPlacePiece(board, piece, r, c)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static List<int> getCompletedRows(List<List<int>> board) {
    final N = board.length;
    final rows = <int>[];
    for (int r = 0; r < N; r++) {
      bool full = true;
      for (int c = 0; c < N; c++) {
        if (board[r][c] == 0) {
          full = false;
          break;
        }
      }
      if (full) rows.add(r);
    }
    return rows;
  }

  static List<int> getCompletedCols(List<List<int>> board) {
    final N = board.length;
    final cols = <int>[];
    for (int c = 0; c < N; c++) {
      bool full = true;
      for (int r = 0; r < N; r++) {
        if (board[r][c] == 0) {
          full = false;
          break;
        }
      }
      if (full) cols.add(c);
    }
    return cols;
  }
}
