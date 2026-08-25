import 'dart:math';

enum LudoColor { red, green, yellow, blue }

enum LudoPhase { awaitRoll, awaitMove, gameOver }

/// Grid cell on the 15x15 board (c = column 0..14, r = row 0..14).
class LudoCell {
  final int c;
  final int r;

  const LudoCell(this.c, this.r);

  @override
  bool operator ==(Object other) =>
      other is LudoCell && other.c == c && other.r == r;

  @override
  int get hashCode => Object.hash(c, r);
}

class LudoToken {
  final LudoColor color;
  final int index;
  int progress; // -1 yard | 0..50 main track | 51..55 home column | 56 home

  LudoToken({required this.color, required this.index}) : progress = -1;

  bool get inYard => progress == -1;
  bool get isHome => progress == 56;
  bool get onMainTrack => progress >= 0 && progress <= 50;
}

class LudoPlayer {
  final LudoColor color;
  final bool isAI;
  final List<LudoToken> tokens;
  bool finished = false;

  LudoPlayer({required this.color, required this.isAI})
    : tokens = List.generate(4, (i) => LudoToken(color: color, index: i));

  int get tokensHome => tokens.where((t) => t.isHome).length;

  int get totalProgress => tokens.fold(0, (sum, t) => sum + max(0, t.progress));
}

class MoveOutcome {
  final int captured;
  final bool finishedToken;
  final bool extraRoll;

  const MoveOutcome({
    required this.captured,
    required this.finishedToken,
    required this.extraRoll,
  });
}

class LudoGame {
  static const List<LudoColor> seatOrder = [
    LudoColor.red,
    LudoColor.green,
    LudoColor.yellow,
    LudoColor.blue,
  ];

  static const int startOffsetRed = 0;
  static const int startOffsetGreen = 13;
  static const int startOffsetYellow = 26;
  static const int startOffsetBlue = 39;

  /// Absolute track indices that are safe (start cells + star cells).
  static const Set<int> safeTrackIndices = {0, 8, 13, 21, 26, 34, 39, 47};

  static const int homeProgress = 56;
  static const int _mainTrackLength = 52;

  final Random _rng = Random();

  late List<LudoPlayer> players;
  int currentSeat = 0;
  LudoPhase phase = LudoPhase.awaitRoll;

  int diceValue = 0;
  int sixStreak = 0;

  LudoGame({required int seatCount, List<bool>? seatIsAI}) {
    assert(seatCount >= 2 && seatCount <= 4);
    players = [];
    for (int i = 0; i < seatCount; i++) {
      players.add(
        LudoPlayer(
          color: seatOrder[i],
          isAI: seatIsAI != null ? seatIsAI[i] : i != 0,
        ),
      );
    }
  }

  // ---------------------------------------------------------------- geometry

  static final List<LudoCell> mainTrack = _buildTrack();

  static List<LudoCell> _buildTrack() {
    const t = <List<int>>[
      [1, 6], [2, 6], [3, 6], [4, 6], [5, 6], // 0-4   red lane
      [6, 5], [6, 4], [6, 3], [6, 2], [6, 1], [6, 0], // 5-10  up left-top lane
      [7, 0], // 11    top tip
      [8, 0], [8, 1], [8, 2], [8, 3], [8, 4], [8, 5], // 12-17 down right-top
      [9, 6], [10, 6], [11, 6], [12, 6], [13, 6], [14, 6], // 18-23 green lane
      [14, 7], // 24    right tip
      [14, 8], [13, 8], [12, 8], [11, 8], [10, 8], [9, 8], // 25-30 yellow lane
      [8, 9],
      [8, 10],
      [8, 11],
      [8, 12],
      [8, 13],
      [8, 14], // 31-36 down right-bottom
      [7, 14], // 37    bottom tip
      [6, 14],
      [6, 13],
      [6, 12],
      [6, 11],
      [6, 10],
      [6, 9], // 38-43 up left-bottom
      [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8], // 44-49 blue lane
      [0, 7], // 50    left tip
      [0, 6], // 51    wraps to index 0
    ];
    return [for (final e in t) LudoCell(e[0], e[1])];
  }

  static int _startOffset(LudoColor color) {
    switch (color) {
      case LudoColor.red:
        return startOffsetRed;
      case LudoColor.green:
        return startOffsetGreen;
      case LudoColor.yellow:
        return startOffsetYellow;
      case LudoColor.blue:
        return startOffsetBlue;
    }
  }

  static List<LudoCell> homeColumn(LudoColor color) {
    switch (color) {
      case LudoColor.red:
        return const [
          LudoCell(1, 7),
          LudoCell(2, 7),
          LudoCell(3, 7),
          LudoCell(4, 7),
          LudoCell(5, 7),
        ];
      case LudoColor.green:
        return const [
          LudoCell(7, 1),
          LudoCell(7, 2),
          LudoCell(7, 3),
          LudoCell(7, 4),
          LudoCell(7, 5),
        ];
      case LudoColor.yellow:
        return const [
          LudoCell(13, 7),
          LudoCell(12, 7),
          LudoCell(11, 7),
          LudoCell(10, 7),
          LudoCell(9, 7),
        ];
      case LudoColor.blue:
        return const [
          LudoCell(7, 13),
          LudoCell(7, 12),
          LudoCell(7, 11),
          LudoCell(7, 10),
          LudoCell(7, 9),
        ];
    }
  }

  /// Board cell for a token at [progress] of [color]; null when in yard/home.
  static LudoCell? cellFor(LudoColor color, int progress) {
    if (progress < 0 || progress >= 51) return null;
    final abs = (_startOffset(color) + progress) % _mainTrackLength;
    return mainTrack[abs];
  }

