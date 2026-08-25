import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/game_widgets.dart';
import '../games/tictactoe/tic_tac_toe_screen.dart';
import '../games/dotsboxes/dots_boxes_screen.dart';
import '../games/snake/snake_screen.dart';
import '../games/bubble/bubble_shooter_screen.dart';
import '../games/fruitninja/fruit_ninja_screen.dart';
import '../games/racer/racer_screen.dart';
import '../games/ludo/ludo_screen.dart';
import '../games/carrom/carrom_screen.dart';
import 'game_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bannerIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildCurrencyRow(),
              const SizedBox(height: 18),
              _buildBannerCarousel(),
              const SizedBox(height: 22),
              const SectionHeader(
                title: 'Continue Playing',
                icon: Icons.play_circle_fill_rounded,
              ),
              const SizedBox(height: 14),
              _buildContinuePlaying(),
              const SizedBox(height: 22),
              const SectionHeader(
                title: 'Popular Games',
                icon: Icons.local_fire_department_rounded,
              ),
              const SizedBox(height: 14),
              _buildPopularGames(),
              const SizedBox(height: 22),
              _buildDailyRewardsCard(),
              const SizedBox(height: 22),
              const SectionHeader(
                title: 'Achievements',
                icon: Icons.star_rounded,
              ),
              const SizedBox(height: 14),
              _buildAchievements(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              AppConstants.currentPlayer.avatar,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      AppConstants.currentPlayer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencyRow() {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: const [
                CurrencyChip(
                  icon: '🪙',
                  amount: 12450,
                  bgColor: AppColors.gold,
                ),
                SizedBox(width: 8),
                CurrencyChip(icon: '💎', amount: 250, bgColor: AppColors.gem),
                SizedBox(width: 8),
                CurrencyChip(icon: '🔷', amount: 35, bgColor: AppColors.token),
                SizedBox(width: 12),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCarousel() {
    final banners = [
      _buildBannerCard(
        title: 'PLAY\nFUN GAMES',
        subtitle: 'All your favorite games\nin one place!',
        buttonText: 'Explore Now',
        icon: '🎮',
      ),
      _buildBannerCard(
        title: 'TOURNAMENT\nLIVE NOW',
        subtitle: 'Join the big battle\nwin huge rewards!',
        buttonText: 'Join Now',
        icon: '🏆',
      ),
      _buildBannerCard(
        title: 'NEW GAMES\nADDED!',
        subtitle: 'Discover fresh\ngaming experiences',
        buttonText: 'Check Now',
        icon: '🎲',
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemCount: banners.length,
            itemBuilder: (_, i) => banners[i],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _bannerIndex == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: _bannerIndex == i ? AppColors.primaryGradient : null,
                color: _bannerIndex == i ? null : AppColors.cardBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required String icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: AppColors.bannerGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: 10,
            child: Text(
              '⭐',
              style: TextStyle(
                fontSize: 28,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            right: 36,
            bottom: 16,
            child: Text(
              '🪙',
              style: TextStyle(
                fontSize: 22,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 8,
            child: Text(
              '💎',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (_, constraints) {
                final maxIconSize = constraints.maxWidth * 0.36;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    height: 1.05,
                                    letterSpacing: -0.5,
                                    fontSize: 24,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.9,
                                    ),
                                    height: 1.3,
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 38,
                            width: 120,
                            child: GradientButton(
                              text: buttonText,
                              onPressed: () {},
                              height: 38,
                              borderRadius: 12,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: constraints.maxHeight * 0.8,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(icon),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuePlaying() {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: AppConstants.continuePlayingGames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final game = AppConstants.continuePlayingGames[i];
          return ContinueGameCard(
            game: game,
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
                  MaterialPageRoute(
                    builder: (_) => const BubbleShooterScreen(),
                  ),
                );
              } else if (game.id == 'fruit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FruitNinjaScreen()),
                );
              } else if (game.id == 'speed') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SpeedRacerScreen()),
                );
              } else if (game.id == 'ludo') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LudoScreen()),
                );
              } else if (game.id == 'carrom') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CarromScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailsScreen(game: game),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildPopularGames() {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: AppConstants.popularGames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final game = AppConstants.popularGames[i];
          return PopularGameCard(
            game: game,
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
                  MaterialPageRoute(
                    builder: (_) => const BubbleShooterScreen(),
                  ),
                );
              } else if (game.id == 'fruit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FruitNinjaScreen()),
                );
              } else if (game.id == 'speed') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SpeedRacerScreen()),
                );
              } else if (game.id == 'ludo') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LudoScreen()),
                );
              } else if (game.id == 'carrom') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CarromScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailsScreen(game: game),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildDailyRewardsCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 130),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF581C87), Color(0xFF701A75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -8,
            child: Text(
              '✨',
              style: TextStyle(
                fontSize: 40,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Rewards',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          'Play daily and claim exciting rewards!',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 40,
                        width: 116,
                        child: GradientButton(
                          text: 'Claim Now',
                          onPressed: () {},
                          height: 40,
                          borderRadius: 12,
                          gradient: AppColors.goldGradient,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  height: 76,
                  child: const FittedBox(
                    fit: BoxFit.contain,
                    child: Text('🎁'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: AppConstants.achievements.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          return AchievementBadge(achievement: AppConstants.achievements[i]);
        },
      ),
    );
  }
}
