part of 'score_manager.dart';

void _smSanitizeForSave(ScoreManager m) {
  final maxSets = m.state.setsToWinMatch * 2 - 1;
  List<Map> sets = (m.state.score['sets'] as List?)?.cast<Map>() ?? [];

  if (sets.length > maxSets) sets = sets.sublist(0, maxSets);

  // remove trailing 0–0 e sets não concluídos no fim
  while (sets.isNotEmpty) {
    final last = sets.last;
    final t1 = (last['team1'] as int?) ?? 0;
    final t2 = (last['team2'] as int?) ?? 0;
    final concluded = _smIsSetConcluded(m, last);
    if (t1 == 0 && t2 == 0) { sets.removeLast(); continue; }
    if (!concluded) { sets.removeLast(); continue; }
    break;
  }

  m.state.score['sets'] = sets;

  if (m.state.matchOver) {
    m.state.score['current'] = {}; // não gravar “Atual” depois de acabar
  }

}

void _smResetMatch(ScoreManager m) {
  // Estado base zerado, sem placeholders de sets
  m.state.inTieBreak = false;
  m.state.matchOver = false;
  m.state.currentSet = 0;

  m.state.score = {
    'sets': <Map<String, int>>[],
    'current': <String, int>{
      'points_team1': 0,
      'points_team2': 0,
      'games_team1': 0,
      'games_team2': 0,
      'tb_team1': 0,
      'tb_team2': 0,
    },
  };
}
