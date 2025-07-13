from fastapi import HTTPException, status
from passlib.context import CryptContext
from db.connection import db
from .jwt_handler import create_access_token

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

users_collection = db.users  # MongoDB collection

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_pwd, hashed_pwd) -> bool:
    return pwd_context.verify(plain_pwd, hashed_pwd)

async def register_user(data):
    # Check if user exists
    if await users_collection.find_one({"email": data.email}):
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_pwd = hash_password(data.password)
    user = {"username": data.username, "email": data.email, "password": hashed_pwd}
    await users_collection.insert_one(user)
    return {"msg": "User registered successfully"}

async def login_user(data):
    user = await users_collection.find_one({"email": data.email})
    if not user or not verify_password(data.password, user["password"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({"sub": user["email"]})
    return {"access_token": token, "token_type": "bearer"}
