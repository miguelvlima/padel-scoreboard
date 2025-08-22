// widgets/team_column.dart
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nome da dupla — 2 linhas com “...”
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            // Pontos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: onDecPoint, icon: const Icon(Icons.remove)),
                const SizedBox(width: 8),
                IconButton(onPressed: onIncPoint, icon: const Icon(Icons.add)),
              ],
            ),

            // Jogos (ajuste manual)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: onDecGame, icon: const Icon(Icons.exposure_neg_1)),
                const SizedBox(width: 8),
                IconButton(onPressed: onIncGame, icon: const Icon(Icons.exposure_plus_1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
