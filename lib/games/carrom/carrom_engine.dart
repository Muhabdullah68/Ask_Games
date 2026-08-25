import 'dart:math';

import 'carrom_models.dart';

class CarromEngine {
  // ---------------------------------------------------------------- board
  static const double boardSize = 400;
  static const double pocketRadius = 18;
  static const double strikerRadius = 14;
  static const double carromManRadius = 9;
  static const double queenRadius = 9;
  static const double baselineY = 345;
  static const double baselineMinX = 100;
  static const double baselineMaxX = 300;
  static const double centerX = boardSize / 2;
  static const double centerY = boardSize / 2;
  static const double centerCircleRadius = 40;

  // physics
  static const double friction = 0.991;
  static const double wallRestitution = 0.72;
  static const double discRestitution = 0.95;
  static const double minVelocity = 0.1;
  static const double fixedDt = 1 / 120;
  static const int maxSubSteps = 8;

  // pocket positions
  static final List<(double, double)> pockets = [
    (pocketRadius + 2, pocketRadius + 2),
    (boardSize - pocketRadius - 2, pocketRadius + 2),
    (pocketRadius + 2, boardSize - pocketRadius - 2),
    (boardSize - pocketRadius - 2, boardSize - pocketRadius - 2),
  ];

  // -------------------------------------------------------------- state
  final Random _rng = Random();
  late List<CarromDisc> discs;
  CarromPlayer currentPlayer = CarromPlayer.one;
  TurnPhase phase = TurnPhase.placeStriker;
  int whitesPocketed = 0;
  int blacksPocketed = 0;
  bool queenPending = false;
  bool queenCoveredByOne = false;
  bool queenCoveredByTwo = false;
  int scoreOne = 0;
  int scoreTwo = 0;
  CarromGameMode mode = CarromGameMode.vsAI;
  CarromDifficulty difficulty = CarromDifficulty.medium;
  List<CarromDisc> pocketedThisTurn = [];

  // striker
  double strikerX = centerX;
  double strikerY = baselineY;

  CarromEngine({
    this.mode = CarromGameMode.vsAI,
    this.difficulty = CarromDifficulty.medium,
  }) {
    resetBoard();
  }

  // ----------------------------------------------------------- setup

  void resetBoard() {
    discs = [];
    currentPlayer = CarromPlayer.one;
    phase = TurnPhase.placeStriker;
    whitesPocketed = 0;
    blacksPocketed = 0;
    queenPending = false;
    queenCoveredByOne = false;
    queenCoveredByTwo = false;
    scoreOne = 0;
    scoreTwo = 0;
    pocketedThisTurn = [];
    strikerX = centerX;
    strikerY = baselineY;
    _placePieces();
  }

  void _placePieces() {
    discs.clear();

    // Striker
    discs.add(
      CarromDisc(
        x: centerX,
        y: baselineY,
        type: DiscType.striker,
        radius: strikerRadius,
      ),
    );

    // Queen at center
    discs.add(
      CarromDisc(
        x: centerX,
        y: centerY,
        type: DiscType.queen,
        radius: queenRadius,
      ),
    );

    // 9 white + 9 black in traditional carrom arrangement
    // Arranged in a circle pattern around the center
    final angles = <double>[];
    // Inner ring: 6 pieces at radius 20
    for (int i = 0; i < 6; i++) {
      angles.add(i * 60.0);
    }
    // Middle ring: 3 pieces at radius 36 (alternating)
    for (int i = 0; i < 3; i++) {
      angles.add(i * 120.0 + 30.0);
    }

    final innerRadius = 22.0;
    final outerRadius = 38.0;

    // Inner ring: alternating white/black
    for (int i = 0; i < 6; i++) {
      final angle = angles[i] * pi / 180;
      final type = i.isEven ? DiscType.white : DiscType.black;
      discs.add(
        CarromDisc(
          x: centerX + cos(angle) * innerRadius,
          y: centerY + sin(angle) * innerRadius,
          type: type,
          radius: carromManRadius,
        ),
      );
    }

    // Middle ring
    for (int i = 0; i < 3; i++) {
      final angle = angles[6 + i] * pi / 180;
      final type = i.isEven ? DiscType.white : DiscType.black;
      discs.add(
        CarromDisc(
          x: centerX + cos(angle) * outerRadius,
          y: centerY + sin(angle) * outerRadius,
          type: type,
          radius: carromManRadius,
        ),
      );
    }

    // Remaining pieces in outer ring
    final remainingWhite = 9 - 4; // already placed 4 white (3 inner + 1 outer)
    final remainingBlack = 9 - 5; // already placed 5 black (3 inner + 2 outer)

    for (int i = 0; i < remainingWhite + remainingBlack; i++) {
      final angle = (i * 360.0 / (remainingWhite + remainingBlack)) * pi / 180;
      final r = 55.0 + (i % 2) * 8.0;
      final type = i < remainingWhite ? DiscType.white : DiscType.black;
      discs.add(
        CarromDisc(
          x: centerX + cos(angle) * r,
          y: centerY + sin(angle) * r,
          type: type,
          radius: carromManRadius,
        ),
      );
    }

    // Ensure pieces don't overlap with each other or the center
    _resolveOverlaps();
  }

