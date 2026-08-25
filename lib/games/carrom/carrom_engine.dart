import 'dart:math';

import 'carrom_models.dart';

class CarromEngine {
  // ---------------------------------------------------------------- board
  static const double boardSize = 400;
  static const double pocketRadius = 18;
  static const double strikerRadius = 14;
  static const double carromManRadius = 9;
  static const double queenRadius = 9;
  static const double centerX = boardSize / 2;
  static const double centerY = boardSize / 2;
  static const double centerCircleRadius = 40;

  // baselines: (min, max, fixed)
  static const double baselineSpanMin = 100;
  static const double baselineSpanMax = 300;
  static const double baselineBottomY = 345;
  static const double baselineTopY = 55;

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
  bool queenPending = false;
  CarromPlayer? queenPendingPlayer;
  List<CarromDisc> pocketedThisTurn = [];

  // per-player state
  late Map<CarromPlayer, int> scores;
  late Map<CarromPlayer, int> pocketedCount;
  late List<CarromPlayer> activePlayers;
  late Map<CarromPlayer, PlayerSeat> seats;

  // striker
  double strikerX = centerX;
  double strikerY = baselineBottomY;

  CarromEngine({
    CarromGameMode mode = CarromGameMode.ai,
    CarromDifficulty difficulty = CarromDifficulty.medium,
    Map<CarromPlayer, PlayerSeat>? playerSeats,
  }) {
    if (playerSeats != null) {
      seats = playerSeats;
      activePlayers = playerSeats.keys.toList();
    } else if (mode == CarromGameMode.ai) {
      seats = {
        CarromPlayer.one: const PlayerSeat(isAI: false),
        CarromPlayer.two: PlayerSeat(isAI: true, difficulty: difficulty),
      };
      activePlayers = [CarromPlayer.one, CarromPlayer.two];
    } else if (mode == CarromGameMode.local4) {
      seats = {
        CarromPlayer.one: const PlayerSeat(isAI: false),
        CarromPlayer.two: const PlayerSeat(isAI: false),
        CarromPlayer.three: const PlayerSeat(isAI: false),
        CarromPlayer.four: const PlayerSeat(isAI: false),
      };
      activePlayers = [
        CarromPlayer.one,
        CarromPlayer.two,
        CarromPlayer.three,
        CarromPlayer.four,
      ];
    } else {
      seats = {
        CarromPlayer.one: const PlayerSeat(isAI: false),
        CarromPlayer.two: const PlayerSeat(isAI: false),
      };
      activePlayers = [CarromPlayer.one, CarromPlayer.two];
    }
    resetBoard();
  }

  CarromGameMode get mode {
    if (seats.length == 4) return CarromGameMode.local4;
    if (seats.values.any((s) => s.isAI)) return CarromGameMode.ai;
    return CarromGameMode.local2;
  }

  int get playerCount => activePlayers.length;

  // ----------------------------------------------------------- setup

  void resetBoard() {
    discs = [];
    currentPlayer = activePlayers.first;
    phase = TurnPhase.placeStriker;
    queenPending = false;
    queenPendingPlayer = null;
    scores = {for (final p in activePlayers) p: 0};
    pocketedCount = {for (final p in activePlayers) p: 0};
    pocketedThisTurn = [];
    strikerX = centerX;
    strikerY = baselineBottomY;
    _placePieces();
  }

