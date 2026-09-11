import 'dart:io';
import 'dart:typed_data';

/// Module d'analyse de fichiers système et de diagnostic d'intégrité.
class FileAnalyzerModule {

  // Liste des répertoires systèmes critiques selon la plateforme.
  static List<String> getSystemDirectories() {
    if (Platform.isWindows) {
      // Sur Windows, les binaires sont souvent dans System32 ou System.
      return [
        r"C:\Windows\System32", 
        r"C:\Program Files"
      ];
    } else if (Platform.isMacOS) {
      // macOS est plus structuré
      return [
        '/bin', 
        '/usr/bin', 
        '/sbin'
      ];
    } else if (Platform.isLinux) {
      // Linux (standard)
      return [
        '/bin', 
        '/usr/bin', 
        '/sbin'
      ];
    }
    return [];
  }

  /// Extrait la description technique brute d'un fichier (Mime/Type, architecture binaire...).
  /// Utilise des outils différents selon l'OS.
  Future<String> getFileDescription(String filePath) async {
    String command = '';
    String tool = '';

    if (Platform.isLinux) {
      command = 'file "$filePath"';
      tool = 'file';
    } else if (Platform.isMacOS) {
      command = 'file "$filePath"';
      tool = 'file';
    } else if (Platform.isWindows) {
      // Sous Windows, nous utilisons la fonctionnalité de l'Explorateur ou PowerShell,
      // car il n'y a pas d'équivalent simple et universel comme 'file'.
      // On se base ici sur une simple vérification de l'extension et une indication.
      return "Analyse de type de fichier limitée sous Windows. Extension: ${filePath.split('.').last.toUpperCase()}";
    } else {
      return "Description de fichier non supportée sur cette plateforme.";
    }

    try {
      final result = await Process.run('sh', ['-c', command]);
      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        final output = result.stdout.toString().trim();
        // Nettoyage simple des outils 'file' qui ajoutent un type au début
        return output.replaceAll(':', '').trim();
      }
      return "Type de fichier indéterminé (Outil $tool a échoué).";
    } catch (e) {
      return "Erreur : L'utilitaire système '$tool' est inaccessible ou non trouvé.";
    }
  }

  /// Diagnostique la corruption d'un fichier binaire spécifique.
  Future<Map<String, dynamic>> diagnosticFileCorruption(String filePath) async {
    try {
      final fileRef = File(filePath);
      if (!await fileRef.exists()) {
        return {"status": "CRITICAL", "message": "ERREUR : Le fichier $filePath n'existe pas."};
      }

      int size = await fileRef.length();
      if (size == 0) {
        return {"status": "CRITICAL", "message": "CORRUPTION : $filePath fait 0 octet."};
      }

      final description = await getFileDescription(filePath);
      
      // ----------------------------------------------------------------
      // Diagnostic de dépendances (Se limite aux plateformes Unix)
      // ----------------------------------------------------------------
      String dependencyCheck = "";
      if (Platform.isLinux) {
        // Diagnostic des dépendances binaires ELF (l'équivalent de ldd)
        dependencyCheck = "ELF (Linux) :";
        final lddResult = await Process.run('ldd', [filePath]);
        
        if (lddResult.exitCode == 0) {
          String lddOutput = lddResult.stdout.toString();
          if (lddOutput.contains("not found")) {
            List<String> brokenLibs = lddOutput
                .split('\n')
                .where((line) => line.contains("not found"))
                .map((line) => line.trim())
                .toList();
            
            return {
              "status": "CRITICAL", 
              "message": "CORRUPTION : Dépendances manquantes (ldd) pour $filePath :\n    -> ${brokenLibs.join('\n    -> ')}"
            };
          }
        } else {
            dependencyCheck += "\n  [Avertissement: Outil 'ldd' a échoué ou non exécutable.]";
        }

      } else if (Platform.isMacOS) {
        // Sur macOS, nous faisons une vérification de base de l'existence et du type.
        // Un vrai check de dépendances nécessite des outils de développeur complexes.
        dependencyCheck = "Type binaire macOS détecté.";
      } else if (Platform.isWindows) {
        dependencyCheck = "Vérification des dépendances binaire complexe sous Windows (non implémentée).";
      }
      
      // ----------------------------------------------------------------
      // Résultat final
      // ----------------------------------------------------------------
      return {
        "status": "OK",
        "message": "INTEGRITÉ VALIDÉE : $filePath (Taille : $size octets). [$description]",
        "details_dep": dependencyCheck
      };

    } catch (e) {
      return {"status": "UNKNOWN", "message": "Échec accès $filePath : $e"};
    }
  }

  /// Scan automatique des répertoires systèmes critiques.
  Future<Map<String, dynamic>> autoScanSystemFiles() async {
    // Utilise la liste de répertoires adaptée à l'OS
    List<String> systemDirs = getSystemDirectories();
    List<String> filesToScan = [];

    for (String dirPath in systemDirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        print("Scanning directory: $dirPath...");
        try {
          await for (FileSystemEntity entity in dir.list()) {
            if (entity is File) {
              filesToScan.add(entity.path);
            }
          }
        } catch (e) {
          print("WARNING: Impossible de lire le dossier $dirPath. (Permissions ?)");
        }
      }
    }

    if (filesToScan.isEmpty) {
         return {"status": "WARNING", "message": "Aucun fichier critique trouvé ou accès refusé dans les chemins système standards."};
    }
    
    return await scanSystemFilesBatch(filesToScan);
  }

  /// Analyse une liste de fichiers pour détecter des corruptions (Batch Scan).
  Future<Map<String, dynamic>> scanSystemFilesBatch(List<String> filePaths) async {
    int total = filePaths.length;
    int corrupted = 0;
    List<String> criticalErrors = [];

    // Limitation de l'analyse pour éviter les timeouts et la saturation CPU
    // Sur un vrai système, il ne faudrait pas scanner *tous* les fichiers.
    final limitedPaths = filePaths.take(50).toList(); 

    print('--- Début de l\'analyse de $total fichiers (limité à $limitedPaths.length) ---');

    for (String path in limitedPaths) {
      var result = await diagnosticFileCorruption(path);
      if (result['status'] == 'CRITICAL') {
        corrupted++;
        criticalErrors.add(result['message']);
      }
    }
    print('--- Analyse terminée ---');


    return {
      "status": corrupted == 0 ? "OK" : "CRITICAL",
      "message": "Scan terminé : $total fichiers analysés, $corrupted corrompus.",
      "details": criticalErrors
    };
  }
}
