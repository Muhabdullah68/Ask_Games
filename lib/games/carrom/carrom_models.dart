enum DiscType { striker, white, black, red, blue, queen }

enum CarromPlayer { one, two, three, four }

enum BoardSide { bottom, right, top, left }

enum TurnPhase {
  placeStriker,
  aiming,
  shooting,
  simulating,
  evaluating,
  gameOver,
}

enum CarromDifficulty { easy, medium, hard }

enum CarromGameMode { ai, local2, local4 }

BoardSide playerSide(CarromPlayer p) => switch (p) {
  CarromPlayer.one => BoardSide.bottom,
  CarromPlayer.two => BoardSide.right,
  CarromPlayer.three => BoardSide.top,
  CarromPlayer.four => BoardSide.left,
};

DiscType playerDisc(CarromPlayer p) => switch (p) {
  CarromPlayer.one => DiscType.white,
  CarromPlayer.two => DiscType.black,
  CarromPlayer.three => DiscType.red,
  CarromPlayer.four => DiscType.blue,
};

String playerLabel(CarromPlayer p) => switch (p) {
  CarromPlayer.one => 'Player 1',
  CarromPlayer.two => 'Player 2',
  CarromPlayer.three => 'Player 3',
  CarromPlayer.four => 'Player 4',
};

String playerEmoji(CarromPlayer p) => switch (p) {
  CarromPlayer.one => '\u26AA',
  CarromPlayer.two => '\u26AB',
  CarromPlayer.three => '\uD83D\uDD34',
  CarromPlayer.four => '\uD83D\uDD35',
};

class PlayerSeat {
  final bool isAI;
  final CarromDifficulty difficulty;
  const PlayerSeat({
    this.isAI = false,
    this.difficulty = CarromDifficulty.medium,
  });
}

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
  final bool queenPocketed;
  final bool strikerPocketed;
  final bool turnContinues;
  final bool queenCovered;
  final bool gameOver;
  final CarromPlayer? winner;
  final Map<CarromPlayer, int> pocketedByPlayer;

  const ShotResult({
    required this.queenPocketed,
    required this.strikerPocketed,
    required this.turnContinues,
    required this.queenCovered,
    required this.gameOver,
    this.winner,
    required this.pocketedByPlayer,
  });
}
