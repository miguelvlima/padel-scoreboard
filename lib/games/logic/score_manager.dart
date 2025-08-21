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

    // 4) Contagem de sets concluídos e vitórias
    int finishedCount = 0, won1 = 0, won2 = 0;
    for (final s in sets) {
      final t1 = (s['team1'] as int?) ?? 0;
      final t2 = (s['team2'] as int?) ?? 0;
      final finished = t1 >= state.gamesToWinSet || t2 >= state.gamesToWinSet;
      if (finished) {
        finishedCount++;
        if (t1 >= state.gamesToWinSet) won1++;
        if (t2 >= state.gamesToWinSet) won2++;
      }
    }
    state.currentSet = finishedCount;

    // 5) Match over derivado
    state.matchOver = (won1 >= state.setsToWinMatch) || (won2 >= state.setsToWinMatch);
    if (state.matchOver) {
      state.inTieBreak = false;
      state.score['current'] = {}; // não mostrar "Atual"
      return;
    }
    if (!state.matchOver && state.superTieBreak) {
      final active = _isSuperTBActive();
      state.inTieBreak = active; // força TB no 3.º “set”
      if (active) {
        final cur = (state.score['current'] as Map?) ?? const {};
        state.score['current'] = {
          'games_team1': 0, 'games_team2': 0, // ignorados no super TB
          'points_team1': 0, 'points_team2': 0,
          'tb_team1': (cur['tb_team1'] as int?) ?? 0,
          'tb_team2': (cur['tb_team2'] as int?) ?? 0,
        };
      }
    }

    // 6) Preservar 'current'
    final current = (state.score['current'] as Map?) ?? const {};
    state.score['current'] = {
      'games_team1': (current['games_team1'] as int?) ?? 0,
      'games_team2': (current['games_team2'] as int?) ?? 0,
      'points_team1': (current['points_team1'] as int?) ?? 0,
      'points_team2': (current['points_team2'] as int?) ?? 0,
      'tb_team1': (current['tb_team1'] as int?) ?? 0,
      'tb_team2': (current['tb_team2'] as int?) ?? 0,
    };

    // 7) Tie-break ativo só se ambos chegaram ao limite de jogos no set atual
    final g1 = state.score['current']['games_team1'] as int? ?? 0;
    final g2 = state.score['current']['games_team2'] as int? ?? 0;
    state.inTieBreak = (g1 == state.gamesToWinSet && g2 == state.gamesToWinSet);
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

    final target = _isSuperTBActive() ? 10 : 7; // super TB até 10, dif. 2
    if (v >= target && (v - ov) >= 2) {
      winSet(team);                 // fecha o “set” (3.º é o super TB)
      state.inTieBreak = false;
      state.score["current"]["tb_team1"] = 0;
      state.score["current"]["tb_team2"] = 0;
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

    final sets = (state.score['sets'] as List).cast<Map>();
    if (sets.length <= state.currentSet) {
      sets.add({'team1': 0, 'team2': 0});
    }

    // Fechar set: se for super TB ativo, gravar os pontos do TB; senão, os jogos
    if (state.inTieBreak && _isSuperTBActive()) {
      final tb1 = (state.score["current"]?["tb_team1"] as int?) ?? 0;
      final tb2 = (state.score["current"]?["tb_team2"] as int?) ?? 0;
      sets[state.currentSet]['team1'] = tb1;
      sets[state.currentSet]['team2'] = tb2;
    } else {
      final g1 = (state.score["current"]?["games_team1"] as int?) ?? 0;
      final g2 = (state.score["current"]?["games_team2"] as int?) ?? 0;
      sets[state.currentSet]['team1'] = g1;
      sets[state.currentSet]['team2'] = g2;
    }

    // Recalcular match over
    final won1 = sets.where((s) => ((s['team1'] as int?) ?? 0) >= state.gamesToWinSet).length;
    final won2 = sets.where((s) => ((s['team2'] as int?) ?? 0) >= state.gamesToWinSet).length;
    state.matchOver = (won1 >= state.setsToWinMatch) || (won2 >= state.setsToWinMatch);

    final finishedCount = sets.where((s) {
      final t1 = (s['team1'] as int?) ?? 0;
      final t2 = (s['team2'] as int?) ?? 0;
      return t1 >= state.gamesToWinSet || t2 >= state.gamesToWinSet;
    }).length;
    state.currentSet = finishedCount;

    // Limpezas & próximo passo
    state.inTieBreak = false;

    if (state.matchOver) {
      // Remove trailing 0–0 se existir e limpa current
      while (sets.isNotEmpty) {
        final last = sets.last;
        final t1 = (last['team1'] as int?) ?? 0;
        final t2 = (last['team2'] as int?) ?? 0;
        if (t1 == 0 && t2 == 0) { sets.removeLast(); continue; }
        break;
      }
      state.score['current'] = {};
      return;
    }

    // SUPER TIE-BREAK (3.º set por pontos até 10, diferença 2)
    if (_isSuperTBActive()) {
      // Avança o índice para o 3.º "set", mas NÃO prepara jogos
      state.currentSet += 1;
      final maxSets = state.setsToWinMatch * 2 - 1;
      if (state.currentSet > maxSets - 1) state.currentSet = maxSets - 1;

      state.inTieBreak = true;
      state.score["current"] = {
        "games_team1": 0, "games_team2": 0, // ignorados no super TB
        "points_team1": 0, "points_team2": 0,
        "tb_team1": 0, "tb_team2": 0,
      };
      return; // NÃO criar placeholder de jogos; o 3.º é TB
    }

    // Próximo set (caso ainda haja)
    state.currentSet += 1;
    final maxSets = state.setsToWinMatch * 2 - 1;
    if (state.currentSet > maxSets - 1) state.currentSet = maxSets - 1;

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
    final sets = (state.score['sets'] as List?)?.cast<Map>() ?? const [];
    final won1 = sets.where((s) => ((s['team1'] as int?) ?? 0) >= state.gamesToWinSet).length;
    final won2 = sets.where((s) => ((s['team2'] as int?) ?? 0) >= state.gamesToWinSet).length;
    // best-of-3 => super TB quando está 1–1 em sets
    return won1 == 1 && won2 == 1;
  }

  void _recomputeMatchOver() {
    final sets = (state.score['sets'] as List?)?.cast<Map>() ?? const [];
    final won1 = sets.where((s) => ((s['team1'] as int?) ?? 0) >= state.gamesToWinSet).length;
    final won2 = sets.where((s) => ((s['team2'] as int?) ?? 0) >= state.gamesToWinSet).length;
    state.matchOver = (won1 >= state.setsToWinMatch) || (won2 >= state.setsToWinMatch);
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

}
