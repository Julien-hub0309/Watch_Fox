import 'dart:io';
import 'package:crypto/crypto.dart';

// Votre base de données de hashs
final Set<String> virusSignatures = {
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
};

Future<void> main() async {
  print('--- Scanner de Fichiers (Mode Interactif) ---');
  print('Veuillez entrer le chemin absolu ou relatif du fichier à scanner :');
  
  // Lecture de l'entrée utilisateur
  final input = stdin.readLineSync();
  
  if (input == null || input.trim().isEmpty) {
    print('Erreur : Aucun chemin fourni.');
    return;
  }

  final filePath = input.trim();
  final file = File(filePath);

  if (!await file.exists()) {
    print('Erreur : Le fichier "$filePath" est introuvable.');
    return;
  }

  print('Calcul du hash et analyse en cours...');

  try {
    // Lecture des octets pour calculer le hash
    final bytes = await file.readAsBytes();
    final fileHash = sha256.convert(bytes).toString();

    print('Hash SHA-256 : $fileHash');

    if (virusSignatures.contains(fileHash)) {
      print('⚠️ ATTENTION : Ce fichier correspond à une signature de virus connue !');
    } else {
      print('✅ Fichier sain (aucune correspondance trouvée).');
    }
  } catch (e) {
    print('Erreur lors de l\'accès au fichier : $e');
  }
  
  print('\nAppuyez sur Entrée pour quitter.');
  stdin.readLineSync();
}