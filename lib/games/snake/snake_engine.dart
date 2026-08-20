import 'dart:math';

enum SnakeDirection { up, down, left, right }

enum SnakeGameState { idle, playing, paused, gameOver }

enum SnakeDifficulty { easy, medium, hard }

class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) {
    if (other is Point) {
      return x == other.x && y == other.y;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

class SnakeGame {
  final int gridSize;
  late List<Point> snake;
  late Point food;
  SnakeDirection direction;
  SnakeDirection _pendingDirection;
  SnakeGameState state;
  SnakeDifficulty difficulty;
  int score;
  int highScore;
  final Random _random = Random();

  SnakeGame({
    this.gridSize = 20,
    this.difficulty = SnakeDifficulty.medium,
    this.highScore = 0,
  })  : direction = SnakeDirection.right,
        _pendingDirection = SnakeDirection.right,
        state = SnakeGameState.idle,
        score = 0 {
    reset();
  }

  int get speedMs {
    switch (difficulty) {
      case SnakeDifficulty.easy:
        return 180;
      case SnakeDifficulty.medium:
        return 120;
      case SnakeDifficulty.hard:
        return 80;
    }
  }

  void reset() {
    final mid = gridSize ~/ 2;
    snake = [
      Point(mid - 1, mid),
      Point(mid, mid),
      Point(mid + 1, mid),
    ];
    direction = SnakeDirection.right;
    _pendingDirection = SnakeDirection.right;
    score = 0;
    state = SnakeGameState.idle;
    _spawnFood();
  }

  void start() {
    if (state == SnakeGameState.gameOver) {
      reset();
    }
    state = SnakeGameState.playing;
  }

  void pause() {
    if (state == SnakeGameState.playing) {
      state = SnakeGameState.paused;
    }
  }

  void resume() {
    if (state == SnakeGameState.paused) {
      state = SnakeGameState.playing;
    }
  }

  void setDirection(SnakeDirection newDir) {
    if (state != SnakeGameState.playing) return;
    final opposite = {
      SnakeDirection.up: SnakeDirection.down,
      SnakeDirection.down: SnakeDirection.up,
      SnakeDirection.left: SnakeDirection.right,
      SnakeDirection.right: SnakeDirection.left,
    };
    if (newDir != opposite[direction]) {
      _pendingDirection = newDir;
    }
  }

  bool step() {
    if (state != SnakeGameState.playing) return false;

    direction = _pendingDirection;
    final head = snake.last;
    int newX = head.x;
    int newY = head.y;

    switch (direction) {
      case SnakeDirection.up:
        newY--;
        break;
      case SnakeDirection.down:
        newY++;
        break;
      case SnakeDirection.left:
        newX--;
        break;
      case SnakeDirection.right:
        newX++;
        break;
    }

    if (newX < 0 || newX >= gridSize || newY < 0 || newY >= gridSize) {
      _gameOver();
      return false;
    }

    final newHead = Point(newX, newY);
    for (int i = 0; i < snake.length; i++) {
      if (snake[i] == newHead) {
        _gameOver();
        return false;
      }
    }

    snake.add(newHead);

    if (newHead == food) {
      score += 10;
      if (score > highScore) {
        highScore = score;
      }
      _spawnFood();
    } else {
      snake.removeAt(0);
    }

    return true;
  }

  void _spawnFood() {
    final available = <Point>[];
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final p = Point(x, y);
        if (!snake.contains(p)) {
          available.add(p);
        }
      }
    }
    if (available.isEmpty) {
      _gameOver();
      return;
    }
    food = available[_random.nextInt(available.length)];
  }

  void _gameOver() {
    state = SnakeGameState.gameOver;
    if (score > highScore) {
      highScore = score;
    }
  }
}
