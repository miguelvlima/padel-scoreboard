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
  final maxV = t1 > t2 ? t1 : t2;
  final minV = t1 > t2 ? t2 : t1;

  // FINAL válido?
  final isValidFinal = _smIsValidFinalSetScore(m, t1, t2, index);
  if (isValidFinal) {
    // If this edit would decide the match earlier and there are trailing sets,
    // only proceed if allowed (after UI confirmation).
    final cutFrom = _smPreviewTrailingDiscardIndex(m, index, t1, t2);
    if (cutFrom != null && !allowDiscardTrailing) {
      return false; // caller should prompt the user first
    }

    // Apply edited result
    s['team1'] = t1;
    s['team2'] = t2;

    // If confirmed, discard all sets from cutFrom to the end
    if (cutFrom != null && allowDiscardTrailing) {
      sets.removeRange(cutFrom, sets.length);
      m.state.score['sets'] = sets;
    }

    // Derivados
    m.state.currentSet =
        ((m.state.score['sets'] as List).cast<Map>())
            .where((x) => _smIsSetConcluded(m, x))
            .length;

    final w1 = _smWonSetsForTeam(m, 1);
    final w2 = _smWonSetsForTeam(m, 2);
    m.state.matchOver =
        (w1 >= m.state.setsToWinMatch) || (w2 >= m.state.setsToWinMatch);
    if (m.state.matchOver) {
      m.state.inTieBreak = false;
      m.state.score['current'] = {};
    }
    return true;
  }

  // --- NÃO final: só reabrimos se for o ÚLTIMO set concluído ---
  final finishedCount =
      ((m.state.score['sets'] as List).cast<Map>())
          .where((x) => _smIsSetConcluded(m, x))
          .length;
  final isLastFinished = index == finishedCount - 1;
  if (!isLastFinished) return false;

  if (_smIsSuperTBSlot(m, index)) {
    // Reabrir SUPER TB
    sets.removeAt(index);
    m.state.score['sets'] = sets;

    m.state.inTieBreak = true;
    m.state.matchOver = false;
    m.state.score['current'] = {
      "games_team1": 0, "games_team2": 0,
      "points_team1": 0, "points_team2": 0,
      "tb_team1": t1, "tb_team2": t2,
    };

    m.state.currentSet =
        ((m.state.score['sets'] as List).cast<Map>())
            .where((x) => _smIsSetConcluded(m, x))
            .length;
    return true;
  }

  // Reabrir SET NORMAL
  final G = m.state.gamesToWinSet;
  final diff = (t1 - t2).abs();
  final okInProgress =
      (maxV < G) ||
          ((maxV == G) && (minV < G) && (diff < 2)) ||
          (t1 == G && t2 == G); // 6–6

  if (!okInProgress) return false;

  sets.removeAt(index);
  m.state.score['sets'] = sets;

  final goesToTB = _smShouldEnterNormalTB(m, t1, t2);
  m.state.inTieBreak = goesToTB;
  m.state.matchOver = false;
  m.state.score['current'] = {
    "games_team1": t1, "games_team2": t2,
    "points_team1": 0, "points_team2": 0,
    "tb_team1": 0, "tb_team2": 0,
  };

  m.state.currentSet =
      ((m.state.score['sets'] as List).cast<Map>())
          .where((x) => _smIsSetConcluded(m, x))
          .length;
  return true;
}
