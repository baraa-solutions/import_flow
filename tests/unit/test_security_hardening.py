"""
Unit Tests for Track 3: Infrastructure & Network Hardening
===========================================================
Covers:
1. Binary magic bytes inspection (prevent disguised PE, ELF, scripts).
2. Filename sanitization against path traversal attacks.
3. JWT Token Revocation Manager (server-side invalidation & persistence).
4. POST /api/v1/auth/logout endpoint verification.
5. Self-signed TLS certificate generation with SAN extensions.
6. System security auditing script helpers.
"""

import os
import tempfile
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.users.model import User
from modules.auth.revoked_token_model import RevokedToken
from modules.auth.security import (
    create_access_token,
    decode_access_token,
    token_revocation_manager,
    hash_password,
)
from modules.smart_document_upload.validators import (
    validate_magic_bytes,
    sanitize_filename,
    validate_file_size,
)
from scripts.generate_tls_cert import generate_self_signed_cert
import scripts.harden_system_security as harden_sec


class TestSecurityHardening(unittest.TestCase):
    def setUp(self):
        # Create an isolated in-memory SQLite DB for testing with cross-thread access
        from sqlalchemy.pool import StaticPool
        self.engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.TestingSessionLocal = sessionmaker(bind=self.engine)
        self.db = self.TestingSessionLocal()

        # Seed a test user
        self.test_user = User(
            username="secuser",
            email="secuser@importflow.com",
            hashed_password=hash_password("Pass12345!"),
            full_name="Security Test User",
            role="ADMIN",
            is_active=True,
        )
        self.db.add(self.test_user)
        self.db.commit()
        self.db.refresh(self.test_user)

        # Initialize token_revocation_manager cache
        token_revocation_manager._revoked_hashes.clear()
        token_revocation_manager._initialized = False
        token_revocation_manager.init_from_db(self.db)

    def tearDown(self):
        self.db.close()
        token_revocation_manager._revoked_hashes.clear()
        token_revocation_manager._initialized = False

    # ── 1. Magic Bytes File Sniffing & Validation ──────────────────

    def test_magic_bytes_valid_pdf(self):
        """Valid PDF with standard %PDF- magic header passes."""
        valid_pdf = b"%PDF-1.5\r\n1 0 obj\r\n<< /Type /Catalog >>\r\nendobj"
        # Should not raise: (content_bytes, filename)
        validate_magic_bytes(valid_pdf, "invoice.pdf")

    def test_magic_bytes_valid_images(self):
        """Valid PNG, JPEG, and WebP images pass validation."""
        valid_png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
        validate_magic_bytes(valid_png, "packing.png")

        valid_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01"
        validate_magic_bytes(valid_jpeg, "photo.jpg")

        valid_webp = b"RIFF\x00\x00\x00\x00WEBPVP8 "
        validate_magic_bytes(valid_webp, "scan.webp")

    def test_magic_bytes_valid_office_docs(self):
        """Valid Office formats (PK zip and OLE compound) pass validation."""
        valid_docx = b"PK\x03\x04\x14\x00\x06\x00\x08\x00"
        validate_magic_bytes(valid_docx, "contract.docx")
        validate_magic_bytes(valid_docx, "data.xlsx")

        valid_ole = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1\x00\x00"
        validate_magic_bytes(valid_ole, "legacy.xls")

    def test_magic_bytes_blocks_disguised_pe_executable(self):
        """Disguised Windows executable (MZ header) renamed to .pdf must be rejected."""
        fake_pdf = b"MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\x00\x00"
        with self.assertRaises(HTTPException) as ctx:
            validate_magic_bytes(fake_pdf, "malicious.pdf")
        self.assertEqual(ctx.exception.status_code, 415)
        self.assertIn("Windows executable", ctx.exception.detail)

    def test_magic_bytes_blocks_disguised_elf_binary(self):
        """Disguised Linux ELF binary renamed to .xlsx must be rejected."""
        fake_xlsx = b"\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        with self.assertRaises(HTTPException) as ctx:
            validate_magic_bytes(fake_xlsx, "report.xlsx")
        self.assertEqual(ctx.exception.status_code, 415)
        self.assertIn("Linux executable", ctx.exception.detail)

    def test_magic_bytes_blocks_embedded_script(self):
        """PHP or HTML script disguised as a document must be rejected."""
        fake_doc = b"<?php system($_GET['cmd']); ?>"
        with self.assertRaises(HTTPException) as ctx:
            validate_magic_bytes(fake_doc, "document.pdf")
        self.assertEqual(ctx.exception.status_code, 415)
        self.assertIn("Web script", ctx.exception.detail)

    def test_validate_file_size_integration(self):
        """validate_file_size integrates magic bytes validation."""
        fake_pdf = b"MZ\x90\x00\x03\x00\x00\x00"
        with self.assertRaises(HTTPException) as ctx:
            validate_file_size(fake_pdf, "document.pdf")
        self.assertEqual(ctx.exception.status_code, 415)

    def test_sanitize_filename_prevents_directory_traversal(self):
        """Filename sanitizer strips path components and illegal characters."""
        self.assertEqual(sanitize_filename("../../etc/passwd"), "passwd")
        self.assertEqual(
            sanitize_filename("C:\\Windows\\System32\\calc.exe"),
            "calc.exe",
        )
        self.assertEqual(sanitize_filename("  test invoice 1.pdf  "), "test invoice 1.pdf")
        self.assertEqual(sanitize_filename(""), "document")

    # ── 2. Server-Side JWT Revocation & Logout ──────────────────────

    def test_token_revocation_lifecycle(self):
        """Token can be revoked, cached in-memory, stored in DB, and rejected on decode."""
        token = create_access_token(
            {"sub": str(self.test_user.user_id), "role": self.test_user.role},
            expires_in_seconds=1800,
        )

        # Verify initial valid token decodes
        decoded = decode_access_token(token)
        self.assertIsNotNone(decoded)
        self.assertEqual(decoded["sub"], str(self.test_user.user_id))

        # Revoke token
        exp = datetime.now(timezone.utc) + timedelta(minutes=30)
        token_revocation_manager.revoke(
            token=token,
            user_id=self.test_user.user_id,
            expires_at=exp,
            db=self.db,
        )

        # 1. In-memory check: O(1) instant lookup
        self.assertTrue(token_revocation_manager.is_revoked(token))

        # 2. Database persistence check
        persisted = self.db.query(RevokedToken).filter_by(user_id=self.test_user.user_id).first()
        self.assertIsNotNone(persisted)

        # 3. decode_access_token must return None for revoked token
        self.assertIsNone(decode_access_token(token))

    def test_revocation_cache_warmup_from_db(self):
        """token_revocation_manager restores unexpired revoked tokens on startup."""
        token = create_access_token({"sub": "99", "role": "OPERATOR"}, expires_in_seconds=3600)
        exp = datetime.now(timezone.utc) + timedelta(hours=1)

        # Revoke and simulate server restart by clearing in-memory set
        token_revocation_manager.revoke(
            token=token,
            user_id=99,
            expires_at=exp,
            db=self.db,
        )
        token_revocation_manager._revoked_hashes.clear()
        token_revocation_manager._initialized = False
        self.assertFalse(token_revocation_manager.is_revoked(token))

        # Reload from DB (as happens on application startup). is_revoked() above lazily loads the app DB
        # (BEX-T08 ensure_loaded), so reset the flag again before loading this test's DB.
        token_revocation_manager._revoked_hashes.clear()
        token_revocation_manager._initialized = False
        token_revocation_manager.init_from_db(self.db)
        self.assertTrue(token_revocation_manager.is_revoked(token))

    def test_logout_api_endpoint(self):
        """POST /api/v1/auth/logout invalidates token and returns 200."""
        from modules.auth.router import router as auth_router
        from database.database import get_db
        from fastapi import FastAPI

        app = FastAPI()
        app.include_router(auth_router)

        def override_get_db():
            db_session = self.TestingSessionLocal()
            try:
                yield db_session
            finally:
                db_session.close()

        app.dependency_overrides[get_db] = override_get_db
        client = TestClient(app)

        token = create_access_token(
            {"sub": str(self.test_user.user_id), "role": self.test_user.role},
            expires_in_seconds=900,
        )

        # Call logout endpoint
        response = client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data.get("status"), "success")
        self.assertIn("نجاح", data.get("message", ""))

        # Calling again or using the same token should now return None on decode
        self.assertIsNone(decode_access_token(token))

        # Accessing protected /api/v1/auth/me with revoked token must be rejected with 401
        me_response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(me_response.status_code, 401)

    # ── 3. TLS Certificate Generator ────────────────────────────────

    def test_tls_san_certificate_generation(self):
        """Generates 2048-bit RSA TLS certificate with SAN extensions."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            cert_file, key_file = generate_self_signed_cert(
                output_dir=temp_path,
                validity_days=30,
            )

            self.assertTrue(cert_file.exists())
            self.assertTrue(key_file.exists())
            self.assertGreater(cert_file.stat().st_size, 500)
            self.assertGreater(key_file.stat().st_size, 1000)

            # Read and inspect certificate
            from cryptography import x509
            from cryptography.hazmat.backends import default_backend

            cert_data = cert_file.read_bytes()
            cert = x509.load_pem_x509_certificate(cert_data, default_backend())

            # Verify Subject
            import socket
            cn = cert.subject.get_attributes_for_oid(x509.NameOID.COMMON_NAME)[0].value
            self.assertEqual(cn, socket.gethostname())

            # Verify SAN Extension contains localhost & 127.0.0.1
            san_ext = cert.extensions.get_extension_for_oid(x509.ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
            san_values = san_ext.value
            names = [str(n.value) for n in san_values]

            self.assertTrue(any("127.0.0.1" in n for n in names))
            self.assertTrue(any("localhost" in n for n in names))

    # ── 4. System Security Hardening Helpers ────────────────────────

    def test_harden_system_security_helpers(self):
        """audit_tls and audit_bitlocker helpers return structured data."""
        tls_res = harden_sec.audit_tls()
        self.assertIn("cert_exists", tls_res)
        self.assertIn("key_exists", tls_res)

        bl_res = harden_sec.audit_bitlocker()
        self.assertIn("drive", bl_res)
        self.assertIn("protection_status", bl_res)


if __name__ == "__main__":
    unittest.main()
