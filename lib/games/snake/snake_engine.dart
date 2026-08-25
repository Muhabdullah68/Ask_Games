import 'dart:math';

enum SnakeDirection { up, down, left, right }

enum SnakeGameState { idle, playing, paused, gameOver }

enum SnakeDifficulty { easy, medium, hard }

enum FoodType { normal, golden, bomb }

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

class Food {
  final Point pos;
  final FoodType type;
  int ticksLeft;

  Food({required this.pos, required this.type, this.ticksLeft = 0});
}

class SnakeGame {
  final int gridSize;
  late List<Point> snake;
  late List<Food> foods;
  late List<Point> obstacles;
  SnakeDirection direction;
  final List<SnakeDirection> _inputQueue = [];
  SnakeGameState state;
  SnakeDifficulty difficulty;
  int score;
  int applesEaten;
  int highScore;
  final Random _random = Random();

  static const int _maxQueueLength = 2;
  static const int _minSpeedMs = 70;
  static const int _startSegments = 3;
  static const int _msPerSegment = 2;

  SnakeGame({
    this.gridSize = 20,
    this.difficulty = SnakeDifficulty.medium,
    this.highScore = 0,
  }) : direction = SnakeDirection.right,
       state = SnakeGameState.idle,
       score = 0,
       applesEaten = 0 {
    reset();
  }

  int get _baseSpeedMs {
    switch (difficulty) {
      case SnakeDifficulty.easy:
        return 200;
      case SnakeDifficulty.medium:
        return 150;
      case SnakeDifficulty.hard:
        return 110;
    }
  }

  /// Starts slow and creeps up 2ms per body segment beyond the initial 3.
  int get speedMs => max(
    _minSpeedMs,
    _baseSpeedMs - (snake.length - _startSegments) * _msPerSegment,
  );

  double get goldenChance {
    switch (difficulty) {
      case SnakeDifficulty.easy:
        return 0.30;
      case SnakeDifficulty.medium:
        return 0.20;
      case SnakeDifficulty.hard:
        return 0.15;
    }
  }

  double get bombChance {
    switch (difficulty) {
      case SnakeDifficulty.easy:
        return 0;
      case SnakeDifficulty.medium:
        return 0.15;
      case SnakeDifficulty.hard:
        return 0.20;
    }
  }

  int get bombScoreGate {
    switch (difficulty) {
      case SnakeDifficulty.easy:
        return 1 << 30;
      case SnakeDifficulty.medium:
        return 50;
      case SnakeDifficulty.hard:
        return 30;
    }
  }

  int get goldenLifetimeTicks => (7000 / speedMs).round().clamp(10, 200);

  int get bombLifetimeTicks => (12000 / speedMs).round().clamp(12, 300);

  bool get hasGolden => foods.any((f) => f.type == FoodType.golden);
  bool get hasBomb => foods.any((f) => f.type == FoodType.bomb);
  Food get normalFood => foods.firstWhere((f) => f.type == FoodType.normal);

  void reset() {
    final mid = gridSize ~/ 2;
    snake = [Point(mid - 1, mid), Point(mid, mid), Point(mid + 1, mid)];
    direction = SnakeDirection.right;
    _inputQueue.clear();
    score = 0;
    applesEaten = 0;
    obstacles = [];
    state = SnakeGameState.idle;
    foods = [];
    _spawnNormalFood();
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
    final reference = _inputQueue.isNotEmpty ? _inputQueue.last : direction;
    if (newDir == reference || newDir == _opposite(reference)) return;
    if (_inputQueue.length >= _maxQueueLength) return;
    _inputQueue.add(newDir);
  }

  SnakeDirection _opposite(SnakeDirection d) {
    switch (d) {
      case SnakeDirection.up:
        return SnakeDirection.down;
      case SnakeDirection.down:
        return SnakeDirection.up;
      case SnakeDirection.left:
        return SnakeDirection.right;
      case SnakeDirection.right:
        return SnakeDirection.left;
    }
  }

  Food? _foodAt(Point p) {
    for (final f in foods) {
      if (f.pos == p) return f;
    }
    return null;
  }

  bool _isObstacle(Point p) => obstacles.contains(p);

  bool _isFree(Point p) {
    if (snake.contains(p)) return false;
    if (_isObstacle(p)) return false;
    if (_foodAt(p) != null) return false;
    return true;
  }

