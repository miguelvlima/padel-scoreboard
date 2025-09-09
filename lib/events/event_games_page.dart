import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_capabilities.dart';
import '../games/game_detail_page.dart';
import '../games/widgets/app_footer.dart';

class EventGamesPage extends StatefulWidget {
  final String eventId;
  final String eventName;
  final AppCapabilities caps;
  const EventGamesPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.caps,
  });

  @override
  State<EventGamesPage> createState() => _EventGamesPageState();
}

class _EventGamesPageState extends State<EventGamesPage> {
  final supabase = Supabase.instance.client;

  // Courts map just to render names (never blocks the list)
  Map<String, String> _courtNameById = {};

  // timer para press contínuo (2 segundos)
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _fetchCourtsForList(); // fire-and-forget; UI não espera
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCourtsForList() async {
    try {
      final rows = await supabase.from('courts').select('id, name').order('name');
      final list = List<Map<String, dynamic>>.from(rows);
      if (!mounted) return;
      setState(() {
        _courtNameById = {
          for (final c in list) (c['id'] as String): (c['name'] as String),
        };
      });
    } catch (_) {
      // ignore – mostra "—" até haver courts
    }
  }

  String _formatLabel(String fmt) {
    switch (fmt) {
      case 'best_of_3':
        return 'Best of 3';
      case 'best_of_3_gp':
        return 'Best of 3 + GP';
      case 'super_tiebreak':
        return 'Super TB';
      case 'super_tiebreak_gp':
        return 'Super TB + GP';
      case 'proset':
        return 'Pro Set';
      case 'proset_gp':
        return 'Pro Set + GP';
      default:
        return fmt;
    }
  }

