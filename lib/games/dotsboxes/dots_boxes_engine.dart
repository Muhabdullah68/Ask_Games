import 'dart:math';

enum DotsPlayer { none, player1, player2 }

enum DotsGameMode { pvp, pve }

enum DotsDifficulty { easy, medium, hard }

class Line {
  bool drawn;
  DotsPlayer owner;

  Line({this.drawn = false, this.owner = DotsPlayer.none});
}

class Box {
  DotsPlayer owner;

  Box({this.owner = DotsPlayer.none});

  bool get isComplete => owner != DotsPlayer.none;
}

class DotsBoxesGame {
  final int gridSize;
  late List<List<Line>> horizontalLines;
  late List<List<Line>> verticalLines;
  late List<List<Box>> boxes;
  DotsPlayer currentTurn;
  DotsGameMode mode;
  DotsDifficulty difficulty;
  DotsPlayer aiPlayer;
  DotsPlayer humanPlayer;
  int player1Score;
  int player2Score;
  bool _gameOver;

  DotsBoxesGame({
    this.gridSize = 4,
    this.mode = DotsGameMode.pve,
    this.difficulty = DotsDifficulty.medium,
    this.aiPlayer = DotsPlayer.player2,
    this.humanPlayer = DotsPlayer.player1,
  })  : currentTurn = DotsPlayer.player1,
        player1Score = 0,
        player2Score = 0,
        _gameOver = false {
    _initBoard();
  }

  void _initBoard() {
    horizontalLines = List.generate(
      gridSize + 1,
      (_) => List.generate(gridSize, (_) => Line()),
    );
    verticalLines = List.generate(
      gridSize,
      (_) => List.generate(gridSize + 1, (_) => Line()),
    );
    boxes = List.generate(
      gridSize,
      (_) => List.generate(gridSize, (_) => Box()),
    );
  }

  bool get isGameOver => _gameOver;
  bool get isAITurn =>
      mode == DotsGameMode.pve && currentTurn == aiPlayer && !isGameOver;

  int get totalBoxes => gridSize * gridSize;
  int get completedBoxes => player1Score + player2Score;
  int get remainingBoxes => totalBoxes - completedBoxes;

  void resetBoard() {
    _initBoard();
    currentTurn = DotsPlayer.player1;
    player1Score = 0;
    player2Score = 0;
    _gameOver = false;
  }

  void resetScores() {
    resetBoard();
  }

  bool drawHorizontalLine(int row, int col) {
    if (_gameOver || horizontalLines[row][col].drawn) return false;

    horizontalLines[row][col].drawn = true;
    horizontalLines[row][col].owner = currentTurn;

    bool completedBox = false;
    if (row > 0) {
      if (_checkBox(row - 1, col)) {
        boxes[row - 1][col].owner = currentTurn;
        completedBox = true;
        _addScore(currentTurn);
      }
    }
    if (row < gridSize) {
      if (_checkBox(row, col)) {
        boxes[row][col].owner = currentTurn;
        completedBox = true;
        _addScore(currentTurn);
      }
    }

    _checkGameOver();
    if (!completedBox && !_gameOver) {
      _switchTurn();
    }
    return true;
  }

  bool drawVerticalLine(int row, int col) {
    if (_gameOver || verticalLines[row][col].drawn) return false;

    verticalLines[row][col].drawn = true;
    verticalLines[row][col].owner = currentTurn;

    bool completedBox = false;
    if (col > 0) {
      if (_checkBox(row, col - 1)) {
        boxes[row][col - 1].owner = currentTurn;
        completedBox = true;
        _addScore(currentTurn);
      }
    }
    if (col < gridSize) {
      if (_checkBox(row, col)) {
        boxes[row][col].owner = currentTurn;
        completedBox = true;
        _addScore(currentTurn);
      }
    }

    _checkGameOver();
    if (!completedBox && !_gameOver) {
      _switchTurn();
    }
    return true;
  }

  bool _checkBox(int row, int col) {
    if (boxes[row][col].isComplete) return false;
    final top = horizontalLines[row][col].drawn;
    final bottom = horizontalLines[row + 1][col].drawn;
    final left = verticalLines[row][col].drawn;
    final right = verticalLines[row][col + 1].drawn;
    return top && bottom && left && right;
  }

  void _addScore(DotsPlayer player) {
    if (player == DotsPlayer.player1) {
      player1Score++;
    } else {
      player2Score++;
    }
  }

  void _switchTurn() {
    currentTurn = currentTurn == DotsPlayer.player1
        ? DotsPlayer.player2
        : DotsPlayer.player1;
  }

  void _checkGameOver() {
    if (player1Score + player2Score == totalBoxes) {
      _gameOver = true;
    }
  }

  DotsPlayer getWinner() {
    if (!_gameOver) return DotsPlayer.none;
    if (player1Score > player2Score) return DotsPlayer.player1;
    if (player2Score > player1Score) return DotsPlayer.player2;
    return DotsPlayer.none;
  }

