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
  final DateTime? startAt;

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
    this.startAt,
  });

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  final supabase = Supabase.instance.client;

  final MatchState state = MatchState();
  late final ScoreManager manager = ScoreManager(state);

  String? _courtName;
  DateTime? _startAt;

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDateTimeShort(DateTime dtLocal) =>
      '${_two(dtLocal.day)}/${_two(dtLocal.month)}/${dtLocal.year} ${_two(dtLocal.hour)}:${_two(dtLocal.minute)}';

  @override
  void initState() {
    super.initState();
    applyFormatRules(state, widget.format);

    _startAt = widget.startAt;

    if (widget.initialScore != null && widget.initialScore!.isNotEmpty) {
      state.score = Map<String, dynamic>.from(widget.initialScore!);
      manager.initializeCurrentSet();
    } else {
      _loadScore();
    }
    _loadCourtMeta();

    if (_startAt == null) _loadStartAt(); // ⬅️ opcional (caso não venha no push)
  }

  Future<void> _loadStartAt() async {
    try {
      final row = await supabase
          .from('games')
          .select('start_at')
          .eq('id', widget.gameId)
          .eq('admin_key', widget.adminKey)
          .maybeSingle();

      final iso = row?['start_at'] as String?;
      if (iso != null && mounted) {
        setState(() => _startAt = DateTime.parse(iso).toLocal());
      }
    } catch (_) {
      // silencioso
    }
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
        title: const Text(''),
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
                      _campoHoraInline(theme), // ⬅️ Campo + Dia&Hora SEM QUEBRA, encolhe se necessário
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
                    team1p1: widget.player1,
                    team1p2: widget.player2,
                    team2p1: widget.player3,
                    team2p2: widget.player4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --------- Controlo de pontos/jogos com cartões ---------
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TeamColumn(
                      onIncPoint: () { manager.incrementPoint(1); _updateScore(); setState(() {}); },
                      onDecPoint: () { manager.decrementPoint(1); _updateScore(); setState(() {}); },
                      onIncGame:  () { manager.adjustGameManually(1, true); _updateScore(); setState(() {}); },
                      onDecGame:  () { manager.adjustGameManually(1, false); _updateScore(); setState(() {}); },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TeamColumn(
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

  Widget _campoHoraInline(ThemeData theme) {
    final court = _courtName ?? '—';
    final when  = widget.startAt != null
        ? _fmtDateTimeShort(widget.startAt!.toLocal())
        : '—';

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 1200),
      child: FittedBox( // encolhe para caber numa linha
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.place_outlined),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Campo', style: theme.textTheme.labelMedium),
                Text(
                  court,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ],
            ),
            const SizedBox(width: 16),
            const Icon(Icons.schedule_outlined),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dia & hora', style: theme.textTheme.labelMedium),
                Text(
                  when,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


}
