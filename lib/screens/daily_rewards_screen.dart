import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/common_widgets.dart';

class DailyRewardsScreen extends StatelessWidget {
  const DailyRewardsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, showAppBar ? 12 : 20, 20, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAppBar)
                Row(
                  children: [
                    const AppBackButton(),
                    const Spacer(),
                    Text(
                      'Daily Rewards',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              if (!showAppBar)
                Text(
                  'Rewards',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              const SizedBox(height: 20),
              _buildComeBackCard(context),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Daily Rewards', showSeeAll: false),
              const SizedBox(height: 14),
              _buildDailyRewardsGrid(),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Tasks', showSeeAll: false),
              const SizedBox(height: 14),
              _buildTasksList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComeBackCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF581C87),
            const Color(0xFF701A75).withOpacity(0.8),
            const Color(0xFF4C1D95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryLight.withOpacity(0.25),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 40,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Come back tomorrow for\nmore rewards!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            height: 1.3,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                child: const Text('🎁', style: TextStyle(fontSize: 56)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRewardsGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(AppConstants.dailyRewards.length, (index) {
        final r = AppConstants.dailyRewards[index];
        return _buildRewardDayCard(r);
      }),
    );
  }

  Widget _buildRewardDayCard(RewardItem r) {
    final todayGradient = AppColors.buttonGradient;
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Container(
          width: 80,
          margin: EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            gradient: r.isToday ? todayGradient : null,
            color: r.isToday ? null : AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: r.claimed
                  ? AppColors.green.withValues(alpha: 0.4)
                  : (r.isToday
                      ? AppColors.primaryLight.withValues(alpha: 0.5)
                      : AppColors.cardBorder),
              width: 0.5,
            ),
            boxShadow: r.isToday
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                'Day ${r.day}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: r.isToday ? Colors.white : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (r.isToday ? Colors.white : AppColors.surfaceLight)
                      .withValues(
                    alpha: r.claimed ? 0.25 : 0.15,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(r.icon, style: const TextStyle(fontSize: 18)),
                    ),
                    if (r.claimed)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '+${r.amount}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: r.isToday ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                r.type == 'coins'
                    ? 'Coins'
                    : r.type == 'gems'
                        ? 'Gems'
                        : 'Box',
                style: TextStyle(
                  fontSize: 8,
                  color: r.isToday
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTasksList(BuildContext context) {
    return Column(
      children: List.generate(AppConstants.dailyTasks.length, (index) {
        final t = AppConstants.dailyTasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            t.completed
                                ? AppColors.green.withOpacity(0.4)
                                : AppColors.primary.withOpacity(0.3),
                            t.completed
                                ? AppColors.green.withOpacity(0.1)
                                : AppColors.primary.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        t.completed
                            ? Icons.check_circle_rounded
                            : Icons.flag_rounded,
                        size: 16,
                        color: t.completed ? AppColors.green : AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.loose,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${t.current}/${t.target}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: t.completed ? AppColors.green : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(t.rewardIcon, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text(
                              '${t.rewardAmount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: t.completed ? AppColors.green : AppColors.gold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (t.completed)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppColors.green,
                              )
                            else
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withOpacity(0.15),
                                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${(100 * (1 - t.progress)).toInt()}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearPercentIndicator(
                  padding: EdgeInsets.zero,
                  lineHeight: 5,
                  animation: true,
                  percent: t.progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.cardBorder.withOpacity(0.5),
                  linearGradient: t.completed
                      ? const LinearGradient(colors: [AppColors.green, Color(0xFF34D399)])
                      : AppColors.buttonGradient,
                  barRadius: const Radius.circular(2.5),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
