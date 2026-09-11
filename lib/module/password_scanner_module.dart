import 'dart:math';

class PasswordAnalysis {
  double entropy;
  double crackTimeSeconds;
  String verdict;

  PasswordAnalysis({
    required this.entropy,
    required this.crackTimeSeconds,
    required this.verdict,
  });
}

class PasswordScannerModule {
  static const String _lowChars = "abcdefghijklmnopqrstuvwxyz";
  static const String _upChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  static const String _numChars = "0123456789";
  static const String _specChars = "!@#\$%^&*()_+-=[]{}|;:,.<>?";

  /// Génère un mot de passe robuste de manière sécurisée
  String generateRobustPassword(int length) {
    final String allChars = "$_lowChars$_upChars$_numChars$_specChars";
    final Random random = Random.secure();

    return List.generate(length, (index) {
      final int randomIndex = random.nextInt(allChars.length);
      return allChars[randomIndex];
    }).join();
  }

  /// Évalue la complexité d'un mot de passe
  PasswordAnalysis evaluatePassword(String password) {
    if (password.isEmpty) {
      return PasswordAnalysis(entropy: 0.0, crackTimeSeconds: 0.0, verdict: "AUCUN");
    }

    final int length = password.length;
    int poolSize = 0;
    int hasLow = 0, hasUp = 0, hasNum = 0, hasSpec = 0;

    for (int i = 0; i < length; i++) {
      final String char = password[i];
      if (_lowChars.contains(char)) {
        hasLow = 26;
      } else if (_upChars.contains(char)) {
        hasUp = 26;
      } else if (_numChars.contains(char)) {
        hasNum = 10;
      } else {
        hasSpec = 32;
      }
    }

    poolSize = hasLow + hasUp + hasNum + hasSpec;

    double entropy = length * (log(poolSize) / log(2));
    if (entropy.isNaN || entropy.isInfinite) entropy = 0.0;

    final double totalCombinations = pow(poolSize, length).toDouble();
    final double crackTimeSeconds = totalCombinations / 1e10;

    String verdict;
    if (entropy < 40) {
      verdict = "TRÈS FAIBLE";
    } else if (entropy < 60) {
      verdict = "MOYEN";
    } else {
      verdict = "FORT";
    }

    return PasswordAnalysis(
      entropy: entropy,
      crackTimeSeconds: crackTimeSeconds,
      verdict: verdict,
    );
  }

  /// Formate la durée estimée de crackage brute en chaîne lisible
  String formatCrackTime(double seconds) {
    if (seconds < 60) {
      return "${seconds.toStringAsFixed(2)} secondes";
    } else if (seconds < 3600) {
      return "${(seconds / 60).toStringAsFixed(2)} minutes";
    } else if (seconds < 86400) {
      return "${(seconds / 3600).toStringAsFixed(2)} heures";
    } else if (seconds < 31536000) {
      return "${(seconds / 86400).toStringAsFixed(0)} jours";
    } else {
      return "${(seconds / 31536000).toStringAsFixed(0)} ans";
    }
  }
}