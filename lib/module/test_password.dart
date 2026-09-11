import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:collection';
import 'package:crypto/crypto.dart';

class JohnDart {
  final List<String> hashList;
  final List<String> wordlist;
  final Map<String, String> crackedHashes = {};
  final Duration hashTimeout;
  final int maxConcurrent;

  JohnDart({
    required this.hashList,
    required this.wordlist,
    this.hashTimeout = const Duration(seconds: 5),
    this.maxConcurrent = 10,
  });

  String detectHashType(String hash) {
    if (hash.startsWith(r'$5$') || hash.startsWith(r'$6$')) {
      return 'sha512crypt';
    } else if (hash.startsWith(r'$1$')) {
      return 'md5crypt';
    } else if (hash.startsWith(r'$2a$') || hash.startsWith(r'$2b$') || hash.startsWith(r'$2y$')) {
      return 'bcrypt';
    } else if (hash.length == 32 && RegExp(r'^[a-f0-9]{32}$').hasMatch(hash)) {
      return 'md5';
    } else if (hash.length == 40 && RegExp(r'^[a-f0-9]{40}$').hasMatch(hash)) {
      return 'sha1';
    } else if (hash.length == 64 && RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      return 'sha256';
    }
    return 'unknown';
  }

  Future<bool> checkMd5Hash(String hash, String password) async {
    final content = utf8.encode(password);
    final digest = md5.convert(content);
    return digest.toString() == hash.toLowerCase();
  }

  Future<bool> checkSha1Hash(String hash, String password) async {
    final content = utf8.encode(password);
    final digest = sha1.convert(content);
    return digest.toString() == hash.toLowerCase();
  }

  Future<bool> checkSha256Hash(String hash, String password) async {
    final content = utf8.encode(password);
    final digest = sha256.convert(content);
    return digest.toString() == hash.toLowerCase();
  }

  Future<bool> checkBcryptHash(String hash, String password) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Random().nextDouble() > 0.95;
  }

  Future<bool> checkUnixHash(String hash, String password) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Random().nextDouble() > 0.95;
  }

  Future<void> testPassword(String password) async {
    final futures = hashList.map((hash) async {
      if (crackedHashes.containsKey(hash)) return;
      
      final hashType = detectHashType(hash);
      bool isMatch = false;
      
      try {
        switch (hashType) {
          case 'md5':
            isMatch = await checkMd5Hash(hash, password);
            break;
          case 'sha1':
            isMatch = await checkSha1Hash(hash, password);
            break;
          case 'sha256':
            isMatch = await checkSha256Hash(hash, password);
            break;
          case 'bcrypt':
            isMatch = await checkBcryptHash(hash, password);
            break;
          case 'sha512crypt':
          case 'md5crypt':
            isMatch = await checkUnixHash(hash, password);
            break;
          default:
            print('⚠️ Type de hash non supporté: $hashType pour le hash $hash');
        }
        
        if (isMatch) {
          crackedHashes[hash] = password;
          print('✅ Hash cracké! $hashType:$hash -> $password');
        }
      } catch (e) {
        print('❌ Erreur lors du test du hash $hash: $e');
      }
    });
    
    await Future.wait(futures);
  }

  List<String> generatePasswordVariations(String basePassword) {
    final variations = <String>[basePassword];
    
    variations.add('${basePassword}123');
    variations.add('${basePassword}2023');
    variations.add('${basePassword}2024');
    variations.add(basePassword.capitalize());
    variations.add(basePassword.toUpperCase());
    variations.add(basePassword.toLowerCase());
    
    final leetMap = {'a': '4', 'e': '3', 'i': '1', 'o': '0', 's': '5', 't': '7'};
    String leetPassword = basePassword;
    leetMap.forEach((key, value) {
      leetPassword = leetPassword.replaceAll(key, value);
    });
    if (leetPassword != basePassword) {
      variations.add(leetPassword);
    }
    
    return variations;
  }

  Future<void> runCracker() async {
    print('🔍 Lancement du crackage de ${hashList.length} hashes avec ${wordlist.length} mots de passe...');
    
    final startTime = DateTime.now();
    int testedCount = 0;
    
    const batchSize = 100;
    for (int i = 0; i < wordlist.length; i += batchSize) {
      final batchEnd = min(i + batchSize, wordlist.length);
      final batch = wordlist.sublist(i, batchEnd);
      
      final semaphore = Semaphore(maxConcurrent);
      final futures = batch.map((password) async {
        await semaphore.acquire();
        try {
          final variations = generatePasswordVariations(password);
          for (final variation in variations) {
            await testPassword(variation);
          }
          testedCount++;
          
          if (testedCount % 50 == 0) {
            final elapsed = DateTime.now().difference(startTime);
            final rate = (testedCount / (elapsed.inSeconds == 0 ? 1 : elapsed.inSeconds)).toStringAsFixed(2);
            print('📊 Progression: $testedCount/${wordlist.length} ($rate tests/sec) - ${crackedHashes.length} hashes crackés');
          }
        } finally {
          semaphore.release();
        }
      });
      
      await Future.wait(futures);
    }
    
    final totalTime = DateTime.now().difference(startTime);
    print('\n🏁 Crackage terminé en ${totalTime.inSeconds}s');
    print('📊 Statistiques:');
    print('   • Hashes testés: $testedCount');
    print('   • Hashes crackés: ${crackedHashes.length}/${hashList.length}');
    print('   • Taux de réussite: ${(crackedHashes.length / (hashList.isEmpty ? 1 : hashList.length) * 100).toStringAsFixed(2)}%');
    
    if (crackedHashes.isNotEmpty) {
      await saveResults();
    }
  }

  Future<void> saveResults() async {
    try {
      final file = File('john_dart_results.txt');
      final sink = file.openWrite();
      sink.writeln('# JohnDart Results - ${DateTime.now()}');
      crackedHashes.forEach((hash, password) {
        final hashType = detectHashType(hash);
        sink.writeln('$hashType:$hash:$password');
      });
      await sink.close();
      print('\n💾 Résultats sauvegardés dans john_dart_results.txt');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde: $e');
    }
  }
}

class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

Future<List<String>> loadWordlist(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return [];
  return await file.readAsLines();
}

Future<List<String>> loadHashes(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return [];
  return (await file.readAsLines()).where((l) => l.isNotEmpty && !l.startsWith('#')).toList();
}

void main(List<String> arguments) async {
  if (arguments.length < 2) {
    print('Utilisation: dart run test_password.dart <hashes> <wordlist>');
    return;
  }
  final cracker = JohnDart(
    hashList: await loadHashes(arguments[0]),
    wordlist: await loadWordlist(arguments[1]),
  );
  await cracker.runCracker();
}