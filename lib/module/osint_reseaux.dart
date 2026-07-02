import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

/// Module OSINT Réseaux - Scanner complet style nmap
/// S'intègre avec WatchFox V2

class NmapDart {
  final String target;
  List<int> ports = [];
  bool topPorts = false;
  int topPortsCount = 1000;
  bool allPorts = false;
  Duration timeout = const Duration(seconds: 3);
  int maxConcurrent = 100;
  bool serviceVersion = false;
  bool verbose = false;
  bool hostDiscovery = true;
  
  // Callback pour les mises à jour de progression
  Function(double, String)? onProgress;

  // Top 1000 ports les plus communs
  static const List<int> top1000Ports = [
    1, 3, 4, 6, 7, 9, 13, 17, 19, 20, 21, 22, 23, 25, 26, 30, 32, 33, 37, 42, 43, 49,
    53, 70, 79, 80, 81, 82, 83, 84, 85, 88, 89, 90, 99, 100, 106, 109, 110, 111, 113,
    119, 125, 135, 139, 143, 144, 146, 161, 163, 179, 199, 211, 212, 222, 254, 255, 256,
    259, 264, 280, 301, 306, 311, 340, 366, 389, 406, 407, 416, 417, 425, 427, 443, 444,
    445, 458, 464, 465, 481, 497, 500, 512, 513, 514, 515, 524, 541, 543, 544, 545, 548,
    554, 555, 563, 587, 593, 616, 617, 625, 631, 636, 646, 648, 666, 667, 668, 683, 687,
    691, 700, 705, 711, 714, 720, 722, 726, 749, 765, 777, 783, 787, 800, 801, 808, 843,
    873, 880, 888, 898, 900, 901, 902, 903, 911, 912, 981, 987, 990, 992, 993, 995, 999,
    1000, 1001, 1002, 1007, 1009, 1010, 1011, 1021, 1022, 1023, 1024, 1025, 1026, 1027,
    1028, 1029, 1030, 1031, 1032, 1033, 1034, 1035, 1036, 1037, 1038, 1039, 1040, 1041,
    1042, 1043, 1044, 1045, 1046, 1047, 1048, 1049, 1050, 1051, 1052, 1053, 1054, 1055,
    1056, 1057, 1058, 1059, 1060, 1061, 1062, 1063, 1064, 1065, 1066, 1067, 1068, 1069,
    1070, 1071, 1072, 1073, 1074, 1075, 1076, 1077, 1078, 1079, 1080, 1081, 1082, 1083,
    1084, 1085, 1086, 1087, 1088, 1089, 1090, 1091, 1092, 1093, 1094, 1095, 1096, 1097,
    1098, 1099, 1100, 1102, 1104, 1105, 1106, 1107, 1108, 1110, 1111, 1112, 1113, 1114,
    1117, 1119, 1121, 1122, 1123, 1124, 1126, 1130, 1131, 1132, 1137, 1138, 1141, 1145,
    1147, 1148, 1149, 1151, 1152, 1154, 1163, 1164, 1165, 1166, 1169, 1174, 1175, 1183,
    1185, 1186, 1187, 1192, 1198, 1199, 1201, 1213, 1216, 1217, 1218, 1233, 1234, 1236,
    1244, 1247, 1248, 1259, 1271, 1272, 1277, 1287, 1296, 1300, 1301, 1309, 1310, 1311,
    1322, 1328, 1334, 1352, 1417, 1433, 1434, 1443, 1455, 1461, 1494, 1500, 1501, 1503,
    1521, 1524, 1533, 1556, 1580, 1583, 1594, 1600, 1641, 1658, 1666, 1687, 1688, 1700,
    1717, 1718, 1719, 1720, 1721, 1723, 1755, 1761, 1782, 1801, 1805, 1812, 1839, 1840,
    1862, 1863, 1864, 1875, 1900, 1914, 1935, 1947, 1971, 1972, 1974, 1984, 1998, 1999,
    2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2013, 2020, 2021,
    2022, 2030, 2033, 2034, 2035, 2038, 2040, 2041, 2042, 2043, 2045, 2046, 2047, 2048,
    2049, 2065, 2068, 2099, 2100, 2103, 2105, 2106, 2107, 2111, 2119, 2121, 2126, 2135,
    2144, 2160, 2161, 2170, 2179, 2190, 2191, 2196, 2200, 2222, 2251, 2280, 2310, 2323,
    2366, 2381, 2382, 2383, 2393, 2394, 2399, 2401, 2492, 2500, 2522, 2525, 2557, 2601,
    2602, 2604, 2605, 2607, 2608, 2638, 2701, 2702, 2710, 2717, 2718, 2725, 2800, 2809,
    2811, 2869, 2875, 2909, 2910, 2920, 2967, 2968, 2998, 3000, 3001, 3003, 3005, 3006,
    3007, 3011, 3013, 3017, 3030, 3031, 3052, 3071, 3077, 3128, 3168, 3211, 3221, 3260,
    3261, 3268, 3269, 3283, 3300, 3301, 3306, 3322, 3323, 3324, 3325, 3333, 3351, 3367,
    3369, 3370, 3371, 3372, 3389, 3390, 3404, 3476, 3493, 3517, 3527, 3546, 3551, 3580,
    3659, 3689, 3690, 3703, 3737, 3766, 3784, 3800, 3801, 3809, 3814, 3826, 3828, 3851,
    3869, 3871, 3878, 3880, 3889, 3905, 3914, 3918, 3920, 3945, 3971, 3986, 3995, 3998,
    4000, 4001, 4002, 4003, 4004, 4005, 4006, 4045, 4111, 4125, 4126, 4129, 4224, 4242,
    4279, 4321, 4343, 4443, 4444, 4445, 4446, 4449, 4550, 4567, 4662, 4848, 4899, 4900,
    4998, 5000, 5001, 5002, 5003, 5004, 5009, 5030, 5033, 5050, 5051, 5054, 5060, 5061,
    5080, 5087, 5100, 5101, 5102, 5120, 5190, 5200, 5214, 5221, 5222, 5225, 5226, 5269,
    5280, 5298, 5357, 5405, 5414, 5431, 5432, 5440, 5500, 5510, 5544, 5550, 5555, 5560,
    5566, 5631, 5633, 5666, 5678, 5679, 5718, 5730, 5800, 5801, 5802, 5810, 5811, 5815,
    5822, 5825, 5850, 5859, 5862, 5877, 5900, 5901, 5902, 5903, 5904, 5906, 5907, 5910,
    5911, 5915, 5922, 5925, 5950, 5952, 5959, 5960, 5961, 5962, 5963, 5987, 5988, 5989,
    5998, 5999, 6000, 6001, 6002, 6003, 6004, 6005, 6006, 6007, 6009, 6025, 6059, 6100,
    6101, 6106, 6112, 6123, 6129, 6156, 6346, 6389, 6502, 6510, 6543, 6547, 6565, 6566,
    6567, 6580, 6646, 6666, 6667, 6668, 6669, 6689, 6692, 6699, 6779, 6788, 6789, 6792,
    6839, 6881, 6901, 6969, 7000, 7001, 7002, 7004, 7007, 7019, 7025, 7070, 7100, 7103,
    7106, 7200, 7201, 7402, 7435, 7443, 7496, 7512, 7625, 7626, 7676, 7741, 7777, 7778,
    7800, 7911, 7920, 7937, 7938, 7999, 8000, 8001, 8002, 8003, 8004, 8005, 8006, 8007,
    8008, 8009, 8010, 8011, 8021, 8022, 8031, 8042, 8045, 8080, 8081, 8082, 8083, 8084,
    8085, 8086, 8087, 8088, 8089, 8090, 8093, 8099, 8100, 8180, 8181, 8192, 8193, 8194,
    8200, 8222, 8254, 8290, 8291, 8292, 8300, 8333, 8383, 8400, 8402, 8443, 8500, 8600,
    8649, 8651, 8652, 8654, 8701, 8800, 8873, 8888, 8899, 8994, 9000, 9001, 9002, 9003,
    9009, 9010, 9011, 9040, 9050, 9071, 9080, 9081, 9090, 9091, 9099, 9100, 9101, 9102,
    9103, 9110, 9111, 9200, 9207, 9220, 9290, 9415, 9418, 9485, 9500, 9502, 9503, 9535,
    9575, 9593, 9594, 9595, 9618, 9666, 9876, 9877, 9878, 9898, 9900, 9917, 9929, 9943,
    9944, 9968, 9998, 9999, 10000, 10001, 10002, 10003, 10004, 10009, 10010, 10012, 10024,
    10025, 10082, 10180, 10215, 10243, 10566, 10616, 10617, 10621, 10626, 10628, 10629,
    10778, 11110, 11111, 11967, 12000, 12174, 12265, 12345, 13456, 13722, 13782, 13783,
    14000, 14238, 14441, 14442, 15000, 15002, 15003, 15004, 15660, 15742, 16000, 16001,
    16012, 16016, 16018, 16080, 16113, 16992, 16993, 17877, 17988, 18000, 18101, 18988,
    19101, 19283, 19315, 19350, 19780, 19801, 19842, 20000, 20005, 20031, 20221, 20222,
    20828, 21571, 22939, 23502, 24444, 24800, 25734, 25735, 26214, 27000, 27352, 27353,
    27355, 27356, 27715, 28201, 30000, 30718, 30951, 31038, 31337, 32768, 32769, 32770,
    32771, 32772, 32773, 32774, 32775, 32776, 32777, 32778, 32779, 32780, 32781, 32782,
    32783, 32784, 32785, 33354, 33899, 34571, 34572, 34573, 35500, 38292, 40193, 40911,
    41511, 42510, 44176, 44442, 44443, 44501, 45100, 48080, 49152, 49153, 49154, 49155,
    49156, 49157, 49158, 49159, 49160, 49161, 49163, 49165, 49167, 49175, 49176, 49400,
    49999, 50000, 50001, 50002, 50003, 50006, 50300, 50389, 50500, 50636, 50800, 51103,
    51493, 52673, 52822, 52848, 52869, 54045, 54328, 55055, 55056, 55555, 55600, 56737,
    56738, 57294, 57797, 58080, 60020, 60443, 61532, 61900, 62078, 63331, 64623, 64680,
    65000, 65129, 65389,
  ];

