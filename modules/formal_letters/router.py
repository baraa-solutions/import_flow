"""
FastAPI Router for AI Formal Letter Drafting (AI-DRAFT-014)
"""

from typing import List
from fastapi import APIRouter, Depends, status
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session
from database.database import get_db

from .schemas import (
    FormalLetterGenerateRequest,
    FormalLetterResponse,
    FormalLetterTemplateInfo,
    FormalLetterRecordResponse,
)
from .service import (
    get_available_templates_service,
    generate_formal_letter_service,
    get_file_letter_history_service,
)

router = APIRouter(prefix="/api/v1/formal-letters", tags=["Formal Letter Drafting (AI-DRAFT-014)"], dependencies=[Depends(get_current_user)])


@router.get(
    "/templates",
    response_model=List[FormalLetterTemplateInfo],
    summary="جلب قائمة قوالب الخطابات الرسمية المتاحة ومواصفاتها",
)
def get_letter_templates_endpoint():
    return get_available_templates_service()


@router.post(
    "/generate",
    response_model=FormalLetterResponse,
    status_code=status.HTTP_201_CREATED,
    summary="توليد وميكنة خطاب رسمي معتمد ببيانات الشحنة وحفظه بالسجل",
    dependencies=[Depends(require_permission("import_documentation.upload"))],
)
def generate_formal_letter_endpoint(req: FormalLetterGenerateRequest, db: Session = Depends(get_db)):
    return generate_formal_letter_service(db, req)


@router.get(
    "/history/{import_file_id}",
    response_model=List[FormalLetterRecordResponse],
    summary="جلب سجل الخطابات الرسمية الصادرة والمولدة لملف شحنة محدد",
)
def get_letter_history_endpoint(import_file_id: int, db: Session = Depends(get_db)):
    return get_file_letter_history_service(db, import_file_id)