  /// Absolute main-track index for [color] at [progress] (0..50), else null.
  static int? absIndexFor(LudoColor color, int progress) {
    if (progress < 0 || progress > 50) return null;
    return (_startOffset(color) + progress) % _mainTrackLength;
  }

  LudoPlayer get currentPlayer => players[currentSeat];
  LudoColor get currentColor => currentPlayer.color;
  bool get isAITurn => currentPlayer.isAI;
  bool get isGameOver => phase == LudoPhase.gameOver;
  bool get forfeitsByTripleSix => diceValue == 6 && sixStreak >= 3;
  bool get isLocalMultiplayer => players.where((p) => !p.isAI).length > 1;

  // ------------------------------------------------------------------- rules

  void rollDice() {
    if (phase != LudoPhase.awaitRoll) return;
    diceValue = _rng.nextInt(6) + 1;
    if (diceValue == 6) {
      sixStreak++;
    } else {
      sixStreak = 0;
    }
    phase = LudoPhase.awaitMove;
  }

  bool canMove(LudoToken token) {
    if (phase != LudoPhase.awaitMove || forfeitsByTripleSix) return false;
    if (token.color != currentColor) return false;
    if (token.inYard) return diceValue == 6;
    return token.progress + diceValue <= homeProgress;
  }

  List<LudoToken> movableTokens() =>
      currentPlayer.tokens.where(canMove).toList();

  /// Advance to next active player. Call after a forfeit or a no-move roll.
  void passTurn() {
    if (phase == LudoPhase.gameOver) return;
    sixStreak = 0;
    do {
      currentSeat = (currentSeat + 1) % players.length;
    } while (players[currentSeat].finished);
    phase = LudoPhase.awaitRoll;
  }

  /// Rolled a 6 with no legal move — keep the turn, re-roll.
  void repeatRoll() {
    if (phase == LudoPhase.gameOver) return;
    phase = LudoPhase.awaitRoll;
  }

  MoveOutcome applyMove(LudoToken token) {
    assert(canMove(token));
    var captured = 0;
    final finishedToken = token.progress + diceValue == homeProgress;

    if (token.inYard) {
      token.progress = 0;
    } else {
      token.progress += diceValue;
    }

    // Captures only apply on the shared main track, never on safe cells.
    final destAbs = absIndexFor(token.color, token.progress);
    if (destAbs != null && !safeTrackIndices.contains(destAbs)) {
      for (final player in players) {
        if (player.color == token.color) continue;
        for (final enemy in player.tokens) {
          if (!enemy.onMainTrack) continue;
          if (absIndexFor(enemy.color, enemy.progress) == destAbs) {
            enemy.progress = -1;
            captured++;
          }
        }
      }
    }

    var extraRoll = diceValue == 6 || captured > 0 || finishedToken;

    if (finishedToken && currentPlayer.tokensHome == 4) {
      currentPlayer.finished = true;
      extraRoll = false;
      _finishGame();
    }

    if (extraRoll && !isGameOver) {
      phase = LudoPhase.awaitRoll;
      if (diceValue != 6) sixStreak = 0;
    } else if (!isGameOver) {
      passTurn();
    }
    return MoveOutcome(
      captured: captured,
      finishedToken: finishedToken,
      extraRoll: extraRoll,
    );
  }

  void _finishGame() {
    for (final p in players) {
      if (!p.finished && p.tokensHome == 4) p.finished = true;
    }
    phase = LudoPhase.gameOver;
  }

  List<LudoPlayer> get standings {
    final sorted = List.of(players)
      ..sort((a, b) {
        if (a.finished != b.finished) return a.finished ? -1 : 1;
        if (a.tokensHome != b.tokensHome) {
          return b.tokensHome - a.tokensHome;
        }
        return b.totalProgress - a.totalProgress;
      });
    return sorted;
  }

  // --------------------------------------------------------------------- AI

  LudoToken? chooseAIMove() {
    final options = movableTokens();
    if (options.isEmpty) return null;

    LudoToken? best;
    var bestScore = -1.0;
    for (final token in options) {
      final score = _scoreMove(token) + _rng.nextDouble();
      if (score > bestScore) {
        bestScore = score;
        best = token;
      }
    }
    return best;
  }

  double _scoreMove(LudoToken token) {
    if (token.inYard) return 90;

    final newProgress = token.progress + diceValue;
    var score = newProgress * 0.3;

    if (newProgress == homeProgress) score += 100;
    if (_isThreatened(token)) score += 40;

    final destAbs = absIndexFor(token.color, newProgress);
    if (destAbs != null) {
      if (safeTrackIndices.contains(destAbs)) {
        score += 25;
      } else {
        for (final player in players) {
          if (player.color == token.color) continue;
          for (final enemy in player.tokens) {
            if (!enemy.onMainTrack) continue;
            if (absIndexFor(enemy.color, enemy.progress) == destAbs) {
              score += 80;
            }
          }
        }
      }
    }
    return score;
  }

  bool _isThreatened(LudoToken token) {
    if (!token.onMainTrack) return false;
    final myAbs = absIndexFor(token.color, token.progress)!;
    if (safeTrackIndices.contains(myAbs)) return false;
    for (final player in players) {
      if (player.color == token.color) continue;
      for (final enemy in player.tokens) {
        if (!enemy.onMainTrack) continue;
        final enemyAbs = absIndexFor(enemy.color, enemy.progress)!;
        if (safeTrackIndices.contains(enemyAbs)) continue;
        final gap = (myAbs - enemyAbs) % _mainTrackLength;
        if (gap >= 1 && gap <= 6) return true;
      }
    }
    return false;
  }
}
