import 'dart:math';

enum RacerDifficulty { easy, medium, hard }

enum RacerGameState { idle, playing, paused, gameOver }

enum PickupType { coin, fuel, shield, nitro }

class TrafficCar {
  double x;
  double y;
  final double upFactor;
  final double width;
  final double height;
  final int colorIndex;

  TrafficCar({
    required this.x,
    required this.y,
    required this.upFactor,
    this.width = 0.13,
    this.height = 0.17,
    required this.colorIndex,
  });
}

class Pickup {
  double x;
  double y;
  final PickupType type;
  final double size;

  Pickup({
    required this.x,
    required this.y,
    required this.type,
    this.size = 0.075,
  });
}

class RacerGame {
  RacerGameState state = RacerGameState.idle;
  RacerDifficulty difficulty;

  double playerX = 0.5;
  double _playerTargetX = 0.5;
  int heldDirection = 0;

  List<TrafficCar> traffic = [];
  List<Pickup> pickups = [];

  double fuel = 100;
  int coinsCollected = 0;
  double meters = 0;
  int score = 0;
  int highScore = 0;
  double roadOffset = 0;
  double elapsed = 0;

  bool hasShield = false;
  double nitroTimeLeft = 0;
  double invulnTimeLeft = 0;

  String gameOverReason = '';

  double _trafficTimer = 0;
  double _coinTimer = 0;
  double _fuelTimer = 0;
  double _powerupTimer = 6;

  final Random _random = Random();

  static const double playerWidth = 0.13;
  static const double playerHeight = 0.17;
  static const double laneWidth = 0.25;
  static const double nitroMultiplier = 1.6;
  static const double nitroDuration = 4.0;
  static const double shieldGraceTime = 1.2;
  static const int fuelRestoreAmount = 35;
  static const int coinScoreValue = 25;

  RacerGame({this.difficulty = RacerDifficulty.medium});

  double get baseRoadSpeed {
    switch (difficulty) {
      case RacerDifficulty.easy:
        return 0.42;
      case RacerDifficulty.medium:
        return 0.58;
      case RacerDifficulty.hard:
        return 0.74;
    }
  }

  double get fuelDrainPerSecond {
    switch (difficulty) {
      case RacerDifficulty.easy:
        return 2.5;
      case RacerDifficulty.medium:
        return 3.4;
      case RacerDifficulty.hard:
        return 4.6;
    }
  }

  double get trafficBaseInterval {
    switch (difficulty) {
      case RacerDifficulty.easy:
        return 1.5;
      case RacerDifficulty.medium:
        return 1.05;
      case RacerDifficulty.hard:
        return 0.78;
    }
  }

  static const double maxLateralSpeed = 1.15;
  static const double rampRate = 0.016;
  static const double rampCap = 2.0;

  bool get nitroActive => nitroTimeLeft > 0;
  bool get invulnerable => nitroActive || invulnTimeLeft > 0;

  double get speedMultiplier => min(rampCap, 1.0 + rampRate * elapsed);

  double get currentRoadSpeed =>
      baseRoadSpeed * speedMultiplier * (nitroActive ? nitroMultiplier : 1.0);

  void reset() {
    playerX = 0.5;
    _playerTargetX = 0.5;
    heldDirection = 0;
    traffic.clear();
    pickups.clear();
    fuel = 100;
    coinsCollected = 0;
    meters = 0;
    score = 0;
    roadOffset = 0;
    elapsed = 0;
    hasShield = false;
    nitroTimeLeft = 0;
    invulnTimeLeft = 0;
    gameOverReason = '';
    _trafficTimer = 0.8;
    _coinTimer = 1.6;
    _fuelTimer = 4;
    _powerupTimer = 7;
    state = RacerGameState.idle;
  }

  void start() {
    if (state == RacerGameState.gameOver || state == RacerGameState.idle) {
      if (state == RacerGameState.gameOver) reset();
      state = RacerGameState.playing;
    } else if (state == RacerGameState.paused) {
      state = RacerGameState.playing;
    }
  }

  void pause() {
    if (state == RacerGameState.playing) state = RacerGameState.paused;
  }

  void setPlayerTargetX(double x) {
    if (state != RacerGameState.playing) return;
    _playerTargetX = x.clamp(0.0, 1.0);
  }

  /// -1 steer left, +1 steer right, 0 release. Held while button pressed.
  void setHeldDirection(int dir) {
    if (state != RacerGameState.playing) return;
    heldDirection = dir.clamp(-1, 1);
  }

  bool update(double dt) {
    if (state != RacerGameState.playing) return false;
    dt = dt.clamp(0.0, 0.05);

    elapsed += dt;
    final speed = currentRoadSpeed;
    roadOffset += speed * dt;
    meters += speed * dt * 100;

    if (heldDirection != 0) {
      _playerTargetX += heldDirection * maxLateralSpeed * dt;
    }

    final halfW = playerWidth / 2 + 0.01;
    _playerTargetX = _playerTargetX.clamp(halfW, 1.0 - halfW);

    final maxDx = maxLateralSpeed * dt;
    final dx = (_playerTargetX - playerX).clamp(-maxDx, maxDx);
    playerX = (playerX + dx).clamp(halfW, 1.0 - halfW);

    fuel -= fuelDrainPerSecond * dt * (nitroActive ? 1.2 : 1.0);
    if (nitroTimeLeft > 0) nitroTimeLeft -= dt;
    if (invulnTimeLeft > 0) invulnTimeLeft -= dt;

    if (fuel <= 0) {
      fuel = 0;
      _gameOver('Out of fuel!');
      return true;
    }

    _updateSpawns(dt);
    _updateTraffic(speed, dt);
    _updatePickups(speed, dt);

    score = meters.toInt() + coinsCollected * coinScoreValue;
    if (score > highScore) highScore = score;

    return true;
  }

