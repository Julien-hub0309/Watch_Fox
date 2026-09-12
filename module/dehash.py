import hashlib
import time
import string
from itertools import product

class HashCracker:
    def __init__(self, hash_to_crack):
        self.hash_to_crack = hash_to_crack.strip().lower()
        self.algorithm = self.identify_hash_type()
        # Configuration par défaut pour l'intégration GUI
        self.charset = string.ascii_lowercase + string.digits
        self.max_brute_length = 5 # Limité pour éviter de bloquer le thread trop longtemps

    def identify_hash_type(self):
        """Identifie l'algo selon la longueur du hash"""
        length = len(self.hash_to_crack)
        if length == 32: return "md5"
        elif length == 40: return "sha1"
        elif length == 64: return "sha256"
        elif length == 128: return "sha512"
        return None

    def hash_password(self, password):
        """Hash un mot de passe avec l'algorithme détecté"""
        if self.algorithm == 'md5':
            return hashlib.md5(password.encode()).hexdigest()
        elif self.algorithm == 'sha1':
            return hashlib.sha1(password.encode()).hexdigest()
        elif self.algorithm == 'sha256':
            return hashlib.sha256(password.encode()).hexdigest()
        elif self.algorithm == 'sha512':
            return hashlib.sha512(password.encode()).hexdigest()
        return None

    def run_scan(self):
        """Méthode principale appelée par main.py"""
        if not self.algorithm:
            print("[!] Format de hash inconnu (MD5, SHA1, SHA256, SHA512 supportés).")
            return

        print(f"[*] DÉBUT DÉHASHAGE [{self.algorithm.upper()}]")
        print(f"[*] Cible : {self.hash_to_crack}")
        
        start_time = time.time()
        
        # 1. Tentative rapide par dictionnaire (si tu as un fichier wordlist.txt)
        # Ici on simule une vérification de mots communs pour l'exemple
        common_pass = ["admin", "password", "123456", "root", "qwerty"]
        for word in common_pass:
            if self.hash_password(word) == self.hash_to_crack:
                print(f"\n[+] MATCH TROUVÉ (Common) : {word}")
                print(f"[+] Temps : {time.time() - start_time:.2f}s")
                return

        # 2. Attaque Brute Force (limitée pour la GUI)
        print(f"[*] Brute force en cours (max {self.max_brute_length} chars)...")
        
        found = False
        for length in range(1, self.max_brute_length + 1):
            if found: break
            for attempt in product(self.charset, repeat=length):
                candidate = ''.join(attempt)
                if self.hash_password(candidate) == self.hash_to_crack:
                    print(f"\n[+] MATCH TROUVÉ : {candidate}")
                    found = True
                    break
        
        elapsed = time.time() - start_time
        if found:
            print(f"[+] Terminé en {elapsed:.2f} secondes.")
        else:
            print(f"\n[!] Échec : Mot de passe non trouvé (max {self.max_brute_length} chars).")