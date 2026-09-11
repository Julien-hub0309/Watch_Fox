import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

// Assuming these imports are correct and present
import 'core/base.dart';
import 'core/config.dart';
import 'module/diagnostique_hardware.dart';
import 'module/diagnostique_reseaux.dart';
import 'module/diagnostique_software.dart';
import 'module/osint_mail.dart';
import 'module/osint_pseudo.dart';
import 'module/osint_reseaux.dart';
import 'module/osint_web.dart';
import 'module/sacnner_file.dart';
import 'module/scanner_url.dart';
import 'module/test_connexion.dart';
import 'module/test_password.dart';
import 'module/password_scanner_module.dart';

void main() => runApp(const WatchFoxApp());

// ─── Couleurs globales Watch Dogs (Bleu Cyan Industriel) ─────────────────────
const kDeepBlack = Color(0xFF0A0A0A);
const kDarkGray = Color(0xFF1A1A1A);
const kCyanAccent = Color(0x40B0FF);
const kBlueDark = Color(0xFF80B0FF);

// Signatures virales connues (exemple)
const Set<String> virusSignatures = {
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // hash vide
};

class WatchFoxApp extends StatelessWidget {
  const WatchFoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kDeepBlack,
        cardColor: kDarkGray,
        primaryColor: kCyanAccent,
        colorScheme: ColorScheme.dark(
          primary: kCyanAccent,
          secondary: kBlueDark,
        ),
      ),
      home: const WatchFoxHome(),
    );
  }
}

// ─── Définition des modules ───────────────────────────────────────────────────
class ModuleDefinition {
  final String name;
  final String icon;
  final String category;
  final String? targetHint;

  const ModuleDefinition({
    required this.name,
    required this.icon,
    required this.category,
    this.targetHint,
  });

  bool get requiresTarget => targetHint != null;
}

const List<ModuleDefinition> kModules = [
  ModuleDefinition(name: "Hardware",      icon: "💾", category: "Diagnostique", targetHint: null),
  ModuleDefinition(name: "Réseaux",       icon: "📡", category: "Diagnostique", targetHint: null),
  ModuleDefinition(name: "Software",      icon: "🖥️", category: "Diagnostique", targetHint: null),
  ModuleDefinition(name: "Mail OSINT",    icon: "📧", category: "OSINT",        targetHint: "Adresse e-mail"),
  ModuleDefinition(name: "Pseudo OSINT",  icon: "👤", category: "OSINT",        targetHint: "Pseudonyme / username"),
  ModuleDefinition(name: "Réseaux OSINT", icon: "🌐", category: "OSINT",        targetHint: "URL / domaine / IP"),
  ModuleDefinition(name: "Web OSINT",     icon: "🔎", category: "OSINT",        targetHint: "URL ou domaine"),
  ModuleDefinition(name: "File Scanner",  icon: "📂", category: "Scanner",      targetHint: "Chemin du fichier"),
  ModuleDefinition(name: "URL Scanner",   icon: "🔗", category: "Scanner",      targetHint: "URL à analyser"),
  ModuleDefinition(name: "Connexion",     icon: "🔌", category: "Test",         targetHint: "IP:mot_de_passe  (ex: 192.168.1.1:admin)"),
  ModuleDefinition(name: "Password Crack", icon: "🔐", category: "Test",         targetHint: "Mot de passe à tester"),
  ModuleDefinition(name: "Password Calculator", icon: "🧮", category: "Test",   targetHint: "Mot de passe à analyser (ou 'generate' pour en créer un)"),
];

// ─── Home (Refactorisé pour l'esthétique Watch Dogs) ────────────────────────
class WatchFoxHome extends StatefulWidget {
  const WatchFoxHome({super.key});

  @override
  State<WatchFoxHome> createState() => _WatchFoxHomeState();
}

class _WatchFoxHomeState extends State<WatchFoxHome> {
  final TextEditingController _targetController = TextEditingController();
  final List<String> _consoleBuffer = ["[!] SYSTÈME DE SURVEILLANCE WATCH_FOX V2.0 initialisé..."];
  final ScrollController _scrollController = ScrollController();

  ModuleDefinition? _selectedModule;

  double? _progress;
  String  _progressLabel = "";

  // ── Horloge & chronomètre de session ────────────────────────────────────
  late final DateTime _sessionStart; // Heure de lancement de l'application
  DateTime _now = DateTime.now();
  Duration _elapsed = Duration.zero;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _now = _sessionStart;

