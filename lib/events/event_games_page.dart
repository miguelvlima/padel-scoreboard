import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../games/game_detail_page.dart';

class EventGamesPage extends StatefulWidget {
  final String eventId;
  final String eventName;
  const EventGamesPage({super.key, required this.eventId, required this.eventName});

  @override
  State<EventGamesPage> createState() => _EventGamesPageState();
}

class _EventGamesPageState extends State<EventGamesPage> {
  final supabase = Supabase.instance.client;
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _p3 = TextEditingController();
  final _p4 = TextEditingController();
  String _selectedFormat = 'best_of_3';

  // Courts dropdown + mapping para mostrar na lista
  List<Map<String, dynamic>> _courts = [];
  Map<String, String> _courtNameById = {};
  String? _selectedCourtId;
  bool _loadingCourts = true;

  @override
  void initState() {
    super.initState();
    _fetchCourts();
  }

  Future<void> _fetchCourts() async {
    try {
      final rows = await supabase
          .from('courts')
          .select('id, name')
          .order('name');

      final list = List<Map<String, dynamic>>.from(rows);
      final map = <String, String>{
        for (final c in list) (c['id'] as String): (c['name'] as String),
      };

      setState(() {
        _courts = list;
        _courtNameById = map;
        _loadingCourts = false;
      });
    } catch (e) {
      setState(() => _loadingCourts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha a carregar courts: $e')),
      );
    }
  }

  Future<void> _createGame() async {
    final player1 = _p1.text.trim();
    final player2 = _p2.text.trim();
    final player3 = _p3.text.trim();
    final player4 = _p4.text.trim();

    if (player1.isEmpty || player2.isEmpty || player3.isEmpty || player4.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche os 4 jogadores.')),
      );
      return;
    }
    if (_selectedCourtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
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
      'format': _selectedFormat,
      'court_id': _selectedCourtId, // grava court
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

    _p1.clear();
    _p2.clear();
    _p3.clear();
    _p4.clear();
    setState(() => _selectedCourtId = null);
  }

  String _scoreSummary(Map<String, dynamic> score) {
    final sets = List<Map<String, dynamic>>.from(score['sets'] ?? []);
    final current = Map<String, dynamic>.from(score['current'] ?? {});
    List<String> summary = [];

    for (var s in sets) {
      int t1 = s['team1'] ?? 0;
      int t2 = s['team2'] ?? 0;
      if (t1 > 0 || t2 > 0) {
        summary.add("$t1-$t2");
      } else {
        int g1 = current['games_team1'] ?? 0;
        int g2 = current['games_team2'] ?? 0;
        summary.add("$g1-$g2");
        break;
      }
    }
    if (summary.isEmpty) {
      int g1 = current['games_team1'] ?? 0;
      int g2 = current['games_team2'] ?? 0;
      summary.add("$g1-$g2");
    }
    return summary.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Jogos - ${widget.eventName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(controller: _p1, decoration: const InputDecoration(labelText: 'Jogador 1')),
                TextField(controller: _p2, decoration: const InputDecoration(labelText: 'Jogador 2')),
                TextField(controller: _p3, decoration: const InputDecoration(labelText: 'Jogador 3')),
                TextField(controller: _p4, decoration: const InputDecoration(labelText: 'Jogador 4')),
                const SizedBox(height: 8),

                // Dropdown de court
                _loadingCourts
                    ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator()),
                  ),
                )
                    : DropdownButtonFormField<String>(
                  value: _selectedCourtId,
                  decoration: const InputDecoration(labelText: 'Court'),
                  items: _courts
                      .map((c) => DropdownMenuItem<String>(
                    value: c['id'] as String,
                    child: Text(c['name'] as String),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCourtId = v),
                ),
                const SizedBox(height: 8),

                DropdownButton<String>(
                  value: _selectedFormat,
                  items: const [
                    DropdownMenuItem(value: 'best_of_3', child: Text('Best of 3')),
                    DropdownMenuItem(value: 'best_of_3_gp', child: Text('Best of 3 + GP')),
                    DropdownMenuItem(value: 'super_tiebreak', child: Text('Super Tiebreak')),
                    DropdownMenuItem(value: 'super_tiebreak_gp', child: Text('Super Tiebreak + GP')),
                    DropdownMenuItem(value: 'proset', child: Text('Pro Set')),
                    DropdownMenuItem(value: 'proset_gp', child: Text('Pro Set + GP')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedFormat = v);
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _createGame, child: const Text('Criar jogo')),
              ],
            ),
          ),
          Expanded(
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
                  return Center(child: Text('Erro ao carregar jogos: ${snapshot.error}'));
                }
                final games = snapshot.data ?? [];
                if (games.isEmpty) return const Center(child: Text('Nenhum jogo criado.'));

                return ListView.builder(
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final g = games[index];

                    final player1 = g['player1'] ?? '';
                    final player2 = g['player2'] ?? '';
                    final player3 = g['player3'] ?? '';
                    final player4 = g['player4'] ?? '';
                    final format = g['format'] ?? 'best_of_3';
                    final adminKey = g['admin_key'] ?? '';
                    final gameId = g['id']?.toString() ?? '';
                    final courtId = g['court_id']?.toString();
                    final courtName = courtId != null ? (_courtNameById[courtId] ?? '—') : '—';

                    final scoreJson = g['score'] != null
                        ? Map<String, dynamic>.from(g['score'] as Map<String, dynamic>)
                        : <String, dynamic>{};

                    return ListTile(
                      title: Text(
                        "$player1 / $player2 vs $player3 / $player4",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true, // dá espaço vertical extra para 2 linhas + 1 subtítulo
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Court: $courtName",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                          Text(
                            "Score: ${_scoreSummary(scoreJson)}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameDetailPage(
                              gameId: gameId,
                              adminKey: adminKey,
                              player1: player1,
                              player2: player2,
                              player3: player3,
                              player4: player4,
                              format: format,
                              initialScore: scoreJson,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
