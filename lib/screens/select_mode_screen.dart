import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class SelectModeScreen extends StatelessWidget {
  const SelectModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Select Mode',
      subtitle:
          'Choose from multiple exciting game modes including Classic, Challenge and Tournament play!',
      emoji: '🎯',
    );
  }
}
