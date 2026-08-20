import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/common_widgets.dart';
import 'select_mode_screen.dart';

class GameDetailsScreen extends StatelessWidget {
  final GameModel game;

  const GameDetailsScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.42,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    game.bgColor,
                    game.bgColor.withOpacity(0.5),
                    AppColors.background,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 40,
                    left: 40,
                    child: Icon(
                      Icons.sports_motorsports_rounded,
                      size: 48,
                      color: game.accentColor.withOpacity(0.1),
                    ),
                  ),
                  Positioned(
                    bottom: 60,
                    right: 20,
                    child: Icon(
                      Icons.star_rounded,
                      size: 32,
                      color: AppColors.gold.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        const AppBackButton(),
                        const Spacer(),
                        _buildIconButton(Icons.favorite_border_rounded, true),
                        const SizedBox(width: 10),
                        _buildIconButton(Icons.more_vert_rounded, false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            game.bgColor,
                            game.bgColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: game.accentColor.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: game.accentColor.withOpacity(0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(game.icon, style: const TextStyle(fontSize: 90)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          game.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildPill(_getCategoryName(game.category), AppColors.primaryLight),
                            const SizedBox(width: 8),
                            _buildPill('Single Player', AppColors.token),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
                                const SizedBox(width: 4),
                                Text(
                                  game.rating.toString(),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_alt_rounded, size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  '${_formatPlayers(game.players)} Players',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Drive fast, avoid obstacles and become the ultimate racer!',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary.withOpacity(0.9),
                              ),
                        ),
                        const SizedBox(height: 28),
                        GradientButton(
                          text: 'Play Now',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SelectModeScreen()),
                            );
                          },
                          width: double.infinity,
                          height: 56,
                          borderRadius: 18,
                        ),
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'About Game',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Speed Racer is an endless racing game where you compete with your best score and other players.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      height: 1.6,
                                      color: AppColors.textSecondary.withOpacity(0.9),
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatItem('Size', game.size),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 36,
                                    color: AppColors.cardBorder,
                                  ),
                                  Expanded(
                                    child: _buildStatItem('Best Score', '${game.bestScore}'),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 36,
                                    color: AppColors.cardBorder,
                                  ),
                                  Expanded(
                                    child: _buildStatItem('Played', '${game.playedCount} Times'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, bool isActive) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Icon(
        icon,
        size: 20,
        color: isActive ? AppColors.accentLight : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(GameCategory c) {
    return c.toString().split('.').last[0].toUpperCase() +
        c.toString().split('.').last.substring(1);
  }

  String _formatPlayers(int p) {
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(1)}K';
    return p.toString();
  }
}
