import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'fruit_ninja_engine.dart';

class FruitNinjaScreen extends StatefulWidget {
  const FruitNinjaScreen({super.key});

  @override
  State<FruitNinjaScreen> createState() => _FruitNinjaScreenState();
}

class _FruitNinjaScreenState extends State<FruitNinjaScreen>
    with TickerProviderStateMixin {
  late final FruitNinjaGame _game;
  Timer? _gameLoop;
  Timer? _spawnTimer;
  late AnimationController _winOverlayController;

  Offset? _lastSwipePoint;
  bool _isSlicing = false;
  Size _boardSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _game = FruitNinjaGame();
    _winOverlayController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  void _startGame() {
    _game.start();
    _startLoops();
    _winOverlayController.reverse();
    setState(() {});
  }

  void _startLoops() {
    _gameLoop?.cancel();
    _spawnTimer?.cancel();

    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final wasOver = _game.state == FruitGameState.gameOver;
      if (_game.state == FruitGameState.playing ||
          _game.slicedFruits.isNotEmpty ||
          _game.swipeTrail.isNotEmpty ||
          _game.activeEffects.isNotEmpty) {
        setState(() {
          _game.update(0.016);
          if (_game.state == FruitGameState.gameOver && !wasOver) {
            _onGameOver();
          }
        });
      }
    });

    _scheduleNextSpawn();
  }

  void _scheduleNextSpawn() {
    if (_game.state == FruitGameState.gameOver) return;

    int interval = _game.getSpawnInterval();
    _spawnTimer = Timer(Duration(milliseconds: interval), () {
      if (_game.state == FruitGameState.playing && _boardSize.width > 0) {
        _game.spawnFruit(_boardSize.width, _boardSize.height);
        setState(() {});
      }
      _scheduleNextSpawn();
    });
  }

  void _onGameOver() {
    _spawnTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _winOverlayController.forward();
    });
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _spawnTimer?.cancel();
    _winOverlayController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_game.state != FruitGameState.playing) return;
    setState(() {
      _isSlicing = true;
      _lastSwipePoint = details.localPosition;
      _game.addSwipePoint(details.localPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_game.state != FruitGameState.playing || !_isSlicing) return;

    Offset current = details.localPosition;
    if (_lastSwipePoint != null && _boardSize.width > 0) {
      _game.checkSlice(
          _lastSwipePoint!, current, _boardSize.width, _boardSize.height);
      _game.addSwipePoint(current);
    }

    setState(() {
      _lastSwipePoint = current;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isSlicing = false;
      _lastSwipePoint = null;
    });
  }

  void _resetAll() {
    _winOverlayController.reverse();
    _gameLoop?.cancel();
    _spawnTimer?.cancel();
    setState(() {
      _game.highScore = 0;
      _game.reset();
    });
  }

  void _setDifficulty(FruitDifficulty d) {
    if (_game.difficulty == d) return;
    _winOverlayController.reverse();
    _gameLoop?.cancel();
    _spawnTimer?.cancel();
    setState(() {
      _game.difficulty = d;
      _game.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.38,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5C1B1C), Color(0xFF3D0A0A), AppColors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(children: [
              Positioned(
                top: 30,
                right: 30,
                child: Text('🍉',
                    style: TextStyle(
                        fontSize: 60,
                        color: AppColors.token.withValues(alpha: 0.12))),
              ),
              Positioned(
                left: 40,
                bottom: 50,
                child: Text('🔪',
                    style: TextStyle(
                        fontSize: 50,
                        color: AppColors.primaryLight.withValues(alpha: 0.12))),
              ),
              Positioned(
                top: 80,
                left: 80,
                child: Text('🍌',
                    style: TextStyle(
                        fontSize: 36,
                        color: AppColors.gold.withValues(alpha: 0.1))),
              ),
              Positioned(
                right: 90,
                bottom: 80,
                child: Text('🍊',
                    style: TextStyle(
                        fontSize: 32,
                        color: AppColors.orange.withValues(alpha: 0.1))),
              ),
            ]),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(children: [
                const AppBackButton(),
                const Spacer(),
                Text('Fruit Ninja',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                const SizedBox(width: 40)
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(children: [
                  _buildScoreRow(),
                  const SizedBox(height: 12),
                  _buildStatus(),
                  const SizedBox(height: 12),
                  _buildGameCanvas(),
                  const SizedBox(height: 14),
                  _buildDifficulty(),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: GradientButton(
                            text: _game.state == FruitGameState.idle
                                ? 'Play'
                                : 'New Game',
                            icon: Icons.play_arrow_rounded,
                            onPressed: _startGame,
                            height: 46)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: BorderedButton(
                            text: 'Reset Scores',
                            onPressed: _resetAll,
                            borderRadius: 14)),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
        _buildEndOverlay(),
      ]),
    );
  }

  Widget _buildScoreRow() {
    return Row(children: [
      Expanded(
          child: _scoreCard(
              'Score',
              _game.score,
              const LinearGradient(
                  colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]),
              '🍉')),
      const SizedBox(width: 6),
      Container(
        width: 44,
        height: 60,
        decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 0.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${_game.timeLeft.ceil()}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color:
                      _game.timeLeft <= 10 ? AppColors.red : AppColors.gold)),
          const Text('⏱️', style: TextStyle(fontSize: 12))
        ]),
      ),
      const SizedBox(width: 6),
      Expanded(
          child: _scoreCard(
              'Strikes',
              _game.bombStrikes,
              const LinearGradient(
                  colors: [Color(0xFFF87171), Color(0xFFDC2626)]),
              '💣',
              suffix: '/${_game.maxBombStrikes}',
              highlight: _game.bombStrikes > 0)),
      const SizedBox(width: 6),
      Expanded(
          child: _scoreCard(
              'Best',
              _game.highScore,
              const LinearGradient(
                  colors: [Color(0xFFFBBF24), Color(0xFFD97706)]),
              '🏆')),
    ]);
  }

  Widget _scoreCard(String label, int value, Gradient g, String icon,
      {String suffix = '', bool highlight = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: highlight ? AppColors.red : AppColors.cardBorder,
            width: highlight ? 1.2 : 0.5),
        boxShadow: highlight
            ? [
                BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.3), blurRadius: 10)
              ]
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 5),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600))),
            const SizedBox(height: 1),
            Text('$value$suffix',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    foreground: Paint()
                      ..shader =
                          g.createShader(const Rect.fromLTWH(0, 0, 100, 1)))),
          ])
        ]),
      ),
    );
  }

  Widget _buildStatus() {
    final isPlaying = _game.state == FruitGameState.playing;
    final isOver = _game.state == FruitGameState.gameOver;
    String label;
    Color color;
    Widget leading;
    if (isOver) {
      label = _game.gameOverReason.isEmpty
          ? 'Game Over'
          : _game.gameOverReason;
      color = AppColors.red;
      leading = const Text('💀', style: TextStyle(fontSize: 16));
    } else if (isPlaying) {
      label = _isSlicing
          ? 'Slicing...'
          : 'Swipe across the canvas to slice!';
      color = AppColors.green;
      leading = Icon(Icons.touch_app_rounded, size: 18, color: color);
    } else {
      label = 'Tap Play to start slicing fruits!';
      color = AppColors.primaryLight;
      leading = Icon(Icons.play_circle_fill_rounded, size: 18, color: color);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
          boxShadow: [
            if (_isSlicing)
              BoxShadow(
                  color: color.withValues(alpha: 0.2), blurRadius: 10)
          ]),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: leading),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: color))
        ]),
      ),
    );
  }

  Widget _buildGameCanvas() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [
              const Color(0xFF2B1036),
              const Color(0xFF3D0A0A).withValues(alpha: 0.7)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
              color: AppColors.token.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: LayoutBuilder(builder: (_, c) {
          final bw = c.maxWidth - 20;
          final bh = (c.maxHeight - 20).clamp(200.0, 520.0);
          if (_boardSize.width != bw || _boardSize.height != bh) {
            _boardSize = Size(bw, bh);
          }
          return Container(
            width: bw,
            height: bh,
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A18).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                  size: Size(bw, bh),
                  painter: FruitNinjaPainter(
                    game: _game,
                    isSlicing: _isSlicing,
                  )),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDifficulty() {
    final opts = [
      FruitDifficulty.easy,
      FruitDifficulty.medium,
      FruitDifficulty.hard
    ];
    final lbl = ['Easy', 'Medium', 'Hard'];
    final clr = [AppColors.green, AppColors.gold, AppColors.red];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10)),
      child: Row(
          children: List.generate(3, (i) {
        final sel = _game.difficulty == opts[i];
        return Expanded(
          child: GestureDetector(
            onTap: () => _setDifficulty(opts[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                gradient: sel
                    ? LinearGradient(
                        colors: [clr[i].withValues(alpha: 0.7), clr[i]])
                    : null,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                  child: Text(lbl[i],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? Colors.white
                              : AppColors.textSecondary))),
            ),
          ),
        );
      })),
    );
  }

  Widget _buildEndOverlay() {
    return FadeTransition(
      opacity: _winOverlayController,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(
            parent: _winOverlayController, curve: Curves.easeOut)),
        child: IgnorePointer(
          ignoring: _game.state != FruitGameState.gameOver,
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(28),
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF3D0A0A), Color(0xFF1E1638)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.cardBorder, width: 0.7),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 16))
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_endEmoji(),
                      style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_endTitle(),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                  color: AppColors.textPrimary, height: 1.2),
                          textAlign: TextAlign.center)),
                  const SizedBox(height: 6),
                  Text(_endSub(),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  _endScores(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                            text: 'Play Again',
                            icon: Icons.refresh_rounded,
                            onPressed: _startGame,
                            height: 46),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 70,
                        child: BorderedButton(
                            text: 'Menu',
                            onPressed: () => Navigator.pop(context),
                            borderRadius: 14),
                      ),
                    ],
                  )
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _endEmoji() {
    if (_game.score >= 300) return '🏆';
    if (_game.score >= 150) return '🔥';
    if (_game.gameOverReason == "Time's Up!") return '⏰';
    if (_game.bombStrikes >= _game.maxBombStrikes) return '💥';
    return '💀';
  }

  String _endTitle() {
    if (_game.score >= 300) return 'Slice Master!';
    if (_game.score >= 150) return 'Great Slicing!';
    return 'Game Over!';
  }

  String _endSub() {
    if (_game.gameOverReason == "Time's Up!") {
      return 'Time ran out. Keep slicing to beat your best!';
    }
    if (_game.bombStrikes >= _game.maxBombStrikes) {
      return 'You hit too many bombs. Watch out for the explosives!';
    }
    return 'Keep practicing to master your slicing skills.';
  }

  Widget _endScores() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Column(children: [
          const Text('🍉', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 3),
          Text('${_game.score}',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: const Color(0xFF60A5FA))),
          Text('Score', style: Theme.of(context).textTheme.bodySmall)
        ]),
        Container(width: 1, height: 32, color: AppColors.cardBorder),
        Column(children: [
          const Text('🏆', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 3),
          Text('${_game.highScore}',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.gold)),
          Text('Best', style: Theme.of(context).textTheme.bodySmall)
        ]),
      ]),
    );
  }
}

