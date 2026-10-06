import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class DailyRewardsScreen extends StatelessWidget {
  const DailyRewardsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return ComingSoonPlaceholder(
      title: showAppBar ? 'Daily Rewards' : 'Rewards',
      subtitle:
          'Earn daily login bonuses, complete fun tasks and unlock exclusive rewards every day!',
      emoji: '🎁',
      showAppBar: showAppBar,
    );
  }
}
