import os
from io import BytesIO
from pathlib import Path
from dotenv import load_dotenv
from PyPDF2 import PdfReader
from sentence_transformers import SentenceTransformer
from transformers import T5ForConditionalGeneration, T5Tokenizer
import torch
import faiss
from datetime import datetime
from models.db import qa_collection  # ✅ your friend's style

# ─── Load .env ───
env_path = Path(__file__).resolve().parents[1] / ".env"
load_dotenv(dotenv_path=env_path)

# ─── Load Fine-Tuned T5 QA Model ───
model = T5ForConditionalGeneration.from_pretrained("valhalla/t5-small-qa-qg-hl")
tokenizer = T5Tokenizer.from_pretrained("valhalla/t5-small-qa-qg-hl")

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

# ─── T5 Answer Generation ───
def ask_t5_with_context(question: str, context: str) -> str:
    try:
        prompt = f"question: {question} context: {context}"
        inputs = tokenizer(prompt, return_tensors="pt", truncation=True)
        outputs = model.generate(inputs["input_ids"], max_length=256)
        return tokenizer.decode(outputs[0], skip_special_tokens=True)
    except Exception as e:
        return f"❌ Error generating answer: {str(e)}"

# ─── From PDF ───
async def run_qa_pdf_t5(pdf_bytes: bytes, question: str, user_id: str = None) -> str:
    try:
        text = extract_text_from_pdf_bytes(pdf_bytes)
        chunks = chunk_text(text)
        db = create_faiss_index(chunks)
        top_chunks = retrieve_top_chunks(question, db)
        answer = ask_t5_with_context(question, top_chunks)

        # ─── MongoDB Logging ───
        if user_id:
            await qa_collection.insert_one({
                "user_id": user_id,
                "timestamp": datetime.utcnow(),
                "input_type": "pdf",
                "question": question,
                "context_used": top_chunks,
                "answer": answer
            })

        return answer
    except Exception as e:
        return f"❌ Error during Q&A (PDF): {str(e)}"

# ─── From Raw Text ───
async def run_qa_text_t5(text: str, question: str, user_id: str = None) -> str:
    try:
        chunks = chunk_text(text)
        db = create_faiss_index(chunks)
        top_chunks = retrieve_top_chunks(question, db)
        answer = ask_t5_with_context(question, top_chunks)

        # ─── MongoDB Logging ───
        if user_id:
            await qa_collection.insert_one({
                "user_id": user_id,
                "timestamp": datetime.utcnow(),
                "input_type": "text",
                "question": question,
                "context_used": top_chunks,
                "answer": answer
            })

        return answer
    except Exception as e:
        return f"❌ Error during Q&A (Text): {str(e)}"