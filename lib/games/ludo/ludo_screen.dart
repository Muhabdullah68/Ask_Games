import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'ludo_engine.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> with TickerProviderStateMixin {
  LudoGame? _game;
  bool _setupOpen = true;
  int _seatCount = 2;

  Timer? _aiTimer;
  Timer? _stepTimer;
  late final AnimationController _diceController;
  late final AnimationController _pulseController;
  late final AnimationController _winOverlayController;

  String _statusText = 'Choose players to begin';
  List<LudoToken> _movable = [];
  final Map<String, int> _displayProgress = {};
  int _diceFace = 1;
  bool _rolling = false;

  static const Color _red = Color(0xFFEF4444);
  static const Color _green = Color(0xFF22C55E);
  static const Color _yellow = Color(0xFFEAB308);
  static const Color _blue = Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _winOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _stepTimer?.cancel();
    _diceController.dispose();
    _pulseController.dispose();
    _winOverlayController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- game flow

  void _startGame(int seats) {
    _aiTimer?.cancel();
    _stepTimer?.cancel();
    setState(() {
      _game = LudoGame(seatCount: seats);
      _seatCount = seats;
      _setupOpen = false;
      _movable = [];
      _displayProgress.clear();
      for (final p in _game!.players) {
        for (final t in p.tokens) {
          _displayProgress[_key(t)] = t.progress;
        }
      }
      _statusText = 'You are 🔴 Red — roll the dice!';
    });
  }

  String _key(LudoToken t) => '${t.color.name}_${t.index}';

  Color _colorOf(LudoColor c) {
    switch (c) {
      case LudoColor.red:
        return _red;
      case LudoColor.green:
        return _green;
      case LudoColor.yellow:
        return _yellow;
      case LudoColor.blue:
        return _blue;
    }
  }

  String _emojiOf(LudoColor c) {
    switch (c) {
      case LudoColor.red:
        return '🔴';
      case LudoColor.green:
        return '🟢';
      case LudoColor.yellow:
        return '🟡';
      case LudoColor.blue:
        return '🔵';
    }
  }

  void _tapDice() {
    if (_game == null || _rolling || _game!.isGameOver) return;
    if (_game!.phase != LudoPhase.awaitRoll || _game!.isAITurn) return;
    _doRoll();
  }

  void _doRoll() {
    final game = _game!;
    setState(() {
      _rolling = true;
      _movable = [];
      _statusText = 'Rolling…';
    });
    _diceController.forward(from: 0);
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 620), () {
      if (!mounted) return;
      setState(() {
        game.rollDice();
        _diceFace = game.diceValue;
        _rolling = false;
      });
      _afterRoll();
    });
  }

  void _afterRoll() {
    final game = _game!;
    if (game.isGameOver) return;

    if (game.forfeitsByTripleSix) {
      setState(() => _statusText = 'Three sixes in a row — turn lost!');
      game.passTurn();
      _scheduleAIIfNeeded();
      return;
    }

    final movable = game.movableTokens();
    if (movable.isEmpty) {
      if (game.diceValue == 6) {
        game.repeatRoll();
        setState(
          () => _statusText = 'No possible move — rolled a 6, roll again!',
        );
      } else {
        setState(() => _statusText = 'No possible move.');
        game.passTurn();
      }
      _scheduleAIIfNeeded();
      return;
    }

    if (game.isAITurn) {
      setState(() => _statusText = '$_statusPrefix AI rolled $_diceFace');
      _aiTimer?.cancel();
      _aiTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted || _game == null || _game!.isGameOver) return;
        final choice = _game!.chooseAIMove();
        if (choice != null) _moveToken(choice);
      });
    } else {
      setState(() {
        _movable = movable;
        _statusText = '$_statusPrefix You rolled $_diceFace — pick a token';
      });
    }
  }

  String get _statusPrefix =>
      _game!.isAITurn ? _emojiOf(_game!.currentColor) : '';

  void _moveToken(LudoToken token) {
    final game = _game!;
    if (!game.canMove(token)) return;
    setState(() => _movable = []);

    final from = token.progress;
    final target = from == -1 ? 0 : from + game.diceValue;
    final key = _key(token);

    if (from == -1) {
      _finishMove(token, target);
      return;
    }

    var cur = from;
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      cur++;
      setState(() => _displayProgress[key] = cur);
      if (cur >= target) {
        _stepTimer?.cancel();
        _finishMove(token, target);
      }
    });
  }

  void _finishMove(LudoToken token, int newProgress) {
    final game = _game!;
    setState(() => _displayProgress[_key(token)] = newProgress);

    final outcome = game.applyMove(token);

    // Sync all display progress with engine truth (captures snap home).
    setState(() {
      for (final p in game.players) {
        for (final t in p.tokens) {
          _displayProgress[_key(t)] = t.progress;
        }
      }
    });

    String msg;
    if (outcome.finishedToken && game.isGameOver) {
      msg = '🏁 All four home — game over!';
    } else if (outcome.finishedToken) {
      msg = 'Token reached home! Roll again 🎲';
    } else if (outcome.captured > 0) {
      msg = '💥 Captured ${outcome.captured}! Extra roll';
    } else if (outcome.extraRoll) {
      msg = 'Rolled a 6 — extra turn!';
    } else {
      msg = '';
    }
    if (msg.isNotEmpty) setState(() => _statusText = msg);

    if (game.isGameOver) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _winOverlayController.forward();
      });
      return;
    }

    if (outcome.extraRoll) {
      _scheduleAIIfNeeded(userTurnMsg: 'Extra turn — roll again!');
      return;
    }
    _scheduleAIIfNeeded();
  }

  void _scheduleAIIfNeeded({String? userTurnMsg}) {
    final game = _game;
    if (game == null || game.isGameOver || !mounted) return;
    if (!game.isAITurn) {
      if (userTurnMsg != null) setState(() => _statusText = userTurnMsg);
      return;
    }
    setState(
      () => _statusText = '${_emojiOf(game.currentColor)} AI is thinking…',
    );
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _game == null || _game!.isGameOver) return;
      if (_game!.phase == LudoPhase.awaitRoll) _doRoll();
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final showOverlay = _game != null && _game!.isGameOver && !_setupOpen;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      const AppBackButton(),
                      const Spacer(),
                      Text(
                        'Ludo King',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: _setupOpen || _game == null
                      ? _buildSetup()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            children: [
                              _buildPlayerChips(),
                              const SizedBox(height: 10),
                              _buildStatusBar(),
                              const SizedBox(height: 12),
                              _buildBoard(),
                              const SizedBox(height: 14),
                              _buildBottomBar(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            if (showOverlay) _buildWinOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildWinOverlay() {
    final standings = _game!.standings;
    final medals = ['🥇', '🥈', '🥉', '4️⃣'];
    return Positioned.fill(
      child: FadeTransition(
        opacity: _winOverlayController,
        child: Container(
          color: Colors.black.withValues(alpha: 0.78),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(28),
              padding: const EdgeInsets.all(26),
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder, width: 0.7),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏆', style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 10),
                  Text(
                    '${_emojiOf(standings.first.color)} ${standings.first.isAI ? "AI wins!" : "You win!"}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...List.generate(standings.length, (i) {
                    final p = standings[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _colorOf(p.color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _colorOf(p.color).withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(medals[i], style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.isAI
                                  ? 'AI ${_emojiOf(p.color)}'
                                  : 'You ${_emojiOf(p.color)}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${p.tokensHome}/4 home',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  GradientButton(
                    text: 'Play Again',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      _winOverlayController.reverse();
                      setState(() {
                        _setupOpen = true;
                        _game = null;
                        _statusText = 'Choose players to begin';
                      });
                    },
                    height: 52,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetup() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder, width: 0.7),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎲', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 14),
            Text(
              'Ludo King',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'How many players?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [2, 3, 4].map((n) {
                final selected = _seatCount == n;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _seatCount = n),
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        gradient: selected ? AppColors.buttonGradient : null,
                        color: selected ? null : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.cardBorder,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$n',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'AI ×${n - 1}',
                            style: TextStyle(
                              fontSize: 10,
                              color: selected
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            Text(
              'You play 🔴 Red · others are AI',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            GradientButton(
              text: 'Start Game',
              icon: Icons.play_arrow_rounded,
              onPressed: () => _startGame(_seatCount),
              height: 52,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerChips() {
    final game = _game!;
    return Row(
      children: List.generate(game.players.length * 2 - 1, (i) {
        if (i.isOdd) return const Spacer();
        final p = game.players[i ~/ 2];
        final active = game.currentColor == p.color && !game.isGameOver;
        final color = _colorOf(p.color);
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.18) : AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? color : AppColors.cardBorder,
                width: active ? 1.4 : 0.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 6, backgroundColor: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          p.isAI ? 'AI' : 'You',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '🏠 ${p.tokensHome}/4',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          if (_rolling)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.casino_rounded, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final cell = side / 15;
        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              CustomPaint(
                size: Size.square(side),
                painter: _LudoBoardPainter(),
              ),
              ..._buildTokens(side, cell),
              if (_setupOpen) const SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }

  Offset _tokenOffset(LudoToken t, int displayedProgress, double cell) {
    if (displayedProgress < 0) {
      // Yard slot
      const slots = [
        Offset(1.5, 1.5),
        Offset(3.5, 1.5),
        Offset(1.5, 3.5),
        Offset(3.5, 3.5),
      ];
      final yardOrigin = _yardOrigin(t.color);
      return Offset(
        (yardOrigin.$1 + slots[t.index].dx) * cell,
        (yardOrigin.$2 + slots[t.index].dy) * cell,
      );
    }
    if (displayedProgress == 56) {
      return _homeCenter(t.color, cell);
    }
    if (displayedProgress >= 51) {
      final col = LudoGame.homeColumn(
        t.color,
      )[math.min(displayedProgress, 55) - 51];
      return Offset((col.c + 0.5) * cell, (col.r + 0.5) * cell);
    }
    final cellPos = LudoGame.cellFor(t.color, math.min(displayedProgress, 50))!;
    return Offset((cellPos.c + 0.5) * cell, (cellPos.r + 0.5) * cell);
  }

  (int, int) _yardOrigin(LudoColor c) {
    switch (c) {
      case LudoColor.red:
        return (0, 0);
      case LudoColor.green:
        return (9, 0);
      case LudoColor.yellow:
        return (9, 9);
      case LudoColor.blue:
        return (0, 9);
    }
  }

  Offset _homeCenter(LudoColor c, double cell) {
    switch (c) {
      case LudoColor.red:
        return Offset(6.5 * cell, 7.5 * cell);
      case LudoColor.green:
        return Offset(7.5 * cell, 6.5 * cell);
      case LudoColor.yellow:
        return Offset(8.5 * cell, 7.5 * cell);
      case LudoColor.blue:
        return Offset(7.5 * cell, 8.5 * cell);
    }
  }

  /// Group tokens that share the same displayed cell so they stack neatly.
  List<Widget> _buildTokens(double side, double cell) {
    final widgets = <Widget>[];
    final buckets = <String, List<MapEntry<Offset, (LudoToken, int)>>>{};

    for (final p in _game!.players) {
      for (final t in p.tokens) {
        final shown = _displayProgress[_key(t)] ?? t.progress;
        final offset = _tokenOffset(t, shown, cell);
        final bucketKey =
            '${(offset.dx / cell).round()}:${(offset.dy / cell).round()}';
        buckets
            .putIfAbsent(bucketKey, () => [])
            .add(MapEntry(offset, (t, shown)));
      }
    }

    buckets.forEach((_, entries) {
      for (int i = 0; i < entries.length; i++) {
        final (token, shown) = entries[i].value;
        final base = entries[i].key;
        final shift = entries.length > 1 ? i * 4.0 : 0.0;
        final canTap =
            _movable.any((m) => identical(m, token)) &&
            !_game!.isAITurn &&
            !_rolling;
        widgets.add(
          Positioned(
            left: base.dx + shift - cell * 0.36,
            top: base.dy + shift - cell * 0.36,
            width: cell * 0.72,
            height: cell * 0.72,
            child: GestureDetector(
              onTap: canTap ? () => _moveToken(token) : null,
              child: _pawn(token, cell * 0.72, highlighted: canTap),
            ),
          ),
        );
      }
    });
    return widgets;
  }

  Widget _pawn(LudoToken t, double size, {required bool highlighted}) {
    final color = _colorOf(t.color);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, _) {
        final glow = highlighted ? 0.35 + 0.65 * _pulseController.value : 0.25;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.95), color],
              center: Alignment.topLeft,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: size * 0.06,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: size * 0.15,
                offset: Offset(size * 0.05, size * 0.08),
              ),
              if (highlighted)
                BoxShadow(
                  color: Colors.white.withValues(alpha: glow),
                  blurRadius: size * 0.5,
                ),
            ],
          ),
          child: Center(
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final humanTurn =
        !_game!.isAITurn &&
        !_game!.isGameOver &&
        _game!.phase == LudoPhase.awaitRoll &&
        !_rolling;
    return Row(
      children: [
        GestureDetector(
          onTap: _tapDice,
          child: AnimatedBuilder(
            animation: _diceController,
            builder: (_, _) {
              final face = _rolling
                  ? (1 + (_diceController.value * 6).floor() % 6)
                  : _diceFace;
              return Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: humanTurn
                      ? AppColors.buttonGradient
                      : LinearGradient(
                          colors: [
                            AppColors.surfaceLight,
                            AppColors.surfaceLight,
                          ],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder, width: 0.6),
                  boxShadow: humanTurn
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(child: _pipLayout(face)),
              );
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GradientButton(
            text: 'New Game',
            icon: Icons.refresh_rounded,
            onPressed: () => setState(() {
              _setupOpen = true;
              _game = null;
              _statusText = 'Choose players to begin';
            }),
            height: 52,
          ),
        ),
      ],
    );
  }

  Widget _pipLayout(int face) {
    final pip = SizedBox(
      width: 8,
      height: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
    Widget grid(List<int> spots) {
      return SizedBox(
        width: 30,
        height: 30,
        child: Stack(
          children: [
            for (final s in spots)
              Positioned(
                left: (s % 3) * 11.0,
                top: (s ~/ 3) * 11.0,
                child: pip,
              ),
          ],
        ),
      );
    }

    switch (face) {
      case 1:
        return grid([4]);
      case 2:
        return grid([0, 8]);
      case 3:
        return grid([0, 4, 8]);
      case 4:
        return grid([0, 2, 6, 8]);
      case 5:
        return grid([0, 2, 4, 6, 8]);
      default:
        return grid([0, 2, 3, 5, 6, 8]);
    }
  }
}

class _LudoBoardPainter extends CustomPainter {
  static const Color _red = Color(0xFFEF4444);
  static const Color _green = Color(0xFF22C55E);
  static const Color _yellow = Color(0xFFEAB308);
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _track = Color(0xFFF1F5F9);
  static const Color _line = Color(0xFFCBD5E1);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    _paintYards(canvas, cell);
    _paintCross(canvas, cell);
    _paintHomeColumns(canvas, cell);
    _paintStartCells(canvas, cell);
    _paintCellBorders(canvas, cell);
    _paintStars(canvas, cell);
    _paintCenter(canvas, cell);
  }

  RRect _rect(
    double c,
    double r,
    double cell, [
    double w = 1,
    double h = 1,
    double rad = 0,
  ]) {
    return RRect.fromRectAndRadius(
      Rect.fromLTWH(c * cell, r * cell, w * cell, h * cell),
      Radius.circular(rad * cell),
    );
  }

  void _paintYards(Canvas canvas, double cell) {
    final yards = [
      (0.0, 0.0, _red),
      (9.0, 0.0, _green),
      (9.0, 9.0, _yellow),
      (0.0, 9.0, _blue),
    ];
    for (final (x, y, color) in yards) {
      canvas.drawRRect(_rect(x, y, cell, 6, 6, 0.8), Paint()..color = color);
      canvas.drawRRect(
        _rect(x + 0.75, y + 0.75, cell, 4.5, 4.5, 0.6),
        Paint()..color = Colors.white,
      );
      // token parking slots
      for (final d in const [
        Offset(1.5, 1.5),
        Offset(3.5, 1.5),
        Offset(1.5, 3.5),
        Offset(3.5, 3.5),
      ]) {
        canvas.drawCircle(
          Offset((x + d.dx) * cell, (y + d.dy) * cell),
          cell * 0.55,
          Paint()..color = color.withValues(alpha: 0.25),
        );
        canvas.drawCircle(
          Offset((x + d.dx) * cell, (y + d.dy) * cell),
          cell * 0.55,
          Paint()
            ..color = Colors.transparent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  void _paintCross(Canvas canvas, double cell) {
    final paint = Paint()..color = _track;
    canvas.drawRRect(_rect(6, 0, cell, 3, 15), paint);
    canvas.drawRRect(_rect(0, 6, cell, 15, 3), paint);
  }

  void _paintHomeColumns(Canvas canvas, double cell) {
    void column(LudoColor c) {
      final color = switch (c) {
        LudoColor.red => _red,
        LudoColor.green => _green,
        LudoColor.yellow => _yellow,
        LudoColor.blue => _blue,
      };
      for (final cl in LudoGame.homeColumn(c)) {
        canvas.drawRect(
          Rect.fromLTWH(cl.c * cell, cl.r * cell, cell, cell),
          Paint()..color = color.withValues(alpha: 0.75),
        );
      }
    }

    column(LudoColor.red);
    column(LudoColor.green);
    column(LudoColor.yellow);
    column(LudoColor.blue);
  }

  void _paintStartCells(Canvas canvas, double cell) {
    void start(int absIndex, LudoColor c) {
      final color = switch (c) {
        LudoColor.red => _red,
        LudoColor.green => _green,
        LudoColor.yellow => _yellow,
        LudoColor.blue => _blue,
      };
      final cellPos = LudoGame.mainTrack[absIndex];
      canvas.drawRect(
        Rect.fromLTWH(cellPos.c * cell, cellPos.r * cell, cell, cell),
        Paint()..color = color.withValues(alpha: 0.85),
      );
    }

    start(LudoGame.startOffsetRed, LudoColor.red);
    start(LudoGame.startOffsetGreen, LudoColor.green);
    start(LudoGame.startOffsetYellow, LudoColor.yellow);
    start(LudoGame.startOffsetBlue, LudoColor.blue);
  }

  void _paintCellBorders(Canvas canvas, double cell) {
    final paint = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final c in LudoGame.mainTrack) {
      canvas.drawRect(Rect.fromLTWH(c.c * cell, c.r * cell, cell, cell), paint);
    }
    for (final color in LudoColor.values) {
      for (final c in LudoGame.homeColumn(color)) {
        canvas.drawRect(
          Rect.fromLTWH(c.c * cell, c.r * cell, cell, cell),
          paint,
        );
      }
    }
  }

  void _paintStars(Canvas canvas, double cell) {
    const starIndices = [8, 21, 34, 47];
    for (final idx in starIndices) {
      final c = LudoGame.mainTrack[idx];
      final center = Offset((c.c + 0.5) * cell, (c.r + 0.5) * cell);
      final tp = TextPainter(
        text: const TextSpan(
          text: '★',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 20),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintCenter(Canvas canvas, double cell) {
    final rect = Rect.fromLTWH(6 * cell, 6 * cell, 3 * cell, 3 * cell);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF334155),
    );

    final mid = rect.center;
    void tri(List<Offset> pts, Color color) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    tri([
      Offset(rect.left + 2, rect.top + 2),
      Offset(mid.dx, mid.dy),
      Offset(rect.right - 2, rect.top + 2),
    ], _green);
    tri([
      Offset(rect.right - 2, rect.top + 2),
      Offset(mid.dx, mid.dy),
      Offset(rect.right - 2, rect.bottom - 2),
    ], _yellow);
    tri([
      Offset(rect.left + 2, rect.bottom - 2),
      Offset(mid.dx, mid.dy),
      Offset(rect.right - 2, rect.bottom - 2),
    ], _blue);
    tri([
      Offset(rect.left + 2, rect.top + 2),
      Offset(mid.dx, mid.dy),
      Offset(rect.left + 2, rect.bottom - 2),
    ], _red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
