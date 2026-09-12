import requests
from bs4 import BeautifulSoup
from urllib.parse import quote_plus
import re

class Profileur:
    def __init__(self, target):
        # On suppose que l'utilisateur entre "Prenom Nom" dans la barre de recherche
        parts = target.split(' ')
        self.prenom = parts[0] if len(parts) > 0 else ""
        self.nom = parts[1] if len(parts) > 1 else ""
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'
        }

    def run_scan(self):
        if not self.nom or not self.prenom:
            print("[!] Format invalide. Veuillez entrer 'Prenom Nom'.")
            return

        query = f"{self.prenom} {self.nom}"
        print(f"[*] RECHERCHE DE PROFIL POUR : {query}")
        print("-" * 40)

        # Simulation de recherche simplifiée pour l'intégration
        url = f"https://www.google.com/search?q={quote_plus(query)}"
        try:
            response = requests.get(url, headers=self.headers, timeout=10)
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extraction des titres de résultats (exemple simplifié)
            results = soup.find_all('h3')
            if results:
                print(f"[+] {len(results)} résultats potentiels trouvés sur le web.")
                for res in results[:5]: # Affiche les 5 premiers
                    print(f"  • {res.get_text()}")
            else:
                print("[?] Aucun résultat public immédiat trouvé.")
                
        except Exception as e:
            print(f"[!] Erreur lors de la recherche : {e}")