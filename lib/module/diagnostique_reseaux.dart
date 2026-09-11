import 'dart:io';

/// Module de diagnostic réseau conçu pour fonctionner de manière
/// trans-plateforme (Linux, macOS, Windows).
class NetworkDiagnosticModule {

  /// Méthode pour obtenir le rapport complet (Interface, IP, Gateway, Ping, DNS).
  Future<Map<String, dynamic>> performFullNetworkDiagnostic() async {
    print('--- Démarrage du diagnostic réseau ---');
    
    // Exécution des diagnostics étape par étape
    final localData = await getLocalIpAndInterface();
    final publicIp = await getPublicIp();
    final gateway = await getGateway();
    final ping = await checkPingLatency();
    final dnsOk = await testDnsResolution();

    print('------------------------------------');
    return {
      "interface": localData['interface'],
      "ip_locale": localData['ip'],
      "ip_publique": publicIp,
      "gateway": gateway,
      "latence_info": ping['message'],
      "dns_status": dnsOk ? "Opérationnel" : "Échec",
      "status_global": (ping['status'] == 'OK' && dnsOk) ? "OK" : "CRITICAL"
    };
  }

  /// Tente de récupérer l'IP locale et l'interface réseau.
  Future<Map<String, String>> getLocalIpAndInterface() async {
    String interface = "N/A";
    String ip = "Non configurée";

    if (Platform.isWindows) {
      // Windows utilise ipconfig pour obtenir toutes les infos
      try {
        // On lance ipconfig et on parse le résultat
        final result = await Process.run('cmd', ['/c', 'ipconfig']);
        final output = result.stdout.toString();
        
        // Méthode simplifiée pour trouver la première adresse IPv4 active
        final ipRegex = RegExp(r'IPv4\s*Address.*?\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
        final interfaceRegex = RegExp(r'Adapter.*?(\w+)');
        
        // On prend les premières correspondances
        var ipMatch = ipRegex.firstMatch(output);
        var interfaceMatch = interfaceRegex.firstMatch(output);

        if (ipMatch != null) {
          ip = ipMatch.group(1)!;
        }
        if (interfaceMatch != null) {
          interface = interfaceMatch.group(1)!;
        }

      } catch (e) {
        return {"interface": "Erreur", "ip": "N/A"};
      }
    } else if (Platform.isLinux) {
      // Linux : Utilise l'outil 'ip'
      try {
        final result = await Process.run('ip', ['addr']);
        final output = result.stdout.toString();
        
        // Regex pour trouver l'IP et l'interface
        final ipRegex = RegExp(r'inet\s+(\d+\.\d+\.\d+\.\d+)/(\d+)\s+scope');
        final interfaceMatch = RegExp(r'^\d+:\s*(\w+):').firstMatch(output);

        var ipMatch = ipRegex.firstMatch(output);
        var interfaceMatch2 = interfaceMatch?.group(1);

        if (ipMatch != null) {
          ip = ipMatch.group(1)!;
        }
        if (interfaceMatch2 != null) {
          interface = interfaceMatch2;
        }

      } catch (e) {
        return {"interface": "Erreur", "ip": "N/A"};
      }
    } else if (Platform.isMacOS) {
      // macOS : Utilise ifconfig
      try {
        final result = await Process.run('ifconfig', []);
        final output = result.stdout.toString();
        
        // Regex plus complexe pour trouver l'IP et l'interface principale (en assumant l'adaptateur 'en0' ou 'en1')
        // On recherche une ligne contenant 'inet ' et on prend le premier IP.
        final ipRegex = RegExp(r'inet\s+([\d\.]+)/(\d+).*');
        var ipMatch = ipRegex.firstMatch(output);
        
        if (ipMatch != null) {
          ip = ipMatch.group(1)!;
        }
        // L'interface est souvent le nom de la section d'ifconfig (ex: "en0:")
        final interfaceRegex = RegExp(r'^\s*(en\d+|lo0):');
        var interfaceMatch = interfaceRegex.firstMatch(output);
        interface = interfaceMatch != null ? interfaceMatch.group(1)! : "N/A";

      } catch (e) {
        return {"interface": "Erreur", "ip": "N/A"};
      }
    }

    return {"interface": interface, "ip": ip};
  }

  /// Récupère l'IP publique en utilisant une API externe.
  Future<String> getPublicIp() async {
    // Utiliser curl est la méthode la plus universellement acceptée.
    // On force l'utilisation de 'curl' via sh pour la cohérence, car c'est souvent l'outil disponible.
    try {
      final result = await Process.run('curl', ['-s', '--connect-timeout', '3', 'https://api.ipify.org']);
      if (result.exitCode == 0 && result.stdout.isNotEmpty) {
        return result.stdout.toString().trim();
      }
      return "Indisponible";
    } catch (_) {
      return "Indisponible";
    }
  }

  /// Récupère la passerelle par défaut (Gateway).
  Future<String> getGateway() async {
    String command;
    if (Platform.isWindows) {
      // Windows : utilise netsh ou ipconfig
      command = 'ipconfig | findstr "Gateway"';
    } else if (Platform.isLinux) {
      // Linux : utilise la méthode 'ip route' originale
      command = "ip route show | grep default | awk '{print \$3}'";
    } else if (Platform.isMacOS) {
      // macOS : utilise netstat
      command = 'netstat -inet | grep default';
    } else {
      return "Méthode Gateway non supportée";
    }

    try {
      final result = await Process.run('sh', ['-c', command]);
      String rawOutput = result.stdout.toString().trim();

      // Nettoyage spécifique pour les OS qui renvoient "default" en plus de l'IP
      if (Platform.isWindows && rawOutput.contains("default")) {
         // Regex simple pour extraire l'IP après "Gateway"
         final gatewayRegex = RegExp(r'Gateway\s+\[.*?\]\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
         final match = gatewayRegex.firstMatch(rawOutput);
         return match != null ? match.group(1)! : "Inconnue";
      }
      
      // Pour les autres OS, la ligne est plus directe
      return rawOutput.isEmpty ? "Inconnue" : rawOutput;

    } catch (_) {
      return "Inconnue";
    }
  }

  /// Vérifie la latence de ping vers 1.1.1.1.
  Future<Map<String, dynamic>> checkPingLatency() async {
    String command;
    List<String> args = [];

    if (Platform.isWindows) {
      // Windows : -n (nombre de paquets), -w (timeout en ms)
      command = 'ping -n 3 -w 2000 1.1.1.1';
    } else {
      // Linux et macOS : -c (nombre de paquets), -W (timeout en secondes)
      // macOS utilise -c, Linux utilise -c
      command = 'ping -c 3 -W 2 1.1.1.1';
    }

    try {
      final result = await Process.run('sh', ['-c', command]);
      final output = result.stdout.toString();

      if (result.exitCode != 0) {
        return {"status": "CRITICAL", "message": "Pas de réponse au ping"};
      }

      // La parsing de la latence est le plus difficile, car le format change énormément.
      // On essaie de cibler la moyenne (rtt min/avg/max)
      String avgLatency = "N/A";
      
      if (Platform.isWindows) {
          // Windows affiche : de, temps=Xms, perte=0%
          final match = RegExp(r'\d+ms').firstMatch(output);
          if (match != null) {
             avgLatency = match.group(0)!;
          }
      } else {
          // Linux/macOS affiche : rtt min/avg/max/mdev
          final statsLine = output.split('\n').lastWhere(
              (l) => l.contains('rtt'), orElse: () => ""
          );
          final parts = statsLine.split('/');
          // L'avg est souvent le 4ème élément (index 3)
          avgLatency = parts.length > 3 ? parts[3].trim() : "N/A";
      }


      return {"status": "OK", "message": "Latence moyenne: $avgLatency"};
    } catch (_) {
      return {"status": "UNKNOWN", "message": "Ping échoué (outil non trouvé)"};
    }
  }

  /// Teste la résolution DNS en fonction de l'OS.
  Future<bool> testDnsResolution() async {
    String command;

    if (Platform.isWindows) {
      // Windows utilise nslookup
      command = 'nslookup google.com';
    } else if (Platform.isMacOS) {
      // macOS préfère dig si disponible, sinon utilise host
      command = 'dig google.com A';
    } else { // Linux
      // Linux utilise souvent dig, mais host est un fallback standard
      command = 'dig google.com A @8.8.8.8'; 
    }

    try {
      final result = await Process.run('sh', ['-c', command]);
      
      // Si la commande s'exécute sans erreur et renvoie du contenu, le DNS est fonctionnel.
      return result.exitCode == 0 && result.stdout.toString().contains("google.com");
    } catch (_) {
      return false;
    }
  }
}