import 'dart:io';
import 'dart:async';
import 'dart:convert';

// ====================================================================
// CLASSE DE CONNEXION ET SCANNER DE PORTS (DeviceConnector)
// ====================================================================
class DeviceConnector {
  final String targetIp;
  final String password;
  final Duration timeout;

  DeviceConnector({
    required this.targetIp,
    required this.password,
    this.timeout = const Duration(seconds: 5),
  });

  // Liste des ports couramment scannés
  static const List<int> commonPorts = [
    21, 22, 23, 80, 135, 139, 443, 445, 993, 995, 1433, 3306, 3389, 5432, 5900, 8080,
  ];

  /// Scan les ports ouverts en envoyant des requêtes de connexion.
  Future<List<int>> scanOpenPorts() async {
    print('🔍 Scan des ports ouverts sur ${targetIp}...');
    
    final openPorts = <int>[];
    // Crée des Futures pour chaque vérification de port et attend qu'elles soient toutes terminées
    final futures = commonPorts.map((port) => _checkPort(port));
    final results = await Future.wait(futures);
    
    for (int i = 0; i < results.length; i++) {
      if (results[i]) {
        openPorts.add(commonPorts[i]);
      }
    }
    
    print('✅ ${openPorts.length} ports ouverts détectés: ${openPorts.join(', ')}');
    return openPorts;
  }

  /// Vérifie si un port est ouvert via une tentative de connexion TCP.
  Future<bool> _checkPort(int port) async {
    try {
      final socket = await Socket.connect(targetIp, port, timeout: timeout);
      socket.destroy(); // Ferme immédiatement la connexion
      return true;
    } catch (e) {
      // Ignorer les erreurs de connexion (timeout, refus)
      return false;
    }
  }

  /// Tente d'établir des connexions et d'exécuter des commandes spécifiques
  /// pour les services détectés (SSH, FTP, RDP, etc.).
  Future<void> tryConnections(List<int> openPorts) async {
    print('\n================================================');
    print('🔐 Tentatives de connexion aux services');
    print('================================================');
    
    for (final port in openPorts) {
      final serviceName = _getServiceName(port);
      print('\n------------------------------------------------');
      print('🔌 Tentative de connexion sur le port $port ($serviceName)...');
      
      try {
        switch (port) {
          case 22:
            await _trySSHConnection(port);
            break;
          case 21:
            await _tryFTPConnection(port);
            break;
          case 23:
            await _tryTelnetConnection(port);
            break;
          case 3389:
            await _tryRDPConnection(port);
            break;
          case 5900:
            await _tryVNCConnection(port);
            break;
          default:
            print('⚠️ Pas de méthode de connexion spécialisée implémentée pour le port $port.');
        }
      } catch (e) {
        print('❌ Échec inattendu de la connexion sur le port $port: $e');
      }
    }
  }

  /// Retourne le nom du service associé à un port.
  String _getServiceName(int port) {
    const Map<int, String> services = {
      21: 'FTP', 22: 'SSH', 23: 'Telnet', 80: 'HTTP', 135: 'RPC', 139: 'NetBIOS',
      443: 'HTTPS', 445: 'SMB', 993: 'IMAPS', 995: 'POP3S', 1433: 'MSSQL',
      3306: 'MySQL', 3389: 'RDP', 5432: 'PostgreSQL', 5900: 'VNC', 8080: 'HTTP-Alt',
    };
    return services[port] ?? 'Unknown';
  }

  // ====================================================================
  // Méthodes de connexion spécifiques
  // ====================================================================

  /// Tente une connexion SSH avec exécution d'une commande simple.
  Future<void> _trySSHConnection(int port) async {
    print('🔐 Tentative de connexion SSH...');
    try {
      final result = await Process.run('ssh', [
        '-o', 'ConnectTimeout=5',
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'PasswordAuthentication=yes',
        'user@$targetIp',
        '-p', '$port',
        'echo "Connection successful"'
      ], runInShell: true);
      
      if (result.exitCode == 0) {
        print('✅ Connexion SSH réussie sur le port $port!');
        print('📄 Sortie: ${result.stdout}');
      } else {
        print('❌ Échec de la connexion SSH. Code d\'erreur: ${result.exitCode}');
        print('stderr: ${result.stderr}');
      }
    } catch (e) {
      print('❌ Erreur lors de la tentative SSH: $e');
    }
  }

