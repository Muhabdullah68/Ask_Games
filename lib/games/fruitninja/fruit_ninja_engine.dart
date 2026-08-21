import 'dart:math';
import 'dart:ui';

enum FruitType { apple, orange, watermelon, banana, coconut, bomb, timeBonus }

enum FruitGameState { idle, playing, paused, gameOver }

enum FruitDifficulty { easy, medium, hard }

class Fruit {
  final FruitType type;
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double rotationSpeed;
  bool isSliced = false;
  double sliceX = 0;
  double sliceY = 0;
  double sliceAngle = 0;
  double half1X = 0;
  double half1Y = 0;
  double half2X = 0;
  double half2Y = 0;
  double half1Vx = 0;
  double half1Vy = 0;
  double half2Vx = 0;
  double half2Vy = 0;
  double half1Rot = 0;
  double half2Rot = 0;
  double slicedLifetime = 1.0;
  bool hasPassedScreen = false;

  bool get isBomb => type == FruitType.bomb;
  bool get isTimeBonus => type == FruitType.timeBonus;
  bool get isStandardFruit =>
      type != FruitType.bomb && type != FruitType.timeBonus;

  Fruit({
    required this.type,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class SliceEffect {
  final Offset position;
  final String text;
  final Color color;
  double lifetime = 1.0;
  double initialY = 0;

  SliceEffect({required this.position, required this.text, required this.color}) {
    initialY = position.dy;
  }
}

class SwipePoint {
  final Offset point;
  double lifetime;

  SwipePoint(this.point, this.lifetime);
}

class FruitNinjaGame {
  FruitGameState state = FruitGameState.idle;
  FruitDifficulty difficulty = FruitDifficulty.medium;

  int score = 0;
  int highScore = 0;
  int bombStrikes = 0;
  double timeLeft = 60.0;
  double elapsedTime = 0.0;

  final int maxBombStrikes = 3;
  static const double _gravity = 0.0022;
  static const int _fruitScore = 10;
  static const double _bonusSeconds = 10.0;

  List<Fruit> activeFruits = [];
  List<Fruit> slicedFruits = [];
  List<SliceEffect> activeEffects = [];
  List<SwipePoint> swipeTrail = [];

  final Random _random = Random();
  String gameOverReason = "";

  void reset() {
    activeFruits.clear();
    slicedFruits.clear();
    activeEffects.clear();
    swipeTrail.clear();
    score = 0;
    bombStrikes = 0;
    timeLeft = _getTimeLimitForDifficulty();
    elapsedTime = 0.0;
    state = FruitGameState.idle;
    gameOverReason = "";
  }

  double _getTimeLimitForDifficulty() {
    switch (difficulty) {
      case FruitDifficulty.easy:
        return 90.0;
      case FruitDifficulty.medium:
        return 60.0;
      case FruitDifficulty.hard:
        return 45.0;
    }
  }

  void start() {
    reset();
    state = FruitGameState.playing;
  }

  void pause() {
    if (state == FruitGameState.playing) {
      state = FruitGameState.paused;
    }
  }

  void resume() {
    if (state == FruitGameState.paused) {
      state = FruitGameState.playing;
    }
  }

  int getSpawnInterval() {
    int baseInterval;
    switch (difficulty) {
      case FruitDifficulty.easy:
        baseInterval = 1400;
        break;
      case FruitDifficulty.medium:
        baseInterval = 1000;
        break;
      case FruitDifficulty.hard:
        baseInterval = 700;
        break;
    }
    double progressFactor = (elapsedTime / 30.0).clamp(0.0, 1.0);
    int reduction = (progressFactor * baseInterval * 0.55).round();
    return (baseInterval - reduction).clamp(250, 2000);
  }

  int getFruitsPerSpawn() {
    switch (difficulty) {
      case FruitDifficulty.easy:
        if (elapsedTime > 40) return 2;
        return 1;
      case FruitDifficulty.medium:
        if (elapsedTime > 30) return _random.nextBool() ? 2 : 1;
        if (elapsedTime > 15) return 2;
        return 1;
      case FruitDifficulty.hard:
        if (elapsedTime > 20) return _random.nextInt(2) + 2;
        if (elapsedTime > 10) return 2;
        return _random.nextBool() ? 2 : 1;
    }
  }

  double getBombChance() {
    double baseChance;
    switch (difficulty) {
      case FruitDifficulty.easy:
        baseChance = 0.06;
        break;
      case FruitDifficulty.medium:
        baseChance = 0.12;
        break;
      case FruitDifficulty.hard:
        baseChance = 0.18;
        break;
    }
    double timeFactor = (elapsedTime / 30.0 * 0.12).clamp(0.0, 0.20);
    return (baseChance + timeFactor).clamp(0.0, 0.38);
  }

  double getTimeBonusChance() {
    switch (difficulty) {
      case FruitDifficulty.easy:
        return 0.12;
      case FruitDifficulty.medium:
        return 0.07;
      case FruitDifficulty.hard:
        return 0.04;
    }
  }

  double getVelocityMultiplier() {
    double progressFactor = (elapsedTime / 40.0).clamp(0.0, 1.0);
    return 1.0 + progressFactor * 0.6;
  }

  void spawnFruit(double screenWidth, double screenHeight) {
    if (state != FruitGameState.playing) return;

    int count = getFruitsPerSpawn();
    double bombChance = getBombChance();
    double timeBonusChance = getTimeBonusChance();
    double velMul = getVelocityMultiplier();

    for (int i = 0; i < count; i++) {
      double chance = _random.nextDouble();
      FruitType type;

      if (chance < bombChance) {
        type = FruitType.bomb;
      } else if (chance < bombChance + timeBonusChance) {
        type = FruitType.timeBonus;
      } else {
        List<FruitType> standardFruits = [
          FruitType.apple,
          FruitType.orange,
          FruitType.watermelon,
          FruitType.banana,
          FruitType.coconut,
        ];
        type = standardFruits[_random.nextInt(standardFruits.length)];
      }

      double aspect = screenHeight > 0 ? screenWidth / screenHeight : 1.0;
      double x;
      if (aspect < 1.0) {
        x = 0.15 + _random.nextDouble() * 0.7;
      } else {
        x = 0.2 + _random.nextDouble() * 0.6;
      }
      double y = 1.12;

      double targetX = 0.3 + _random.nextDouble() * 0.4;
      double arcHeight = 0.55 + _random.nextDouble() * 0.28;
      double riseTime = sqrt(2 * arcHeight / _gravity);
      double vy = -_gravity * riseTime * velMul;
      double horizontalDistance = targetX - x;
      double totalFlightTime = riseTime + sqrt(2 * (arcHeight + 0.12) / _gravity);
      double vx = (horizontalDistance / totalFlightTime) * velMul;

      if (vx.abs() > 0.003) {
        vx = vx.sign * min(vx.abs(), 0.003);
      }

      activeFruits.add(Fruit(
        type: type,
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.18,
      ));
    }
  }

  void update(double dt) {
    for (int i = swipeTrail.length - 1; i >= 0; i--) {
      swipeTrail[i].lifetime -= dt * 4.5;
      if (swipeTrail[i].lifetime <= 0) {
        swipeTrail.removeAt(i);
      }
    }

    if (state != FruitGameState.playing) return;

    elapsedTime += dt;
    timeLeft -= dt;

    if (timeLeft <= 0) {
      timeLeft = 0;
      gameOverReason = "Time's Up!";
      _triggerGameOver();
      return;
    }

    for (int i = activeEffects.length - 1; i >= 0; i--) {
      activeEffects[i].lifetime -= dt * 1.6;
      if (activeEffects[i].lifetime <= 0) {
        activeEffects.removeAt(i);
      }
    }

    for (int i = slicedFruits.length - 1; i >= 0; i--) {
      Fruit f = slicedFruits[i];
      f.slicedLifetime -= dt * 1.8;
      f.half1X += f.half1Vx;
      f.half1Y += f.half1Vy;
      f.half2X += f.half2Vx;
      f.half2Y += f.half2Vy;
      f.half1Vy += _gravity;
      f.half2Vy += _gravity;
      f.half1Rot += f.rotationSpeed * 2.5;
      f.half2Rot -= f.rotationSpeed * 2.5;
      if (f.slicedLifetime <= 0) {
        slicedFruits.removeAt(i);
      }
    }

    for (int i = activeFruits.length - 1; i >= 0; i--) {
      Fruit f = activeFruits[i];
      f.x += f.vx;
      f.y += f.vy;
      f.vy += _gravity;
      f.rotation += f.rotationSpeed;

      if (f.y > 1.18 && f.vy > 0) {
        f.hasPassedScreen = true;
        activeFruits.removeAt(i);
      }
    }
  }

  void addSwipePoint(Offset p) {
    swipeTrail.add(SwipePoint(p, 1.0));
    while (swipeTrail.length > 40) {
      swipeTrail.removeAt(0);
    }
  }

  List<Fruit> checkSlice(Offset p1, Offset p2, double screenWidth, double screenHeight) {
    if (state != FruitGameState.playing) return [];
    if (screenWidth <= 0 || screenHeight <= 0) return [];

    List<Fruit> sliced = [];
    double fruitRadiusNorm = 0.058;

    for (int i = activeFruits.length - 1; i >= 0; i--) {
      Fruit f = activeFruits[i];
      if (f.isSliced) continue;

      Offset fruitPos = Offset(f.x * screenWidth, f.y * screenHeight);
      double radiusPx = fruitRadiusNorm * min(screenWidth, screenHeight);

      if (_lineIntersectsCircle(p1, p2, fruitPos, radiusPx * 1.15)) {
        f.isSliced = true;
        f.sliceX = p2.dx;
        f.sliceY = p2.dy;
        f.sliceAngle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);

        Offset delta = p2 - p1;
        double len = delta.distance;
        Offset dir = len > 0 ? delta / len : const Offset(1, 0);
        Offset perp = Offset(-dir.dy, dir.dx);
        double spread = 0.018;

        f.half1X = f.x - perp.dx * spread * 0.0;
        f.half1Y = f.y - perp.dy * spread * 0.0;
        f.half2X = f.x + perp.dx * spread * 0.0;
        f.half2Y = f.y + perp.dy * spread * 0.0;
        f.half1Vx = f.vx - perp.dx * 0.004 + dir.dx * 0.001;
        f.half1Vy = f.vy - 0.002;
        f.half2Vx = f.vx + perp.dx * 0.004 + dir.dx * 0.001;
        f.half2Vy = f.vy - 0.002;
        f.half1Rot = f.rotation;
        f.half2Rot = f.rotation;

        sliced.add(f);
        slicedFruits.add(f);
        activeFruits.removeAt(i);

        if (f.isBomb) {
          bombStrikes++;
          activeEffects.add(SliceEffect(
            position: fruitPos,
            text: bombStrikes >= maxBombStrikes
                ? "BOOM!"
                : "Strike $bombStrikes/$maxBombStrikes",
            color: const Color(0xFFF44336),
          ));
          if (bombStrikes >= maxBombStrikes) {
            gameOverReason = "Too Many Bombs!";
            _triggerGameOver();
          }
        } else if (f.isTimeBonus) {
          timeLeft += _bonusSeconds;
          activeEffects.add(SliceEffect(
            position: fruitPos,
            text: "+${_bonusSeconds.toInt()}s",
            color: const Color(0xFF06B6D4),
          ));
        } else {
          score += _fruitScore;
          if (score > highScore) {
            highScore = score;
          }
          activeEffects.add(SliceEffect(
            position: fruitPos,
            text: "+$_fruitScore",
            color: const Color(0xFF10B981),
          ));
        }
      }
    }
    return sliced;
  }

  void _triggerGameOver() {
    if (score > highScore) highScore = score;
    state = FruitGameState.gameOver;
  }

  bool _lineIntersectsCircle(Offset p1, Offset p2, Offset center, double radius) {
    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;

    double lenSq = dx * dx + dy * dy;
    if (lenSq == 0) {
      return (center - p1).distanceSquared <= radius * radius;
    }

    double t =
        ((center.dx - p1.dx) * dx + (center.dy - p1.dy) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);

    double closestX = p1.dx + t * dx;
    double closestY = p1.dy + t * dy;

    double distSq = (center.dx - closestX) * (center.dx - closestX) +
        (center.dy - closestY) * (center.dy - closestY);

    return distSq <= radius * radius;
  }
}
