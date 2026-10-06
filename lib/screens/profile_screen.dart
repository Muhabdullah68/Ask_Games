import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return ComingSoonPlaceholder(
      title: 'Profile',
      subtitle:
          'View your gaming stats, track achievements and customize your player experience.',
      emoji: '👤',
      showAppBar: showAppBar,
    );
  }
}
