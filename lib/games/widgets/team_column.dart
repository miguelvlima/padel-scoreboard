// lib/games/widgets/team_column.dart
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

    // estilos comuns para ambos os grupos de botões
    const btnPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    const btnSize = Size(64, 40);
    final outlinedStyle = OutlinedButton.styleFrom(
      minimumSize: btnSize,
      padding: btnPadding,
      visualDensity: VisualDensity.compact,
    );
    final filledStyle = FilledButton.styleFrom(
      minimumSize: btnSize,
      padding: btnPadding,
      visualDensity: VisualDensity.compact,
    );

    Widget group({
      required String title,
      required VoidCallback onDec,
      required VoidCallback onInc,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: onDec,
                style: outlinedStyle,
                child: const Text('−'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onInc,
                style: filledStyle,
                child: const Text('+'),
              ),
            ],
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Nome da dupla
            Text(
              name,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // PONTOS (centrado)
            group(title: 'PONTOS', onDec: onDecPoint, onInc: onIncPoint),

            const Divider(height: 24),

            // JOGOS (centrado)
            group(title: 'JOGOS', onDec: onDecGame, onInc: onIncGame),
          ],
        ),
      ),
    );
  }
}
