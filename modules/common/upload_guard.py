"""
Upload defense shared by every file-accepting endpoint.

read_upload_bytes() enforces, before any parser sees the content:
1. an extension allow-list (case-insensitive, taken from a sanitised filename),
2. a hard size limit, read in chunks so an oversized body is rejected without loading it all in memory,
3. a content signature check (magic bytes) for binary formats, so a renamed executable is refused.

safe_filename() strips directory parts, control characters and unsafe symbols from a client filename before
it is logged, stored or used to build a path.
"""
import os
import re
import unicodedata
from typing import Iterable, Optional

from fastapi import HTTPException, UploadFile, status

UPLOAD_CHUNK_BYTES = 1024 * 1024
DEFAULT_MAX_UPLOAD_BYTES = 20 * 1024 * 1024
MAX_FILENAME_LENGTH = 150

EXCEL_EXTENSIONS = frozenset({".xlsx", ".xlsm"})
EXCEL_OR_CSV_EXTENSIONS = frozenset({".xlsx", ".xlsm", ".xls", ".csv"})

# Leading bytes of each binary format. Text formats (.csv / .txt) have no signature and are checked for NUL bytes.
_ZIP_SIGNATURE = b"PK\x03\x04"
_OLE2_SIGNATURE = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"
CONTENT_SIGNATURES = {
    ".xlsx": (_ZIP_SIGNATURE,),
    ".xlsm": (_ZIP_SIGNATURE,),
    ".docx": (_ZIP_SIGNATURE,),
    ".xls": (_OLE2_SIGNATURE,),
    ".doc": (_OLE2_SIGNATURE,),
    ".pdf": (b"%PDF-",),
    ".png": (b"\x89PNG\r\n\x1a\n",),
    ".jpg": (b"\xff\xd8\xff",),
    ".jpeg": (b"\xff\xd8\xff",),
}
TEXT_EXTENSIONS = frozenset({".csv", ".txt"})

_UNSAFE_FILENAME_CHARS = re.compile(r"[^\w.\- ()؀-ۿ]+", re.UNICODE)


def safe_filename(filename: Optional[str], default: str = "upload") -> str:
    """Basename of a client-supplied filename with path parts, control and unsafe characters removed."""
    name = unicodedata.normalize("NFC", filename or "")
    name = name.replace("\\", "/").split("/")[-1]
    name = "".join(ch for ch in name if unicodedata.category(ch)[0] != "C")
    name = _UNSAFE_FILENAME_CHARS.sub("_", name).strip(" .")
    if not name:
        return default
    if len(name) > MAX_FILENAME_LENGTH:
        stem, ext = os.path.splitext(name)
        name = stem[: MAX_FILENAME_LENGTH - len(ext)] + ext
    return name


def file_extension(filename: Optional[str]) -> str:
    return os.path.splitext(safe_filename(filename))[1].lower()


def validate_upload_extension(filename: Optional[str], allowed_extensions: Iterable[str]) -> str:
    """Returns the lower-case extension, or 415 when it is not in the allow-list."""
    allowed = {e.lower() for e in allowed_extensions}
    ext = file_extension(filename)
    if ext not in allowed:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"File type '{ext or 'unknown'}' is not allowed. Allowed: {', '.join(sorted(allowed))}.",
        )
    return ext


def validate_content_signature(ext: str, content: bytes) -> None:
    """415 when the bytes do not match the declared extension (e.g. an .exe renamed to .xlsx)."""
    signatures = CONTENT_SIGNATURES.get(ext)
    if signatures and not any(content.startswith(sig) for sig in signatures):
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"File content does not match its '{ext}' extension.",
        )
    if ext in TEXT_EXTENSIONS and b"\x00" in content[:8192]:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"File content is binary, not a '{ext}' text file.",
        )


async def read_limited(file: UploadFile, max_bytes: int) -> bytes:
    """Reads the upload in chunks; 413 as soon as it exceeds max_bytes."""
    chunks = []
    total = 0
    while True:
        chunk = await file.read(UPLOAD_CHUNK_BYTES)
        if not chunk:
            break
        total += len(chunk)
        if total > max_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                detail=f"File exceeds the maximum allowed size of {max_bytes // (1024 * 1024)} MB.",
            )
        chunks.append(chunk)
    return b"".join(chunks)


async def read_upload_bytes(
    file: UploadFile,
    allowed_extensions: Iterable[str],
    max_bytes: int = DEFAULT_MAX_UPLOAD_BYTES,
) -> bytes:
    """Extension allow-list + bounded read + signature check. Returns the file content."""
    ext = validate_upload_extension(file.filename, allowed_extensions)
    content = await read_limited(file, max_bytes)
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty.")
    validate_content_signature(ext, content)
    return content
