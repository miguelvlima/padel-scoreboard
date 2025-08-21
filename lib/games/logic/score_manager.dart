import 'match_state.dart';

/// Responsável pela lógica de pontuação/sets e pela estrutura do score.
class ScoreManager {
  final MatchState state;
  ScoreManager(this.state);

  void initializeCurrentSet() {
    // 1) Estrutura base
    state.score.putIfAbsent('sets', () => <Map<String, int>>[]);
    List<Map> sets = (state.score['sets'] as List).cast<Map>();

    // 2) Limite pelo formato (best-of-N ⇒ maxSets = 2*N - 1)
    final maxSets = state.setsToWinMatch * 2 - 1;
    if (sets.length > maxSets) {
      sets = sets.sublist(0, maxSets);
      state.score['sets'] = sets;
    }

    // 3) REMOVER “trailers” vazios (… , {0,0}, {0,0}, …)
    while (sets.isNotEmpty) {
      final last = sets.last;
      final t1 = (last['team1'] as int?) ?? 0;
      final t2 = (last['team2'] as int?) ?? 0;
      if (t1 == 0 && t2 == 0) { sets.removeLast(); continue; }
      break;
    }
    state.score['sets'] = sets;

    // 4) Contagem de sets CONCLUÍDOS (usa _isSetConcluded) e vitórias por equipa
    final finishedSets = sets.where((s) => _isSetConcluded(s)).toList();
    state.currentSet = finishedSets.length;

    final won1 = finishedSets.where((s) => ((s['team1'] as int?) ?? 0) > ((s['team2'] as int?) ?? 0)).length;
    final won2 = finishedSets.where((s) => ((s['team2'] as int?) ?? 0) > ((s['team1'] as int?) ?? 0)).length;

    // Atualiza matchOver com base em sets GANHOS
    state.matchOver = (won1 >= state.setsToWinMatch) || (won2 >= state.setsToWinMatch);
    if (state.matchOver) {
      state.inTieBreak = false;
      state.score['current'] = {}; // não mostrar "Atual"
      return;
    }

    // 5) Super TB ativo? (3.º “set” em formatos super com 1–1)
    if (!state.matchOver && state.superTieBreak) {
      final active = _isSuperTBActive();
      state.inTieBreak = active; // força TB no 3.º “set”
      if (active) {
        final cur = (state.score['current'] as Map?) ?? const {};
        state.score['current'] = {
          'games_team1': 0, 'games_team2': 0,  // ignorados no super TB
          'points_team1': 0, 'points_team2': 0,
          'tb_team1': (cur['tb_team1'] as int?) ?? 0,
          'tb_team2': (cur['tb_team2'] as int?) ?? 0,
        };
        return; // já estamos em super TB — não reavaliar tie-break normal
      }
    }

    // 6) Preservar/Completar 'current'
    final current = (state.score['current'] as Map?) ?? const {};
    state.score['current'] = {
      'games_team1': (current['games_team1'] as int?) ?? 0,
      'games_team2': (current['games_team2'] as int?) ?? 0,
      'points_team1': (current['points_team1'] as int?) ?? 0,
      'points_team2': (current['points_team2'] as int?) ?? 0,
      'tb_team1': (current['tb_team1'] as int?) ?? 0,
      'tb_team2': (current['tb_team2'] as int?) ?? 0,
    };

    // 7) Tie-break NORMAL ativo só se o set atual está 6–6
    final g1 = state.score['current']['games_team1'] as int? ?? 0;
    final g2 = state.score['current']['games_team2'] as int? ?? 0;
    state.inTieBreak = (g1 == state.gamesToWinSet && g2 == state.gamesToWinSet);
  }


  bool _isSetConcluded(Map s) {
    final t1 = (s['team1'] as int?) ?? 0;
    final t2 = (s['team2'] as int?) ?? 0;
    return (t1 != t2) && ((t1 >= state.gamesToWinSet) || (t2 >= state.gamesToWinSet));
  }

  String pointsText(int teamNum) {
    if (state.inTieBreak) {
      final tb = state.score["current"]["tb_team$teamNum"] as int? ?? 0;
      return state.superTieBreak && _isSuperTBActive()
          ? "Super TB: $tb"
          : "Tie-Break: $tb";
    }

    final p = (state.score["current"]["points_team$teamNum"] as int? ?? 0);
    final opp = (state.score["current"]["points_team${teamNum == 1 ? 2 : 1}"] as int? ?? 0);

    if (!state.gpRule) {
      // Regras com vantagem
      if (p <= 3 && opp <= 3) {
        return "Points: ${state.pointValues[p]}";
      }
      if (p == 4 && opp < 4) {
        return "Points: Ad";
      }
      if (opp == 4 && p < 4) {
        return "Points: 40";
      }
      // Deuce
      return "Points: 40";
    } else {
      // Golden point: só 0/15/30/40, sem Ad
      final idx = p.clamp(0, 3);
      return "Points: ${state.pointValues[idx]}";
    }
  }

