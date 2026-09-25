import os
import shutil
import tempfile
from pathlib import Path
import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from scripts.daily_backup import (
    sync_to_google_drive,
    prune_backups_in_dir,
    compute_sha256,
)
from modules.system_observability.alert_dispatcher import AlertDispatcher


@pytest.fixture
def isolated_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_compute_sha256(tmp_path):
    f = tmp_path / "sample.txt"
    f.write_text("Hello Offsite Backup Verification", encoding="utf-8")
    hash1 = compute_sha256(f)
    assert len(hash1) == 64
    assert hash1 == compute_sha256(f)


def test_sync_to_google_drive(tmp_path):
    local_dir = tmp_path / "local"
    offsite_dir = tmp_path / "offsite"
    local_dir.mkdir()

    # Create dummy backup and metadata
    backup_file = local_dir / "daily_backup_20260919_010000.db"
    backup_file.write_bytes(b"SQLITE_DUMMY_DATABASE_CONTENT_FOR_BACKUP_TEST")
    meta_file = local_dir / "daily_backup_20260919_010000.json"
    meta_file.write_text('{"status": "success"}', encoding="utf-8")

    # 1. Run sync with default AES-256-GCM encryption
    result = sync_to_google_drive(
        backup_path=backup_file,
        meta_path=meta_file,
        offsite_dir=offsite_dir,
        retention_days=30,
        encrypt_offsite=True,
    )

    assert result["status"] == "SUCCESS"
    assert result["verified"] is True
    assert result["is_encrypted"] is True
    assert result["algorithm"] == "AES-256-GCM"

    target_path = Path(result["target_path"])
    assert target_path.exists()
    assert target_path.name.endswith(".db.enc")
    assert result["size_bytes"] == target_path.stat().st_size
    assert result["sha256"] == compute_sha256(target_path)
    assert (target_path.parent / meta_file.name).exists()

    # 2. Run sync with unencrypted mode
    result_unenc = sync_to_google_drive(
        backup_path=backup_file,
        meta_path=meta_file,
        offsite_dir=offsite_dir / "unenc",
        retention_days=30,
        encrypt_offsite=False,
    )
    assert result_unenc["status"] == "SUCCESS"
    assert result_unenc["is_encrypted"] is False
    assert result_unenc["size_bytes"] == backup_file.stat().st_size
    assert result_unenc["sha256"] == compute_sha256(backup_file)


def test_crypto_utils_and_tampering_protection(tmp_path):
    from utils.crypto_utils import (
        encrypt_backup_file,
        decrypt_backup_file,
        is_encrypted_backup,
        get_backup_encryption_key,
    )

    key = get_backup_encryption_key()
    assert len(key) == 32

    src_file = tmp_path / "plain.db"
    src_content = b"CRITICAL_FINANCIAL_AND_CUSTOMS_DATA_SECRET_PAYLOAD" * 50
    src_file.write_bytes(src_content)

    enc_file = tmp_path / "plain.db.enc"
    enc_res = encrypt_backup_file(src_file, enc_file, key=key)
    assert enc_res["verified"] is True
    assert enc_file.exists()
    assert is_encrypted_backup(enc_file) is True
    assert is_encrypted_backup(src_file) is False

    # Valid Decryption
    dec_file = tmp_path / "restored.db"
    success = decrypt_backup_file(enc_file, dec_file, key=key)
    assert success is True
    assert dec_file.read_bytes() == src_content

    # Tampering Protection (flip 1 byte in ciphertext)
    tampered_bytes = bytearray(enc_file.read_bytes())
    tampered_bytes[-5] ^= 0xFF  # Corrupt ciphertext byte
    tampered_file = tmp_path / "tampered.db.enc"
    tampered_file.write_bytes(tampered_bytes)

    dec_tampered = tmp_path / "tampered_restored.db"
    with pytest.raises(RuntimeError) as exc_info:
        decrypt_backup_file(tampered_file, dec_tampered, key=key)
    assert "Invalid encryption key or the backup file has been tampered with" in str(exc_info.value)
    assert not dec_tampered.exists()


