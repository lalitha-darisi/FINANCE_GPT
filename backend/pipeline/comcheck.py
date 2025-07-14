# backend/usecases/comcheck.py
import os
import re
import json
import faiss
import fitz
import torch
import google.generativeai as genai
from io import BytesIO
from typing import List, Union
from datetime import datetime
from sentence_transformers import SentenceTransformer
from models.db import compliance_collection
from dotenv import load_dotenv
from pathlib import Path
from pipeline.travel import TRAVEL_POLICIES



backend_dir = Path(__file__).resolve().parent.parent
env_path = backend_dir / ".env"
load_dotenv(dotenv_path=env_path)

api_key = os.getenv("GEMINI_API_KEY")
print("✅ API KEY loaded.")
if not api_key:
    raise ValueError("GEMINI_API_KEY not set in environment.")
genai.configure(api_key=api_key)

gemini = genai.GenerativeModel("gemini-1.5-flash")

# Embedder and FAISS
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
EMBEDDER = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2", device=DEVICE)

# Define TRAVEL_POLICIES (import from another file or paste inline)


policy_texts = [p["policy"] for p in TRAVEL_POLICIES]
policy_embeds = EMBEDDER.encode(policy_texts, convert_to_numpy=True, normalize_embeddings=True)
INDEX = faiss.IndexFlatIP(policy_embeds.shape[1])
INDEX.add(policy_embeds)

CITY_TO_TIER = {
    "Delhi": "Tier 1", "Mumbai": "Tier 1", "Bangalore": "Tier 1", "Hyderabad": "Tier 2",
    "Pune": "Tier 2", "Chennai": "Tier 1", "Kolkata": "Tier 1", "Ahmedabad": "Tier 2",
    "Indore": "Tier 2", "Jaipur": "Tier 2", "Coimbatore": "Tier 3", "Mysore": "Tier 3",
    "Patna": "Tier 3", "Nagpur": "Tier 3", "Lucknow": "Tier 2", "Bhopal": "Tier 3", "Guwahati": "Tier 3"
}

def extract_text_from_bytes(pdf_bytes: bytes) -> str:
    with fitz.open("pdf", pdf_bytes) as doc:
        return " ".join(p.get_text() for p in doc if p.get_text()).strip()

def split_claims(text: str) -> List[str]:
    return [f"Claim: {s.strip()}" for s in re.split(r"(?i)\bclaim\s*:", text) if s.strip()]

def add_city_tier(claim: str) -> str:
    for city, tier in CITY_TO_TIER.items():
        if city.lower() in claim.lower():
            return f"{claim}\n\nDetected city: {city} → {tier}."
    return claim

def top_k_policies(claim: str, k=2) -> List[dict]:
    q_emb = EMBEDDER.encode([claim], convert_to_numpy=True, normalize_embeddings=True)
    _, idx = INDEX.search(q_emb, k)
    return [TRAVEL_POLICIES[i] for i in idx[0]]

def gemini_classify(claim: str, policies: List[dict]) -> str:
    p1, p2 = policies
    prompt = (
        "You are a travel policy compliance assistant.\n\n"
        f"Claim:\n{claim}\n\n"
        f"[{p1['category']}]\n{p1['policy']}\n\n"
        f"[{p2['category']}]\n{p2['policy']}\n\n"
        "Return exactly two lines:\n"
        "• Compliance: <Compliant | Non‑Compliant>\n"
        "• Reasoning: <one concise sentence>"
    )
    return gemini.generate_content(prompt).text.strip()

# 💡 Final callable for FastAPI

async def run_compliance_check_gemini(content: Union[bytes, str], user_id: str, is_raw_text: bool = False):
    try:
        # Step 1: Get plain text
        text = content if is_raw_text else extract_text_from_bytes(content)

        # Step 2: Split text into individual claims
        claims = split_claims(text)

        results = []

        for raw in claims:
            claim = add_city_tier(raw)
            top_pols = top_k_policies(claim)
            result_text = gemini_classify(claim, top_pols)

            lines = result_text.strip().splitlines()
            classification_line = next((line for line in lines if "compliance" in line.lower()), "")
            reasoning_line = next((line for line in lines if "reasoning" in line.lower()), "")

            classification = "Non-Compliant" if "non-compliant" in classification_line.lower() else "Compliant"
            reasoning = (
                reasoning_line.split(":", 1)[1].strip()
                if ":" in reasoning_line else "No reasoning provided."
            )

            result = {
                "claim": claim,
                "classification": classification,
                "reasoning": reasoning,
                "matched_policies": [p["category"] for p in top_pols]
            }

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

