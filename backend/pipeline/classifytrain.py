from fastapi import UploadFile, File, Form, HTTPException
from pdf2image import convert_from_bytes
import pytesseract
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from typing import Optional
import re

# === Model setup ===
MODEL_PATH = "document_type_classifier"
POPPLER_PATH = r"C:\Users\LALITHA\Downloads\Release-24.08.0-0\poppler-24.08.0\Library\bin"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
LABELS = ["Invoice", "Bill", "Budget", "Tax Document", "Contract"]

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH).to(DEVICE)
model.eval()

def mask_pii(text: str) -> str:
    text = re.sub(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}\b', 'XXXXX', text)
    text = re.sub(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b', 'XXXXX', text)
    text = re.sub(r'\b[6-9]\d{9}\b', 'XXXXX', text)
    text = re.sub(r'\b\d{10}\b', 'XXXXX', text)
    text = re.sub(r'\$\d{1,3}(?:,\d{3})*(?:\.\d{2})?', 'XXXXX', text)
    text = re.sub(r'(Taxpayer Name:\s*)(.*)', r'\1XXXXX', text)
    return text

def classify_text_with_model(text):
    clean_text = text.lower().replace("\n", " ").strip()
    if not clean_text:
        return "Unclassified (No text)"
    try:
        inputs = tokenizer(clean_text, truncation=True, padding=True, max_length=256, return_tensors="pt").to(DEVICE)
        with torch.no_grad():
            outputs = model(**inputs)
        pred = torch.argmax(outputs.logits, dim=1).item()
        return LABELS[pred]
    except Exception as e:
        print("⚠ Model inference error:", str(e))
        return "Unclassified (Error)"

# ✅ Function to be called by main.py
async def classify_file_from_train_model(text: Optional[str] = None, file: Optional[UploadFile] = None):
    if file:
        try:
            contents = await file.read()
            images = convert_from_bytes(contents, poppler_path=POPPLER_PATH)
            results = []
            for i, img in enumerate(images):
                text = pytesseract.image_to_string(img)
                label = classify_text_with_model(text) if text.strip() else "Unclassified (No text)"
                masked = mask_pii(text.strip())
                results.append({
                    "page": i + 1,
                    "label": label,
                    "ocr_text": text.strip(),
                    "masked_text": masked
                })
            return {"type": "pdf", "results": results}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error processing PDF: {str(e)}")

    elif text:
        label = classify_text_with_model(text)
        masked = mask_pii(text)
        return {"type": "text", "label": label, "input": text, "masked": masked}

    else:
        raise HTTPException(status_code=400, detail="No input provided.")