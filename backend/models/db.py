# models/db.py
from motor.motor_asyncio import AsyncIOMotorClient

client = AsyncIOMotorClient("mongodb://localhost:27017")
db = client["finance_gpt"]

compliance_collection = db.compliance_results
summarization_collection = db.summarization_results
qa_collection = db.qa_results
classification_collection = db.classification_results
