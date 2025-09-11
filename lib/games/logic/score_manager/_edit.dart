part of 'score_manager.dart';

// --- helpers for preview ---
int _smIndexWhereMatchDecided(ScoreManager m, List<Map> sets) {
  int w1 = 0, w2 = 0;
  for (int i = 0; i < sets.length; i++) {
    final s = sets[i];
    if (!_smIsSetConcluded(m, s)) continue;
    final t1 = (s['team1'] as int?) ?? 0;
    final t2 = (s['team2'] as int?) ?? 0;
    if (t1 > t2) w1++; else if (t2 > t1) w2++;
    if (w1 >= m.state.setsToWinMatch || w2 >= m.state.setsToWinMatch) {
      return i; // decided at index i
    }
  }
  return -1;
}

// DEEP copy (only team1/team2 used for decisions)
List<Map<String,int>> _smCopySets(List<Map> src) => [
  for (final s in src)
    {
      'team1': (s['team1'] as int?) ?? 0,
      'team2': (s['team2'] as int?) ?? 0,
    }
];

// PREVIEW: if applying (index,t1,t2) would decide earlier,
// return the first trailing index to discard (cutFrom), else null.
int? _smPreviewTrailingDiscardIndex(ScoreManager m, int index, int t1, int t2) {
  final sets = (m.state.score['sets'] as List?)?.cast<Map>() ?? const [];
  if (index < 0 || index >= sets.length) return null;

  // Must be a FINAL result; non-final edits are handled as re-open and never discard.
  if (!_smIsValidFinalSetScore(m, t1, t2, index)) return null;

  final copy = _smCopySets(sets);
  copy[index]['team1'] = t1;
  copy[index]['team2'] = t2;

  final decidedAt = _smIndexWhereMatchDecided(m, copy);
  if (decidedAt == -1) return null;

  // If decision happens before the last recorded set, we need to drop trailing sets.
  if (decidedAt < copy.length - 1) {
    return decidedAt + 1; // discard from next index
  }
  return null;
}

int? _smPreviewReopenDiscardIndex(ScoreManager m, int index, int t1, int t2) {
  final sets = (m.state.score['sets'] as List?)?.cast<Map>() ?? [];
  if (index < 0 || index >= sets.length) return null;

  // Se for um FINAL válido, não é caso de reabertura
  if (_smIsValidFinalSetScore(m, t1, t2, index)) return null;

  final allowSuper = _smIsSuperTBSlot(m, index);
  final G = m.state.gamesToWinSet;
  final diff = (t1 - t2).abs();
  final maxV = t1 > t2 ? t1 : t2;
  final minV = t1 > t2 ? t2 : t1;

  bool okInProgress;
  if (allowSuper) {
    // super TB em curso = ainda não atingiu 10 (ou sem diferença de 2)
    okInProgress = !((maxV >= 10) && (diff >= 2));
  } else if (G == 6) {
    // 0..5-x, 6-5, 5-6, 6-6 (TB) — tudo isto é "em curso"
    okInProgress = (maxV < 6) || (maxV == 6 && diff < 2);
  } else {
    // ex. proset a 9: em curso = <9, ou >=9 mas sem diferença de 2
    okInProgress = (maxV < G) || (maxV >= G && diff < 2);
  }

  if (!okInProgress) return null;

  // Reabrir um set implica descartar deste índice em diante (inclui o próprio)
  return index;
}


// existing: _smAdjustFinishedSet(...)
// (unchanged)

