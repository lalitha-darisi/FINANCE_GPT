from bson import ObjectId
from fastapi import APIRouter, HTTPException, UploadFile, Form
from models.user import UserRegister, UserLogin
from db.mongodb import db
from passlib.context import CryptContext

from utils.pdf_parser import extract_claim_from_pdf
import os
import tempfile
router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

@router.post("/register")
async def register_user(user: UserRegister):
    if await db.users.find_one({"email": user.email}):
        raise HTTPException(status_code=400, detail="Email already registered")
    hashed = pwd_context.hash(user.password)
    await db.users.insert_one({
        "email": user.email,
        "hashed_password": hashed,
        "uploaded_claims": []
    })
    return {"message": "User registered successfully"}

@router.post("/login")
async def login_user(user: UserLogin):
    user_data = await db.users.find_one({"email": user.email})
    if not user_data:
        raise HTTPException(status_code=400, detail="Invalid credentials")
    
    if not pwd_context.verify(user.password, user_data["hashed_password"]):
        raise HTTPException(status_code=400, detail="Incorrect password")

    return {
        "message": "Login successful",
        "email": user_data["email"],
        "user_id": str(user_data["_id"])  # ✅ MongoDB _id must be converted to string
    }


