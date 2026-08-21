import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'bubble_shooter_engine.dart';

class BubbleShooterScreen extends StatefulWidget {
  const BubbleShooterScreen({super.key});
  @override
  State<BubbleShooterScreen> createState() => _BubbleShooterScreenState();
}

class _BubbleShooterScreenState extends State<BubbleShooterScreen>
    with TickerProviderStateMixin {
  late final BubbleShooterGame _game;
  late AnimationController _shootAnim;
  late AnimationController _popAnim;
  late AnimationController _winOverlayController;
  Timer? _aiTimer;

  double _aimAngle = pi / 2;
  bool _isAiming = false;
  bool _isAnimating = false;
  bool _playerShotInFlight = false;
  BubbleColor _shootingColor = BubbleColor.red;
  bool _shootingIsBomb = false;
  final Set<String> _poppingCells = {};
  final Map<String, BubbleColor> _poppingColors = {};
  final Set<String> _poppingBombs = {};
  Size _boardSize = Size.zero;
  double _cellSize = 0;
  final GlobalKey _boardKey = GlobalKey();
  List<Offset> _previewPath = const [];
  List<int>? _previewLanding;
  List<Offset> _flightPath = const [];
  List<double> _flightSegLens = const [];
  double _flightTotalLen = 1;

  @override
  void initState() {
    super.initState();
    _game = BubbleShooterGame(difficulty: BubbleDifficulty.medium);
    _shootAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))
      ..addListener(() => setState(() {}));
    _popAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
      ..addListener(() {
        setState(() {});
        if (_popAnim.isCompleted) _onPopComplete();
      });
    _winOverlayController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _shootAnim.dispose();
    _popAnim.dispose();
    _winOverlayController.dispose();
    _aiTimer?.cancel();
    super.dispose();
  }

  Offset get _cannonPos => Offset(_boardSize.width / 2, _boardSize.height);

  void _onPanStart(DragStartDetails d) {
    if (_isAnimating || _game.isGameOver || _game.isAITurn) return;
    _updateAim(d.localPosition);
    setState(() => _isAiming = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isAnimating || _game.isGameOver || _game.isAITurn) return;
    _updateAim(d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isAnimating || _game.isGameOver || !_isAiming || _game.isAITurn) return;
    setState(() => _isAiming = false);
    _firePlayerShot(_aimAngle);
  }

  void _updateAim(Offset pos) {
    if (_boardSize.width == 0) return;
    final delta = pos - _cannonPos;
    double angle = atan2(-delta.dy, delta.dx);
    if (angle.isNaN) angle = pi / 2;
    _aimAngle = angle.clamp(BubbleShooterGame.minAimAngle, pi - BubbleShooterGame.minAimAngle);
    _refreshPreview();
    setState(() {});
  }

  void _refreshPreview() {
    if (_boardSize.width == 0) return;
    final sim = _game.simulateShot(_aimAngle);
    _previewPath = sim.points.map((p) => Offset(p[0] * _cellSize, p[1] * _cellSize)).toList();
    _previewLanding = sim.landing;
  }

  void _firePlayerShot(double angle) {
    if (_isAnimating) return;
    _isAnimating = true;
    _shootingColor = _game.currentColor;
    _shootingIsBomb = _game.currentIsBomb;

    final sim = _game.simulateShot(angle);
    if (sim.landing == null) {
      _game.shootAtAngle(angle);
      _isAnimating = false;
      setState(() {});
      _checkAfterShot();
      return;
    }
    _setFlightPath(sim.points);
    _playerShotInFlight = true;
    _shootAnim.forward(from: 0).then((_) {
      if (_playerShotInFlight) _onShootLanded();
    });
  }

  void _setFlightPath(List<List<double>> gridPoints) {
    _flightPath = gridPoints.map((p) => Offset(p[0] * _cellSize, p[1] * _cellSize)).toList();
    final lens = <double>[];
    double total = 0;
    for (int i = 1; i < _flightPath.length; i++) {
      final l = (_flightPath[i] - _flightPath[i - 1]).distance;
      lens.add(l);
      total += l;
    }
    _flightSegLens = lens;
    _flightTotalLen = total <= 0 ? 1 : total;
  }

  void _onShootLanded() {
    _playerShotInFlight = false;
    final result = _game.shootAtAngle(_aimAngle);
    _shootAnim.reset();
    setState(() {});
    if (result != null && result.matchedAny) {
      _startPopAnimation(result);
    } else {
      _isAnimating = false;
      _checkAfterShot();
    }
  }

  void _startPopAnimation(ShootResult result) {
    _poppingCells.clear();
    _poppingColors.clear();
    _poppingBombs.clear();
    for (final p in result.matched) {
      _poppingCells.add('${p[0]},${p[1]}');
    }
    for (final p in result.dropped) {
      _poppingCells.add('${p[0]},${p[1]}');
    }
    result.popped.forEach((key, bubble) {
      _poppingColors[key] = bubble.color;
      if (bubble.isBomb) _poppingBombs.add(key);
    });
    _popAnim.forward(from: 0);
  }

  void _onPopComplete() {
    _poppingCells.clear();
    _poppingColors.clear();
    _poppingBombs.clear();
    setState(() {});
    _isAnimating = false;
    _checkAfterShot();
  }

  void _checkAfterShot() {
    if (_game.isGameOver) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _winOverlayController.forward();
      });
      return;
    }
    if (_game.isAITurn) _scheduleAIMove();
  }

  void _scheduleAIMove() {
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _game.isGameOver) return;
      _fireAIShot();
    });
  }

  void _fireAIShot() {
    _isAnimating = true;
    final result = _game.aiShoot();
    if (result != null && result.path.isNotEmpty) {
      _shootingColor = result.placedColor;
      _shootingIsBomb = result.placedIsBomb;
      _setFlightPath(result.path);
      _shootAnim.forward(from: 0).then((_) {
        if (!mounted) return;
        _shootAnim.reset();
        setState(() {});
        if (result.matchedAny) {
          _startPopAnimation(result);
        } else {
          _isAnimating = false;
          setState(() {});
          _checkAfterShot();
        }
      });
    } else {
      _isAnimating = false;
      setState(() {});
      _checkAfterShot();
    }
  }

  void _newGame() {
    _winOverlayController.reverse();
    _aiTimer?.cancel();
    _playerShotInFlight = false;
    _shootAnim.reset();
    _popAnim.reset();
    setState(() {
      _game.resetBoard();
      _isAnimating = false;
      _poppingCells.clear();
      _poppingColors.clear();
      _poppingBombs.clear();
      _flightPath = const [];
      _previewLanding = null;
      _refreshPreview();
    });
  }

  void _resetAll() {
    _winOverlayController.reverse();
    _aiTimer?.cancel();
    _playerShotInFlight = false;
    _shootAnim.reset();
    _popAnim.reset();
    setState(() {
      _game.resetScores();
      _isAnimating = false;
      _poppingCells.clear();
      _poppingColors.clear();
      _poppingBombs.clear();
      _flightPath = const [];
      _refreshPreview();
    });
  }

  void _setDifficulty(BubbleDifficulty d) {
    if (_game.difficulty == d) return;
    _winOverlayController.reverse();
    _aiTimer?.cancel();
    _playerShotInFlight = false;
    _shootAnim.reset();
    setState(() {
      _game.setDifficulty(d);
      _isAnimating = false;
      _poppingCells.clear();
      _poppingColors.clear();
      _poppingBombs.clear();
      _flightPath = const [];
      _refreshPreview();
    });
  }

  void _setMode(BubbleGameMode m) {
    if (_game.mode == m) return;
    _winOverlayController.reverse();
    _aiTimer?.cancel();
    _playerShotInFlight = false;
    _shootAnim.reset();
    setState(() {
      _game.setMode(m);
      _isAnimating = false;
      _poppingCells.clear();
      _poppingColors.clear();
      _poppingBombs.clear();
      _flightPath = const [];
      _refreshPreview();
    });
  }

  void _swapAmmo() {
    if (_isAnimating || _game.isAITurn || _game.isGameOver) return;
    setState(() => _game.swapAmmo());
  }

  static const Color _bombBase = Color(0xFF4B5563);
  static const Color _bombGlow = Color(0xFF1F2937);

  Color _bColor(BubbleColor c) => switch (c) {
    BubbleColor.red => const Color(0xFFEF4444),
    BubbleColor.blue => const Color(0xFF3B82F6),
    BubbleColor.green => const Color(0xFF22C55E),
    BubbleColor.yellow => const Color(0xFFFBBF24),
    BubbleColor.purple => const Color(0xFFA855F7),
    BubbleColor.orange => const Color(0xFFF97316),
  };

  Color _bGlow(BubbleColor c) => switch (c) {
    BubbleColor.red => const Color(0xFFDC2626),
    BubbleColor.blue => const Color(0xFF2563EB),
    BubbleColor.green => const Color(0xFF16A34A),
    BubbleColor.yellow => const Color(0xFFD97706),
    BubbleColor.purple => const Color(0xFF9333EA),
    BubbleColor.orange => const Color(0xFFEA580C),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(top: 0, left: 0, right: 0,
          height: MediaQuery.of(context).size.height * 0.38,
          child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF0F2942), AppColors.background],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            child: Stack(children: [
              Positioned(top: 30, right: 30, child: Icon(Icons.bubble_chart_rounded, size: 60, color: AppColors.token.withValues(alpha: 0.1))),
              Positioned(left: 40, bottom: 50, child: Icon(Icons.circle, size: 50, color: AppColors.primaryLight.withValues(alpha: 0.1))),
            ]))),
        SafeArea(bottom: false, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(children: [const AppBackButton(), const Spacer(),
              Text('Bubble Shooter', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(), const SizedBox(width: 40)])),
          const SizedBox(height: 12),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Column(children: [
              _buildScoreRow(), const SizedBox(height: 12),
              _buildStatus(), const SizedBox(height: 12),
              _buildBoard(), const SizedBox(height: 10),
              _buildShooterArea(), const SizedBox(height: 14),
              _buildDifficulty(), const SizedBox(height: 8),
              _buildMode(), const SizedBox(height: 14),
              Row(children: [
                Expanded(child: GradientButton(text: 'New Game', icon: Icons.refresh_rounded, onPressed: _newGame, height: 46)),
                const SizedBox(width: 12),
                Expanded(child: BorderedButton(text: 'Reset Scores', onPressed: _resetAll, borderRadius: 14)),
              ]),
            ]))),
      ])),
      _buildEndOverlay(),
    ]));
  }

  Widget _buildScoreRow() {
    if (_game.mode == BubbleGameMode.pve) {
      return Row(children: [
        Expanded(child: _scoreCard('You', _game.playerScore, const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]), '🔵', highlight: !_game.isAITurn && !_game.isGameOver)),
        const SizedBox(width: 6),
        Container(width: 44, height: 60, decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder, width: 0.5)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${_game.shotsUntilNewRow}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _game.shotsUntilNewRow <= 2 ? AppColors.red : AppColors.gold)),
            const Text('🛒', style: TextStyle(fontSize: 12))])),
        const SizedBox(width: 6),
        Expanded(child: _scoreCard('AI', _game.aiScore, const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]), '🟠', highlight: _game.isAITurn)),
      ]);
    }
    return Row(children: [
      Expanded(child: _scoreCard('Score', _game.playerScore, const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]), '🎯')),
      const SizedBox(width: 8),
      Container(width: 50, height: 60, decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder, width: 0.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${_game.shotsUntilNewRow}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _game.shotsUntilNewRow <= 2 ? AppColors.red : AppColors.gold)),
          const Text('🛒', style: TextStyle(fontSize: 12))])),
      const SizedBox(width: 8),
      Expanded(child: _scoreCard('Best', _game.highScore, const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFD97706)]), '🏆')),
    ]);
  }

  Widget _scoreCard(String label, int value, Gradient g, String icon, {bool highlight = false}) {
    return AnimatedContainer(duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? AppColors.primaryLight : AppColors.cardBorder, width: highlight ? 1.2 : 0.5),
        boxShadow: highlight ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10)] : null),
      child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 16)), const SizedBox(width: 5),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w600))),
          const SizedBox(height: 1),
          Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, foreground: Paint()..shader = g.createShader(const Rect.fromLTWH(0, 0, 100, 1)))),
        ])])));
  }

  Widget _buildStatus() {
    final isAI = _game.isAITurn, isOver = _game.isGameOver, isWon = _game.state == BubbleGameState.won;
    String label; Color color; Widget leading;
    if (isOver && isWon) { label = _game.mode == BubbleGameMode.pve ? 'You Win! Board Cleared!' : 'Board Cleared!'; color = AppColors.green; leading = const Icon(Icons.emoji_events_rounded, size: 18, color: AppColors.gold); }
    else if (isOver) {
      label = _game.mode == BubbleGameMode.pve ? (_game.playerScore > _game.aiScore ? 'You Win!' : _game.playerScore < _game.aiScore ? 'AI Wins!' : "It's a Draw!") : 'Game Over!';
      color = _game.playerScore >= _game.aiScore ? AppColors.green : AppColors.red;
      leading = Text(_game.playerScore >= _game.aiScore ? '🏆' : '💀', style: const TextStyle(fontSize: 16));
    } else if (isAI) { label = 'AI is shooting...'; color = AppColors.primaryLight; leading = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight));
    } else if (_isAnimating) { label = 'Clearing...'; color = AppColors.gold; leading = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold));
    } else { label = 'Drag to aim, release to shoot! Tap Next to swap!'; color = AppColors.green; leading = Icon(Icons.touch_app_rounded, size: 18, color: color); }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder, width: 0.5),
        boxShadow: [if (isAI || _isAnimating) BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10)]),
      child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: leading), const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color))])));
  }

  Widget _buildBoard() {
    return Container(key: _boardKey, width: double.infinity, padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF0B1D33), const Color(0xFF132E4F).withValues(alpha: 0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder, width: 0.6),
        boxShadow: [BoxShadow(color: AppColors.token.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))]),
      child: GestureDetector(onPanStart: _onPanStart, onPanUpdate: _onPanUpdate, onPanEnd: _onPanEnd,
        child: LayoutBuilder(builder: (_, c) {
          final bw = c.maxWidth - 20; _cellSize = bw / _game.gridCols;
          final bh = _cellSize * _game.gridRows * 0.88; _boardSize = Size(bw, bh);
          return Container(width: bw, height: bh,
            decoration: BoxDecoration(color: const Color(0xFF0A1628).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
            child: ClipRRect(borderRadius: BorderRadius.circular(14),
              child: CustomPaint(size: Size(bw, bh),
                painter: BubbleGridPainter(game: _game, cellSize: _cellSize, boardSize: _boardSize,
                  aimAngle: _aimAngle, isAiming: _isAiming, shootVal: _shootAnim.value,
                  shootColor: _shootingColor, shootIsBomb: _shootingIsBomb,
                  currentAmmoColor: _game.currentColor, currentAmmoIsBomb: _game.currentIsBomb,
                  previewPath: _previewPath, previewLanding: _previewLanding,
                  flightPath: _flightPath, flightSegLens: _flightSegLens, flightTotalLen: _flightTotalLen,
                  popVal: _popAnim.value, popping: _poppingCells, poppingColors: _poppingColors,
                  poppingBombs: _poppingBombs,
                  bColor: _bColor, bGlow: _bGlow))));
        })));
  }

  Widget _buildShooterArea() {
    final canSwap = !_isAnimating && !_game.isAITurn && !_game.isGameOver;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder, width: 0.5)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(onTap: canSwap ? _swapAmmo : null,
          child: _preview('Next', _game.nextColor, 28, isBomb: _game.nextIsBomb, tappable: canSwap)),
        const SizedBox(width: 10),
        GestureDetector(onTap: canSwap ? _swapAmmo : null,
          child: Icon(Icons.swap_horiz_rounded, size: 22,
            color: canSwap ? AppColors.primaryLight : AppColors.textMuted.withValues(alpha: 0.4))),
        const SizedBox(width: 10),
        Container(width: 1, height: 32, color: AppColors.cardBorder), const SizedBox(width: 16),
        _preview('Ready', _game.currentColor, 36, isBomb: _game.currentIsBomb),
        if (_game.mode == BubbleGameMode.pve) ...[
          const SizedBox(width: 16), Container(width: 1, height: 32, color: AppColors.cardBorder), const SizedBox(width: 16),
          Column(children: [
            Text('Turn', style: TextStyle(fontSize: 8, color: _game.isAITurn ? AppColors.primaryLight : AppColors.green, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            AnimatedSwitcher(duration: const Duration(milliseconds: 200),
              child: Text(_game.isAITurn ? '🤖' : '🧑', key: ValueKey(_game.isAITurn), style: const TextStyle(fontSize: 20))),
          ]),
        ]]));
  }

  Widget _preview(String label, BubbleColor color, double size, {bool isBomb = false, bool tappable = false}) {
    final base = isBomb ? _bombBase : _bColor(color);
    final glow = isBomb ? _bombGlow : _bGlow(color);
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      AnimatedSwitcher(duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween<double>(begin: -0.25, end: 0).animate(anim),
          child: FadeTransition(opacity: anim, child: child)),
        child: Container(key: ValueKey('$color-$isBomb'),
          width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [base, glow], center: const Alignment(-0.3, -0.3)),
            boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.5), blurRadius: size * 0.3)],
            border: tappable ? Border.all(color: AppColors.primaryLight.withValues(alpha: 0.8), width: 1.2) : null),
          child: isBomb ? Center(child: Text('💣', style: TextStyle(fontSize: size * 0.48))) : null)),
    ]);
  }

  Widget _buildDifficulty() {
    final opts = [BubbleDifficulty.easy, BubbleDifficulty.medium, BubbleDifficulty.hard];
    final lbl = ['Easy', 'Medium', 'Hard'];
    final clr = [AppColors.green, AppColors.gold, AppColors.red];
    return Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
      child: Row(children: List.generate(3, (i) {
        final sel = _game.difficulty == opts[i];
        return Expanded(child: GestureDetector(onTap: () => _setDifficulty(opts[i]),
          child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(gradient: sel ? LinearGradient(colors: [clr[i].withValues(alpha: 0.7), clr[i]]) : null, borderRadius: BorderRadius.circular(7)),
            child: Center(child: Text(lbl[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary))))));
      })));
  }

  Widget _buildMode() {
    const opts = [BubbleGameMode.solo, BubbleGameMode.pve];
    const lbl = ['Solo', 'vs AI'];
    const ico = ['🎯', '🤖'];
    return Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
      child: Row(children: List.generate(2, (i) {
        final sel = _game.mode == opts[i];
        return Expanded(child: GestureDetector(onTap: () => _setMode(opts[i]),
          child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(gradient: sel ? AppColors.buttonGradient : null, borderRadius: BorderRadius.circular(7),
              boxShadow: sel ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))] : null),
            child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(ico[i], style: const TextStyle(fontSize: 12)), const SizedBox(width: 4),
              Text(lbl[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary))])))));
      })));
  }

  Widget _buildEndOverlay() {
    return FadeTransition(opacity: _winOverlayController,
      child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(CurvedAnimation(parent: _winOverlayController, curve: Curves.easeOut)),
        child: IgnorePointer(ignoring: !_game.isGameOver,
          child: Container(color: Colors.black.withValues(alpha: 0.6),
            child: Center(child: Container(margin: const EdgeInsets.all(28), padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E1638), Color(0xFF0F2942)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.cardBorder, width: 0.7),
                boxShadow: [BoxShadow(color: (_game.state == BubbleGameState.won ? AppColors.green : AppColors.red).withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 16))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_game.state == BubbleGameState.won ? '🏆' : '💀', style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                FittedBox(fit: BoxFit.scaleDown, child: Text(_endTitle(), style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.textPrimary, height: 1.2), textAlign: TextAlign.center)),
                const SizedBox(height: 6),
                Text(_endSub(), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 14), _endScores(),
                const SizedBox(height: 20),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180),
                  child: GradientButton(text: 'Play Again', icon: Icons.refresh_rounded, onPressed: _newGame, height: 46)),
              ])))))));
  }

  String _endTitle() {
    if (_game.state == BubbleGameState.won) return _game.mode == BubbleGameMode.pve ? 'You Win!' : 'Board Cleared!';
    if (_game.mode == BubbleGameMode.pve) return _game.playerScore > _game.aiScore ? 'You Win!' : _game.playerScore < _game.aiScore ? 'AI Wins!' : "It's a Draw!";
    return 'Game Over!';
  }

  String _endSub() {
    if (_game.state == BubbleGameState.won) return _game.mode == BubbleGameMode.pve ? 'You cleared the board before the AI!' : 'Amazing — every bubble popped!';
    if (_game.mode == BubbleGameMode.pve) {
      if (_game.playerScore > _game.aiScore) return 'You scored higher than the AI!';
      if (_game.playerScore < _game.aiScore) return 'The AI outscored you this time.';
      return 'Perfectly matched scores!';
    }
    return 'Great try! Ready for another round?';
  }

  Widget _endScores() {
    if (_game.mode == BubbleGameMode.pve) {
      return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Column(children: [const Text('🔵', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 3), Text('${_game.playerScore}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color(0xFF60A5FA))),
            Text('You', style: Theme.of(context).textTheme.bodySmall)]),
          Text('vs', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted)),
          Column(children: [const Text('🟠', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 3), Text('${_game.aiScore}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color(0xFFF97316))),
            Text('AI', style: Theme.of(context).textTheme.bodySmall)]),
        ]));
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Column(children: [const Text('🎯', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 3), Text('${_game.playerScore}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color(0xFF60A5FA))),
          Text('Score', style: Theme.of(context).textTheme.bodySmall)]),
        Container(width: 1, height: 32, color: AppColors.cardBorder),
        Column(children: [const Text('🏆', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 3), Text('${_game.highScore}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.gold)),
          Text('Best', style: Theme.of(context).textTheme.bodySmall)]),
      ]));
  }
}