class FruitNinjaPainter extends CustomPainter {
  final FruitNinjaGame game;
  final bool isSlicing;

  FruitNinjaPainter({required this.game, required this.isSlicing});

  static const Map<FruitType, (Color base, Color glow, String emoji)>
      _fruitStyles = {
    FruitType.apple: (Color(0xFFEF4444), Color(0xFFDC2626), '🍎'),
    FruitType.orange: (Color(0xFFF97316), Color(0xFFEA580C), '🍊'),
    FruitType.watermelon: (Color(0xFF22C55E), Color(0xFF16A34A), '🍉'),
    FruitType.banana: (Color(0xFFFBBF24), Color(0xFFD97706), '🍌'),
    FruitType.coconut: (Color(0xFFA78BFA), Color(0xFF7C3AED), '🥥'),
  };

  static const Color _bombBase = Color(0xFF374151);
  static const Color _bombGlow = Color(0xFF1F2937);
  static const Color _bonusBase = Color(0xFF22D3EE);
  static const Color _bonusGlow = Color(0xFF0891B2);

  @override
  void paint(Canvas c, Size s) {
    _drawBackground(c, s);
    _drawSwipeTrail(c, s);
    for (final f in game.slicedFruits) {
      _drawSlicedFruit(c, s, f);
    }
    for (final f in game.activeFruits) {
      _drawWholeFruit(c, s, f);
    }
    for (final e in game.activeEffects) {
      _drawEffect(c, s, e);
    }
  }

