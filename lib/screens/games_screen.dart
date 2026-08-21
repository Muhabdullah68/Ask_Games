import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../games/tictactoe/tic_tac_toe_screen.dart';
import '../games/dotsboxes/dots_boxes_screen.dart';
import '../games/snake/snake_screen.dart';
import '../games/bubble/bubble_shooter_screen.dart';
import 'game_details_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final allGames = [
      ...AppConstants.continuePlayingGames,
      ...AppConstants.popularGames,
    ];
    final categories = ['All', 'Racing', 'Arcade', 'Board', 'Puzzle', 'Action'];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Games',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 20),
              _buildCategoryChips(categories),
              const SizedBox(height: 20),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: allGames.length,
                itemBuilder: (_, i) {
                  final game = allGames[i];
                  return _buildGridGameCard(context, game);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search games...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted.withOpacity(0.8),
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: selected ? AppColors.buttonGradient : null,
              color: selected ? null : AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.transparent : AppColors.cardBorder,
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              categories[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridGameCard(BuildContext context, GameModel game) {
    return GestureDetector(
      onTap: () {
        if (game.id == 'tictactoe') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TicTacToeScreen()),
          );
        } else if (game.id == 'dotsboxes') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DotsBoxesScreen()),
          );
        } else if (game.id == 'snake') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SnakeScreen()),
          );
        } else if (game.id == 'bubble') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BubbleShooterScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GameDetailsScreen(game: game)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [game.bgColor, AppColors.cardBg],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: game.accentColor.withOpacity(0.25),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: game.bgColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(game.icon, style: const TextStyle(fontSize: 52)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
                const SizedBox(width: 3),
                Text(
                  game.rating.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: 18,
                  color: game.accentColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
