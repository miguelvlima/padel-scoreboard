import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return SizedBox(
      height: 44, // fixed, small
      child: SafeArea(
        top: false,
        child: Center(
          child: Text(
            '© New Padel Solutions 2025',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
