import 'package:flutter/material.dart';
import '../logic/match_state.dart';
import '../logic/score_manager/score_manager.dart';

const _kOuterPad = EdgeInsets.fromLTRB(4, 2, 4, 4);
const _kInnerPad = EdgeInsets.symmetric(horizontal: 4, vertical: 2);
const _kLabelMinWidth = 52.0;

class ScoreBoard extends StatefulWidget {
  final MatchState state;
  final ScoreManager manager;
  final Future<void> Function()? onPersist;

  // Nomes (duas linhas por equipa)
  final String team1p1;
  final String team1p2;
  final String team2p1;
  final String team2p2;

  const ScoreBoard({
    super.key,
    required this.state,
    required this.manager,
    this.onPersist,
    required this.team1p1,
    required this.team1p2,
    required this.team2p1,
    required this.team2p2,
  });

  @override
  State<ScoreBoard> createState() => _ScoreBoardState();
}

class _ScoreBoardState extends State<ScoreBoard> {
  MatchState get state => widget.state;
  ScoreManager get manager => widget.manager;

  int get _maxSlots => (state.setsToWinMatch * 2 - 1).clamp(1, 4);
  bool _isSuperTBSlot(int index) => state.superTieBreak && index == _maxSlots - 1;

  String _pointLabel(int p, int o) {
    if (state.gpRule) {
      const map = ['0', '15', '30', '40'];
      final idx = p.clamp(0, 3);
      return map[idx];
    }
    if (p <= 3 && o <= 3) {
      const map = ['0', '15', '30', '40'];
      return map[p];
    }
    if (p == 4 && o < 4) return 'Ad';
    if (o == 4 && p < 4) return '40';
    return '40';
  }