  // ------- criação de jogo (sheet) -------
  Future<void> _openCreateGameSheet() async {
    // proteção: modo consulta não cria jogos
    if (!widget.caps.canCreateEntities) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este modo não permite criar jogos.')),
        );
      }
      return;
    }

    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final p3 = TextEditingController();
    final p4 = TextEditingController();
    String format = 'best_of_3';
    String? courtId = _courtNameById.keys.isNotEmpty ? _courtNameById.keys.first : null;
    DateTime? startAt = DateTime.now(); // default: agora (pode ser alterado)

    // lazy-load courts se vazio
    if (_courtNameById.isEmpty) {
      try {
        final rows = await supabase.from('courts').select('id, name').order('name');
        final list = List<Map<String, dynamic>>.from(rows);
        if (list.isNotEmpty) {
          _courtNameById = {for (final c in list) (c['id'] as String): (c['name'] as String)};
          courtId = _courtNameById.keys.first;
          if (mounted) setState(() {});
        }
      } catch (_) {}
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Novo jogo', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _text(ctx, p1, 'Jogador 1'),
                    const SizedBox(height: 8),
                    _text(ctx, p2, 'Jogador 2'),
                    const SizedBox(height: 8),
                    _text(ctx, p3, 'Jogador 3'),
                    const SizedBox(height: 8),
                    _text(ctx, p4, 'Jogador 4'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: courtId,
                      decoration: const InputDecoration(labelText: 'Court'),
                      items: _courtNameById.entries
                          .map((e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      ))
                          .toList(),
                      onChanged: (v) => setSheet(() => courtId = v),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: const Text('Data & hora'),
                      subtitle: Text(startAt != null ? _fmtDateTimeShort(startAt!) : '—'),
                      trailing: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('Escolher'),
                        onPressed: () async {
                          final picked = await _pickDateTime(context, startAt);
                          if (picked != null) setSheet(() => startAt = picked);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: format,
                      decoration: const InputDecoration(labelText: 'Formato'),
                      items: const [
                        DropdownMenuItem(value: 'best_of_3', child: Text('Best of 3')),
                        DropdownMenuItem(value: 'best_of_3_gp', child: Text('Best of 3 + GP')),
                        DropdownMenuItem(value: 'super_tiebreak', child: Text('Super Tiebreak')),
                        DropdownMenuItem(value: 'super_tiebreak_gp', child: Text('Super Tiebreak + GP')),
                        DropdownMenuItem(value: 'proset', child: Text('Pro Set')),
                        DropdownMenuItem(value: 'proset_gp', child: Text('Pro Set + GP')),
                      ],
                      onChanged: (v) => setSheet(() => format = v ?? 'best_of_3'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        const Spacer(),
                        FilledButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Criar'),
                          onPressed: () async {
                            final player1 = p1.text.trim();
                            final player2 = p2.text.trim();
                            final player3 = p3.text.trim();
                            final player4 = p4.text.trim();

                            if ([player1, player2, player3, player4].any((e) => e.isEmpty)) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Preenche os 4 jogadores.')),
                              );
                              return;
                            }
                            if (courtId == null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Escolhe o court.')),
                              );
                              return;
                            }

                            final adminKey = DateTime.now().millisecondsSinceEpoch.toString();
                            await supabase.from('games').insert({
                              'event_id': widget.eventId,
                              'player1': player1,
                              'player2': player2,
                              'player3': player3,
                              'player4': player4,
                              'format': format,
                              'start_at': startAt?.toUtc().toIso8601String(),
                              'court_id': courtId,
                              'admin_key': adminKey,
                              'score': {
                                "current": {
                                  "points_team1": 0,
                                  "points_team2": 0,
                                  "games_team1": 0,
                                  "games_team2": 0,
                                  "tb_team1": 0,
                                  "tb_team2": 0,
                                },
                                "sets": [
                                  {"team1": 0, "team2": 0},
                                  {"team1": 0, "team2": 0},
                                  {"team1": 0, "team2": 0},
                                ]
                              },
                              'created_at': DateTime.now().toIso8601String(),
                            });

                            if (mounted) Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _text(BuildContext ctx, TextEditingController c, String label) {
    return TextField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      textInputAction: TextInputAction.next,
    );
  }

  // -------------------------------------------

  String _scoreSummary(Map<String, dynamic> score, String format) {
    final isProset = format.startsWith('proset');
    final isSuperFormat = format.startsWith('super_tiebreak');
    final G = isProset ? 9 : 6;
    final maxSets = isProset ? 1 : 3;
    final setsToWin = isProset ? 1 : 2;

    final rawSets = List<Map<String, dynamic>>.from(score['sets'] ?? const []);
    final current = Map<String, dynamic>.from(score['current'] ?? const {});

    bool isFinishedSet(int t1, int t2, int index) {
      final maxV = t1 > t2 ? t1 : t2;
      final minV = t1 > t2 ? t2 : t1;
      final diff = (t1 - t2).abs();

      if (isSuperFormat && index == maxSets - 1 && maxV >= 9) {
        return (maxV >= 10) && (diff >= 2);
      }
      if (G == 6) {
        if (maxV == 6 && diff >= 2) return true;
        if (maxV == 7 && (minV == 5 || minV == 6)) return true;
        return false;
      }
      return (maxV >= G) && (diff >= 2);
    }

    final finished = <Map<String, int>>[];
    for (int i = 0; i < rawSets.length && i < maxSets; i++) {
      final s = rawSets[i];
      final t1 = (s['team1'] as num?)?.toInt() ?? 0;
      final t2 = (s['team2'] as num?)?.toInt() ?? 0;
      if (isFinishedSet(t1, t2, i)) {
        finished.add({'team1': t1, 'team2': t2});
      }
    }

    int w1 = 0, w2 = 0;
    for (final s in finished) {
      if (s['team1']! > s['team2']!) w1++;
      if (s['team2']! > s['team1']!) w2++;
    }
    final matchOver = (w1 >= setsToWin) || (w2 >= setsToWin);

    final parts = <String>[
      for (final s in finished) '${s['team1']}-${s['team2']}',
    ];

    if (!matchOver && current.isNotEmpty) {
      final g1 = (current['games_team1'] as num?)?.toInt() ?? 0;
      final g2 = (current['games_team2'] as num?)?.toInt() ?? 0;
      final tb1 = (current['tb_team1'] as num?)?.toInt() ?? 0;
      final tb2 = (current['tb_team2'] as num?)?.toInt() ?? 0;

      if (isSuperFormat && w1 == 1 && w2 == 1) {
        parts.add('STB: $tb1-$tb2');
      } else if (!isProset && g1 == G && g2 == G) {
        parts.add('TB: $tb1-$tb2');
      } else {
        parts.add('$g1-$g2');
      }
    } else if (parts.isEmpty) {
      parts.add('0-0');
    }

    return parts.join(' | ');
  }

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

  // =========================================================
  // =============== SCOREBOARDS (long-press) ================
  // =========================================================

  // Press & hold helpers (2s)
  void _startHold(VoidCallback onElapsed) {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 2), () {
      _holdTimer = null;
      onElapsed();
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  // Abre o menu principal para um jogo: memberships + botão Adicionar
  Future<void> _openScoreboardsMenu(String gameId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 12 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: FutureBuilder<_ScoreboardMembershipData>(
            future: _loadMembershipAndBoards(gameId),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
              }
              final data = snap.data!;
              return StatefulBuilder(
                builder: (ctx, setSheet) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scoreboards', style: Theme.of(ctx).textTheme.titleLarge),
                      const SizedBox(height: 8),

                      if (data.memberships.isEmpty)
                        const ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('Este jogo não está em nenhum scoreboard.'),
                        )
                      else
                        ...data.memberships.map(
                              (m) => ListTile(
                            leading: const Icon(Icons.tv),
                            title: Text(m.boardTitle),
                            subtitle: Text('Posição ${m.position}'),
                            trailing: widget.caps.canCreateEntities
                                ? IconButton(
                              tooltip: 'Remover deste scoreboard',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () async {
                                try {
                                  await supabase
                                      .from('scoreboard_selections')
                                      .delete()
                                      .eq('id', m.selectionId);
                                  final refreshed = await _loadMembershipAndBoards(gameId);
                                  setSheet(() {
                                    data.memberships
                                      ..clear()
                                      ..addAll(refreshed.memberships);
                                    data.boards
                                      ..clear()
                                      ..addAll(refreshed.boards);
                                  });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Removido de "${m.boardTitle}".')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erro ao remover: $e')),
                                    );
                                  }
                                }
                              },
                            )
                                : null,
                          ),
                        ),

                      const Divider(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar a scoreboard'),
                          onPressed: widget.caps.canCreateEntities
                              ? () async {
                            final added = await _showAddToScoreboardSheet(gameId);
                            if (added == true) {
                              final refreshed = await _loadMembershipAndBoards(gameId);
                              setSheet(() {
                                data.memberships
                                  ..clear()
                                  ..addAll(refreshed.memberships);
                                data.boards
                                  ..clear()
                                  ..addAll(refreshed.boards);
                              });
                            }
                          }
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // Sheet para escolher scoreboard + posição e gravar
  Future<bool?> _showAddToScoreboardSheet(String gameId) async {
    final boards = await _fetchBoards();
    if (boards.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há scoreboards. Cria uma primeiro.')),
      );
      return false;
    }

    String selectedBoardId = boards.first['id'] as String;
    List<int> positions = await _positionsForBoard(selectedBoardId);
    int? selectedPos = positions.isNotEmpty ? positions.first : null;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
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
                  Text('Adicionar a scoreboard', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedBoardId,
                    decoration: const InputDecoration(labelText: 'Scoreboard'),
                    items: boards.map<DropdownMenuItem<String>>((b) {
                      final title = (b['title'] as String?)?.trim();
                      final key = (b['key'] as String?)?.trim();
                      final label = (title?.isNotEmpty == true ? title! : key ?? 'Sem título');
                      return DropdownMenuItem(
                        value: b['id'] as String,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      selectedBoardId = v;
                      positions = await _positionsForBoard(selectedBoardId); // SEM filtrar ocupadas
                      selectedPos = positions.isNotEmpty ? positions.first : null;
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: positions.contains(selectedPos) ? selectedPos : (positions.isNotEmpty ? positions.first : null),
                    decoration: const InputDecoration(labelText: 'Posição'),
                    items: positions.map((p) => DropdownMenuItem<int>(value: p, child: Text('Posição $p'))).toList(),
                    onChanged: (v) => setSheet(() => selectedPos = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Adicionar'),
                        onPressed: selectedPos == null
                            ? null
                            : () async {
                          try {
                            await _assignGameToBoard(selectedBoardId, selectedPos!, gameId);
                            if (context.mounted) {
                              Navigator.pop(ctx, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Atribuído à posição $selectedPos.')),
                              );
                            }
                          } on PostgrestException catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro: ${e.message}')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro: $e')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===================== APAGAR JOGO (admin-only) =====================

  Future<bool> _confirmDeleteGame(String teamA, String teamB) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar jogo?'),
        content: Text('Isto vai apagar o jogo:\n$teamA  vs  $teamB'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteGame(String gameId) async {
    try {
      await supabase.from('games').delete().eq('id', gameId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jogo apagado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao apagar: $e')),
        );
      }
    }
  }

  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.caps.canCreateEntities == true;

    return Scaffold(
      appBar: AppBar(title: Text('Jogos — ${widget.eventName}', maxLines: 2, overflow: TextOverflow.ellipsis)),
      bottomNavigationBar: const AppFooter(),
      body: Stack(
        children: [
          _bg(
            child: SafeArea(
              bottom: false,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase
                    .from('games')
                    .stream(primaryKey: ['id'])
                    .eq('event_id', widget.eventId)
                    .order('created_at', ascending: true)
                    .execute(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Erro a carregar jogos:\n${snapshot.error}', textAlign: TextAlign.center),
                      ),
                    );
                  }
                  final games = snapshot.data ?? [];
                  if (games.isEmpty) {
                    return const Center(child: Text('Nenhum jogo criado.'));
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await supabase.from('games').select('id').eq('event_id', widget.eventId).limit(1);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final g = games[index];

                        final p1 = g['player1'] ?? '';
                        final p2 = g['player2'] ?? '';
                        final p3 = g['player3'] ?? '';
                        final p4 = g['player4'] ?? '';
                        final format = g['format'] ?? 'best_of_3';
                        final adminKey = g['admin_key'] ?? '';
                        final gameId = g['id']?.toString() ?? '';
                        final courtId = g['court_id']?.toString();
                        final court = courtId != null ? (_courtNameById[courtId] ?? '—') : '—';
                        final startAtIso = g['start_at'] as String?;
                        final startAt = startAtIso != null ? DateTime.parse(startAtIso).toLocal() : null;

                        final scoreJson = g['score'] != null
                            ? Map<String, dynamic>.from(g['score'] as Map<String, dynamic>)
                            : <String, dynamic>{};

                        final teamALabel = '$p1 / $p2';
                        final teamBLabel = '$p3 / $p4';

                        // Conteúdo do cartão com overlay de apagar (X) só para admin
                        final cardInner = Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(teamALabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium),
                              Text(teamBLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Chip(avatar: const Icon(Icons.place, size: 18), label: Text(court)),
                                  Chip(avatar: const Icon(Icons.rule, size: 18), label: Text(_formatLabel(format))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Score: ${_scoreSummary(scoreJson, format)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.outline),
                                ],
                              ),
                            ],
                          ),
                        );

                        final stack = Stack(
                          children: [
                            // Corpo do cartão (tap navega para detalhe)
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GameDetailPage(
                                      gameId: gameId,
                                      adminKey: adminKey,
                                      player1: p1,
                                      player2: p2,
                                      player3: p3,
                                      player4: p4,
                                      format: format,
                                      initialScore: scoreJson,
                                      startAt: startAt,
                                      caps: widget.caps, // passa caps
                                    ),
                                  ),
                                );
                              },
                              child: cardInner,
                            ),

                          ],
                        );

                        final tile = GestureDetector(
                          // Long press “manual”: só se admin (gestão)
                          onTapDown: (_) {
                            if (isAdmin) {
                              _startHold(() => _openScoreboardsMenu(gameId));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Modo consulta: não é possível gerir scoreboards.')),
                              );
                            }
                          },
                          onTapUp: (_) => _cancelHold(),
                          onTapCancel: _cancelHold,
                          onPanStart: (_) => _cancelHold(),
                          child: Card(child: stack),
                        );

                        if (!isAdmin) return tile;

                        // Admin: permite swipe-to-delete com confirmação
                        return Dismissible(
                          key: ValueKey('game-$gameId'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDeleteGame(teamALabel, teamBLabel),
                          onDismissed: (_) => _deleteGame(gameId),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: tile,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          // FAB – só mostra se pode criar jogos
          if (widget.caps.canCreateEntities)
            Positioned(
              right: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom + 44, // 44 = footer height
              child: FloatingActionButton.extended(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                onPressed: _openCreateGameSheet,
                icon: const Icon(Icons.add),
                label: const Text('Novo jogo'),
              ),
            ),
        ],
      ),
    );
  }
}

