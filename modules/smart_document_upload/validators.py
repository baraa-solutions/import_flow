"""
Smart Document Upload — Validators
File type, size, and module validation.
"""

import os
import re
from typing import List, Optional

from fastapi import HTTPException, UploadFile, status

# Max file size: 20 MB
MAX_FILE_SIZE_BYTES = 20 * 1024 * 1024
# Files per multi-document upload (SDU-03)
MAX_FILES_PER_UPLOAD = 10
# Pasted raw text (characters) accepted by /extract/* (SDU-02)
MAX_RAW_TEXT_CHARS = 200_000

ALLOWED_EXTENSIONS = {
    ".pdf", ".docx", ".doc",
    ".xlsx", ".xls",
    ".txt", ".csv",
    ".png", ".jpg", ".jpeg", ".webp",
}

EXTENSION_TO_TYPE = {
    ".pdf": "pdf",
    ".docx": "word",
    ".doc": "word",
    ".xlsx": "excel",
    ".xls": "excel",
    ".txt": "text",
    ".csv": "text",
    ".png": "image",
    ".jpg": "image",
    ".jpeg": "image",
    ".webp": "image",
}

SUPPORTED_MODULES = {
    "purchase-order",
    "import-file",
    "cargo-shipping",
    "customs-clearance",
    "freight-quotation",
    "freight-booking",
    "clearance-quotation",
    "customs-broker-quotation",
    "customs-consultation",
    "warehouse-receiving",
    "demurrage",
    "financial-document",
    "commercial-invoice",
    "commercial_invoice",
    "invoice",
    "bill-of-lading",
    "bill_of_lading",
    "bl",
    "awb",
    "coo-certificate",


    "inspection-certificate",
    "master-data-entity",
    "supplier-entity",
    "importer-entity",
    "import-company-entity",
    "partner-entity",
    "bank-entity",
    "shipping-line-entity",
    "customs-broker-entity",
    "freight-forwarder-entity",
    "inland-transport-entity",
    "inspection-agency-entity",
    "insurance-company-entity",
}


def validate_module_name(module: str) -> None:
    if module not in SUPPORTED_MODULES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Unsupported module '{module}'. Supported: {sorted(SUPPORTED_MODULES)}",
        )


def validate_upload_file(file: UploadFile) -> str:
    """
    Validates file extension and returns the detected file type string.
    Raises HTTPException on invalid file.
    """
    filename = file.filename or ""
    lower = filename.lower()

    matched_ext = None
    for ext in ALLOWED_EXTENSIONS:
        if lower.endswith(ext):
            matched_ext = ext
            break

    if matched_ext is None:
        raise HTTPException(
            status_code=415,
            detail=(
                "File type not supported. "
                f"Allowed types: PDF, Word (.docx/.doc), Excel (.xlsx/.xls), Text (.txt/.csv), "
                f"Images (.png/.jpg/.jpeg/.webp)"
            ),
        )

    return EXTENSION_TO_TYPE[matched_ext]


def sanitize_filename(filename: str) -> str:
    """Sanitizes filename against path traversal and dangerous characters."""
    base = os.path.basename(filename.replace("\\", "/"))
    cleaned = re.sub(r'[^a-zA-Z0-9_.\-\u0600-\u06FF ]', '', base)
    return cleaned.strip() or "document"


