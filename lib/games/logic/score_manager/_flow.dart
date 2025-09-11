part of 'score_manager.dart';

void _smIncrementPoint(ScoreManager m, int team) {
  if (m.state.matchOver) return;

  final cur = (m.state.score['current'] as Map?) ?? {};
  final g1 = (cur['games_team1'] as int?) ?? 0;
  final g2 = (cur['games_team2'] as int?) ?? 0;

  // Enter tie-break automatically when needed
  final bool isProset = m.state.setsToWinMatch == 1; // Pro Set formats
  final int tbAtGames = isProset ? 8 : 6;
  if (!m.state.inTieBreak && g1 == tbAtGames && g2 == tbAtGames) {
    m.state.inTieBreak = true;
  }

  // Route to TB (normal or super) if active
  if (m.state.inTieBreak || _smIsSuperTBActive(m)) {
    m.state.inTieBreak = true;
    _smIncrementTieBreak(m, team);
    return;
  }

  final selfKey = 'points_team$team';
  final oppTeam = (team == 1) ? 2 : 1;
  final oppKey = 'points_team$oppTeam';

  int p = (cur[selfKey] as int?) ?? 0;
  int o = (cur[oppKey] as int?) ?? 0;

  if (!m.state.gpRule) {
    // NO-GP: 0,15,30,40,Ad
    if (p >= 3 && o < 3) { _smWinGame(m, team); return; }
    if (p == 3 && o == 3) {
      m.state.score['current'][selfKey] = 4; // gain Advantage
    } else if (p == 4 && o == 4) {
      // back to deuce
      m.state.score['current'][selfKey] = 3;
      m.state.score['current'][oppKey]  = 3;
    } else if (p == 4) {
      _smWinGame(m, team); return;
    } else if (o == 4) {
      m.state.score['current'][oppKey] = 3;
    } else {
      m.state.score['current'][selfKey] = p + 1;
    }
  } else {
    // GP: game ends at 40 for whoever reaches it
    if (p >= 3) { _smWinGame(m, team); return; }
    m.state.score['current'][selfKey] = p + 1;
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
  if (m.state.matchOver) return;

  final selfKey = team == 1 ? 'tb_team1' : 'tb_team2';
  final oppKey  = team == 1 ? 'tb_team2' : 'tb_team1';

  final cur = (m.state.score['current'] as Map?) ?? <String, dynamic>{};
  final t = ((cur[selfKey] as num?)?.toInt() ?? 0) + 1;
  final o =  (cur[oppKey]  as num?)?.toInt() ?? 0;

  cur[selfKey] = t;
  cur[oppKey]  = o;
  m.state.score['current'] = cur;

  final bool isSuper = _smIsSuperTBActive(m);
  final int target = isSuper ? 10 : 7;

  // venceu o TB?
  if (t >= target && (t - o) >= 2) {
    if (isSuper) {
      // --- SUPER TB fecha o MATCH ---
      final tb1 = (cur['tb_team1'] as num?)?.toInt() ?? 0;
      final tb2 = (cur['tb_team2'] as num?)?.toInt() ?? 0;

      // Normaliza sets existentes para lista tipada e acrescenta Super TB
      final existing = (m.state.score['sets'] as List?) ?? const [];
      final List<Map<String, int>> sets = [
        for (final s in existing)
          if (s is Map)
            {
              'team1': (s['team1'] as num?)?.toInt() ?? 0,
              'team2': (s['team2'] as num?)?.toInt() ?? 0,
            },
      ];
      sets.add(<String, int>{'team1': tb1, 'team2': tb2});
      m.state.score['sets'] = sets;

      m.state.inTieBreak = false;
      m.state.matchOver  = true;
      m.state.score['current'] = {};
      m.state.currentSet = sets.length;
      return;
    } else {
      // --- TB normal fecha o SET (7–6 ou, no Proset, 9–8) ---
      // 1) Normaliza para lista tipada
      final existing = (m.state.score['sets'] as List?) ?? const [];
      final List<Map<String, int>> sets = [
        for (final s in existing)
          if (s is Map)
            {
              'team1': (s['team1'] as num?)?.toInt() ?? 0,
              'team2': (s['team2'] as num?)?.toInt() ?? 0,
            },
      ];

      // 2) Regras do fecho via TB
      final G      = m.state.gamesToWinSet; // 6 (set normal) / 9 (proset)
      final proset = _smIsProsetFormat(m);

      // Resultado do set após TB:
      // - set normal: vencedor = G+1 (7), vencido = G (6)
      // - proset:     vencedor = G   (9), vencido = G-1 (8)
      final winGames  = proset ? G     : (G + 1);
      final loseGames = proset ? G - 1 : G;

      // 3) Acrescenta o set vencedor
      if (team == 1) {
        sets.add(<String, int>{'team1': winGames, 'team2': loseGames});
      } else {
        sets.add(<String, int>{'team1': loseGames, 'team2': winGames});
      }
      m.state.score['sets'] = sets;

      // 4) Limpa “current” e sai de TB
      m.state.inTieBreak = false;
      m.state.score['current'] = {
        'games_team1': 0, 'games_team2': 0,
        'points_team1': 0, 'points_team2': 0,
        'tb_team1': 0, 'tb_team2': 0,
      };

      // 5) Atualiza estado derivado
      m.state.currentSet = sets.length;

      final w1 = _smWonSetsForTeam(m, 1);
      final w2 = _smWonSetsForTeam(m, 2);
      m.state.matchOver =
          (w1 >= m.state.setsToWinMatch) || (w2 >= m.state.setsToWinMatch);

      // Formato com Super TB: se ficou 1–1 em sets, entra direto no SUPER TB
      if (!m.state.matchOver && m.state.superTieBreak) {
        final a = _smWonSetsForTeam(m, 1);
        final b = _smWonSetsForTeam(m, 2);
        if (a == 1 && b == 1) {
          m.state.inTieBreak = true; // Super TB arranca sem abrir “set 3”
          m.state.score['current']['tb_team1'] = 0;
          m.state.score['current']['tb_team2'] = 0;
        }
      }
      return;
    }
  }
}





void _smWinGame(ScoreManager m, int team) {
  if (m.state.matchOver) return;

  final gKey = "games_team$team";
  final oppTeam = team == 1 ? 2 : 1;
  final ogKey = "games_team$oppTeam";

  final p1Key = "points_team1";
  final p2Key = "points_team2";

  int g = (m.state.score["current"][gKey] ?? 0) as int;
  int og = (m.state.score["current"][ogKey] ?? 0) as int;

  // incrementa jogo do vencedor
  g += 1;
  m.state.score["current"][gKey] = g;
  m.state.score["current"][ogKey] = og;

  // limpa pontos do jogo atual
  m.state.score["current"][p1Key] = 0;
  m.state.score["current"][p2Key] = 0;

  // certifica-te que o TB fica desligado/limpo (no caso de vir de um tie-break)
  m.state.inTieBreak = false;
  m.state.score["current"]["tb_team1"] = 0;
  m.state.score["current"]["tb_team2"] = 0;

  // --- Regra de fecho do set ---
  // Normal: fecha em (6+ com diferença ≥2) OU 7–5 / 7–6
  // Pro Set: fecha em (9–8) OU (9+ com diferença ≥2)
  final bool isProSet = (m.state.setsToWinMatch == 1);
  final int G = m.state.gamesToWinSet; // 6 para sets normais, 9 para proset

  bool closeSet = false;
  if (!isProSet) {
    // Set normal (G=6)
    if ((g >= 6 && (g - og) >= 2) || (g == 7 && (og == 5 || og == 6))) {
      closeSet = true;
    }
  } else {
    // Pro Set (G=9) — 9–8 fecha o set (vem do TB aos 8–8)
    if ((g == 9 && og == 8) || (g >= 9 && (g - og) >= 2)) {
      closeSet = true;
    }
  }

  if (closeSet) {
    // move set para a lista de concluídos e prepara próximo set/jogo
    final existing = (m.state.score["sets"] as List?) ?? const [];
    final List<Map<String, int>> sets = [
      for (final s in existing)
        if (s is Map)
          {
            "team1": (s["team1"] as num?)?.toInt() ?? 0,
            "team2": (s["team2"] as num?)?.toInt() ?? 0,
          },
    ];

    sets.add(<String, int>{
      "team1": (m.state.score["current"]["games_team1"] as num?)?.toInt() ?? 0,
      "team2": (m.state.score["current"]["games_team2"] as num?)?.toInt() ?? 0,
    });

    m.state.score["sets"] = sets;


    // limpa "current" para o próximo set
    m.state.score["current"] = {
      "points_team1": 0, "points_team2": 0,
      "games_team1": 0,  "games_team2": 0,
      "tb_team1": 0,     "tb_team2": 0,
    };
    m.state.inTieBreak = false;

    // atualiza índices/estado de fim de jogo
    m.state.currentSet = sets.length;
    final w1 = _smWonSetsForTeam(m, 1);
    final w2 = _smWonSetsForTeam(m, 2);
    m.state.matchOver = (w1 >= m.state.setsToWinMatch) || (w2 >= m.state.setsToWinMatch);

    // >>> SUPER TB (se aplicável): se ficou 1–1 em sets, entra diretamente no Super TB
    if (!m.state.matchOver && m.state.superTieBreak && w1 == 1 && w2 == 1) {
      m.state.inTieBreak = true; // arranca super tie-break
      m.state.score["current"] = {
        "points_team1": 0, "points_team2": 0,
        "games_team1": 0,  "games_team2": 0,
        "tb_team1": 0,     "tb_team2": 0,
      };
    }

    if (m.state.matchOver) {
      m.state.score["current"] = {}; // fecha completamente
    }
    return;
  }

  // Ainda não fechou o set → verificar entrada em tie-break
  final bool shouldEnterTB = (() {
    final int g1 = (m.state.score["current"]["games_team1"] ?? 0) as int;
    final int g2 = (m.state.score["current"]["games_team2"] ?? 0) as int;
    if (isProSet) {
      // Pro Set: tie-break ao 8–8
      return g1 == 8 && g2 == 8;
    } else {
      // Set normal: tie-break ao 6–6
      return g1 == 6 && g2 == 6;
    }
  })();

  if (shouldEnterTB) {
    m.state.inTieBreak = true;
    m.state.score["current"]["tb_team1"] = 0;
    m.state.score["current"]["tb_team2"] = 0;
  }
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

  final existing = (m.state.score['sets'] as List?) ?? const [];
  final List<Map<String, int>> sets = [
    for (final s in existing)
      if (s is Map)
        {
          'team1': (s['team1'] as num?)?.toInt() ?? 0,
          'team2': (s['team2'] as num?)?.toInt() ?? 0,
        },
  ];

// garante que existe entrada para currentSet
  final targetIndex = m.state.currentSet < 0 ? 0 : m.state.currentSet;
  while (sets.length <= targetIndex) {
    sets.add(<String, int>{'team1': 0, 'team2': 0});
  }

// escreve de volta no score
  m.state.score['sets'] = sets;


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
