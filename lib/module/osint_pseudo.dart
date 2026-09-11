import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UsernameOSINT {
  final String username;
  final List<String> found = [];
  final List<String> notFound = [];
  final Map<String, String> siteData = {};
  bool verbose = false;
  bool saveToFile = false;
  String outputFormat = "text"; // Options: text, json, csv

  UsernameOSINT(String target) : username = target.toLowerCase().replaceAll('@', '').trim();

  Future<void> checkSite(String siteName, String urlTemplate, List<String> notFoundTexts, {Map<String, String>? headers}) async {
    final url = urlTemplate.replaceAll('{username}', username);
    try {
      final request = http.Request('GET', Uri.parse(url));
      if (headers != null) {
        request.headers.addAll(headers);
      }
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);
      
      bool isFound = response.statusCode == 200;
      if (isFound) {
        for (var text in notFoundTexts) {
          if (response.body.toLowerCase().contains(text.toLowerCase())) {
            isFound = false;
            break;
          }
        }
      }

      if (isFound) {
        if (verbose) print("[✓] $siteName trouvé: $url");
        found.add(url);
        siteData[siteName] = url;
      } else {
        notFound.add(siteName);
        if (verbose) print("[✗] $siteName non trouvé");
      }
    } catch (e) {
      if (verbose) print("[!] Erreur sur $siteName: ${e.toString()}");
    }
  }

  Future<void> runScan() async {
    print("Recherche du nom d'utilisateur: $username");
    print("=====================================");
    
    // Réseaux sociaux
    await checkSite("Twitter", "https://twitter.com/{username}", ["suspended", "not found"]);
    await checkSite("Nitter (Twitter alternatif)", "https://nitter.net/{username}", ["not found"]);
    await checkSite("Instagram", "https://www.instagram.com/{username}", ["page doesn't exist"]);
    await checkSite("Facebook", "https://www.facebook.com/{username}", ["content that you requested"]);
    await checkSite("LinkedIn", "https://www.linkedin.com/in/{username}", ["404", "not found"]);
    await checkSite("TikTok", "https://www.tiktok.com/@{username}", ["Couldn't find this account"]);
    await checkSite("YouTube", "https://www.youtube.com/c/{username}", ["not found"]);
    await checkSite("YouTube (channel)", "https://www.youtube.com/channel/{username}", ["not found"]);
    await checkSite("Reddit", "https://www.reddit.com/user/{username}", ["not found"]);
    await checkSite("Pinterest", "https://www.pinterest.com/{username}", ["not found"]);
    await checkSite("Snapchat", "https://www.snapchat.com/add/{username}", ["404"]);
    await checkSite("Tumblr", "https://{username}.tumblr.com", ["not found"]);
    await checkSite("Flickr", "https://www.flickr.com/people/{username}/", ["not found"]);
    await checkSite("Vimeo", "https://vimeo.com/{username}", ["404"]);
    await checkSite("Medium", "https://medium.com/@{username}", ["not found"]);
    await checkSite("Telegram", "https://t.me/{username}", ["404"]);
    await checkSite("Discord", "https://discord.com/users/{username}", ["404"]);
    await checkSite("Twitch", "https://www.twitch.tv/{username}", ["not found"]);
    await checkSite("Steam", "https://steamcommunity.com/id/{username}", ["The specified profile"]);
    
    // Plateformes de développement
    await checkSite("GitHub", "https://github.com/{username}", ["404"]);
    await checkSite("GitLab", "https://gitlab.com/{username}", ["404"]);
    await checkSite("Bitbucket", "https://bitbucket.org/{username}/", ["not found"]);
    await checkSite("Stack Overflow", "https://stackoverflow.com/users/{username}", ["not found"]);
    await checkSite("Dev.to", "https://dev.to/{username}", ["not found"]);
    await checkSite("HackerNews", "https://news.ycombinator.com/user?id={username}", ["not found"]);
    await checkSite("CodePen", "https://codepen.io/{username}", ["not found"]);
    await checkSite("JSFiddle", "https://jsfiddle.net/user/{username}", ["not found"]);
    await checkSite("Replit", "https://replit.com/@{username}", ["not found"]);
    
    // Forums et communautés
    await checkSite("9GAG", "https://9gag.com/u/{username}", ["404"]);
    await checkSite("Quora", "https://www.quora.com/profile/{username}", ["not found"]);
    await checkSite("Disqus", "https://disqus.com/by/{username}/", ["not found"]);
    await checkSite("Mastodon", "https://mastodon.social/@{username}", ["not found"]);
    await checkSite("Keybase", "https://keybase.io/{username}", ["not found"]);
    await checkSite("ProductHunt", "https://www.producthunt.com/@{username}", ["not found"]);
    
    // Autres plateformes
    await checkSite("SoundCloud", "https://soundcloud.com/{username}", ["not found"]);
    await checkSite("Spotify", "https://open.spotify.com/user/{username}", ["not found"]);
    await checkSite("Last.fm", "https://www.last.fm/user/{username}", ["not found"]);
    await checkSite("Behance", "https://www.behance.net/{username}", ["not found"]);
    await checkSite("Dribbble", "https://dribbble.com/{username}", ["not found"]);
    await checkSite("Foursquare", "https://foursquare.com/{username}", ["not found"]);
    await checkSite("TripAdvisor", "https://www.tripadvisor.com/members-{username}", ["not found"]);
    
    // Sites d'images
    await checkSite("Imgur", "https://imgur.com/user/{username}", ["not found"]);
    await checkSite("Giphy", "https://giphy.com/{username}", ["not found"]);
    
    // Sites de jeux
    await checkSite("Epic Games", "https://www.epicgames.com/account/{username}", ["not found"]);
    await checkSite("Roblox", "https://www.roblox.com/user.aspx?username={username}", ["not found"]);
    await checkSite("Minecraft", "https://crafatar.com/avatars/{username}", ["not found"]);
    
    // Sites de dating
    await checkSite("Tinder", "https://www.gotinder.com/@{username}", ["not found"]);
    await checkSite("OkCupid", "https://www.okcupid.com/profile/{username}", ["not found"]);
    
    // Autres
    await checkSite("WhatsApp", "https://wa.me/{username}", ["not found"]);
  }

  void printResults() {
    print("\n\nRÉSULTATS DE LA RECHERCHE POUR: $username");
    print("=====================================");
    print("Trouvés (${found.length}):");
    for (var site in siteData.entries) {
      print("- ${site.key}: ${site.value}");
    }
    
    print("\nNon trouvés (${notFound.length}):");
    for (var site in notFound) {
      print("- $site");
    }
    
    print("\nStatistiques:");
    print("- Total vérifié: ${found.length + notFound.length}");
    print("- Taux de réussite: ${(found.length / (found.length + notFound.length) * 100).toStringAsFixed(1)}%");
  }

  Future<void> saveResults() async {
    if (!saveToFile) return;
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = "osint_${username}_$timestamp";
    
    if (outputFormat == "json") {
      final file = File("$filename.json");
      final data = {
        "username": username,
        "timestamp": timestamp,
        "found": siteData,
        "notFound": notFound,
        "stats": {
          "total": found.length + notFound.length,
          "found": found.length,
          "successRate": found.length / (found.length + notFound.length) * 100
        }
      };
      await file.writeAsString(jsonEncode(data));
      print("\nRésultats sauvegardés dans $filename.json");
    } else if (outputFormat == "csv") {
      final file = File("$filename.csv");
      final buffer = StringBuffer();
      buffer.writeln("Plateforme,URL,Trouvé");
      
      for (var site in siteData.entries) {
        buffer.writeln("${site.key},${site.value},Oui");
      }
      
      for (var site in notFound) {
        buffer.writeln("$site,,Non");
      }
      
      await file.writeAsString(buffer.toString());
      print("\nRésultats sauvegardés dans $filename.csv");
    }
  }
}