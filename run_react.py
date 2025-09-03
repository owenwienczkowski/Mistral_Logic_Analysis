import json
from pathlib import Path
import subprocess
import re

# --- Main script setup ---
ROOT = Path(__file__).resolve().parent.parent
dataset_path = ROOT / "LogicBench-BQA-bidirectional.json"
llama_executable = ROOT / "runtime" / "llama.exe"
prover9_executable = ROOT / "runtime" / "prover9.exe"

model_path = ROOT / "models"   / "mistral-7b-v0.1.Q4_K_M.gguf"
# model_path = ROOT / "models"   / "mistral-7b-instruct-v0.1.Q4_K_M.gguf"
out_dir = ROOT / "traces" / "base" / "ReAct"
prover_files_dir = out_dir / "prover_files"
out_dir.mkdir(parents=True, exist_ok=True)
prover_files_dir.mkdir(parents=True, exist_ok=True)

from prompts import react_prompt, react_prompt_template, react_prompt_template_instruct

def extract_prover_input(model_output: str) -> str | None:
    """Extracts the Prover9 input block from the model's output."""
    match = re.search(r"BEGIN_PROVER9_INPUT(.*?)END_PROVER9_INPUT", model_output, re.DOTALL)
    if match:
        return match.group(1).strip()
    return None

def run_prover(prover_input_str: str, qid: str) -> str:
    """
    Runs prover9.exe on the given input string and returns the result.
    Saves prover input and output to a dedicated subdirectory for organization.
    """
    input_filename = prover_files_dir / f"{qid}_prover.in"
    output_filename = prover_files_dir / f"{qid}_prover.out"
    
    with open(input_filename, "w", encoding="utf-8") as f:
        f.write(prover_input_str)

    prover_cmd = [str(prover9_executable), "-f", str(input_filename)]
    
    try:
        result = subprocess.run(prover_cmd, capture_output=True, text=True, timeout=15)
        with open(output_filename, "w", encoding="utf-8") as f:
            f.write(result.stdout)
        
        if "THEOREM PROVED" in result.stdout:
            return "PROVED"
        elif "SEARCH FAILED" in result.stdout:
            return "FAILED"
        else:
            # Handle cases where Prover9 exits unexpectedly
            print(f"  -> Prover9 produced an unexpected output for {qid}.")
            return "ERROR"
            
    except subprocess.TimeoutExpired as e:
        print(f"  -> Prover9 timed out for {qid}: {e}")
        with open(output_filename, "w", encoding="utf-8") as f:
            f.write(f"PROVER9 TIMEOUT\n\n{e}")
        return "ERROR"
    
def run_llama(prompt_text: str, n_predict=500, stop_sequence=None):
    llama_cmd = [
        str(llama_executable),
        "-m", str(model_path),
        "-p", prompt_text,
        
        "--n-predict", str(n_predict), # This can be changed for each call
        "--temp", "0.0",
        "--top-k", "1",                
        "-s", "2025"                 
    ]
    
    # adds the stop sequence, which is different for Step 1 and Step 3
    if stop_sequence:
        llama_cmd.extend(["-r", stop_sequence])

    result = subprocess.run(llama_cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        print(f"--- Llama.exe failed with return code: {result.returncode} ---")
        print("--- STDERR ---")
        print(result.stderr)
    return result.stdout

data = json.load(open(dataset_path))

# --- Main execution loop ---
for sample in data["samples"]:
    sid = f"{sample['id']:03d}"
    context = sample["context"]
    for i, pair in enumerate(sample["qa_pairs"]):
        qid = f"{sid}_q{i+1}"
        question = pair["question"]
        full_trace_fname = out_dir / f"{qid}_full_trace.txt"

        if full_trace_fname.exists():
            print(f"Skipping already completed {qid}")
            continue

        print(f"\n=== PROCESSING {qid} ===")

        # --- STEP 1: Generate the Thought and Action ---
        print("  Step 1: Generating formal logic action...")
        # prompt1 = f"{react_prompt}\n\nContext: {context}\nQuestion: {question}\nLet's think step by step.\n"
        prompt1 = f"[INST]{react_prompt}\n\nContext: {context}\nQuestion: {question}\nLet's think step by step.\nThought:[/INST]"

        
        raw_step1_output = run_llama(prompt1, n_predict=1024, stop_sequence="END_PROVER9_INPUT")
        
        if prompt1 in raw_step1_output:
            model_generation = raw_step1_output.split(prompt1, 1)[1]
        else:
            model_generation = raw_step1_output

        model_thought_and_action = f"{model_generation}END_PROVER9_INPUT"

        prover_input = extract_prover_input(model_thought_and_action)
        
        if not prover_input:
            print(f"  -> FAILED: Model did not generate a valid Prover9 block for {qid}.")
            with open(full_trace_fname, "w", encoding="utf-8") as f:
                f.write(f"--- STEP 1 FAILED ---\n{model_thought_and_action}")
            continue
        
        print(f"  ... Extracted Prover Input:\n---\n{prover_input}\n---")

        # --- STEP 2: Run Prover and get Observation ---
        print(f"  Step 2: Running Prover9 for {qid}...")
        observation = run_prover(prover_input, qid)
        
        if observation == "ERROR":
            print(f"  -> FAILED: Prover9 encountered an error for {qid}.")
            with open(full_trace_fname, "w", encoding="utf-8") as f:
                f.write(f"--- STEP 2 FAILED (Prover Error) ---\n{model_thought_and_action}")
            continue

        # --- STEP 3: Generate Final Answer --- 
        if model_path == (ROOT / "models"   / "mistral-7b-instruct-v0.1.Q4_K_M.gguf"):
            template = react_prompt_template_instruct
        else:
            template = react_prompt_template

        print(f"  Step 3: Generating final answer with observation: {observation}...")
        prompt2 = template.format(
            model_step1_output=model_thought_and_action,
            observation=observation
        )
        
        raw_step2_output = run_llama(prompt2, n_predict=100)
        
        if prompt2 in raw_step2_output:
            step2_generation = raw_step2_output.split(prompt2, 1)[1]
        else:
            step2_generation = raw_step2_output

        final_trace = f"{model_thought_and_action}\nObservation: {observation}\nThought: The prover result was {observation}.\nFINAL ANSWER:{step2_generation}"

        with open(full_trace_fname, "w", encoding="utf-8") as f:
            f.write(final_trace)
        
        print(f"  -> Successfully processed and saved {qid}")

print("\n--- Automated Two-Step ReAct Generation Complete ---")