// ================== MODELOS & HELPERS (top-level) ==================

class _Board {
  final String id;
  final String label;
  final String layout;
  final int maxPositions;
  _Board({
    required this.id,
    required this.label,
    required this.layout,
    required this.maxPositions,
  });
}

class _Membership {
  final int selectionId;
  final String boardId;
  final String boardTitle;
  final int position;
  _Membership({
    required this.selectionId,
    required this.boardId,
    required this.boardTitle,
    required this.position,
  });
}

class _ScoreboardMembershipData {
  final List<_Board> boards;
  final List<_Membership> memberships;
  _ScoreboardMembershipData({
    required this.boards,
    required this.memberships,
  });
}

Future<_ScoreboardMembershipData> _loadMembershipAndBoards(String gameId) async {
  final supabase = Supabase.instance.client;

  final selRows = await supabase
      .from('scoreboard_selections')
      .select('id, scoreboard_id, position')
      .eq('game_id', gameId);

  final selections = List<Map<String, dynamic>>.from(selRows);

  final boardsRows = await supabase
      .from('scoreboards')
      .select('id, key, title, layout, positions')
      .order('updated_at', ascending: false);

  final boards = List<Map<String, dynamic>>.from(boardsRows);
  final boardsById = {for (final b in boards) b['id'] as String: b};

  final boardsModels = boards.map<_Board>((b) {
    final title = (b['title'] as String?)?.trim();
    final key = (b['key'] as String?)?.trim();
    final label = (title?.isNotEmpty == true ? title! : key ?? 'Sem título');
    final layout = (b['layout'] as String?) ?? 'auto';
    final maxPos = _maxPositionsFromMap(b);
    return _Board(id: b['id'] as String, label: label, layout: layout, maxPositions: maxPos);
  }).toList();

  final membershipsModels = selections.map<_Membership>((s) {
    final b = boardsById[s['scoreboard_id'] as String];
    final title = (b?['title'] as String?)?.trim();
    final key = (b?['key'] as String?)?.trim();
    final label = (title?.isNotEmpty == true ? title! : key ?? 'Sem título');
    return _Membership(
      selectionId: s['id'] as int,
      boardId: s['scoreboard_id'] as String,
      boardTitle: label,
      position: s['position'] as int,
    );
  }).toList();

  return _ScoreboardMembershipData(boards: boardsModels, memberships: membershipsModels);
}