    // Timer qui se déclenche chaque seconde pour rafraîchir l'horloge
    // ET le chronomètre de temps passé sur l'application.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _elapsed = _now.difference(_sessionStart);
      });
    });
  }

  // Formate une Duration en HH:MM:SS
  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  // Formate l'heure courante en HH:MM:SS
  String _formatClock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  // ── Sélection d'un module ──────────────────────────────────────────────────
  void _selectModule(ModuleDefinition module) {
    setState(() {
      _selectedModule = module;
      _targetController.clear();
      _progress = null;
      _progressLabel = "";
    });
    if (!module.requiresTarget) {
      _launchModule(module, null);
    }
  }

  // ── Interception de print() → console Flutter (Logique inchangée) ──
  void _log(String line) {
    if (!mounted) return;
    
    String mapped = line;
    
    if (line.startsWith('[*]') || line.startsWith('[>]') || 
        line.startsWith('[~]') || line.startsWith('[!]')) {
      mapped = line;
    } 
    else if (line.startsWith('✅') || line.startsWith('✓')) {
      mapped = '[~] ${line.substring(line.indexOf(' ') + 1)}'; 
    } else if (line.startsWith('❌') || line.startsWith('✗')) {
      mapped = '[!] ${line.substring(line.indexOf(' ') + 1)}'; 
    } else if (line.startsWith('🔍') || line.startsWith('📊') || line.startsWith('📡') ||
               line.startsWith('🔐') || line.startsWith('🔌') || line.startsWith('📄') ||
               line.startsWith('★') || line.startsWith('===')) {
      mapped = '[*] $line'; 
    } else if (line.startsWith('⚠️') || line.startsWith('💾') || line.startsWith('🏁')) {
      mapped = '[>] $line'; 
    } else {
      mapped = '[?] $line'; // Nouveau préfixe pour le défaut
    }
    
    setState(() => _consoleBuffer.add(mapped));
    _scrollToBottom();
  }

  // Lancement du module (Logique inchangée)
  Future<void> _launchModule(ModuleDefinition module, String? target) async {
    // ... (Le contenu de _launchModule est inchangé) ...
    setState(() {
      _consoleBuffer.add("");
      _consoleBuffer.add("======================================================");
      _consoleBuffer.add("[*] EXÉCUTION MODULE : ${module.name}");
      _consoleBuffer.add(target != null
          ? "[>] CIBLE  : $target"
          : "[>] CIBLE  : MACHINE LOCALE");
      _consoleBuffer.add("======================================================");
      _consoleBuffer.add("[~] Initialisation des subroutines...");
      _progress = 0.05;
      _progressLabel = "Démarrage...";
    });
    _scrollToBottom();

    try {
      await runZonedGuarded(
        () => _runModuleLogic(module, target),
        (error, stack) {
          _log('[!] ÉCHEC CRITIQUE : $error');
          if (verboseDebug) {
            _log('[!] STACK : $stack');
          }
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => _log(line),
        ),
      );
    } catch (e) {
      _log('[!] ERREUR INATTENDUE : $e');
    } finally {
      setState(() {
        _progress = 1.0;
        _progressLabel = "TERMINÉ. PRÊT POUR LA PROCHAINE CIBLE.";
      });
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() {
        _progress = null;
        _progressLabel = "";
      });
    }
  }

  // Contient le vrai switch vers chaque module (Logique inchangée)
  Future<void> _runModuleLogic(ModuleDefinition module, String? target) async {
    // ... (Le contenu du switch est inchangé) ...
    void step(double v, String label) {
      if (!mounted) return;
      setState(() {
        _progress = v;
        _progressLabel = label;
      });
    }

    switch (module.name) {
      // ── DIAGNOSTIQUE ────────────────────────────────────────────────────
      case "Hardware":
        step(0.2, "Lecture CPU / RAM...");
        final hw = HardwareDiagnosticModule();
        final cpu    = await hw.getCpuModel();
        final ram    = await hw.getRamTotal();
        step(0.5, "Lecture GPU / stockage...");
        final gpu    = await hw.getGpuModel();
        final disks  = await hw.getStorageDevices();
        step(0.8, "Capteurs thermiques...");
        final therm  = await hw.checkThermalStatus();
        print("CPU     : $cpu");
        print("RAM     : $ram");
        print("GPU     : $gpu");
        print("Disques : ${disks.join(' | ')}");
        print("Therm.  : ${therm['message']}");
        break;

      case "Réseaux":
        step(0.3, "Récupération IP locale...");
        final net = NetworkDiagnosticModule();
        final report = await net.performFullNetworkDiagnostic();
        step(0.9, "Analyse terminée...");
        report.forEach((k, v) => print("$k : $v"));
        break;

      case "Software":
        step(0.2, "Scan des fichiers système...");
        final sw = FileAnalyzerModule();
        final result = await sw.autoScanSystemFiles();
        step(0.9, "Résultats...");
        print(result['message']);
        final details = result['details'] as List<String>? ?? [];
        for (final d in details) { print('[!] $d'); }
        break;

      // ── OSINT ────────────────────────────────────────────────────────────
      case "Mail OSINT":
        if (target == null || target.isEmpty) { print('[!] Cible manquante.'); break; }
        step(0.1, "Validation e-mail...");
        final mail = EmailOSINT(target);
        mail.verbose = true;
        step(0.2, "Scan en cours (peut prendre du temps)...");
        await mail.runFullScan();
        break;

      case "Pseudo OSINT":
        if (target == null || target.isEmpty) { print('[!] Cible manquante.'); break; }
        step(0.1, "Recherche du pseudo sur les plateformes...");
        final pseudo = UsernameOSINT(target);
        pseudo.verbose = true;
        await pseudo.runScan();
        step(0.95, "Affichage des résultats...");
        pseudo.printResults();
        break;

      case "Réseaux OSINT":
        if (target == null || target.isEmpty) { print('[!] Cible manquante.'); break; }
        final nmapd = NmapDart(
          target: target,
          serviceVersion: true,
          verbose: true,
          onProgress: (v, label) => step(v, label),
        );
        await nmapd.scan();
        break;

      case "Web OSINT":
        if (target == null || target.isEmpty) { print('[!] Cible manquante.'); break; }
        step(0.2, "Analyse infrastructure...");
        final web = WebScanner(target);
        await web.scanInfra();
        break;

      // ── SCANNERS ─────────────────────────────────────────────────────────
      case "File Scanner":
        if (target == null || target.isEmpty) { print('[!] Chemin manquant.'); break; }
        step(0.3, "Calcul du hash SHA-256...");
        final file = File(target);
        if (!await file.exists()) { print('[!] Fichier introuvable : $target'); break; }
        final bytes    = await file.readAsBytes();
        final fileHash = sha256.convert(bytes).toString();
        print("Fichier : $target");
        print("SHA-256 : $fileHash");
        step(0.8, "Vérification signature...");
        if (virusSignatures.contains(fileHash)) {
          print('[!] ⚠️ SIGNATURE VIRUS DÉTECTÉE !');
        } else {
          print('[~] ✅ Aucune signature malveillante trouvée.');
        }
        break;

      case "URL Scanner":
        if (target == null || target.isEmpty) { print('[!] URL manquante.'); break; }
        step(0.3, "Analyse heuristique...");
        final urlScanner = UrlScannerModule();
        final heuristics = urlScanner.checkHeuristics(target);
        print("Hôte         : ${heuristics['host']}");
        print("Score danger : ${heuristics['score']}/100");
        final alerts = heuristics['alerts'] as List<String>;
        if (alerts.isEmpty) {
          print("[~] Aucune alerte heuristique.");
        } else {
          for (final a in alerts) { print("[!] $a"); }
        }
        step(0.7, "Test de connexion HTTP...");
        final statusCode = await urlScanner.testUrlConnection(target);
        if (statusCode != null) {
          print("Statut HTTP  : $statusCode");
        } else {
          print("[!] Serveur inaccessible ou timeout.");
        }
        break;

      // ── TESTS ────────────────────────────────────────────────────────────
      case "Connexion":
        if (target == null || target.isEmpty) { print('[!] Cible manquante.'); break; }
        step(0.1, "Validation de l\'IP...");
        final connParts = target.split(':');
        final connIp  = connParts[0].trim();
        final connPwd = connParts.length > 1 ? connParts.sublist(1).join(':').trim() : "";
        if (!_isValidIP(connIp)) { print('[!] Adresse IP invalide : $connIp'); break; }
        if (connPwd.isEmpty) { print('[>] ⚠️ Aucun mot de passe fourni — tentative anonyme.'); }
        final connector = DeviceConnector(targetIp: connIp, password: connPwd);
        step(0.3, "Scan des ports ouverts...");
        final openPorts = await connector.scanOpenPorts();
        if (openPorts.isEmpty) {
          print('[!] Aucun port ouvert détecté.');
        } else {
          step(0.6, "Tentatives de connexion...");
          await connector.tryConnections(openPorts);
        }
        break;

      case "Password Crack":
        if (target == null || target.isEmpty) { print('[!] Hash ou mot de passe manquant.'); break; }
        step(0.2, "Analyse du hash...");
        final parts = target.split(':');
        final hashInput  = parts[0].trim();
        final wordlistPath = parts.length > 1 ? parts[1].trim() : null;
        final wordlist = wordlistPath != null
            ? await _loadWordlist(wordlistPath)
            : ["password", "123456", "admin", "letmein", "qwerty", target];
        step(0.4, "Crackage en cours...");
        final cracker = JohnDart(hashList: [hashInput], wordlist: wordlist);
        await cracker.runCracker();
        break;

      case "Password Calculator":
        if (target == null || target.isEmpty) { print('[!] Mot de passe manquant.'); break; }
        final scanner = PasswordScannerModule();
        String pwdToAnalyze = target;

        step(0.2, "Préparation de l'analyse...");
        if (target.trim().toLowerCase() == "generate") {
          step(0.4, "Génération d'un mot de passe robuste...");
          pwdToAnalyze = scanner.generateRobustPassword(16);
          print("🔑 Mot de passe généré : $pwdToAnalyze");
        }

        step(0.7, "Calcul de l'entropie...");
        final analysis = scanner.evaluatePassword(pwdToAnalyze);

        print("Longueur          : ${pwdToAnalyze.length} caractères");
        print("Entropie          : ${analysis.entropy.toStringAsFixed(2)} bits");
        print("Temps de crackage : ${scanner.formatCrackTime(analysis.crackTimeSeconds)}");

        switch (analysis.verdict) {
          case "FORT":
            print("[~] ✅ Verdict : ${analysis.verdict}");
            break;
          case "MOYEN":
            print("[>] ⚠️ Verdict : ${analysis.verdict}");
            break;
          default:
            print("[!] Verdict : ${analysis.verdict}");
        }
        break;

      default:
        print('[!] Module "${ module.name }" non reconnu.');
    }
  }


  // Chargement d'une wordlist depuis un fichier
  Future<List<String>> _loadWordlist(String path) async {
    // ... (Inchangé)
    try {
      final file = File(path);
      if (!await file.exists()) {
        print('[!] Wordlist introuvable : $path');
        return ["password", "123456", "admin"];
      }
      final lines = await file.readAsLines();
      return lines.where((l) => l.trim().isNotEmpty).toList();
    } catch (e) {
      print('[!] Erreur chargement wordlist : $e');
      return ["password", "123456", "admin"];
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFF101010)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  // Sidebar
                  SizedBox(width: 260, child: _buildSidebar()),
                  // Contenu principal
                  Expanded(child: _buildMainContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header (Horloge + Chronomètre de session ajoutés) ────────────────────
  Widget _buildHeader() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: kDarkGray.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(color: kCyanAccent.withOpacity(0.3), width: 2.0),
          left: BorderSide(color: kCyanAccent.withOpacity(0.3), width: 1.5),
          right: BorderSide(color: kCyanAccent.withOpacity(0.3), width: 1.5),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo et statut système
            Row(
              children: [
                // Simulateur de badge d'état
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent,
                    boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.7), blurRadius: 10)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "SYSTEM ACTIVE // STATUS: OK",
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
            // Titre principal style Terminal — dynamique selon le module sélectionné
            Text(
              _selectedModule != null
                  ? "WATCH_FOX V2.0 // ${_selectedModule!.name.toUpperCase()}"
                  : "WATCH_FOX V2.0",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kCyanAccent,
                letterSpacing: 5,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(color: kCyanAccent, blurRadius: 8),
                  Shadow(color: kBlueDark, blurRadius: 2),
                ],
              ),
            ),
            // ── Horloge live + Chronomètre de session ──────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Horloge (date + heure en temps réel)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatClock(_now),
                      style: const TextStyle(
                        color: kCyanAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 30, color: kCyanAccent.withOpacity(0.25)),
                const SizedBox(width: 16),
                // Chronomètre de session (temps passé sur l'application)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, color: Colors.greenAccent.withOpacity(0.8), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(_elapsed),
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "SESSION UPTIME",
                      style: TextStyle(
                        color: Colors.greenAccent.withOpacity(0.6),
                        fontSize: 9,
                        letterSpacing: 1,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    final categories = <String, List<ModuleDefinition>>{};
    for (final m in kModules) {
      categories.putIfAbsent(m.category, () => []).add(m);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        color: kDarkGray,
        border: Border.all(color: kCyanAccent.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: kCyanAccent.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1)
        ]
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: categories.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text(
                  "// CATEGORY: ${entry.key.toUpperCase()}",
                  style: TextStyle(
                    color: kCyanAccent,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              ...entry.value.map((m) => _buildModuleTile(m)).toList(),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModuleTile(ModuleDefinition module) {
    final isSelected = _selectedModule?.name == module.name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? kCyanAccent.withOpacity(0.15) : Colors.transparent,
          // Correction : Utilisation de Border.all
          border: Border.all(
            color: isSelected ? kCyanAccent : kDarkGray.withOpacity(0.5),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: InkWell(
          onTap: () => _selectModule(module),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Text(module.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    module.name,
                    style: TextStyle(
                      color: isSelected ? kCyanAccent : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (!module.requiresTarget)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      "LOCAL",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 9,
                        letterSpacing: 1,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Contenu principal ─────────────────────────────────────────────────────
  Widget _buildMainContent() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkGray,
        border: Border.all(color: kCyanAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: kCyanAccent.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2)
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedModule == null)
            _buildWelcomeHint()
          else if (_selectedModule!.requiresTarget)
            _buildTargetInput()
          else
            _buildLocalModuleBanner(),

          const SizedBox(height: 15),

          if (_progress != null) _buildProgressBar(),

          if (_progress != null) const SizedBox(height: 10),

          Expanded(child: _buildConsole()),
        ],
      ),
    );
  }

  // ── Barre de progression ──────────────────────────────────────────────────
  Widget _buildProgressBar() {
    final pct = ((_progress ?? 0.0) * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "STATUS: $_progressLabel",
              style: const TextStyle(color: kBlueDark, fontSize: 11, fontFamily: 'monospace'),
            ),
            Text(
              "$pct%",
              style: const TextStyle(
                color: kCyanAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            backgroundColor: kCyanAccent.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(kCyanAccent),
          ),
        ),
      ],
    );
  }

  // ── Widgets secondaires (Inchangés, car corrects) ────────────────────────
  Widget _buildWelcomeHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: kCyanAccent.withOpacity(0.3)),
        color: kDeepBlack,
        borderRadius: BorderRadius.circular(6)
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: kCyanAccent.withOpacity(0.7), size: 16),
          const SizedBox(width: 10),
          Text(
            ">> SELECT MODULE: Please select a module from the sidebar to begin the analysis protocol.",
            style: TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalModuleBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6)
      ),
      child: Row(
        children: [
          Text(_selectedModule!.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODULE ACTIVE: ${_selectedModule!.name}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'monospace',
                  ),
                ),
                const Text(
                  "Analysis of local machine resources. No target input required.",
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_selectedModule!.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              _selectedModule!.name,
              style: const TextStyle(
                color: kCyanAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            Text(
              _selectedModule!.category,
              style: const TextStyle(color: kBlueDark, fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: kDeepBlack,
            border: Border.all(color: kCyanAccent.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(4)
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: _selectedModule!.targetHint,
                      hintStyle: const TextStyle(color: Colors.white30),
                      // Correction: Simplification des bordures pour l'API Flutter
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: kCyanAccent, width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kCyanAccent, width: 2.0),
                      ),
                      prefixIcon: const Icon(Icons.chevron_right, color: kCyanAccent),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _launchModule(_selectedModule!, value.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _progress != null
                      ? null
                      : () {
                          final target = _targetController.text.trim();
                          if (target.isNotEmpty) {
                            _launchModule(_selectedModule!, target);
                          }
                        },
                  icon: _progress != null
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(_progress != null ? "CONNECTING..." : "EXECUTE PROTOCOL"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCyanAccent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: kCyanAccent.withOpacity(0.4),
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                    ),
                    // Style de forme pour le côté HUD
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: kCyanAccent, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Console (Style Terminal) ──────────────────────────────────────────
  Widget _buildConsole() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kDeepBlack,
        border: Border.all(color: kCyanAccent.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _consoleBuffer.length,
        itemBuilder: (context, i) {
          final line = _consoleBuffer[i];
          Color color = Colors.white;
          
          // Détermination de la couleur basée sur le préfixe
          if (line.startsWith("================")) {
            color = kCyanAccent.withOpacity(0.5);
          } else if (line.startsWith("[*]")) {
            color = kCyanAccent; 
          } else if (line.startsWith("[>]")) {
            color = kBlueDark;
          } else if (line.startsWith("[~]")) {
            color = Colors.greenAccent; 
          } else if (line.startsWith("[!]")) {
            color = Colors.redAccent; 
          } else if (line.startsWith('[?]')) {
            color = Colors.white38;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              line,
              style: TextStyle(
                color: color,
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isValidIP(String ip) {
    final regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!regex.hasMatch(ip)) return false;
    return ip.split('.').every((p) {
      final n = int.tryParse(p);
      return n != null && n >= 0 && n <= 255;
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _targetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Variable globale pour le mode debug verbose
bool verboseDebug = false;