  void incrementPoint(int team) {
    if (state.matchOver) return;

    // SUPER TIE-BREAK ou tie-break normal: contam pontos sequenciais no TB
    if (state.inTieBreak || _isSuperTBActive()) {
      state.inTieBreak = true;       // garante que o UI mostra TB
      incrementTieBreak(team);
      return;                        // NUNCA mexer em points 15/30/40 nem em games aqui
    }

    final selfKey = "points_team$team";
    final oppTeam = team == 1 ? 2 : 1;
    final oppKey = "points_team$oppTeam";

    int p = state.score["current"][selfKey] ?? 0;
    int o = state.score["current"][oppKey] ?? 0;

    if (!state.gpRule) {
      // Com vantagem
      if (p >= 3 && o < 3) {
        // 40-x -> ganha jogo
        winGame(team);
        return;
      }
      if (p == 3 && o == 3) {
        // deuce -> Ad
        state.score["current"][selfKey] = 4;
      } else if (p == 4 && o == 4) {
        // ambos em Ad (raro) -> volta a deuce
        state.score["current"][selfKey] = 3;
        state.score["current"][oppKey] = 3;
      } else if (p == 4) {
        // tens Ad e marcas -> jogo
        winGame(team);
        return;
      } else if (o == 4) {
        // adversário tem Ad -> retira Ad (volta deuce)
        state.score["current"][oppKey] = 3;
      } else {
        // 0,15,30 -> +1
        state.score["current"][selfKey] = p + 1;
      }
    } else {
      // Golden point
      if (p >= 3 && o >= 3) {
        winGame(team);
        return;
      }
      if (p >= 3) {
        winGame(team);
        return;
      }
      state.score["current"][selfKey] = p + 1;
    }
  }

  void decrementPoint(int team) {
    if (state.inTieBreak) {
      final key = "tb_team$team";
      final v = (state.score["current"][key] as int? ?? 0);
      state.score["current"][key] = v > 0 ? v - 1 : 0;
      return;
    }
    final key = "points_team$team";
    final v = (state.score["current"][key] as int? ?? 0);
    state.score["current"][key] = v > 0 ? v - 1 : 0;
  }

  void incrementTieBreak(int team) {
    final key = "tb_team$team";
    state.score["current"][key] = (state.score["current"][key] as int? ?? 0) + 1;

    final other = team == 1 ? 2 : 1;
    final v  = state.score["current"][key] as int;
    final ov = state.score["current"]["tb_team$other"] as int? ?? 0;

    final target = _isSuperTBActive() ? 10 : 7;
    if (v >= target && (v - ov) >= 2) {
      winSet(team);   // <-- só isto
      return;         // NÃO mexer em state.inTieBreak nem zerar tb aqui
    }
  }

  void winGame(int team) {

    if (state.matchOver) return;

    final gKey = "games_team$team";
    state.score["current"][gKey] = (state.score["current"][gKey] as int? ?? 0) + 1;

    // reset points
    state.score["current"]["points_team1"] = 0;
    state.score["current"]["points_team2"] = 0;

    final g1 = state.score["current"]["games_team1"] as int? ?? 0;
    final g2 = state.score["current"]["games_team2"] as int? ?? 0;

    if ((g1 >= state.gamesToWinSet || g2 >= state.gamesToWinSet) && ( (g1 - g2).abs() >= 2 )) {
      winSet(g1 > g2 ? 1 : 2);
    } else if (g1 == state.gamesToWinSet && g2 == state.gamesToWinSet) {
      state.inTieBreak = true;
    }

    _recomputeMatchOver();
    if (state.matchOver) {
      state.inTieBreak = false;
    }

  }

  void adjustGameManually(int team, bool increment) {

    if (state.matchOver || state.inTieBreak || _isSuperTBActive()) return;

    final gKey = "games_team$team";
    int current = state.score["current"][gKey] as int? ?? 0;
    current = increment ? current + 1 : (current > 0 ? current - 1 : 0);
    state.score["current"][gKey] = current;

    int g1 = state.score["current"]["games_team1"] as int? ?? 0;
    int g2 = state.score["current"]["games_team2"] as int? ?? 0;

    if ((g1 >= state.gamesToWinSet || g2 >= state.gamesToWinSet) && ((g1 - g2).abs() >= 2)) {
      winSet(g1 > g2 ? 1 : 2);
    } else if (g1 == state.gamesToWinSet && g2 == state.gamesToWinSet) {
      state.inTieBreak = true;
    }

    _recomputeMatchOver();
    if (state.matchOver) {
      state.inTieBreak = false;
    }

  }

