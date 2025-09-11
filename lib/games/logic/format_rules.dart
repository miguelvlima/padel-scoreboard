import 'match_state.dart';

void applyFormatRules(MatchState s, String format) {
  switch (format) {
    case 'proset':
      s.setsToWinMatch = 1;
      s.gamesToWinSet  = 9;     // alvo do set
      s.superTieBreak  = false; // sem super TB no fim do match
      s.gpRule         = false; // sem Golden Point
      break;

    case 'proset_gp':
      s.setsToWinMatch = 1;
      s.gamesToWinSet  = 9;
      s.superTieBreak  = false;
      s.gpRule         = true;  // Golden Point
      break;

    case 'best_of_3':
      s.setsToWinMatch = 2;
      s.gamesToWinSet  = 6;
      s.superTieBreak  = false;
      s.gpRule         = false;
      break;

    case 'best_of_3_gp':
      s.setsToWinMatch = 2;
      s.gamesToWinSet  = 6;
      s.superTieBreak  = false;
      s.gpRule         = true;
      break;

    case 'super_tiebreak':
      s.setsToWinMatch = 2;
      s.gamesToWinSet  = 6;
      s.superTieBreak  = true;
      s.gpRule         = false;
      break;

    case 'super_tiebreak_gp':
      s.setsToWinMatch = 2;
      s.gamesToWinSet  = 6;
      s.superTieBreak  = true;
      s.gpRule         = true;
      break;
  }
}

