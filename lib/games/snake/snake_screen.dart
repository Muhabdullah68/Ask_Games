import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'snake_engine.dart';

class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen>
    with TickerProviderStateMixin {
  late final SnakeGame _game;
  Timer? _gameTimer;
  late AnimationController _winOverlayController;
  late AnimationController _pulseController;
  late final FocusNode _focusNode;
  Offset? _swipeStart;
  bool _swipeHandled = false;

  @override
  void initState() {
    super.initState();
    _game = SnakeGame(gridSize: 18, difficulty: SnakeDifficulty.medium);
    _focusNode = FocusNode();
    _winOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _winOverlayController.dispose();
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startOrResume() {
    if (_game.state == SnakeGameState.playing) return;
    if (_game.state == SnakeGameState.gameOver) {
      _winOverlayController.reverse();
      _game.reset();
    }
    _game.start();
    _startTimer();
    setState(() {});
  }

  void _pause() {
    _game.pause();
    _gameTimer?.cancel();
    setState(() {});
  }

  int _activeSpeedMs = 120;

  void _startTimer() {
    _gameTimer?.cancel();
    _activeSpeedMs = _game.speedMs;
    _gameTimer = Timer.periodic(Duration(milliseconds: _activeSpeedMs), (_) {
      if (_game.state != SnakeGameState.playing) return;
      final changed = _game.step();
      if (_game.state == SnakeGameState.gameOver) {
        _gameTimer?.cancel();
        _winOverlayController.forward();
        setState(() {});
        return;
      }
      if (_game.speedMs != _activeSpeedMs) {
        setState(() {});
        _startTimer();
        return;
      }
      if (changed) setState(() {});
    });
  }

  void _resetGame() {
    _gameTimer?.cancel();
    _winOverlayController.reverse();
    setState(() {
      _game.reset();
    });
  }

  void _setDifficulty(SnakeDifficulty d) {
    if (_game.difficulty == d) return;
    _gameTimer?.cancel();
    _winOverlayController.reverse();
    setState(() {
      _game.difficulty = d;
      _game.reset();
    });
  }

  void _setDir(SnakeDirection dir) {
    _game.setDirection(dir);
    if (_game.state == SnakeGameState.idle) {
      _startOrResume();
    }
  }

  void _onSwipeStart(DragStartDetails d) {
    _swipeStart = d.localPosition;
    _swipeHandled = false;
  }

  void _onSwipeUpdate(DragUpdateDetails d) {
    if (_swipeStart == null || _swipeHandled) return;
    final delta = d.localPosition - _swipeStart!;
    if (delta.distance < 24) return;
    _swipeHandled = true;
    if (delta.dx.abs() > delta.dy.abs()) {
      _setDir(delta.dx > 0 ? SnakeDirection.right : SnakeDirection.left);
    } else {
      _setDir(delta.dy > 0 ? SnakeDirection.down : SnakeDirection.up);
    }
  }

  void _onSwipeEnd(DragEndDetails d) {
    _swipeStart = null;
    _swipeHandled = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.keyW) {
              _setDir(SnakeDirection.up);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.keyS) {
              _setDir(SnakeDirection.down);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.keyA) {
              _setDir(SnakeDirection.left);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.keyD) {
              _setDir(SnakeDirection.right);
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              if (_game.state == SnakeGameState.playing) {
                _pause();
              } else {
                _startOrResume();
              }
            }
          }
        },
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.38,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF052E16),
                      Color(0xFF064E3B),
                      AppColors.background,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 30,
                      right: 30,
                      child: Icon(
                        Icons.grass_rounded,
                        size: 60,
                        color: AppColors.green.withValues(alpha: 0.1),
                      ),
                    ),
                    Positioned(
                      left: 40,
                      bottom: 50,
                      child: Icon(
                        Icons.local_florist_rounded,
                        size: 50,
                        color: AppColors.gold.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
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
                          'Snake Rush',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      child: Column(
                        children: [
                          _buildScoreRow(),
                          const SizedBox(height: 22),
                          _buildStatusIndicator(),
                          const SizedBox(height: 22),
                          _buildGameBoard(),
                          const SizedBox(height: 24),
                          _buildControlPad(),
                          const SizedBox(height: 22),
                          _buildDifficultySelector(),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(child: _buildMainButton()),
                              const SizedBox(width: 12),
                              Expanded(
                                child: BorderedButton(
                                  text: 'Reset',
                                  onPressed: _resetGame,
                                  borderRadius: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildEndOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow() {
    return Row(
      children: [
        Expanded(
          child: _buildScoreCard(
            label: 'Score',
            value: _game.score,
            gradient: const LinearGradient(
              colors: [Color(0xFF4ADE80), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: '🎯',
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 60,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🐍', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                '${_game.snake.length}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildScoreCard(
            label: 'Best',
            value: _game.highScore,
            gradient: const LinearGradient(
              colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: '🏆',
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard({
    required String label,
    required int value,
    required Gradient gradient,
    required String icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    foreground: Paint()
                      ..shader = gradient.createShader(
                        const Rect.fromLTWH(0, 0, 100, 1),
                      ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final (label, icon, color) = switch (_game.state) {
      SnakeGameState.idle => (
        'Tap Play or swipe any direction to start',
        Icons.play_circle_rounded,
        AppColors.primaryLight,
      ),
      SnakeGameState.playing => (
        'Eat apples! 🍎 Gold = +50 · Avoid bombs 💣',
        Icons.play_arrow_rounded,
        AppColors.green,
      ),
      SnakeGameState.paused => (
        'Paused — tap Resume to continue',
        Icons.pause_circle_rounded,
        AppColors.gold,
      ),
      SnakeGameState.gameOver => (
        'Game Over!',
        Icons.timer_off_rounded,
        AppColors.red,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
        boxShadow: [
          if (_game.state == SnakeGameState.playing)
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.2),
              blurRadius: 16,
            ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _game.state == SnakeGameState.playing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.green,
                      ),
                    )
                  : Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _game.state == SnakeGameState.playing
                    ? AppColors.green
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameBoard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF052E16),
            const Color(0xFF064E3B).withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color(0xFF065F46), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final boardSize = constraints.maxWidth - 28;
          final n = _game.gridSize;
          final cellSize = boardSize / n;

          return Container(
            width: boardSize,
            height: boardSize,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Color(0xFF022C22).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: _onSwipeStart,
                onPanUpdate: _onSwipeUpdate,
                onPanEnd: _onSwipeEnd,
                child: Stack(
                  children: [
                    ..._buildGrid(n, cellSize),
                    ..._buildObstacles(cellSize),
                    ..._buildFoods(cellSize),
                    ..._buildSnake(n, cellSize),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGrid(int n, double cellSize) {
    final widgets = <Widget>[];
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        final dark = (x + y) % 2 == 0;
        widgets.add(
          Positioned(
            left: x * cellSize,
            top: y * cellSize,
            width: cellSize,
            height: cellSize,
            child: Container(
              color: dark
                  ? Color(0xFF022C22).withValues(alpha: 0.35)
                  : Color(0xFF064E3B).withValues(alpha: 0.25),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildSnake(int n, double cellSize) {
    final widgets = <Widget>[];
    final len = _game.snake.length;
    for (int i = 0; i < len; i++) {
      final p = _game.snake[i];
      final isHead = i == len - 1;
      final t = i / (len - 1);

      final rT = 1.0 - t;
      final r = (0x4A + (0x05 - 0x4A) * (1.0 - rT)).round();
      final g = (0xDE + (0x96 - 0xDE) * (1.0 - rT)).round();
      final b = (0x80 + (0x69 - 0x80) * (1.0 - rT)).round();
      final bodyColor = Color.fromRGBO(
        r.clamp(0, 255),
        g.clamp(0, 255),
        b.clamp(0, 255),
        1,
      );

      widgets.add(
        Positioned(
          left: p.x * cellSize + cellSize * 0.06,
          top: p.y * cellSize + cellSize * 0.06,
          width: cellSize * 0.88,
          height: cellSize * 0.88,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: isHead
                    ? [Color(0xFF86EFAC), Color(0xFF22C55E)]
                    : [bodyColor.withValues(alpha: 0.95), bodyColor],
                center: Alignment.topLeft,
                radius: 1.2,
              ),
              borderRadius: BorderRadius.circular(
                isHead ? cellSize * 0.35 : cellSize * 0.25,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHead
                      ? AppColors.green.withValues(alpha: 0.6)
                      : Color(0xFF22C55E).withValues(alpha: 0.25),
                  blurRadius: isHead ? 10 : 4,
                  spreadRadius: isHead ? 1 : 0,
                ),
              ],
            ),
            child: isHead ? Center(child: _buildHeadEyes(cellSize)) : null,
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildHeadEyes(double cellSize) {
    final dir = _game.direction;
    final eyeSize = cellSize * 0.18;
    final pupSize = cellSize * 0.09;
    final offset = cellSize * 0.18;

    double left1 = 0, top1 = 0, left2 = 0, top2 = 0;
    switch (dir) {
      case SnakeDirection.up:
        left1 = offset - eyeSize / 2 + cellSize * 0.12;
        top1 = offset;
        left2 = cellSize * 0.88 - offset - eyeSize / 2;
        top2 = offset;
        break;
      case SnakeDirection.down:
        left1 = offset - eyeSize / 2 + cellSize * 0.12;
        top1 = cellSize * 0.88 - offset - eyeSize;
        left2 = cellSize * 0.88 - offset - eyeSize / 2;
        top2 = cellSize * 0.88 - offset - eyeSize;
        break;
      case SnakeDirection.left:
        left1 = offset;
        top1 = offset - eyeSize / 2 + cellSize * 0.12;
        left2 = offset;
        top2 = cellSize * 0.88 - offset - eyeSize / 2;
        break;
      case SnakeDirection.right:
        left1 = cellSize * 0.88 - offset - eyeSize;
        top1 = offset - eyeSize / 2 + cellSize * 0.12;
        left2 = cellSize * 0.88 - offset - eyeSize;
        top2 = cellSize * 0.88 - offset - eyeSize / 2;
        break;
    }

    return Stack(
      children: [
        Positioned(
          left: left1,
          top: top1,
          width: eyeSize,
          height: eyeSize,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Center(
              child: Container(
                width: pupSize,
                height: pupSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: left2,
          top: top2,
          width: eyeSize,
          height: eyeSize,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Center(
              child: Container(
                width: pupSize,
                height: pupSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildObstacles(double cellSize) {
    return _game.obstacles.map((p) {
      return Positioned(
        left: p.x * cellSize + cellSize * 0.04,
        top: p.y * cellSize + cellSize * 0.04,
        width: cellSize * 0.92,
        height: cellSize * 0.92,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6B7280), Color(0xFF374151)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(cellSize * 0.18),
            border: Border.all(color: const Color(0xFF1F2937), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: cellSize * 0.3,
              height: cellSize * 0.18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(cellSize * 0.09),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildFoods(double cellSize) {
    return _game.foods.map((f) {
      switch (f.type) {
        case FoodType.normal:
          return _buildApple(f, cellSize);
        case FoodType.golden:
          return _buildGolden(f, cellSize);
        case FoodType.bomb:
          return _buildBomb(f, cellSize);
      }
    }).toList();
  }

  Widget _foodPulse(Food f, Widget child, {double amount = 0.1}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, wrapped) {
        final expiring =
            f.type != FoodType.normal && f.ticksLeft * _game.speedMs < 2000;
        final scale =
            (1.0 + amount * _pulseController.value) *
            (expiring ? 0.75 + 0.25 * _pulseController.value : 1.0);
        return Transform.scale(scale: scale, child: wrapped);
      },
      child: child,
    );
  }

  Widget _buildApple(Food f, double cellSize) {
    final p = f.pos;
    return Positioned(
      left: p.x * cellSize + cellSize * 0.1,
      top: p.y * cellSize + cellSize * 0.1,
      width: cellSize * 0.8,
      height: cellSize * 0.8,
      child: _foodPulse(
        f,
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFDC2626)],
              center: Alignment.topLeft,
              radius: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withValues(alpha: 0.7),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: cellSize * 0.38,
                top: cellSize * 0.02,
                child: Transform.rotate(
                  angle: 0.4,
                  child: Container(
                    width: cellSize * 0.1,
                    height: cellSize * 0.2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(cellSize * 0.05),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: cellSize * 0.2,
                top: cellSize * 0.2,
                child: Container(
                  width: cellSize * 0.14,
                  height: cellSize * 0.08,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(cellSize * 0.04),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGolden(Food f, double cellSize) {
    final p = f.pos;
    return Positioned(
      left: p.x * cellSize + cellSize * 0.08,
      top: p.y * cellSize + cellSize * 0.08,
      width: cellSize * 0.84,
      height: cellSize * 0.84,
      child: _foodPulse(
        f,
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
              center: Alignment.topLeft,
              radius: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.85),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: cellSize * 0.38,
                top: cellSize * 0.02,
                child: Transform.rotate(
                  angle: 0.4,
                  child: Container(
                    width: cellSize * 0.1,
                    height: cellSize * 0.2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(cellSize * 0.05),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text('✨', style: TextStyle(fontSize: cellSize * 0.42)),
              ),
            ],
          ),
        ),
        amount: 0.16,
      ),
    );
  }

  Widget _buildBomb(Food f, double cellSize) {
    final p = f.pos;
    return Positioned(
      left: p.x * cellSize + cellSize * 0.08,
      top: p.y * cellSize + cellSize * 0.08,
      width: cellSize * 0.84,
      height: cellSize * 0.84,
      child: _foodPulse(
        f,
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF4B5563), Color(0xFF111827)],
              center: Alignment(-0.3, -0.3),
              radius: 0.9,
            ),
            border: Border.all(color: const Color(0xFF9CA3AF), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: cellSize * 0.14,
                top: cellSize * 0.06,
                child: Container(
                  width: cellSize * 0.18,
                  height: cellSize * 0.18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFBBF24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.9),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Text('💥', style: TextStyle(fontSize: cellSize * 0.36)),
              ),
            ],
          ),
        ),
        amount: 0.14,
      ),
    );
  }

  Widget _buildControlPad() {
    final size = 72.0;
    final borderRadius = 20.0;
    return Column(
      children: [
        _buildDirButton(
          size: size,
          borderRadius: borderRadius,
          icon: Icons.keyboard_arrow_up_rounded,
          onTap: () => _setDir(SnakeDirection.up),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDirButton(
              size: size,
              borderRadius: borderRadius,
              icon: Icons.keyboard_arrow_left_rounded,
              onTap: () => _setDir(SnakeDirection.left),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                if (_game.state == SnakeGameState.playing) {
                  _pause();
                } else {
                  _startOrResume();
                }
              },
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _game.state == SnakeGameState.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _buildDirButton(
              size: size,
              borderRadius: borderRadius,
              icon: Icons.keyboard_arrow_right_rounded,
              onTap: () => _setDir(SnakeDirection.right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDirButton(
          size: size,
          borderRadius: borderRadius,
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: () => _setDir(SnakeDirection.down),
        ),
      ],
    );
  }

  Widget _buildDirButton({
    required double size,
    required double borderRadius,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.cardBorder, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 40),
      ),
    );
  }

  Widget _buildMainButton() {
    final state = _game.state;
    final (text, icon, onPressed) = switch (state) {
      SnakeGameState.idle => (
        'Start Game',
        Icons.play_arrow_rounded,
        _startOrResume,
      ),
      SnakeGameState.playing => ('Pause', Icons.pause_rounded, _pause),
      SnakeGameState.paused => (
        'Resume',
        Icons.play_arrow_rounded,
        _startOrResume,
      ),
      SnakeGameState.gameOver => (
        'Play Again',
        Icons.refresh_rounded,
        _startOrResume,
      ),
    };
    return GradientButton(
      text: text,
      icon: icon,
      onPressed: onPressed,
      height: 50,
    );
  }

  Widget _buildDifficultySelector() {
    final options = [
      SnakeDifficulty.easy,
      SnakeDifficulty.medium,
      SnakeDifficulty.hard,
    ];
    final labels = ['Easy', 'Medium', 'Hard'];
    final colors = [AppColors.green, AppColors.gold, AppColors.red];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final selected = _game.difficulty == options[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => _setDifficulty(options[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: [colors[i].withValues(alpha: 0.7), colors[i]],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEndOverlay() {
    return FadeTransition(
      opacity: _winOverlayController,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1).animate(
          CurvedAnimation(parent: _winOverlayController, curve: Curves.easeOut),
        ),
        child: IgnorePointer(
          ignoring: _game.state != SnakeGameState.gameOver,
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  margin: const EdgeInsets.all(28),
                  padding: const EdgeInsets.all(28),
                  constraints: const BoxConstraints(maxWidth: 360),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF052E16)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Color(0xFF065F46), width: 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.green.withValues(alpha: 0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _game.score >= _game.highScore && _game.score > 0
                            ? '🏆'
                            : '💀',
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _game.score >= _game.highScore && _game.score > 0
                              ? 'New High Score!'
                              : 'Game Over',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _game.score >= _game.highScore && _game.score > 0
                            ? 'Incredible run — you beat your record!'
                            : 'Great try! Ready for another round?',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  '🎯',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_game.score}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: Color(0xFF4ADE80)),
                                ),
                                Text(
                                  'Score',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.cardBorder,
                            ),
                            Column(
                              children: [
                                const Text(
                                  '🏆',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_game.highScore}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: AppColors.gold),
                                ),
                                Text(
                                  'Best',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.cardBorder,
                            ),
                            Column(
                              children: [
                                const Text(
                                  '🐍',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_game.snake.length}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: AppColors.primaryLight),
                                ),
                                Text(
                                  'Length',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: GradientButton(
                          text: 'Play Again',
                          icon: Icons.refresh_rounded,
                          onPressed: _startOrResume,
                          height: 52,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
