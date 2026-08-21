import 'dart:math';

enum BubbleColor { red, blue, green, yellow, purple, orange }

enum BubbleDifficulty { easy, medium, hard }

enum BubbleGameMode { solo, pve }

enum BubbleGameState { idle, shooting, aiTurn, popping, falling, gameOver, won }

class Bubble {
  BubbleColor color;
  bool isBomb;
  bool popped;

  Bubble({required this.color, this.isBomb = false, this.popped = false});
}

/// Simulated shot trajectory in grid units (x: 0..gridCols, y: 0..boardHeight).
/// [points] are waypoints including start, every wall bounce and the end.
class ShotPath {
  final List<List<double>> points;
  final List<int>? landing;
  final double angle;

  const ShotPath({required this.points, required this.angle, this.landing});
}

class ShootResult {
  final int row;
  final int col;
  final List<List<int>> matched;
  final List<List<int>> dropped;
  final bool matchedAny;
  final Map<String, Bubble> popped;
  final BubbleColor placedColor;
  final bool placedIsBomb;
  final List<List<double>> path;

  const ShootResult({
    required this.row,
    required this.col,
    required this.matched,
    required this.dropped,
    required this.matchedAny,
    required this.placedColor,
    this.placedIsBomb = false,
    this.popped = const {},
    this.path = const [],
  });
}

class _AIPlan {
  final double angle;
  final BubbleColor color;
  final bool isBomb;

  const _AIPlan(this.angle, this.color, this.isBomb);
}

class _AITarget {
  final int row;
  final int col;
  final BubbleColor color;

  const _AITarget(this.row, this.col, this.color);
}

class BubbleShooterGame {
  final int gridRows;
  final int gridCols;
  late List<List<Bubble?>> grid;
  BubbleColor currentColor;
  bool currentIsBomb;
  BubbleColor nextColor;
  bool nextIsBomb;
  BubbleDifficulty difficulty;
  BubbleGameMode mode;
  BubbleGameState state;
  int playerScore;
  int aiScore;
  int highScore;
  int _shotsUntilNewRow;
  bool _gameOver;
  final Random _random = Random();

  static const int _shotsPerNewRow = 6;
  static const double bombProbability = 0.20;
  static const double rowHeight = 0.88;
  static const double bubbleRadius = 0.4;
  static const double _collideDist = 0.78;
  static const double minAimAngle = 0.14;
  static const double _simStep = 0.04;

  BubbleShooterGame({
    this.gridRows = 10,
    this.gridCols = 10,
    this.difficulty = BubbleDifficulty.medium,
    this.mode = BubbleGameMode.solo,
    this.highScore = 0,
  })  : currentColor = BubbleColor.red,
        currentIsBomb = false,
        nextColor = BubbleColor.blue,
        nextIsBomb = false,
        _shotsUntilNewRow = _shotsPerNewRow,
        _gameOver = false,
        state = BubbleGameState.idle,
        playerScore = 0,
        aiScore = 0 {
    _initBoard();
    currentColor = _randomColor();
    currentIsBomb = _random.nextDouble() < bombProbability;
    _rollNextAmmo();
  }

  double get boardHeight => gridRows * rowHeight;
  bool get isGameOver => _gameOver;
  bool get isAITurn => state == BubbleGameState.aiTurn;
  int get shotsUntilNewRow => _shotsUntilNewRow;
  bool get isBoardCleared => _isBoardCleared();

  void _initBoard() {
    grid = List.generate(gridRows, (_) => List.generate(gridCols, (_) => null));
    final colors = BubbleColor.values.toList()..shuffle(_random);
    int colorIndex = 0;
    for (int r = 0; r < 6; r++) {
      final cols = colsInRow(r);
      final fillRate = r == 0 ? 1.0 : 0.78;
      for (int c = 0; c < cols; c++) {
        if (_random.nextDouble() < fillRate) {
          grid[r][c] = Bubble(color: colors[colorIndex % colors.length]);
          colorIndex++;
        }
      }
    }
  }

  int colsInRow(int row) => row % 2 == 0 ? gridCols : gridCols - 1;

