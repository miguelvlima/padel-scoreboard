import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_capabilities.dart';
import '../games/widgets/app_footer.dart';

class EventScoreboardsPage extends StatefulWidget {
  final String eventId;
  final String eventName;
  final AppCapabilities caps;

  const EventScoreboardsPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.caps,
  });

  @override
  State<EventScoreboardsPage> createState() => _EventScoreboardsPageState();
}

class _EventScoreboardsPageState extends State<EventScoreboardsPage> {
  final supabase = Supabase.instance.client;

  // data
  List<Map<String, dynamic>> _boards = [];
  List<Map<String, dynamic>> _courts = [];
  List<Map<String, dynamic>> _games = [];

  // selections (guardamos como String para consistência)
  String? _boardId;
  String? _courtId;
  String? _gameId;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  // ---------- helpers p/ dropdowns (dedup + valor seguro) ----------
  List<DropdownMenuItem<String>> _itemsUnique(
      List<Map<String, dynamic>> rows, {
        required String idKey,
        required String Function(Map<String, dynamic>) labelOf,
      }) {
    final used = <String>{};
    final items = <DropdownMenuItem<String>>[];
    for (final r in rows) {
      final id = (r[idKey]?.toString() ?? '');
      if (id.isEmpty || !used.add(id)) continue;
      items.add(DropdownMenuItem<String>(value: id, child: Text(labelOf(r))));
    }
    return items;
  }

  String? _safeValue(String? current, List<DropdownMenuItem<String>> items) {
    if (current != null && items.any((i) => i.value == current)) return current;
    return items.isNotEmpty ? items.first.value : null;
  }

