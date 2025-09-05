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
  final G = m.state.gamesToWinSet;                 // 6 (sets normais), 9 (proset), etc.
  final maxSets = m.state.setsToWinMatch * 2 - 1;  // ex.: BO3 => 3
  final isLastPossible = index == maxSets - 1;

  final diff = (t1 - t2).abs();
  final maxV = t1 > t2 ? t1 : t2;
  final minV = t1 > t2 ? t2 : t1;

  // --- SUPER TIE-BREAK (apenas no slot final de formatos super) ---
  if (m.state.superTieBreak && isLastPossible) {
    // alvo mínimo = 10, por 2.
    if (maxV < 10) return false;
    if (maxV == 10) return diff >= 2;          // 10–8, 10–7, ...
    // Se passou de 10, tem de ser exatamente por 2 (minimalidade)
    return diff == 2;                           // 11–9, 12–10, ... (12–9 é inválido)
  }

  // --- SET NORMAL (G == 6) com TB a 6–6 ---
  if (G == 6) {
    // válidos: 6–0..6–4, 7–5, 7–6 (mínimos); tudo o resto inválido (ex.: 8–6, 7–3, 9–7…)
    if (maxV == 6 && diff >= 2) return true;
    if (maxV == 7 && (minV == 5 || minV == 6)) return true;
    return false;
  }

  // --- PROSET / outros formatos “G por 2” (ex.: G = 9) ---
  // a) Termina exatamente quando alguém atinge G com diferença >= 2
  if (maxV == G) return diff >= 2;              // 9–0..9–7 (válidos)

  // b) Extensão a partir de G–1–G–1 (ex.: 8–8) → termina na primeira vantagem de 2
  //    Para garantir minimalidade:
  //    - tem de vir de pelo menos G–1 do adversário (ex.: >= 8)
  //    - diferença TEM de ser exatamente 2 (ex.: 10–8, 11–9, 12–10…)
  if (maxV > G) {
    if (minV < G - 1) return false;             // 10–7 inválido: teria terminado 9–7
    return diff == 2;                           // 11–8 inválido (seria 10–8 antes)
  }

  // Ainda ninguém chegou a G
  return false;
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