  void _placePieces() {
    discs.clear();

    // Striker at current player's baseline
    discs.add(
      CarromDisc(
        x: centerX,
        y: baselineBottomY,
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

    if (activePlayers.length == 2) {
      _placePieces2P();
    } else {
      _placePieces4P();
    }

    _resolveOverlaps();
  }

  void _placePieces2P() {
    // 9 white + 9 black arranged around center
    final angles = <double>[];
    for (int i = 0; i < 6; i++) {
      angles.add(i * 60.0);
    }
    for (int i = 0; i < 3; i++) {
      angles.add(i * 120.0 + 30.0);
    }

    final innerRadius = 22.0;
    final outerRadius = 38.0;

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

    final remainingWhite = 9 - 4;
    final remainingBlack = 9 - 5;

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
  }

  void _placePieces4P() {
    // 4 pieces per player (white, black, red, blue) in alternating circle
    final colors = [
      DiscType.white,
      DiscType.black,
      DiscType.red,
      DiscType.blue,
    ];

    // Inner ring: 8 pieces
    for (int i = 0; i < 8; i++) {
      final angle = i * 45.0 * pi / 180;
      final type = colors[i % 4];
      final r = 22.0 + (i % 2) * 6.0;
      discs.add(
        CarromDisc(
          x: centerX + cos(angle) * r,
          y: centerY + sin(angle) * r,
          type: type,
          radius: carromManRadius,
        ),
      );
    }

    // Outer ring: remaining 8 pieces
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0 + 22.5) * pi / 180;
      final type = colors[i % 4];
      final r = 42.0 + (i % 2) * 6.0;
      discs.add(
        CarromDisc(
          x: centerX + cos(angle) * r,
          y: centerY + sin(angle) * r,
          type: type,
          radius: carromManRadius,
        ),
      );
    }
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
      d.vx *= friction;
      d.vy *= friction;
      d.x += d.vx * dt * 60;
      d.y += d.vy * dt * 60;
      if (d.vx.abs() < minVelocity) d.vx = 0;
      if (d.vy.abs() < minVelocity) d.vy = 0;
    }

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

    final nx = dx / dist;
    final ny = dy / dist;

    final dvx = a.vx - b.vx;
    final dvy = a.vy - b.vy;
    final dvn = dvx * nx + dvy * ny;

    if (dvn <= 0) return;

    final impulse = dvn * discRestitution;
    a.vx -= impulse * nx;
    a.vy -= impulse * ny;
    b.vx += impulse * nx;
    b.vy += impulse * ny;