  // Base de données des services
  static const Map<int, Map<String, String>> serviceDatabase = {
    1: {'name': 'tcpmux', 'desc': 'TCP Port Service Multiplexer'},
    7: {'name': 'echo', 'desc': 'Echo'},
    9: {'name': 'discard', 'desc': 'Discard'},
    13: {'name': 'daytime', 'desc': 'Daytime'},
    17: {'name': 'qotd', 'desc': 'Quote of the Day'},
    19: {'name': 'chargen', 'desc': 'Character Generator'},
    20: {'name': 'ftp-data', 'desc': 'FTP Data'},
    21: {'name': 'ftp', 'desc': 'File Transfer Protocol'},
    22: {'name': 'ssh', 'desc': 'SSH Remote Login Protocol'},
    23: {'name': 'telnet', 'desc': 'Telnet'},
    25: {'name': 'smtp', 'desc': 'Simple Mail Transfer Protocol'},
    37: {'name': 'time', 'desc': 'Time'},
    42: {'name': 'nameserver', 'desc': 'Host Name Server'},
    43: {'name': 'whois', 'desc': 'Who Is'},
    53: {'name': 'domain', 'desc': 'DNS'},
    67: {'name': 'bootps', 'desc': 'Bootstrap Protocol Server'},
    68: {'name': 'bootpc', 'desc': 'Bootstrap Protocol Client'},
    69: {'name': 'tftp', 'desc': 'Trivial File Transfer'},
    79: {'name': 'finger', 'desc': 'Finger'},
    80: {'name': 'http', 'desc': 'World Wide Web HTTP'},
    88: {'name': 'kerberos', 'desc': 'Kerberos'},
    101: {'name': 'hostname', 'desc': 'NIC Host Name Server'},
    102: {'name': 'iso-tsap', 'desc': 'ISO-TSAP Class 0'},
    107: {'name': 'rtelnet', 'desc': 'Remote Telnet Service'},
    109: {'name': 'pop2', 'desc': 'Post Office Protocol v2'},
    110: {'name': 'pop3', 'desc': 'Post Office Protocol v3'},
    111: {'name': 'sunrpc', 'desc': 'SUN Remote Procedure Call'},
    113: {'name': 'auth', 'desc': 'Authentication Service'},
    115: {'name': 'sftp', 'desc': 'Simple File Transfer Protocol'},
    117: {'name': 'uucp-path', 'desc': 'UUCP Path Service'},
    119: {'name': 'nntp', 'desc': 'Network News Transfer Protocol'},
    123: {'name': 'ntp', 'desc': 'Network Time Protocol'},
    135: {'name': 'msrpc', 'desc': 'Microsoft RPC'},
    137: {'name': 'netbios-ns', 'desc': 'NETBIOS Name Service'},
    138: {'name': 'netbios-dgm', 'desc': 'NETBIOS Datagram Service'},
    139: {'name': 'netbios-ssn', 'desc': 'NETBIOS Session Service'},
    143: {'name': 'imap', 'desc': 'Internet Message Access Protocol'},
    161: {'name': 'snmp', 'desc': 'SNMP'},
    162: {'name': 'snmptrap', 'desc': 'SNMP TRAP'},
    177: {'name': 'xdmcp', 'desc': 'X Display Manager Control Protocol'},
    179: {'name': 'bgp', 'desc': 'Border Gateway Protocol'},
    194: {'name': 'irc', 'desc': 'Internet Relay Chat'},
    201: {'name': 'at-rtmp', 'desc': 'AppleTalk Routing Maintenance'},
    202: {'name': 'at-nbp', 'desc': 'AppleTalk Name Binding'},
    204: {'name': 'at-echo', 'desc': 'AppleTalk Echo'},
    206: {'name': 'at-zis', 'desc': 'AppleTalk Zone Information'},
    389: {'name': 'ldap', 'desc': 'Lightweight Directory Access Protocol'},
    443: {'name': 'https', 'desc': 'HTTP over TLS/SSL'},
    445: {'name': 'microsoft-ds', 'desc': 'Microsoft-DS'},
    464: {'name': 'kpasswd', 'desc': 'Kerberos Password'},
    465: {'name': 'smtps', 'desc': 'SMTP over TLS/SSL'},
    512: {'name': 'exec', 'desc': 'Remote Process Execution'},
    513: {'name': 'login', 'desc': 'Remote Login'},
    514: {'name': 'shell', 'desc': 'Remote Shell'},
    515: {'name': 'printer', 'desc': 'Spooler'},
    530: {'name': 'courier', 'desc': 'RPC'},
    531: {'name': 'conference', 'desc': 'Chat'},
    532: {'name': 'netnews', 'desc': 'Readnews'},
    540: {'name': 'uucp', 'desc': 'UUCP Daemon'},
    543: {'name': 'klogin', 'desc': 'Kerberos Login'},
    544: {'name': 'kshell', 'desc': 'Kerberos Remote Shell'},
    548: {'name': 'afp', 'desc': 'Apple Filing Protocol'},
    554: {'name': 'rtsp', 'desc': 'Real Time Streaming Protocol'},
    587: {'name': 'submission', 'desc': 'Message Submission'},
    631: {'name': 'ipp', 'desc': 'Internet Printing Protocol'},
    636: {'name': 'ldaps', 'desc': 'LDAP over TLS/SSL'},
    873: {'name': 'rsync', 'desc': 'Rsync'},
    990: {'name': 'ftps', 'desc': 'FTP over TLS/SSL'},
    993: {'name': 'imaps', 'desc': 'IMAP over TLS/SSL'},
    995: {'name': 'pop3s', 'desc': 'POP3 over TLS/SSL'},
    1080: {'name': 'socks', 'desc': 'Socks'},
    1194: {'name': 'openvpn', 'desc': 'OpenVPN'},
    1433: {'name': 'ms-sql-s', 'desc': 'Microsoft SQL Server'},
    1434: {'name': 'ms-sql-m', 'desc': 'Microsoft SQL Monitor'},
    1521: {'name': 'oracle', 'desc': 'Oracle Database'},
    1701: {'name': 'l2tp', 'desc': 'Layer Two Tunneling Protocol'},
    1723: {'name': 'pptp', 'desc': 'Point-to-Point Tunneling Protocol'},
    2049: {'name': 'nfs', 'desc': 'Network File System'},
    2082: {'name': 'cpanel', 'desc': 'cPanel'},
    2083: {'name': 'cpanel-ssl', 'desc': 'cPanel SSL'},
    2086: {'name': 'whm', 'desc': 'Web Host Manager'},
    2087: {'name': 'whm-ssl', 'desc': 'Web Host Manager SSL'},
    2095: {'name': 'webmail', 'desc': 'Webmail'},
    2096: {'name': 'webmail-ssl', 'desc': 'Webmail SSL'},
    3128: {'name': 'squid-http', 'desc': 'Squid Web Proxy'},
    3306: {'name': 'mysql', 'desc': 'MySQL Database'},
    3389: {'name': 'ms-wbt-server', 'desc': 'Microsoft Remote Desktop'},
    5432: {'name': 'postgresql', 'desc': 'PostgreSQL Database'},
    5900: {'name': 'vnc', 'desc': 'Virtual Network Computing'},
    5901: {'name': 'vnc-1', 'desc': 'VNC display :1'},
    5902: {'name': 'vnc-2', 'desc': 'VNC display :2'},
    5984: {'name': 'couchdb', 'desc': 'CouchDB'},
    6379: {'name': 'redis', 'desc': 'Redis Key-Value Store'},
    6667: {'name': 'ircd', 'desc': 'Internet Relay Chat Daemon'},
    8000: {'name': 'http-alt', 'desc': 'HTTP Alternate'},
    8008: {'name': 'http', 'desc': 'HTTP'},
    8080: {'name': 'http-proxy', 'desc': 'HTTP Proxy'},
    8081: {'name': 'blackice-icecap', 'desc': 'BlackICE ICEcap'},
    8443: {'name': 'https-alt', 'desc': 'HTTPS Alternate'},
    8888: {'name': 'sun-answerbook', 'desc': 'Sun Answerbook'},
    9000: {'name': 'cslistener', 'desc': 'CSlistener'},
    9001: {'name': 'tor-orport', 'desc': 'Tor ORPort'},
    9040: {'name': 'tor-trans', 'desc': 'Tor TransPort'},
    9050: {'name': 'tor-socks', 'desc': 'Tor SocksPort'},
    9051: {'name': 'tor-control', 'desc': 'Tor ControlPort'},
    9090: {'name': 'zeus-admin', 'desc': 'Zeus Admin Server'},
    9091: {'name': 'zeus', 'desc': 'Zeus'},
    9200: {'name': 'elasticsearch', 'desc': 'Elasticsearch'},
    9418: {'name': 'git', 'desc': 'Git Version Control System'},
    10000: {'name': 'snet-sensor-mgmt', 'desc': 'SecureNet Pro'},
    11211: {'name': 'memcache', 'desc': 'Memcached'},
    27017: {'name': 'mongodb', 'desc': 'MongoDB'},
    27018: {'name': 'mongodb-shard', 'desc': 'MongoDB Shard'},
    27019: {'name': 'mongodb-config', 'desc': 'MongoDB Config Server'},
    50000: {'name': 'db2', 'desc': 'IBM DB2'},
  };

