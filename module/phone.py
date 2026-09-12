import phonenumbers
from phonenumbers import geocoder, carrier
from core.base import JustradamusModule
from utile.display import console

class PhonyNode(JustradamusModule):
    def run_scan(self):
        try:
            num = "+" + self.target.replace("+", "")
            parsed = phonenumbers.parse(num)

            # ┌─ EN-TÊTE ──────────────────────────────────────┐
            console.print("[>] PHONE INTELLIGENCE SCAN")
            console.print(f"Cible : {self.target}")
            console.print("-" * 40)

            country  = geocoder.country_name_for_number(parsed, "fr")
            operator = carrier.name_for_number(parsed, "fr")
            valid    = phonenumbers.is_valid_number(parsed)

            # Résultats formatés pour FakeConsole
            console.print(f"[+] Pays      : {country}")
            console.print(f"[+] Opérateur : {operator if operator else 'Inconnu'}")

            if valid:
                console.print("[+] Validité  : Numéro VALIDE")
            else:
                console.print("[!] Validité  : Numéro INVALIDE")

            console.print("Spam Score    : Recherche de réputation en cours...")
            console.print("-" * 40)

            info = {
                "Pays": country,
                "Operateur": operator,
                "Validite": valid,
                "Spam_Score": "Recherche de réputation en cours..."
            }

            self.save_finding("Phone_Intel", info)
            self.display_results("Intelligence Téléphonique", info)

        except Exception as e:
            console.print(f"[!] Erreur Phone : {e}")