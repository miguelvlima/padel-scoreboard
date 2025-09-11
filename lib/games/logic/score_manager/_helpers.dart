part of 'score_manager.dart';

// ---------- Helpers de regras/derivados (privados) ----------

bool _smIsSetConcluded(ScoreManager m, Map s) {
  final t1 = (s['team1'] as int?) ?? 0;
  final t2 = (s['team2'] as int?) ?? 0;
  return (t1 != t2) &&
      ((t1 >= m.state.gamesToWinSet) || (t2 >= m.state.gamesToWinSet));
}

bool _smIsSuperTBSlot(ScoreManager m, int index) {
  final maxSets = m.state.setsToWinMatch * 2 - 1;
  return m.state.superTieBreak && index == maxSets - 1;
}

bool _smIsSuperTBActive(ScoreManager m) {
  if (!m.state.superTieBreak || m.state.matchOver) return false;
  final w1 = _smWonSetsForTeam(m, 1);
  final w2 = _smWonSetsForTeam(m, 2);
  return w1 == 1 && w2 == 1; // 3.º "set" em formatos super (1–1)
}

/// Validação única para resultados finais de set (bloqueia 7–3, 8–6, …).
bool _smIsValidFinalSetScore(ScoreManager m, int t1, int t2, int index) {
  final G = m.state.gamesToWinSet;
  final maxV = t1 > t2 ? t1 : t2;
  final minV = t1 > t2 ? t2 : t1;
  final diff = (t1 - t2).abs();

  // Super TB (último "set" nos formatos super): >=10 por 2
  if (_smIsSuperTBSlot(m, index)) {
    return (maxV >= 10) && (diff >= 2);
  }

  // Sets normais (G=6): 6–0..6–4, 7–5, 7–6
  if (G == 6) {
    if (maxV == 6 && diff >= 2) return true;
    if (maxV == 7 && (minV == 5 || minV == 6)) return true;
    return false;
  }

  // Pro Set (G=9) com TB a 8–8: finais válidos 9–8 (via TB) ou 9–0..9–7
  if (m.state.setsToWinMatch == 1 && G == 9) {
    if (maxV != 9) return false;
    if (minV == 8) return true;   // 9–8 pelo TB
    return diff >= 2;             // 9–0..9–7 por diferença de 2
  }

  // Fallback (não usado atualmente)
  return (maxV >= G) && (diff >= 2);
}



int _smWonSetsForTeam(ScoreManager m, int team) {
  final sets = (m.state.score['sets'] as List?)?.cast<Map>() ?? const [];
  int won = 0;
  for (final s in sets) {
    final t1 = (s['team1'] as int?) ?? 0;
    final t2 = (s['team2'] as int?) ?? 0;
    final finished = (t1 >= m.state.gamesToWinSet) || (t2 >= m.state.gamesToWinSet);
    if (!finished) continue;
    if (team == 1 && t1 > t2) won++;
    if (team == 2 && t2 > t1) won++;
  }
  return won;
}

bool _smIsProsetFormat(ScoreManager m) => m.state.setsToWinMatch == 1;

/// TB normal:
/// - Sets normais: 6–6
/// - Proset:       8–8
bool _smShouldEnterNormalTB(ScoreManager m, int g1, int g2) {
  if (_smIsProsetFormat(m)) {
    return g1 == 8 && g2 == 8; // proset: TB a 8–8
  }
  final G = m.state.gamesToWinSet; // 6 nos sets normais
  return g1 == G && g2 == G;       // 6–6
}

void _smRecomputeMatchOver(ScoreManager m) {
  final w1 = _smWonSetsForTeam(m, 1);
  final w2 = _smWonSetsForTeam(m, 2);
  m.state.matchOver =
      (w1 >= m.state.setsToWinMatch) || (w2 >= m.state.setsToWinMatch);
}

