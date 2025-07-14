from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
from typing import Optional
import fitz
import io
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Summarization and QA
from pipeline.qa import run_qa_gemini, run_qa_from_text_gemini
from pipeline.t5small import run_qa_pdf_t5, run_qa_text_t5
from pipeline.summarize import generate_summary
from pipeline.summarize_t5 import summarize_pdf_sectionwise,summarize_text_sectionwise


# Compliance
from pipeline.comcheck import run_compliance_check_gemini 
from pipeline.comcheck_llama import run_compliance_check_llama 

# Classification
from pipeline.classify import classify_pdf_bytes, classify_text_content
from pipeline.classifytrain import classify_file_from_train_model

from pathlib import Path
from routes import user
from fastapi.responses import JSONResponse

app = FastAPI()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(user.router, prefix="/api/user")

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# === Summarization ===
@app.post("/summarize")
async def summarize(
    file: UploadFile = File(None),
    summary_type: str = Form("detailed"),
    model: str = Form("gemini"),
    text: str = Form(None),
    user_id: str = Form(None)
):
    print(f"📌 Summarize Request | Type: {summary_type} | Model: {model}")

    if file is not None:
        file_path = os.path.join(UPLOAD_FOLDER, file.filename)
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)

        if model == "gemini":
            summary = await generate_summary(file_path, summary_type, model=model, is_text=False,user_id=user_id)
        elif model == "t5":
            summary = await summarize_pdf_sectionwise(file_path, user_id=user_id, model=model)

        else:
            return {"error": "❌ Unsupported summarization model."}

        return {"summary": summary}

    elif text:
        if model == "gemini":
            summary = await generate_summary(text, summary_type, model=model, is_text=True,user_id=user_id)
        elif model == "t5":
            summary = await summarize_text_sectionwise(text, user_id=user_id, model=model)

        else:
            return {"error": "❌ Unsupported summarization model."}

        return {"summary": summary}

    else:
        return {"error": "❌ Please provide either a PDF file or text input."}

# ✅ === Updated QA API: /qa ===
@app.post("/qa_api")
async def qa_api(
    question: str = Form(...),
    model: str = Form("gemini"),
    text: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    user_id: Optional[str] = Form(None) 
):
    try:
        print(f"🤖 Q&A Request | Model: {model} | Question: {question}")
        is_text_input = text is not None and text.strip() != ""
        is_file_input = file is not None

        if not is_text_input and not is_file_input:
            return JSONResponse(
                status_code=400,
                content={"answer": "❌ Please provide either a PDF file or text context."}
            )

        if model.lower() == "t5_small":
            if is_file_input:
                pdf_bytes = await file.read()
                response = await run_qa_pdf_t5(pdf_bytes, question,user_id=user_id)
            else:
                response = await run_qa_text_t5(text, question,user_id=user_id)

        elif model.lower() == "gemini":
            if is_file_input:
                pdf_bytes = await file.read()
                response = await run_qa_gemini(pdf_bytes, question,user_id=user_id)
            else:
                response = await run_qa_from_text_gemini(text, question,user_id=user_id)

        else:
            return JSONResponse(
                status_code=400,
                content={"answer": "❌ Unsupported model name"}
            )

        return {"answer": response, "model_used": model}

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"answer": f"[❌ QA Error]: {str(e)}", "model_used": model}
        )

# ✅ === Unified Classification ===
@app.post("/classify")
async def classify(
    file: Optional[UploadFile] = File(None),
    text: Optional[str] = Form(None),
    model: str = Form("bert"),
    user_id: str = Form(None)
):
    print(f"📄 Classify | Model: {model}")

    try:
        if model in ["bert", "distilbert"]:
            result = await classify_file_from_train_model(text=text, file=file,user_id=user_id)
            if result.get("type") == "pdf":
                results = [{
                    "page": page["page"],
                    "label": page["label"],
                    "text_preview": page["masked_text"][:300]
                } for page in result["results"]]
                return {"results": results}
            else:
                return {
                    "results": [{
                        "page": 1,
                        "label": result["label"],
                        "text_preview": result["masked"][:300]
                    }]
                }

        elif model == "gemini":
            if file:
                contents = await file.read()
                return classify_pdf_bytes(contents)
            elif text:
                label = classify_text_content(text)
                return {
                    "results": [{
                        "page": 1,
                        "label": label,
                        "text_preview": text[:300]
                    }]
                }
            else:
                return {"error": "❌ No input provided."}

        else:
            return {"error": f"❌ Unsupported model: {model}"}

    except Exception as e:
        return {"error": f"❌ Classification failed: {str(e)}"}

# === Compliance ===
@app.post("/compliance")
async def compliance_api(
    model: str = Form("gemini"),
    file: UploadFile = File(None),
    text: str = Form(None),
    user_id: str = Form(None)
):
    print("📥 Incoming Compliance Request")
    print("📌 Model:", model)
    print("📌 User ID:", user_id)

    if file is None and not text:
        return {"results": [dict(
            claim="Unknown",
            classification="Error",
            reasoning="No file or text provided",
            matched_policies=[]
        )]}

    content = text if text else await file.read()
    is_raw_text = bool(text)
    print("📌 Raw Text?", is_raw_text)
    print("📄 Content:\n", content[:500])

    if model == "gemini":
        result = await run_compliance_check_gemini(content, is_raw_text=is_raw_text, user_id=user_id)
    elif model in ["tinyllama", "tiny_lama"]:
        result = await run_compliance_check_llama(content, is_raw_text=is_raw_text, user_id=user_id)
    else:
        return {"results": [dict(
            claim="Unknown",
            classification="Error",
            reasoning=f"Unsupported model: {model}",
            matched_policies=[]
        )]}

    print("📤 Result:", result)
    return result
