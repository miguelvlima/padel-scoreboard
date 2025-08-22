import 'package:flutter/material.dart';
import '../logic/match_state.dart';
import '../logic/score_manager/score_manager.dart';

class ScoreBoard extends StatefulWidget {
  final MatchState state;
  final ScoreManager manager;
  final Future<void> Function()? onPersist; // opcional: grava na DB após "guardar"
  const ScoreBoard({
    super.key,
    required this.state,
    required this.manager,
    this.onPersist,
  });

  @override
  State<ScoreBoard> createState() => _ScoreBoardState();
}

class _ScoreBoardState extends State<ScoreBoard> {
  MatchState get state => widget.state;
  ScoreManager get manager => widget.manager;

  // Edição local: setIndex -> {team1, team2}
  final Map<int, Map<String, int>> _editing = {};

  void _startEdit(int index, Map s) {
    _editing[index] = {
      'team1': (s['team1'] as int?) ?? 0,
      'team2': (s['team2'] as int?) ?? 0,
    };
    setState(() {});
  }

  void _cancelEdit(int index) {
    _editing.remove(index);
    setState(() {});
  }

  void _bump(int index, int team, int delta) {
    final m = _editing[index];
    if (m == null) return;
    final key = team == 1 ? 'team1' : 'team2';
    m[key] = ((m[key] ?? 0) + delta).clamp(0, 99);
    setState(() {});
  }

  Future<void> _saveEdit(int index) async {
    final m = _editing[index];
    if (m == null) return;
    final t1 = m['team1'] ?? 0;
    final t2 = m['team2'] ?? 0;

    // 1) Preview: will this edit force discarding trailing set(s)?
    final cutFrom = manager.previewEditDiscardIndex(index, t1, t2);
    if (cutFrom != null) {
      final total = ((state.score['sets'] as List?)?.length ?? 0);
      final fromSetNumber = cutFrom + 1;
      final toSetNumber = total;
      final rangeText = (fromSetNumber == toSetNumber)
          ? 'set $fromSetNumber'
          : 'sets $fromSetNumber–$toSetNumber';

      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Isto vai decidir o jogo mais cedo'),
          content: Text(
            'Esta alteração vai tornar o resultado final ${fromSetNumber - 1}+1 '
                'e o $rangeText será descartado. Queres continuar?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
          ],
        ),
      ) ?? false;

      if (!ok) return;

      // 2) Apply with discard allowed
      final applied = manager.applyFinishedSetResult(index, t1, t2, allowDiscardTrailing: true);
      if (!applied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível aplicar a alteração.')),
          );
        }
        return;
      }
    } else {
      // No discard needed: apply normally
      final applied = manager.applyFinishedSetResult(index, t1, t2);
      if (!applied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resultado inválido ou não editável.')),
          );
        }
        return;
      }
    }

    _editing.remove(index);
    if (mounted) setState(() {});
    await widget.onPersist?.call(); // grava na DB se fornecido
  }


  @override
  Widget build(BuildContext context) {
    final rawSets = (state.score['sets'] as List?) ?? [];
    final current = (state.score['current'] as Map?) ?? {};

    // Parcial atual (jogos) e tie-break (pontos)
    final g1 = (current['games_team1'] as int?) ?? 0;
    final g2 = (current['games_team2'] as int?) ?? 0;
    final tb1 = (current['tb_team1'] as int?) ?? 0;
    final tb2 = (current['tb_team2'] as int?) ?? 0;

    // Máximo de sets jogados para o formato: best-of-N ⇒ 2N−1
    final maxSets = state.setsToWinMatch * 2 - 1;

    // Só sets concluídos (o manager mantém state.currentSet atualizado)
    final finishedCount = state.currentSet.clamp(0, maxSets);
    final finishedSets = <Map>[
      for (int i = 0; i < rawSets.length && i < finishedCount; i++)
        (rawSets[i] as Map),
    ];

    // Podemos mostrar "Atual" se o jogo não acabou, há current, e ainda cabe no formato
    final canShowCurrent = !state.matchOver && current.isNotEmpty && finishedSets.length < maxSets;

    // Estamos a jogar o Super TB agora? (slot final de formatos super, em TB, após 2 sets)
    final isSuperTBNow =
        state.superTieBreak &&
            state.inTieBreak &&
            finishedSets.length == (maxSets - 1);

    // Chip de um set concluído (com lápis/disquete no modo edição)
    Widget _finishedSetRow(int i, Map s) {
      final editing = _editing.containsKey(i);
      final a = editing ? (_editing[i]!['team1'] ?? 0) : (s['team1'] as int? ?? 0);
      final b = editing ? (_editing[i]!['team2'] ?? 0) : (s['team2'] as int? ?? 0);

      // Rotulagem correta de Super TB por "slot", não por valor:
      final isSuperTBSet = state.superTieBreak &&
          i == maxSets - 1 &&
          finishedSets.length == maxSets;

      if (!editing) {
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Chip(
              label: Text(
                isSuperTBSet ? 'Super TB: $a - $b' : 'Set ${i + 1}: $a - $b',
              ),
            ),
            IconButton(
              tooltip: 'Editar set ${i + 1}',
              icon: const Icon(Icons.edit),
              onPressed: () => _startEdit(i, s),
            ),
          ],
        );
      }

      // Modo edição
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Chip(
            label: Text(
              isSuperTBSet
                  ? 'Super TB (editar): $a - $b'
                  : 'Set ${i + 1} (editar): $a - $b',
            ),
          ),
          // Team 1
          IconButton(
            tooltip: '−1 equipa 1',
            onPressed: () => _bump(i, 1, -1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: '+1 equipa 1',
            onPressed: () => _bump(i, 1, 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 2),
          // Team 2
          IconButton(
            tooltip: '−1 equipa 2',
            onPressed: () => _bump(i, 2, -1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: '+1 equipa 2',
            onPressed: () => _bump(i, 2, 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
          // Ações
          IconButton(
            tooltip: 'Guardar',
            onPressed: () => _saveEdit(i),
            icon: const Icon(Icons.save),
          ),
          IconButton(
            tooltip: 'Cancelar',
            onPressed: () => _cancelEdit(i),
            icon: const Icon(Icons.close),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // Sets concluídos (chips + lápis/edição)
            for (int i = 0; i < finishedSets.length; i++) _finishedSetRow(i, finishedSets[i]),

            // Set atual (quando está 6–6 num set normal, mantemos o 6–6 visível)
            if (canShowCurrent && state.inTieBreak && !isSuperTBNow)
              Chip(label: Text('Set atual: $g1 - $g2')),

            // TB atual (normal ou super) — rotulado pelo slot e estado
            if (canShowCurrent && state.inTieBreak)
              Chip(label: Text(isSuperTBNow ? 'Super TB: $tb1 - $tb2' : 'Tie-break: $tb1 - $tb2')),

            // Fora de TB: mostrar o parcial atual normalmente
            if (canShowCurrent && !state.inTieBreak)
              Chip(label: Text('Atual: $g1 - $g2')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(manager.pointsText(1), style: Theme.of(context).textTheme.titleMedium),
            Text(manager.pointsText(2), style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}