  void _resolveOverlaps() {
    for (int iter = 0; iter < 50; iter++) {
      bool anyOverlap = false;
      for (int i = 0; i < discs.length; i++) {
        for (int j = i + 1; j < discs.length; j++) {
          if (discs[i].pocketed || discs[j].pocketed) continue;
          final dx = discs[j].x - discs[i].x;
          final dy = discs[j].y - discs[i].y;
          final dist = sqrt(dx * dx + dy * dy);
          final minDist = discs[i].radius + discs[j].radius + 1;
          if (dist < minDist && dist > 0) {
            anyOverlap = true;
            final overlap = (minDist - dist) / 2;
            final nx = dx / dist;
            final ny = dy / dist;
            discs[i].x -= nx * overlap;
            discs[i].y -= ny * overlap;
            discs[j].x += nx * overlap;
            discs[j].y += ny * overlap;
          }
        }
      }
      if (!anyOverlap) break;
    }
  }

  // ----------------------------------------------------------- physics

  void update(double dt) {
    if (phase != TurnPhase.simulating) return;

    final steps = (dt / fixedDt).ceil().clamp(1, maxSubSteps);
    for (int s = 0; s < steps; s++) {
      _subStep(fixedDt);
    }

    if (!_anyDiscMoving()) {
      _evaluateShot();
    }
  }

  void _subStep(double dt) {
    for (final d in discs) {
      if (d.pocketed || d.type == DiscType.striker) continue;
      // Friction
      d.vx *= friction;
      d.vy *= friction;
      // Move
      d.x += d.vx * dt * 60;
      d.y += d.vy * dt * 60;
      // Stop very slow
      if (d.vx.abs() < minVelocity) d.vx = 0;
      if (d.vy.abs() < minVelocity) d.vy = 0;
    }

    // Striker moves too
    final striker = _striker;
    if (striker != null && !striker.pocketed) {
      striker.vx *= friction;
      striker.vy *= friction;
      striker.x += striker.vx * dt * 60;
      striker.y += striker.vy * dt * 60;
      if (striker.vx.abs() < minVelocity) striker.vx = 0;
      if (striker.vy.abs() < minVelocity) striker.vy = 0;
    }

    _resolveDiscCollisions();
    _resolveWallCollisions();
    _checkPockets();
  }

  bool _anyDiscMoving() {
    for (final d in discs) {
      if (d.pocketed) continue;
      if (d.vx.abs() > minVelocity || d.vy.abs() > minVelocity) return true;
    }
    return false;
  }

  // --------------------------------------------------------- collisions

  void _resolveDiscCollisions() {
    for (int i = 0; i < discs.length; i++) {
      if (discs[i].pocketed) continue;
      for (int j = i + 1; j < discs.length; j++) {
        if (discs[j].pocketed) continue;
        _resolvePair(discs[i], discs[j]);
      }
    }
  }

