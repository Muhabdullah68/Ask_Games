import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Settings',
      subtitle:
          'Manage your account, customize audio, notifications and personalize your preferences.',
      emoji: '⚙️',
    );
  }
}
