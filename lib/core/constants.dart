class AppConstants {
  AppConstants._();

  // Base URL du backend (Raspberry Pi local)
  static const String baseUrl = 'http://192.168.129.119:5217';
  static const String hubUrl = '$baseUrl/gamehub';

  // Règles du jeu
  static const int roomCodeLength = 4;
  static const int pointsPerCorrectAnswer = 100;
}