from bson import ObjectId
from fastapi import APIRouter, HTTPException, UploadFile, Form
from models.user import UserRegister, UserLogin
from db.mongodb import user_db
from passlib.context import CryptContext
from models.db import compliance_collection, summarization_collection,classification_collection,qa_collection 
from utils.pdf_parser import extract_claim_from_pdf
import os
import tempfile

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

@router.post("/register")
async def register_user(user: UserRegister):
    if await user_db.users.find_one({"email": user.email}):
        raise HTTPException(status_code=400, detail="Email already registered")
    hashed = pwd_context.hash(user.password)
    await user_db.users.insert_one({
        "email": user.email,
        "hashed_password": hashed,
        "uploaded_claims": []
    })
    return {"message": "User registered successfully"}


@router.post("/login")
async def login_user(user: UserLogin):
    user_data = await user_db.users.find_one({"email": user.email})
    if not user_data:
        raise HTTPException(status_code=400, detail="Invalid credentials")
    
    if not pwd_context.verify(user.password, user_data["hashed_password"]):
        raise HTTPException(status_code=400, detail="Incorrect password")

    return {
        "message": "Login successful",
        "email": user_data["email"],
        "user_id": str(user_data["_id"])
    }


@router.get("/history/{user_id}")
async def get_user_history(user_id: str):
    print(f"🔍 Looking up compliance history for user_id: {user_id}")
    results = await compliance_collection.find({"user_id": user_id}).to_list(100)
    for r in results:
        r["_id"] = str(r["_id"])
    print(f"✅ Fetched {len(results)} compliance records.")
    return results


@router.get("/history/summarization/{user_id}")
async def get_summarization_history(user_id: str):
    print(f"🔍 Looking up summarization history for user_id: {user_id}")
    results = await summarization_collection.find({"user_id": user_id}).to_list(100)
    for r in results:
        r["_id"] = str(r["_id"])
    print(f"✅ Fetched {len(results)} summarization records.")
    return results
@router.get("/history/classification/{user_id}")
async def get_classification_history(user_id: str):
    print(f"🔍 Looking up classification history for user_id: {user_id}")
    results = await classification_collection.find({"user_id": user_id}).to_list(100)
    for r in results:
        r["_id"] = str(r["_id"])
    print(f"✅ Fetched {len(results)} classification records.")
    return results
@router.get("/history/qa/{user_id}")
async def get_qa_history(user_id: str):
    print(f"🔍 Looking up Q/A history for user_id: {user_id}")
    results = await qa_collection.find({"user_id": user_id}).to_list(100)
    for r in results:
        r["_id"] = str(r["_id"])
    print(f"✅ Fetched {len(results)} Q/A records.")
    return results
