import requests
import base64

class URLAnalyzer:
    def __init__(self, url):
        self.url = url
        # Note : Il est recommandé de ne pas coder l'API KEY en dur, 
        # mais pour l'intégration directe, on la garde.
        self.api_key = "b5c670ae139caa20e28ad1adad49ffb858cd0655450d4798686d1e3a4741ced6"

    def run_scan(self):
        """Logique d'analyse appelée par execute_scan dans main.py"""
        print(f"[*] Analyse VirusTotal pour : {self.url}")
        
        try:
            # Encodage de l'URL pour l'API VirusTotal v3
            url_id = base64.urlsafe_b64encode(self.url.encode()).decode().strip("=")
            endpoint = f"https://www.virustotal.com/api/v3/urls/{url_id}"
            headers = {"x-apikey": self.api_key}

            response = requests.get(endpoint, headers=headers)
            
            if response.status_code == 200:
                stats = response.json()['data']['attributes']['last_analysis_stats']
                
                print(f"\n[+] Safe : {stats['harmless']}")
                print(f"[!] Suspect : {stats['suspicious']}")
                print(f"[X] Malveillant : {stats['malicious']}")

                if stats['malicious'] > 0:
                    print("\n[!!!] VERDICT : DANGEREUX !")
                else:
                    print("\n[V] VERDICT : LÉGITIME.")
            else:
                print(f"[!] Erreur API ({response.status_code}) : URL non trouvée ou clé invalide.")
                
        except Exception as e:
            print(f"[!] Erreur lors de l'analyse URL : {e}")