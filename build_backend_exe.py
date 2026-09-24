"""
Sorour Logistics ERP — Backend PyInstaller Builder
Compiles FastAPI backend into a standalone `backend.exe` executable.
"""
import os
import sys
import subprocess
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent

def build_backend():
    print("===============================================================================")
    print("        Sorour Logistics ERP - Compiling Standalone Backend Executable         ")
    print("===============================================================================")

    hidden_imports = [
        "uvicorn",
        "uvicorn.logging",
        "uvicorn.loops",
        "uvicorn.loops.auto",
        "uvicorn.loops.asyncio",
        "uvicorn.protocols",
        "uvicorn.protocols.http",
        "uvicorn.protocols.http.auto",
        "uvicorn.protocols.http.h11_impl",
        "uvicorn.protocols.websockets",
        "uvicorn.protocols.websockets.auto",
        "uvicorn.lifespan",
        "uvicorn.lifespan.on",
        "uvicorn.lifespan.off",
        "fastapi",
        "fastapi.middleware.cors",
        "starlette",
        "starlette.middleware",
        "starlette.middleware.base",
        "pydantic",
        "pydantic_core",
        "sqlalchemy",
        "sqlalchemy.dialects.sqlite",
        "alembic",
        "sqlite3",
        "multipart",
        "reportlab",
        "openpyxl",
        "pandas",
        "pdfplumber",
        "pypdf",
        "fitz",
        "pymupdf",
        "docx",
        "httpx",
        "requests",
        "anyio",
        "seed",
        "seed_clearance_expenses",
        "main",
        "database.database",
        "database.master_data_sync_service",
        "database.schema_upgrade_service",
        "utils.migration_linter",
        "utils.crypto_utils",
        "utils.db_safety",
        # In-app update (plan §6) and the verified daily backup it relies on (R5, §7)
        "modules.app_update",
        "modules.app_update.model",
        "modules.app_update.schemas",
        "modules.app_update.repository",
        "modules.app_update.service",
        "modules.app_update.validators",
        "modules.app_update.router",
        "scripts",
        "scripts.daily_backup",
        "scripts.db_script_guard",
        "modules.common.concurrency",
        "modules.system_observability.daily_report_service",
        "modules.smart_document_upload.extractors.purchase_order",
        "modules.smart_document_upload.extractors.import_file",
        "modules.smart_document_upload.extractors.cargo_shipping",
        "modules.smart_document_upload.extractors.customs_clearance",
        "modules.smart_document_upload.extractors.customs_broker_quotation",
        "modules.smart_document_upload.extractors.freight_quotation",
        "modules.smart_document_upload.extractors.freight_booking",
        "modules.smart_document_upload.extractors.other_extractors",
        "modules.smart_document_upload.extractors.master_data_entity",
        "modules.smart_document_upload.extractors.base_extractor",
    ]

    # Collect all modules
    modules_dir = ROOT_DIR / "modules"
    for item in modules_dir.iterdir():
        if item.is_dir() and not item.name.startswith("__"):
            hidden_imports.extend([
                f"modules.{item.name}",
                f"modules.{item.name}.model",
                f"modules.{item.name}.schemas",
                f"modules.{item.name}.repository",
                f"modules.{item.name}.service",
                f"modules.{item.name}.validators",
                f"modules.{item.name}.router",
            ])

    cmd = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--onefile",
        "--noconsole",
        "--name", "backend",
        "--distpath", str(ROOT_DIR / "dist_backend"),
        "--workpath", str(ROOT_DIR / "build_backend"),
    ]

    # Code only: never --add-data / --add-binary anything data-bearing (*.db, .env, keys, backups, version
    # state). The backend creates its database next to backend.exe on first run (plan section 0, R1/R4).

    # Add hidden imports
    for imp in hidden_imports:
        cmd.extend(["--hidden-import", imp])

    # Add app entrypoint
    cmd.append(str(ROOT_DIR / "backend_runner.py"))

    print("Running PyInstaller command...")
    result = subprocess.run(cmd, cwd=str(ROOT_DIR))
    if result.returncode != 0:
        print(f"[ERROR] PyInstaller build failed with return code {result.returncode}")
        return False

    print("===============================================================================")
    print(f"[SUCCESS] Standalone backend.exe successfully created at: {ROOT_DIR / 'dist_backend' / 'backend.exe'}")
    print("===============================================================================")
    return True

if __name__ == "__main__":
    success = build_backend()
    sys.exit(0 if success else 1)
