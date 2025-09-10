import 'app_mode.dart';

class AppCapabilities {
  final bool canCreateEntities;    // criar eventos/jogos
  final bool canAttachScoreboards; // gerir scoreboard selections
  final bool canEditMeta;          // mudar court/formato no detalhe, resetar etc.

  /// Novo: pode editar sem aprovação?
  final bool canEditWithoutApproval;

  /// Novo: pode aprovar pedidos de scorers?
  final bool canApproveScorers;

  const AppCapabilities({
    required this.canCreateEntities,
    required this.canAttachScoreboards,
    required this.canEditMeta,
    required this.canEditWithoutApproval,
    required this.canApproveScorers,
  });

  factory AppCapabilities.fromMode(AppMode mode) {
    switch (mode) {
      case AppMode.scorer:
        return const AppCapabilities(
          canCreateEntities: false,
          canAttachScoreboards: false,
          canEditMeta: false,
          canEditWithoutApproval: false,
          canApproveScorers: false,
        );
      case AppMode.admin:
      default:
        return const AppCapabilities(
          canCreateEntities: true,
          canAttachScoreboards: true,
          canEditMeta: true,
          canEditWithoutApproval: true,
          canApproveScorers: true,
        );
    }
  }
}
