import 'package:flutter/material.dart';
import '../logic/match_state.dart';
import '../logic/score_manager.dart';

class ScoreBoard extends StatelessWidget {
  final MatchState state;
  final ScoreManager manager;
  const ScoreBoard({super.key, required this.state, required this.manager});

  @override
  Widget build(BuildContext context) {
    final rawSets = (state.score['sets'] as List?) ?? [];
    final current = (state.score['current'] as Map?) ?? {};

    // Parcial atual (jogos) e tie-break (pontos)
    final g1 = (current['games_team1'] as int?) ?? 0;
    final g2 = (current['games_team2'] as int?) ?? 0;
    final tb1 = (current['tb_team1'] as int?) ?? 0;
    final tb2 = (current['tb_team2'] as int?) ?? 0;

    // Máximo de sets jogados para o formato: best-of-N ⇒ 2N−1
    final maxSets = state.setsToWinMatch * 2 - 1;

    // Só sets CONCLUÍDOS (usamos o índice lógico currentSet já calculado no manager)
    final finishedCount = state.currentSet.clamp(0, maxSets);
    final finishedSets = <Map>[
      for (int i = 0; i < rawSets.length && i < finishedCount; i++)
        (rawSets[i] as Map),
    ];

    // Mostrar “Atual”?
    final showCurrentChip = !state.matchOver &&
        finishedSets.length < maxSets &&
        current.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            // Chips dos sets concluídos (limitados ao máximo do formato)
            for (int i = 0; i < finishedSets.length; i++)
              Chip(
                label: Text(
                  (state.superTieBreak &&
                      finishedSets.length == (state.setsToWinMatch * 2 - 1) && // ex.: best-of-3 => 3
                      i == finishedSets.length - 1)                             // último chip
                      ? 'Super TB: ${finishedSets[i]['team1']} - ${finishedSets[i]['team2']}'
                      : 'Set ${i + 1}: ${finishedSets[i]['team1']} - ${finishedSets[i]['team2']}',
                ),
              ),

            // Chip do set atual (apenas se fizer sentido)
            if (showCurrentChip)
              Chip(
                label: Text(
                  state.inTieBreak
                      ? (state.superTieBreak
                      ? 'Super TB: $tb1 - $tb2'
                      : 'Tie-break: $tb1 - $tb2')
                      : 'Atual: $g1 - $g2',
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              manager.pointsText(1),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              manager.pointsText(2),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ],
    );
  }
}
