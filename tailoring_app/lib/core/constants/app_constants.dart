/// App-wide constants.
class AppConstants {
  AppConstants._();

  // Roles — the shop has exactly two operating users.
  static const String roleAdmin = 'admin'; // le Gérant
  static const String roleSecretary = 'secretary'; // la Secrétaire

  // Order statuses (API values), in workflow order. 'livre' IS the
  // Historique: same row, moved by status — never copied.
  static const String statusEnAttente = 'en_attente';
  static const String statusEnCours = 'en_cours';
  static const String statusTermine = 'termine';
  static const String statusLivre = 'livre';

  /// Cancelling an order is a status change, never a hard delete — the line
  /// items, their corrections, the cash collected and the tailor's entries all
  /// survive. Deliberately NOT in [orderStatuses]: it is not a step of the
  /// workflow and must never appear in a status dropdown.
  static const String statusAnnule = 'annule';

  /// The four fixed statuses in order (dropdown source of truth).
  static const List<String> orderStatuses = <String>[
    statusEnAttente,
    statusEnCours,
    statusTermine,
    statusLivre,
  ];

  /// French labels for each status.
  static const Map<String, String> orderStatusLabels = <String, String>{
    statusEnAttente: 'En attente',
    statusEnCours: 'En cours',
    statusTermine: 'Terminé',
    statusLivre: 'Livré',
  };

  static String statusLabel(String status) =>
      orderStatusLabels[status] ?? status;
}
