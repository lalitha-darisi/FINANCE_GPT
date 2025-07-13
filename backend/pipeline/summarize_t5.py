import torch
import os
import numpy as np
import faiss
from typing import List
from transformers import T5Tokenizer, T5ForConditionalGeneration
from sentence_transformers import SentenceTransformer
import PyPDF2

# === Load models ===
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
tokenizer = T5Tokenizer.from_pretrained("t5-base")
model = T5ForConditionalGeneration.from_pretrained("t5-base").to(device)
embedding_model = SentenceTransformer("all-MiniLM-L6-v2")

# === Step 1: Extract text from PDF ===
def extract_text_from_pdf(pdf_path: str) -> str:
    text = ""
    with open(pdf_path, "rb") as file:
        reader = PyPDF2.PdfReader(file)
        for page in reader.pages:
            extracted = page.extract_text()
            if extracted:
                text += extracted + "\n"
    return text

# === Step 2: Split text into manageable chunks ===
def split_text(text: str, max_tokens: int = 512) -> List[str]:
    sentences = text.split(". ")
    chunks = []
    current_chunk = ""
    for sentence in sentences:
        if len(tokenizer.encode(current_chunk + sentence, truncation=False)) < max_tokens:
            current_chunk += sentence + ". "
        else:
            chunks.append(current_chunk.strip())
            current_chunk = sentence + ". "
    if current_chunk:
        chunks.append(current_chunk.strip())
    return chunks

# === Step 3: Build FAISS index from chunks ===
def build_faiss_index(chunks: List[str]):
    embeddings = embedding_model.encode(chunks)
    index = faiss.IndexFlatL2(embeddings.shape[1])
    index.add(np.array(embeddings))
    return index, embeddings

# === Step 4: Retrieve relevant chunks ===
def retrieve_relevant_chunks(query: str, chunks: List[str], index, embeddings, top_k: int = 15) -> List[str]:
    query_embedding = embedding_model.encode([query])
    D, I = index.search(query_embedding, top_k)
    return [chunks[i] for i in I[0]]

# === Step 5: Section-wise summarization using T5 ===
def structured_summary_with_sections(chunks: List[str], queries: List[str]) -> str:
    index, embeddings = build_faiss_index(chunks)
    full_summary = ""

    for query in queries:
        relevant_chunks = retrieve_relevant_chunks(query, chunks, index, embeddings, top_k=15)
        sub_summaries = []
        for i in range(0, len(relevant_chunks), 5):
            group = " ".join(relevant_chunks[i:i+5])
            prompt = query + ": " + group.replace("\n", " ")
            inputs = tokenizer(prompt, return_tensors="pt", truncation=True, padding="longest", max_length=512).to(device)
            summary_ids = model.generate(inputs["input_ids"], max_length=512, num_beams=4, length_penalty=2.0, early_stopping=True)
            sub_summary = tokenizer.decode(summary_ids[0], skip_special_tokens=True)
            sub_summaries.append(sub_summary)
        full_summary += f"### {query.capitalize()}\n" + "\n".join(sub_summaries) + "\n\n"

    return full_summary

# === Main pipeline function ===
def summarize_pdf_sectionwise(pdf_path: str) -> str:
    full_text = extract_text_from_pdf(pdf_path)
    chunks = split_text(full_text)

    queries = [
        "summarize the cash flow and capital expenditures information",
        "summarize internal controls over financial reporting",
        "summarize income tax and foreign tax liabilities",
        "summarize the consolidated financial statements and auditor report"
    ]

    return structured_summary_with_sections(chunks, queries)

def summarize_text_sectionwise(text: str) -> str:
    print("🧩 Splitting input text into chunks...")
    chunks = split_text(text)

    print("📚 Running RAG + T5 summarization for multiple sections...")

    queries = [
        "summarize the cash flow and capital expenditures information",
        "summarize internal controls over financial reporting",
        "summarize income tax and foreign tax liabilities",
        "summarize the consolidated financial statements and auditor report"
    ]

    structured_summary = structured_summary_with_sections(chunks, queries)
    return structured_summary
