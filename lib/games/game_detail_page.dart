import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/score_board.dart';
import 'widgets/team_column.dart';
import 'widgets/end_match_dialog.dart';
import 'widgets/app_footer.dart';

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

  String? _courtName;

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
    _loadCourtMeta();
  }

  // ---------------- Meta (court + formato) ----------------
  Future<void> _loadCourtMeta() async {
    try {
      final game = await supabase
          .from('games')
          .select('court_id')
          .eq('id', widget.gameId)
          .eq('admin_key', widget.adminKey)
          .maybeSingle();

      final courtId = game?['court_id'];
      if (courtId == null) {
        if (mounted) setState(() => _courtName = '—');
        return;
      }

      final court = await supabase
          .from('courts')
          .select('name')
          .eq('id', courtId)
          .maybeSingle();

      if (mounted) setState(() => _courtName = (court?['name'] as String?) ?? '—');
    } catch (_) {
      if (mounted) setState(() => _courtName = '—');
    }
  }

  String _formatLabel(String fmt) {
    switch (fmt) {
      case 'best_of_3': return 'Best of 3';
      case 'best_of_3_gp': return 'Best of 3 + GP';
      case 'super_tiebreak': return 'Super Tiebreak';
      case 'super_tiebreak_gp': return 'Super Tiebreak + GP';
      case 'proset': return 'Pro Set';
      case 'proset_gp': return 'Pro Set + GP';
      default: return fmt;
    }
  }

  // ---------------- Persistência ----------------
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

  // ---------------- Reset com confirmação ----------------
  Future<void> _confirmAndResetMatch() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Repor pontuações?'),
        content: const Text(
            'Isto vai apagar todos os sets e pontuações deste jogo e voltar a 0–0. '
                'Queres continuar?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    setState(() {
      state.matchOver = false;
      state.inTieBreak = false;
      state.currentSet = 0;
      state.score = {};
      manager.initializeCurrentSet();
    });

    await _updateScore();
  }

  // ---------------- UI helpers ----------------
  Widget _bg({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF000000), Color(0xFF0A0B0D)],
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // AppBar com duas linhas, auto-scale e tema escuro
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 8,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.player1} / ${widget.player2}',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
              Text(
                '${widget.player3} / ${widget.player4}',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: _confirmAndResetMatch,
            tooltip: 'Reset ao jogo',
          ),
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _confirmEndMatch,
            tooltip: 'Terminar jogo',
          ),
        ],
      ),

      // Footer com copyright
      bottomNavigationBar: const AppFooter(),

      body: _bg(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --------- Meta card (campo + formato) com layout responsivo ---------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      const Icon(Icons.place_outlined),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 160, maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Campo', style: theme.textTheme.labelMedium),
                            Text(
                              _courtName ?? '—',
                              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                              maxLines: 3,
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.rule, size: 18),
                        label: Text(_formatLabel(widget.format)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --------- ScoreBoard (segue o teu widget; tema já trata o estilo) ---------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ScoreBoard(
                    state: state,
                    manager: manager,
                    onPersist: () async {
                      manager.sanitizeForSave();
                      await _updateScore();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --------- Controlo de pontos/jogos com cartões ---------
              Text('Controlo', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TeamColumn(
                      name: "${widget.player1} / ${widget.player2}",
                      onIncPoint: () { manager.incrementPoint(1); _updateScore(); setState(() {}); },
                      onDecPoint: () { manager.decrementPoint(1); _updateScore(); setState(() {}); },
                      onIncGame:  () { manager.adjustGameManually(1, true); _updateScore(); setState(() {}); },
                      onDecGame:  () { manager.adjustGameManually(1, false); _updateScore(); setState(() {}); },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TeamColumn(
                      name: "${widget.player3} / ${widget.player4}",
                      onIncPoint: () { manager.incrementPoint(2); _updateScore(); setState(() {}); },
                      onDecPoint: () { manager.decrementPoint(2); _updateScore(); setState(() {}); },
                      onIncGame:  () { manager.adjustGameManually(2, true); _updateScore(); setState(() {}); },
                      onDecGame:  () { manager.adjustGameManually(2, false); _updateScore(); setState(() {}); },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
