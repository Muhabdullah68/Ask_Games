import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'All Games',
      subtitle:
          'Browse and discover our complete collection of exciting games. New titles added regularly!',
      emoji: '🎮',
      showAppBar: false,
    );
  }
}
