from typing import List
from io import BytesIO
import PyPDF2
import fitz
def extract_claim_from_pdf(file_bytes: bytes) -> List[str]:
    """
    Reads a PDF from bytes and returns a list of page-wise extracted text.
    Each item in the list corresponds to a page in the PDF.
    """
    pages = []
    with BytesIO(file_bytes) as f:
        reader = PyPDF2.PdfReader(f)
        for page in reader.pages:
            text = page.extract_text()
            pages.append(text.strip() if text else "")
    return pages
def extract_text_from_bytes(pdf_bytes: bytes) -> str:
    with fitz.open("pdf", pdf_bytes) as doc:
        return " ".join(page.get_text() for page in doc if page.get_text()).strip()