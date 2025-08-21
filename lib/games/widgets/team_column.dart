import 'package:flutter/material.dart';

class TeamColumn extends StatelessWidget {
  final String name;
  final VoidCallback onIncPoint;
  final VoidCallback onDecPoint;
  final VoidCallback onIncGame;
  final VoidCallback onDecGame;

  const TeamColumn({
    super.key,
    required this.name,
    required this.onIncPoint,
    required this.onDecPoint,
    required this.onIncGame,
    required this.onDecGame,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(onPressed: onDecPoint, icon: const Icon(Icons.remove)),
            IconButton(onPressed: onIncPoint, icon: const Icon(Icons.add)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(onPressed: onDecGame, icon: const Icon(Icons.arrow_downward)),
            IconButton(onPressed: onIncGame, icon: const Icon(Icons.arrow_upward)),
          ],
        ),
      ],
    );
  }
}