  void _resolvePair(CarromDisc a, CarromDisc b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final dist = sqrt(dx * dx + dy * dy);
    final minDist = a.radius + b.radius;

    if (dist >= minDist || dist == 0) return;

    // Normal
    final nx = dx / dist;
    final ny = dy / dist;

    // Relative velocity
    final dvx = a.vx - b.vx;
    final dvy = a.vy - b.vy;
    final dvn = dvx * nx + dvy * ny;

    if (dvn <= 0) return; // Moving apart

    final impulse = dvn * discRestitution;
    a.vx -= impulse * nx;
    a.vy -= impulse * ny;
    b.vx += impulse * nx;
    b.vy += impulse * ny;

    // Separate
    final overlap = (minDist - dist) / 2 + 0.5;
    a.x -= overlap * nx;
    a.y -= overlap * ny;
    b.x += overlap * nx;
    b.y += overlap * ny;
  }

  void _resolveWallCollisions() {
    for (final d in discs) {
      if (d.pocketed) continue;
      // Square wall bounds
      if (d.x - d.radius < 0) {
        d.x = d.radius;
        d.vx = d.vx.abs() * wallRestitution;
      }
      if (d.x + d.radius > boardSize) {
        d.x = boardSize - d.radius;
        d.vx = -d.vx.abs() * wallRestitution;
      }
      if (d.y - d.radius < 0) {
        d.y = d.radius;
        d.vy = d.vy.abs() * wallRestitution;
      }
      if (d.y + d.radius > boardSize) {
        d.y = boardSize - d.radius;
        d.vy = -d.vy.abs() * wallRestitution;
      }
    }
  }

