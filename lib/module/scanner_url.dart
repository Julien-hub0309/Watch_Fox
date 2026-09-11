import 'package:http/http.dart' as http;
import '../core/config.dart';

class UrlScannerModule {
  /// Évalue la dangerosité de l'URL par rapport à sa structure syntaxique
  Map<String, dynamic> checkHeuristics(String urlString) {
    int dangerScore = 0;
    List<String> alerts = [];

    Uri uri = Uri.parse(urlString);
    String host = uri.host.toLowerCase();

    if (uri.scheme == 'http') {
      dangerScore += 25;
      alerts.add("Protocole non sécurisé (HTTP détecté)");
    }

    List<String> suspiciousKeywords = ['secure', 'login', 'verification', 'compte', 'connexion', 'banking', 'update'];
    for (var word in suspiciousKeywords) {
      if (host.contains(word)) {
        dangerScore += 15;
        alerts.add("Mot-clé à risque détecté : '$word'");
      }
    }

    List<String> suspiciousTlds = ['.tk', '.ml', '.ga', '.cf', '.gq', '.xyz', '.top'];
    for (var tld in suspiciousTlds) {
      if (host.endsWith(tld)) {
        dangerScore += 30;
        alerts.add("Extension de domaine (TLD) suspecte : '$tld'");
      }
    }

    return {
      "score": dangerScore,
      "alerts": alerts,
      "host": host,
    };
  }

  /// Tente de joindre brièvement l'URL pour voir si le serveur répond
  Future<int?> testUrlConnection(String urlString) async {
    try {
      final response = await http.get(
        Uri.parse(urlString), 
        headers: AppConfig.getRandomHeaders(),
      ).timeout(const Duration(seconds: 4));
      
      return response.statusCode;
    } catch (e) {
      return null;
    }
  }
}