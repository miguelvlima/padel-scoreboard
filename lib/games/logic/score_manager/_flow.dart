part of 'score_manager.dart';

void _smIncrementPoint(ScoreManager m, int team) {
  if (m.state.matchOver) return;

  if (m.state.inTieBreak || _smIsSuperTBActive(m)) {
    m.state.inTieBreak = true;
    _smIncrementTieBreak(m, team);
    return;
  }

  final selfKey = "points_team$team";
  final oppTeam = team == 1 ? 2 : 1;
  final oppKey = "points_team$oppTeam";

  int p = m.state.score["current"][selfKey] ?? 0;
  int o = m.state.score["current"][oppKey] ?? 0;

  if (!m.state.gpRule) {
    if (p >= 3 && o < 3) { _smWinGame(m, team); return; }
    if (p == 3 && o == 3) {
      m.state.score["current"][selfKey] = 4;
    } else if (p == 4 && o == 4) {
      m.state.score["current"][selfKey] = 3;
      m.state.score["current"][oppKey] = 3;
    } else if (p == 4) {
      _smWinGame(m, team); return;
    } else if (o == 4) {
      m.state.score["current"][oppKey] = 3;
    } else {
      m.state.score["current"][selfKey] = p + 1;
    }
  } else {
    if (p >= 3 && o >= 3) { _smWinGame(m, team); return; }
    if (p >= 3) { _smWinGame(m, team); return; }
    m.state.score["current"][selfKey] = p + 1;
  }
}

void _smDecrementPoint(ScoreManager m, int team) {
  if (m.state.inTieBreak) {
    final key = "tb_team$team";
    final v = (m.state.score["current"][key] as int? ?? 0);
    m.state.score["current"][key] = v > 0 ? v - 1 : 0;
    return;
  }
  final key = "points_team$team";
  final v = (m.state.score["current"][key] as int? ?? 0);
  m.state.score["current"][key] = v > 0 ? v - 1 : 0;
}

void _smIncrementTieBreak(ScoreManager m, int team) {
  final key = "tb_team$team";
  m.state.score["current"][key] = (m.state.score["current"][key] as int? ?? 0) + 1;

  final other = team == 1 ? 2 : 1;
  final v  = m.state.score["current"][key] as int;
  final ov = m.state.score["current"]["tb_team$other"] as int? ?? 0;

  final target = _smIsSuperTBActive(m) ? 10 : 7;
  if (v >= target && (v - ov) >= 2) {
    _smWinSet(m, team);
    return;
  }
}

void _smWinGame(ScoreManager m, int team) {
  if (m.state.matchOver) return;

  final gKey = "games_team$team";
  m.state.score["current"][gKey] =
      (m.state.score["current"][gKey] as int? ?? 0) + 1;

  // reset points
  m.state.score["current"]["points_team1"] = 0;
  m.state.score["current"]["points_team2"] = 0;

  final g1 = m.state.score["current"]["games_team1"] as int? ?? 0;
  final g2 = m.state.score["current"]["games_team2"] as int? ?? 0;

  if ((g1 >= m.state.gamesToWinSet || g2 >= m.state.gamesToWinSet) &&
      ((g1 - g2).abs() >= 2)) {
    _smWinSet(m, g1 > g2 ? 1 : 2);
  } else if (_smShouldEnterNormalTB(m, g1, g2)) {
    m.state.inTieBreak = true;
  }

  _smRecomputeMatchOver(m);
  if (m.state.matchOver) m.state.inTieBreak = false;
}