  NmapDart({
    required this.target,
    this.topPorts = true,
    this.topPortsCount = 1000,
    this.allPorts = false,
    this.timeout = const Duration(seconds: 3),
    this.maxConcurrent = 100,
    this.serviceVersion = true,
    this.verbose = true,
    this.hostDiscovery = true,
    this.onProgress,
  }) {
    // Initialisation des ports à scanner
    if (allPorts) {
      ports = List.generate(65535, (i) => i + 1);
    } else if (topPorts || ports.isEmpty) {
      ports = top1000Ports.take(topPortsCount).toList();
    }
  }

  void _updateProgress(double value, String label) {
    onProgress?.call(value, label);
  }

  String getServiceName(int port) {
    return serviceDatabase[port]?['name'] ?? 'unknown';
  }

  String getServiceDescription(int port) {
    return serviceDatabase[port]?['desc'] ?? 'Unknown service';
  }

  Future<bool> pingHost(String host) async {
    try {
      // Tentative de connexion sur les ports communs
      for (var port in [80, 443, 22, 445, 139, 3389]) {
        try {
          final socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 800));
          socket.destroy();
          return true;
        } catch (_) {}
      }
      
      // Fallback sur la résolution DNS
      try {
        await InternetAddress.lookup(host);
        return true;
      } catch (_) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> resolveTarget(String target) async {
    final result = <String, dynamic>{};
    
    try {
      // Détection si c'est une IP ou un nom de domaine
      final isIP = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(target);
      
      if (isIP) {
        result['ip'] = target;
        try {
          final reverse = await InternetAddress(target).reverse();
          result['hostname'] = reverse.host;
        } catch (_) {
          result['hostname'] = null;
        }
      } else {
        // Résolution DNS
        final addresses = await InternetAddress.lookup(target);
        result['ip'] = addresses.first.address;
        result['hostname'] = target;
      }
      
      result['isUp'] = await pingHost(result['ip']);
      
    } catch (e) {
      result['error'] = 'Impossible de résoudre la cible: $e';
    }
    
    return result;
  }

