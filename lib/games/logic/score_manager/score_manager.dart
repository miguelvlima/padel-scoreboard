import '../match_state.dart';

part '_helpers.dart';
part '_init.dart';
part '_points.dart';
part '_flow.dart';
part '_edit.dart';
part '_persist.dart';

class ScoreManager {
  final MatchState state;
  ScoreManager(this.state);

  // existing delegates...
  void initializeCurrentSet() => _smInitializeCurrentSet(this);
  String pointsText(int teamNum) => _smPointsText(this, teamNum);
  void incrementPoint(int team) => _smIncrementPoint(this, team);
  void decrementPoint(int team) => _smDecrementPoint(this, team);
  void incrementTieBreak(int team) => _smIncrementTieBreak(this, team);
  void winGame(int team) => _smWinGame(this, team);
  void adjustGameManually(int team, bool increment) =>
      _smAdjustGameManually(this, team, increment);
  void winSet(int team) => _smWinSet(this, team);
  void sanitizeForSave() => _smSanitizeForSave(this);

  // NEW: preview if editing a set would require discarding trailing sets
  int? previewEditDiscardIndex(int index, int team1Val, int team2Val) =>
      _smPreviewTrailingDiscardIndex(this, index, team1Val, team2Val);

  // UPDATED: allow opt-in trailing discard after user confirmation
  bool applyFinishedSetResult(int index, int team1Val, int team2Val,
      {bool allowDiscardTrailing = false}) =>
      _smApplyFinishedSetResult(this, index, team1Val, team2Val,
          allowDiscardTrailing: allowDiscardTrailing);
}
