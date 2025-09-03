import json
from pathlib import Path
import subprocess
from prompts import cot_prompt


# Necessary Paths 
ROOT = Path(__file__).resolve().parents[1] # Root directory
dataset  = ROOT / "LogicBench-BQA-bidirectional.json"
llama = ROOT / "runtime"  / "llama.exe"
# model    = ROOT / "models"   / "mistral-7b-v0.1.Q4_K_M.gguf" # Model
model    = ROOT / "models"   / "mistral-7b-instruct-v0.1.Q4_K_M.gguf" # Model
# out_dir = ROOT / "traces" / "instruct" / "basic" # Directory to store model outputs
out_dir = ROOT / "traces" / "instruct" / "cot" # Directory to store model outputs

out_dir.mkdir(parents=True, exist_ok=True)

data = json.load(open(dataset)) # Dataset

for sample in data["samples"]:
    sid = f"{sample['id']:03d}"
    context = sample["context"]
    for i, pair in enumerate(sample["qa_pairs"]):
        qid = f"q{i+1}"
        question = pair["question"]

        # prompts for base model
        # prompt = f"Context: {context}\nQuestion: {question}.\nRespond only either \"Yes\" or \"No\".\nFINAL ANSWER:"
        # prompt = f"{cot_prompt}\nContext: {context}\nQuestion: {question}.\nLet's think step by step.\nThought: "
        
        # prompts for instruct model
        # prompt = f"[INST] Context: {context}\nQuestion: {question}.\nRespond only either \"Yes\" or \"No\".\nFINAL ANSWER: [/INST]"
        prompt = f"[INST]{cot_prompt}\nContext: {context}\nQuestion: {question}.\nLet's think step by step.\nThought: [/INST]"

        # Run llama.exe with mistral model
        llama_cmd = [
            str(llama),
            "-m", str(model),
            "-p", prompt,
            "--n-predict", "300", # 300 base, 500 expanded
            "--temp", "0.0",
            "--top-k", "1",
            "-s", "2025",
            "-r", "//end of example"
        ]

        # print("\n=== SENDING PROMPT TO MODEL ===\n", prompt)
        result = subprocess.run(llama_cmd, capture_output=True, text=True)

        # Check if the process failed (returncode is not 0)
        if result.returncode != 0:
            print(f"--- Llama.exe failed for qid: {qid} ---")
            print(f"Return Code: {result.returncode}")
            print("\n--- STDERR ---")
            print(result.stderr)
            # Raising an error here will stop the script so you can see the problem
            raise RuntimeError("Llama.exe process failed. See STDERR output above.")

        output = result.stdout.strip()
        if not output:
            print(f"--- Llama.exe ran successfully but produced no output for qid: {qid} ---")
            # It's still useful to print stderr in this case
            print("\n--- STDERR ---")
            print(result.stderr)
            raise RuntimeError("Model returned empty output despite a successful run.")
        fname = out_dir / f"{sid}_{qid}.txt"
        with fname.open("w", encoding="utf-8") as f:
            f.write(output)

