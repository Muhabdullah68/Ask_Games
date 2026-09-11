import 'package:flutter/material.dart';

import '../widgets/bottom_nav.dart';
import 'daily_rewards_screen.dart';
import 'games_screen.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    GamesScreen(),
    DailyRewardsScreen(showAppBar: false),
    LeaderboardScreen(showAppBar: false),
    ProfileScreen(showAppBar: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: AppBottomNav(
                currentIndex: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