  void winSet(int team) {
    if (state.matchOver) return;

    final wasTB = state.inTieBreak;

    // snapshot antes de qualquer limpeza
    final curG1  = (state.score["current"]?["games_team1"] as int?) ?? 0;
    final curG2  = (state.score["current"]?["games_team2"] as int?) ?? 0;
    final curTB1 = (state.score["current"]?["tb_team1"]    as int?) ?? 0;
    final curTB2 = (state.score["current"]?["tb_team2"]    as int?) ?? 0;

    final sets = (state.score['sets'] as List).cast<Map>();
    if (sets.length <= state.currentSet) {
      sets.add({'team1': 0, 'team2': 0});
    }

    // Fechar set: TB normal vs Super TB vs jogos normais
    if (wasTB) {
      final isSuperTB = _isSuperTBActive();
      if (isSuperTB) {
        // SUPER TB: gravar pontos do TB como resultado do 3.º “set”
        sets[state.currentSet]['team1'] = curTB1;
        sets[state.currentSet]['team2'] = curTB2;
      } else {
        // TIE-BREAK NORMAL (6–6): resultado 7–6 para o vencedor
        final win  = team == 1 ? 'team1' : 'team2';
        final lose = team == 1 ? 'team2' : 'team1';
        sets[state.currentSet][win]  = state.gamesToWinSet + 1; // 7
        sets[state.currentSet][lose] = state.gamesToWinSet;     // 6
      }
    } else {
      // Jogo normal (sem TB): fechar com jogos correntes
      sets[state.currentSet]['team1'] = curG1;
      sets[state.currentSet]['team2'] = curG2;
    }

    // Recalcular match over e nº de sets concluídos (SEM incrementar manualmente)
    final won1 = _wonSetsForTeam(1);
    final won2 = _wonSetsForTeam(2);
    state.matchOver = (won1 >= state.setsToWinMatch) || (won2 >= state.setsToWinMatch);

    state.currentSet = ((state.score['sets'] as List).cast<Map>())
        .where(_isSetConcluded)
        .length;

    // Limpezas
    state.inTieBreak = false;

    if (state.matchOver) {
      // remove trailing 0–0 e limpa current
      final setsList = (state.score['sets'] as List).cast<Map>();
      while (setsList.isNotEmpty) {
        final last = setsList.last;
        final t1 = (last['team1'] as int?) ?? 0;
        final t2 = (last['team2'] as int?) ?? 0;
        if (t1 == 0 && t2 == 0) { setsList.removeLast(); continue; }
        break;
      }
      state.score['current'] = {};
      return;
    }

    // Se ficou 1–1 e o formato é super, preparar o 3.º como SUPER TB (sem mexer currentSet)
    if (state.superTieBreak && won1 == 1 && won2 == 1) {
      state.inTieBreak = true;
      state.score["current"] = {
        "games_team1": 0, "games_team2": 0, // ignorados no super TB
        "points_team1": 0, "points_team2": 0,
        "tb_team1": 0, "tb_team2": 0,
      };
      return; // sem placeholder de jogos
    }

    // Próximo set NORMAL: apenas reset do 'current' (NÃO alterar currentSet!)
    state.score["current"] = {
      "games_team1": 0, "games_team2": 0,
      "points_team1": 0, "points_team2": 0,
      "tb_team1": 0, "tb_team2": 0,
    };
  }




  bool _isSetFinished(Map s) {
    final t1 = (s['team1'] as int?) ?? 0;
    final t2 = (s['team2'] as int?) ?? 0;
    return t1 >= state.gamesToWinSet || t2 >= state.gamesToWinSet;
  }

  bool _isSuperTBActive() {
    if (!state.superTieBreak || state.matchOver) return false;
    final w1 = _wonSetsForTeam(1);
    final w2 = _wonSetsForTeam(2);
    return w1 == 1 && w2 == 1; // só no 3.º set, 1–1
  }

  void _recomputeMatchOver() {
    final w1 = _wonSetsForTeam(1);
    final w2 = _wonSetsForTeam(2);
    state.matchOver = (w1 >= state.setsToWinMatch) || (w2 >= state.setsToWinMatch);
  }

  void sanitizeForSave() {
    final maxSets = state.setsToWinMatch * 2 - 1;
    List<Map> sets = (state.score['sets'] as List?)?.cast<Map>() ?? [];

    // recorta ao máximo
    if (sets.length > maxSets) sets = sets.sublist(0, maxSets);

    // remove trailing 0–0 e também sets não concluídos no fim
    while (sets.isNotEmpty) {
      final last = sets.last;
      final t1 = (last['team1'] as int?) ?? 0;
      final t2 = (last['team2'] as int?) ?? 0;
      final finished = t1 >= state.gamesToWinSet || t2 >= state.gamesToWinSet;
      if (t1 == 0 && t2 == 0) { sets.removeLast(); continue; }
      if (!finished) { sets.removeLast(); continue; }
      break;
    }

    state.score['sets'] = sets;

    if (state.matchOver) {
      state.score['current'] = {}; // não gravar “Atual” depois de acabar
    }
  }

  int _wonSetsForTeam(int team) {
    final sets = (state.score['sets'] as List?)?.cast<Map>() ?? const [];
    int won = 0;
    for (final s in sets) {
      final t1 = (s['team1'] as int?) ?? 0;
      final t2 = (s['team2'] as int?) ?? 0;
      final finished = (t1 >= state.gamesToWinSet) || (t2 >= state.gamesToWinSet);
      if (!finished) continue;
      if (team == 1 && t1 > t2) won++;
      if (team == 2 && t2 > t1) won++;
    }
    return won;
  }

}