    final overlap = (minDist - dist) / 2 + 0.5;
    a.x -= overlap * nx;
    a.y -= overlap * ny;
    b.x += overlap * nx;
    b.y += overlap * ny;
  }

  void _resolveWallCollisions() {
    for (final d in discs) {
      if (d.pocketed) continue;
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

  // ------------------------------------------------------ baseline helpers

  bool _isHorizontalSide(BoardSide side) =>
      side == BoardSide.bottom || side == BoardSide.top;

  // ------------------------------------------------------ striker control

  void placeStriker(double pos) {
    final side = playerSide(currentPlayer);
    if (_isHorizontalSide(side)) {
      strikerX = pos.clamp(
        baselineSpanMin + strikerRadius,
        baselineSpanMax - strikerRadius,
      );
      strikerY = side == BoardSide.bottom ? baselineBottomY : baselineTopY;
    } else {
      strikerY = pos.clamp(
        baselineSpanMin + strikerRadius,
        baselineSpanMax - strikerRadius,
      );
      strikerX = side == BoardSide.right ? baselineBottomY : baselineTopY;
    }
    final striker = _striker;
    if (striker != null) {
      striker.x = strikerX;
      striker.y = strikerY;
      striker.pocketed = false;
    }
  }

  /// Returns a good position along the current player's baseline for AI.
  double aiStrikerPosition() {
    final side = playerSide(currentPlayer);
    final targetType = playerDisc(currentPlayer);
    final targets = discs
        .where((d) => !d.pocketed && d.type == targetType)
        .toList();
    if (targets.isEmpty) return (baselineSpanMin + baselineSpanMax) / 2;

    // Pick the target closest to center and aim along the axis
    double bestPos = (baselineSpanMin + baselineSpanMax) / 2;
    double bestDist = 999999.0;
    for (final t in targets) {
      final d = sqrt(
        (t.x - centerX) * (t.x - centerX) + (t.y - centerY) * (t.y - centerY),
      );
      if (d < bestDist) {
        bestDist = d;
        bestPos = _isHorizontalSide(side) ? t.x : t.y;
      }
    }
    return bestPos.clamp(
      baselineSpanMin + strikerRadius + 10,
      baselineSpanMax - strikerRadius - 10,
    );
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
    final speed = power * 18;

    striker.vx = nx * speed;
    striker.vy = ny * speed;

    pocketedThisTurn.clear();
    phase = TurnPhase.simulating;
  }

  // ------------------------------------------------------ shot evaluation

  void _evaluateShot() {
    phase = TurnPhase.evaluating;

    bool queenIn = false;
    bool strikerIn = false;
    final Map<CarromPlayer, int> pocketed = {};

    for (final d in pocketedThisTurn) {
      if (d.type == DiscType.queen) {
        queenIn = true;
      } else if (d.type == DiscType.striker) {
        strikerIn = true;
      } else {
        // Find which player owns this disc
        for (final p in activePlayers) {
          if (playerDisc(p) == d.type) {
            pocketed[p] = (pocketed[p] ?? 0) + 1;
            break;
          }
        }
      }
    }

    bool foul = strikerIn;
    bool turnContinues = false;

    // Score pocketed pieces for current player
    final myPocketed = pocketed[currentPlayer] ?? 0;
    if (!foul && myPocketed > 0) {
      scores[currentPlayer] = (scores[currentPlayer] ?? 0) + myPocketed;
      pocketedCount[currentPlayer] =
          (pocketedCount[currentPlayer] ?? 0) + myPocketed;
    }

    // Queen handling
    bool queenCovered = false;
    if (queenIn && !queenPending) {
      queenPending = true;
      queenPendingPlayer = currentPlayer;
    }

    if (queenPending && queenPendingPlayer == currentPlayer) {
      if (myPocketed > 0) {
        // Covered!
        queenCovered = true;
        scores[currentPlayer] = (scores[currentPlayer] ?? 0) + 5;
        queenPending = false;
        queenPendingPlayer = null;
      } else if (queenIn) {
        // Pocketed queen on this shot but didn't cover — queen stays pending
      } else if (!queenIn && pocketedThisTurn.isNotEmpty) {
        // Queen was pending from before, not covered this turn
        _returnQueenToCenter();
        queenPending = false;
        queenPendingPlayer = null;
      }
    } else if (queenIn && queenPending && queenPendingPlayer != currentPlayer) {
      // Different player pocketed queen while another player's queen is pending
      _returnQueenToCenter();
    }

    // Turn continues if player pocketed their own pieces (and no foul)
    if (!foul) {
      turnContinues = myPocketed > 0;
    }

    // Check game over: any player has all their pieces pocketed
    bool gameOver = false;
    CarromPlayer? winner;
    final piecesPerPlayer = activePlayers.length == 2 ? 9 : 4;

    for (final p in activePlayers) {
      if ((pocketedCount[p] ?? 0) >= piecesPerPlayer && !queenPending) {
        gameOver = true;
        break;
      }
    }

    // Winner = player with highest score (most pieces + queen bonus)
    if (gameOver) {
      int bestScore = -1;
      for (final p in activePlayers) {
        if ((scores[p] ?? 0) > bestScore) {
          bestScore = scores[p]!;
          winner = p;
        }
      }
    }

    if (foul) {
      final striker = _striker;
      if (striker != null) {
        striker.pocketed = false;
        striker.vx = 0;
        striker.vy = 0;
      }
    }

    final result = ShotResult(
      queenPocketed: queenIn,
      strikerPocketed: strikerIn,
      turnContinues: turnContinues,
      queenCovered: queenCovered,
      gameOver: gameOver,
      winner: winner,
      pocketedByPlayer: pocketed,
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

    // Reset striker to new player's baseline
    _resetStrikerToBaseline();

    _shotResult = result;
  }

  void _returnQueenToCenter() {
    discs.add(
      CarromDisc(
        x: centerX,
        y: centerY,
        type: DiscType.queen,
        radius: queenRadius,
      ),
    );
  }

  void _resetStrikerToBaseline() {
    final side = playerSide(currentPlayer);
    if (_isHorizontalSide(side)) {
      strikerX = centerX;
      strikerY = side == BoardSide.bottom ? baselineBottomY : baselineTopY;
    } else {
      strikerX = side == BoardSide.right ? baselineBottomY : baselineTopY;
      strikerY = centerX;
    }
    final striker = _striker;
    if (striker != null) {
      striker.x = strikerX;
      striker.y = strikerY;
      striker.vx = 0;
      striker.vy = 0;
    }
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

  int remainingOf(DiscType type) => _countOnBoard(type);

  void _advanceTurn() {
    final piecesPerPlayer = activePlayers.length == 2 ? 9 : 4;
    int idx = activePlayers.indexOf(currentPlayer);
    do {
      idx = (idx + 1) % activePlayers.length;
      currentPlayer = activePlayers[idx];
    } while ((pocketedCount[currentPlayer] ?? 0) >= piecesPerPlayer);

    phase = TurnPhase.placeStriker;
  }

  bool get isAITurn {
    final seat = seats[currentPlayer];
    return seat?.isAI ?? false;
  }

  CarromDifficulty get currentDifficulty =>
      seats[currentPlayer]?.difficulty ?? CarromDifficulty.medium;

  // ----------------------------------------------------------- AI

  (double aimDx, double aimDy, double power)? chooseAIMove() {
    final striker = _striker;
    if (striker == null || striker.pocketed) return null;

    final targetType = playerDisc(currentPlayer);
    final targets = discs
        .where((d) => !d.pocketed && d.type == targetType)
        .toList();

    if (targets.isEmpty) return _randomShot();

    double bestScore = -1;
    double bestAimX = 0, bestAimY = 0, bestPower = 0.8;

    for (final target in targets) {
      for (final (px, py) in pockets) {
        final score = _evaluateAim(striker, target, px, py);
        if (score > bestScore) {
          bestScore = score;

          final tx = target.x - striker.x;
          final ty = target.y - striker.y;
          final tDist = sqrt(tx * tx + ty * ty);

          final tpDx = px - target.x;
          final tpDy = py - target.y;
          final tpDist = sqrt(tpDx * tpDx + tpDy * tpDy);

          if (tDist > 0 && tpDist > 0) {
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

    final diff = currentDifficulty;
    final errorAngle = _difficultyErrorAngle(diff);
    final cosE = cos(errorAngle);
    final sinE = sin(errorAngle);
    final ax = bestAimX * cosE - bestAimY * sinE;
    final ay = bestAimX * sinE + bestAimY * cosE;

    final powerVariance = _difficultyPowerVariance(diff);
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

    final cosAngle = (tx * tpDx + ty * tpDy) / (tDist * tpDist);
    final cutAngle = acos(cosAngle.clamp(-1, 1));
    final directness = (pi - cutAngle).abs() / pi;
    final distanceScore = 1.0 - (tDist / 300).clamp(0, 1);

    return directness * 60 + distanceScore * 40;
  }

  (double, double, double) _randomShot() {
    final angle = _rng.nextDouble() * 2 * pi;
    final power = 0.5 + _rng.nextDouble() * 0.4;
    return (cos(angle), sin(angle), power);
  }

  double _difficultyErrorAngle(CarromDifficulty diff) {
    final base = switch (diff) {
      CarromDifficulty.easy => 15.0,
      CarromDifficulty.medium => 8.0,
      CarromDifficulty.hard => 3.0,
    };
    return (_rng.nextDouble() * 2 - 1) * base * pi / 180;
  }

  double _difficultyPowerVariance(CarromDifficulty diff) {
    final (min, max) = switch (diff) {
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

      if (px - strikerRadius < 0 || px + strikerRadius > boardSize) {
        dx = -dx;
        px = px.clamp(strikerRadius, boardSize - strikerRadius);
      }
      if (py - strikerRadius < 0 || py + strikerRadius > boardSize) {
        dy = -dy;
        py = py.clamp(strikerRadius, boardSize - strikerRadius);
      }

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
