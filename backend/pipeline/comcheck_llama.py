import os
import re
import faiss
import fitz
import torch
import sys
import json
from pathlib import Path
from typing import List, Union
from datetime import datetime

# ✅ Fix path so models/ and pipeline/ are importable
backend_root = Path(__file__).resolve().parent.parent
sys.path.append(str(backend_root))

from sentence_transformers import SentenceTransformer
from models.db import compliance_collection
from pipeline.travel import TRAVEL_POLICIES
from transformers import AutoTokenizer, AutoModelForCausalLM

# === Load TinyLLaMA fine-tuned model ===
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
MODEL_ID = "lalithadarisi/tinyllama-compliance-merged"

tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, cache_dir="D:/hf_cache")
model = AutoModelForCausalLM.from_pretrained(MODEL_ID, cache_dir="D:/hf_cache")
model.to(DEVICE)

print("✅ TinyLLaMA model loaded successfully on", DEVICE)

# === FAISS policy index setup ===
EMBEDDER = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2", device=DEVICE)
policy_texts = [p["policy"] for p in TRAVEL_POLICIES]
policy_embeds = EMBEDDER.encode(policy_texts, convert_to_numpy=True, normalize_embeddings=True)
INDEX = faiss.IndexFlatIP(policy_embeds.shape[1])
INDEX.add(policy_embeds)

# === City-tier mapping ===
CITY_TO_TIER = {
    "Delhi": "Tier 1", "Mumbai": "Tier 1", "Bangalore": "Tier 1", "Hyderabad": "Tier 2",
    "Pune": "Tier 2", "Chennai": "Tier 1", "Kolkata": "Tier 1", "Ahmedabad": "Tier 2",
    "Indore": "Tier 2", "Jaipur": "Tier 2", "Coimbatore": "Tier 3", "Mysore": "Tier 3",
    "Patna": "Tier 3", "Nagpur": "Tier 3", "Lucknow": "Tier 2", "Bhopal": "Tier 3", "Guwahati": "Tier 3"
}

# === Utility functions ===
def extract_text_from_bytes(pdf_bytes: bytes) -> str:
    with fitz.open("pdf", pdf_bytes) as doc:
        return " ".join(p.get_text() for p in doc if p.get_text()).strip()

def split_claims(text: str) -> List[str]:
    return [f"{s.strip()}" for s in re.split(r"(?i)\bclaim\s*:", text) if s.strip()]

def add_city_tier(claim: str) -> str:
    for city, tier in CITY_TO_TIER.items():
        if city.lower() in claim.lower():
            return f"{claim} (City Tier: {tier})"
    return claim

def top_k_policies(claim: str, k=2) -> List[dict]:
    q_emb = EMBEDDER.encode([claim], convert_to_numpy=True, normalize_embeddings=True)
    _, idx = INDEX.search(q_emb, k)
    return [TRAVEL_POLICIES[i] for i in idx[0]]

def correct_conflicting_label(label: str, reasoning: str) -> str:
    if "non-compliant" in reasoning.lower() and label == "Compliant":
        return "Non-Compliant"
    if "compliant" in reasoning.lower() and label == "Non-Compliant":
        return "Compliant"
    return label

def parse_classification(result_text: str) -> tuple[str, str]:
    match = re.search(r"classification\s*[:\-]*\s*(compliant|non-compliant)", result_text, re.IGNORECASE)
    classification = match.group(1).capitalize() if match else "Unknown"
    return classification, result_text



def extract_reasoning(text: str) -> str:
    match = re.search(r"reasoning[\s:\-–.]*([\s\S]+)", text, re.IGNORECASE)
    if match:
        reasoning = match.group(1).strip()
        lines = [line.strip() for line in reasoning.splitlines() if line.strip()]
        seen = set()
        unique_lines = []
        for line in lines:
            if line not in seen:
                seen.add(line)
                unique_lines.append(line)
        return " ".join(unique_lines)
    return "No reasoning provided."

# === Model inference ===
def llama_classify(claim: str) -> str:
    prompt = (
        "You are a travel compliance expert. Review the claim and respond in the following format ONLY:\n\n"
        "Classification: [Compliant / Non-Compliant]\n"
        "Reasoning: <Concise explanation based strictly on travel policy>\n\n"
        f"Claim: {claim}\n\n"
        "Classification:"
    )
    inputs = tokenizer(prompt, return_tensors="pt").to(DEVICE)
    outputs = model.generate(
        **inputs,
        max_new_tokens=150,
        do_sample=False,
        eos_token_id=tokenizer.eos_token_id,
        pad_token_id=tokenizer.pad_token_id,
    )
    return tokenizer.decode(outputs[0], skip_special_tokens=True).strip()


# === Main compliance check function ===
async def run_compliance_check_llama(content: Union[bytes, str], user_id: str, is_raw_text: bool = False):
    try:
        text = content if is_raw_text else extract_text_from_bytes(content)
        claims = split_claims(text)

        results = []

        for raw_claim in claims:
            claim = add_city_tier(raw_claim)
            top_pols = top_k_policies(claim)
            result_text = llama_classify(claim)

            # === Parse result ===
            classification, reasoning_text = parse_classification(result_text)
            reasoning = extract_reasoning(reasoning_text)
            classification = correct_conflicting_label(classification, reasoning)

            result = {
                "claim": claim,
                "classification": classification,
                "reasoning": reasoning,
                "matched_policies": [p["category"] for p in top_pols]
            }

            # Store in DB
            await compliance_collection.insert_one({
                "user_id": user_id,
                "timestamp": datetime.utcnow(),
                "claim_text": result["claim"],
                "compliant": result["classification"].lower() == "compliant",
                "reasoning": result["reasoning"],
                "matched_policies": result["matched_policies"]
            })

            results.append(result)

        return {"results": results}

    except Exception as e:
        import traceback
        traceback.print_exc()
        return {"results": [{
            "claim": "Unknown",
            "classification": "Error",
            "reasoning": f"❌ Exception: {str(e)}",
            "matched_policies": []
        }]}
