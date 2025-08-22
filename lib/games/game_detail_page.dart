import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/score_board.dart';
import 'widgets/team_column.dart';
import 'widgets/end_match_dialog.dart';
import 'logic/match_state.dart';
import 'logic/score_manager/score_manager.dart';
import 'logic/format_rules.dart';

class GameDetailPage extends StatefulWidget {
  final String gameId;
  final String adminKey;
  final String player1;
  final String player2;
  final String player3;
  final String player4;
  final String format;
  final Map<String, dynamic>? initialScore;

  const GameDetailPage({
    super.key,
    required this.gameId,
    required this.adminKey,
    required this.player1,
    required this.player2,
    required this.player3,
    required this.player4,
    required this.format,
    this.initialScore,
  });

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  final supabase = Supabase.instance.client;

  final MatchState state = MatchState();
  late final ScoreManager manager = ScoreManager(state);

  @override
  void initState() {
    super.initState();
    applyFormatRules(state, widget.format);

    if (widget.initialScore != null && widget.initialScore!.isNotEmpty) {
      state.score = Map<String, dynamic>.from(widget.initialScore!);
      manager.initializeCurrentSet();
    } else {
      _loadScore();
    }
  }

  Future<void> _updateScore() async {

    manager.sanitizeForSave();

    await supabase
        .from('games')
        .update({'score': state.score})
        .eq('id', widget.gameId)
        .eq('admin_key', widget.adminKey);
  }

  Future<void> _loadScore() async {
    final response = await supabase
        .from('games')
        .select('score')
        .eq('id', widget.gameId)
        .eq('admin_key', widget.adminKey)
        .maybeSingle();

    if (response != null && response['score'] != null) {
      setState(() {
        state.score = Map<String, dynamic>.from(response['score'] as Map<String, dynamic>);
        manager.initializeCurrentSet();
      });
    } else {
      setState(() {
        state.score = {};
        manager.initializeCurrentSet();
      });
    }
  }

  void _confirmEndMatch() {
    showDialog(
      context: context,
      builder: (_) => EndMatchDialog(onConfirm: () {
        setState(() {
          state.matchOver = true;
        });
        _updateScore();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.player1} / ${widget.player2}  vs  ${widget.player3} / ${widget.player4}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _confirmEndMatch,
            tooltip: 'Terminar jogo',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ScoreBoard(
              state: state,
              manager: manager,
              onPersist: () async {
                manager.sanitizeForSave();
                await _updateScore(); // o teu método Supabase
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TeamColumn(
                  name: "${widget.player1} / ${widget.player2}",
                  onIncPoint: () { manager.incrementPoint(1); _updateScore(); setState(() {}); },
                  onDecPoint: () { manager.decrementPoint(1); _updateScore(); setState(() {}); },
                  onIncGame:  () { manager.adjustGameManually(1, true); _updateScore(); setState(() {}); },
                  onDecGame:  () { manager.adjustGameManually(1, false); _updateScore(); setState(() {}); },
                ),
                TeamColumn(
                  name: "${widget.player3} / ${widget.player4}",
                  onIncPoint: () { manager.incrementPoint(2); _updateScore(); setState(() {}); },
                  onDecPoint: () { manager.decrementPoint(2); _updateScore(); setState(() {}); },
                  onIncGame:  () { manager.adjustGameManually(2, true); _updateScore(); setState(() {}); },
                  onDecGame:  () { manager.adjustGameManually(2, false); _updateScore(); setState(() {}); },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