class BubbleGridPainter extends CustomPainter {
  final BubbleShooterGame game;
  final double cellSize, aimAngle;
  final Size boardSize;
  final bool isAiming;
  final double shootVal, popVal;
  final BubbleColor shootColor;
  final bool shootIsBomb;
  final BubbleColor currentAmmoColor;
  final bool currentAmmoIsBomb;
  final List<Offset> previewPath;
  final List<int>? previewLanding;
  final List<Offset> flightPath;
  final List<double> flightSegLens;
  final double flightTotalLen;
  final Set<String> popping;
  final Map<String, BubbleColor> poppingColors;
  final Set<String> poppingBombs;
  final Color Function(BubbleColor) bColor;
  final Color Function(BubbleColor) bGlow;

  static const Color _bombBase = Color(0xFF4B5563);
  static const Color _bombGlow = Color(0xFF1F2937);

  BubbleGridPainter({
    required this.game, required this.cellSize, required this.boardSize,
    required this.aimAngle, required this.isAiming,
    required this.shootVal, required this.shootColor, required this.shootIsBomb,
    required this.currentAmmoColor, required this.currentAmmoIsBomb,
    required this.previewPath, required this.previewLanding,
    required this.flightPath, required this.flightSegLens, required this.flightTotalLen,
    required this.popVal, required this.popping,
    required this.poppingColors, required this.poppingBombs,
    required this.bColor, required this.bGlow,
  });

