import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

abstract class JustradamusModule {
  String target;
  String? proxy;
  bool verbose = false;
  bool saveToFile = false;
  String outputFormat = "text"; // Options: text, json, csv
  Map<String, dynamic> findings = {};
  
  JustradamusModule(this.target, [this.proxy]);
  
  Future<String> saveFinding(String type, Map<String, dynamic> data) async {
    if (!saveToFile) return "";
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = "${type}_${target}_${timestamp}";
    
    if (outputFormat == "json") {
      final file = File("${filename}.json");
      final allData = {
        "target": target,
        "timestamp": timestamp,
        "type": type,
        "data": data,
        "findings": findings
      };
      await file.writeAsString(jsonEncode(allData));
      return file.path;
    } else if (outputFormat == "csv") {
      final file = File("${filename}.csv");
      final buffer = StringBuffer();
      buffer.writeln("Propriété,Valeur");
      
      data.forEach((key, value) {
        buffer.writeln("${key},${value}");
      });
      
      await file.writeAsString(buffer.toString());
      return file.path;
    }
    
    return "";
  }
  
  void displayResults(String title, Map<String, dynamic> info) {
    print("\n=== ${title} ===");
    info.forEach((key, value) {
      print("${key}: ${value}");
    });
    print("==================");
  }
}

class EmailOSINT extends JustradamusModule {
  late String email;
  late String username;
  late String domain;
  List<String> found = [];
  List<String> notFound = [];
  List<String> errors = [];
  Map<String, dynamic> emailData = {};
  
