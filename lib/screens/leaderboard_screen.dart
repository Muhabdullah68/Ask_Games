import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return ComingSoonPlaceholder(
      title: 'Leaderboard',
      subtitle:
          'Compete with players worldwide, climb the global ranks and earn your spot at the top!',
      emoji: '🏆',
      showAppBar: showAppBar,
    );
  }
}
