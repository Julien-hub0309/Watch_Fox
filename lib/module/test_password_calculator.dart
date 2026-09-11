import 'package:flutter/material.dart';
import 'password_scanner_module.dart';

class PasswordCalculator extends StatefulWidget {
  const PasswordCalculator({super.key});

  @override
  State<PasswordCalculator> createState() => _PasswordCalculatorState();
}

class _PasswordCalculatorState extends State<PasswordCalculator> {
  final PasswordScannerModule _scanner = PasswordScannerModule();
  final TextEditingController _controller = TextEditingController();

  PasswordAnalysis? _result;
  bool _obscure = true;

  void _analyze(String value) {
    setState(() {
      _result = _scanner.evaluatePassword(value);
    });
  }

  void _generate() {
    final generated = _scanner.generateRobustPassword(16);
    _controller.text = generated;
    _analyze(generated);
  }

  Color _verdictColor(String verdict) {
    switch (verdict) {
      case "TRÈS FAIBLE":
        return Colors.red;
      case "MOYEN":
        return Colors.orange;
      case "FORT":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text("Password Calculator")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              obscureText: _obscure,
              onChanged: _analyze,
              decoration: InputDecoration(
                labelText: "Mot de passe",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.autorenew),
              label: const Text("Générer un mot de passe robuste"),
            ),
            const SizedBox(height: 24),
            if (result != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text("Verdict : ", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            result.verdict,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _verdictColor(result.verdict),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Entropie : ${result.entropy.toStringAsFixed(2)} bits"),
                      const SizedBox(height: 8),
                      Text(
                        "Temps de crackage estimé : ${_scanner.formatCrackTime(result.crackTimeSeconds)}",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}