# backend/usecases/qa.py

import os
from io import BytesIO
from pathlib import Path
from dotenv import load_dotenv
from PyPDF2 import PdfReader
from sentence_transformers import SentenceTransformer
from transformers import T5ForConditionalGeneration, T5Tokenizer
import torch
import faiss

# ─── Load .env (Optional, in case you store model path or debug flag) ───
env_path = Path(__file__).resolve().parents[1] / ".env"
load_dotenv(dotenv_path=env_path)

# ─── Load T5-small Model ───
model = T5ForConditionalGeneration.from_pretrained("t5-small")
tokenizer = T5Tokenizer.from_pretrained("t5-small")

# ─── Sentence Embedding Model ───
embedder = SentenceTransformer("all-MiniLM-L6-v2")

# ─── PDF Text Extraction ───
def extract_text_from_pdf_bytes(pdf_bytes: bytes) -> str:
    reader = PdfReader(BytesIO(pdf_bytes))
    text = ""
    for page in reader.pages:
        content = page.extract_text()
        if content:
            text += content
    return text.strip()

# ─── Chunking ───
def chunk_text(text: str, chunk_size=500):
    return [text[i:i + chunk_size] for i in range(0, len(text), chunk_size)]

# ─── FAISS Indexing ───
def create_faiss_index(chunks):
    vectors = embedder.encode(chunks)
    index = faiss.IndexFlatL2(vectors.shape[1])
    index.add(vectors)
    return {"index": index, "chunks": chunks, "vectors": vectors}

def retrieve_top_chunks(question: str, db, top_k=3):
    q_vec = embedder.encode([question])
    _, I = db["index"].search(q_vec, top_k)
    return "\n".join([db["chunks"][i] for i in I[0]])

# ─── T5-based Answer Generation ───
def ask_t5_with_context(question: str, context: str) -> str:
    prompt = f"question: {question} context: {context}"
    inputs = tokenizer(prompt, return_tensors="pt", truncation=True)
    outputs = model.generate(inputs["input_ids"], max_length=256)
    return tokenizer.decode(outputs[0], skip_special_tokens=True)

# ─── From PDF ───
def run_qa_pdf_t5(pdf_bytes: bytes, question: str) -> str:
    try:
        text = extract_text_from_pdf_bytes(pdf_bytes)
        chunks = chunk_text(text)
        db = create_faiss_index(chunks)
        context = retrieve_top_chunks(question, db)
        answer = ask_t5_with_context(question, context)
        return answer
    except Exception as e:
        return f"❌ Error during Q&A (PDF): {str(e)}"

# ─── From Raw Text ───
def run_qa_text_t5(text: str, question: str) -> str:
    try:
        chunks = chunk_text(text)
        db = create_faiss_index(chunks)
        context = retrieve_top_chunks(question, db)
        answer = ask_t5_with_context(question, context)
        return answer
    except Exception as e:
        return f"❌ Error during Q&A (Text): {str(e)}"