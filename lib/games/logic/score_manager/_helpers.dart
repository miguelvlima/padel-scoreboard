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
  final G = m.state.gamesToWinSet; // 6 (BO3 normal), 9 (proset), etc.
  final diff = (t1 - t2).abs();
  final maxV = t1 > t2 ? t1 : t2;
  final minV = t1 > t2 ? t2 : t1;

  // Super TB: só no slot final dos formatos super (≥10 e diferença 2)
  if (_smIsSuperTBSlot(m, index) && maxV >= 9) {
    return (maxV >= 10) && (diff >= 2);
  }

  // Sets normais com TB a 6–6 (G == 6): válidos apenas 6–0..6–4, 7–5, 7–6
  if (G == 6) {
    if (maxV == 6 && diff >= 2) return true;                // 6–0..6–4
    if (maxV == 7 && (minV == 5 || minV == 6)) return true; // 7–5 ou 7–6
    return false;                                           // bloqueia 7–3, 8–6, etc.
  }

  // Outros formatos (ex.: proset a 9): “por dois” a partir de G (9–7, 10–8, …)
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

bool _smShouldEnterNormalTB(ScoreManager m, int g1, int g2) {
  // Em proset (um único set), NUNCA há tie-break normal
  if (m.state.setsToWinMatch <= 1) return false;

  // Nos restantes formatos, trigger é o próprio G (ex.: 6–6)
  final trigger = m.state.gamesToWinSet; // normalmente 6
  return g1 == trigger && g2 == trigger;
}

void _smRecomputeMatchOver(ScoreManager m) {
  final w1 = _smWonSetsForTeam(m, 1);
  final w2 = _smWonSetsForTeam(m, 2);
  m.state.matchOver =
      (w1 >= m.state.setsToWinMatch) || (w2 >= m.state.setsToWinMatch);
}

