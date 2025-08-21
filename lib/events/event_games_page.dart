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

  Future<void> _createGame() async {
    final player1 = _p1.text.trim();
    final player2 = _p2.text.trim();
    final player3 = _p3.text.trim();
    final player4 = _p4.text.trim();
    if (player1.isEmpty || player2.isEmpty || player3.isEmpty || player4.isEmpty) return;

    final adminKey = DateTime.now().millisecondsSinceEpoch.toString();
    await supabase.from('games').insert({
      'event_id': widget.eventId,
      'player1': player1,
      'player2': player2,
      'player3': player3,
      'player4': player4,
      'format': _selectedFormat,
      'admin_key': adminKey,
      'score': {
        "sets": <Map<String, int>>[],   // ← sem placeholders
        "current": <String, int>{},     // ← vazio até começar
      },
      'created_at': DateTime.now().toIso8601String(),
    });

    _p1.clear();
    _p2.clear();
    _p3.clear();
    _p4.clear();
  }

  String _scoreSummary(Map<String, dynamic> score) {
    final sets = List<Map<String, dynamic>>.from(score['sets'] ?? []);
    final current = Map<String, dynamic>.from(score['current'] ?? {});

    // Só sets concluídos (ignora 0-0)
    final concluded = <String>[];
    for (final s in sets) {
      final t1 = (s['team1'] ?? 0) as int;
      final t2 = (s['team2'] ?? 0) as int;
      if (t1 == 0 && t2 == 0) break; // ignora placeholders/trailers
      concluded.add('$t1-$t2');
    }

    if (concluded.isNotEmpty) {
      return concluded.join(' | ');
    }

    // Se não há sets concluídos, mostra parcial atual se existir
    if (current.isNotEmpty) {
      final g1 = (current['games_team1'] ?? 0) as int;
      final g2 = (current['games_team2'] ?? 0) as int;
      return '$g1-$g2';
    }

    // Totalmente vazio → traço
    return '-';
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
                final raw = snapshot.data ?? [];

                // Normaliza e FILTRA linhas inválidas (evita cartões “vazios”)
                final games = raw.where((g) {
                  // 1) precisa de id
                  final id = g['id']?.toString();
                  if (id == null || id.isEmpty) return false;

                  // 2) precisa dos 4 jogadores preenchidos
                  final p1 = (g['player1'] ?? '').toString().trim();
                  final p2 = (g['player2'] ?? '').toString().trim();
                  final p3 = (g['player3'] ?? '').toString().trim();
                  final p4 = (g['player4'] ?? '').toString().trim();
                  if (p1.isEmpty || p2.isEmpty || p3.isEmpty || p4.isEmpty) return false;

                  // 3) precisa de score com conteúdo
                  final score = g['score'];
                  if (score == null) return false;
                  if (score is Map && score.isEmpty) return false;

                  // (Se quiseres mostrar jogos acabados de criar mesmo com score vazio,
                  //  remove a linha acima "if (score is Map && score.isEmpty) return false;")
                  return true;
                }).toList();

                if (games.isEmpty) {
                  return const Center(child: Text('Nenhum jogo criado.'));
                }


                return ListView.builder(
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final g = games[index];

                    // Evitar nulls
                    final player1 = g['player1'] ?? '';
                    final player2 = g['player2'] ?? '';
                    final player3 = g['player3'] ?? '';
                    final player4 = g['player4'] ?? '';
                    final format = g['format'] ?? 'best_of_3';
                    final adminKey = g['admin_key'] ?? '';
                    final gameId = g['id']?.toString() ?? '';
                    final scoreJson = g['score'] != null
                        ? Map<String, dynamic>.from(g['score'] as Map<String, dynamic>)
                        : <String, dynamic>{};

                    return ListTile(
                      title: Text("$player1 / $player2 vs $player3 / $player4"),
                      subtitle: Text("Score: ${_scoreSummary(scoreJson)}"),
                      onTap: () {
                        final id = g['id']?.toString();
                        final score = g['score'] as Map<String, dynamic>?;
                        if (id == null || id.isEmpty || score == null || score.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Jogo incompleto — não é possível abrir.')),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameDetailPage(
                              gameId: id,
                              adminKey: g['admin_key'] ?? '',
                              player1: g['player1'] ?? '',
                              player2: g['player2'] ?? '',
                              player3: g['player3'] ?? '',
                              player4: g['player4'] ?? '',
                              format: g['format'] ?? 'best_of_3',
                              initialScore: Map<String, dynamic>.from(score),
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
