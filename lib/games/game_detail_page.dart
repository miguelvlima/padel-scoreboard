import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/score_board.dart';
import 'widgets/team_column.dart';
import 'widgets/end_match_dialog.dart';
import 'widgets/app_footer.dart';

import 'logic/match_state.dart';
import 'logic/score_manager/score_manager.dart';
import 'logic/format_rules.dart';

import '../app_capabilities.dart';

/// Identidade única por instalação do app.
/// Guardada em secure storage; usada para pedir autorização.
class ClientIdentity {
  final String id;     // único da instalação
  final String label;  // descrição amigável para o admin
  ClientIdentity(this.id, this.label);
}

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
  final AppCapabilities caps;

  const GameDetailPage({
    super.key,
    required this.gameId,
    required this.adminKey,
    required this.player1,
    required this.player2,
    required this.player3,
    required this.player4,
    required this.format,
    required this.caps,
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

  // ---------- Identidade da instalação (client_id) ----------
  final _secure = const FlutterSecureStorage();
  ClientIdentity? _me;

  String _randomId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<ClientIdentity> _getOrCreateClientIdentity() async {
    // 1) id persistente
    var id = await _secure.read(key: 'client_id');
    if (id == null || id.isEmpty) {
      id = _randomId();
      await _secure.write(key: 'client_id', value: id);
    }

    // 2) label útil p/ admin
    final info = DeviceInfoPlugin();
    String label = 'Dispositivo';
    try {
      final a = await info.deviceInfo;
      // tenta campos comuns para apresentar algo útil
      label = (a.data['brand'] ??
          a.data['manufacturer'] ??
          a.data['model'] ??
          a.data['device'] ??
          'Dispositivo')
          .toString();
    } catch (_) {}

    return ClientIdentity(id, label);
  }

  // ------ autorização scorer ------
  String _reqStatus = 'approved'; // admins editam sem pedir; scorer começa 'pending'
  String? _myReqId;
  StreamSubscription<List<Map<String, dynamic>>>? _reqSub;
  StreamSubscription<List<Map<String, dynamic>>>? _adminReqSub;
  Timer? _pollTimer;
  int? _lastSnackForPendingHash; // evita snackbar duplicado

  bool get _isAdmin => widget.caps.canCreateEntities;
  bool get _canEdit => _isAdmin || _reqStatus == 'approved';

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
    if (_startAt == null) _loadStartAt();

    // autorização
    if (_isAdmin) {
      _watchIncomingRequestsForAdmin();
    } else {
      _initScorerAuth(); // cria/segue pedido e bloqueia edição até aprovar
    }
  }

  @override
  void dispose() {
    _reqSub?.cancel();
    _adminReqSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ---------- scorer auth flow ----------
  Future<void> _initScorerAuth() async {
    setState(() {
      _reqStatus = 'pending';
      _myReqId = null;
    });

    final me = await _getOrCreateClientIdentity();
    if (!mounted) return;
    setState(() => _me = me);

    if (await _hasApprovedFor(me.id)) {
      setState(() => _reqStatus = 'approved');
    } else {
      await _createOrReuseRequest(me);
    }

    _watchMyRequest(me.id);     // stream (filtra no cliente)
    _startPollFallback(me.id);  // fallback polling
  }

  Future<bool> _hasApprovedFor(String clientId) async {
    final rows = await supabase
        .from('game_edit_requests')
        .select('client_id,status')
        .eq('game_id', widget.gameId);

    if (rows is! List) return false;
    final list = List<Map<String, dynamic>>.from(rows);
    return list.any((r) =>
    ((r['client_id'] as String?) ?? '') == clientId &&
        ((r['status'] as String?) ?? 'pending') == 'approved');
  }

  Future<void> _createOrReuseRequest(ClientIdentity me) async {
    final last = await supabase
        .from('game_edit_requests')
        .select('id,client_id,status,created_at')
        .eq('game_id', widget.gameId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (last != null && (last['client_id'] as String?) == me.id) {
      final st = (last['status'] as String?) ?? 'pending';
      setState(() {
        _reqStatus = st;
        _myReqId = last['id'] as String?;
      });
      if (st == 'pending' || st == 'approved') return;
    }

    final inserted = await supabase
        .from('game_edit_requests')
        .insert({
      'game_id': widget.gameId,
      'client_id': me.id,
      'client_label': me.label,
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    })
        .select('id,status')
        .single();

    setState(() {
      _myReqId = inserted['id'] as String?;
      _reqStatus = (inserted['status'] as String?) ?? 'pending';
    });
  }

  void _watchMyRequest(String clientId) {
    _reqSub?.cancel();
    _reqSub = supabase
        .from('game_edit_requests')
        .stream(primaryKey: ['id'])
        .execute()
        .listen((rows) {
      if (!mounted || rows.isEmpty) return;

      final mine = rows.where((r) =>
      r['game_id'] == widget.gameId &&
          ((r['client_id'] as String?) ?? '') == clientId).toList();
      if (mine.isEmpty) return;

      final hasApproved = mine.any((r) => ((r['status'] as String?) ?? 'pending') == 'approved');
      final hasPending  = mine.any((r) => ((r['status'] as String?) ?? 'pending') == 'pending');

      mine.sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
      final lastId = mine.last['id'] as String?;

      setState(() {
        _myReqId = lastId;
        _reqStatus = hasApproved ? 'approved' : (hasPending ? 'pending' : 'denied');
      });
    });
  }

  void _startPollFallback(String clientId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (!mounted || _reqStatus == 'approved') {
        t.cancel();
        return;
      }
      final rows = await supabase
          .from('game_edit_requests')
          .select('client_id,status')
          .eq('game_id', widget.gameId);
      if (rows is! List) return;
      final list = List<Map<String, dynamic>>.from(rows);
      final hasApproved = list.any((r) =>
      ((r['client_id'] as String?) ?? '') == clientId &&
          ((r['status'] as String?) ?? 'pending') == 'approved');
      if (hasApproved && _reqStatus != 'approved') {
        setState(() => _reqStatus = 'approved');
      }
    });
  }

  // ---------- admin: pedidos ----------
  void _watchIncomingRequestsForAdmin() {
    _adminReqSub?.cancel();
    _adminReqSub = supabase
        .from('game_edit_requests')
        .stream(primaryKey: ['id'])
        .execute()
        .listen((rows) async {
      if (!mounted || rows.isEmpty) return;

      final pending = rows.where((r) =>
      r['game_id'] == widget.gameId &&
          ((r['status'] as String?) ?? 'pending') == 'pending').toList();
      if (pending.isEmpty) return;

      pending.sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
      final r = pending.last;
      final id = r['id'] as String; // UUID
      final label = (r['client_label'] as String?) ?? 'Dispositivo';
      final hash = id.hashCode;

      if (_lastSnackForPendingHash == hash) return; // evita duplicar
      _lastSnackForPendingHash = hash;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido de autorização: $label'),
          action: SnackBarAction(
            label: 'Autorizar',
            onPressed: () async {
              await supabase.from('game_edit_requests').update({
                'status': 'approved',
                'approved_at': DateTime.now().toUtc().toIso8601String(),
                'approved_by': 'admin',
              }).eq('id', id);
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  Future<void> _openPermissionsSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: supabase
              .from('game_edit_requests')
              .select('id,client_id,client_label,status,created_at,approved_at,approved_by')
              .eq('game_id', widget.gameId)
              .order('created_at', ascending: false),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro a carregar pedidos:\n${snap.error}'),
              );
            }
            final rows = (snap.data ?? []).cast<Map<String, dynamic>>();
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 12 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security),
                      const SizedBox(width: 8),
                      Text('Permissões de edição', style: Theme.of(ctx).textTheme.titleLarge),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Recarregar',
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (rows.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Sem pedidos ainda.'),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          final id = (r['id'] as String?) ?? '';
                          final label = (r['client_label'] as String?) ?? 'Dispositivo';
                          final cid = (r['client_id'] as String?) ?? '';
                          final shortId = cid.length >= 6 ? cid.substring(0, 6) : cid;
                          final status = ((r['status'] as String?) ?? 'pending').toLowerCase();

                          Color chipColor;
                          String chipText;
                          switch (status) {
                            case 'approved':
                              chipColor = Colors.green;
                              chipText = 'APROVADO';
                              break;
                            case 'denied':
                              chipColor = Colors.red;
                              chipText = 'NEGADO';
                              break;
                            default:
                              chipColor = Colors.orange;
                              chipText = 'PENDENTE';
                          }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                            leading: const Icon(Icons.phone_iphone),
                            title: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('ID $shortId', style: Theme.of(context).textTheme.bodySmall),
                                  const SizedBox(width: 10),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: chipColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: chipColor.withOpacity(0.4)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      child: Text(
                                        chipText,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: chipColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Aprovar',
                                  onPressed: status == 'approved'
                                      ? null
                                      : () async {
                                    await supabase.from('game_edit_requests').update({
                                      'status': 'approved',
                                      'approved_at': DateTime.now().toUtc().toIso8601String(),
                                      'approved_by': 'admin',
                                    }).eq('id', id);
                                    if (mounted) setState(() {});
                                  },
                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                ),
                                IconButton(
                                  tooltip: 'Negar',
                                  onPressed: status == 'denied'
                                      ? null
                                      : () async {
                                    await supabase.from('game_edit_requests').update({
                                      'status': 'denied',
                                    }).eq('id', id);
                                    if (mounted) setState(() {});
                                  },
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _resendRequest() async {
    if (_isAdmin) return;
    final me = _me ?? await _getOrCreateClientIdentity();
    await supabase.from('game_edit_requests').insert({
      'game_id': widget.gameId,
      'client_id': me.id,
      'client_label': me.label,
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pedido enviado. Aguarda autorização.')),
    );
  }

  // ---------------- Meta (court + formato) ----------------
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
    } catch (_) {}
  }

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

      final court = await supabase.from('courts').select('name').eq('id', courtId).maybeSingle();
      if (mounted) setState(() => _courtName = (court?['name'] as String?) ?? '—');
    } catch (_) {
      if (mounted) setState(() => _courtName = '—');
    }
  }

  String _formatLabel(String fmt) {
    switch (fmt) {
      case 'best_of_3':
        return 'Best of 3';
      case 'best_of_3_gp':
        return 'Best of 3 + GP';
      case 'super_tiebreak':
        return 'Super Tiebreak';
      case 'super_tiebreak_gp':
        return 'Super Tiebreak + GP';
      case 'proset':
        return 'Pro Set';
      case 'proset_gp':
        return 'Pro Set + GP';
      default:
        return fmt;
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
    if (!_canEdit) {
      _needAuthSnack();
      return;
    }
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
    if (!_canEdit) {
      _needAuthSnack();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Repor pontuações?'),
        content: const Text(
            'Isto vai apagar todos os sets e pontuações deste jogo e voltar a 0–0. '
                'Queres continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
        ],
      ),
    ) ??
        false;

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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF000000), Color(0xFF0A0B0D)],
        ),
      ),
      child: child,
    );
  }

  void _needAuthSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Precisas de autorização do admin para editar.')),
    );
  }

  Widget _campoHoraInline(ThemeData theme) {
    final court = _courtName ?? '—';
    final when = _startAt != null ? _fmtDateTimeShort(_startAt!) : '—';

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 1200),
      child: FittedBox(
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

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Permissões',
              icon: const Icon(Icons.security),
              onPressed: _openPermissionsSheet,
            ),
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
      bottomNavigationBar: const AppFooter(),

      body: _bg(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // -------- Banner compacto de autorização (scorer) --------
              if (!_isAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _canEdit ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _canEdit ? Icons.check_circle : Icons.lock_clock,
                              size: 16,
                              color: _canEdit ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _canEdit ? 'Autorizado' : 'Aguarda autorização',
                              style: theme.textTheme.labelSmall,
                            ),
                            if (!_canEdit) ...[
                              const SizedBox(width: 10),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _resendRequest,
                                icon: const Icon(Icons.send, size: 14),
                                label: const Text('Pedir', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // --------- Meta (campo + formato + hora) ---------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _campoHoraInline(theme),
                      Chip(
                        avatar: const Icon(Icons.rule, size: 18),
                        label: Text(_formatLabel(widget.format)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --------- ScoreBoard (bloqueado se sem autorização) ---------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AbsorbPointer(
                    absorbing: !_canEdit,
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
              ),
              const SizedBox(height: 16),

              // --------- Controlo de pontos/jogos ---------
              Row(
                children: [
                  Expanded(
                    child: TeamColumn(
                      onIncPoint: () {
                        if (!_canEdit) return _needAuthSnack();
                        manager.incrementPoint(1);
                        _updateScore();
                        setState(() {});
                      },
                      onDecPoint: () {
                        if (!_canEdit) return _needAuthSnack();
                        manager.decrementPoint(1);
                        _updateScore();
                        setState(() {});
                      },
                      onIncGame: () {
                        if (!_canEdit) return _needAuthSnack();
                        manager.adjustGameManually(1, true);
                        _updateScore();
                        setState(() {});
                      },
                      onDecGame: () {
                        if (!_canEdit) return _needAuthSnack();
                        manager.adjustGameManually(1, false);
                        _updateScore();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TeamColumn(
                      onIncPoint: () {
                        if (!_canEdit) return _needAuthSnack();
                        manager.incrementPoint(2);
                        _updateScore();
                        setState(() {});
                      },
                      onDecPoint: () {
                        if (!_canEdit) return _needAuthSnack();
                        manager.decrementPoint(2);
                        _updateScore();
                        setState(() {});
                      },
                      onIncGame: () {
                        if (!_canEdit) return _needAuthSnack();
                        manager.adjustGameManually(2, true);
                        _updateScore();
                        setState(() {});
                      },
                      onDecGame: () {
                        if (!_canEdit) return _needAuthSnack();
                        manager.adjustGameManually(2, false);
                        _updateScore();
                        setState(() {});
                      },
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
