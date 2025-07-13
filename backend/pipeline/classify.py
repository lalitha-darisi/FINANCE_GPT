import os
import pytesseract
from pdf2image import convert_from_bytes
import google.generativeai as genai
from PIL import Image

# === Configuration ===
POPPLER_PATH = r"C:\Users\LALITHA\Downloads\Release-24.08.0-0\poppler-24.08.0\Library\bin"
GEMINI_API_KEY = "AIzaSyCaPzD02BOMZxCYdi4YESjI_Zl3trKpZF4"
LABELS = ["Invoice", "Bill", "Budget", "Tax Document", "Contract"]

# Optional: Tesseract path
# pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

# === Gemini Setup ===
genai.configure(api_key=GEMINI_API_KEY)
gemini_model = genai.GenerativeModel("gemini-1.5-flash")

# === Fallback Classifier ===
def fallback_label(text):
    text = text.lower()
    if "invoice" in text:
        return "Invoice"
    if "bill" in text:
        return "Bill"
    if "budget" in text:
        return "Budget"
    if "tax" in text:
        return "Tax Document"
    if "contract" in text:
        return "Contract"
    return "Unclassified"

# === Single Page / Text Classifier ===
def classify_text_content(text: str) -> str:
    prompt = f"""
You are a document classification assistant.
Classify the following text into one of these categories:
- Invoice
- Bill
- Budget
- Tax Document
- Contract

Return ONLY the category name (no explanation).

Page Text:
{text}
"""
    try:
        response = gemini_model.generate_content(prompt)
        label = response.text.strip()

        # Match only valid labels
        for valid_label in LABELS:
            if valid_label.lower() in label.lower():
                return valid_label
        return fallback_label(text)
    except Exception as e:
        print(f"[Gemini Error] {e}")
        return fallback_label(text)

# === Full PDF Classifier ===
def classify_pdf_bytes(file_bytes: bytes):
    try:
        images = convert_from_bytes(file_bytes, poppler_path=POPPLER_PATH)
    except Exception as e:
        print("[ERROR] PDF to Image failed:", e)
        return {"results": [{"page": 0, "label": "PDF conversion failed", "text_preview": ""}]}

    results = []
    for i, img in enumerate(images):
        try:
            custom_config = r'--oem 3 --psm 6'
            text = pytesseract.image_to_string(img, config=custom_config)
            print(f"[PAGE {i+1} OCR]:", text[:300])

            if not text.strip():
                results.append({"page": i + 1, "label": "No Text Found", "text_preview": ""})
                continue

            label = classify_text_content(text)
            print(f"[PAGE {i+1}] Label: {label}")

            results.append({
                "page": i + 1,
                "label": label,
                "text_preview": text.strip()[:300]
            })
        except Exception as page_err:
            print(f"[OCR Error on Page {i+1}]: {page_err}")
            results.append({
                "page": i + 1,
                "label": "Error",
                "text_preview": "Could not process this page."
            })

    return {"results": results}