Future<List<Map<String, dynamic>>> _fetchBoards() async {
  final supabase = Supabase.instance.client;
  final rows = await supabase
      .from('scoreboards')
      .select('id, key, title, layout, positions')
      .order('updated_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
}

Future<List<int>> _positionsForBoard(String boardId) async {
  final supabase = Supabase.instance.client;
  final row = await supabase
      .from('scoreboards')
      .select('layout, positions')
      .eq('id', boardId)
      .maybeSingle();

  return List<int>.generate(_maxPositionsFromMap(row ?? const {'layout': 'auto'}), (i) => i + 1);
}

// garante cast seguro (positions é smallint/num)
int _maxPositionsFromMap(Map b) {
  final int? explicit = (b['positions'] as num?)?.toInt();
  if (explicit != null && explicit >= 1 && explicit <= 4) return explicit;

  final layout = (b['layout'] as String?)?.toLowerCase() ?? 'auto';
  switch (layout) {
    case '1x1':
      return 1;
    case '1x2':
      return 2;
    case '1x3':
      return 3;
    case '1x4':
      return 4;
    case '2x2':
      return 4;
    default:
      return 4;
  }
}

Future<int> _maxPositionsForBoard(String boardId) async {
  final supabase = Supabase.instance.client;
  final row = await supabase
      .from('scoreboards')
      .select('layout, positions')
      .eq('id', boardId)
      .maybeSingle();
  return _maxPositionsFromMap(row ?? const {'layout': 'auto'});
}

Future<void> _assignGameToBoard(String boardId, int position, String gameId) async {
  final supabase = Supabase.instance.client;

  // 1) Liberta a posição (se estiver ocupada)
  await supabase
      .from('scoreboard_selections')
      .delete()
      .eq('scoreboard_id', boardId)
      .eq('position', position);

  // 2) Cria ou move este jogo para a posição (override efetivo)
  await supabase.from('scoreboard_selections').upsert(
    {
      'scoreboard_id': boardId,
      'game_id': gameId,
      'position': position,
    },
    onConflict: 'scoreboard_id,game_id',
  );
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initial) async {
  final now = DateTime.now();
  final base = initial ?? now;

  final date = await showDatePicker(
    context: context,
    initialDate: base,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 2),
  );
  if (date == null) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtDateTimeShort(DateTime dtLocal) {
  final d = dtLocal;
  // dd/MM/yyyy HH:mm
  return '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}