  void _updateSpawns(double dt) {
    _trafficTimer -= dt;
    if (_trafficTimer <= 0) {
      _trafficTimer = trafficBaseInterval * (0.7 + _random.nextDouble() * 0.6);
      _spawnTraffic();
    }

    _coinTimer -= dt;
    if (_coinTimer <= 0) {
      _coinTimer = 2.2 + _random.nextDouble() * 1.4;
      _spawnCoinCluster();
    }

    _fuelTimer -= dt;
    if (_fuelTimer <= 0) {
      _fuelTimer = 3.5;
      if (fuel < 60 &&
          !pickups.any((p) => p.type == PickupType.fuel) &&
          _random.nextDouble() < 0.75) {
        pickups.add(
          Pickup(
            x: _laneCenter(_random.nextInt(4)),
            y: -0.08,
            type: PickupType.fuel,
            size: 0.09,
          ),
        );
      }
    }

    _powerupTimer -= dt;
    if (_powerupTimer <= 0) {
      _powerupTimer = 12 + _random.nextDouble() * 6;
      final alreadyOnScreen = pickups.any(
        (p) => p.type == PickupType.shield || p.type == PickupType.nitro,
      );
      if (!alreadyOnScreen && !hasShield) {
        final type = _random.nextBool() ? PickupType.shield : PickupType.nitro;
        if (!(type == PickupType.nitro && nitroActive)) {
          pickups.add(
            Pickup(
              x: _laneCenter(_random.nextInt(4)),
              y: -0.08,
              type: type,
              size: 0.095,
            ),
          );
        }
      }
    }
  }

  void _spawnTraffic() {
    final topBandCars = traffic.where((c) => c.y < 0.14).toList();
    final occupiedLanes = topBandCars
        .map((c) => (c.x / laneWidth).round().clamp(0, 3))
        .toSet();
    if (occupiedLanes.length >= 3) return;

    int lane = _random.nextInt(4);
    int attempts = 0;
    while (occupiedLanes.contains(lane) && attempts++ < 8) {
      lane = _random.nextInt(4);
    }
    if (occupiedLanes.contains(lane)) return;

    traffic.add(
      TrafficCar(
        x: _laneCenter(lane) + (_random.nextDouble() - 0.5) * 0.06,
        y: -0.12,
        upFactor: 0.35 + _random.nextDouble() * 0.3,
        colorIndex: _random.nextInt(6),
      ),
    );
  }

  void _spawnCoinCluster() {
    final lane = _random.nextInt(4);
    for (int i = 0; i < 3; i++) {
      pickups.add(
        Pickup(
          x: _laneCenter(lane),
          y: -0.08 - i * 0.11,
          type: PickupType.coin,
        ),
      );
    }
  }

  double _laneCenter(int lane) => laneWidth * lane + laneWidth / 2;

  void _updateTraffic(double speed, double dt) {
    for (final car in traffic) {
      car.y += speed * (1.0 - car.upFactor) * dt;
    }
    traffic.removeWhere((c) => c.y > 1.15);
  }

  void _updatePickups(double speed, double dt) {
    for (final p in pickups) {
      p.y += speed * dt;
    }

    final pHalfW = playerWidth / 2;
    final pHalfH = playerHeight / 2;
    final px = playerX;
    const py = 0.82;

    for (final p in List.of(pickups)) {
      final radius = p.size / 2 + 0.02;
      final overlapX = (p.x - px).abs() < pHalfW + radius;
      final overlapY = (p.y - py).abs() < pHalfH + radius;
      if (!overlapX || !overlapY) continue;

      switch (p.type) {
        case PickupType.coin:
          coinsCollected++;
          break;
        case PickupType.fuel:
          fuel = min(100.0, fuel + fuelRestoreAmount);
          break;
        case PickupType.shield:
          if (hasShield) {
            meters += 50;
          } else {
            hasShield = true;
          }
          break;
        case PickupType.nitro:
          nitroTimeLeft = nitroDuration;
          break;
      }
      pickups.remove(p);
    }
    pickups.removeWhere((p) => p.y > 1.15);

    for (final car in List.of(traffic)) {
      final insetW = car.width * 0.44;
      final insetH = car.height * 0.44;
      if ((car.x - px).abs() < pHalfW + insetW &&
          (car.y - py).abs() < pHalfH + insetH) {
        if (invulnerable) {
          traffic.remove(car);
          meters += 15;
          continue;
        }
        if (hasShield) {
          hasShield = false;
          invulnTimeLeft = shieldGraceTime;
          traffic.remove(car);
          continue;
        }
        _gameOver('You crashed!');
        return;
      }
    }
  }

  void _gameOver(String reason) {
    gameOverReason = reason;
    state = RacerGameState.gameOver;
    heldDirection = 0;
    if (score > highScore) highScore = score;
  }
}
