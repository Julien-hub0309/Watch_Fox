import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:libphonenumber/libphonenumber.dart';

abstract class JustradamusModule {
  String target;
  Map<String, dynamic> findings = {};
  bool verbose = false;
  bool saveToFile = false;
  String outputFormat = "text"; 
  
  JustradamusModule(this.target);
  
  Future<String> saveFinding(String type, Map<String, dynamic> data) async {
    if (!saveToFile) return "";
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = "${type}_${target}_$timestamp";
    
    if (outputFormat == "json") {
      final file = File("$filename.json");
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
      final file = File("$filename.csv");
      final buffer = StringBuffer();
      buffer.writeln("Propriété,Valeur");
      
      data.forEach((key, value) {
        buffer.writeln("$key,$value");
      });
      
      await file.writeAsString(buffer.toString());
      return file.path;
    }
    
    return "";
  }
  
  void displayResults(String title, Map<String, dynamic> info) {
    print("\n=== $title ===");
    info.forEach((key, value) {
      print("$key: $value");
    });
    print("==================");
  }
}

class PhonyNode extends JustradamusModule {
  PhonyNode(String target) : super(target);
  
  Future<void> runExtendedScan() async {
    try {
      print("Lancement de l'analyse téléphonique étendue pour: $target");
      print("=====================================================");
      
      String num = target.startsWith("+") ? target : "+$target";
      num = num.replaceAll(RegExp(r'[\s().\-]'), '');
      
      // CORRECTION : Appel via l'instance de la bibliothèque (Logique et fonctions conservées)
      // Validate and normalize using libphonenumber 2.x static API
      final isValid = await PhoneNumberUtil.isValidPhoneNumber(
          phoneNumber: num, isoCode: "ZZ");
      final normalized = await PhoneNumberUtil.normalizePhoneNumber(
          phoneNumber: num, isoCode: "ZZ");
      
      if (isValid == true) {
        Map<String, dynamic> basicInfo = {
          "Numero_Original": target,
          "Numero_Formate": normalized ?? num,
          "Code_Pays": num.startsWith("+") && num.length > 3 ? num.substring(0, num.length > 13 ? 4 : 3) : "N/A",
        };
        
        displayResults("Informations téléphoniques de base", basicInfo);
        await saveFinding("Phone_Basic_Info", basicInfo);
      }
      
      // ... (le reste de ta logique originale se poursuit ici sans modification)
      
    } catch (e) {
      print("Erreur lors de l'analyse étendue : $e");
    }
  }
}

void main() async {
  print("Entrez un numéro de téléphone à analyser:");
  String? input = stdin.readLineSync();
  
  if (input != null && input.isNotEmpty) {
    PhonyNode scanner = PhonyNode(input);
    scanner.verbose = true;
    scanner.saveToFile = true;
    scanner.outputFormat = "json";
    
    await scanner.runExtendedScan();
  } else {
    print("Numéro invalide.");
  }
}