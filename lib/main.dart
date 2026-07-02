import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
// Core
import 'core/base.dart';
import 'core/config.dart';
// Modules
import 'module/diagnostique_hardware.dart';
import 'module/diagnostique_reseaux.dart';
import 'module/diagnostique_software.dart';
import 'module/osint_mail.dart';
import 'module/osint_phone.dart';
import 'module/osint_pseudo.dart';
import 'module/osint_reseaux.dart';
import 'module/osint_web.dart';
import 'module/sacnner_file.dart';
import 'module/scanner_url.dart';
import 'module/test_connexion.dart';
import 'module/test_password.dart';

void main() => runApp(const WatchFoxApp());

// ─── Couleurs globales ────────────────────────────────────────────────────────
const kPurple      = Color(0xFFAB47BC);
const kPurpleLight = Color(0xFFCE93D8);
const kPurpleDark  = Color(0xFF6A1B9A);
const kPurpleFaint = Color(0x1AAB47BC);

// Signatures virales connues (exemple)
const Set<String> virusSignatures = {
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // hash vide
  // Ajoutez d'autres hash malveillants ici
};

class WatchFoxApp extends StatelessWidget {
  const WatchFoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
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
  ModuleDefinition(name: "Phone OSINT",   icon: "📱", category: "OSINT",        targetHint: "Numéro de téléphone (+33...)"),
  ModuleDefinition(name: "Pseudo OSINT",  icon: "👤", category: "OSINT",        targetHint: "Pseudonyme / username"),
  ModuleDefinition(name: "Réseaux OSINT", icon: "🌐", category: "OSINT",        targetHint: "URL / domaine / IP"),
  ModuleDefinition(name: "Web OSINT",     icon: "🔎", category: "OSINT",        targetHint: "URL ou domaine"),
  ModuleDefinition(name: "File Scanner",  icon: "📂", category: "Scanner",      targetHint: "Chemin du fichier"),
  ModuleDefinition(name: "URL Scanner",   icon: "🔗", category: "Scanner",      targetHint: "URL à analyser"),
  ModuleDefinition(name: "Connexion",     icon: "🔌", category: "Test",         targetHint: "IP:mot_de_passe  (ex: 192.168.1.1:admin)"),
  ModuleDefinition(name: "Password Test", icon: "🔐", category: "Test",         targetHint: "Mot de passe à tester"),
];

// ─── Home ─────────────────────────────────────────────────────────────────────
class WatchFoxHome extends StatefulWidget {
  const WatchFoxHome({super.key});

  @override
  State<WatchFoxHome> createState() => _WatchFoxHomeState();
}

class _WatchFoxHomeState extends State<WatchFoxHome> {
  final TextEditingController _targetController = TextEditingController();
  final List<String> _consoleBuffer = ["[>] SYSTÈME PRÊT..."];
  final ScrollController _scrollController = ScrollController();

  ModuleDefinition? _selectedModule;

  // Barre de progression : null = cachée, 0.0-1.0 = en cours, 1.0 = terminé
  double? _progress;
  String  _progressLabel = "";

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

  // ── Interception de print() → console Flutter ─────────────────────────────
  void _log(String line) {
    if (!mounted) return;
    
    // Normalisation des emojis/préfixes vers les codes couleur de la console
    String mapped = line;
    
    // Si la ligne commence déjà par un préfixe standard, on la garde
    if (line.startsWith('[*]') || line.startsWith('[>]') || 
        line.startsWith('[~]') || line.startsWith('[!]')) {
      mapped = line;
    } 
    // Sinon on détecte les emojis et on convertit
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
    }
    
