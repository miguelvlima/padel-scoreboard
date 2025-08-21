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

    // Só sets concluídos (o manager calcula state.currentSet)
    final finishedCount = state.currentSet.clamp(0, maxSets);
    final finishedSets = <Map>[
      for (int i = 0; i < rawSets.length && i < finishedCount; i++)
        (rawSets[i] as Map),
    ];

    // Super TB só quando: formato super, estamos em TB e cada equipa venceu 1 set
    final won1 = rawSets.where((s) {
      final m = (s as Map);
      return (m['team1'] ?? 0) >= state.gamesToWinSet && (m['team1'] ?? 0) > (m['team2'] ?? 0);
    }).length;
    final won2 = rawSets.where((s) {
      final m = (s as Map);
      return (m['team2'] ?? 0) >= state.gamesToWinSet && (m['team2'] ?? 0) > (m['team1'] ?? 0);
    }).length;
    final isSuperTBNow = state.superTieBreak && !state.matchOver && state.inTieBreak && won1 == 1 && won2 == 1;

    // Mostrar chips do “set atual” (6–6) e do TB?
    final canShowCurrent = !state.matchOver && current.isNotEmpty && finishedSets.length < maxSets;

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
                      finishedSets.length == maxSets &&
                      i == finishedSets.length - 1)
                      ? 'Super TB: ${finishedSets[i]['team1']} - ${finishedSets[i]['team2']}'
                      : 'Set ${i + 1}: ${finishedSets[i]['team1']} - ${finishedSets[i]['team2']}',
                ),
              ),

            // ✅ No tie-break normal: manter o placar do set (ex.: 6–6)
            if (canShowCurrent && state.inTieBreak && !isSuperTBNow)
              Chip(label: Text('Set atual: $g1 - $g2')),

            // ✅ Chip do TB (normal ou super)
            if (canShowCurrent && state.inTieBreak)
              Chip(label: Text(isSuperTBNow ? 'Super TB: $tb1 - $tb2' : 'Tie-break: $tb1 - $tb2')),

            // ✅ Fora de TB: mostrar o parcial atual normalmente
            if (canShowCurrent && !state.inTieBreak)
              Chip(label: Text('Atual: $g1 - $g2')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(manager.pointsText(1), style: Theme.of(context).textTheme.titleMedium),
            Text(manager.pointsText(2), style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}