  BubbleColor _randomColor() {
    return BubbleColor.values[_random.nextInt(BubbleColor.values.length)];
  }

  void _rollNextAmmo() {
    nextColor = _randomColor();
    nextIsBomb = _random.nextDouble() < bombProbability;
  }

  /// Swap the ready and next bubbles. Only allowed on the player's idle turn.
  bool swapAmmo() {
    if (_gameOver || state != BubbleGameState.idle) return false;
    final c = currentColor;
    final b = currentIsBomb;
    currentColor = nextColor;
    currentIsBomb = nextIsBomb;
    nextColor = c;
    nextIsBomb = b;
    return true;
  }

  bool _isBoardCleared() {
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < colsInRow(r); c++) {
        if (grid[r][c] != null) return false;
      }
    }
    return true;
  }

  void resetBoard() {
    _initBoard();
    playerScore = 0;
    aiScore = 0;
    _shotsUntilNewRow = _shotsPerNewRow;
    _gameOver = false;
    state = BubbleGameState.idle;
    currentColor = _randomColor();
    currentIsBomb = _random.nextDouble() < bombProbability;
    _rollNextAmmo();
  }

  void resetScores() {
    resetBoard();
    highScore = 0;
  }

  void setDifficulty(BubbleDifficulty d) {
    difficulty = d;
    resetBoard();
  }

  void setMode(BubbleGameMode m) {
    mode = m;
    resetBoard();
  }

  /// Simulate a shot fired from the bottom-center cannon at [angle]
  /// (radians, standard math orientation: straight up = pi/2).
  /// Reflects off side walls and stops at the first collision.
  ShotPath simulateShot(double angle) {
    final a = angle.clamp(minAimAngle, pi - minAimAngle);
    double x = gridCols / 2.0;
    double y = boardHeight;
    double dx = cos(a);
    double dy = -sin(a);
    final points = <List<double>>[[x, y]];

    for (int i = 0; i < 8000; i++) {
      x += dx * _simStep;
      y += dy * _simStep;

      if (x <= bubbleRadius && dx < 0) {
        x = 2 * bubbleRadius - x;
        dx = -dx;
        points.add([x, y]);
      } else if (x >= gridCols - bubbleRadius && dx > 0) {
        x = 2 * (gridCols - bubbleRadius) - x;
        dx = -dx;
        points.add([x, y]);
      }

      if (y <= bubbleRadius || _occupiedContact(x, y) != null) {
        points.add([x, y]);
        return ShotPath(points: points, angle: a, landing: _resolveLanding(x, y));
      }
    }
    points.add([x, y]);
    return ShotPath(points: points, angle: a, landing: _resolveLanding(x, y));
  }

  List<int>? _occupiedContact(double x, double y) {
    final approxRow = ((y - 0.5) / rowHeight).round();
    for (int r = max(0, approxRow - 1); r <= min(gridRows - 1, approxRow + 1); r++) {
      final cols = colsInRow(r);
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == null) continue;
        final cx = (r.isOdd ? 0.5 : 0.0) + c + 0.5;
        final cy = r * rowHeight + 0.5;
        final ddx = cx - x;
        final ddy = cy - y;
        if (ddx * ddx + ddy * ddy < _collideDist * _collideDist) return [r, c];
      }
    }
    return null;
  }

  List<int>? _resolveLanding(double x, double y) {
    List<int>? best;
    double bestDist = double.infinity;
    final approxRow = ((y - 0.5) / rowHeight).round();
    for (int r = max(0, approxRow - 2); r <= min(gridRows - 1, approxRow + 2); r++) {
      final off = r.isOdd ? 0.5 : 0.0;
      final approxCol = (x - off - 0.5).round();
      for (int c = max(0, approxCol - 2); c <= min(colsInRow(r) - 1, approxCol + 2); c++) {
        if (grid[r][c] != null) continue;
        if (r != 0 && !_hasAdjacentBubble(r, c)) continue;
        final cx = off + c + 0.5;
        final cy = r * rowHeight + 0.5;
        final d = (cx - x) * (cx - x) + (cy - y) * (cy - y);
        if (d < bestDist) {
          bestDist = d;
          best = [r, c];
        }
      }
    }
    return best;
  }

  /// Shoot the player's current bubble at [angle]. Returns ShootResult.
  ShootResult? shootAtAngle(double angle) {
    if (_gameOver) return null;
    if (state == BubbleGameState.aiTurn) return null;

    final sim = simulateShot(angle);
    final landing = sim.landing;
    if (landing == null) {
      _advancePlayerTurn(false, 0, [], []);
      return null;
    }

    return _applyShot(
      landing[0],
      landing[1],
      Bubble(color: currentColor, isBomb: currentIsBomb),
      sim.points,
      true,
    );
  }

  /// AI shoots. Returns ShootResult with the solved trajectory in [path].
  ShootResult? aiShoot() {
    if (state != BubbleGameState.aiTurn || _gameOver) return null;

    final plan = _planAIShot();
    if (plan == null) {
      _advanceAITurn(false, 0, [], []);
      return null;
    }

    final sim = simulateShot(plan.angle);
    final landing = sim.landing;
    if (landing == null) {
      _advanceAITurn(false, 0, [], []);
      return null;
    }

    return _applyShot(
      landing[0],
      landing[1],
      Bubble(color: plan.color, isBomb: plan.isBomb),
      sim.points,
      false,
    );
  }

  ShootResult _applyShot(int r, int c, Bubble ammo, List<List<double>> path, bool isPlayer) {
    grid[r][c] = ammo;

    final affected = <List<int>>[];
    bool matchedAny = false;

    if (ammo.isBomb) {
      affected.add([r, c]);
      for (final n in _getNeighbors(r, c)) {
        if (grid[n[0]][n[1]] != null) affected.add(n);
      }
      matchedAny = true;
    } else {
      final matches = _findMatches(r, c);
      if (matches.length >= 3) {
        affected.addAll(matches);
        matchedAny = true;
      }
    }

    final popped = <String, Bubble>{};
    final dropped = <List<int>>[];
    int poppedCount = 0;
    if (matchedAny) {
      for (final pos in affected) {
        popped['${pos[0]},${pos[1]}'] = grid[pos[0]][pos[1]]!;
        grid[pos[0]][pos[1]] = null;
        poppedCount++;
      }
      dropped.addAll(_dropUnsupported());
      poppedCount += dropped.length;
    }

    int points = 0;
    if (poppedCount > 0) {
      final multiplier = difficulty == BubbleDifficulty.easy
          ? 1
          : difficulty == BubbleDifficulty.medium
              ? 2
              : 3;
      final chainBonus = affected.length >= 5 ? 3 : 2;
      points = poppedCount * 10 * multiplier * chainBonus;
      if (isPlayer) {
        playerScore += points;
        if (playerScore > highScore) highScore = playerScore;
      } else {
        aiScore += points;
        if (aiScore > highScore) highScore = aiScore;
      }
    }

    if (isPlayer) {
      _advancePlayerTurn(matchedAny, points, affected, dropped);
    } else {
      _advanceAITurn(matchedAny, points, affected, dropped);
    }

    return ShootResult(
      row: r,
      col: c,
      matched: affected,
      dropped: dropped,
      matchedAny: matchedAny,
      popped: popped,
      placedColor: ammo.color,
      placedIsBomb: ammo.isBomb,
      path: path,
    );
  }

  void _advancePlayerTurn(bool matched, int points, List<List<int>> matches, List<List<int>> dropped) {
    if (matched) {
      _shotsUntilNewRow = _shotsPerNewRow;
    } else {
      _shotsUntilNewRow--;
      if (_shotsUntilNewRow <= 0) {
        _pushDownRow();
        _shotsUntilNewRow = _shotsPerNewRow;
      }
    }

    if (_checkGameEnd()) return;

    currentColor = nextColor;
    currentIsBomb = nextIsBomb;
    _rollNextAmmo();

    if (mode == BubbleGameMode.pve && !_gameOver) {
      state = BubbleGameState.aiTurn;
    }
  }

  void _advanceAITurn(bool matched, int points, List<List<int>> matches, List<List<int>> dropped) {
    if (_checkGameEnd()) return;

    if (mode == BubbleGameMode.pve && !_gameOver) {
      state = BubbleGameState.idle;
    }
  }

  bool _checkGameEnd() {
    if (_isBoardCleared()) {
      _gameOver = true;
      if (mode == BubbleGameMode.pve) {
        state = playerScore >= aiScore ? BubbleGameState.won : BubbleGameState.gameOver;
      } else {
        state = BubbleGameState.won;
      }
      if (playerScore > highScore) highScore = playerScore;
      return true;
    }
    if (_hasReachedBottom()) {
      _gameOver = true;
      state = BubbleGameState.gameOver;
      if (playerScore > highScore) highScore = playerScore;
      return true;
    }
    return false;
  }

  bool _hasReachedBottom() {
    final bottomRow = gridRows - 1;
    for (int c = 0; c < colsInRow(bottomRow); c++) {
      if (grid[bottomRow][c] != null) return true;
    }
    return false;
  }

  bool _hasAdjacentBubble(int row, int col) {
    for (final n in _getNeighbors(row, col)) {
      if (grid[n[0]][n[1]] != null) return true;
    }
    return false;
  }

  List<List<int>> _findMatches(int row, int col) {
    final b = grid[row][col];
    if (b == null) return [];

    final visited = <String>{};
    final matches = <List<int>>[];
    final queue = <List<int>>[[row, col]];

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final key = '${current[0]},${current[1]}';
      if (visited.contains(key)) continue;
      visited.add(key);

      final cb = grid[current[0]][current[1]];
      if (cb == null || cb.isBomb || cb.color != b.color) continue;

      matches.add(current);
      for (final neighbor in _getNeighbors(current[0], current[1])) {
        if (!visited.contains('${neighbor[0]},${neighbor[1]}')) {
          queue.add(neighbor);
        }
      }
    }
    return matches;
  }

  List<List<int>> _getNeighbors(int row, int col) {
    final neighbors = <List<int>>[];
    final evenRow = row % 2 == 0;
    final offsets = evenRow
        ? [
            [-1, -1], [-1, 0],
            [0, -1], [0, 1],
            [1, -1], [1, 0],
          ]
        : [
            [-1, 0], [-1, 1],
            [0, -1], [0, 1],
            [1, 0], [1, 1],
          ];

    for (final off in offsets) {
      final nr = row + off[0];
      final nc = col + off[1];
      if (nr >= 0 && nr < gridRows && nc >= 0 && nc < colsInRow(nr)) {
        neighbors.add([nr, nc]);
      }
    }
    return neighbors;
  }

  List<List<int>> _dropUnsupported() {
    final connected = <String>{};
    for (int c = 0; c < colsInRow(0); c++) {
      if (grid[0][c] != null) {
        _floodFill(0, c, connected);
      }
    }

    final dropped = <List<int>>[];
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < colsInRow(r); c++) {
        if (grid[r][c] != null && !connected.contains('$r,$c')) {
          dropped.add([r, c]);
          grid[r][c] = null;
        }
      }
    }
    return dropped;
  }

  void _floodFill(int row, int col, Set<String> visited) {
    final key = '$row,$col';
    if (visited.contains(key)) return;
    final b = grid[row][col];
    if (b == null) return;
    visited.add(key);
    for (final n in _getNeighbors(row, col)) {
      _floodFill(n[0], n[1], visited);
    }
  }

  void _pushDownRow() {
    for (int r = gridRows - 1; r > 0; r--) {
      final colsAbove = colsInRow(r - 1);
      final colsCurrent = colsInRow(r);
      for (int c = 0; c < colsCurrent; c++) {
        grid[r][c] = c < colsAbove ? grid[r - 1][c] : null;
      }
    }
    final topCols = colsInRow(0);
    for (int c = 0; c < topCols; c++) {
      grid[0][c] = null;
    }
  }

  _AIPlan? _planAIShot() {
    final isBomb = _random.nextDouble() < bombProbability;
    switch (difficulty) {
      case BubbleDifficulty.easy:
        return _randomPlan(isBomb);
      case BubbleDifficulty.medium:
        return _random.nextBool() ? _smartPlan(isBomb) : _randomPlan(isBomb);
      case BubbleDifficulty.hard:
        return _smartPlan(isBomb);
    }
  }

  _AIPlan? _randomPlan(bool isBomb) {
    for (int i = 0; i < 24; i++) {
      final a = minAimAngle + _random.nextDouble() * (pi - 2 * minAimAngle);
      final sim = simulateShot(a);
      if (sim.landing != null) {
        return _AIPlan(sim.angle, _randomColor(), isBomb);
      }
    }
    final straight = simulateShot(pi / 2);
    if (straight.landing == null) return null;
    return _AIPlan(straight.angle, _randomColor(), isBomb);
  }

  _AIPlan _smartPlan(bool isBomb) {
    final target = _chooseSmartTarget(isBomb);

    final angles = <double>[];
    for (double a = minAimAngle; a <= pi - minAimAngle + 1e-9; a += pi / 180) {
      angles.add(a);
    }
    angles.sort((p, q) => (p - pi / 2).abs().compareTo((q - pi / 2).abs()));

    double? fallbackAngle;
    int? fallbackDist;
    for (final a in angles) {
      final sim = simulateShot(a);
      final landing = sim.landing;
      if (landing == null) continue;
      if (landing[0] == target.row && landing[1] == target.col) {
        return _AIPlan(sim.angle, target.color, isBomb);
      }
      final dist = (landing[0] - target.row).abs() + (landing[1] - target.col).abs();
      if (fallbackDist == null || dist < fallbackDist) {
        fallbackDist = dist;
        fallbackAngle = sim.angle;
      }
    }
    return _AIPlan(fallbackAngle ?? pi / 2, target.color, isBomb);
  }

  _AITarget _chooseSmartTarget(bool useBomb) {
    _AITarget? best;
    int bestScore = -1;

    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < colsInRow(r); c++) {
        if (grid[r][c] != null) continue;
        if (r != 0 && !_hasAdjacentBubble(r, c)) continue;

        int score;
        BubbleColor chosen;
        if (useBomb) {
          score = 0;
          for (final n in _getNeighbors(r, c)) {
            if (grid[n[0]][n[1]] != null) score += 12;
          }
          chosen = _randomColor();
        } else {
          score = 0;
          chosen = BubbleColor.red;
          for (final color in BubbleColor.values) {
            grid[r][c] = Bubble(color: color);
            final matches = _findMatches(r, c);
            int s;
            if (matches.length >= 3) {
              s = matches.length * 20 + _countFloatingAfterRemoval(matches) * 15;
            } else {
              int adjSame = 0;
              for (final n in _getNeighbors(r, c)) {
                final nb = grid[n[0]][n[1]];
                if (nb != null && !nb.isBomb && nb.color == color) adjSame++;
              }
              s = adjSame * 5;
            }
            grid[r][c] = null;
            if (s > score) {
              score = s;
              chosen = color;
            }
          }
        }

        final distFromCenter = (c - gridCols / 2).abs();
        score -= distFromCenter.toInt();

        if (score > bestScore) {
          bestScore = score;
          best = _AITarget(r, c, chosen);
        }
      }
    }
    return best ?? _AITarget(0, gridCols ~/ 2, _randomColor());
  }

  int _countFloatingAfterRemoval(List<List<int>> removed) {
    final saved = <String, Bubble>{};
    for (final p in removed) {
      final key = '${p[0]},${p[1]}';
      saved[key] = grid[p[0]][p[1]]!;
      grid[p[0]][p[1]] = null;
    }

    final connected = <String>{};
    for (int c = 0; c < colsInRow(0); c++) {
      if (grid[0][c] != null) {
        _floodFill(0, c, connected);
      }
    }
    int count = 0;
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < colsInRow(r); c++) {
        if (grid[r][c] != null && !connected.contains('$r,$c')) count++;
      }
    }

    saved.forEach((key, bubble) {
      final parts = key.split(',');
      grid[int.parse(parts[0])][int.parse(parts[1])] = bubble;
    });
    return count;
  }
}