  void _drawBackground(Canvas c, Size s) {
    final bg = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1A0A18), Color(0xFF2B1036), Color(0xFF1A0A18)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, s.width, s.height));
    c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), bg);

    final dots = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    final r = Random(42);
    for (int i = 0; i < 30; i++) {
      double x = r.nextDouble() * s.width;
      double y = r.nextDouble() * s.height;
      c.drawCircle(Offset(x, y), r.nextDouble() * 1.5 + 0.5, dots);
    }

    final linePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    double splitY = s.height * 0.82;
    c.drawLine(Offset(0, splitY), Offset(s.width, splitY), linePaint);
  }

  void _drawSwipeTrail(Canvas c, Size s) {
    final trail = game.swipeTrail;
    if (trail.length < 2) return;

    for (int pass = 0; pass < 2; pass++) {
      final isGlow = pass == 0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (isGlow) {
        paint.strokeWidth = 14;
      } else {
        paint.strokeWidth = 4;
      }
      for (int i = 1; i < trail.length; i++) {
        final lifeA = trail[i - 1].lifetime.clamp(0.0, 1.0);
        final lifeB = trail[i].lifetime.clamp(0.0, 1.0);
        if (lifeA <= 0.05 || lifeB <= 0.05) continue;
        final alphaA = isGlow ? lifeA * 0.35 : lifeA * 0.95;
        final alphaB = isGlow ? lifeB * 0.35 : lifeB * 0.95;
        final shader = LinearGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: alphaA),
            const Color(0xFFFFFFFF).withValues(alpha: alphaB),
          ],
        ).createShader(Rect.fromPoints(trail[i - 1].point, trail[i].point));
        paint.shader = shader;
        c.drawLine(trail[i - 1].point, trail[i].point, paint);
      }
    }
  }

  double _fruitRadius(Size s) => min(s.width, s.height) * 0.058;

  void _drawWholeFruit(Canvas c, Size s, Fruit f) {
    final r = _fruitRadius(s);
    final cx = f.x * s.width;
    final cy = f.y * s.height;

    if (cx < -r || cx > s.width + r || cy < -r || cy > s.height + r) return;

    c.save();
    c.translate(cx, cy);
    c.rotate(f.rotation);

    if (f.isBomb) {
      _drawBomb(c, r);
    } else if (f.isTimeBonus) {
      _drawTimeBonus(c, r);
    } else {
      final style = _fruitStyles[f.type] ?? _fruitStyles[FruitType.apple]!;
      _drawFruitBody(c, r, style.$1, style.$2, false);
      c.save();
      c.rotate(-f.rotation);
      _drawEmoji(c, style.$3, r * 1.1);
      c.restore();
    }
    c.restore();
  }

  void _drawSlicedFruit(Canvas c, Size s, Fruit f) {
    final life = f.slicedLifetime.clamp(0.0, 1.0);
    if (life <= 0.0) return;
    final alpha = (life).clamp(0.0, 1.0);
    final r = _fruitRadius(s) * (0.9 + life * 0.1);
    final c1 = Offset(f.half1X * s.width, f.half1Y * s.height);
    final c2 = Offset(f.half2X * s.width, f.half2Y * s.height);

    if (f.isBomb) {
      _drawExplosionHalf(c, c1, r, f.half1Rot, alpha, true);
      _drawExplosionHalf(c, c2, r, f.half2Rot, alpha, false);
      return;
    }
    if (f.isTimeBonus) {
      _drawBonusHalf(c, c1, r, f.half1Rot, alpha, true);
      _drawBonusHalf(c, c2, r, f.half2Rot, alpha, false);
      return;
    }
    final style = _fruitStyles[f.type] ?? _fruitStyles[FruitType.apple]!;
    _drawHalfCircle(c, c1, r, f.half1Rot, style.$1, style.$2, alpha, true);
    _drawHalfCircle(c, c2, r, f.half2Rot, style.$1, style.$2, alpha, false);
  }

  void _drawFruitBody(
      Canvas c, double r, Color base, Color glow, bool cut) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [base, glow],
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r))
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset.zero, r, paint);

    final ringPaint = Paint()
      ..color = glow.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08;
    c.drawCircle(Offset.zero, r * 0.92, ringPaint);

    final shine = Paint()..color = Colors.white.withValues(alpha: 0.32);
    c.drawCircle(
        Offset(-r * 0.28, -r * 0.28), r * 0.18, shine);
    final smallShine = Paint()..color = Colors.white.withValues(alpha: 0.18);
    c.drawCircle(
        Offset(r * 0.1, -r * 0.42), r * 0.08, smallShine);
  }

  void _drawHalfCircle(Canvas c, Offset center, double r, double rot,
      Color base, Color glow, double alpha, bool top) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(rot);

    final a = alpha;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    final baseWith = base.withValues(alpha: a);
    final glowWith = glow.withValues(alpha: a);

    final path = Path();
    if (top) {
      path.moveTo(-r, 0);
      path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: false);
    } else {
      path.moveTo(-r, 0);
      path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);
    }
    path.close();

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [baseWith, glowWith],
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    c.drawPath(path, paint);

    final cutLinePaint = Paint()
      ..color = glow.withValues(alpha: a * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, r * 0.06)
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(-r, 0), Offset(r, 0), cutLinePaint);

    final fleshPaint = Paint()
      ..color = const Color(0xFFFFF8E7).withValues(alpha: a * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, r * 0.035);
    c.drawLine(Offset(-r * 0.78, r * 0.0), Offset(r * 0.78, r * 0.0),
        fleshPaint);

    final shine = Paint()
      ..color = Colors.white.withValues(alpha: a * 0.3);
    c.drawCircle(
        Offset(-r * 0.28, top ? -r * 0.28 : r * 0.28), r * 0.14, shine);

    c.restore();
  }

  void _drawExplosionHalf(Canvas c, Offset center, double r, double rot,
      double alpha, bool top) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(rot);
    final a = alpha;
    final path = Path();
    if (top) {
      path.moveTo(-r, 0);
      path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: false);
    } else {
      path.moveTo(-r, 0);
      path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);
    }
    path.close();
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _bombBase.withValues(alpha: a),
          _bombGlow.withValues(alpha: a)
        ],
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r))
      ..style = PaintingStyle.fill;
    c.drawPath(path, paint);
    final cutLinePaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: a * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, r * 0.06)
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(-r, 0), Offset(r, 0), cutLinePaint);
    c.restore();
  }

  void _drawBonusHalf(Canvas c, Offset center, double r, double rot,
      double alpha, bool top) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(rot);
    final a = alpha;
    final path = Path();
    if (top) {
      path.moveTo(-r, 0);
      path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: false);
    } else {
      path.moveTo(-r, 0);
      path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);
    }
    path.close();
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _bonusBase.withValues(alpha: a),
          _bonusGlow.withValues(alpha: a)
        ],
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r))
      ..style = PaintingStyle.fill;
    c.drawPath(path, paint);
    final cutLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: a * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, r * 0.06)
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(-r, 0), Offset(r, 0), cutLinePaint);
    c.restore();
  }

  void _drawBomb(Canvas c, double r) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [_bombBase, _bombGlow],
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r))
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset.zero, r, paint);

    final spikes = 12;
    final spikePaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < spikes; i++) {
      final a = (i / spikes) * 2 * pi;
      final innerR = r * 0.92;
      final outerR = r * 1.14;
      final path = Path();
      final a1 = a - pi / spikes;
      final a2 = a + pi / spikes;
      path.moveTo(cos(a1) * innerR, sin(a1) * innerR);
      path.lineTo(cos(a) * outerR, sin(a) * outerR);
      path.lineTo(cos(a2) * innerR, sin(a2) * innerR);
      path.close();
      c.drawPath(path, spikePaint);
    }

    final outline = Paint()
      ..color = const Color(0xFF111827).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05;
    c.drawCircle(Offset.zero, r, outline);

    final shine = Paint()..color = Colors.white.withValues(alpha: 0.18);
    c.drawCircle(
        Offset(-r * 0.28, -r * 0.28), r * 0.14, shine);

    final fuseStart = Offset(r * 0.2, -r * 0.88);
    final fuseMid = Offset(r * 0.42, -r * 1.2);
    final fuseEnd = Offset(r * 0.3, -r * 1.42);
    final fusePaint = Paint()
      ..color = const Color(0xFF78716C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1
      ..strokeCap = StrokeCap.round;
    c.drawPath(
        Path()
          ..moveTo(fuseStart.dx, fuseStart.dy)
          ..quadraticBezierTo(
              fuseMid.dx, fuseMid.dy, fuseEnd.dx, fuseEnd.dy),
        fusePaint);

    final sparkR = r * 0.22;
    final sparkCenter = fuseEnd;
    final t = DateTime.now().millisecondsSinceEpoch / 200.0;
    final pulse = 0.85 + 0.15 * sin(t);
    final sparkOuter = Paint()
      ..color = const Color(0xFFFB923C).withValues(alpha: 0.5 * pulse);
    c.drawCircle(sparkCenter, sparkR * 1.8 * pulse, sparkOuter);
    final sparkMid = Paint()
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.85 * pulse);
    c.drawCircle(sparkCenter, sparkR * 1.1, sparkMid);
    final sparkCore = Paint()..color = const Color(0xFFFFFDE7);
    c.drawCircle(sparkCenter, sparkR * 0.5, sparkCore);
  }

  void _drawTimeBonus(Canvas c, double r) {
    final pulse = 0.9 + 0.1 * sin(DateTime.now().millisecondsSinceEpoch / 250.0);
    final actualR = r * pulse;

    final glowPaint = Paint()
      ..color = _bonusBase.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5);
    c.drawCircle(Offset.zero, actualR * 1.5, glowPaint);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [_bonusBase, _bonusGlow],
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: actualR))
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset.zero, actualR, paint);

    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08;
    c.drawCircle(Offset.zero, actualR * 0.92, ring);

    final shine = Paint()..color = Colors.white.withValues(alpha: 0.35);
    c.drawCircle(
        Offset(-r * 0.28, -r * 0.28), r * 0.16, shine);

    c.save();
    c.rotate(-(c.getSaveCount() > 0 ? 0.0 : 0.0));
    final iconPainter = TextPainter(
        text: TextSpan(
            text: '⏱️',
            style: TextStyle(
                fontSize: r * 1.15,
                shadows: [
                  Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 2)
                ])),
        textDirection: TextDirection.ltr);
    iconPainter.layout();
    iconPainter.paint(
        c, Offset(-iconPainter.width / 2, -iconPainter.height / 2));
    c.restore();
  }

  void _drawEmoji(Canvas c, String emoji, double size) {
    final painter = TextPainter(
        text: TextSpan(
            text: emoji,
            style: TextStyle(
                fontSize: size,
                shadows: [
                  Shadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 2,
                      offset: const Offset(0, 1))
                ])),
        textDirection: TextDirection.ltr);
    painter.layout();
    painter.paint(c, Offset(-painter.width / 2, -painter.height / 2));
  }

  void _drawEffect(Canvas c, Size s, SliceEffect e) {
    final life = e.lifetime.clamp(0.0, 1.0);
    if (life <= 0.0) return;
    final scale = 0.85 + (1.0 - life) * 0.55;
    final alpha = life;
    final floatY = (1.0 - life) * 65;

    c.save();
    c.translate(e.position.dx, e.position.dy - floatY);
    c.scale(scale);

    final bgR = Rect.fromLTWH(-60, -24, 120, 48);
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final rr = RRect.fromRectAndRadius(bgR, const Radius.circular(22));
    c.drawRRect(rr, bgPaint);
    final fillPaint = Paint()
      ..color = const Color(0xFF1A1333).withValues(alpha: alpha * 0.9);
    c.drawRRect(rr, fillPaint);
    final borderPaint = Paint()
      ..color = e.color.withValues(alpha: alpha * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    c.drawRRect(rr, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: e.text,
        style: TextStyle(
          color: e.color.withValues(alpha: alpha),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          shadows: [
            Shadow(
                color: e.color.withValues(alpha: alpha * 0.5),
                blurRadius: 6),
            Shadow(
                color: Colors.black.withValues(alpha: alpha * 0.6),
                blurRadius: 2,
                offset: const Offset(0, 1))
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
        c, Offset(-textPainter.width / 2, -textPainter.height / 2));

    c.restore();
  }

  @override
  bool shouldRepaint(covariant FruitNinjaPainter old) {
    return old.game != game || old.isSlicing != isSlicing;
  }
}
