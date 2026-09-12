import math
import secrets
import string

class PasswordAnalyzer:
    def __init__(self, target=None):
        # target contient le mot de passe saisi dans la barre de recherche du GUI
        self.target = target

    def generer_robuste(self, longueur=16):
        """Génère un mot de passe fort si celui testé est trop faible"""
        caracteres = string.ascii_letters + string.digits + string.punctuation
        while True:
            mdp = ''.join(secrets.choice(caracteres) for _ in range(longueur))
            if (any(c.islower() for c in mdp) and any(c.isupper() for c in mdp)
                and any(c.isdigit() for c in mdp) and any(c in string.punctuation for c in mdp)):
                return mdp

    def evaluer(self, mdp):
        """Calcule l'entropie et le temps estimé de crackage"""
        jeu = 0
        if any(c.islower() for c in mdp): jeu += 26
        if any(c.isupper() for c in mdp): jeu += 26
        if any(c.isdigit() for c in mdp): jeu += 10
        if any(c in string.punctuation for c in mdp): jeu += 32
        
        longueur = len(mdp)
        entropie = longueur * math.log2(jeu) if jeu > 0 else 0
        # Estimation basée sur 10 milliards de tentatives par seconde
        tentatives_par_seconde = 10_000_000_000
        secondes = (jeu ** longueur) / tentatives_par_seconde if jeu > 0 else 0
        return {"entropie": entropie, "temps": secondes}

    def run_scan(self):
        """Exécution de la logique d'analyse pour le thread principal"""
        if not self.target:
            print("[!] Aucun mot de passe à analyser.")
            return

        print(f"[*] ANALYSE DE SÉCURITÉ DU MOT DE PASSE")
        print("-" * 40)
        
        analyse = self.evaluer(self.target)
        print(f"[>] Entropie : {analyse['entropie']:.2f} bits")
        
        # Formatage du temps de crackage estimé
        t = analyse['temps']
        if t < 60: temps_str = f"{t:.2f} secondes"
        elif t < 3600: temps_str = f"{t/60:.2f} minutes"
        elif t < 86400: temps_str = f"{t/3600:.2f} heures"
        else: temps_str = f"{t/86400:.0f} jours"

        print(f"[>] Temps de crackage estimé : ~{temps_str}")

        if analyse['entropie'] < 60:
            print("\n[!] VERDICT : SÉCURITÉ INSUFFISANTE")
            suggestion = self.generer_robuste()
            print(f"[+] Suggestion robuste : {suggestion}")
        else:
            print("\n[V] VERDICT : MOT DE PASSE ROBUSTE")