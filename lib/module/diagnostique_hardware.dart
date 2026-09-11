import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Nécessaire pour Platform

/// Module de diagnostic matériel conçu pour fonctionner de manière
/// trans-plateforme (Linux, macOS, Windows).
class HardwareDiagnosticModule {

  // Helper fonction pour exécuter des commandes shell de manière sécurisée
  // Nous renvoyons la chaîne de caractères (stdout)
  static Future<String> _runCommand(String command) async {
    final platform = Platform.operatingSystem;
    
    ProcessResult process;
    if (platform.contains('linux') || platform.contains('macOS')) {
      // Utilisation de sh -c pour exécuter des commandes complexes shell
      process = await Process.run('sh', ['-c', command]);
    } else if (platform.contains('windows')) {
      // Utilisation de cmd /c pour exécuter des commandes Windows batch
      process = await Process.run('cmd', ['/c', command]);
    } else {
      return "Plateforme non reconnue pour le diagnostic système.";
    }
    
    // On retourne stdout pour l'utilisation dans les autres méthodes
    return process.stdout.toString().trim();
  }

  // =================================================================
  // 1. CPU : Amélioré pour 3 OS
  // =================================================================
  Future<String> getCpuModel() async {
    String command = "";
    
    if (Platform.isLinux) {
      // Utilisation de Raw String Literal (r'''...''') pour échapper les caractères $
      command = r'lscpu | grep -E "Model name" | cut -d":" -f2 | sed "s/^[ \t]*//"#';
    } else if (Platform.isMacOS) {
      // macOS : Utilisation de Raw String Literal pour les placeholders awk
      command = r'system_profiler SPHardwareDataType | grep "Model Name:" | awk "{print \$3}"';
    } else if (Platform.isWindows) {
      // Windows : wmic cpu get Name
      command = r'wmic cpu get Name';
    } else {
      return "Plateforme non supportée pour CPU";
    }

    try {
      final result = await _runCommand(command);
      return result.isEmpty ? "Processeur générique (Non détecté)" : result;
    } catch (e) {
      return "Erreur CPU lors de l'exécution de la commande : $e";
    }
  }

  // =================================================================
  // 2. RAM : Amélioré pour 3 OS
  // =================================================================
  Future<String> getRamTotal() async {
    double totalGB = 0.0;

    if (Platform.isLinux) {
      // Linux : Lecture via /proc/meminfo (méthode Dart native)
      try {
        final file = File('/proc/meminfo');
        if (await file.exists()) {
          final contents = await file.readAsString();
          final regex = RegExp(r'MemTotal:\s*(\d+)\s*kB');
          final match = regex.firstMatch(contents);
          if (match != null) {
            final kb = int.parse(match.group(1)!);
            totalGB = kb / (1024 * 1024);
          }
        }
      } catch (e) {
        return "Erreur Lecture RAM (Linux) : $e";
      }
    } else if (Platform.isMacOS) {
      // macOS : Lecture via sysctl (appel système)
      try {
        String command = 'sysctl -n hw.memsize';
        final result = await _runCommand(command);
        final bytes = int.tryParse(result);
        if (bytes != null) {
          totalGB = bytes / (1024 * 1024 * 1024);
        }
      } catch (e) {
        return "Erreur Lecture RAM (macOS) : $e";
      }
    } else if (Platform.isWindows) {
      // Windows : Lecture via WMIC (appel système)
      try {
        String command = 'wmic ComputerSystem get TotalPhysicalMemory';
        final result = await _runCommand(command);
        
        final lines = result.split('\n').where((l) => l.contains('TotalPhysicalMemory')).toList();
        if (lines.isNotEmpty) {
            // Nettoyage du résultat pour isoler les nombres
            String bytesStr = lines.first.replaceAll(RegExp(r'[| ]'), '').trim();
            final bytes = int.tryParse(bytesStr);
            if (bytes != null) {
                totalGB = bytes / (1024 * 1024 * 1024);
            }
        }
      } catch (e) {
        return "Erreur Lecture RAM (Windows) : $e";
      }
    }

    return totalGB.toStringAsFixed(2) + " GB";
  }

  // =================================================================
  // 3. GPU : Utilisation de la meilleure commande possible.
  // =================================================================
  Future<String> getGpuModel() async {
    String command = "";
    
    if (Platform.isLinux) {
      // Linux : lspci
      command = r'lspci -v -s 0x20 -d 8086:xxxx | grep -E "VGA|3D" | awk -F: "{print \$2}" | sed "s/^[ \t]*//"';
    } else if (Platform.isMacOS) {
      // macOS : system_profiler
      command = r'system_profiler SPDisplaysDataType | grep "Model Identifier" | awk "{print \$3}"';
    } else if (Platform.isWindows) {
      // Windows : WMIC
      command = r'wmic path Win32_VideoController get Name';
    } else {
      return "Plateforme non supportée pour GPU";
    }

    try {
      final result = await _runCommand(command);
      return result.isEmpty ? "Contrôleur standard ou non détecté" : result;
    } catch (e) {
      return "Erreur GPU : $e";
    }
  }

  // =================================================================
  // 4. Disques : Amélioré pour 3 OS
  // =================================================================
  Future<List<String>> getStorageDevices() async {
    String command;
    if (Platform.isLinux) {
      // Linux : lsblk
      command = r'lsblk -d -n -o NAME,SIZE';
    } else if (Platform.isMacOS) {
      // macOS : diskutil list
      command = r'diskutil list providers';
    } else if (Platform.isWindows) {
      // Windows : WMIC
      command = r'wmic diskdrive get Caption, Size';
    } else {
      return [];
    }
    
    try {
      // Ici, nous nous faisons passer la commande shell comme argument unique.
      final result = await _runCommand(command);
      
      // Le splitting doit être fait sur la chaîne de caractères retournée
      return result
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();
    } catch (e) {
      print("Erreur lors de la récupération des disques: $e");
      return [];
    }
  }

  // =================================================================
  // 5. THERMIQUE : Très difficile à rendre cross-platform.
  // =================================================================
  Future<Map<String, dynamic>> checkThermalStatus() async {
    if (Platform.isLinux) {
      // Maintien de l'approche Linux (la plus fiable)
      Map<String, String> temperatures = {};
      try {
        final dir = Directory('/sys/class/thermal/');
        if (await dir.exists()) {
          final directories = dir.listSync().whereType<Directory>();
          for (var entity in directories) {
            final path = entity.path;
            if (path.contains('thermal_zone')) {
              final typeFile = File('$path/type');
              final tempFile = File('$path/temp');
              
              if (await typeFile.exists() && await tempFile.exists()) {
                 final type = await typeFile.readAsString();
                 final temp = await tempFile.readAsString();
                 try {
                     final tempDouble = double.parse(temp.trim()) / 1000;
                     temperatures[type.trim()] = "${tempDouble.toStringAsFixed(1)}°C";
                 } catch (e) {
                    print("Erreur de parse température: $e");
                 }
              }
            }
          }
        }
      } catch (e) {
        return {"status": "ERROR", "message": "Accès capteurs impossible: $e"};
      }
      
      return {
        "status": temperatures.isEmpty ? "WARNING" : "OK",
        "message": temperatures.isEmpty ? "Aucune sonde détectée" : temperatures.toString()
      };
    } else {
      return {
        "status": "LIMITED",
        "message": "La détection thermique est fortement dépendante du système d'exploitation et est limitée à Linux (/sys/class/thermal/). Ce diagnostic est indisponible sur ${Platform.operatingSystem}."
      };
    }
  }
}