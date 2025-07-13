import os
import io
from PyPDF2 import PdfReader
from sentence_transformers import SentenceTransformer
from dotenv import load_dotenv
import faiss
import numpy as np
import google.generativeai as genai
from collections import deque
from sklearn.metrics.pairwise import cosine_similarity

# ---------- Setup ----------
load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# Load models
embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
gemini_model = genai.GenerativeModel('gemini-1.5-flash')

# Short-Term Memory
memory = deque(maxlen=7)

# ---------- PDF Text Extraction ----------
def extract_text_from_pdf_bytes(pdf_bytes):
    reader = PdfReader(pdf_bytes)
    text = ""
    for page in reader.pages:
        if page.extract_text():
            text += page.extract_text()
    return text

def chunk_text(text, chunk_size=300):
    sentences = text.split('. ')
    chunks = []
    chunk = ""
    for sentence in sentences:
        if len(chunk) + len(sentence) < chunk_size:
            chunk += sentence + ". "
        else:
            chunks.append(chunk.strip())
            chunk = sentence + ". "
    if chunk:
        chunks.append(chunk.strip())
    return chunks

# ---------- FAISS Setup ----------
def create_faiss_index(chunks):
    embeddings = embedding_model.encode(chunks)
    dim = embeddings.shape[1]
    index = faiss.IndexFlatL2(dim)
    index.add(np.array(embeddings))
    return index, chunks

def retrieve_relevant_chunks(query, index, chunks, top_k=3, relevance_threshold=0.5):
    query_embedding = embedding_model.encode([query])
    D, I = index.search(np.array(query_embedding), top_k)

    relevant_chunks = []
    for i in I[0]:
        chunk = chunks[i]
        chunk_embedding = embedding_model.encode([chunk])
        similarity = cosine_similarity(query_embedding, chunk_embedding)[0][0]
        if similarity >= relevance_threshold:
            relevant_chunks.append(chunk)
    return relevant_chunks

# ---------- Gemini Answering ----------
def ask_question_with_rag(query, index, chunks):
    retrieved = retrieve_relevant_chunks(query, index, chunks)
    context = "\n\n".join(retrieved).strip()
    use_context = len(retrieved) > 0

    memory_context = "\n".join([f"User: {q}\nAI: {a}" for q, a in memory])

    prompt = f"""
You are a helpful and knowledgeable financial assistant AI.

Context from document:
{context if use_context else "No relevant context found in uploaded documents."}

Previous Conversation:
{memory_context}

User: {query}
AI:"""

    try:
        response = gemini_model.generate_content(prompt)
        answer = response.text.strip()
    except Exception as e:
        answer = f"[❌ Gemini Error] {str(e)}"

    memory.append((query, answer))
    return answer


# ---------- Final Exported Functions ----------

def run_qa_gemini(pdf_bytes: bytes, question: str) -> str:
    try:
        pdf_file_like = io.BytesIO(pdf_bytes)
        text = extract_text_from_pdf_bytes(pdf_file_like)  # ✅ fixed
        chunks = chunk_text(text)
        index, chunk_store = create_faiss_index(chunks)
        return ask_question_with_rag(question, index, chunk_store)
    except Exception as e:
        return f"[❌ QA Error]: {str(e)}"

def run_qa_from_text_gemini(context: str, question: str) -> str:
    try:
        chunks = chunk_text(context)
        index, chunk_store = create_faiss_index(chunks)
        return ask_question_with_rag(question, index, chunk_store)
    except Exception as e:
        return f"[❌ QA (text) Error]: {str(e)}"
