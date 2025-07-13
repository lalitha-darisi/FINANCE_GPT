#summarize.py
import os
import re
import faiss
import numpy as np
import PyPDF2
import time
from sentence_transformers import SentenceTransformer
import google.generativeai as genai
from dotenv import load_dotenv
from pathlib import Path

# === Load API Key ===
backend_dir = Path(__file__).resolve().parent.parent
env_path = backend_dir / ".env"
load_dotenv(dotenv_path=env_path)

api_key = os.getenv("GEMINI_API_KEY")
print("✅ API KEY loaded.")
if not api_key:
    raise ValueError("GEMINI_API_KEY not set in environment.")
genai.configure(api_key=api_key)

# === Models ===
embedding_model = SentenceTransformer("all-MiniLM-L6-v2")
gemini_model = genai.GenerativeModel("gemini-1.5-flash")

# === Text cleaning ===
def clean_text(text):
    text = re.sub(r"\s+", " ", text)
    return text.strip()

# === PDF extraction ===
def extract_text_from_pdf(pdf_path):
    reader = PyPDF2.PdfReader(pdf_path)
    all_text = ""
    for page in reader.pages:
        page_text = page.extract_text()
        if page_text:
            all_text += page_text
    cleaned = clean_text(all_text)
    if not cleaned:
        raise ValueError("⚠️ PDF text extraction failed.")
    return cleaned

# === Chunking and FAISS indexing ===
def split_into_chunks(text, chunk_size=500):
    words = text.split()
    return [" ".join(words[i:i + chunk_size]) for i in range(0, len(words), chunk_size)]

def build_faiss_index(chunks):
    embeddings = embedding_model.encode(chunks, show_progress_bar=False)
    index = faiss.IndexFlatL2(embeddings.shape[1])
    index.add(np.array(embeddings))
    return index, embeddings

# === Query Map & Prompts ===
QUERY_MAP = {
    "short": "summary of company performance",
    "detailed": "company financials and risks",
    "financial_only": "financial statements overview",
    "risk_only": "risk factors and challenges"
}

PROMPTS = {
    "short": '''
You are a professional financial analyst. Write a crisp, executive-style summary of a company’s annual report that can be read in under a minute.

📝 Format:
- Use 6 to 8 clear bullet points (slightly more detailed than usual)
- Keep it under 500 words
- Avoid technical jargon and long paragraphs

✅ Include:
- Key financial highlights: Revenue, Profit, Cash Flow (only if mentioned)
- Key business updates or major developments
- Major risks or challenges
- Future direction or strategic plans (if available)
- Noteworthy operational, market, or leadership updates

🚫 Do NOT:
- Mention missing data or unavailable sections
- Include tables or detailed analysis

Focus only on what's clearly available in the report. Make it easy for a busy executive to quickly grasp the company's position and direction.

Company Report Excerpts:
{context}
''',

    "detailed": """
You are a senior financial analyst. Write a comprehensive, investor-grade, multi-page summary of the company's annual report. Your summary should aim for 8–10 pages (5000–7000+ words) if the provided context allows. 

📝 Structure:
1. Executive Summary
2. Business Overview & Market Position
3. Products, Services, and Revenue Streams
4. Financial Performance and Key Metrics (Revenue, Profitability, Cash Flow, Assets, Liabilities)
5. Management Discussion and Analysis
6. Risk Factors and Challenges
7. Strategic Initiatives and Future Outlook
8. Noteworthy Events, Leadership Changes, or Developments

✅ Guidelines:
- Target length: 5000–7000 words if enough information is present
- Write in well-structured paragraphs, no bullet points
- Maintain a formal, analytical tone
- Avoid unnecessary repetition
- Do NOT mention missing or unavailable data
- If patterns, trends, or strategic implications are implied, explain them thoroughly
- No tables — use clear, detailed text descriptions

Use ONLY the extracted report content below. Ensure maximum clarity, completeness, and depth.

Extracted Annual Report Content:
{context}
""",

    "financial_only": """
You are a professional finance analyst. Write a precise, structured summary focusing strictly on the company's **financial performance**, based only on the content provided.

✅ Include:
- Revenue and Net Income figures or trends
- Operating margins, profitability indicators (if available)
- Assets and Liabilities overview
- Cash Flow breakdown: Operating, Investing, Financing
- Year-over-year comparisons or financial trends (if mentioned)

⚠ Avoid:
- Business descriptions, risk factors, or strategy discussions
- Mentioning missing or unavailable data
- Overly technical jargon

Present the information in clear, concise paragraphs using plain English. The summary should give a reader a strong understanding of the company's financial health based only on the extracted content.

Extracted Financial Content:
{context}
""",

    "risk_only": """
You are a risk management analyst. Write a detailed summary focused solely on the **Risk Factors** presented in the company's annual report.

Include:
- Strategic, market, legal, environmental, operational risks
- Risk implications on performance or future strategy
- Mention any mitigation plans or risk disclosures

Guidelines:
- Do not include financials or other topics
- Do not write "data missing" — use only the content provided
- Use a structured format or headings if helpful

Extracted Risk-Related Context:
{context}
"""
}

def split_prompt(text, max_len=12000):
    return [text[i:i + max_len] for i in range(0, len(text), max_len)]

# === Summarization logic ===
def generate_summary(input_data, summary_type="detailed", model="gemini", is_text=False):
    if is_text:
        full_text = clean_text(input_data)
    else:
        full_text = extract_text_from_pdf(input_data)

    chunks = split_into_chunks(full_text)
    if not chunks:
        raise ValueError("⚠️ No usable chunks found.")

    index, _ = build_faiss_index(chunks)

    query_text = QUERY_MAP.get(summary_type, "company summary")
    query_embedding = embedding_model.encode([query_text])

    k_value = 60 if summary_type == "detailed" else 5
    D, I = index.search(np.array(query_embedding), k=k_value)
    selected_chunks = [chunks[i] for i in I[0]]
    context = "\n\n".join(selected_chunks)

    prompt_template = PROMPTS.get(summary_type, PROMPTS["detailed"])
    final_prompt = prompt_template.format(context=context)
    prompt_parts = split_prompt(final_prompt)

    result = ""
    if model == "gemini":
        for part in prompt_parts:
            response = gemini_model.generate_content(
                part,
                generation_config=genai.types.GenerationConfig(temperature=0.2, max_output_tokens=4096)
            )
            if response.text:
                result += response.text.strip() + "\n\n"

    elif model == "t5":
        result = "T5 summary logic not implemented yet."

    else:
        raise ValueError(f"Unsupported model: {model}")

    if not result.strip():
        return "⚠️ No summary generated."

    return result.strip()