  int _manhattan(Point a, Point b) => (a.x - b.x).abs() + (a.y - b.y).abs();

  bool step() {
    if (state != SnakeGameState.playing) return false;

    while (_inputQueue.isNotEmpty) {
      final next = _inputQueue.removeAt(0);
      if (next != direction && next != _opposite(direction)) {
        direction = next;
        break;
      }
    }

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

    if (_isObstacle(newHead)) {
      _gameOver();
      return false;
    }

    final hitFood = _foodAt(newHead);
    if (hitFood?.type == FoodType.bomb) {
      _gameOver();
      return false;
    }

    final willGrow =
        hitFood != null &&
        (hitFood.type == FoodType.normal || hitFood.type == FoodType.golden);

    for (int i = 0; i < snake.length; i++) {
      if (!willGrow && i == 0 && snake[i] == newHead) continue;
      if (snake[i] == newHead) {
        _gameOver();
        return false;
      }
    }

    snake.add(newHead);

    if (willGrow) {
      if (hitFood.type == FoodType.normal) {
        score += 10;
        applesEaten++;
        foods.remove(hitFood);
        _spawnNormalFood();
        _maybeSpawnSpecials();
        _maybeSpawnObstacles();
      } else {
        score += 50;
        foods.remove(hitFood);
      }
      if (score > highScore) {
        highScore = score;
      }
    } else {
      snake.removeAt(0);
    }

    for (final f in foods) {
      if (f.type != FoodType.normal) f.ticksLeft--;
    }
    foods.removeWhere((f) => f.type != FoodType.normal && f.ticksLeft <= 0);

    return true;
  }

  void _spawnNormalFood() {
    final spot = _randomFreeCell(minDistanceFromHead: 1);
    if (spot == null) {
      _gameOver();
      return;
    }
    foods.removeWhere((f) => f.type == FoodType.normal);
    foods.add(Food(pos: spot, type: FoodType.normal));
  }

  void _maybeSpawnSpecials() {
    if (!hasGolden && _random.nextDouble() < goldenChance) {
      final spot = _randomFreeCell(minDistanceFromHead: 2);
      if (spot != null) {
        foods.add(
          Food(
            pos: spot,
            type: FoodType.golden,
            ticksLeft: goldenLifetimeTicks,
          ),
        );
      }
    }
    if (!hasBomb &&
        score >= bombScoreGate &&
        _random.nextDouble() < bombChance) {
      final spot = _randomFreeCell(minDistanceFromHead: 4);
      if (spot != null) {
        foods.add(
          Food(pos: spot, type: FoodType.bomb, ticksLeft: bombLifetimeTicks),
        );
      }
    }
  }

  void _maybeSpawnObstacles() {
    if (difficulty != SnakeDifficulty.hard) return;
    if (applesEaten % 3 != 0) return;

    final length = 2 + _random.nextInt(2);
    final horizontal = _random.nextBool();

    for (int attempt = 0; attempt < 40; attempt++) {
      final x = _random.nextInt(gridSize);
      final y = _random.nextInt(gridSize);
      final cells = <Point>[];
      var ok = true;
      for (int i = 0; i < length; i++) {
        final p = horizontal ? Point(x + i, y) : Point(x, y + i);
        if (p.x < 0 || p.x >= gridSize || p.y < 0 || p.y >= gridSize) {
          ok = false;
          break;
        }
        if (!_isFree(p)) {
          ok = false;
          break;
        }
        if (_manhattan(p, snake.last) <= 2 ||
            _manhattan(p, normalFood.pos) <= 1) {
          ok = false;
          break;
        }
        cells.add(p);
      }
      if (ok) {
        obstacles.addAll(cells);
        return;
      }
    }
  }

  Point? _randomFreeCell({int minDistanceFromHead = 0}) {
    final head = snake.last;
    final available = <Point>[];
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final p = Point(x, y);
        if (!_isFree(p)) continue;
        if (_manhattan(p, head) < minDistanceFromHead) continue;
        available.add(p);
      }
    }
    if (available.isEmpty) return null;
    return available[_random.nextInt(available.length)];
  }

  void _gameOver() {
    state = SnakeGameState.gameOver;
    if (score > highScore) {
      highScore = score;
    }
  }
}
