import 'package:flutter/material.dart';
import '../app_capabilities.dart';
import 'event_games_page.dart';
import 'event_scoreboards_page.dart';

class EventHomePage extends StatelessWidget {
  final String eventId;
  final String eventName;
  final AppCapabilities caps;

  const EventHomePage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.caps,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = caps.canCreateEntities == true;

    return Scaffold(
      appBar: AppBar(
        title: Text('Evento — $eventName', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (_, c) {
              final wide = c.maxWidth > 520;
              // dentro do build() de EventHomePage:
              return GridView.count(
                crossAxisCount: wide ? 2 : 1,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // dá mais altura aos tiles para não rebentar com o texto
                childAspectRatio: wide ? 1.9 : 1.45,
                children: [
                  _Tile(
                    icon: Icons.sports_tennis,
                    title: 'Jogos',
                    subtitle: 'Lista e gerir jogos do evento',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventGamesPage(
                            eventId: eventId,
                            eventName: eventName,
                            caps: caps,
                          ),
                        ),
                      );
                    },
                  ),
                  if (isAdmin)
                    _Tile(
                      icon: Icons.tv,
                      title: 'Scoreboards',
                      subtitle: 'Escolher court e jogo a transmitir',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventScoreboardsPage(
                              eventId: eventId,
                              eventName: eventName,
                              caps: caps,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// classe _Tile
class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 112), // altura mínima segura
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(radius: 28, child: Icon(icon, size: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,                      // ← cabe em 2 linhas
                        overflow: TextOverflow.ellipsis,  // ← com reticências
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