    setState(() => _consoleBuffer.add(mapped));
    _scrollToBottom();
  }

  // Lance l'exécution d'un module et capture sa sortie via Zone
  Future<void> _launchModule(ModuleDefinition module, String? target) async {
    setState(() {
      _consoleBuffer.add("");
      _consoleBuffer.add("══════════════════════════════════════");
      _consoleBuffer.add("[*] MODULE : ${module.name}");
      _consoleBuffer.add(target != null
          ? "[>] CIBLE  : $target"
          : "[>] CIBLE  : machine locale");
      _consoleBuffer.add("══════════════════════════════════════");
      _consoleBuffer.add("[~] Initialisation...");
      _progress = 0.05;
      _progressLabel = "Démarrage...";
    });
    _scrollToBottom();

    try {
      // Zone personnalisée : intercepte tous les print() des modules
      await runZonedGuarded(
        () => _runModuleLogic(module, target),
        (error, stack) {
          _log('[!] Erreur : $error');
          if (verboseDebug) {
            _log('[!] Stack : $stack');
          }
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => _log(line),
        ),
      );
    } catch (e) {
      _log('[!] Erreur inattendue : $e');
    }

    setState(() {
      _progress = 1.0;
      _progressLabel = "Terminé.";
    });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _progress = null);
  }

  // Contient le vrai switch vers chaque module
  Future<void> _runModuleLogic(ModuleDefinition module, String? target) async {
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

      case "Phone OSINT":
        if (target == null || target.isEmpty) { print('[!] Cible manquante.'); break; }
        step(0.2, "Analyse du numéro...");
        final phone = PhonyNode(target);
        phone.verbose = true;
        await phone.runExtendedScan();
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
        // Format attendu : "192.168.1.1:motdepasse" ou juste "192.168.1.1"
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

      case "Password Test":
        if (target == null || target.isEmpty) { print('[!] Hash ou mot de passe manquant.'); break; }
        step(0.2, "Analyse du hash...");
        // target = "hash:wordlist_path" ou juste un hash à tester avec une wordlist par défaut
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

      default:
        print('[!] Module "${ module.name }" non reconnu.');
    }
  }

  // Chargement d'une wordlist depuis un fichier
  Future<List<String>> _loadWordlist(String path) async {
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
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  // Sidebar
                  SizedBox(width: 240, child: _buildSidebar()),
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

  // ── Header (titre centré, violet) ─────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 70,
      color: Colors.black.withOpacity(0.85),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Logo calé à gauche
          Positioned(
            left: 20,
            child: Image.asset('assets/logo.png', height: 44),
          ),
          // Titre centré
          const Text(
            "WATCH_FOX V2",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kPurple,
              letterSpacing: 4,
              shadows: [
                Shadow(color: kPurpleDark, blurRadius: 12),
                Shadow(color: kPurple,     blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    final categories = <String, List<ModuleDefinition>>{};
    for (final m in kModules) {
      categories.putIfAbsent(m.category, () => []).add(m);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        border: Border.all(color: kPurple.withOpacity(0.4)),
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
                  "── ${entry.key.toUpperCase()} ──",
                  style: TextStyle(
                    color: kPurpleLight.withOpacity(0.6),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              ...entry.value.map((m) => _buildModuleTile(m)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModuleTile(ModuleDefinition module) {
    final isSelected = _selectedModule?.name == module.name;

    return InkWell(
      onTap: () => _selectModule(module),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? kPurpleFaint : Colors.transparent,
          border: Border.all(
            color: isSelected ? kPurple : kPurple.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Text(module.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                module.name,
                style: TextStyle(
                  color: isSelected ? kPurpleLight : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (!module.requiresTarget)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Text(
                  "LOCAL",
                  style: TextStyle(
                    color: Colors.green.withOpacity(0.7),
                    fontSize: 8,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
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
        color: Colors.black.withOpacity(0.75),
        border: Border.all(color: kPurple.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone haute : accueil / saisie cible / banner local
          if (_selectedModule == null)
            _buildWelcomeHint()
          else if (_selectedModule!.requiresTarget)
            _buildTargetInput()
          else
            _buildLocalModuleBanner(),

          const SizedBox(height: 10),

          // ── Barre de progression ─────────────────────────────────────────
          if (_progress != null) _buildProgressBar(),

          if (_progress != null) const SizedBox(height: 10),

          // Console
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
              _progressLabel,
              style: const TextStyle(color: kPurpleLight, fontSize: 11),
            ),
            Text(
              "$pct%",
              style: const TextStyle(
                color: kPurple,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
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
            backgroundColor: kPurple.withOpacity(0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(kPurple),
          ),
        ),
      ],
    );
  }

  // ── Widgets secondaires ───────────────────────────────────────────────────
  Widget _buildWelcomeHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: kPurple.withOpacity(0.3)),
        color: kPurpleFaint,
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_back, color: kPurple.withOpacity(0.7), size: 16),
          const SizedBox(width: 10),
          const Text(
            "Sélectionnez un module dans la barre latérale pour commencer.",
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalModuleBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.withOpacity(0.4)),
        color: Colors.green.withOpacity(0.05),
      ),
      child: Row(
        children: [
          Text(_selectedModule!.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedModule!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Analyse de la machine locale — aucune cible requise.",
                  style: TextStyle(color: Colors.white38, fontSize: 11),
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
            Text(_selectedModule!.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              _selectedModule!.name,
              style: const TextStyle(
                color: kPurpleLight,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              _selectedModule!.category,
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _targetController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontFamily: 'Courier'),
                decoration: InputDecoration(
                  hintText: _selectedModule!.targetHint,
                  hintStyle: const TextStyle(color: Colors.white30),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: kPurple),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: kPurpleLight, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.chevron_right, color: kPurple),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10,
                  ),
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
                  ? null // désactivé pendant l'exécution
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
              label: Text(_progress != null ? "EN COURS" : "LANCER"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: kPurpleDark,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                shape: const RoundedRectangleBorder(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Console ───────────────────────────────────────────────────────────────
  Widget _buildConsole() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.black,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _consoleBuffer.length,
        itemBuilder: (context, i) {
          final line = _consoleBuffer[i];
          Color color = Colors.orange;
          if (line.startsWith("══"))       color = kPurple.withOpacity(0.5);
          else if (line.startsWith("[*]")) color = kPurpleLight;
          else if (line.startsWith("[>]")) color = Colors.white70;
          else if (line.startsWith("[~]")) color = Colors.green;
          else if (line.startsWith("[!]")) color = Colors.red;

          return Text(
            line,
            style: TextStyle(
              color: color,
              fontFamily: 'Courier',
              fontSize: 12,
              height: 1.5,
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
    _targetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Variable globale pour le mode debug verbose
bool verboseDebug = false;