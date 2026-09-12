import torch
from transformers import GPT2LMHeadModel, GPT2Tokenizer
import os

class IADetector:
    def __init__(self, file_path):
        # Nettoyage du chemin du fichier (cas des drag & drop avec guillemets)
        self.file_path = file_path.replace('"', '').replace("'", "").strip()
        self.model_id = "gpt2"

    def calculate_ai_score(self, text, model, tokenizer):
        """Calcule la perplexité du texte (plus elle est basse, plus l'IA est probable)"""
        encodings = tokenizer(text, return_tensors="pt")
        max_length = model.config.n_positions
        stride = 512
        nlls = []
        
        for i in range(0, encodings.input_ids.size(1), stride):
            begin_loc = max(i + stride - max_length, 0)
            end_loc = min(i + stride, encodings.input_ids.size(1))
            trg_len = end_loc - i
            input_ids = encodings.input_ids[:, begin_loc:end_loc]
            target_ids = input_ids.clone()
            target_ids[:, :-trg_len] = -100
            
            with torch.no_grad():
                outputs = model(input_ids, labels=target_ids)
                neg_log_likelihood = outputs.loss * trg_len
            nlls.append(neg_log_likelihood)
            
        return torch.exp(torch.stack(nlls).sum() / end_loc).item()

    def run_scan(self):
        """Logique principale exécutée dans le thread de main.py"""
        if not os.path.exists(self.file_path):
            print(f"[!] Fichier introuvable : {self.file_path}")
            return

        try:
            with open(self.file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except Exception as e:
            print(f"[!] Erreur de lecture : {e}")
            return

        if len(content.strip()) < 10:
            print("[!] Contenu trop court pour une analyse fiable.")
            return

        print("[*] Initialisation de l'IA (chargement GPT-2)...")
        try:
            # Note : Le premier lancement téléchargera le modèle (~500MB)
            model = GPT2LMHeadModel.from_pretrained(self.model_id)
            tokenizer = GPT2Tokenizer.from_pretrained(self.model_id)
            
            print("[*] Analyse de perplexité en cours...")
            score = self.calculate_ai_score(content, model, tokenizer)

            print(f"\n[+] SCORE DE PERPLEXITÉ : {score:.2f}")
            
            if score < 25:
                print("[!!!] VERDICT : GÉNÉRÉ PAR IA (Très probable)")
            elif score < 50:
                print("[!] VERDICT : SUSPECT (Aide IA probable)")
            else:
                print("[V] VERDICT : HUMAIN (Légitime)")
                
        except Exception as e:
            print(f"[!] Erreur lors de l'analyse IA : {e}")