  Future<Map<String, dynamic>> scanPort(String host, int port) async {
    final result = {
      'port': port,
      'protocol': 'tcp',
      'state': 'unknown',
      'service': getServiceName(port),
      'banner': null,
      'version': null,
    };
    
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      result['state'] = 'open';
      
      // Banner grabbing si activé
      if (serviceVersion) {
        try {
          socket.listen(
            (data) {
              final banner = utf8.decode(data, allowMalformed: true).trim();
              if (banner.isNotEmpty) {
                result['banner'] = banner.substring(0, min(banner.length, 256));
                _detectVersion(result);
              }
            },
            onError: (_) {},
            cancelOnError: true,
          );
          
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (_) {}
      }
      
      socket.destroy();
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 111) {
        result['state'] = 'closed';
      } else {
        result['state'] = 'filtered';
      }
    } catch (e) {
      result['state'] = 'filtered';
    }
    
    return result;
  }

  void _detectVersion(Map<String, dynamic> portInfo) {
    final banner = (portInfo['banner'] as String?)?.toLowerCase() ?? '';
    if (banner.isEmpty) return;
    
    final patterns = {
      'ssh': RegExp(r'ssh-(\d+\.\d+)', caseSensitive: false),
      'apache': RegExp(r'apache/(\d+\.\d+\.\d+)', caseSensitive: false),
      'nginx': RegExp(r'nginx/(\d+\.\d+\.\d+)', caseSensitive: false),
      'mysql': RegExp(r'(\d+\.\d+\.\d+)-mysql', caseSensitive: false),
      'postgre': RegExp(r'postgresql\s+(\d+\.\d+)', caseSensitive: false),
      'ftp': RegExp(r'ftp\s+(\d+\.\d+)', caseSensitive: false),
      'smtp': RegExp(r'(\d+\.\d+\.\d+)', caseSensitive: false),
    };
    
    for (var entry in patterns.entries) {
      final match = entry.value.firstMatch(portInfo['banner']);
      if (match != null) {
        portInfo['version'] = '${portInfo['service']} ${match.group(1)}';
        break;
      }
    }
  }

  Future<void> scan() async {
    final stopwatch = Stopwatch()..start();
    
    print('');
    print('╔════════════════════════════════════════════════════════════╗');
    print('║           NMAP DART - NETWORK SCANNER                      ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('');
    
    // Phase 1: Résolution DNS et Host Discovery
    _updateProgress(0.1, 'Résolution DNS...');
    print('[*] Phase 1: Résolution et découverte d\'hôte');
    print('[>] Cible: $target');
    
    final targetInfo = await resolveTarget(target);
    
    if (targetInfo.containsKey('error')) {
      print('[!] ${targetInfo['error']}');
      return;
    }
    
    final ip = targetInfo['ip'] as String;
    final hostname = targetInfo['hostname'] as String?;
    final isUp = targetInfo['isUp'] as bool;
    
    print('[~] IP résolue: $ip');
    if (hostname != null && hostname != target) {
      print('[~] Nom d\'hôte: $hostname');
    }
    
    if (!isUp && hostDiscovery) {
      print('[!] Hôte semble hors ligne');
      print('[>] Si l\'hôte est actif mais bloque les pings, utilisez --Pn');
    } else {
      print('[~] Hôte actif détecté');
    }
    
    // Phase 2: Scan des ports
    _updateProgress(0.2, 'Scan des ports...');
    print('');
    print('[*] Phase 2: Scan des ports (${ports.length} ports)');
    print('[>] Démarrage du scan avec $maxConcurrent connexions parallèles');
    
    final openPorts = <Map<String, dynamic>>[];
    final closedPorts = <Map<String, dynamic>>[];
    final filteredPorts = <Map<String, dynamic>>[];
    
    // Semaphore pour contrôler la concurrence
    final semaphore = _Semaphore(maxConcurrent);
    final futures = <Future<void>>[];
    
    int scanned = 0;
    int lastReportedProgress = 0;
    
    for (final port in ports) {
      futures.add(() async {
        await semaphore.acquire();
        try {
          final result = await scanPort(ip, port);
          
          if (result['state'] == 'open') {
            openPorts.add(result);
          } else if (result['state'] == 'closed') {
            closedPorts.add(result);
          } else {
            filteredPorts.add(result);
          }
          
          scanned++;
          
          // Mise à jour de la progression tous les 10%
          final progress = (scanned / ports.length * 100).toInt();
          if (progress >= lastReportedProgress + 10) {
            lastReportedProgress = (progress ~/ 10) * 10;
            final progressValue = 0.2 + (scanned / ports.length * 0.6);
            _updateProgress(progressValue, 'Scan des ports... $progress%');
            if (verbose) {
              print('[>] Progression: $progress% ($scanned/${ports.length} ports)');
            }
          }
          
        } finally {
          semaphore.release();
        }
      }());
    }
    
    await Future.wait(futures);
    
    // Phase 3: Rapport
    _updateProgress(0.9, 'Génération du rapport...');
    print('');
    print('╔════════════════════════════════════════════════════════════╗');
    print('║                     RÉSULTATS DU SCAN                        ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('');
    print('Cible: $target ($ip)');
    if (hostname != null) print('Nom:   $hostname');
    print('');
    
    // Tri des ports ouverts
    openPorts.sort((a, b) => (a['port'] as int).compareTo(b['port'] as int));
    
    if (openPorts.isNotEmpty) {
      print('PORTS OUVERTS:');
      print('┌──────────┬────────┬─────────────────┬──────────────────────────────┐');
      print('│ PORT     │ PROTO  │ SERVICE         │ VERSION                      │');
      print('├──────────┼────────┼─────────────────┼──────────────────────────────┤');
      
      for (final port in openPorts) {
        final portNum = (port['port'] as int).toString().padRight(8);
        final proto = (port['protocol'] as String).padRight(6);
        final service = (port['service'] as String).padRight(15);
        final version = (port['version'] ?? '').padRight(28);
        print('│ $portNum │ $proto │ $service │ $version │');
      }
      print('└──────────┴────────┴─────────────────┴──────────────────────────────┘');
    } else {
      print('[!] Aucun port ouvert détecté');
    }
    
    print('');
    print('STATISTIQUES:');
    print('  • Ports ouverts:   ${openPorts.length}');
    print('  • Ports fermés:    ${closedPorts.length}');
    print('  • Ports filtrés:   ${filteredPorts.length}');
    print('  • Total scanné:    ${ports.length}');
    
    stopwatch.stop();
    print('');
    print('[~] Scan terminé en ${stopwatch.elapsed.inSeconds}.${stopwatch.elapsed.inMilliseconds % 1000}s');
    
    _updateProgress(1.0, 'Terminé');
  }
}

// Classe Semaphore pour contrôle de concurrence
class _Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  _Semaphore(this.maxCount) : _currentCount = maxCount;

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