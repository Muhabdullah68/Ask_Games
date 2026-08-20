import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';

class ContinueGameCard extends StatelessWidget {
  final GameModel game;
  final VoidCallback onTap;
  final double width;

  const ContinueGameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.width = 140,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [game.bgColor, AppColors.cardBg],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: game.accentColor.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: game.bgColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  game.icon,
                  style: const TextStyle(fontSize: 56),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              game.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LinearPercentIndicator(
                    padding: EdgeInsets.zero,
                    lineHeight: 4,
                    animation: true,
                    percent: game.progress,
                    backgroundColor: AppColors.cardBorder.withOpacity(0.5),
                    progressColor: game.accentColor,
                    barRadius: const Radius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(game.progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: game.accentColor,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PopularGameCard extends StatelessWidget {
  final GameModel game;
  final VoidCallback onTap;
  final double width;

  const PopularGameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.width = 100,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [game.bgColor, AppColors.cardBg],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: game.accentColor.withOpacity(0.25),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: game.bgColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  game.icon,
                  style: const TextStyle(fontSize: 44),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              game.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.2,
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
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AchievementBadge extends StatelessWidget {
  final AchievementModel achievement;
  final double size;
  final VoidCallback? onTap;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.size = 56,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: achievement.unlocked
              ? LinearGradient(
                  colors: [
                    achievement.color.withOpacity(0.3),
                    achievement.color.withOpacity(0.1),
                  ],
                )
              : null,
          color: achievement.unlocked ? null : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: achievement.unlocked
                ? achievement.color.withOpacity(0.4)
                : AppColors.cardBorder,
            width: 0.5,
          ),
        ),
        child: Icon(
          achievement.icon,
          size: size * 0.48,
          color: achievement.unlocked ? achievement.color : AppColors.textMuted,
        ),
      ),
    );
  }
}

class SmallGameIcon extends StatelessWidget {
  final GameModel game;
  final double size;
  final VoidCallback? onTap;

  const SmallGameIcon({
    super.key,
    required this.game,
    this.size = 56,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [game.bgColor, AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: game.accentColor.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(game.icon, style: TextStyle(fontSize: size * 0.48)),
        ),
      ),
    );
  }
}
