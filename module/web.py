import socket
import urllib.request
import json
from core.base import JustradamusModule
from utile.display import console

class WebScanner(JustradamusModule):
    def scan_infra(self):
        console.print("[>] WEB / IP INFRASTRUCTURE SCAN")
        console.print(f"Cible : {self.target}")
        console.print("-" * 40)

        results = {}
        try:
            # --- Résolution IP ---
            ip = socket.gethostbyname(self.target)
            results["IP"] = ip
            console.print(f"[+] IP résolue : {ip}")

            # --- Géolocalisation ---
            try:
                req = urllib.request.Request(
                    f"http://ip-api.com/json/{ip}",
                    headers={'User-Agent': 'Mozilla/5.0'}
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    geo = json.loads(resp.read().decode())
                    if geo.get("status") == "success":
                        localisation = f"{geo.get('city')}, {geo.get('country')}"
                        isp          = geo.get("isp", "Inconnu")
                        org          = geo.get("org", "Inconnu")
                        results["Localisation"] = localisation
                        results["ISP"]          = isp
                        results["Organisation"] = org
                        console.print(f"[+] Localisation  : {localisation}")
                        console.print(f"[+] ISP           : {isp}")
                        console.print(f"[+] Organisation  : {org}")
                    else:
                        results["Localisation"] = "Erreur API Géo"
                        console.print("[!] Géolocalisation : Echec API")
            except Exception:
                results["Localisation"] = "Erreur API Géo"
                console.print("[!] Géolocalisation : Timeout/Erreur")

            # --- Scan de ports ---
            console.print("Scan des ports en cours...")
            open_ports = []
            for port in [21, 22, 80, 443, 8080]:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    s.settimeout(0.5)
                    if s.connect_ex((ip, port)) == 0:
                        open_ports.append(port)
                        console.print(f"[+] Port {port} : OUVERT")

            ports_str = ", ".join(map(str, open_ports)) if open_ports else "Aucun"
            results["Ports_Ouverts"] = ports_str

            if not open_ports:
                console.print("[!] Aucun port commun ouvert détecté")

            console.print("-" * 40)

            self.save_finding("Web_Infra", results)
            self.display_results("Infrastructure Web", results)

        except socket.gaierror:
            console.print(f"[!] Impossible de résoudre le domaine : {self.target}")
        except Exception as e:
            console.print(f"[!] Erreur Web : {e}")