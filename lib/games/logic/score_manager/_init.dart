part of 'score_manager.dart';

void _smInitializeCurrentSet(ScoreManager m) {
  // 1) Estrutura base
  m.state.score.putIfAbsent('sets', () => <Map<String, int>>[]);
  List<Map> sets = (m.state.score['sets'] as List).cast<Map>();

  // 2) Limite pelo formato (best-of-N ⇒ maxSets = 2*N - 1)
  final maxSets = m.state.setsToWinMatch * 2 - 1;
  if (sets.length > maxSets) {
    sets = sets.sublist(0, maxSets);
    m.state.score['sets'] = sets;
  }

  // 3) REMOVER “trailers” vazios no fim (… , {0,0}, {0,0}, …)
  while (sets.isNotEmpty) {
    final last = sets.last;
    final t1 = (last['team1'] as int?) ?? 0;
    final t2 = (last['team2'] as int?) ?? 0;
    if (t1 == 0 && t2 == 0) { sets.removeLast(); continue; }
    break;
  }
  m.state.score['sets'] = sets;

  // 4) Contagem de sets concluídos e vitórias
  final finishedSets = sets.where((s) => _smIsSetConcluded(m, s)).toList();
  m.state.currentSet = finishedSets.length;

  final won1 = finishedSets.where((s) => ((s['team1'] as int?) ?? 0) > ((s['team2'] as int?) ?? 0)).length;
  final won2 = finishedSets.where((s) => ((s['team2'] as int?) ?? 0) > ((s['team1'] as int?) ?? 0)).length;

  m.state.matchOver =
      (won1 >= m.state.setsToWinMatch) || (won2 >= m.state.setsToWinMatch);
  if (m.state.matchOver) {
    m.state.inTieBreak = false;
    m.state.score['current'] = {};
    return;
  }

  // 5) Super TB ativo? (3.º “set” em formatos super com 1–1)
  if (!m.state.matchOver && m.state.superTieBreak) {
    final active = _smIsSuperTBActive(m);
    m.state.inTieBreak = active; // força TB no 3.º “set”
    if (active) {
      final cur = (m.state.score['current'] as Map?) ?? const {};
      m.state.score['current'] = {
        'games_team1': 0, 'games_team2': 0,  // ignorados no super TB
        'points_team1': 0, 'points_team2': 0,
        'tb_team1': (cur['tb_team1'] as int?) ?? 0,
        'tb_team2': (cur['tb_team2'] as int?) ?? 0,
      };
      return; // já estamos em super TB — não reavaliar tie-break normal
    }
  }

  // 6) Preservar/Completar 'current'
  final current = (m.state.score['current'] as Map?) ?? const {};
  m.state.score['current'] = {
    'games_team1': (current['games_team1'] as int?) ?? 0,
    'games_team2': (current['games_team2'] as int?) ?? 0,
    'points_team1': (current['points_team1'] as int?) ?? 0,
    'points_team2': (current['points_team2'] as int?) ?? 0,
    'tb_team1': (current['tb_team1'] as int?) ?? 0,
    'tb_team2': (current['tb_team2'] as int?) ?? 0,
  };

  // 7) Tie-break NORMAL ativo só se o set atual está 6–6
  final g1 = m.state.score['current']['games_team1'] as int? ?? 0;
  final g2 = m.state.score['current']['games_team2'] as int? ?? 0;
  m.state.inTieBreak = _smShouldEnterNormalTB(m, g1, g2);
}
