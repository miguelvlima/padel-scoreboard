part of 'score_manager.dart';

String _smPointsText(ScoreManager m, int teamNum) {
  if (m.state.inTieBreak) {
    final tb = m.state.score["current"]["tb_team$teamNum"] as int? ?? 0;
    return m.state.superTieBreak && _smIsSuperTBActive(m)
        ? "Super TB: $tb"
        : "Tie-Break: $tb";
  }

  final p = (m.state.score["current"]["points_team$teamNum"] as int? ?? 0);
  final opp = (m.state.score["current"]["points_team${teamNum == 1 ? 2 : 1}"] as int? ?? 0);

  if (!m.state.gpRule) {
    // COM vantagem
    if (p == 4 && opp == 3) return "PONTOS: Ad"; // tens vantagem
    if (p == 3 && opp == 4) return "PONTOS: 40"; // adversário tem Ad, tu mostras 40
    return "PONTOS: ${m.state.pointValues[p.clamp(0, 3)]}"; // 0/15/30/40 (inclui deuce 40–40)
  } else {
    // Golden point
    final idx = p.clamp(0, 3);
    return "PONTOS: ${m.state.pointValues[idx]}";
  }
}

void _smFinishNormalTB(ScoreManager m, int winnerTeam) {
  // Se for Pro Set, o TB entra a 8–8 e o set final deve ser 9–8 / 8–9.
  // Set normal entra a 6–6 e fecha 7–6 / 6–7.
  final isProSet = (m.state.setsToWinMatch == 1); // Pro Set quando só há 1 "set"
  final base = isProSet ? 8 : 6;

  final t1 = base + (winnerTeam == 1 ? 1 : 0);
  final t2 = base + (winnerTeam == 2 ? 1 : 0);

  final sets = ((m.state.score['sets'] as List?)?.cast<Map<String, dynamic>>()) ?? <Map<String, dynamic>>[];
  sets.add({'team1': t1, 'team2': t2});
  m.state.score['sets'] = sets;

  // sair do TB e limpar corrente
  m.state.inTieBreak = false;
  m.state.score['current'] = {
    'games_team1': 0, 'games_team2': 0,
    'points_team1': 0, 'points_team2': 0,
    'tb_team1': 0, 'tb_team2': 0,
  };

  // derivados
  m.state.currentSet = sets.length;
  final w1 = _smWonSetsForTeam(m, 1);
  final w2 = _smWonSetsForTeam(m, 2);
  m.state.matchOver = (w1 >= m.state.setsToWinMatch) || (w2 >= m.state.setsToWinMatch);
  if (m.state.matchOver) {
    m.state.inTieBreak = false;
    m.state.score['current'] = {};
  }
}

void _smFinishSuperTB(ScoreManager m, int tb1, int tb2) {
  // O Super TB é o último "set" (decisor). Guarda diretamente os pontos do STB.
  final sets = ((m.state.score['sets'] as List?)?.cast<Map<String, dynamic>>()) ?? <Map<String, dynamic>>[];
  sets.add({'team1': tb1, 'team2': tb2});
  m.state.score['sets'] = sets;

  m.state.inTieBreak = false;
  m.state.score['current'] = {};

  // derivados
  m.state.currentSet = sets.length;
  final w1 = _smWonSetsForTeam(m, 1);
  final w2 = _smWonSetsForTeam(m, 2);
  m.state.matchOver = (w1 >= m.state.setsToWinMatch) || (w2 >= m.state.setsToWinMatch);
}