bool _smApplyFinishedSetResult(
    ScoreManager m,
    int index,
    int team1Val,
    int team2Val, {
      bool allowDiscardTrailing = false,
    }) {
  final sets = (m.state.score['sets'] as List?)?.cast<Map>() ?? [];
  if (index < 0 || index >= sets.length) return false;

  final s = sets[index];
  if (!_smIsSetConcluded(m, s)) return false;

  final t1 = team1Val.clamp(0, 99);
  final t2 = team2Val.clamp(0, 99);
  final diff = (t1 - t2).abs();
  final maxV = t1 > t2 ? t1 : t2;
  final minV = t1 > t2 ? t2 : t1;

  // =========== CASO A: resultado FINAL ===========
  final isValidFinal = _smIsValidFinalSetScore(m, t1, t2, index);
  if (isValidFinal) {
    // Se decidir mais cedo, pode exigir descartar sets seguintes
    final cutFrom = _smPreviewTrailingDiscardIndex(m, index, t1, t2);
    if (cutFrom != null && !allowDiscardTrailing) return false;

    // aplica o novo resultado ao set
    s['team1'] = t1;
    s['team2'] = t2;

    // descarta sets a partir de cutFrom, se confirmado
    if (cutFrom != null && allowDiscardTrailing) {
      sets.removeRange(cutFrom, sets.length);
      m.state.score['sets'] = sets;
    }

    // derivados
    m.state.currentSet =
        ((m.state.score['sets'] as List).cast<Map>()).where((x) => _smIsSetConcluded(m, x)).length;

    final w1 = _smWonSetsForTeam(m, 1);
    final w2 = _smWonSetsForTeam(m, 2);
    m.state.matchOver = (w1 >= m.state.setsToWinMatch) || (w2 >= m.state.setsToWinMatch);
    if (m.state.matchOver) {
      m.state.inTieBreak = false;
      m.state.score['current'] = {};
    }
    return true;
  }

  // =========== CASO B: resultado NÃO FINAL → reabrir ===========
  final finishedCount =
      ((m.state.score['sets'] as List).cast<Map>()).where((x) => _smIsSetConcluded(m, x)).length;
  final isLastFinished = index == finishedCount - 1;

  // set pode ser reaberto SE for um estado "em curso" válido
  final G = m.state.gamesToWinSet;
  final isSuperSlot = _smIsSuperTBSlot(m, index);

  bool okInProgress;
  if (isSuperSlot) {
    // super TB em curso: ainda não atingiu alvo de 10 com diferença 2
    okInProgress = !((maxV >= 10) && (diff >= 2));
  } else if (G == 6) {
    // sets normais com TB a 6–6
    okInProgress = (maxV < 6) || (maxV == 6 && diff < 2); // inclui 6–6
  } else {
    // Pro Set (G=9): só está "em curso" enquanto maxV < 9
    okInProgress = (maxV < G);
  }
  if (!okInProgress) return false;

  // Se não é o último set concluído, para reabrir temos de descartar trailing
  if (!isLastFinished) {
    if (!allowDiscardTrailing) return false; // o UI deve pedir confirmação
    // remove ESTE set e todos os seguintes
    sets.removeRange(index, sets.length);
  } else {
    // último concluído: remove só este
    sets.removeAt(index);
  }
  m.state.score['sets'] = sets;

  // preparar o 'current' reaberto
  if (isSuperSlot) {
    // SUPER TB reaberto: manter os pontos editados
    m.state.inTieBreak = true;
    m.state.matchOver = false;
    m.state.score['current'] = {
      "games_team1": 0, "games_team2": 0, // ignorados em super TB
      "points_team1": 0, "points_team2": 0,
      "tb_team1": t1, "tb_team2": t2,     // ← preservar pontos editados
    };
  } else {
    final goesToTB = _smShouldEnterNormalTB(m, t1, t2); // true se 6–6 (ou equivalente)
    m.state.inTieBreak = goesToTB;
    m.state.matchOver = false;
    m.state.score['current'] = {
      "games_team1": t1, "games_team2": t2, // ← jogos reabertos
      "points_team1": 0, "points_team2": 0,
      "tb_team1": 0, "tb_team2": 0,         // TB começa 0–0 se for o caso
    };
  }

  // derivados
  m.state.currentSet =
      ((m.state.score['sets'] as List).cast<Map>()).where((x) => _smIsSetConcluded(m, x)).length;

  return true;
}
