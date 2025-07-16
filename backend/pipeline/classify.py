import os
import re
import io
import pytesseract
from pdf2image import convert_from_bytes
from datetime import datetime
from PIL import Image
import google.generativeai as genai
from models.db import classification_collection
from dotenv import load_dotenv
from pathlib import Path
# === Configuration ===
POPPLER_PATH = r"C:\Users\LALITHA\Downloads\Release-24.08.0-0\poppler-24.08.0\Library\bin"
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
backend_dir = Path(__file__).resolve().parent.parent
env_path = backend_dir / ".env"
load_dotenv(dotenv_path=env_path)

api_key = os.getenv("GEMINI_API_KEY")
print("✅ API KEY loaded.")
if not api_key:
    raise ValueError("GEMINI_API_KEY not set in environment.")
genai.configure(api_key=api_key)

gemini = genai.GenerativeModel("gemini-1.5-flash")


LABELS = ["Invoice", "Bill", "Budget", "Tax Document", "Contract", "Utility Bill"]


# === Sensitive Data Masking ===
def mask_sensitive_data(text: str) -> str:
    text = text.encode('ascii', 'ignore').decode('utf-8', 'ignore')
    text = text.replace('\r', '').replace('\n', ' ')
    text = re.sub(r'\s+', ' ', text).strip()

    text = re.sub(r'\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b', 'XXXXX', text)  # Aadhaar
    text = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', 'XXX-XX-XXXX', text)        # SSN
    text = re.sub(r'\+?\d{1,2}[\s\-]?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{4}', 'Phone Number: XXXXX', text)
    text = re.sub(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', 'EMAIL', text)  # Email

    orgs = ['IRS', 'Infosys', 'TCS', 'Wipro', 'HDFC', 'ICICI', 'Deloitte']
    for org in orgs:
        text = re.sub(fr'\b{org}\b', '[ORG]', text, flags=re.IGNORECASE)

    text = re.sub(r'(₹|\$|Rs\.?)\s?\d+[,.]?\d*', 'XXXXX', text)  # Currency
    text = re.sub(r'Name\s*[:\-]?\s*[A-Z][a-z]+\s[A-Z][a-z]+', 'Name: XXXXX', text)

    return text

# === Fallback Classifier ===
def fallback_label(text: str) -> str:
    text = text.lower()
    if "irs form 1040" in text or "tax year" in text or "filing status" in text:
        return "Tax Document"
    if "utility bill" in text:
        return "Utility Bill"
    if "invoice" in text:
        return "Invoice"
    if "budget" in text:
        return "Budget"
    if "contract" in text:
        return "Contract"
    if "bill" in text:
        return "Bill"
    return "Unclassified"

# === Gemini Text Classification ===
def classify_text_content(text: str) -> str:
    prompt = f"""
You are a document classification assistant.
Classify the following text into one of these categories:
- Invoice
- Bill
- Budget
- Tax Document
- Contract
- Utility Bill

Return ONLY the category name (no explanation).

Page Text:
{text}
"""
    try:
        response = gemini.generate_content(prompt)
        label = response.text.strip()

        if label:
            normalized = label.lower()
            for valid_label in LABELS:
                if normalized == valid_label.lower():
                    return valid_label
        return fallback_label(text)
    except Exception as e:
        print("[Gemini Error]", e)
        return fallback_label(text)

# === PDF Classification with Optional MongoDB Logging ===
async def classify_pdf_bytes(file_bytes: bytes, user_id: str = None):
    try:
        images = convert_from_bytes(file_bytes, poppler_path=POPPLER_PATH)
    except Exception as e:
        print("[ERROR] PDF to Image failed:", e)
        return {
            "results": [{
                "page": 0,
                "label": "PDF conversion failed",
                "text_preview": "",
                "error": str(e)
            }]
        }

    results = []
    for i, img in enumerate(images):
        try:
            raw_text = pytesseract.image_to_string(img, config='--oem 3 --psm 6')
            text = raw_text.encode('ascii', 'ignore').decode('utf-8', 'ignore')
            text = text.replace('\r', '').replace('\n', ' ')
            text = re.sub(r'\s+', ' ', text).strip()

            if not text:
                results.append({"page": i + 1, "label": "No Text Found", "text_preview": ""})
                continue

            label = classify_text_content(text)
            masked = mask_sensitive_data(text)

            result = {
                "page": i + 1,
                "label": label,
                "masked_text": masked
            }

            # Save to MongoDB if user_id is present
            if user_id:
                await classification_collection.insert_one({
                    "user_id": user_id,
                    "timestamp": datetime.utcnow(),
                    **result
                })

            results.append({
                "page": i + 1,
                "label": label,
                "text_preview": masked[:300]
            })

        except Exception as e:
            print(f"[OCR Error on Page {i+1}]: {e}")
            results.append({
                "page": i + 1,
                "label": "Error",
                "text_preview": "Could not process this page.",
                "error": str(e)
            })

    return {"results": results}
