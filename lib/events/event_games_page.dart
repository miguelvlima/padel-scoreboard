import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../games/game_detail_page.dart';
import '../games/widgets/app_footer.dart';

class EventGamesPage extends StatefulWidget {
  final String eventId;
  final String eventName;
  const EventGamesPage({super.key, required this.eventId, required this.eventName});

  @override
  State<EventGamesPage> createState() => _EventGamesPageState();
}

class _EventGamesPageState extends State<EventGamesPage> {
  final supabase = Supabase.instance.client;

  // Courts map just to render names (never blocks the list)
  Map<String, String> _courtNameById = {};

  @override
  void initState() {
    super.initState();
    _fetchCourtsForList(); // fire-and-forget; UI does not wait for this
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
      // ignore – we’ll just show "—" until courts are available
    }
  }

  String _formatLabel(String fmt) {
    switch (fmt) {
      case 'best_of_3': return 'Best of 3';
      case 'best_of_3_gp': return 'Best of 3 + GP';
      case 'super_tiebreak': return 'Super TB';
      case 'super_tiebreak_gp': return 'Super TB + GP';
      case 'proset': return 'Pro Set';
      case 'proset_gp': return 'Pro Set + GP';
      default: return fmt;
    }
  }

  // ------- creation sheet (unchanged) -------
  Future<void> _openCreateGameSheet() async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final p3 = TextEditingController();
    final p4 = TextEditingController();
    String format = 'best_of_3';
    String? courtId = _courtNameById.keys.isNotEmpty ? _courtNameById.keys.first : null;

    // lazy-load courts if empty
    if (_courtNameById.isEmpty) {
      try {
        final rows = await supabase.from('courts').select('id, name').order('name');
        final list = List<Map<String, dynamic>>.from(rows);
        if (list.isNotEmpty) {
          _courtNameById = { for (final c in list) (c['id'] as String): (c['name'] as String) };
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
                left: 16, right: 16, top: 16,
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

  String _scoreSummary(Map<String, dynamic> score) {
    final sets = List<Map<String, dynamic>>.from(score['sets'] ?? []);
    final current = Map<String, dynamic>.from(score['current'] ?? {});
    final parts = <String>[];

    for (final s in sets) {
      final t1 = s['team1'] ?? 0;
      final t2 = s['team2'] ?? 0;
      if (t1 > 0 || t2 > 0) {
        parts.add('$t1-$t2');
      } else {
        final g1 = current['games_team1'] ?? 0;
        final g2 = current['games_team2'] ?? 0;
        parts.add('$g1-$g2');
        break;
      }
    }
    if (parts.isEmpty) {
      final g1 = current['games_team1'] ?? 0;
      final g2 = current['games_team2'] ?? 0;
      parts.add('$g1-$g2');
    }
    return parts.join(' | ');
  }

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
                        final gameId   = g['id']?.toString() ?? '';
                        final courtId  = g['court_id']?.toString();
                        final court    = courtId != null ? (_courtNameById[courtId] ?? '—') : '—';

                        final scoreJson = g['score'] != null
                            ? Map<String, dynamic>.from(g['score'] as Map<String, dynamic>)
                            : <String, dynamic>{};

                        return Card(
                          child: InkWell(
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
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$p1 / $p2', maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.titleMedium),
                                  Text('$p3 / $p4', maxLines: 1, overflow: TextOverflow.ellipsis,
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
                                          'Score: ${_scoreSummary(scoreJson)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodyLarge,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          // FAB pinned above the footer – always visible
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