  /// Tente une connexion FTP en s'authentifiant en tant qu'utilisateur anonyme.
  Future<void> _tryFTPConnection(int port) async {
    print('🔐 Tentative de connexion FTP...');
    try {
      final process = await Process.start('ftp', [targetIp, port.toString()]);
      
      // 1. Envoyer les commandes via stdin
      process.stdin.writeln('user anonymous $password');
      process.stdin.writeln('ls');
      process.stdin.writeln('quit');
      await process.stdin.close(); 
      
      // 2. Lire la sortie et attendre le code de sortie
      final stdout = await utf8.decodeStream(process.stdout);
      final exitCode = await process.exitCode;
      
      if (exitCode == 0) {
        print('✅ Connexion FTP réussie sur le port $port!');
        print('📄 Sortie: $stdout');
      } else {
        print('❌ Échec de la connexion FTP. Code de sortie: $exitCode');
      }
    } catch (e) {
      print('❌ Erreur lors de la tentative FTP: $e');
    }
  }

  /// Tente une connexion Telnet en utilisant l'outil expect.
  Future<void> _tryTelnetConnection(int port) async {
    print('🔐 Tentative de connexion Telnet...');
    try {
      final script = '''
set timeout 5
spawn telnet $targetIp $port
expect "login:"
send "anonymous\\r"
expect "Password:"
send "$password\\r"
expect "\$"
send "echo 'Connection successful'\\r"
expect "\$"
send "exit\\r"
expect eof
''';
      final result = await Process.run('expect', ['-c', script], runInShell: true);
      
      if (result.exitCode == 0) {
        print('✅ Connexion Telnet réussie sur le port $port!');
        print('📄 Sortie: ${result.stdout}');
      } else {
        print('❌ Échec de la connexion Telnet. Code d\'erreur: ${result.exitCode}');
        print('stderr: ${result.stderr}');
      }
    } catch (e) {
      print('❌ Erreur lors de la tentative Telnet: $e');
    }
  }

  /// Tente une connexion RDP en utilisant xfreerdp.
  Future<void> _tryRDPConnection(int port) async {
    print('🔐 Tentative de connexion RDP...');
    try {
      final result = await Process.run('xfreerdp', [
        '/v:$targetIp:$port',
        '/u:anonymous',
        '/p:$password',
        '/cert-ignore',
        '/bpp:8',
        '/size:800x600',
        '/timeout:5000',
        '/echo',
      ], runInShell: true);
      
      if (result.exitCode == 0) {
        print('✅ Connexion RDP réussie sur le port $port!');
      } else {
        print('❌ Échec de la connexion RDP. Code d\'erreur: ${result.exitCode}');
        print('stderr: ${result.stderr}');
      }
    } catch (e) {
      print('❌ Erreur lors de la tentative RDP: $e');
    }
  }

  /// Tente une connexion VNC en utilisant vncviewer.
  Future<void> _tryVNCConnection(int port) async {
    print('🔐 Tentative de connexion VNC...');
    try {
      final result = await Process.run('vncviewer', [
        '-passwd', '$password',
        '$targetIp:$port',
        '-autopass',
      ], runInShell: true);
      
      if (result.exitCode == 0) {
        print('✅ Connexion VNC réussie sur le port $port!');
      } else {
        print('❌ Échec de la connexion VNC. Code d\'erreur: ${result.exitCode}');
        print('stderr: ${result.stderr}');
      }
    } catch (e) {
      print('❌ Erreur lors de la tentative VNC: $e');
    }
  }

  /// Orchestre le processus complet de scan et de connexion.
  Future<void> connect() async {
    print('=================================================');
    print('✨ Démarrage de l\'analyse du périphérique $targetIp');
    print('=================================================');
    
    final openPorts = await scanOpenPorts();
    
    if (openPorts.isEmpty) {
      print('\n❌ Aucun port ouvert détecté sur $targetIp. Impossible de continuer.');
      return;
    }
    
    await tryConnections(openPorts);
    print('\n=================================================');
    print('📊 Analyse terminée.');
    print('=================================================');
  }
}

// ====================================================================
// FONCTIONS UTILITAIRES ET MAIN
// ====================================================================

/// Valide si la chaîne donnée est une adresse IP valide.
bool _isValidIP(String ip) {
  final regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
  if (!regex.hasMatch(ip)) return false;
  final parts = ip.split('.');
  for (final part in parts) {
    final num = int.tryParse(part);
    // Vérifie que le nombre est bien compris et dans la plage [0, 255]
    if (num == null || num < 0 || num > 255) return false;
  }
  return true;
}

void main(List<String> arguments) async {
  if (arguments.length < 2) {
    print('================================================');
    print('SCANNER DE PORTS & CONNECTIVITÉ DE DÉVICE');
    print('================================================');
    print('Utilisation: dart run device_connector.dart <adresse_ip> <mot_de_passe>');
    print('Exemple: dart run device_connector.dart 192.168.1.1 secretpass');
    return;
  }
  
  final String ip = arguments[0];
  final String password = arguments[1];
  
  if (!_isValidIP(ip)) {
    print('❌ Adresse IP invalide: $ip');
    return;
  }
  
  final connector = DeviceConnector(targetIp: ip, password: password);
  await connector.connect();
}