  void aiMove() {
    if (!isAITurn) return;

    List<int>? move;

    switch (difficulty) {
      case DotsDifficulty.easy:
        move = _findRandomMove();
        break;
      case DotsDifficulty.medium:
        if (Random().nextBool()) {
          move = _findCaptureMove();
        }
        if (move == null) move = _findSafeMove();
        if (move == null) move = _findRandomMove();
        break;
      case DotsDifficulty.hard:
        move = _findBestMove();
        if (move == null) move = _findRandomMove();
        break;
    }

    if (move != null) {
      if (move[0] == 0) {
        drawHorizontalLine(move[1], move[2]);
      } else {
        drawVerticalLine(move[1], move[2]);
      }
    }
  }

  List<int>? _findRandomMove() {
    final moves = <List<int>>[];
    for (int r = 0; r <= gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!horizontalLines[r][c].drawn) {
          moves.add([0, r, c]);
        }
      }
    }
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c <= gridSize; c++) {
        if (!verticalLines[r][c].drawn) {
          moves.add([1, r, c]);
        }
      }
    }
    if (moves.isEmpty) return null;
    return moves[Random().nextInt(moves.length)];
  }

  List<int>? _findCaptureMove() {
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (boxes[r][c].isComplete) continue;
        int sides = 0;
        List<int>? missingMove;
        if (!horizontalLines[r][c].drawn) {
          sides++;
          missingMove = [0, r, c];
        }
        if (!horizontalLines[r + 1][c].drawn) {
          sides++;
          missingMove = [0, r + 1, c];
        }
        if (!verticalLines[r][c].drawn) {
          sides++;
          missingMove = [1, r, c];
        }
        if (!verticalLines[r][c + 1].drawn) {
          sides++;
          missingMove = [1, r, c + 1];
        }
        if (sides == 1 && missingMove != null) {
          return missingMove;
        }
      }
    }
    return null;
  }

  List<int>? _findSafeMove() {
    final safeMoves = <List<int>>[];
    for (int r = 0; r <= gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!horizontalLines[r][c].drawn &&
            _isSafeMove(0, r, c)) {
          safeMoves.add([0, r, c]);
        }
      }
    }
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c <= gridSize; c++) {
        if (!verticalLines[r][c].drawn &&
            _isSafeMove(1, r, c)) {
          safeMoves.add([1, r, c]);
        }
      }
    }
    if (safeMoves.isEmpty) return null;
    return safeMoves[Random().nextInt(safeMoves.length)];
  }

  bool _isSafeMove(int type, int row, int col) {
    final savedH = horizontalLines.map((e) => e.map((l) => Line(drawn: l.drawn)).toList()).toList();
    final savedV = verticalLines.map((e) => e.map((l) => Line(drawn: l.drawn)).toList()).toList();

    if (type == 0) {
      horizontalLines[row][col].drawn = true;
    } else {
      verticalLines[row][col].drawn = true;
    }

    bool safe = true;
    for (int r = 0; r < gridSize && safe; r++) {
      for (int c = 0; c < gridSize && safe; c++) {
        int sides = 0;
        if (horizontalLines[r][c].drawn) sides++;
        if (horizontalLines[r + 1][c].drawn) sides++;
        if (verticalLines[r][c].drawn) sides++;
        if (verticalLines[r][c + 1].drawn) sides++;
        if (sides == 3) safe = false;
      }
    }

    horizontalLines = savedH;
    verticalLines = savedV;
    return safe;
  }

  List<int>? _findBestMove() {
    final capture = _findCaptureMove();
    if (capture != null) return capture;
    final safe = _findSafeMove();
    if (safe != null) return safe;

    int bestCount = 999;
    List<int>? bestMove;
    for (int r = 0; r <= gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!horizontalLines[r][c].drawn) {
          final count = _countGivenUpBoxes(0, r, c);
          if (count < bestCount) {
            bestCount = count;
            bestMove = [0, r, c];
          }
        }
      }
    }
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c <= gridSize; c++) {
        if (!verticalLines[r][c].drawn) {
          final count = _countGivenUpBoxes(1, r, c);
          if (count < bestCount) {
            bestCount = count;
            bestMove = [1, r, c];
          }
        }
      }
    }
    return bestMove;
  }

  int _countGivenUpBoxes(int type, int row, int col) {
    final savedH = horizontalLines.map((e) => e.map((l) => Line(drawn: l.drawn)).toList()).toList();
    final savedV = verticalLines.map((e) => e.map((l) => Line(drawn: l.drawn)).toList()).toList();
    final savedBoxes = boxes.map((e) => e.map((b) => Box(owner: b.owner)).toList()).toList();

    if (type == 0) {
      horizontalLines[row][col].drawn = true;
    } else {
      verticalLines[row][col].drawn = true;
    }

    int count = 0;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        int sides = 0;
        if (horizontalLines[r][c].drawn) sides++;
        if (horizontalLines[r + 1][c].drawn) sides++;
        if (verticalLines[r][c].drawn) sides++;
        if (verticalLines[r][c + 1].drawn) sides++;
        if (sides >= 3) count++;
      }
    }

    horizontalLines = savedH;
    verticalLines = savedV;
    boxes = savedBoxes;
    return count;
  }
}
