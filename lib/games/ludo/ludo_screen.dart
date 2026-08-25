import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'ludo_engine.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> with TickerProviderStateMixin {
  // ------------------------------------------------------------------ state
  LudoGame? _game;
  bool _setupOpen = true;
  int _setupMode = 0; // 0 = vs AI, 1 = local multiplayer
  int _humanCount = 2;
  int _seatCount = 2;

  Timer? _aiTimer;
  String _statusText = 'Choose a mode to begin';
  List<LudoToken> _movable = [];
  final Map<String, int> _displayProgress = {};
  int _diceFace = 1;
  bool _rolling = false;
  bool _animatingMove = false;
  bool _showHandoff = false;
  String _handoffName = '';
  LudoColor _handoffColor = LudoColor.red;

  // animation controllers
  late final AnimationController _diceController;
  late final AnimationController _pulseController;
  late final AnimationController _winOverlayController;
  late final AnimationController _moveAnimController;
  late final AnimationController _handoffController;

  // move animation tracking
  LudoToken? _movingToken;
  int _moveToProgress = 0;
  Offset _moveFromPixel = Offset.zero;
  Offset _moveToPixel = Offset.zero;

  // current cell size (set by LayoutBuilder)
  double _cellSize = 0;

  static const Color _red = Color(0xFFEF4444);
  static const Color _green = Color(0xFF22C55E);
  static const Color _yellow = Color(0xFFEAB308);
  static const Color _blue = Color(0xFF3B82F6);

  // ---------------------------------------------------------------- lifecycle

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
    _moveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _handoffController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _diceController.dispose();
    _pulseController.dispose();
    _winOverlayController.dispose();
    _moveAnimController.dispose();
    _handoffController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- helpers

  String _key(LudoToken t) => '${t.color.name}_${t.index}';

  Color _colorOf(LudoColor c) => switch (c) {
    LudoColor.red => _red,
    LudoColor.green => _green,
    LudoColor.yellow => _yellow,
    LudoColor.blue => _blue,
  };

  String _emojiOf(LudoColor c) => switch (c) {
    LudoColor.red => '🔴',
    LudoColor.green => '🟢',
    LudoColor.yellow => '🟡',
    LudoColor.blue => '🔵',
  };

  String _playerName(LudoPlayer p) {
    if (p.isAI) return 'AI';
    if (_game!.isLocalMultiplayer) {
      final idx = _game!.players.indexOf(p) + 1;
      return 'P$idx';
    }
    return 'You';
  }

  // ---------------------------------------------------------------- setup

  void _startGame() {
    _aiTimer?.cancel();
    final seatIsAI = <bool>[];
    if (_setupMode == 0) {
      // vs AI: seat 0 = human, rest = AI
      for (int i = 0; i < _seatCount; i++) {
        seatIsAI.add(i != 0);
      }
    } else {
      // Local: first _humanCount seats = human, rest = AI
      for (int i = 0; i < _seatCount; i++) {
        seatIsAI.add(i >= _humanCount);
      }
    }
    setState(() {
      _game = LudoGame(seatCount: _seatCount, seatIsAI: seatIsAI);
      _setupOpen = false;
      _movable = [];
      _displayProgress.clear();
      for (final p in _game!.players) {
        for (final t in p.tokens) {
          _displayProgress[_key(t)] = t.progress;
        }
      }
      final human = _game!.players.firstWhere((p) => !p.isAI);
      _statusText =
          '${_emojiOf(human.color)} ${_playerName(human)} — roll the dice!';
    });
  }

  // ------------------------------------------------------------ handoff

  void _dismissHandoff() {
    _handoffController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _showHandoff = false);
    });
  }

  // --------------------------------------------------------------- dice

  void _tapDice() {
    if (_game == null || _rolling || _game!.isGameOver || _animatingMove) {
      return;
    }
    if (_game!.phase != LudoPhase.awaitRoll || _game!.isAITurn) return;
    HapticFeedback.lightImpact();
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
      setState(() => _statusText = 'Three sixes — turn lost!');
      game.passTurn();
      _scheduleNext();
      return;
    }

    final movable = game.movableTokens();
    if (movable.isEmpty) {
      if (game.diceValue == 6) {
        game.repeatRoll();
        setState(() => _statusText = 'No move available — roll again!');
      } else {
        setState(() => _statusText = 'No move available.');
        game.passTurn();
      }
      _scheduleNext();
      return;
    }

    if (game.isAITurn) {
      setState(
        () =>
            _statusText = '${_emojiOf(game.currentColor)} AI rolled $_diceFace',
      );
      _aiTimer?.cancel();
      _aiTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted || _game == null || _game!.isGameOver) return;
        final choice = _game!.chooseAIMove();
        if (choice != null) _executeMove(choice);
      });
    } else {
      setState(() {
        _movable = movable;
        _statusText = 'Rolled $_diceFace — pick a token';
      });
    }
  }

  // ----------------------------------------------------------- move flow

  void _animateToken(LudoToken token, int toProgress) {
    final fromPos = _tokenOffset(token, -1, _cellSize);
    final toPos = _tokenOffset(token, toProgress, _cellSize);

    _movingToken = token;
    _moveToProgress = toProgress;
    _moveFromPixel = fromPos;
    _moveToPixel = toPos;
    _animatingMove = true;

    _moveAnimController.duration = const Duration(milliseconds: 250);
    _moveAnimController.forward(from: 0).then((_) {
      _animatingMove = false;
      _movingToken = null;
      _finishMove(token, toProgress);
    });
    _moveAnimController.addListener(() => setState(() {}));
  }

  void _executeMove(LudoToken token) {
    final game = _game!;
    if (!game.canMove(token)) return;
    setState(() => _movable = []);

    final from = token.progress;
    final to = from == -1 ? 0 : from + game.diceValue;

    if (from == -1) {
      _animateToken(token, to);
      return;
    }

    // Smooth glide animation
    final fromPos = _tokenOffset(token, from, _cellSize);
    final toPos = _tokenOffset(token, to, _cellSize);
    final dx = (toPos.dx - fromPos.dx).abs();
    final dy = (toPos.dy - fromPos.dy).abs();
    final dist = math.sqrt(dx * dx + dy * dy);

    // Snap if wrapping around the board
    if (dist > _cellSize * 8) {
      _finishMove(token, to);
      return;
    }

    _movingToken = token;
    _moveToProgress = to;
    _moveFromPixel = fromPos;
    _moveToPixel = toPos;
    _animatingMove = true;

    final steps = (to - from).abs();
    _moveAnimController.duration = Duration(
      milliseconds: (steps * 80).clamp(80, 400),
    );
    _moveAnimController.forward(from: 0).then((_) {
      _animatingMove = false;
      _movingToken = null;
      _finishMove(token, to);
    });
    _moveAnimController.addListener(() => setState(() {}));
  }

  void _finishMove(LudoToken token, int newProgress) {
    final game = _game!;
    setState(() => _displayProgress[_key(token)] = newProgress);

    final outcome = game.applyMove(token);

    // Sync all display progress
    setState(() {
      for (final p in game.players) {
        for (final t in p.tokens) {
          _displayProgress[_key(t)] = t.progress;
        }
      }
    });

    if (outcome.captured > 0) {
      HapticFeedback.mediumImpact();
    }

    String msg;
    if (outcome.finishedToken && game.isGameOver) {
      msg = 'Game over!';
      HapticFeedback.heavyImpact();
    } else if (outcome.finishedToken) {
      msg = 'Token home! Roll again';
      HapticFeedback.lightImpact();
    } else if (outcome.captured > 0) {
      msg = 'Captured! Extra roll';
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
      _scheduleNext(userTurnMsg: 'Extra turn — roll again!');
      return;
    }
    _scheduleNext();
  }

  // ----------------------------------------------------------- scheduling

  void _scheduleNext({String? userTurnMsg}) {
    final game = _game;
    if (game == null || game.isGameOver || !mounted) return;

    if (!game.isAITurn) {
      if (game.isLocalMultiplayer && !_showHandoff) {
        // Show handoff screen for human players in local mode
        _handoffName = _playerName(game.currentPlayer);
        _handoffColor = game.currentColor;
        _showHandoff = true;
        _handoffController.forward(from: 0);
        if (userTurnMsg != null) {
          // Store msg to show after handoff dismissed
          _statusText = userTurnMsg;
        }
        return;
      }
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

  // ----------------------------------------------------------- geometry

  Offset _tokenOffset(LudoToken t, int progress, double cell) {
    if (progress < 0) {
      const slots = [
        Offset(1.5, 1.5),
        Offset(3.5, 1.5),
        Offset(1.5, 3.5),
        Offset(3.5, 3.5),
      ];
      final o = _yardOrigin(t.color);
      return Offset(
        (o.$1 + slots[t.index].dx) * cell,
        (o.$2 + slots[t.index].dy) * cell,
      );
    }
    if (progress >= 56) return _homeCenter(t.color, cell);
    if (progress >= 51) {
      final c = LudoGame.homeColumn(t.color)[math.min(progress, 55) - 51];
      return Offset((c.c + 0.5) * cell, (c.r + 0.5) * cell);
    }
    final c = LudoGame.cellFor(t.color, math.min(progress, 50))!;
    return Offset((c.c + 0.5) * cell, (c.r + 0.5) * cell);
  }

  (int, int) _yardOrigin(LudoColor c) => switch (c) {
    LudoColor.red => (0, 0),
    LudoColor.green => (9, 0),
    LudoColor.yellow => (9, 9),
    LudoColor.blue => (0, 9),
  };

  Offset _homeCenter(LudoColor c, double cell) => switch (c) {
    LudoColor.red => Offset(6.5 * cell, 7.5 * cell),
    LudoColor.green => Offset(7.5 * cell, 6.5 * cell),
    LudoColor.yellow => Offset(8.5 * cell, 7.5 * cell),
    LudoColor.blue => Offset(7.5 * cell, 8.5 * cell),
  };

  // ----------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final showOverlay = _game != null && _game!.isGameOver && !_setupOpen;
    return Scaffold(
      body: Stack(
        children: [
          // gradient background header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.38,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF78350F),
                    Color(0xFF92400E),
                    AppColors.background,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      const AppBackButton(),
                      const Spacer(),
                      Text(
                        'Ludo King',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: Colors.white),
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
                              _buildBoardContainer(),
                              const SizedBox(height: 14),
                              _buildBottomBar(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (_showHandoff) _buildHandoffOverlay(),
          if (showOverlay) _buildWinOverlay(),
        ],
      ),
    );
  }

  // --------------------------------------------------------- setup screen

  Widget _buildSetup() {
    final isAI = _setupMode == 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Mode selector
              Text(
                'Game Mode',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _modeCard(0, '🤖', 'vs AI'),
                  const SizedBox(width: 10),
                  _modeCard(1, '👥', 'Local'),
                ],
              ),
              const SizedBox(height: 20),

              // Player count
              Text(
                isAI ? 'Total Players' : 'Human Players',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [2, 3, 4].map((n) {
                  final selected = isAI ? _seatCount == n : _humanCount == n;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (isAI) {
                          _seatCount = n;
                        } else {
                          _humanCount = n;
                          _seatCount = math.max(n, 2);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: selected ? AppColors.buttonGradient : null,
                          color: selected ? null : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.cardBorder,
                            width: selected ? 1.2 : 0.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$n',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              isAI ? 'AI×${n - 1}' : 'Human',
                              style: TextStyle(
                                fontSize: 9,
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

              if (!isAI && _humanCount < _seatCount) ...[
                const SizedBox(height: 8),
                Text(
                  'AI fills remaining ${_seatCount - _humanCount} seat(s)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 18),
              Text(
                isAI
                    ? 'You play 🔴 · others are AI'
                    : 'Pass the device each turn',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              GradientButton(
                text: 'Start Game',
                icon: Icons.play_arrow_rounded,
                onPressed: _startGame,
                height: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(int mode, String emoji, String label) {
    final selected = _setupMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _setupMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.buttonGradient : null,
            color: selected ? null : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.cardBorder,
              width: selected ? 1.2 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------- player chips

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
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 6, backgroundColor: color),
                    const SizedBox(width: 5),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _playerName(p),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '🏠${p.tokensHome}/4',
                  style: TextStyle(
                    fontSize: 10,
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

  // --------------------------------------------------------- status bar

  Widget _buildStatusBar() {
    final game = _game!;
    final color = _colorOf(game.currentColor);
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _rolling
                ? SizedBox(
                    key: const ValueKey('spin'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(
                    Icons.casino_rounded,
                    key: const ValueKey('icon'),
                    size: 18,
                    color: color,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- board

  Widget _buildBoardContainer() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cardBg,
            AppColors.surfaceLight.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _buildBoard(),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final cell = side / 15;
        _cellSize = cell;
        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              CustomPaint(
                size: Size.square(side),
                painter: _LudoBoardPainter(),
              ),
              ..._buildGhosts(cell),
              ..._buildTokens(cell),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------- ghosts

  List<Widget> _buildGhosts(double cell) {
    if (_movable.isEmpty || _animatingMove || _rolling) return [];
    final game = _game!;
    if (game.isAITurn) return [];
    final widgets = <Widget>[];
    for (final token in _movable) {
      final from = _displayProgress[_key(token)] ?? token.progress;
      final to = from == -1 ? 0 : from + game.diceValue;
      final offset = _tokenOffset(token, to, cell);
      widgets.add(
        Positioned(
          left: offset.dx - cell * 0.36,
          top: offset.dy - cell * 0.36,
          width: cell * 0.72,
          height: cell * 0.72,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (_, _) {
              final opacity = 0.15 + 0.2 * _pulseController.value;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorOf(token.color).withValues(alpha: opacity),
                  border: Border.all(
                    color: _colorOf(token.color).withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return widgets;
  }

  // --------------------------------------------------------- tokens

  Offset _animInterpolatedPixel(double cell) {
    if (_movingToken == null || _cellSize == 0) return Offset.zero;
    final t = Curves.easeInOut.transform(_moveAnimController.value);
    return Offset(
      _moveFromPixel.dx + (_moveToPixel.dx - _moveFromPixel.dx) * t,
      _moveFromPixel.dy + (_moveToPixel.dy - _moveFromPixel.dy) * t,
    );
  }

  List<Widget> _buildTokens(double cell) {
    final widgets = <Widget>[];
    final buckets = <String, List<MapEntry<Offset, (LudoToken, int, bool)>>>{};

    for (final p in _game!.players) {
      for (final t in p.tokens) {
        final key = _key(t);

        // If this token is being animated, use interpolated pixel position
        if (_animatingMove && identical(_movingToken, t)) {
          final pixel = _animInterpolatedPixel(cell);
          final bucketKey =
              '${(pixel.dx / cell).round()}:${(pixel.dy / cell).round()}';
          buckets
              .putIfAbsent(bucketKey, () => [])
              .add(MapEntry(pixel, (t, _moveToProgress, true)));
          continue;
        }

        final shown = _displayProgress[key] ?? t.progress;
        final offset = _tokenOffset(t, shown, cell);
        final bucketKey =
            '${(offset.dx / cell).round()}:${(offset.dy / cell).round()}';
        buckets
            .putIfAbsent(bucketKey, () => [])
            .add(MapEntry(offset, (t, shown, false)));
      }
    }

    buckets.forEach((_, entries) {
      for (int i = 0; i < entries.length; i++) {
        final (token, shown, isAnimating) = entries[i].value;
        final base = entries[i].key;
        final shift = entries.length > 1 ? i * 5.0 : 0.0;
        final canTap =
            _movable.any((m) => identical(m, token)) &&
            !_game!.isAITurn &&
            !_rolling &&
            !_animatingMove;
        widgets.add(
          Positioned(
            left: base.dx + shift - cell * 0.36,
            top: base.dy + shift - cell * 0.36,
            width: cell * 0.72,
            height: cell * 0.72,
            child: GestureDetector(
              onTap: canTap ? () => _executeMove(token) : null,
              child: _pawn(
                token,
                cell * 0.72,
                highlighted: canTap,
                animating: isAnimating,
              ),
            ),
          ),
        );
      }
    });
    return widgets;
  }

  Widget _pawn(
    LudoToken t,
    double size, {
    required bool highlighted,
    bool animating = false,
  }) {
    final color = _colorOf(t.color);
    final scale = animating
        ? Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).transform(Curves.easeOut.transform(_moveAnimController.value))
        : 1.0;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) {
        final glow = highlighted ? 0.35 + 0.65 * _pulseController.value : 0.25;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withValues(alpha: 0.9), color],
                center: Alignment.topLeft,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: size * 0.055,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: size * 0.12,
                  offset: Offset(size * 0.04, size * 0.06),
                ),
                if (highlighted)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: glow),
                    blurRadius: size * 0.45,
                  ),
              ],
            ),
            child: Center(
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------- dice

  Widget _buildBottomBar() {
    final game = _game!;
    final humanTurn =
        !game.isAITurn &&
        !game.isGameOver &&
        game.phase == LudoPhase.awaitRoll &&
        !_rolling &&
        !_animatingMove;
    final diceColor = _colorOf(game.currentColor);
    return Row(
      children: [
        GestureDetector(
          onTap: _tapDice,
          child: AnimatedBuilder(
            animation: Listenable.merge([_diceController, _pulseController]),
            builder: (_, _) {
              final face = _rolling
                  ? (1 + (_diceController.value * 6).floor() % 6)
                  : _diceFace;
              final spin = _rolling ? _diceController.value * 6.28 : 0.0;
              final breath = humanTurn
                  ? 1.0 + 0.04 * _pulseController.value
                  : 1.0;
              return Transform.scale(
                scale: breath,
                child: Transform.rotate(
                  angle: spin,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: humanTurn
                          ? LinearGradient(
                              colors: [
                                diceColor.withValues(alpha: 0.85),
                                diceColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                AppColors.surfaceLight,
                                AppColors.surfaceLight,
                              ],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: humanTurn
                            ? Colors.white.withValues(alpha: 0.3)
                            : AppColors.cardBorder,
                        width: 0.8,
                      ),
                      boxShadow: humanTurn
                          ? [
                              BoxShadow(
                                color: diceColor.withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(child: _pipLayout(face)),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GradientButton(
            text: 'New Game',
            icon: Icons.refresh_rounded,
            onPressed: () {
              _aiTimer?.cancel();
              _moveAnimController.stop();
              _winOverlayController.reverse();
              setState(() {
                _setupOpen = true;
                _game = null;
                _showHandoff = false;
                _animatingMove = false;
                _movingToken = null;
                _movable = [];
                _statusText = 'Choose a mode to begin';
              });
            },
            height: 52,
          ),
        ),
      ],
    );
  }

  Widget _pipLayout(int face) {
    final pipColor = _game != null && !_game!.isAITurn
        ? Colors.white
        : AppColors.textPrimary;
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
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: pipColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return switch (face) {
      1 => grid([4]),
      2 => grid([0, 8]),
      3 => grid([0, 4, 8]),
      4 => grid([0, 2, 6, 8]),
      5 => grid([0, 2, 4, 6, 8]),
      _ => grid([0, 2, 3, 5, 6, 8]),
    };
  }

  // -------------------------------------------------------- handoff

  Widget _buildHandoffOverlay() {
    final color = _handoffColor;
    return Positioned.fill(
      child: FadeTransition(
        opacity: _handoffController,
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, _) {
                    final s = 1.0 + 0.08 * _pulseController.value;
                    return Transform.scale(
                      scale: s,
                      child: Text(
                        _emojiOf(color),
                        style: const TextStyle(fontSize: 72),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Pass to',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _handoffName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _colorOf(color),
                  ),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _dismissHandoff();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _colorOf(color).withValues(alpha: 0.7),
                          _colorOf(color),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _colorOf(color).withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Text(
                      'Tap to play',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------- win overlay

  Widget _buildWinOverlay() {
    final standings = _game!.standings;
    final medals = ['🥇', '🥈', '🥉', '4️⃣'];
    final winner = standings.first;
    return Positioned.fill(
      child: FadeTransition(
        opacity: _winOverlayController,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(
              parent: _winOverlayController,
              curve: Curves.easeOut,
            ),
          ),
          child: Container(
            color: Colors.black.withValues(alpha: 0.78),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(28),
                padding: const EdgeInsets.all(26),
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.cardBg,
                      _colorOf(winner.color).withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder, width: 0.7),
                  boxShadow: [
                    BoxShadow(
                      color: _colorOf(winner.color).withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 10),
                    Text(
                      '${_emojiOf(winner.color)} ${_playerName(winner)} wins!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                            Text(
                              medals[i],
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_playerName(p)} ${_emojiOf(p.color)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${p.tokensHome}/4',
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
                          _showHandoff = false;
                          _statusText = 'Choose a mode to begin';
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
      ),
    );
  }
}

// ================================================================== painter

class _LudoBoardPainter extends CustomPainter {
  static const Color _red = Color(0xFFEF4444);
  static const Color _green = Color(0xFF22C55E);
  static const Color _yellow = Color(0xFFEAB308);
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _track = Color(0xFFF1F5F9);
  static const Color _line = Color(0xFFCBD5E1);
  static const Color _gold = Color(0xFFFBBF24);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

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
      for (final d in const [
        Offset(1.5, 1.5),
        Offset(3.5, 1.5),
        Offset(1.5, 3.5),
        Offset(3.5, 3.5),
      ]) {
        canvas.drawCircle(
          Offset((x + d.dx) * cell, (y + d.dy) * cell),
          cell * 0.55,
          Paint()..color = color.withValues(alpha: 0.2),
        );
        canvas.drawCircle(
          Offset((x + d.dx) * cell, (y + d.dy) * cell),
          cell * 0.55,
          Paint()
            ..color = color.withValues(alpha: 0.35)
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
      final cells = LudoGame.homeColumn(c);
      for (int i = 0; i < cells.length; i++) {
        final cl = cells[i];
        final shade = 0.6 + (i * 0.08);
        canvas.drawRect(
          Rect.fromLTWH(cl.c * cell, cl.r * cell, cell, cell),
          Paint()..color = color.withValues(alpha: shade),
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
        Paint()..color = color,
      );
      // small triangle indicator
      final cx = (cellPos.c + 0.5) * cell;
      final cy = (cellPos.r + 0.5) * cell;
      final path = Path()
        ..moveTo(cx - cell * 0.2, cy - cell * 0.25)
        ..lineTo(cx + cell * 0.2, cy)
        ..lineTo(cx - cell * 0.2, cy + cell * 0.25)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
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
      ..strokeWidth = 0.8;
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
      // gold glow
      canvas.drawCircle(
        center,
        cell * 0.3,
        Paint()..color = _gold.withValues(alpha: 0.15),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '★',
          style: TextStyle(color: _gold, fontSize: cell * 0.55),
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
}
