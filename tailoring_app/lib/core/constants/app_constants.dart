/// App-wide constants.
class AppConstants {
  AppConstants._();

  // Roles — the shop has exactly two operating users.
  static const String roleAdmin = 'admin'; // le Gérant
  static const String roleSecretary = 'secretary'; // la Secrétaire

  // Order statuses (API values). 'livre' IS the Historique: same row,
  // moved by status — never copied.
  static const String statusEnCours = 'en_cours';
  static const String statusPret = 'pret';
  static const String statusLivre = 'livre';
}
