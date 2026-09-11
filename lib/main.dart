import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GameHubApp());
}

class GameHubApp extends StatelessWidget {
  const GameHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: const SplashScreen(),
    );
  }
}