  // -------------------- load --------------------
  Future<void> _loadInitial() async {
    try {
      final boards = await _fetchBoards();
      final courts = await _fetchCourts();

      _boards = boards;
      _courts = courts;

      if (_boards.isNotEmpty) {
        _boardId = _boards.first['id'].toString();
        // preenche court/jogo se houver seleção já associada ao board
        await _prefillFromBoard(_boardId!);
      } else {
        // sem scoreboards… ainda assim tenta preparar jogos (provavelmente vazio)
        if (_courts.isNotEmpty) _courtId = _courts.first['id'].toString();
        await _reloadGames();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBoards() async {
    final rows = await supabase
        .from('scoreboards')
        .select('id, key, title, layout, positions, updated_at')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> _fetchCourts() async {
    final rows = await supabase.from('courts').select('id, name').order('name');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _reloadGames() async {
    var q = supabase
        .from('games')
        .select('id, player1, player2, player3, player4, court_id, start_at, format, score')
        .eq('event_id', widget.eventId);

    // aplica filtro por court ANTES de ordenar
    final courtId = _courtId;
    if (courtId != null && courtId.isNotEmpty) {
      q = q.eq('court_id', courtId);
    }

    final rows = await q.order('start_at', ascending: true);

    final list = List<Map<String, dynamic>>.from(rows as List);

    // se o jogo selecionado deixou de existir na lista, limpamos
    if (_gameId != null && !list.any((g) => (g['id']?.toString() ?? '') == _gameId)) {
      _gameId = null;
    }

    if (!mounted) return;
    setState(() => _games = list);
  }

  // labels
  String _boardLabel(Map<String, dynamic> b) {
    final title = (b['title'] as String?)?.trim() ?? '';
    final key = (b['key'] as String?)?.trim() ?? '';
    if (title.isNotEmpty) return title;
    if (key.isNotEmpty) return key;
    return 'Sem título';
  }

  String _courtLabel(Map<String, dynamic> c) =>
      (c['name'] as String?) ?? '—';

  String _gameLabel(Map<String, dynamic> g) {
    final p1 = g['player1'] ?? '';
    final p2 = g['player2'] ?? '';
    final p3 = g['player3'] ?? '';
    final p4 = g['player4'] ?? '';
    return '$p1 / $p2  vs  $p3 / $p4';
  }

  /// Quando escolhemos um scoreboard, tenta pré-preencher court + jogo
  /// com base na primeira seleção existente (posição mais baixa).
  Future<void> _prefillFromBoard(String boardId) async {
    // Lê uma seleção existente (se houver)
    final sel = await supabase
        .from('scoreboard_selections')
        .select('id, game_id, position')
        .eq('scoreboard_id', boardId)
        .order('position', ascending: true)
        .limit(1)
        .maybeSingle();

    if (sel == null) {
      // sem seleção associada → escolhe primeiro court disponível (se houver)
      if (_courtId == null && _courts.isNotEmpty) {
        _courtId = _courts.first['id'].toString();
      }
      await _reloadGames();
      return;
    }

    final gameId = sel['game_id']?.toString();
    if (gameId == null || gameId.isEmpty) {
      if (_courtId == null && _courts.isNotEmpty) {
        _courtId = _courts.first['id'].toString();
      }
      await _reloadGames();
      return;
    }

    // Busca o court do jogo (para pré-selecionar o court)
    final game = await supabase
        .from('games')
        .select('id, court_id')
        .eq('id', gameId)
        .maybeSingle();

    final courtId = (game?['court_id']?.toString());

    _gameId = gameId;
    _courtId = courtId ?? (_courts.isNotEmpty ? _courts.first['id'].toString() : null);

    await _reloadGames(); // garante que a lista contém esse jogo
  }

  Future<void> _assignGame() async {
    if (_boardId == null || _gameId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolhe o scoreboard e o jogo.')),
      );
      return;
    }
    try {
      await _assignGameToBoard(_boardId!, 1, _gameId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jogo atribuído ao scoreboard.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  // Liberta posição e faz upsert
  Future<void> _assignGameToBoard(String boardId, int position, String gameId) async {
    await supabase
        .from('scoreboard_selections')
        .delete()
        .eq('scoreboard_id', boardId)
        .eq('position', position);

    await supabase.from('scoreboard_selections').upsert(
      {
        'scoreboard_id': boardId,
        'game_id': gameId,
        'position': position,
      },
      onConflict: 'scoreboard_id,game_id',
    );
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
    final isAdmin = widget.caps.canCreateEntities == true;

    // constrói items e valida valores para evitar asserts do Dropdown
    final boardItems = _itemsUnique(
      _boards,
      idKey: 'id',
      labelOf: _boardLabel,
    );
    final safeBoardId = _safeValue(_boardId, boardItems);

    final courtItems = _itemsUnique(
      _courts,
      idKey: 'id',
      labelOf: _courtLabel,
    );
    final safeCourtId = _safeValue(_courtId, courtItems);

    final gameItems = _itemsUnique(
      _games,
      idKey: 'id',
      labelOf: _gameLabel,
    );
    final safeGameId = _safeValue(_gameId, gameItems);

    return Scaffold(
      appBar: AppBar(
        title: Text('Scoreboards — ${widget.eventName}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      bottomNavigationBar: const AppFooter(),
      body: _bg(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // SCOREBOARD
                        DropdownButtonFormField<String>(
                          key: ValueKey('board-$safeBoardId'),
                          value: safeBoardId,
                          isExpanded: true,
                          menuMaxHeight: 420,
                          decoration: const InputDecoration(
                            labelText: 'Scoreboard',
                          ),
                          items: boardItems,
                          onChanged: !isAdmin
                              ? null
                              : (v) async {
                            if (v == null) return;
                            setState(() {
                              _boardId = v;
                              _gameId = null; // limpar jogo ao trocar board
                            });
                            await _prefillFromBoard(v);
                          },
                        ),
                        const SizedBox(height: 12),

                        // COURT
                        DropdownButtonFormField<String>(
                          key: ValueKey('court-$safeBoardId-$safeCourtId'),
                          value: safeCourtId,
                          isExpanded: true,
                          menuMaxHeight: 420,
                          decoration: const InputDecoration(
                            labelText: 'Court',
                          ),
                          items: courtItems,
                          onChanged: !isAdmin
                              ? null
                              : (v) async {
                            setState(() {
                              _courtId = v;
                              _gameId = null;
                            });
                            await _reloadGames();
                          },
                        ),
                        const SizedBox(height: 12),

                        // GAME
                        DropdownButtonFormField<String>(
                          key: ValueKey('game-$safeCourtId-$safeGameId'),
                          value: safeGameId,
                          isExpanded: true,
                          menuMaxHeight: 420,
                          decoration: const InputDecoration(
                            labelText: 'Jogo',
                          ),
                          items: gameItems
                              .map(
                                (it) => DropdownMenuItem<String>(
                              value: it.value,
                              child: Text(
                                (it.child as Text).data ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                              .toList(),
                          onChanged: !isAdmin
                              ? null
                              : (v) => setState(() => _gameId = v),
                        ),

                        const SizedBox(height: 16),

                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.play_circle),
                            label: const Text('Transmitir'),
                            onPressed: !isAdmin ? null : _assignGame,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
