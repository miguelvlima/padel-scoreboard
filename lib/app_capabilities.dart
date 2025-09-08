import 'app_mode.dart';

class AppCapabilities {
  final bool canCreateEntities;    // criar eventos/jogos
  final bool canAttachScoreboards; // gerir scoreboard selections
  final bool canEditMeta;          // mudar court/formato no detalhe, resetar etc.

  const AppCapabilities({
    required this.canCreateEntities,
    required this.canAttachScoreboards,
    required this.canEditMeta,
  });

  factory AppCapabilities.fromMode(AppMode mode) {
    switch (mode) {
      case AppMode.scorer:
        return const AppCapabilities(
          canCreateEntities: false,
          canAttachScoreboards: false,
          canEditMeta: false,
        );
      case AppMode.admin:
      default:
        return const AppCapabilities(
          canCreateEntities: true,
          canAttachScoreboards: true,
          canEditMeta: true,
        );
    }
  }
}
