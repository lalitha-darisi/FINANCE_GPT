from pymongo import MongoClient

client = MongoClient("mongodb://localhost:27017/")
db = client["finance_gpt"]

# Collection to store compliance results
compliance_collection = db["compliance_results"]
