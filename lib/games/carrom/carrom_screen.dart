import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'carrom_engine.dart';
import 'carrom_models.dart';

class CarromScreen extends StatefulWidget {
  const CarromScreen({super.key});

  @override
  State<CarromScreen> createState() => _CarromScreenState();
}

class _CarromScreenState extends State<CarromScreen>
    with TickerProviderStateMixin {
  late CarromEngine _engine;
  bool _setupOpen = true;
  int _setupMode = 0;
  CarromDifficulty _difficulty = CarromDifficulty.medium;

  Timer? _gameLoop;
  late final AnimationController _pulseController;
  late final AnimationController _winOverlayController;
  late final AnimationController _handoffController;

  String _statusText = 'Choose a mode to begin';
  bool _showHandoff = false;
  String _handoffName = '';
  CarromPlayer _handoffPlayer = CarromPlayer.one;

  // gesture state
  bool _isDraggingStriker = false;
  bool _isAiming = false;
  Offset _aimStart = Offset.zero;
  Offset _aimCurrent = Offset.zero;
  List<Offset> _trajectoryPoints = [];
  double _aimPower = 0;

  // board sizing
  double _boardSize = 0;
  double _scale = 1;
  final double _offsetX = 0;
  final double _offsetY = 0;

  // score display
  int _scoreOne = 0;
  int _scoreTwo = 0;

  static const Color _white = Color(0xFFF5F5F0);
  static const Color _black = Color(0xFF2A2A2A);

  @override
  void initState() {
    super.initState();
    _engine = CarromEngine();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _winOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _handoffController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _startGameLoop();
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _pulseController.dispose();
    _winOverlayController.dispose();
    _handoffController.dispose();
    super.dispose();
  }

  void _startGameLoop() {
    _gameLoop?.cancel();
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || _setupOpen) return;
      _engine.update(0.016);

      // Check shot result
      final result = _engine.consumeShotResult();
      if (result != null) {
        _handleShotResult(result);
      }

      setState(() {
        _scoreOne = _engine.scoreOne;
        _scoreTwo = _engine.scoreTwo;
      });
    });
  }

  void _handleShotResult(ShotResult result) {
    if (result.gameOver) {
      final winner = result.winner;
      String msg;
      if (winner == CarromPlayer.one) {
        msg = _engine.mode == CarromGameMode.local
            ? 'Player 1 wins!'
            : 'You win!';
      } else {
        msg = _engine.mode == CarromGameMode.local
            ? 'Player 2 wins!'
            : 'AI wins!';
      }
      setState(() => _statusText = msg);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _winOverlayController.forward();
      });
      return;
    }

    String msg = '';
    if (result.strikerPocketed) {
      msg = 'Foul! Striker pocketed';
    } else if (result.queenCovered) {
      msg = 'Queen covered! +5 bonus';
    } else if (result.turnContinues) {
      msg = 'Nice shot! Shoot again';
    } else {
      msg = 'Turn over';
    }

    if (msg.isNotEmpty) setState(() => _statusText = msg);

    if (!result.turnContinues || result.strikerPocketed) {
      _maybeShowHandoff();
    }
  }

  void _maybeShowHandoff() {
    if (_engine.mode == CarromGameMode.local && !_engine.isAITurn) {
      _handoffPlayer = _engine.currentPlayer;
      _handoffName = _engine.currentPlayer == CarromPlayer.one
          ? 'Player 1'
          : 'Player 2';
      _showHandoff = true;
      _handoffController.forward(from: 0);
    } else if (_engine.isAITurn) {
      setState(() => _statusText = 'AI is thinking…');
    }
  }

  void _dismissHandoff() {
    _handoffController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _showHandoff = false;
        _statusText = _engine.currentPlayer == CarromPlayer.one
            ? 'Your turn — place striker'
            : 'Your turn — place striker';
      });
    });
  }

  // ---------------------------------------------------------------- setup

  void _startGame() {
    final mode = _setupMode == 0 ? CarromGameMode.vsAI : CarromGameMode.local;
    _engine = CarromEngine(mode: mode, difficulty: _difficulty);
    setState(() {
      _setupOpen = false;
      _scoreOne = 0;
      _scoreTwo = 0;
      _statusText = 'Place the striker on the baseline';
    });
    _startGameLoop();
  }

  // ------------------------------------------------------------ gestures

  Offset _screenToBoard(Offset screenPos) {
    return Offset(
      (screenPos.dx - _offsetX) / _scale,
      (screenPos.dy - _offsetY) / _scale,
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (_setupOpen || _engine.phase == TurnPhase.gameOver) return;
    if (_engine.isAITurn) return;

    final boardPos = _screenToBoard(details.localPosition);

    if (_engine.phase == TurnPhase.placeStriker) {
      final striker = _engine.discs.firstWhere(
        (d) => d.type == DiscType.striker,
        orElse: () => CarromDisc(x: 0, y: 0, type: DiscType.striker),
      );
      final dx = boardPos.dx - striker.x;
      final dy = boardPos.dy - striker.y;
      if (dx * dx + dy * dy < 40 * 40) {
        _isDraggingStriker = true;
        HapticFeedback.selectionClick();
      }
    } else if (_engine.phase == TurnPhase.aiming) {
      _isAiming = true;
      _aimStart = boardPos;
      _aimCurrent = boardPos;
      HapticFeedback.selectionClick();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_setupOpen) return;
    final boardPos = _screenToBoard(details.localPosition);

    if (_isDraggingStriker && _engine.phase == TurnPhase.placeStriker) {
      _engine.placeStriker(boardPos.dx);
      setState(() {});
    } else if (_isAiming && _engine.phase == TurnPhase.aiming) {
      _aimCurrent = boardPos;
      final dx = _aimStart.dx - _aimCurrent.dx;
      final dy = _aimStart.dy - _aimCurrent.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      _aimPower = (dist / 150).clamp(0.0, 1.0);

      // Compute trajectory
      final striker = _engine.discs.firstWhere(
        (d) => d.type == DiscType.striker,
        orElse: () => CarromDisc(x: 0, y: 0, type: DiscType.striker),
      );
      final rawTrajectory = _engine.computeTrajectory(
        striker.x,
        striker.y,
        dx,
        dy,
      );
      _trajectoryPoints = rawTrajectory.map((p) => Offset(p.$1, p.$2)).toList();
      setState(() {});
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDraggingStriker) {
      _isDraggingStriker = false;
      if (_engine.phase == TurnPhase.placeStriker) {
        _engine.phase = TurnPhase.aiming;
        setState(() => _statusText = 'Drag to aim and shoot');
      }
    } else if (_isAiming) {
      _isAiming = false;
      final dx = _aimStart.dx - _aimCurrent.dx;
      final dy = _aimStart.dy - _aimCurrent.dy;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist > 15 && _aimPower > 0.05) {
        HapticFeedback.mediumImpact();
        _engine.shoot(dx, dy, _aimPower);
        setState(() {
          _statusText = 'Shooting…';
          _trajectoryPoints = [];
          _aimPower = 0;
        });
      } else {
        setState(() {
          _trajectoryPoints = [];
          _aimPower = 0;
          _engine.phase = TurnPhase.placeStriker;
          _statusText = 'Place the striker on the baseline';
        });
      }
    }
  }

  void _onTapBoard(TapUpDetails details) {
    if (_setupOpen || _engine.isAITurn) return;
    if (_engine.phase == TurnPhase.placeStriker) {
      final boardPos = _screenToBoard(details.localPosition);
      // If tapping near baseline, place striker there
      if ((boardPos.dy - CarromEngine.baselineY).abs() < 30) {
        _engine.placeStriker(boardPos.dx);
        _engine.phase = TurnPhase.aiming;
        setState(() => _statusText = 'Drag to aim and shoot');
      }
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final showOverlay = !_setupOpen && _engine.phase == TurnPhase.gameOver;
    return Scaffold(
      body: Stack(
        children: [
          // gradient header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.38,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF291505),
                    Color(0xFF4A2E0A),
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
                        'Carrom Pool',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: Colors.white),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: _setupOpen
                      ? _buildSetup()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Column(
                            children: [
                              _buildScoreRow(),
                              const SizedBox(height: 8),
                              _buildStatusBar(),
                              const SizedBox(height: 10),
                              _buildBoardWidget(),
                              const SizedBox(height: 12),
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

  // --------------------------------------------------------- setup

  Widget _buildSetup() {
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
              const Text('🎯', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 14),
              Text(
                'Carrom Pool',
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

              if (_setupMode == 0) ...[
                const SizedBox(height: 20),
                Text(
                  'Difficulty',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: CarromDifficulty.values.map((d) {
                    final selected = _difficulty == d;
                    final label = d.name[0].toUpperCase() + d.name.substring(1);
                    final color = switch (d) {
                      CarromDifficulty.easy => AppColors.green,
                      CarromDifficulty.medium => AppColors.gold,
                      CarromDifficulty.hard => AppColors.red,
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _difficulty = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? LinearGradient(colors: [color, color])
                                : null,
                            color: selected ? null : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? color : AppColors.cardBorder,
                              width: selected ? 1.2 : 0.5,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 18),
              Text(
                _setupMode == 0
                    ? 'You play ⚪ White · AI plays ⚫ Black'
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

  // --------------------------------------------------------- score

  Widget _buildScoreRow() {
    final isOneTurn = _engine.currentPlayer == CarromPlayer.one;
    return Row(
      children: [
        _scoreCard(
          '⚪',
          'P1',
          _scoreOne,
          _engine.remainingWhite,
          isOneTurn && !_engine.isAITurn,
        ),
        const SizedBox(width: 8),
        _scoreCard(
          '⚫',
          _engine.mode == CarromGameMode.local ? 'P2' : 'AI',
          _scoreTwo,
          _engine.remainingBlack,
          !isOneTurn || _engine.isAITurn,
        ),
      ],
    );
  }

  Widget _scoreCard(
    String emoji,
    String label,
    int score,
    int remaining,
    bool active,
  ) {
    final color = active ? const Color(0xFFF59E0B) : AppColors.cardBorder;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: active ? 1.4 : 0.5),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: active
                        ? const Color(0xFFF59E0B)
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              '($remaining left)',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------- status

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
          if (_engine.phase == TurnPhase.simulating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFF59E0B),
              ),
            )
          else
            const Icon(Icons.circle, size: 8, color: Color(0xFFF59E0B)),
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

  // --------------------------------------------------------- board

  Widget _buildBoardWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _boardSize = constraints.maxWidth;
        _scale = _boardSize / CarromEngine.boardSize;
        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTapUp: _onTapBoard,
          child: Container(
            width: _boardSize,
            height: _boardSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _CarromBoardPainter(
                engine: _engine,
                scale: _scale,
                trajectoryPoints: _trajectoryPoints,
                aimPower: _aimPower,
                isAiming: _isAiming,
                aimStart: _aimStart,
                aimCurrent: _aimCurrent,
              ),
              size: Size.square(_boardSize),
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------- bottom bar

  Widget _buildBottomBar() {
    final canPlace =
        _engine.phase == TurnPhase.placeStriker && !_engine.isAITurn;
    final canAim = _engine.phase == TurnPhase.aiming && !_engine.isAITurn;
    final isSimulating = _engine.phase == TurnPhase.simulating;

    return Column(
      children: [
        // Power meter
        if (canAim || _isAiming)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, _) {
                final color = _aimPower < 0.5
                    ? AppColors.green
                    : _aimPower < 0.8
                    ? AppColors.gold
                    : AppColors.red;
                return FractionallySizedBox(
                  widthFactor: _aimPower,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color]),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        Row(
          children: [
            // Status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _engine.currentPlayer == CarromPlayer.one
                          ? _white
                          : _black,
                      border: Border.all(color: AppColors.cardBorder, width: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSimulating
                        ? 'Watching…'
                        : canPlace
                        ? 'Place striker'
                        : canAim
                        ? 'Aim & shoot'
                        : _engine.isAITurn
                        ? 'AI turn'
                        : 'Waiting',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GradientButton(
              text: 'New Game',
              icon: Icons.refresh_rounded,
              onPressed: () {
                _gameLoop?.cancel();
                _winOverlayController.reverse();
                setState(() {
                  _setupOpen = true;
                  _showHandoff = false;
                  _trajectoryPoints = [];
                  _statusText = 'Choose a mode to begin';
                });
              },
              height: 48,
            ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------- handoff

  Widget _buildHandoffOverlay() {
    final isP1 = _handoffPlayer == CarromPlayer.one;
    final color = isP1 ? _white : _black;
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
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
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
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
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

  // --------------------------------------------------------- win overlay

  Widget _buildWinOverlay() {
    final winner = _engine.currentPlayer;
    final isP1 = winner == CarromPlayer.one;
    final winnerName = _engine.mode == CarromGameMode.local
        ? (isP1 ? 'Player 1' : 'Player 2')
        : (isP1 ? 'You' : 'AI');
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
                      const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder, width: 0.7),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
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
                      '$winnerName wins!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _resultColumn(
                          '⚪ P1',
                          _scoreOne,
                          _engine.remainingWhite,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.cardBorder,
                        ),
                        _resultColumn(
                          _engine.mode == CarromGameMode.local
                              ? '⚫ P2'
                              : '⚫ AI',
                          _scoreTwo,
                          _engine.remainingBlack,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GradientButton(
                      text: 'Play Again',
                      icon: Icons.refresh_rounded,
                      onPressed: () {
                        _winOverlayController.reverse();
                        setState(() {
                          _setupOpen = true;
                          _showHandoff = false;
                          _trajectoryPoints = [];
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

  Widget _resultColumn(String label, int score, int remaining) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF59E0B),
          ),
        ),
        Text(
          '$remaining remaining',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ================================================================== painter

class _CarromBoardPainter extends CustomPainter {
  final CarromEngine engine;
  final double scale;
  final List<Offset> trajectoryPoints;
  final double aimPower;
  final bool isAiming;
  final Offset aimStart;
  final Offset aimCurrent;

  _CarromBoardPainter({
    required this.engine,
    required this.scale,
    required this.trajectoryPoints,
    required this.aimPower,
    required this.isAiming,
    required this.aimStart,
    required this.aimCurrent,
  });

  static const Color _boardBg = Color(0xFFF5E6C8);
  static const Color _frame = Color(0xFF8B6914);
  static const Color _frameDark = Color(0xFF5C4610);
  static const Color _pocket = Color(0xFF1A1205);
  static const Color _white = Color(0xFFF5F5F0);
  static const Color _black = Color(0xFF2A2A2A);
  static const Color _queen = Color(0xFFDC2626);
  static const Color _strikerColor = Color(0xFFF59E0B);
  static const Color _line = Color(0xFF8B6914);

  @override
  bool shouldRepaint(covariant _CarromBoardPainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / CarromEngine.boardSize;
    canvas.save();
    canvas.scale(s);

    _drawFrame(canvas);
    _drawSurface(canvas);
    _drawDecorations(canvas);
    _drawPockets(canvas);
    _drawTrajectory(canvas);
    _drawAimLine(canvas);
    _drawDiscs(canvas);

    canvas.restore();
  }

  void _drawFrame(Canvas canvas) {
    final board = CarromEngine.boardSize;
    // Outer frame
    final framePaint = Paint()
      ..shader = const LinearGradient(
        colors: [_frame, _frameDark, _frame],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(-12, -12, board + 24, board + 24));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-12, -12, board + 24, board + 24),
        const Radius.circular(14),
      ),
      framePaint,
    );
  }

  void _drawSurface(Canvas canvas) {
    final board = CarromEngine.boardSize;
    // Board surface
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, board, board),
        const Radius.circular(6),
      ),
      Paint()..color = _boardBg,
    );

    // Subtle wood grain lines
    final grainPaint = Paint()
      ..color = const Color(0xFFE8D5B0)
      ..strokeWidth = 0.5;
    for (double y = 10; y < board; y += 8) {
      canvas.drawLine(Offset(5, y), Offset(board - 5, y), grainPaint);
    }
  }

  void _drawDecorations(Canvas canvas) {
    final board = CarromEngine.boardSize;
    final cx = board / 2;
    final cy = board / 2;

    // Center circle
    final centerPaint = Paint()
      ..color = _line.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
      Offset(cx, cy),
      CarromEngine.centerCircleRadius,
      centerPaint,
    );

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = _line);

    // Baseline
    final basePaint = Paint()
      ..color = _line
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(CarromEngine.baselineMinX, CarromEngine.baselineY),
      Offset(CarromEngine.baselineMaxX, CarromEngine.baselineY),
      basePaint,
    );

    // Baseline circles at ends
    canvas.drawCircle(
      Offset(CarromEngine.baselineMinX, CarromEngine.baselineY),
      4,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      Offset(CarromEngine.baselineMaxX, CarromEngine.baselineY),
      4,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Top baseline (opponent)
    canvas.drawLine(
      Offset(CarromEngine.baselineMinX, board - CarromEngine.baselineY),
      Offset(CarromEngine.baselineMaxX, board - CarromEngine.baselineY),
      basePaint,
    );

    // Decorative arrows on each side
    _drawArrow(canvas, cx, 20, 0); // top
    _drawArrow(canvas, cx, board - 20, math.pi); // bottom
    _drawArrow(canvas, 20, cy, math.pi / 2); // left
    _drawArrow(canvas, board - 20, cy, -math.pi / 2); // right

    // Inner border
    final innerPaint = Paint()
      ..color = _line.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, 20, board - 40, board - 40),
        const Radius.circular(4),
      ),
      innerPaint,
    );
  }

  void _drawArrow(Canvas canvas, double x, double y, double angle) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -6)
      ..lineTo(5, 4)
      ..lineTo(-5, 4)
      ..close();
    canvas.drawPath(path, Paint()..color = _line.withValues(alpha: 0.4));
    canvas.restore();
  }

  void _drawPockets(Canvas canvas) {
    for (final (px, py) in CarromEngine.pockets) {
      // Pocket shadow
      canvas.drawCircle(
        Offset(px, py),
        CarromEngine.pocketRadius + 2,
        Paint()..color = Colors.black.withValues(alpha: 0.3),
      );
      // Pocket hole
      canvas.drawCircle(
        Offset(px, py),
        CarromEngine.pocketRadius,
        Paint()..color = _pocket,
      );
      // Rim
      canvas.drawCircle(
        Offset(px, py),
        CarromEngine.pocketRadius,
        Paint()
          ..color = _frameDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawTrajectory(Canvas canvas) {
    if (trajectoryPoints.isEmpty) return;
    final dotPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.6);
    for (int i = 0; i < trajectoryPoints.length; i++) {
      final opacity = (1.0 - i / trajectoryPoints.length) * 0.6;
      dotPaint.color = const Color(0xFFF59E0B).withValues(alpha: opacity);
      canvas.drawCircle(trajectoryPoints[i], 2, dotPaint);
    }
  }

  void _drawAimLine(Canvas canvas) {
    if (!isAiming) return;
    final striker = engine.discs.firstWhere(
      (d) => d.type == DiscType.striker,
      orElse: () => CarromDisc(x: 0, y: 0, type: DiscType.striker),
    );
    if (striker.pocketed) return;

    // Direction line from striker
    final dx = aimStart.dx - aimCurrent.dx;
    final dy = aimStart.dy - aimCurrent.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 5) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(striker.x, striker.y),
      Offset(striker.x + dx * 0.5, striker.y + dy * 0.5),
      paint,
    );
  }

  void _drawDiscs(Canvas canvas) {
    for (final d in engine.discs) {
      if (d.pocketed) continue;
      _drawDisc(canvas, Offset(d.x, d.y), d.radius, d.type);
    }
  }

  void _drawDisc(Canvas canvas, Offset center, double radius, DiscType type) {
    // Shadow
    canvas.drawCircle(
      center + Offset(1.5, 2),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    Color baseColor;
    bool hasRing = false;
    switch (type) {
      case DiscType.striker:
        baseColor = _strikerColor;
      case DiscType.white:
        baseColor = _white;
      case DiscType.black:
        baseColor = _black;
        hasRing = true;
      case DiscType.queen:
        baseColor = _queen;
    }

    // Body
    final gradient = RadialGradient(
      colors: [baseColor.withValues(alpha: 0.85), baseColor],
      center: const Alignment(-0.3, -0.3),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        ),
    );

    // Highlight ring
    canvas.drawCircle(
      center,
      radius * 0.7,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Black piece gold ring
    if (hasRing) {
      canvas.drawCircle(
        center,
        radius * 0.5,
        Paint()
          ..color = const Color(0xFFF59E0B).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Queen crown
    if (type == DiscType.queen) {
      canvas.drawCircle(
        center,
        radius * 0.35,
        Paint()
          ..color = const Color(0xFFFBBF24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Striker crosshair
    if (type == DiscType.striker) {
      final crossPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(center.dx - radius * 0.3, center.dy),
        Offset(center.dx + radius * 0.3, center.dy),
        crossPaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - radius * 0.3),
        Offset(center.dx, center.dy + radius * 0.3),
        crossPaint,
      );
    }
  }
}
