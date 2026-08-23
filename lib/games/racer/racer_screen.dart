import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'racer_engine.dart';

class SpeedRacerScreen extends StatefulWidget {
  const SpeedRacerScreen({super.key});

  @override
  State<SpeedRacerScreen> createState() => _SpeedRacerScreenState();
}

class _SpeedRacerScreenState extends State<SpeedRacerScreen>
    with TickerProviderStateMixin {
  late final RacerGame _game;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  late AnimationController _pulseController;
  late final FocusNode _focusNode;

  static const Color _asphaltDark = Color(0xFF0B1220);
  static const Color _asphaltLight = Color(0xFF1F2937);
  static const List<Color> _trafficColors = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFF97316),
    Color(0xFF14B8A6),
    Color(0xFFEAB308),
    Color(0xFFE5E7EB),
  ];

  static const List<String> _trafficEmojis = [
    '🚗',
    '🚙',
    '🚕',
    '🚌',
    '🚚',
    '🛻',
  ];

  @override
  void initState() {
    super.initState();
    _game = RacerGame();
    _focusNode = FocusNode();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (_game.state != RacerGameState.playing) {
      _stopLoop();
      return;
    }
    setState(() {
      _game.update(dt.clamp(0.0, 0.05));
    });
  }

  void _startLoop() {
    _ticker ??= createTicker(_onTick);
    _lastElapsed = Duration.zero;
    if (!_ticker!.isActive) _ticker!.start();
  }

  void _stopLoop() {
    _ticker?.stop();
    _lastElapsed = Duration.zero;
  }

  void _startOrResume() {
    if (_game.state == RacerGameState.playing) return;
    _game.start();
    _startLoop();
    setState(() {});
  }

  void _pause() {
    if (_game.state != RacerGameState.playing) return;
    _game.pause();
    _game.setHeldDirection(0);
    _stopLoop();
    setState(() {});
  }

  void _restart() {
    _game.reset();
    _game.start();
    _startLoop();
    setState(() {});
  }

  void _setDifficulty(RacerDifficulty d) {
    if (_game.state == RacerGameState.playing ||
        _game.state == RacerGameState.paused) {
      return;
    }
    setState(() => _game.difficulty = d);
    _game.reset();
  }

  @override
  Widget build(BuildContext context) {
    final gameOver = _game.state == RacerGameState.gameOver;
    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: SafeArea(
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
                          'Speed Racer',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      child: Column(
                        children: [
                          _buildScoreRow(),
                          const SizedBox(height: 14),
                          _buildFuelGauge(),
                          const SizedBox(height: 14),
                          _buildStatusIndicator(),
                          const SizedBox(height: 14),
                          _buildGameBoard(),
                          const SizedBox(height: 18),
                          _buildControlPad(),
                          const SizedBox(height: 18),
                          _buildDifficultySelector(),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: _buildMainButton()),
                              const SizedBox(width: 12),
                              _buildRestartButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (gameOver) _buildGameOverOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKey(KeyEvent event) {
    int dir = 0;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyA) {
      dir = -1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyD) {
      dir = 1;
    }
    if (dir != 0) {
      _game.setHeldDirection(event is KeyDownEvent ? dir : 0);
      return;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      if (_game.state == RacerGameState.playing) {
        _pause();
      } else {
        _startOrResume();
      }
    }
  }

  Widget _buildScoreRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _scoreCard(
              'Score',
              '${_game.score}',
              Icons.star_rounded,
              AppColors.gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _scoreCard(
              'Best',
              '${_game.highScore}',
              Icons.emoji_events_rounded,
              AppColors.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _scoreCard(
              'Coins',
              '${_game.coinsCollected}',
              Icons.paid_rounded,
              AppColors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelGauge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, _) {
        final critical = _game.fuel < 25;
        final opacity = critical ? 0.55 + 0.45 * _pulseController.value : 1.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Text(
                  '⛽',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _game.fuel / 100,
                      minHeight: 12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _game.fuel < 25
                            ? AppColors.red
                            : _game.fuel < 50
                            ? Colors.orange
                            : AppColors.green,
                      ),
                      backgroundColor: _asphaltLight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 42,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_game.fuel.round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator() {
    final (text, icon, color) = switch (_game.state) {
      RacerGameState.idle => (
        'Tap Start or drag the road to begin',
        Icons.play_circle_rounded,
        AppColors.primaryLight,
      ),
      RacerGameState.playing => (
        'Dodge traffic · grab ⛽ before it runs dry!',
        Icons.speed_rounded,
        AppColors.green,
      ),
      RacerGameState.paused => (
        'Paused — take a breath',
        Icons.pause_circle_rounded,
        AppColors.gold,
      ),
      RacerGameState.gameOver => (
        _game.gameOverReason,
        Icons.warning_rounded,
        AppColors.red,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = MediaQuery.of(context).size.height * 0.44;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanDown: (d) => _steerTo(d.localPosition.dx, w),
            onPanUpdate: (d) => _steerTo(d.localPosition.dx, w),
            child: Container(
              width: w,
              height: h,
              color: _asphaltDark,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  ..._buildRoadSurface(w, h),
                  ..._buildPickups(w, h),
                  ..._buildTraffic(w, h),
                  _buildPlayerCar(w, h),
                  if (_game.state == RacerGameState.idle ||
                      _game.state == RacerGameState.paused)
                    _buildBoardOverlay(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _steerTo(double localDx, double boardWidth) {
    if (_game.state != RacerGameState.playing) return;
    _game.setPlayerTargetX(localDx / boardWidth);
  }

  List<Widget> _buildRoadSurface(double w, double h) {
    final widgets = <Widget>[
      Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_asphaltLight, _asphaltDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: 5,
        child: Container(color: AppColors.primary.withValues(alpha: 0.55)),
      ),
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: 5,
        child: Container(color: AppColors.primary.withValues(alpha: 0.55)),
      ),
    ];

    const cycle = 0.24;
    final shift = (_game.roadOffset % cycle) * h;
    for (int divider = 1; divider <= 3; divider++) {
      final x = (divider * 0.25) * w - 1.5;
      for (int k = 0; k < 6; k++) {
        final top = shift + k * cycle * h - cycle * h;
        if (top > h || top < -h * 0.08) continue;
        widgets.add(
          Positioned(
            left: x,
            top: top,
            width: 3,
            height: h * 0.09,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _emojiCar({
    required double width,
    required double height,
    required String emoji,
    Color? glowColor,
    Widget? extra,
  }) {
    final size = min(width, height);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 0.92,
          height: size * 0.92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (glowColor ?? Colors.black).withValues(alpha: 0.35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: size * 0.18,
                offset: Offset(size * 0.04, size * 0.08),
              ),
            ],
          ),
        ),
        Text(emoji, style: TextStyle(fontSize: size * 0.94, height: 1.0)),
        ?extra,
      ],
    );
  }

  List<Widget> _buildTraffic(double w, double h) {
    return _game.traffic.map((car) {
      final cw = car.width * w;
      final ch = car.height * h;
      return Positioned(
        left: car.x * w - cw / 2,
        top: car.y * h - ch / 2,
        width: cw,
        height: ch,
        child: _emojiCar(
          width: cw,
          height: ch,
          emoji: _trafficEmojis[car.colorIndex % _trafficEmojis.length],
          glowColor: _trafficColors[car.colorIndex % _trafficColors.length],
        ),
      );
    }).toList();
  }

  List<Widget> _buildPickups(double w, double h) {
    return _game.pickups.map((p) {
      final size = p.size * min(w, h * 1.4);
      Widget icon;
      switch (p.type) {
        case PickupType.coin:
          icon = Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
                center: Alignment.topLeft,
                radius: 1.1,
              ),
              border: Border.all(color: const Color(0xFFB45309), width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.8),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '★',
                style: TextStyle(
                  fontSize: size * 0.5,
                  color: const Color(0xFF92400E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
          break;
        case PickupType.fuel:
          icon = Container(
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(size * 0.22),
              border: Border.all(color: Colors.white24, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.red.withValues(alpha: 0.7),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text('⛽', style: TextStyle(fontSize: size * 0.52)),
            ),
          );
          break;
        case PickupType.shield:
          icon = Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.25),
              border: Border.all(color: const Color(0xFF38BDF8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.7),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Text('🛡️', style: TextStyle(fontSize: size * 0.5)),
            ),
          );
          break;
        case PickupType.nitro:
          icon = Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFACC15).withValues(alpha: 0.25),
              border: Border.all(color: const Color(0xFFFBBF24), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.75),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Text('⚡', style: TextStyle(fontSize: size * 0.5)),
            ),
          );
          break;
      }
      return Positioned(
        left: p.x * w - size / 2,
        top: p.y * h - size / 2,
        width: size,
        height: size,
        child: icon,
      );
    }).toList();
  }

  Widget _buildPlayerCar(double w, double h) {
    const py = 0.82;
    final cw = RacerGame.playerWidth * w;
    final ch = RacerGame.playerHeight * h;

    Widget extras = const SizedBox.shrink();
    if (_game.hasShield) {
      extras = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF38BDF8), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
              blurRadius: 14,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, _) {
        Widget car = _emojiCar(
          width: cw,
          height: ch,
          emoji: '🏎️',
          glowColor: AppColors.primaryLight,
          extra: extras,
        );

        if (_game.nitroActive) {
          car = Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: -ch * 0.35,
                child: Opacity(
                  opacity: 0.6 + 0.4 * _pulseController.value,
                  child: Text('🔥🔥', style: TextStyle(fontSize: cw * 0.34)),
                ),
              ),
              car,
            ],
          );
        }

        return Positioned(
          left: _game.playerX * w - cw / 2,
          top: py * h - ch / 2,
          width: cw,
          height: ch,
          child: car,
        );
      },
    );
  }

  Widget _buildBoardOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _game.state == RacerGameState.idle
                    ? Icons.sports_score_rounded
                    : Icons.pause_circle_rounded,
                color: Colors.white70,
                size: 44,
              ),
              const SizedBox(height: 10),
              Text(
                _game.state == RacerGameState.idle
                    ? 'Drag to steer\nGrab ⛽ · Dodge 🚗'
                    : 'Paused',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoldSteerButton(int direction, IconData icon) {
    return Listener(
      onPointerDown: (_) => _game.setHeldDirection(direction),
      onPointerUp: (_) => _game.setHeldDirection(0),
      onPointerCancel: (_) => _game.setHeldDirection(0),
      child: Container(
        width: 84,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
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

  Widget _buildControlPad() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildHoldSteerButton(-1, Icons.keyboard_arrow_left_rounded),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            if (_game.state == RacerGameState.playing) {
              _pause();
            } else {
              _startOrResume();
            }
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _game.state == RacerGameState.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildHoldSteerButton(1, Icons.keyboard_arrow_right_rounded),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    final options = RacerDifficulty.values;
    final labels = ['Easy', 'Medium', 'Hard'];
    final colors = [AppColors.green, AppColors.gold, AppColors.red];
    final locked =
        _game.state == RacerGameState.playing ||
        _game.state == RacerGameState.paused;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final selected = _game.difficulty == options[i];
          return Expanded(
            child: GestureDetector(
              onTap: locked ? null : () => _setDifficulty(options[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.buttonGradient : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : colors[i].withValues(alpha: locked ? 0.4 : 0.9),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMainButton() {
    final state = _game.state;
    final (text, icon, onPressed) = switch (state) {
      RacerGameState.idle => (
        'Start Engine',
        Icons.play_arrow_rounded,
        _startOrResume,
      ),
      RacerGameState.playing => ('Pause', Icons.pause_rounded, _pause),
      RacerGameState.paused => (
        'Resume',
        Icons.play_arrow_rounded,
        _startOrResume,
      ),
      RacerGameState.gameOver => (
        'Race Again',
        Icons.refresh_rounded,
        _restart,
      ),
    };
    return GradientButton(
      text: text,
      icon: icon,
      onPressed: onPressed,
      height: 50,
    );
  }

  Widget _buildRestartButton() {
    return GestureDetector(
      onTap: () {
        _game.reset();
        _stopLoop();
        setState(() {});
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder, width: 0.8),
        ),
        child: Icon(
          Icons.restart_alt_rounded,
          color: AppColors.textSecondary,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    final newBest = _game.score >= _game.highScore && _game.score > 0;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('💥', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 12),
                Text(
                  _game.gameOverReason,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                if (newBest)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'NEW BEST!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statColumn('Score', '${_game.score}', AppColors.gold),
                    _statColumn(
                      'Distance',
                      '${_game.meters.toInt()} m',
                      AppColors.primaryLight,
                    ),
                    _statColumn(
                      'Coins',
                      '${_game.coinsCollected}',
                      AppColors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                GradientButton(
                  text: 'Race Again',
                  icon: Icons.refresh_rounded,
                  onPressed: _restart,
                  height: 52,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
