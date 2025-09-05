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