  // Constantes à adapter selon votre configuration
  static const Duration TIMEOUT = Duration(seconds: 30);
  static const List<String> USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0'
  ];

  EmailOSINT(String target, [String? proxy]) : super(target, proxy) {
    email = target.toLowerCase().trim();
    username = email.contains('@') ? email.split('@')[0] : email;
    domain = email.contains('@') ? email.split('@')[1] : '';
  }

  Future<http.Response?> _get(String url, {Map<String, String>? customHeaders}) async {
    try {
      Map<String, String> headers = customHeaders ?? _getRandomHeader();
      
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);
      
      final streamedResponse = await request.send().timeout(TIMEOUT);
      final response = await http.Response.fromStream(streamedResponse);
      
      return response;
    } catch (e) {
      if (verbose) print("Erreur lors de la requête vers $url: $e");
      return null;
    }
  }

  Map<String, String> _getRandomHeader() {
    final random = Random();
    final userAgent = USER_AGENTS[random.nextInt(USER_AGENTS.length)];
    
    return {
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
    };
  }

  void _printFound(String source, [String info = ""]) {
    print('✓ $source $info');
    found.add("$source: $info");
  }

  void _printNotFound(String source) {
    print('✗ $source');
    notFound.add(source);
  }

  void _printError(String source) {
    print('! $source: Timeout/Erreur');
    errors.add(source);
  }

  void _printSection(String title) {
    print('\n★ $title ★');
  }

  Future<void> checkEmailValidity() async {
    try {
      // Vérification de la validité syntaxique
      final isValid = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\$').hasMatch(email);
      
      Map<String, dynamic> validityData = {
        "email": email,
        "syntax_valid": isValid,
        "username": username,
        "domain": domain
      };
      
      if (isValid) {
        // Vérification du domaine
        try {
          final ipAddresses = await InternetAddress.lookup(domain)
              .then((list) => list.map((a) => a.address).toList());
          validityData["domain_ips"] = ipAddresses;
        } catch (e) {
          validityData["domain_resolves"] = false;
        }
        
        // Vérification des enregistrements MX
        try {
          final mxResp = await http.get(Uri.parse(
              'https://dns.google/resolve?name=$domain&type=MX'));
          if (mxResp.statusCode == 200) {
            final mxData = jsonDecode(mxResp.body);
            final mxHosts = (mxData['Answer'] as List<dynamic>? ?? [])
                .map((r) => r['data'].toString()).toList();
            validityData["mx_records"] = mxHosts;
          }
        } catch (e) {
          validityData["mx_records"] = [];
        }
        
        // Vérification des enregistrements SPF/DKIM/DMARC
        try {
          final txtResp = await http.get(Uri.parse(
              'https://dns.google/resolve?name=$domain&type=TXT'));
          if (txtResp.statusCode == 200) {
            final txtData = jsonDecode(txtResp.body);
            final txtRecords = (txtData['Answer'] as List<dynamic>? ?? [])
                .map((r) => r['data'].toString()).toList();
            validityData["txt_records"] = txtRecords;
          }
        } catch (e) {
          validityData["txt_records"] = [];
        }
      }
      
      emailData["validity"] = validityData;
      _printFound("Validité e-mail", isValid ? "Valide" : "Invalide");
    } catch (e) {
      _printError("Validité e-mail");
    }
  }

  Future<void> checkHibpWeb() async {
    final response = await _get('https://haveibeenpwned.com/unifiedsearch/${Uri.encodeComponent(email)}');
    
    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final breaches = (data['Breaches'] as List<dynamic>?)
            ?.map((b) => {
                  'name': b['Name'] as String,
                  'date': b['BreachDate'] as String,
                  'dataClasses': b['DataClasses'] as List<dynamic>
                })
            .toList() ?? [];
            
        if (breaches.isNotEmpty) {
          _printFound("Have I Been Pwned", "${breaches.length} fuites: ${breaches.take(3).map((b) => b['name']).join(', ')}");
          emailData["hibp"] = {"found": true, "breaches": breaches};
          return;
        }
      } catch (e) {
        // Ignorer les erreurs de parsing
      }
    }
    _printNotFound("Have I Been Pwned");
    emailData["hibp"] = {"found": false};
  }

  Future<void> checkLeakcheck() async {
    final response = await _get('https://leakcheck.io/api/public?check=${Uri.encodeComponent(email)}');
    
    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data['found'] == true) {
          _printFound("LeakCheck", "${data['count'] ?? 0} fuites");
          emailData["leakcheck"] = {"found": true, "count": data['count']};
          return;
        }
      } catch (e) {
        // Ignorer les erreurs de parsing
      }
    }
    _printNotFound("LeakCheck");
    emailData["leakcheck"] = {"found": false};
  }

  Future<void> checkPsbdmp() async {
    final response = await _get('https://psbdmp.ws/api/v3/search/${Uri.encodeComponent(email)}');
    
    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
if ((data['count'] ?? 0) > 0) {
          _printFound("Psbdmp.ws", "${data['count']} dumps");
          emailData["psbdmp"] = {"found": true, "count": data['count']};
          return;
        }
      } catch (e) {
        // Ignorer les erreurs de parsing
      }
    }
    _printNotFound("Psbdmp.ws");
    emailData["psbdmp"] = {"found": false};
  }

  Future<void> checkBreachdirectory() async {
    final response = await _get('https://breachdirectory.org/api.php?query=${Uri.encodeComponent(email)}');
    
    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data['found'] == 'true') {
          _printFound("BreachDirectory", "${data['count'] ?? 0} résultats");
          emailData["breachdirectory"] = {"found": true, "count": data['count']};
          return;
        }
      } catch (e) {
        // Ignorer les erreurs de parsing
      }
    }
    _printNotFound("BreachDirectory");
    emailData["breachdirectory"] = {"found": false};
  }

  Future<void> checkEmailrep() async {
    final response = await _get('https://emailrep.io/${Uri.encodeComponent(email)}');
    
    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final rep = data['reputation'] ?? 'unknown';
        final susp = data['suspicious'] == true ? " [SUSPICIOUS]" : "";
        _printFound("EmailRep", "Rep: $rep$susp");
        emailData["emailrep"] = {
          "reputation": rep,
          "suspicious": data['suspicious'],
          "details": data
        };
        return;
      } catch (e) {
        // Ignorer les erreurs de parsing
      }
    }
    _printNotFound("EmailRep");
    emailData["emailrep"] = {"found": false};
  }

  Future<void> checkGravatar() async {
    final bytes = utf8.encode(email.toLowerCase().trim());
    final digest = md5.convert(bytes);
    final emailHash = digest.toString();
    
    final response = await _get('https://www.gravatar.com/avatar/$emailHash?d=404');
    
    if (response != null && response.statusCode != 404) {
      _printFound("Gravatar", "https://www.gravatar.com/$emailHash");
      emailData["gravatar"] = {"found": true, "hash": emailHash, "url": "https://www.gravatar.com/$emailHash"};
      return;
    }
    _printNotFound("Gravatar");
    emailData["gravatar"] = {"found": false};
  }

  Future<void> checkDns() async {
    try {
      final dnsResp = await http.get(Uri.parse(
          'https://dns.google/resolve?name=$domain&type=MX'));
      final dnsData = jsonDecode(dnsResp.body);
      final mxHosts = (dnsData['Answer'] as List<dynamic>? ?? [])
          .map((r) => r['data'].toString()).toList();
      _printFound("DNS/MX", "Serveurs: ${mxHosts.take(2).join(', ')}");
      emailData["dns"] = {"mx_records": mxHosts};
    } catch (e) {
      _printNotFound("DNS/MX");
      emailData["dns"] = {"mx_records": []};
    }
  }

  Future<void> _checkSocial(String site, String url, List<String>? notFoundTexts) async {
    final response = await _get(url);
    
    if (response != null && response.statusCode == 200) {
      if (notFoundTexts != null) {
        final content = response.body.toLowerCase();
        for (final text in notFoundTexts) {
          if (content.contains(text.toLowerCase())) {
            _printNotFound(site);
            return;
          }
        }
      }
      _printFound(site, url);
      emailData[site.toLowerCase()] = {"found": true, "url": url};
      return;
    }
    _printNotFound(site);
    emailData[site.toLowerCase()] = {"found": false};
  }

  Future<void> checkTwitter() async {
    final cleanUsername = username.replaceAll('.', '').replaceAll('_', '');
    await _checkSocial(
      "Twitter/X",
      "https://nitter.net/$cleanUsername",
      ["this user does not exist", "not found"]
    );
  }

  Future<void> checkReddit() async {
    await _checkSocial(
      "Reddit",
      "https://www.reddit.com/user/$username/about.json",
      ["not found"]
    );
  }

  Future<void> checkGithub() async {
    final ghUser = username.replaceAll('.', '-').replaceAll('_', '-');
    final response = await _get('https://api.github.com/users/$ghUser');
    
    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        _printFound("GitHub", "${data['html_url']} (${data['public_repos']} repos)");
        emailData["github"] = {
          "found": true,
          "url": data['html_url'],
          "public_repos": data['public_repos'],
          "name": data['name'],
          "bio": data['bio']
        };
        return;
      } catch (e) {
        // Ignorer les erreurs de parsing
      }
    }
    _printNotFound("GitHub");
    emailData["github"] = {"found": false};
  }

  Future<void> checkMedium() async {
    await _checkSocial(
      "Medium",
      "https://medium.com/@$username",
      ["not found", "404"]
    );
  }

  Future<void> checkSteam() async {
    await _checkSocial(
      "Steam",
      "https://steamcommunity.com/id/$username",
      ["the specified profile could not be found"]
    );
  }

  Future<void> checkOnlyfans() async {
    await _checkSocial(
      "OnlyFans",
      "https://onlyfans.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkFansly() async {
    await _checkSocial(
      "Fansly",
      "https://fansly.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkChaturbate() async {
    await _checkSocial(
      "Chaturbate",
      "https://chaturbate.com/$username/",
      ["not found", "404", "page not found"]
    );
  }

  Future<void> checkLinkedIn() async {
    await _checkSocial(
      "LinkedIn",
      "https://www.linkedin.com/in/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkFacebook() async {
    await _checkSocial(
      "Facebook",
      "https://www.facebook.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkInstagram() async {
    await _checkSocial(
      "Instagram",
      "https://www.instagram.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkTikTok() async {
    await _checkSocial(
      "TikTok",
      "https://www.tiktok.com/@$username",
      ["not found", "404"]
    );
  }

  Future<void> checkYouTube() async {
    await _checkSocial(
      "YouTube",
      "https://www.youtube.com/c/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkPinterest() async {
    await _checkSocial(
      "Pinterest",
      "https://www.pinterest.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkKeybase() async {
    await _checkSocial(
      "Keybase",
      "https://keybase.io/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkTelegram() async {
    await _checkSocial(
      "Telegram",
      "https://t.me/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkDiscord() async {
    await _checkSocial(
      "Discord",
      "https://discord.com/users/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkSpotify() async {
    await _checkSocial(
      "Spotify",
      "https://open.spotify.com/user/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkSoundCloud() async {
    await _checkSocial(
      "SoundCloud",
      "https://soundcloud.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkFlickr() async {
    await _checkSocial(
      "Flickr",
      "https://www.flickr.com/people/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkDeviantArt() async {
    await _checkSocial(
      "DeviantArt",
      "https://www.deviantart.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkBitbucket() async {
    await _checkSocial(
      "Bitbucket",
      "https://bitbucket.org/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkGitLab() async {
    await _checkSocial(
      "GitLab",
      "https://gitlab.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkStackOverflow() async {
    await _checkSocial(
      "StackOverflow",
      "https://stackoverflow.com/users/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkHackerNews() async {
    await _checkSocial(
      "HackerNews",
      "https://news.ycombinator.com/user?id=$username",
      ["not found", "404"]
    );
  }

  Future<void> checkDevTo() async {
    await _checkSocial(
      "Dev.to",
      "https://dev.to/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkCodePen() async {
    await _checkSocial(
      "CodePen",
      "https://codepen.io/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkBehance() async {
    await _checkSocial(
      "Behance",
      "https://www.behance.net/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkDribbble() async {
    await _checkSocial(
      "Dribbble",
      "https://dribbble.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkFoursquare() async {
    await _checkSocial(
      "Foursquare",
      "https://foursquare.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkTripAdvisor() async {
    await _checkSocial(
      "TripAdvisor",
      "https://www.tripadvisor.com/members-$username",
      ["not found", "404"]
    );
  }

  Future<void> checkImgur() async {
    await _checkSocial(
      "Imgur",
      "https://imgur.com/user/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkQuora() async {
    await _checkSocial(
      "Quora",
      "https://www.quora.com/profile/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkProductHunt() async {
    await _checkSocial(
      "ProductHunt",
      "https://www.producthunt.com/@$username",
      ["not found", "404"]
    );
  }

  Future<void> checkMastodon() async {
    await _checkSocial(
      "Mastodon",
      "https://mastodon.social/@$username",
      ["not found", "404"]
    );
  }

  Future<void> checkDisqus() async {
    await _checkSocial(
      "Disqus",
      "https://disqus.com/by/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkBadoo() async {
    await _checkSocial(
      "Badoo",
      "https://badoo.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkBumble() async {
    await _checkSocial(
      "Bumble",
      "https://bumble.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkOkCupid() async {
    await _checkSocial(
      "OkCupid",
      "https://www.okcupid.com/profile/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkTinder() async {
    await _checkSocial(
      "Tinder",
      "https://www.gotinder.com/@$username",
      ["not found", "404"]
    );
  }

  Future<void> checkMatch() async {
    await _checkSocial(
      "Match",
      "https://www.match.com/profile/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkPof() async {
    await _checkSocial(
      "PlentyOfFish",
      "https://www.pof.com/viewprofile.aspx?username=$username",
      ["not found", "404"]
    );
  }

  Future<void> checkMeetup() async {
    await _checkSocial(
      "Meetup",
      "https://www.meetup.com/members/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkFurAffinity() async {
    await _checkSocial(
      "FurAffinity",
      "https://www.furaffinity.net/user/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkEtsy() async {
    await _checkSocial(
      "Etsy",
      "https://www.etsy.com/people/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkEbay() async {
    await _checkSocial(
      "eBay",
      "https://www.ebay.com/usr/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkAmazon() async {
    await _checkSocial(
      "Amazon",
      "https://www.amazon.com/gp/pdp/profile/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkRedditUserHistory() async {
    final response = await _get('https://www.reddit.com/user/$username/comments.json');
    
    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['children'].isNotEmpty) {
          _printFound("Reddit History", "Found ${data['data']['children'].length} recent comments");
          emailData["reddit_history"] = {"found": true, "comment_count": data['data']['children'].length};
          return;
        }
      } catch (e) {
        // Ignorer les erreurs de parsing
      }
    }
    _printNotFound("Reddit History");
    emailData["reddit_history"] = {"found": false};
  }

  Future<void> checkPastebin() async {
    final response = await _get('https://pastebin.com/u/$username');
    
    if (response != null && response.statusCode == 200) {
      if (response.body.contains("No pastes found")) {
        _printNotFound("Pastebin");
        emailData["pastebin"] = {"found": false};
      } else {
        _printFound("Pastebin", "https://pastebin.com/u/$username");
        emailData["pastebin"] = {"found": true, "url": "https://pastebin.com/u/$username"};
      }
      return;
    }
    _printNotFound("Pastebin");
    emailData["pastebin"] = {"found": false};
  }

  Future<void> checkGumtree() async {
    await _checkSocial(
      "Gumtree",
      "https://www.gumtree.com.au/s-seller/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkGumroad() async {
    await _checkSocial(
      "Gumroad",
      "https://$username.gumroad.com",
      ["not found", "404"]
    );
  }

  Future<void> checkPatreon() async {
    await _checkSocial(
      "Patreon",
      "https://www.patreon.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkKickstarter() async {
    await _checkSocial(
      "Kickstarter",
      "https://www.kickstarter.com/profile/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkIndiegogo() async {
    await _checkSocial(
      "Indiegogo",
      "https://www.indiegogo.com/individuals/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkGoFundMe() async {
    await _checkSocial(
      "GoFundMe",
      "https://www.gofundme.com/f/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkVimeo() async {
    await _checkSocial(
      "Vimeo",
      "https://vimeo.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkDailymotion() async {
    await _checkSocial(
      "Dailymotion",
      "https://www.dailymotion.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkTwitch() async {
    await _checkSocial(
      "Twitch",
      "https://www.twitch.tv/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkMixer() async {
    await _checkSocial(
      "Mixer",
      "https://mixer.com/$username",
      ["not found", "404"]
    );
  }

Future<void> checkPeriscope() async {
    await _checkSocial(
      "Periscope",
      "https://www.periscope.tv/$username",
      ["not found", "404"]
    );
  }

  Future<void> check9GAG() async {
    await _checkSocial(
      "9GAG",
      "https://9gag.com/u/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkLiveJournal() async {
    await _checkSocial(
      "LiveJournal",
      "https://$username.livejournal.com",
      ["not found", "404"]
    );
  }

  Future<void> checkBlogger() async {
    await _checkSocial(
      "Blogger",
      "https://$username.blogspot.com",
      ["not found", "404"]
    );
  }

  Future<void> checkWordpress() async {
    await _checkSocial(
      "WordPress",
      "https://$username.wordpress.com",
      ["not found", "404"]
    );
  }

  Future<void> checkTumblr() async {
    await _checkSocial(
      "Tumblr",
      "https://$username.tumblr.com",
      ["not found", "404"]
    );
  }

  Future<void> checkWeibo() async {
    await _checkSocial(
      "Weibo",
      "https://weibo.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkVK() async {
    await _checkSocial(
      "VK",
      "https://vk.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkWeChat() async {
    await _checkSocial(
      "WeChat",
      "https://weixin.qq.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkSnapchat() async {
    await _checkSocial(
      "Snapchat",
      "https://www.snapchat.com/add/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkKik() async {
    await _checkSocial(
      "Kik",
      "https://kik.me/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkWhatsApp() async {
    await _checkSocial(
      "WhatsApp",
      "https://wa.me/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkSignal() async {
    await _checkSocial(
      "Signal",
      "https://signal.me/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkZoom() async {
    await _checkSocial(
      "Zoom",
      "https://zoom.us/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkSkype() async {
    await _checkSocial(
      "Skype",
      "https://skype.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkSlack() async {
    await _checkSocial(
      "Slack",
      "https://$username.slack.com",
      ["not found", "404"]
    );
  }

  Future<void> checkTeams() async {
    await _checkSocial(
      "Teams",
      "https://teams.microsoft.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkLastFM() async {
    await _checkSocial(
      "Last.fm",
      "https://www.last.fm/user/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkPandora() async {
    await _checkSocial(
      "Pandora",
      "https://www.pandora.com/profile/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkDeezer() async {
    await _checkSocial(
      "Deezer",
      "https://www.deezer.com/en/profile/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkTidal() async {
    await _checkSocial(
      "Tidal",
      "https://tidal.com/user/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkAppleMusic() async {
    await _checkSocial(
      "Apple Music",
      "https://music.apple.com/profile/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkGooglePlay() async {
    await _checkSocial(
      "Google Play",
      "https://play.google.com/store/apps/developer?id=$username",
      ["not found", "404"]
    );
  }

  Future<void> checkAppStore() async {
    await _checkSocial(
      "App Store",
      "https://apps.apple.com/developer/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkSteamDeveloper() async {
    await _checkSocial(
      "Steam Developer",
      "https://store.steampowered.com/developer/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkEpicGames() async {
    await _checkSocial(
      "Epic Games",
      "https://store.epicgames.com/creator/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkUplay() async {
    await _checkSocial(
      "Uplay",
      "https://account.ubisoft.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkOrigin() async {
    await _checkSocial(
      "Origin",
      "https://www.origin.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkBattleNet() async {
    await _checkSocial(
      "Battle.net",
      "https://battle.net/account/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkRiotGames() async {
    await _checkSocial(
      "Riot Games",
      "https://riotgames.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkBlizzard() async {
    await _checkSocial(
      "Blizzard",
      "https://blizzard.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkXbox() async {
    await _checkSocial(
      "Xbox",
      "https://xbox.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkPlayStation() async {
    await _checkSocial(
      "PlayStation",
      "https://playstation.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkNintendo() async {
    await _checkSocial(
      "Nintendo",
      "https://nintendo.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkRoblox() async {
    await _checkSocial(
      "Roblox",
      "https://www.roblox.com/users/$username/profile",
      ["not found", "404"]
    );
  }

  Future<void> checkMinecraft() async {
    await _checkSocial(
      "Minecraft",
      "https://minecraft.net/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkFortnite() async {
    await _checkSocial(
      "Fortnite",
      "https://fortnite.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkApexLegends() async {
    await _checkSocial(
      "Apex Legends",
      "https://apexlegends.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkValorant() async {
    await _checkSocial(
      "Valorant",
      "https://playvalorant.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkOverwatch() async {
    await _checkSocial(
      "Overwatch",
      "https://overwatch.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkLeagueOfLegends() async {
    await _checkSocial(
      "League of Legends",
      "https://leagueoflegends.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkDota2() async {
    await _checkSocial(
      "Dota 2",
      "https://dota2.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkCSGO() async {
    await _checkSocial(
      "CS:GO",
      "https://csgo.com/$username",
      ["not found", "404"]
    );
  }

  Future<void> checkHearthstone() async {
    await _checkSocial(
      "Hearthstone",
      "https://playhearthstone.com/$username",
      ["not found", "404"]
    );
  }

Future<void> checkAnno() async {
    await _checkSocial(
      "Anno",
      "https://anno.com/$username",
      ["not found", "404"]
    );
  }

  Future<String> generateFullReport() async {
    try {
      // Générer un rapport complet avec toutes les informations collectées
      Map<String, dynamic> fullReport = {
        "target": email,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "data": emailData,
        "found_count": found.length,
        "not_found_count": notFound.length,
        "error_count": errors.length,
        "summary": {
          "risk_level": _calculateRiskLevel(),
          "confidence_score": _calculateTrustScore(),
          "recommendations": _generateRecommendations()
        }
      };
      
      // Sauvegarder le rapport complet
      final reportPath = await saveFinding("Email_Full_Report", fullReport);
      
      if (reportPath.isNotEmpty) {
        print("\nRapport complet sauvegardé dans: $reportPath");
      }
      
      return reportPath;
    } catch (e) {
      if (verbose) print("Erreur lors de la génération du rapport complet: $e");
      return "";
    }
  }
  
  String _calculateRiskLevel() {
    // Calculer le niveau de risque basé sur les résultats
    int foundCount = found.length;
    int notFoundCount = notFound.length;
    
    double ratio = foundCount / (foundCount + notFoundCount);
    
    if (ratio >= 0.7) return "Faible";
    if (ratio >= 0.4) return "Modéré";
    if (ratio >= 0.2) return "Élevé";
    return "Très élevé";
  }
  
  double _calculateTrustScore() {
    // Calculer un score de confiance basé sur plusieurs facteurs
    double score = 50.0; // Score de départ
    
    // Points positifs
    if (found.length > 5) score += 20;
    if (emailData.containsKey("validity") && emailData["validity"]["syntax_valid"] == true) score += 10;
    if (emailData.containsKey("gravatar") && emailData["gravatar"]["found"] == true) score += 10;
    
    // Points négatifs
    if (errors.length > 5) score -= 20;
    if (emailData.containsKey("hibp") && emailData["hibp"]["found"] == true) score -= 15;
    if (emailData.containsKey("emailrep") && emailData["emailrep"]["suspicious"] == true) score -= 15;
    
    // S'assurer que le score reste dans la plage 0-100
    score = score.clamp(0.0, 100.0);
    
    return score;
  }
  
  List<String> _generateRecommendations() {
    // Générer des recommandations basées sur les résultats
    List<String> recommendations = [];
    
    if (emailData.containsKey("hibp") && emailData["hibp"]["found"] == true) {
      recommendations.add("Cette adresse e-mail a été compromise dans des fuites de données");
    }
    
    if (emailData.containsKey("emailrep") && emailData["emailrep"]["suspicious"] == true) {
      recommendations.add("Cette adresse e-mail est suspecte selon les bases de données de réputation");
    }
    
    if (found.length < 3) {
      recommendations.add("Cette adresse e-mail a peu de présence en ligne, ce qui peut indiquer une utilisation limitée");
    }
    
    if (errors.length > 5) {
      recommendations.add("De nombreuses erreurs ont été rencontrées, ce qui peut indiquer des restrictions d'accès");
    }
    
    if (recommendations.isEmpty) {
      recommendations.add("Aucun risque particulier détecté, pratiques de sécurité standard recommandées");
    }
    
    return recommendations;
  }
  
  void printSummary() {
    // Afficher un résumé de tous les résultats
    print("\n\n=== RÉSUMÉ DE L'ANALYSE E-MAIL ===");
    print("E-mail analysé: $email");
    print("Nombre total de vérifications: ${found.length + notFound.length + errors.length}");
    print("Trouvés: ${found.length}");
    print("Non trouvés: ${notFound.length}");
    print("Erreurs: ${errors.length}");
    
    if (emailData.containsKey("validity")) {
      print("Validité: ${emailData["validity"]["syntax_valid"] ? "Valide" : "Invalide"}");
    }
    
    if (emailData.containsKey("hibp") && emailData["hibp"]["found"] == true) {
      print("Fuites de données: Oui");
    }
    
    print("Score de confiance: ${_calculateTrustScore().toStringAsFixed(1)}%");
    print("Niveau de risque: ${_calculateRiskLevel()}");
    
    print("\nRecommandations:");
    for (var recommendation in _generateRecommendations()) {
      print("- $recommendation");
    }
    
    print("\n=====================================");
  }
  
  // Fonction principale pour exécuter une analyse complète
  Future<void> runFullScan() async {
    print("Lancement de l'analyse e-mail pour: $email");
    print("========================================");
    
    // Analyse de base
    await checkEmailValidity();
    
    // Vérification des fuites de données
    _printSection("FUITES DE DONNÉES");
    await checkHibpWeb();
    await checkLeakcheck();
    await checkPsbdmp();
    await checkBreachdirectory();
    
    // Vérification de la réputation
    _printSection("RÉPUTATION");
    await checkEmailrep();
    await checkGravatar();
    
    // Vérification DNS
    _printSection("DNS");
    await checkDns();
    
    // Réseaux sociaux principaux
    _printSection("RÉSEAUX SOCIAUX");
    await checkTwitter();
    await checkReddit();
    await checkGithub();
    await checkMedium();
    await checkLinkedIn();
    await checkFacebook();
    await checkInstagram();
    await checkTikTok();
    await checkYouTube();
    await checkPinterest();
    
    // Plateformes de contenu
    _printSection("PLATEFORMES DE CONTENU");
    await checkKeybase();
    await checkTelegram();
    await checkDiscord();
    await checkSpotify();
    await checkSoundCloud();
    await checkFlickr();
    await checkDeviantArt();
    await checkBehance();
    await checkDribbble();
    
    // Plateformes de jeu
    _printSection("JEUX EN LIGNE");
    await checkSteam();
    await checkEpicGames();
    await checkBattleNet();
    await checkRiotGames();
    await checkXbox();
    await checkPlayStation();
    await checkRoblox();
    await checkMinecraft();
    
    // Plateformes de développement
    _printSection("DÉVELOPPEMENT");
    await checkBitbucket();
    await checkGitLab();
    await checkStackOverflow();
    await checkDevTo();
    await checkCodePen();
    
    // Plateformes pour adultes
    _printSection("PLATEFORMES POUR ADULTES");
    await checkOnlyfans();
    await checkFansly();
    await checkChaturbate();
    
    // Vérifications additionnelles
    _printSection("AUTRES VÉRIFICATIONS");
    await checkRedditUserHistory();
    await checkPastebin();
    await checkPatreon();
    await checkKickstarter();
    
    // Générer le rapport complet
    await generateFullReport();
    
    // Afficher le résumé
    printSummary();
  }
}

// Fonction principale pour tester le module
void main() async {
  print("Entrez une adresse e-mail à analyser:");
  String? input = stdin.readLineSync();
  
  if (input != null && input.isNotEmpty) {
    EmailOSINT scanner = EmailOSINT(input);
    scanner.verbose = true;
    scanner.saveToFile = true;
    scanner.outputFormat = "json";
    
    await scanner.runFullScan();
  } else {
    print("Adresse e-mail invalide ou non fournie.");
  }
}