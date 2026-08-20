import 'dart:math';

enum Player { none, x, o }
enum GameMode { pvp, pve }
enum Difficulty { easy, medium, hard }

class Cell {
  Player owner;
  bool isWinning;

  Cell({this.owner = Player.none, this.isWinning = false});
}

class TicTacToeGame {
  final int size = 3;
  late List<List<Cell>> board;
  Player currentTurn;
  GameMode mode;
  Difficulty difficulty;
  Player aiPlayer;
  Player humanPlayer;
  int xScore;
  int oScore;
  int draws;
  bool _gameOver;
  List<List<int>>? winningLine;

  TicTacToeGame({
    this.mode = GameMode.pve,
    this.difficulty = Difficulty.hard,
    this.aiPlayer = Player.o,
    this.humanPlayer = Player.x,
  })  : currentTurn = Player.x,
        xScore = 0,
        oScore = 0,
        draws = 0,
        _gameOver = false {
    board = List.generate(size, (_) => List.generate(size, (_) => Cell()));
  }

  bool get isGameOver => _gameOver;
  bool get isBoardFull => _countMarks() == size * size;
  bool get isAITurn =>
      mode == GameMode.pve && currentTurn == aiPlayer && !isGameOver;

  void resetBoard() {
    board = List.generate(size, (_) => List.generate(size, (_) => Cell()));
    currentTurn = Player.x;
    _gameOver = false;
    winningLine = null;
  }

  void resetScores() {
    xScore = 0;
    oScore = 0;
    draws = 0;
    resetBoard();
  }

  bool makeMove(int row, int col) {
    if (_gameOver || board[row][col].owner != Player.none) return false;

    board[row][col].owner = currentTurn;

    final winner = _checkWinner();
    if (winner != Player.none) {
      _gameOver = true;
      _markWinningCells();
      if (winner == Player.x) {
        xScore++;
      } else {
        oScore++;
      }
      return true;
    }

    if (isBoardFull) {
      _gameOver = true;
      draws++;
      return true;
    }

    currentTurn = currentTurn == Player.x ? Player.o : Player.x;
    return true;
  }

  void aiMove() {
    if (!isAITurn) return;

    int? row;
    int? col;

    switch (difficulty) {
      case Difficulty.easy:
        final empty = _getEmptyCells();
        if (empty.isNotEmpty) {
          final pick = empty[Random().nextInt(empty.length)];
          row = pick[0];
          col = pick[1];
        }
        break;
      case Difficulty.medium:
        if (Random().nextBool()) {
          final empty = _getEmptyCells();
          if (empty.isNotEmpty) {
            final pick = empty[Random().nextInt(empty.length)];
            row = pick[0];
            col = pick[1];
          }
        } else {
          final best = _findBestMove();
          row = best[0];
          col = best[1];
        }
        break;
      case Difficulty.hard:
        final best = _findBestMove();
        row = best[0];
        col = best[1];
        break;
    }

    if (row != null && col != null) {
      makeMove(row, col);
    }
  }

  Player _checkWinner() {
    for (int i = 0; i < size; i++) {
      if (board[i][0].owner != Player.none &&
          board[i][0].owner == board[i][1].owner &&
          board[i][1].owner == board[i][2].owner) {
        winningLine = [
          [i, 0],
          [i, 1],
          [i, 2]
        ];
        return board[i][0].owner;
      }
      if (board[0][i].owner != Player.none &&
          board[0][i].owner == board[1][i].owner &&
          board[1][i].owner == board[2][i].owner) {
        winningLine = [
          [0, i],
          [1, i],
          [2, i]
        ];
        return board[0][i].owner;
      }
    }

    if (board[0][0].owner != Player.none &&
        board[0][0].owner == board[1][1].owner &&
        board[1][1].owner == board[2][2].owner) {
      winningLine = [
        [0, 0],
        [1, 1],
        [2, 2]
      ];
      return board[0][0].owner;
    }
    if (board[0][2].owner != Player.none &&
        board[0][2].owner == board[1][1].owner &&
        board[1][1].owner == board[2][0].owner) {
      winningLine = [
        [0, 2],
        [1, 1],
        [2, 0]
      ];
      return board[0][2].owner;
    }

    return Player.none;
  }

  Player getWinner() => _checkWinner();

  void _markWinningCells() {
    if (winningLine == null) return;
    for (final pos in winningLine!) {
      board[pos[0]][pos[1]].isWinning = true;
    }
  }

  int _countMarks() {
    int count = 0;
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        if (board[i][j].owner != Player.none) count++;
      }
    }
    return count;
  }

  List<List<int>> _getEmptyCells() {
    final list = <List<int>>[];
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        if (board[i][j].owner == Player.none) list.add([i, j]);
      }
    }
    return list;
  }

  List<int> _findBestMove() {
    int bestScore = -999999;
    List<int> bestMove = [0, 0];

    for (final cell in _getEmptyCells()) {
      final r = cell[0];
      final c = cell[1];
      board[r][c].owner = aiPlayer;
      final score = _minimax(0, false, -999999, 999999);
      board[r][c].owner = Player.none;
      if (score > bestScore) {
        bestScore = score;
        bestMove = [r, c];
      }
    }
    return bestMove;
  }

  int _minimax(int depth, bool isMaximizing, int alpha, int beta) {
    final winner = _checkWinner();
    if (winner == aiPlayer) return 10 - depth;
    if (winner == humanPlayer) return depth - 10;
    if (isBoardFull) return 0;

    if (isMaximizing) {
      int best = -999999;
      for (final cell in _getEmptyCells()) {
        final r = cell[0];
        final c = cell[1];
        board[r][c].owner = aiPlayer;
        best = max(best, _minimax(depth + 1, false, alpha, beta));
        board[r][c].owner = Player.none;
        alpha = max(alpha, best);
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = 999999;
      for (final cell in _getEmptyCells()) {
        final r = cell[0];
        final c = cell[1];
        board[r][c].owner = humanPlayer;
        best = min(best, _minimax(depth + 1, true, alpha, beta));
        board[r][c].owner = Player.none;
        beta = min(beta, best);
        if (beta <= alpha) break;
      }
      return best;
    }
  }
}