  void _checkPockets() {
    for (final d in discs) {
      if (d.pocketed) continue;
      for (final (px, py) in pockets) {
        final dx = d.x - px;
        final dy = d.y - py;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < pocketRadius * 0.8) {
          d.pocketed = true;
          d.vx = 0;
          d.vy = 0;
          pocketedThisTurn.add(d);
        }
      }
    }
  }

  // ------------------------------------------------------ striker control

  void placeStriker(double x) {
    strikerX = x.clamp(
      baselineMinX + strikerRadius,
      baselineMaxX - strikerRadius,
    );
    strikerY = baselineY;
    final striker = _striker;
    if (striker != null) {
      striker.x = strikerX;
      striker.y = strikerY;
      striker.pocketed = false;
    }
  }

  CarromDisc? get _striker {
    for (final d in discs) {
      if (d.type == DiscType.striker) return d;
    }
    return null;
  }

  void shoot(double aimDx, double aimDy, double power) {
    final striker = _striker;
    if (striker == null || striker.pocketed) return;

    final len = sqrt(aimDx * aimDx + aimDy * aimDy);
    if (len == 0) return;

    final nx = aimDx / len;
    final ny = aimDy / len;
    final speed = power * 18; // max speed

    striker.vx = nx * speed;
    striker.vy = ny * speed;

    pocketedThisTurn.clear();
    phase = TurnPhase.simulating;
  }

  // ------------------------------------------------------ shot evaluation

  void _evaluateShot() {
    phase = TurnPhase.evaluating;

    int whiteCount = 0;
    int blackCount = 0;
    bool queenIn = false;
    bool strikerIn = false;

    for (final d in pocketedThisTurn) {
      switch (d.type) {
        case DiscType.white:
          whiteCount++;
          break;
        case DiscType.black:
          blackCount++;
          break;
        case DiscType.queen:
          queenIn = true;
          break;
        case DiscType.striker:
          strikerIn = true;
          break;
      }
    }

    bool foul = strikerIn;
    bool turnContinues = false;

    final isOne = currentPlayer == CarromPlayer.one;

    // Update scores
    if (isOne) {
      whitesPocketed += whiteCount;
      scoreOne += whiteCount;
    } else {
      blacksPocketed += blackCount;
      scoreTwo += blackCount;
    }

    // Queen handling
    if (queenIn && !queenPending) {
      queenPending = true;
      if (isOne) {
        queenCoveredByOne = false;
      } else {
        queenCoveredByTwo = false;
      }
    } else if (queenIn && queenPending) {
      // Queen was already pending — this shouldn't happen normally
    }

    if (queenPending) {
      final covered = isOne ? whiteCount > 0 : blackCount > 0;
      if (covered) {
        // Queen covered
        if (isOne) {
          queenCoveredByOne = true;
          scoreOne += 5;
        } else {
          queenCoveredByTwo = true;
          scoreTwo += 5;
        }
        queenPending = false;
      } else if (!queenIn) {
        // Queen returned to center (was pending but not covered)
        // Actually queen was just pocketed this turn — check if covered
      }
    }

    // If queen was pocketed this turn and was pending from before
    if (queenPending && !queenIn) {
      // Queen was pending, no cover this shot — queen stays on board (already returned by being pocketed before)
      queenPending = false;
    }

    // Turn continues if player pocketed their own pieces (and no foul)
    if (!foul) {
      turnContinues = isOne ? whiteCount > 0 : blackCount > 0;
    }

    // Check game over
    bool gameOver = false;
    CarromPlayer? winner;

    if (whitesPocketed >= 9) {
      gameOver = true;
      winner = CarromPlayer.one;
    } else if (blacksPocketed >= 9) {
      gameOver = true;
      winner = CarromPlayer.two;
    }

    if (foul) {
      // Reset striker
      final striker = _striker;
      if (striker != null) {
        striker.pocketed = false;
        striker.vx = 0;
        striker.vy = 0;
      }
    }

    final result = ShotResult(
      whitesPocketed: whiteCount,
      blacksPocketed: blackCount,
      queenPocketed: queenIn,
      strikerPocketed: strikerIn,
      turnContinues: turnContinues,
      queenCovered:
          queenIn &&
          queenPending == false &&
          (isOne ? queenCoveredByOne : queenCoveredByTwo),
      gameOver: gameOver,
      winner: winner,
    );

    if (gameOver) {
      phase = TurnPhase.gameOver;
      _shotResult = result;
      return;
    }

    if (!turnContinues || foul) {
      _advanceTurn();
    } else {
      phase = TurnPhase.placeStriker;
    }

    // Reset striker position for next turn
    strikerX = centerX;
    strikerY = baselineY;
    final striker = _striker;
    if (striker != null) {
      striker.x = centerX;
      striker.y = baselineY;
      striker.vx = 0;
      striker.vy = 0;
    }

    _shotResult = result;
  }

  ShotResult? _shotResult;
  ShotResult? consumeShotResult() {
    final r = _shotResult;
    _shotResult = null;
    return r;
  }

  int _countOnBoard(DiscType type) {
    int count = 0;
    for (final d in discs) {
      if (!d.pocketed && d.type == type) count++;
    }
    return count;
  }

  void _advanceTurn() {
    do {
      currentPlayer = currentPlayer == CarromPlayer.one
          ? CarromPlayer.two
          : CarromPlayer.one;
    } while (_isFinished(currentPlayer));

    phase = TurnPhase.placeStriker;
  }

  bool _isFinished(CarromPlayer p) {
    if (p == CarromPlayer.one) return whitesPocketed >= 9;
    return blacksPocketed >= 9;
  }

  bool get isAITurn {
    if (mode == CarromGameMode.local) return false;
    return currentPlayer == CarromPlayer.two;
  }

  int get remainingWhite => _countOnBoard(DiscType.white);
  int get remainingBlack => _countOnBoard(DiscType.black);

  // ----------------------------------------------------------- AI

  (double aimDx, double aimDy, double power)? chooseAIMove() {
    final striker = _striker;
    if (striker == null || striker.pocketed) return null;

    final targetType = currentPlayer == CarromPlayer.one
        ? DiscType.white
        : DiscType.black;
    final targets = discs
        .where((d) => !d.pocketed && d.type == targetType)
        .toList();

    if (targets.isEmpty) {
      // No own pieces left — try to hit anything
      return _randomShot();
    }

    double bestScore = -1;
    double bestAimX = 0, bestAimY = 0, bestPower = 0.8;

    for (final target in targets) {
      for (final (px, py) in pockets) {
        final score = _evaluateAim(striker, target, px, py);
        if (score > bestScore) {
          bestScore = score;
          // Compute aim
          final tx = target.x - striker.x;
          final ty = target.y - striker.y;
          final tDist = sqrt(tx * tx + ty * ty);

          // Direction from target to pocket
          final tpDx = px - target.x;
          final tpDy = py - target.y;
          final tpDist = sqrt(tpDx * tpDx + tpDy * tpDy);

          if (tDist > 0 && tpDist > 0) {
            // Aim direction: we want to hit the target so it goes toward pocket
            // The striker should hit the target on the side opposite to the pocket
            final hitX =
                target.x - (tpDx / tpDist) * (target.radius + striker.radius);
            final hitY =
                target.y - (tpDy / tpDist) * (target.radius + striker.radius);

            bestAimX = hitX - striker.x;
            bestAimY = hitY - striker.y;
            bestPower = (0.7 + tDist / 300).clamp(0.5, 1.0);
          }
        }
      }
    }

    if (bestScore < 0) return _randomShot();

    // Apply difficulty error
    final errorAngle = _difficultyErrorAngle();
    final cosE = cos(errorAngle);
    final sinE = sin(errorAngle);
    final ax = bestAimX * cosE - bestAimY * sinE;
    final ay = bestAimX * sinE + bestAimY * cosE;

    final powerVariance = _difficultyPowerVariance();
    final power = (bestPower * powerVariance).clamp(0.3, 1.0);

    return (ax, ay, power);
  }

  double _evaluateAim(
    CarromDisc striker,
    CarromDisc target,
    double px,
    double py,
  ) {
    final tx = target.x - striker.x;
    final ty = target.y - striker.y;
    final tDist = sqrt(tx * tx + ty * ty);

    final tpDx = px - target.x;
    final tpDy = py - target.y;
    final tpDist = sqrt(tpDx * tpDx + tpDy * tpDy);

    if (tDist == 0 || tpDist == 0) return -1;

    // Cut angle: angle between striker→target and target→pocket
    final cosAngle = (tx * tpDx + ty * tpDy) / (tDist * tpDist);
    final cutAngle = acos(cosAngle.clamp(-1, 1));

    // Direct shots are better (cut angle close to pi = 180 degrees is ideal)
    final directness = (pi - cutAngle).abs() / pi;

    // Closer is easier
    final distanceScore = 1.0 - (tDist / 300).clamp(0, 1);

    return directness * 60 + distanceScore * 40;
  }

  (double, double, double) _randomShot() {
    final angle = _rng.nextDouble() * 2 * pi;
    final power = 0.5 + _rng.nextDouble() * 0.4;
    return (cos(angle), sin(angle), power);
  }

  double _difficultyErrorAngle() {
    final base = switch (difficulty) {
      CarromDifficulty.easy => 15.0,
      CarromDifficulty.medium => 8.0,
      CarromDifficulty.hard => 3.0,
    };
    return (_rng.nextDouble() * 2 - 1) * base * pi / 180;
  }

  double _difficultyPowerVariance() {
    final (min, max) = switch (difficulty) {
      CarromDifficulty.easy => (0.6, 0.85),
      CarromDifficulty.medium => (0.75, 0.95),
      CarromDifficulty.hard => (0.9, 1.0),
    };
    return min + _rng.nextDouble() * (max - min);
  }

  // ------------------------------------------------- trajectory preview

  List<(double, double)> computeTrajectory(
    double startX,
    double startY,
    double aimDx,
    double aimDy,
  ) {
    final points = <(double, double)>[];
    double px = startX;
    double py = startY;
    double dx = aimDx;
    double dy = aimDy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return points;
    dx /= len;
    dy /= len;

    final stepSize = 3.0;
    final maxSteps = 150;

    for (int i = 0; i < maxSteps; i++) {
      px += dx * stepSize;
      py += dy * stepSize;
      points.add((px, py));

      // Wall bounce
      if (px - strikerRadius < 0 || px + strikerRadius > boardSize) {
        dx = -dx;
        px = px.clamp(strikerRadius, boardSize - strikerRadius);
      }
      if (py - strikerRadius < 0 || py + strikerRadius > boardSize) {
        dy = -dy;
        py = py.clamp(strikerRadius, boardSize - strikerRadius);
      }

      // Check disc hit
      bool hit = false;
      for (final d in discs) {
        if (d.pocketed || d.type == DiscType.striker) continue;
        final ddx = px - d.x;
        final ddy = py - d.y;
        final dist = sqrt(ddx * ddx + ddy * ddy);
        if (dist < d.radius + strikerRadius) {
          hit = true;
          break;
        }
      }
      if (hit) break;
    }

    return points;
  }
}
