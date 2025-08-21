import 'match_state.dart';

/// Aplica regras de formato ao estado (nº de jogos por set, nº de sets, golden point).
void applyFormatRules(MatchState state, String format) {
  switch (format) {
    case 'best_of_3':
      state.gamesToWinSet = 6;
      state.setsToWinMatch = 2;
      state.gpRule = false;
      break;
    case 'best_of_3_gp':
      state.gamesToWinSet = 6;
      state.setsToWinMatch = 2;
      state.gpRule = true;
      break;
    case 'super_tiebreak':
      state.gamesToWinSet = 6;
      state.setsToWinMatch = 2;
      state.superTieBreak = true;
      state.gpRule = false;
      break;
    case 'super_tiebreak_gp':
      state.gamesToWinSet = 6;
      state.setsToWinMatch = 2;
      state.superTieBreak = true;
      state.gpRule = true;
      break;
    case 'proset':
      state.gamesToWinSet = 9;
      state.setsToWinMatch = 1;
      state.gpRule = false;
      break;
    case 'proset_gp':
      state.gamesToWinSet = 9;
      state.setsToWinMatch = 1;
      state.gpRule = true;
      break;
  }
}
