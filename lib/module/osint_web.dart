import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class JustradamusModule {
  String target;
  
  JustradamusModule(this.target);
  
  String saveFinding(String type, Map<String, dynamic> data) {
    // Implémentation à adapter selon votre système
    return "path/to/report.json";
  }
  
  void displayResults(String title, Map<String, dynamic> info) {
    // Implémentation à adapter selon votre système d'affichage
    print("=== $title ===");
    info.forEach((key, value) {
      print("$key: $value");
    });
  }
}

class WebScanner extends JustradamusModule {
  WebScanner(String target) : super(target);
  
  Future<void> scanInfra() async {
    print("[🌐] Analyse d'infrastructure pour : $target");
    Map<String, dynamic> results = {};
    
    try {
      // Résolution IP
      String ip = await InternetAddress.lookup(target).then((addresses) => addresses.first.address);
      results["IP"] = ip;
      
      try {
        // Requête pour obtenir les informations de géolocalisation
        final response = await http.get(
          Uri.parse('http://ip-api.com/json/$ip'),
          headers: {'User-Agent': 'Mozilla/5.0'},
        ).timeout(Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final geo = jsonDecode(response.body);
          if (geo["status"] == "success") {
            results["Localisation"] = "${geo['city']}, ${geo['country']}";
            results["ISP"] = geo["isp"];
            results["Organisation"] = geo["org"];
          } else {
            results["Localisation"] = "Erreur API Géo";
          }
        } else {
          results["Localisation"] = "Erreur API Géo";
        }
      } catch (e) {
        results["Localisation"] = "Erreur API Géo";
      }

      // Scan de ports
      List<int> openPorts = [];
      List<int> portsToCheck = [21, 22, 80, 443, 8080];
      
      for (int port in portsToCheck) {
        try {
          final socket = await Socket.connect(ip, port, timeout: Duration(milliseconds: 500));
          openPorts.add(port);
          socket.destroy();
        } catch (e) {
          // Port fermé, on continue
        }
      }
      
      // Convertir la liste en string pour l'affichage
      results["Ports_Ouverts"] = openPorts.isNotEmpty ? openPorts.join(", ") : "Aucun";

      saveFinding("Web_Infra", results);
      displayResults("Infrastructure Web", results);
      
    } on SocketException catch (e) {
      print("[!] Impossible de résoudre le domaine : $target");
    } catch (e) {
      print("[!] Erreur Web : $e");
    }
  }
}