def test_restore_database_from_encrypted_backup(tmp_path):
    import sqlite3
    from scripts.restore_database import restore_database
    from utils.crypto_utils import encrypt_backup_file

    # 1. Create a valid SQLite test database with data
    original_db = tmp_path / "source.db"
    conn = sqlite3.connect(original_db)
    cur = conn.cursor()
    cur.execute("CREATE TABLE customs_tariffs (id INTEGER PRIMARY KEY, hs_code TEXT, rate REAL);")
    cur.execute("INSERT INTO customs_tariffs VALUES (1, '8471.30.00', 5.0);")
    cur.execute("INSERT INTO customs_tariffs VALUES (2, '8517.12.00', 10.0);")
    conn.commit()
    conn.close()

    # 2. Encrypt it with AES-256-GCM
    enc_backup = tmp_path / "daily_backup_test_restore.db.enc"
    encrypt_backup_file(original_db, enc_backup)
    assert enc_backup.exists()

    # 3. Restore to a new target database path
    target_restored_db = tmp_path / "restored_production.db"
    success = restore_database(enc_backup, target_db=target_restored_db)
    assert success is True
    assert target_restored_db.exists()

    # 4. Verify restored database contents & integrity
    conn_restored = sqlite3.connect(target_restored_db)
    cur_res = conn_restored.cursor()
    cur_res.execute("PRAGMA integrity_check;")
    assert cur_res.fetchone()[0] == "ok"

    cur_res.execute("SELECT hs_code, rate FROM customs_tariffs ORDER BY id;")
    rows = cur_res.fetchall()
    assert len(rows) == 2
    assert rows[0] == ("8471.30.00", 5.0)
    assert rows[1] == ("8517.12.00", 10.0)
    conn_restored.close()


def test_prune_backups_in_dir(tmp_path):
    backup_dir = tmp_path / "backups"
    backup_dir.mkdir()

    # Create 3 backups: today (.enc), 10 days ago (.db), 40 days ago (.db.enc)
    now = datetime.now(timezone.utc)
    b_new = backup_dir / "daily_backup_new.db.enc"
    b_new.write_bytes(b"new")

    b_mid = backup_dir / "daily_backup_mid.db"
    b_mid.write_bytes(b"mid")
    mid_time = (now - timedelta(days=10)).timestamp()
    os.utime(b_mid, (mid_time, mid_time))

    b_old = backup_dir / "daily_backup_old.db.enc"
    b_old.write_bytes(b"old")
    old_time = (now - timedelta(days=40)).timestamp()
    os.utime(b_old, (old_time, old_time))

    # R9: the newest 7 daily backups are always kept, so add 5 more recent ones (8 in total);
    # the 40-day-old file is then outside the floor and past the 30-day retention.
    for i in range(5):
        (backup_dir / f"daily_backup_recent_{i}.db").write_bytes(b"recent")

    # Prune with 30-day retention
    deleted_count = prune_backups_in_dir(backup_dir, retention_days=30)
    assert deleted_count == 1
    assert b_new.exists()
    assert b_mid.exists()
    assert not b_old.exists()


def test_observability_offsite_backup_alert(isolated_db):
    dispatcher = AlertDispatcher()
    dispatcher.reset_cooldown()

    # 1. Simulate offsite backup overdue (> 26 hours)
    results = dispatcher.evaluate_all(
        db=isolated_db,
        force=True,
        offsite_age_hours_override=28.5,
    )
    overdue_alerts = [r for r in results if r["condition_key"] == "OFFSITE_BACKUP_OVERDUE"]
    assert len(overdue_alerts) == 1
    assert overdue_alerts[0]["severity"] == "HIGH"
    assert overdue_alerts[0]["target_tab"] == "deep-health"

    # 2. Simulate fresh offsite backup (2 hours)
    dispatcher.reset_cooldown()
    results_fresh = dispatcher.evaluate_all(
        db=isolated_db,
        force=True,
        offsite_age_hours_override=2.0,
    )
    fresh_alerts = [r for r in results_fresh if r["condition_key"] == "OFFSITE_BACKUP_OVERDUE"]
    assert len(fresh_alerts) == 0
