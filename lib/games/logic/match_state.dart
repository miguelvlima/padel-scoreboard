class MatchState {
  Map<String, dynamic> score = {};
  final List<String> pointValues = ['0', '15', '30', '40'];
  int gamesToWinSet = 6;
  int setsToWinMatch = 2;
  int currentSet = 0;
  bool inTieBreak = false;
  bool gpRule = false;
  bool matchOver = false;
  bool superTieBreak = false;

  MatchState();
}