  // ---------- POPUP: editar set concluído ----------
  Future<void> _openEditDialog(
      BuildContext context,
      int index,
      int initialA,
      int initialB, {
        required bool isSuper,
      }) async {
    int t1 = initialA;
    int t2 = initialB;
    final theme = Theme.of(context);

    const btnPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    const btnSize = Size(64, 40);
    final decStyle = OutlinedButton.styleFrom(
      minimumSize: btnSize,
      padding: btnPadding,
      visualDensity: VisualDensity.compact,
    );
    final incStyle = FilledButton.styleFrom(
      minimumSize: btnSize,
      padding: btnPadding,
      visualDensity: VisualDensity.compact,
    );

    bool saved = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final cutFinal = manager.previewEditDiscardIndex(index, t1, t2);
            final cutReopen = manager.previewReopenDiscardIndex(index, t1, t2);

            return AlertDialog(
              title: Text(isSuper ? 'Editar Super TB' : 'Editar Set ${index + 1}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Equipa 1', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => setSheet(() => t1 = (t1 - 1).clamp(0, 99)),
                        style: decStyle,
                        child: const Text('−1'),
                      ),
                      const SizedBox(width: 8),
                      Text('$t1', style: theme.textTheme.headlineMedium),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => setSheet(() => t1 = (t1 + 1).clamp(0, 99)),
                        style: incStyle,
                        child: const Text('+1'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Equipa 2', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => setSheet(() => t2 = (t2 - 1).clamp(0, 99)),
                        style: decStyle,
                        child: const Text('−1'),
                      ),
                      const SizedBox(width: 8),
                      Text('$t2', style: theme.textTheme.headlineMedium),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => setSheet(() => t2 = (t2 + 1).clamp(0, 99)),
                        style: incStyle,
                        child: const Text('+1'),
                      ),
                    ],
                  ),
                  if (cutFinal != null || cutReopen != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cutFinal != null
                                ? 'Esta alteração pode decidir o jogo mais cedo e descartar sets seguintes.'
                                : 'Esta alteração vai reabrir o set e descartar este e os sets seguintes.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () async {
                    final cutFinal2 = manager.previewEditDiscardIndex(index, t1, t2);
                    final cutReopen2 = manager.previewReopenDiscardIndex(index, t1, t2);

                    if (cutFinal2 != null || cutReopen2 != null) {
                      final msg = (cutFinal2 != null)
                          ? 'Esta alteração vai decidir o jogo mais cedo e remover os sets seguintes. Continuar?'
                          : 'Esta alteração vai reabrir este set e remover este e os sets seguintes. Continuar?';

                      final proceed = await showDialog<bool>(
                        context: ctx,
                        builder: (ctx2) => AlertDialog(
                          title: const Text('Confirmar alteração'),
                          content: Text(msg),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Não')),
                            FilledButton(onPressed: () => Navigator.pop(ctx2, true), child: const Text('Sim')),
                          ],
                        ),
                      ) ??
                          false;

                      if (!proceed) return;

                      final applied = manager.applyFinishedSetResult(
                        index,
                        t1,
                        t2,
                        allowDiscardTrailing: true,
                      );
                      if (!applied) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Resultado inválido.')),
                          );
                        }
                        return;
                      }
                    } else {
                      final ok = manager.applyFinishedSetResult(index, t1, t2);
                      if (!ok) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Resultado inválido.')),
                          );
                        }
                        return;
                      }
                    }

                    saved = true;
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved) {
      if (mounted) setState(() {});
      await widget.onPersist?.call();
    }
  }

  // ---------- Cabeçalho: só nomes + VS ----------
  Widget _namesHeader(BuildContext context) {
    final t = Theme.of(context);
    final nameStyle = t.textTheme.titleMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      overflow: TextOverflow.ellipsis,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.team1p1, maxLines: 1, style: nameStyle),
                const SizedBox(height: 2),
                Text(widget.team1p2, maxLines: 1, style: nameStyle),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Center(
              child: Text(
                'VS',
                style: t.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(widget.team2p1, maxLines: 1, textAlign: TextAlign.right, style: nameStyle),
                const SizedBox(height: 2),
                Text(widget.team2p2, maxLines: 1, textAlign: TextAlign.right, style: nameStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setsList = (state.score['sets'] as List?) ?? const [];
    final current = (state.score['current'] as Map?) ?? const {};

    final g1 = (current['games_team1'] as int?) ?? 0;
    final g2 = (current['games_team2'] as int?) ?? 0;

    final p1 = (current['points_team1'] as int?) ?? 0;
    final p2 = (current['points_team2'] as int?) ?? 0;
    final tb1 = (current['tb_team1'] as int?) ?? 0;
    final tb2 = (current['tb_team2'] as int?) ?? 0;

    final finishedCount = state.currentSet.clamp(0, _maxSlots);
    final finishedSets = <Map>[
      for (int i = 0; i < setsList.length && i < finishedCount; i++) (setsList[i] as Map),
    ];

    final canShowInPlay = !state.matchOver && current.isNotEmpty;
    final isTBNow = state.inTieBreak;
    final isSuperTBNow = state.superTieBreak && isTBNow && finishedSets.length == (_maxSlots - 1);

    // valores do cartão live (vai para o FIM)
    String liveLabel = '';
    String liveLeft = '';
    String liveRight = '';
    if (canShowInPlay) {
      if (isTBNow) {
        liveLabel = isSuperTBNow ? 'Super TB' : 'Tie-break';
        liveLeft = '$tb1';
        liveRight = '$tb2';
      } else {
        liveLabel = 'Jogo';
        liveLeft = _pointLabel(p1, p2);
        liveRight = _pointLabel(p2, p1);
      }
    }

    final children = <Widget>[
      _namesHeader(context),
      const SizedBox(height: 8),
    ];

    // Sets concluídos
    for (int i = 0; i < finishedSets.length; i++) {
      final s = finishedSets[i];
      final a = s['team1'] as int? ?? 0;
      final b = s['team2'] as int? ?? 0;
      final label = (_isSuperTBSlot(i) && finishedSets.length == _maxSlots)
          ? 'Super TB'
          : (state.setsToWinMatch == 1 ? 'Pro Set' : 'Set ${i + 1}');
      children.add(
        _SetCard(
          label: label,
          scoreA: a,
          scoreB: b,
          onEdit: () => _openEditDialog(context, i, a, b, isSuper: label == 'Super TB'),
        ),
      );
      children.add(const SizedBox(height: 2));
    }

    // Set/Proset em curso (jogos) — antes do live
    if (canShowInPlay && !isSuperTBNow) {
      final nextIndex = finishedSets.length;
      final label = (state.setsToWinMatch == 1 ? 'Pro Set' : 'Set ${nextIndex + 1}');
      children.add(
        _SetCard(
          label: label,
          subtitle: 'A decorrer',
          scoreA: g1,
          scoreB: g2,
        ),
      );
      children.add(const SizedBox(height: 2));
    }

    // Cartão LIVE no FIM (branco, invertido)
    if (canShowInPlay) {
      children.add(
        _LiveCard(
          label: liveLabel,
          leftText: liveLeft,
          rightText: liveRight,
        ),
      );
    } else {
      if (children.isNotEmpty) {
        // remove o último SizedBox extra se existir
        if (children.last is SizedBox) children.removeLast();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

// ----------------- UI: cartão de set em faixa -----------------
class _SetCard extends StatelessWidget {
  final String label;
  final int? scoreA;
  final int? scoreB;
  final String? subtitle;
  final VoidCallback? onEdit;

  const _SetCard({
    required this.label,
    required this.scoreA,
    required this.scoreB,
    this.subtitle,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasScore = scoreA != null && scoreB != null;
    final leftTxt = hasScore ? '${scoreA!}' : '—';
    final rightTxt = hasScore ? '${scoreB!}' : '—';

    return Card(
      child: Padding(
        padding: _kOuterPad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitle != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      leftTxt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: _kLabelMinWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (onEdit != null) ...[
                          const SizedBox(width: 8),
                          InkResponse(
                            onTap: onEdit,
                            radius: 16,
                            child: const Icon(Icons.edit, size: 18),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rightTxt,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- UI: cartão LIVE com cores invertidas -----------------
class _LiveCard extends StatelessWidget {
  final String label;
  final String leftText;
  final String rightText;

  const _LiveCard({
    required this.label,
    required this.leftText,
    required this.rightText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: _kOuterPad,
        child: Container(
          padding: _kInnerPad,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  leftText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _kLabelMinWidth),
                child: Center(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  rightText,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