  @override
  void paint(Canvas c, Size s) {
    _drawBackground(c, s);
    _drawGrid(c);
    _drawTrajectory(c);
    _drawCannon(c, s);
    _drawShootingBubble(c);
    if (game.isGameOver) _drawGameOverOverlay(c, s);
  }

  Offset _cellCenter(int row, int col) {
    final offset = row % 2 != 0 ? cellSize * 0.5 : 0.0;
    return Offset(offset + col * cellSize + cellSize * 0.5, row * cellSize * 0.88 + cellSize * 0.5);
  }

  void _drawBackground(Canvas c, Size s) {
    final bg = Paint()..shader = const LinearGradient(
      colors: [Color(0xFF0A1628), Color(0xFF0F1E32)],
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, s.width, s.height));
    c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), bg);
  }

  void _drawGrid(Canvas c) {
    for (int row = 0; row < game.gridRows; row++) {
      final cols = game.colsInRow(row);
      for (int col = 0; col < cols; col++) {
        final bubble = game.grid[row][col];
        final center = _cellCenter(row, col);
        final key = '$row,$col';
        if (popping.contains(key)) {
          _drawPoppingBubble(c, center.dx, center.dy, poppingColors[key] ?? bubble?.color,
              poppingBombs.contains(key));
          continue;
        }
        if (bubble == null) {
          _drawEmptyCell(c, center.dx, center.dy, row);
          continue;
        }
        _drawBubble(c, center.dx, center.dy, bubble.color, bubble.isBomb);
      }
    }
  }

  void _drawEmptyCell(Canvas c, double cx, double cy, int row) {
    final r = cellSize * 0.36;
    final bgPaint = Paint()..color = const Color(0xFF1A2E45).withValues(alpha: row < 2 ? 0.3 : 0.5);
    bgPaint.style = PaintingStyle.fill;
    c.drawCircle(Offset(cx, cy), r, bgPaint);
  }

  void _drawBubble(Canvas c, double cx, double cy, BubbleColor color, bool isBomb) {
    final r = cellSize * 0.4;
    final base = isBomb ? _bombBase : bColor(color);
    final glow = isBomb ? _bombGlow : bGlow(color);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [base, glow],
        center: const Alignment(-0.3, -0.3), radius: 0.8,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset(cx, cy), r, paint);

    final innerGlow = Paint()..color = glow.withValues(alpha: 0.3);
    c.drawCircle(Offset(cx, cy), r * 0.6, innerGlow);

    final shine = Paint()..color = Colors.white.withValues(alpha: 0.25);
    c.drawCircle(Offset(cx - r * 0.22, cy - r * 0.22), r * 0.14, shine);

    if (isBomb) _drawFuse(c, cx, cy, r, 255);
  }

  void _drawFuse(Canvas c, double cx, double cy, double r, int alpha) {
    final sparkPos = Offset(cx + r * 0.38, cy - r * 0.55);
    final spark = Paint()..color = const Color(0xFFFBBF24).withValues(alpha: alpha / 255);
    c.drawCircle(sparkPos, r * 0.18, spark);
    final core = Paint()..color = Colors.white.withValues(alpha: alpha / 255);
    c.drawCircle(sparkPos, r * 0.08, core);
  }

  void _drawPoppingBubble(Canvas c, double cx, double cy, BubbleColor? color, bool isBomb) {
    if (color == null && !isBomb) return;
    final t = popVal.clamp(0.0, 1.0);
    final r = cellSize * 0.4 * (1 - t);
    if (r <= 0) return;

    final alpha = (255 * (1 - t)).round().clamp(0, 255);
    final base = isBomb ? _bombBase : bColor(color!);
    final glow = isBomb ? _bombGlow : bGlow(color!);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [base.withValues(alpha: alpha / 255), glow.withValues(alpha: alpha / 255)],
        center: const Alignment(-0.3, -0.3), radius: 0.8,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset(cx, cy), r, paint);

    if (isBomb) _drawFuse(c, cx, cy, r, alpha);
  }

  void _drawTrajectory(Canvas c) {
    if (!isAiming || shootVal > 0 || previewPath.length < 2) return;
    final lineColor = shootIsBomb ? const Color(0xFF9CA3AF) : bColor(shootColor);

    for (int i = 1; i < previewPath.length; i++) {
      final fade = (1 - i / previewPath.length).clamp(0.25, 1.0);
      final segPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.75 * fade)
        ..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round;
      c.drawLine(previewPath[i - 1], previewPath[i], segPaint);
    }

    final landing = previewLanding;
    if (landing != null) {
      final center = _cellCenter(landing[0], landing[1]);
      final ring = Paint()
        ..color = lineColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke..strokeWidth = 2;
      c.drawCircle(center, cellSize * 0.4, ring);
      final fill = Paint()..color = lineColor.withValues(alpha: 0.12);
      c.drawCircle(center, cellSize * 0.4, fill);
    }
  }

  void _drawCannon(Canvas c, Size s) {
    if (game.isGameOver) return;
    final base = Offset(s.width / 2, s.height - cellSize * 0.12);
    final dir = Offset(cos(aimAngle), -sin(aimAngle));

    final barrelEnd = base + dir * (cellSize * 0.62);
    final barrel = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = cellSize * 0.2..strokeCap = StrokeCap.round;
    c.drawLine(base, barrelEnd, barrel);

    final body = Paint()..shader = const RadialGradient(
      colors: [Color(0xFF2C3E54), Color(0xFF101B2B)],
      center: Alignment(-0.3, -0.3),
    ).createShader(Rect.fromCircle(center: base, radius: cellSize * 0.42));
    c.drawCircle(base, cellSize * 0.42, body);
    c.drawCircle(base, cellSize * 0.42, Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    final ammoR = cellSize * 0.22;
    final ammoBase = currentAmmoIsBomb ? _bombBase : bColor(currentAmmoColor);
    final ammoGlow = currentAmmoIsBomb ? _bombGlow : bGlow(currentAmmoColor);
    final ammo = Paint()..shader = RadialGradient(
      colors: [ammoBase, ammoGlow],
      center: const Alignment(-0.3, -0.3),
    ).createShader(Rect.fromCircle(center: base, radius: ammoR));
    c.drawCircle(base, ammoR, ammo);
    if (currentAmmoIsBomb) _drawFuse(c, base.dx, base.dy, ammoR, 255);
  }

  void _drawShootingBubble(Canvas c) {
    if (shootVal <= 0 || flightPath.length < 2) return;
    final dist = shootVal.clamp(0.0, 1.0) * flightTotalLen;

    Offset pos = flightPath.last;
    double acc = 0;
    for (int i = 0; i < flightSegLens.length; i++) {
      if (acc + flightSegLens[i] >= dist) {
        final t = flightSegLens[i] <= 0 ? 0.0 : (dist - acc) / flightSegLens[i];
        pos = Offset.lerp(flightPath[i], flightPath[i + 1], t)!;
        break;
      }
      acc += flightSegLens[i];
    }

    final r = cellSize * 0.38;
    final base = shootIsBomb ? _bombBase : bColor(shootColor);
    final glow = shootIsBomb ? _bombGlow : bGlow(shootColor);

    final trailOpacity = (0.35 * (1 - shootVal)).clamp(0.0, 0.35);
    final trail = Paint()..color = glow.withValues(alpha: trailOpacity);
    c.drawCircle(pos, r * 0.7, trail);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [base, glow],
        center: const Alignment(-0.3, -0.3), radius: 0.8,
      ).createShader(Rect.fromCircle(center: pos, radius: r))
      ..style = PaintingStyle.fill;
    c.drawCircle(pos, r, paint);

    final shine = Paint()..color = Colors.white.withValues(alpha: 0.35);
    c.drawCircle(Offset(pos.dx - r * 0.2, pos.dy - r * 0.2), r * 0.12, shine);
    if (shootIsBomb) _drawFuse(c, pos.dx, pos.dy, r, 255);
  }

  void _drawGameOverOverlay(Canvas c, Size s) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.15);
    c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), overlayPaint);
    final linePaint = Paint()..color = Colors.white24..strokeWidth = 1;
    for (int row = 0; row < game.gridRows; row++) {
      final y = row * cellSize * 0.88 + cellSize * 0.5;
      c.drawLine(Offset(0, y), Offset(s.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(BubbleGridPainter old) {
    return old.game != game || old.shootVal != shootVal || old.popVal != popVal
        || old.aimAngle != aimAngle || old.isAiming != isAiming
        || old.popping != popping || old.poppingColors != poppingColors
        || old.poppingBombs != poppingBombs || old.shootIsBomb != shootIsBomb
        || old.previewPath != previewPath || old.flightPath != flightPath
        || old.shootColor != shootColor;
  }
}