def validate_magic_bytes(content_bytes: bytes, filename: str) -> None:
    """
    Validates binary content signature (magic bytes) against declared extension.
    Explicitly rejects disguised executables (PE, ELF, scripts).
    """
    if not content_bytes:
        raise HTTPException(
            status_code=400,
            detail=f"The uploaded file is empty (0 bytes).",
        )

    # 1. Unconditional executable and script blocking
    if content_bytes.startswith(b"MZ"):
        raise HTTPException(
            status_code=415,
            detail=f"Security Violation: Windows executable (PE/EXE) detected.",
        )
    if content_bytes.startswith(b"\x7fELF"):
        raise HTTPException(
            status_code=415,
            detail=f"Security Violation: Linux executable (ELF) detected.",
        )
    if content_bytes.startswith(b"<!DOCTYPE html") or content_bytes.startswith(b"<html") or content_bytes.startswith(b"<?php"):
        raise HTTPException(
            status_code=415,
            detail=f"Security Violation: Web script or HTML file detected.",
        )

    # 2. Check declared extension against binary headers
    lower = filename.lower()
    if lower.endswith(".pdf"):
        if not content_bytes.startswith(b"%PDF-"):
            raise HTTPException(
                status_code=415,
                detail=f"The file has .pdf extension but lacks a valid PDF header (%PDF-).",
            )
    elif lower.endswith(".xlsx") or lower.endswith(".docx"):
        if not content_bytes.startswith(b"PK\x03\x04"):
            raise HTTPException(
                status_code=415,
                detail=f"The file has Office OpenXML extension but lacks valid ZIP header (PK..).",
            )
    elif lower.endswith(".xls") or lower.endswith(".doc"):
        if not content_bytes.startswith(b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1") and not content_bytes.startswith(b"PK\x03\x04"):
            raise HTTPException(
                status_code=415,
                detail=f"The file has legacy Office extension but lacks valid CFBF/OLE header.",
            )
    elif lower.endswith(".png"):
        if not content_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            raise HTTPException(
                status_code=415,
                detail=f"The file has .png extension but lacks valid PNG header.",
            )
    elif lower.endswith(".jpg") or lower.endswith(".jpeg"):
        if not content_bytes.startswith(b"\xff\xd8\xff"):
            raise HTTPException(
                status_code=415,
                detail=f"The file has JPEG extension but lacks valid JPEG SOI marker.",
            )
    elif lower.endswith(".webp"):
        if not (content_bytes.startswith(b"RIFF") and len(content_bytes) >= 12 and content_bytes[8:12] == b"WEBP"):
            raise HTTPException(
                status_code=415,
                detail=f"The file has .webp extension but lacks valid WEBP header.",
            )


def validate_file_size(content_bytes: bytes, filename: str) -> None:
    if len(content_bytes) > MAX_FILE_SIZE_BYTES:
        size_mb = len(content_bytes) / (1024 * 1024)
        raise HTTPException(
            status_code=413,
            detail=f"The file is too large ({size_mb:.1f} MB). Maximum allowed: 20 MB.",
        )
    # Content magic bytes inspection
    validate_magic_bytes(content_bytes, filename)



async def read_limited(file: UploadFile, limit: int = MAX_FILE_SIZE_BYTES) -> bytes:
    """Read at most ``limit + 1`` bytes: an upload above ``limit`` is rejected with 413 without loading the rest
    into memory (SDU-03)."""
    content = await file.read(limit + 1)
    if len(content) > limit:
        raise HTTPException(
            status_code=413,
            detail=f"The file is too large. Maximum allowed: {limit // (1024 * 1024)} MB.",
        )
    return content


async def read_validated_upload(file: UploadFile) -> tuple:
    """Extension whitelist + bounded read + size / magic-byte checks. Returns ``(file_type, content_bytes)``."""
    file_type = validate_upload_file(file)
    content = await read_limited(file)
    validate_file_size(content, file.filename or "unknown")
    return file_type, content


def validate_files_count(files: Optional[List[UploadFile]]) -> None:
    if files and len(files) > MAX_FILES_PER_UPLOAD:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"عدد الملفات ({len(files)}) يتجاوز الحد الأقصى المسموح ({MAX_FILES_PER_UPLOAD}) في الرفع الواحد.",
        )


def validate_raw_text(raw_text: Optional[str]) -> None:
    if raw_text is not None and len(raw_text) > MAX_RAW_TEXT_CHARS:
        raise HTTPException(
            status_code=413,
            detail=f"النص الملصق طويل جداً ({len(raw_text)} حرف). الحد الأقصى {MAX_RAW_TEXT_CHARS} حرف.",
        )


def stored_filename(filename: Optional[str]) -> str:
    """Client filename as stored / echoed: sanitized and cut to the column size (SDU-08)."""
    return sanitize_filename(filename or "")[:255]


# ── Apply targets ─────────────────────────────────────────────────────────────
CLOSED_FILE_STATUSES = ("Closed", "Archived")


def ensure_import_file_open(import_file) -> None:
    """Extracted data is never applied to a closed / archived (read-only) import file: 409 SDU_FILE_CLOSED."""
    if (import_file.status or "") in CLOSED_FILE_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "SDU_FILE_CLOSED",
                "message": f"ملف الاستيراد {import_file.import_file_code} مغلق ولا يمكن تعديل بياناته.",
                "import_file_code": import_file.import_file_code,
                "status": import_file.status,
            },
        )


def ensure_invoice_number_present(invoice_number: Optional[str]) -> str:
    """When applying to an import file, an invoice number is required (SDU-01 / BE03-T03): 400 SDU_INVOICE_NUMBER_REQUIRED."""
    cleaned = (invoice_number or "").strip()
    if not cleaned:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": "SDU_INVOICE_NUMBER_REQUIRED",
                "message": "رقم الفاتورة مطلوب لربط بيانات الفاتورة بملف الشحنة.",
            },
        )
    return cleaned