void _smAdjustGameManually(ScoreManager m, int team, bool increment) {
  if (m.state.matchOver || m.state.inTieBreak || _smIsSuperTBActive(m)) return;

  final gKey = "games_team$team";
  int current = m.state.score["current"][gKey] as int? ?? 0;
  current = increment ? current + 1 : (current > 0 ? current - 1 : 0);
  m.state.score["current"][gKey] = current;

  int g1 = m.state.score["current"]["games_team1"] as int? ?? 0;
  int g2 = m.state.score["current"]["games_team2"] as int? ?? 0;

  if ((g1 >= m.state.gamesToWinSet || g2 >= m.state.gamesToWinSet) &&
      ((g1 - g2).abs() >= 2)) {
    _smWinSet(m, g1 > g2 ? 1 : 2);
  } else if (_smShouldEnterNormalTB(m, g1, g2)) {
    m.state.inTieBreak = true;
  }

  _smRecomputeMatchOver(m);
  if (m.state.matchOver) m.state.inTieBreak = false;
}

void _smWinSet(ScoreManager m, int team) {
  if (m.state.matchOver) return;

  final wasTB = m.state.inTieBreak;

  // snapshot antes de limpeza
  final curG1  = (m.state.score["current"]?["games_team1"] as int?) ?? 0;
  final curG2  = (m.state.score["current"]?["games_team2"] as int?) ?? 0;
  final curTB1 = (m.state.score["current"]?["tb_team1"]    as int?) ?? 0;
  final curTB2 = (m.state.score["current"]?["tb_team2"]    as int?) ?? 0;

  final sets = (m.state.score['sets'] as List).cast<Map>();
  if (sets.length <= m.state.currentSet) {
    sets.add({'team1': 0, 'team2': 0});
  }

  // Fechar set: TB normal vs Super TB vs jogos normais
  if (wasTB) {
    final isSuperTB = _smIsSuperTBActive(m);
    if (isSuperTB) {
      // SUPER TB: gravar pontos do TB como resultado do 3.º “set”
      sets[m.state.currentSet]['team1'] = curTB1;
      sets[m.state.currentSet]['team2'] = curTB2;
    } else {
      // TIE-BREAK NORMAL (6–6): 7–6 para o vencedor
      final win  = team == 1 ? 'team1' : 'team2';
      final lose = team == 1 ? 'team2' : 'team1';
      sets[m.state.currentSet][win]  = m.state.gamesToWinSet + 1; // 7
      sets[m.state.currentSet][lose] = m.state.gamesToWinSet;     // 6
    }
  } else {
    // Sem TB: fechar com jogos correntes
    sets[m.state.currentSet]['team1'] = curG1;
    sets[m.state.currentSet]['team2'] = curG2;
  }

  // Derivados (sem incrementar índice manualmente)
  final won1 = _smWonSetsForTeam(m, 1);
  final won2 = _smWonSetsForTeam(m, 2);
  m.state.matchOver =
      (won1 >= m.state.setsToWinMatch) || (won2 >= m.state.setsToWinMatch);

  m.state.currentSet =
      ((m.state.score['sets'] as List).cast<Map>())
          .where((s) => _smIsSetConcluded(m, s))
          .length;

  // Limpezas
  m.state.inTieBreak = false;

  if (m.state.matchOver) {
    // remove trailing 0–0 e limpa current
    final setsList = (m.state.score['sets'] as List).cast<Map>();
    while (setsList.isNotEmpty) {
      final last = setsList.last;
      final t1 = (last['team1'] as int?) ?? 0;
      final t2 = (last['team2'] as int?) ?? 0;
      if (t1 == 0 && t2 == 0) { setsList.removeLast(); continue; }
      break;
    }
    m.state.score['current'] = {};
    return;
  }

  // Se ficou 1–1 e o formato é super, preparar o 3.º como SUPER TB
  if (m.state.superTieBreak && won1 == 1 && won2 == 1) {
    m.state.inTieBreak = true;
    m.state.score["current"] = {
      "games_team1": 0, "games_team2": 0, // ignorados no super TB
      "points_team1": 0, "points_team2": 0,
      "tb_team1": 0, "tb_team2": 0,
    };
    return;
  }

  // Próximo set NORMAL: só reset do 'current'
  m.state.score["current"] = {
    "games_team1": 0, "games_team2": 0,
    "points_team1": 0, "points_team2": 0,
    "tb_team1": 0, "tb_team2": 0,
  };
}
