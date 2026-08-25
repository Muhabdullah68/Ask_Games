enum DiscType { striker, white, black, queen }

enum CarromPlayer { one, two }

enum TurnPhase {
  placeStriker,
  aiming,
  shooting,
  simulating,
  evaluating,
  gameOver,
}

enum CarromDifficulty { easy, medium, hard }

enum CarromGameMode { vsAI, local }

class CarromDisc {
  double x;
  double y;
  double vx;
  double vy;
  final double radius;
  final DiscType type;
  bool pocketed;

  CarromDisc({
    required this.x,
    required this.y,
    required this.type,
    this.radius = 9,
    this.vx = 0,
    this.vy = 0,
    this.pocketed = false,
  });

  bool get isMoving => vx.abs() > 0.01 || vy.abs() > 0.01;

  CarromDisc copy() => CarromDisc(
    x: x,
    y: y,
    vx: vx,
    vy: vy,
    radius: radius,
    type: type,
    pocketed: pocketed,
  );
}

class ShotResult {
  final int whitesPocketed;
  final int blacksPocketed;
  final bool queenPocketed;
  final bool strikerPocketed;
  final bool turnContinues;
  final bool queenCovered;
  final bool gameOver;
  final CarromPlayer? winner;

  const ShotResult({
    required this.whitesPocketed,
    required this.blacksPocketed,
    required this.queenPocketed,
    required this.strikerPocketed,
    required this.turnContinues,
    required this.queenCovered,
    required this.gameOver,
    this.winner,
  });
}
