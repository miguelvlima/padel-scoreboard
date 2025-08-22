import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_games_page.dart';
import '../games/widgets/app_footer.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final sb = Supabase.instance.client;

  Future<void> _openCreateEventSheet() async {
    final nameCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Novo evento', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome do evento'),
                textInputAction: TextInputAction.done,
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
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Indica o nome do evento.')),
                        );
                        return;
                      }
                      await sb.from('events').insert({
                        'name': name,
                        'created_at': DateTime.now().toIso8601String(),
                      });
                      if (mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
    return Scaffold(
      appBar: AppBar(title: const Text('EVENTOS')),
      bottomNavigationBar: const AppFooter(),
      body: Stack(
        children: [
          // background + list
          _bg(
            child: SafeArea(
              bottom: false,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: sb
                    .from('events')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: true)
                    .execute(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Erro a carregar eventos:\n${snap.error}', textAlign: TextAlign.center),
                      ),
                    );
                  }
                  final events = snap.data ?? [];
                  if (events.isEmpty) {
                    return const Center(child: Text('Sem eventos ainda.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 120), // room for FAB + footer
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final e = events[i];
                      final id = e['id']?.toString() ?? '';
                      final name = e['name']?.toString() ?? '—';

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventGamesPage(eventId: id, eventName: name),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Icon(Icons.emoji_events, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // FAB pinned above the footer, always visible
          Positioned(
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom + 44, // 44 = footer height
            child: FloatingActionButton.extended(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: _openCreateEventSheet,
              icon: const Icon(Icons.add),
              label: const Text('Novo evento'),
            ),
          ),
        ],
      ),
    );
  }
}
