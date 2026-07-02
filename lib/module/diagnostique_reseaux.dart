import 'dart:io';

class NetworkDiagnosticModule {
  
  /// Méthode pour obtenir le rapport complet (Interface, IP, Gateway, Ping, DNS)
  Future<Map<String, dynamic>> performFullNetworkDiagnostic() async {
    final localData = await getLocalIpAndInterface();
    final publicIp = await getPublicIp();
    final gateway = await getGateway();
    final ping = await checkPingLatency();
    final dnsOk = await testDnsResolution();

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

  Future<Map<String, String>> getLocalIpAndInterface() async {
    try {
      final routeResult = await Process.run('sh', ['-c', "ip route show | grep default | awk '{print \$5}'"]);
      String interface = routeResult.stdout.toString().trim();
      
      if (interface.isEmpty) return {"interface": "Inconnue", "ip": "Non configurée"};

      final ipResult = await Process.run('sh', ['-c', "ip addr show $interface | grep 'inet ' | awk '{print \$2}' | cut -d/ -f1 | head -n1"]);
      String ip = ipResult.stdout.toString().trim();

      return {"interface": interface, "ip": ip.isNotEmpty ? ip : "Déconnecté"};
    } catch (_) {
      return {"interface": "Erreur", "ip": "N/A"};
    }
  }

  Future<String> getPublicIp() async {
    try {
      final result = await Process.run('curl', ['-s', '--connect-timeout', '3', 'https://api.ipify.org']);
      return (result.exitCode == 0) ? result.stdout.toString().trim() : "Indisponible";
    } catch (_) {
      return "Indisponible";
    }
  }

  Future<String> getGateway() async {
    try {
      final result = await Process.run('sh', ['-c', "ip route show | grep default | awk '{print \$3}'"]);
      return (result.exitCode == 0 && result.stdout.toString().isNotEmpty) 
          ? result.stdout.toString().trim() : "Inconnue";
    } catch (_) {
      return "Inconnue";
    }
  }

  Future<Map<String, dynamic>> checkPingLatency() async {
    try {
      final result = await Process.run('ping', ['-c', '3', '-W', '2', '1.1.1.1']);
      if (result.exitCode != 0) {
        return {"status": "CRITICAL", "message": "Perte de paquets"};
      }
      final statsLine = result.stdout.toString().split('\n').lastWhere((l) => l.contains('rtt'), orElse: () => "");
      String avgLatency = statsLine.isNotEmpty ? statsLine.split('/')[4] : "N/A";
      return {"status": "OK", "message": "$avgLatency ms"};
    } catch (_) {
      return {"status": "UNKNOWN", "message": "Ping échoué"};
    }
  }

  Future<bool> testDnsResolution() async {
    final result = await Process.run('sh', ['-c', 'getent hosts google.com > /dev/null']);
    return result.exitCode == 0;
  }
}