from pydantic import BaseModel, EmailStr
from typing import List, Optional

class UserData(BaseModel):
    email: EmailStr
    hashed_password: str
    uploaded_claims: List[dict] = []
