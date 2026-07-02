// module/osint_person.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;

class PersonOSINT {
  final String nom;
  final String prenom;
  final String age;
  final String torProxy = 'socks5://127.0.0.1:9050';
  bool verbose = false;
  
  // Liste de sites à rechercher
  final List<String> searchSites = [
    "https://www.facebook.com/public/",
    "https://www.linkedin.com/pub/dir/",
    "https://twitter.com/search?q=",
    "https://www.google.com/search?q=",
    "https://duckduckgo.com/html/?q="
  ];
  
  PersonOSINT(this.nom, this.prenom, this.age);
  
  Future<void> runScan() async {
    if (verbose) print("[*] Initialisation de la recherche OSINT par personne...");
    
    try {
      if (verbose) print("[*] Configuration du proxy Tor...");
      
      // Construire la requête de recherche
      String query = "$prenom $nom $age";
      if (verbose) print("[>] Requête de recherche : $query");
      
      int siteCount = 0;
      int totalSites = searchSites.length;
      
      for (String site in searchSites) {
        siteCount++;
        if (verbose) print("[*] Recherche sur ${site.split('/')[2]} ($siteCount/$totalSites)...");
        
        try {
          String searchUrl = "$site$query";
          if (verbose) print("[>] URL de recherche : $searchUrl");
          
          // Effectuer la requête via Tor
          final client = HttpClient();
          
          // Configuration du proxy Tor
          client.findProxy = (url) {
            return "PROXY $torProxy";
          };
          
          final request = await client.getUrl(Uri.parse(searchUrl));
          final response = await request.close();
          
          // Analyser les résultats
          String responseBody = await response.transform(utf8.decoder).join();
          var document = html.parse(responseBody);
          var links = document.querySelectorAll('a[href]');
          
          int matchesFound = 0;
          
          // Vérifier si au moins deux des informations apparaissent sur la page
          for (var link in links) {
            String linkText = link.text?.toLowerCase() ?? '';
            String href = link.attributes['href'] ?? '';
            
            bool nomMatch = nom.toLowerCase().split(' ').any((n) => linkText.contains(n));
            bool prenomMatch = prenom.toLowerCase().split(' ').any((p) => linkText.contains(p));
            bool ageMatch = linkText.contains(age);
            
            if ((nomMatch && prenomMatch) || (nomMatch && ageMatch) || (prenomMatch && ageMatch)) {
              matchesFound++;
              if (matchesFound <= 5) { // Limiter l'affichage à 5 résultats par site
                print("[~] Résultat trouvé sur ${site.split('/')[2]}:");
                print("   URL: $href");
                print("   Contexte: ${linkText.length > 100 ? linkText.substring(0, 100) + '...' : linkText}");
                print("");
              }
            }
          }
          
          if (matchesFound == 0) {
            if (verbose) print("[~] Aucune correspondance trouvée sur ${site.split('/')[2]}");
          } else {
            print("[~] $matchesFound correspondance(s) trouvée(s) sur ${site.split('/')[2]}");
          }
          
          client.close();
          
          // Pause entre les requêtes pour éviter le blocage
          await Future.delayed(Duration(seconds: 2));
          
        } catch (e) {
          print("[!] Erreur lors de la recherche sur ${site.split('/')[2]}: $e");
          continue;
        }
      }
      
      print("[*] Recherche terminée.");
      
    } catch (e) {
      print("[!] Erreur générale lors de la recherche: $e");
    }
  }
}