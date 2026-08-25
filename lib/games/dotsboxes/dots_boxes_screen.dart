import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'dots_boxes_engine.dart';

class DotsBoxesScreen extends StatefulWidget {
  const DotsBoxesScreen({super.key});

  @override
  State<DotsBoxesScreen> createState() => _DotsBoxesScreenState();
}

class _DotsBoxesScreenState extends State<DotsBoxesScreen>
    with TickerProviderStateMixin {
  late final DotsBoxesGame _game;
  late AnimationController _winOverlayController;
  late List<AnimationController> _lineAnimations;
  late List<AnimationController> _boxAnimations;
  Timer? _aiTimer;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _game = DotsBoxesGame(gridSize: 4);
    _winOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _lineAnimations = List.generate(
      (_game.gridSize + 1) * _game.gridSize +
          _game.gridSize * (_game.gridSize + 1),
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );
    _boxAnimations = List.generate(
      _game.gridSize * _game.gridSize,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
    );
    _maybeAIMove();
  }

  @override
  void dispose() {
    _winOverlayController.dispose();
    for (final a in _lineAnimations) {
      a.dispose();
    }
    for (final a in _boxAnimations) {
      a.dispose();
    }
    _aiTimer?.cancel();
    super.dispose();
  }

  int _hLineIdx(int r, int c) => r * _game.gridSize + c;
  int _vLineIdx(int r, int c) =>
      (_game.gridSize + 1) * _game.gridSize + r * (_game.gridSize + 1) + c;

  void _onHorizontalTap(int r, int c) {
    if (_animating || _game.isGameOver || _game.isAITurn) return;
    if (_game.horizontalLines[r][c].drawn) return;

    final prevP1 = _game.player1Score;
    final prevP2 = _game.player2Score;
    final drawn = _game.drawHorizontalLine(r, c);
    if (drawn) {
      _lineAnimations[_hLineIdx(r, c)].forward(from: 0);
      _checkBoxAnimations(prevP1, prevP2);
      _checkAndShowEnd();
      _maybeAIMove();
    }
  }

  void _onVerticalTap(int r, int c) {
    if (_animating || _game.isGameOver || _game.isAITurn) return;
    if (_game.verticalLines[r][c].drawn) return;

    final prevP1 = _game.player1Score;
    final prevP2 = _game.player2Score;
    final drawn = _game.drawVerticalLine(r, c);
    if (drawn) {
      _lineAnimations[_vLineIdx(r, c)].forward(from: 0);
      _checkBoxAnimations(prevP1, prevP2);
      _checkAndShowEnd();
      _maybeAIMove();
    }
  }

  void _checkBoxAnimations(int prevP1, int prevP2) {
    if (_game.player1Score != prevP1 || _game.player2Score != prevP2) {
      for (int r = 0; r < _game.gridSize; r++) {
        for (int c = 0; c < _game.gridSize; c++) {
          if (_game.boxes[r][c].isComplete &&
              !_boxAnimations[r * _game.gridSize + c].isCompleted &&
              !_boxAnimations[r * _game.gridSize + c].isAnimating) {
            _boxAnimations[r * _game.gridSize + c].forward(from: 0);
          }
        }
      }
    }
  }

  void _maybeAIMove() {
    if (!_game.isAITurn) return;
    _animating = true;
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final prevP1 = _game.player1Score;
      final prevP2 = _game.player2Score;
      _game.aiMove();
      _animateLastLine();
      _checkBoxAnimations(prevP1, prevP2);
      setState(() {
        _animating = false;
      });
      _checkAndShowEnd();
      _maybeAIMove();
    });
  }

  void _animateLastLine() {
    for (int r = 0; r <= _game.gridSize; r++) {
      for (int c = 0; c < _game.gridSize; c++) {
        if (_game.horizontalLines[r][c].drawn &&
            !_lineAnimations[_hLineIdx(r, c)].isCompleted &&
            !_lineAnimations[_hLineIdx(r, c)].isAnimating) {
          _lineAnimations[_hLineIdx(r, c)].forward(from: 0);
          return;
        }
      }
    }
    for (int r = 0; r < _game.gridSize; r++) {
      for (int c = 0; c <= _game.gridSize; c++) {
        if (_game.verticalLines[r][c].drawn &&
            !_lineAnimations[_vLineIdx(r, c)].isCompleted &&
            !_lineAnimations[_vLineIdx(r, c)].isAnimating) {
          _lineAnimations[_vLineIdx(r, c)].forward(from: 0);
          return;
        }
      }
    }
  }

  void _checkAndShowEnd() {
    if (mounted && _game.isGameOver) {
      setState(() {});
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _winOverlayController.forward();
      });
    } else {
      setState(() {});
    }
  }

  void _newGame() {
    _winOverlayController.reverse();
    setState(() {
      _game.resetBoard();
      for (final a in _lineAnimations) {
        a.reset();
      }
      for (final a in _boxAnimations) {
        a.reset();
      }
    });
    _maybeAIMove();
  }

  void _resetAll() {
    _winOverlayController.reverse();
    setState(() {
      _game.resetScores();
      for (final a in _lineAnimations) {
        a.reset();
      }
      for (final a in _boxAnimations) {
        a.reset();
      }
    });
  }

  void _setDifficulty(DotsDifficulty d) {
    if (_game.difficulty == d) return;
    _winOverlayController.reverse();
    setState(() {
      _game.difficulty = d;
      _game.resetBoard();
      for (final a in _lineAnimations) {
        a.reset();
      }
      for (final a in _boxAnimations) {
        a.reset();
      }
    });
    _maybeAIMove();
  }

  void _setMode(DotsGameMode m) {
    if (_game.mode == m) return;
    _winOverlayController.reverse();
    setState(() {
      _game.mode = m;
      _game.resetBoard();
      for (final a in _lineAnimations) {
        a.reset();
      }
      for (final a in _boxAnimations) {
        a.reset();
      }
    });
    _maybeAIMove();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
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
                    Color(0xFF1A1A2E),
                    Color(0xFF0F172A),
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
                      Icons.grid_3x3_rounded,
                      size: 60,
                      color: AppColors.token.withValues(alpha: 0.1),
                    ),
                  ),
                  Positioned(
                    left: 40,
                    bottom: 50,
                    child: Icon(
                      Icons.square_rounded,
                      size: 50,
                      color: AppColors.accentLight.withValues(alpha: 0.1),
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
                        'Dots & Boxes',
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
                        _buildTurnIndicator(),
                        const SizedBox(height: 22),
                        _buildGameBoard(),
                        const SizedBox(height: 28),
                        _buildDifficultySelector(),
                        const SizedBox(height: 16),
                        _buildModeSelector(),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: GradientButton(
                                text: 'New Game',
                                icon: Icons.refresh_rounded,
                                onPressed: _newGame,
                                height: 50,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: BorderedButton(
                                text: 'Reset Scores',
                                onPressed: _resetAll,
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
    );
  }

  Widget _buildScoreRow() {
    return Row(
      children: [
        Expanded(
          child: _buildScoreCard(
            label: _game.mode == DotsGameMode.pve ? 'You (P1)' : 'Player 1',
            value: _game.humanPlayer == DotsPlayer.player1
                ? _game.player1Score
                : _game.player2Score,
            gradient: const LinearGradient(
              colors: [Color(0xFF34D399), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: '🟢',
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
              const Text('📦', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                '${_game.remainingBoxes}',
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
            label: _game.mode == DotsGameMode.pve ? 'AI (P2)' : 'Player 2',
            value: _game.humanPlayer == DotsPlayer.player1
                ? _game.player2Score
                : _game.player1Score,
            gradient: const LinearGradient(
              colors: [Color(0xFFF472B6), Color(0xFFDB2777)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: '🔴',
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

  Widget _buildTurnIndicator() {
    final turnLabel = _game.isGameOver
        ? 'Game Over'
        : _game.isAITurn
        ? 'AI is thinking...'
        : _game.currentTurn == DotsPlayer.player1
        ? (_game.mode == DotsGameMode.pve ? "Your Turn" : "Player 1's Turn")
        : (_game.mode == DotsGameMode.pve ? "AI's Turn" : "Player 2's Turn");
    final turnIcon = _game.currentTurn == DotsPlayer.player1 ? '🟢' : '🔴';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
        boxShadow: [
          if (_game.isAITurn)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
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
              child: _game.isGameOver
                  ? const Icon(
                      Icons.timer_off_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    )
                  : _game.isAITurn
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryLight,
                      ),
                    )
                  : Text(turnIcon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Text(
              turnLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _game.isAITurn
                    ? AppColors.primaryLight
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E1638).withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: AppColors.token.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final boardSize = constraints.maxWidth - 36;
          final n = _game.gridSize;
          final gap = boardSize / n;
          final dotSize = gap * 0.18;

          return Container(
            width: boardSize,
            height: boardSize,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                ..._buildBoxes(n, gap, dotSize),
                ..._buildHorizontalLines(n, gap, dotSize),
                ..._buildVerticalLines(n, gap, dotSize),
                ..._buildDots(n, gap, dotSize),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildBoxes(int n, double gap, double dotSize) {
    final widgets = <Widget>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final box = _game.boxes[r][c];
        final anim = _boxAnimations[r * n + c];
        final left = c * gap + dotSize / 2;
        final top = r * gap + dotSize / 2;
        final size = gap - dotSize;

        widgets.add(
          Positioned(
            left: left,
            top: top,
            width: size,
            height: size,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.elasticOut),
              ),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: box.owner == DotsPlayer.none
                      ? null
                      : box.owner == DotsPlayer.player1
                      ? Color(0xFF059669).withValues(alpha: 0.35)
                      : Color(0xFFDB2777).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: box.owner != DotsPlayer.none
                      ? Border.all(
                          color: box.owner == DotsPlayer.player1
                              ? Color(0xFF34D399)
                              : Color(0xFFF472B6),
                          width: 1.2,
                        )
                      : null,
                ),
                child: Center(
                  child: box.owner != DotsPlayer.none
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            box.owner == DotsPlayer.player1 ? 'P1' : 'P2',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: box.owner == DotsPlayer.player1
                                  ? Color(0xFF34D399)
                                  : Color(0xFFF472B6),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildHorizontalLines(int n, double gap, double dotSize) {
    final widgets = <Widget>[];
    for (int r = 0; r <= n; r++) {
      for (int c = 0; c < n; c++) {
        final line = _game.horizontalLines[r][c];
        final anim = _lineAnimations[_hLineIdx(r, c)];
        final left = c * gap + dotSize / 2;
        final top = r * gap;
        final lineLength = gap - dotSize;
        final thickness = dotSize * 0.55;
        final bandHeight = gap * 0.55;

        final color = line.owner == DotsPlayer.none
            ? AppColors.cardBorder.withValues(alpha: 0.4)
            : line.owner == DotsPlayer.player1
            ? const Color(0xFF34D399)
            : const Color(0xFFF472B6);

        widgets.add(
          Positioned(
            left: left,
            top: top + dotSize / 2 - bandHeight / 2,
            width: gap,
            height: bandHeight,
            child: GestureDetector(
              onTap: () => _onHorizontalTap(r, c),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: AnimatedBuilder(
                  animation: anim,
                  builder: (_, _) {
                    return Container(
                      width:
                          lineLength *
                              (line.drawn
                                  ? 1.0
                                  : (line.drawn ? anim.value : 0.0)) +
                          (line.drawn ? 0 : lineLength * 0.15),
                      height: thickness,
                      decoration: BoxDecoration(
                        color: line.drawn ? color : Colors.transparent,
                        borderRadius: BorderRadius.circular(thickness / 2),
                        boxShadow: line.drawn
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        if (!line.drawn) {
          widgets.add(
            Positioned(
              left: left + lineLength * 0.4,
              top: top + dotSize / 2 - 2,
              child: IgnorePointer(
                child: Container(
                  width: lineLength * 0.2,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildVerticalLines(int n, double gap, double dotSize) {
    final widgets = <Widget>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c <= n; c++) {
        final line = _game.verticalLines[r][c];
        final anim = _lineAnimations[_vLineIdx(r, c)];
        final left = c * gap;
        final top = r * gap + dotSize / 2;
        final lineLength = gap - dotSize;
        final thickness = dotSize * 0.55;
        final bandWidth = gap * 0.55;

        final color = line.owner == DotsPlayer.none
            ? AppColors.cardBorder.withValues(alpha: 0.4)
            : line.owner == DotsPlayer.player1
            ? const Color(0xFF34D399)
            : const Color(0xFFF472B6);

        widgets.add(
          Positioned(
            left: left + dotSize / 2 - bandWidth / 2,
            top: top,
            width: bandWidth,
            height: gap,
            child: GestureDetector(
              onTap: () => _onVerticalTap(r, c),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: AnimatedBuilder(
                  animation: anim,
                  builder: (_, _) {
                    return Container(
                      width: thickness,
                      height:
                          lineLength * (line.drawn ? 1.0 : 0.0) +
                          (line.drawn ? 0 : lineLength * 0.15),
                      decoration: BoxDecoration(
                        color: line.drawn ? color : Colors.transparent,
                        borderRadius: BorderRadius.circular(thickness / 2),
                        boxShadow: line.drawn
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        if (!line.drawn) {
          widgets.add(
            Positioned(
              left: left + dotSize / 2 - 2,
              top: top + lineLength * 0.4,
              child: IgnorePointer(
                child: Container(
                  width: 4,
                  height: lineLength * 0.2,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildDots(int n, double gap, double dotSize) {
    final widgets = <Widget>[];
    for (int r = 0; r <= n; r++) {
      for (int c = 0; c <= n; c++) {
        widgets.add(
          Positioned(
            left: c * gap,
            top: r * gap,
            width: dotSize,
            height: dotSize,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFC4B5FD), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildDifficultySelector() {
    final options = [
      DotsDifficulty.easy,
      DotsDifficulty.medium,
      DotsDifficulty.hard,
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

  Widget _buildModeSelector() {
    const options = [DotsGameMode.pve, DotsGameMode.pvp];
    const labels = ['vs AI', '2 Players'];
    const icons = ['🤖', '👥'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final selected = _game.mode == options[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => _setMode(options[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.buttonGradient : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(icons[i], style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
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
          ignoring: !_game.isGameOver,
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
                      colors: [Color(0xFF1E1638), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.cardBorder, width: 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEndEmoji(),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _buildEndTitle(),
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
                        _buildEndSubtitle(),
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
                                  '🟢',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_game.player1Score}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: Color(0xFF34D399)),
                                ),
                              ],
                            ),
                            Text(
                              ':',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Column(
                              children: [
                                const Text(
                                  '🔴',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_game.player2Score}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: Color(0xFFF472B6)),
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
                          icon: Icons.play_arrow_rounded,
                          onPressed: _newGame,
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

  Widget _buildEndEmoji() {
    final winner = _game.getWinner();
    String emoji = '🎮';
    if (winner == DotsPlayer.none) {
      emoji = '🤝';
    } else {
      final pve = _game.mode == DotsGameMode.pve;
      final humanWon = pve && winner == _game.humanPlayer;
      final aiWon = pve && winner == _game.aiPlayer;
      if (pve && humanWon) emoji = '🏆';
      if (pve && aiWon) emoji = '🤖';
      if (!pve) emoji = '🎉';
    }
    return Text(emoji, style: const TextStyle(fontSize: 64));
  }

  String _buildEndTitle() {
    final winner = _game.getWinner();
    if (winner == DotsPlayer.none) return "It's a Draw!";
    final pve = _game.mode == DotsGameMode.pve;
    if (pve) {
      return winner == _game.humanPlayer ? 'You Win!' : 'AI Wins!';
    }
    return 'Player ${winner == DotsPlayer.player1 ? '1' : '2'} Wins!';
  }

  String _buildEndSubtitle() {
    final winner = _game.getWinner();
    if (winner == DotsPlayer.none) return 'Perfectly matched!';
    final pve = _game.mode == DotsGameMode.pve;
    if (pve && winner == _game.humanPlayer) {
      return 'Amazing! You outboxed the AI!';
    }
    if (pve) return 'Try again — capture those boxes!';
    return 'Excellent strategy!';
  }
}
