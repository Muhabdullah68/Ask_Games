import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'tic_tac_toe_engine.dart';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen>
    with TickerProviderStateMixin {
  late final TicTacToeGame _game;
  late List<AnimationController> _markAnimations;
  late AnimationController _winOverlayController;
  Timer? _aiTimer;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _game = TicTacToeGame();
    _markAnimations = List.generate(
      9,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
      ),
    );
    _winOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _maybeAIMove();
  }

  @override
  void dispose() {
    for (final a in _markAnimations) {
      a.dispose();
    }
    _winOverlayController.dispose();
    _aiTimer?.cancel();
    super.dispose();
  }

  void _onCellTap(int r, int c) {
    if (_animating || _game.isGameOver || _game.isAITurn) return;

    final idx = r * 3 + c;
    if (_game.board[r][c].owner != Player.none) return;

    final moved = _game.makeMove(r, c);
    if (moved) {
      _markAnimations[idx].forward(from: 0);
      _checkAndShowEnd();
      _maybeAIMove();
    }
  }

  void _maybeAIMove() {
    if (!_game.isAITurn) return;
    _animating = true;
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _game.aiMove();
      final pos = _findLastMove();
      if (pos != null) {
        _markAnimations[pos].forward(from: 0);
      }
      setState(() {
        _animating = false;
      });
      _checkAndShowEnd();
    });
  }

  int? _findLastMove() {
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (_game.board[r][c].owner != Player.none &&
            !_markAnimations[r * 3 + c].isCompleted &&
            !_markAnimations[r * 3 + c].isAnimating) {
          return r * 3 + c;
        }
      }
    }
    return null;
  }

  void _checkAndShowEnd() {
    if (mounted && _game.isGameOver) {
      setState(() {});
      Future.delayed(const Duration(milliseconds: 400), () {
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
      for (final a in _markAnimations) {
        a.reset();
      }
    });
    _maybeAIMove();
  }

  void _resetAll() {
    _winOverlayController.reverse();
    setState(() {
      _game.resetScores();
      for (final a in _markAnimations) {
        a.reset();
      }
    });
  }

  void _setDifficulty(Difficulty d) {
    if (_game.difficulty == d) return;
    _winOverlayController.reverse();
    setState(() {
      _game.difficulty = d;
      _game.resetBoard();
      for (final a in _markAnimations) {
        a.reset();
      }
    });
    _maybeAIMove();
  }

  void _setMode(GameMode m) {
    if (_game.mode == m) return;
    _winOverlayController.reverse();
    setState(() {
      _game.mode = m;
      _game.resetBoard();
      for (final a in _markAnimations) {
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
                  colors: [Color(0xFF1A1A2E), Color(0xFF3B0764), AppColors.background],
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
                      Icons.sports_esports_rounded,
                      size: 60,
                      color: AppColors.accentLight.withValues(alpha: 0.1),
                    ),
                  ),
                  Positioned(
                    left: 40,
                    bottom: 50,
                    child: Icon(
                      Icons.circle_outlined,
                      size: 50,
                      color: AppColors.gem.withValues(alpha: 0.1),
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
                        'Tic Tac Toe',
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
            label: 'Player (X)',
            value: _game.humanPlayer == Player.x ? _game.xScore : _game.oScore,
            gradient: LinearGradient(
              colors: [const Color(0xFFE879F9), const Color(0xFFC026D3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: '❌',
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
              const Text('🤝', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                '${_game.draws}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildScoreCard(
            label: _game.mode == GameMode.pve ? 'AI (O)' : 'Player 2 (O)',
            value: _game.humanPlayer == Player.x ? _game.oScore : _game.xScore,
            gradient: LinearGradient(
              colors: [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: '⭕',
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
            : _game.currentTurn == Player.x
                ? "Player X's Turn"
                : _game.mode == GameMode.pve
                    ? 'AI O Turn'
                    : "Player O's Turn";
    final turnIcon = _game.currentTurn == Player.x ? '❌' : '⭕';

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
                  ? const Icon(Icons.timer_off_rounded, size: 20, color: AppColors.textSecondary)
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
            const Color(0xFF1A1333),
            const Color(0xFF1E1638).withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final boardSize = constraints.maxWidth - 4;
          final cellSize = (boardSize - 16) / 3;

          return Container(
            width: boardSize,
            height: boardSize,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: Column(
                children: List.generate(3, (r) {
                  return Expanded(
                    child: Row(
                      children: List.generate(3, (c) {
                        final idx = r * 3 + c;
                        final cell = _game.board[r][c];
                        return Expanded(
                          child: _buildCell(
                            r,
                            c,
                            cell,
                            cellSize,
                            _markAnimations[idx],
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCell(
    int r,
    int c,
    Cell cell,
    double cellSize,
    AnimationController anim,
  ) {
    final borderColor = cell.isWinning
        ? AppColors.gold
        : AppColors.cardBorder.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.all(cell.isWinning ? 0 : 3),
        decoration: BoxDecoration(
          gradient: cell.isWinning
              ? LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.25),
                    AppColors.gold.withValues(alpha: 0.05),
                  ],
                )
              : null,
          color: cell.isWinning ? null : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: cell.isWinning ? 1.2 : 0.5,
          ),
          boxShadow: cell.isWinning
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: cell.owner == Player.none
              ? null
              : ScaleTransition(
                  scale: Tween<double>(begin: 0.3, end: 1).animate(
                    CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                  ),
                  child: _buildMark(cell.owner, cellSize),
                ),
        ),
      ),
    );
  }

  Widget _buildMark(Player owner, double size) {
    final isX = owner == Player.x;
    final color = isX ? const Color(0xFFE879F9) : const Color(0xFF60A5FA);
    final glow = isX ? AppColors.accent : AppColors.token;

    return SizedBox(
      width: size * 0.6,
      height: size * 0.6,
      child: CustomPaint(
        painter: _MarkPainter(
          isX: isX,
          color: color,
          glowColor: glow,
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    final options = [Difficulty.easy, Difficulty.medium, Difficulty.hard];
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
    const options = [GameMode.pve, GameMode.pvp];
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
                          color: selected ? Colors.white : AppColors.textSecondary,
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
                      colors: [Color(0xFF1E1638), Color(0xFF2A1F52)],
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
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
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
    if (winner == Player.none) {
      emoji = '🤝';
    } else {
      final pve = _game.mode == GameMode.pve;
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
    if (winner == Player.none) return "It's a Draw!";
    final pve = _game.mode == GameMode.pve;
    if (pve) {
      return winner == _game.humanPlayer ? 'You Win!' : 'AI Wins!';
    }
    return 'Player ${winner == Player.x ? 'X' : 'O'} Wins!';
  }

  String _buildEndSubtitle() {
    final winner = _game.getWinner();
    if (winner == Player.none) return 'Well played by both sides.';
    final pve = _game.mode == GameMode.pve;
    if (pve && winner == _game.humanPlayer) {
      return 'Amazing! You outsmarted the AI!';
    }
    if (pve) return 'Try again — can you beat it?';
    return 'Excellent strategy!';
  }
}

class _MarkPainter extends CustomPainter {
  final bool isX;
  final Color color;
  final Color glowColor;

  _MarkPainter({
    required this.isX,
    required this.color,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = glowColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isX) {
      final pad = size.width * 0.16;
      canvas.drawLine(
        Offset(pad, pad),
        Offset(size.width - pad, size.height - pad),
        glow,
      );
      canvas.drawLine(
        Offset(size.width - pad, pad),
        Offset(pad, size.height - pad),
        glow,
      );
      canvas.drawLine(
        Offset(pad, pad),
        Offset(size.width - pad, size.height - pad),
        paint,
      );
      canvas.drawLine(
        Offset(size.width - pad, pad),
        Offset(pad, size.height - pad),
        paint,
      );
    } else {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.width * 0.36;
      canvas.drawCircle(center, radius, glow);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.isX != isX ||
      oldDelegate.color != color ||
      oldDelegate.glowColor != glowColor;
}
