import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_games_page.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  Future<void> _createEvent() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    if (name.isEmpty) return;

    await supabase.from('events').insert({
      'name': name,
      'location': location,
      'created_at': DateTime.now().toIso8601String(),
    });

    _nameController.clear();
    _locationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome do evento')),
                TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Local')),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _createEvent, child: const Text('Criar evento')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase.from('events').stream(primaryKey: ['id']).order('created_at', ascending: true).execute(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final events = snapshot.data!;
                if (events.isEmpty) return const Center(child: Text('Nenhum evento criado.'));
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final e = events[index];
                    return ListTile(
                      title: Text(e['name']),
                      subtitle: Text(e['location'] ?? ''),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventGamesPage(
                              eventId: e['id'].toString(),
                              eventName: e['name'],
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
