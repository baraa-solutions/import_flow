"""
DB safety follow-ups (docs/plans/update-system-plan.md section 0):

- Mailbox passwords saved by the old frozen build were encrypted with the hard-coded fallback key
  (SECRET_KEY never reached os.environ there). Now that SECRET_KEY is a persisted random key they must
  still decrypt (MultiFernet current + legacy) and move to the current key on the next save.
- ALLOW_DEV_AUTH_BYPASS is ignored in the production build even if {app}\\.env sets it.
- ADMIN_INITIAL_PASSWORD is never written to .env any more (the seeded admin gets a known default and
  must change it on first login). A leftover line from an old 2.1.x install is still removed from .env
  in the frozen build once the admin has changed the password.
- system_observability paths follow the live DB (R11).
"""
import logging
import os
import sys
from pathlib import Path

import pytest
from cryptography.fernet import Fernet
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.master_data_sync_service as mds
import settings
from database.database import Base, DB_PATH
from modules.auth.security import hash_password
from modules.smart_email_listener import crypto as email_crypto
from modules.users.model import User

NEW_SECRET = "n" * 64


@pytest.fixture(autouse=True)
def _restore_env():
    keys = ("SECRET_KEY", "ALLOW_DEV_AUTH_BYPASS", "ADMIN_INITIAL_PASSWORD")
    saved = {k: os.environ.get(k) for k in keys}
    yield
    for k, v in saved.items():
        if v is None:
            os.environ.pop(k, None)
        else:
            os.environ[k] = v


def _legacy_token(plain: str) -> str:
    """What the old frozen build stored: SECRET_KEY absent -> hard-coded fallback key."""
    return "enc:" + email_crypto._fernet_for(email_crypto.LEGACY_FALLBACK_SECRET).encrypt(plain.encode()).decode()


# ---------------------------------------------------------------- mailbox passwords

def test_password_encrypted_by_old_frozen_build_still_decrypts(monkeypatch):
    stored = _legacy_token("imap-app-password")  # old frozen token stored under legacy key
    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)                        # new build: persisted random key
    assert email_crypto.decrypt_email_password(stored) == "imap-app-password"


def test_encrypt_without_secret_key_raises_runtime_error(monkeypatch):
    monkeypatch.delenv("SECRET_KEY", raising=False)
    with pytest.raises(RuntimeError, match="SECRET_KEY is not configured"):
        email_crypto.encrypt_email_password("imap-app-password")


def test_legacy_password_is_moved_to_current_key_on_save(monkeypatch):
    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)
    legacy = _legacy_token("smtp-pass")
    assert email_crypto.is_encrypted_with_current_key(legacy) is False

    rotated = email_crypto.encrypt_email_password(legacy)  # setter receiving the stored value
    assert rotated != legacy
    assert email_crypto.is_encrypted_with_current_key(rotated) is True
    assert email_crypto.decrypt_email_password(rotated) == "smtp-pass"

    fresh = email_crypto.encrypt_email_password("typed-again")  # user re-enters the password
    assert email_crypto.is_encrypted_with_current_key(fresh) is True


def test_new_encryptions_never_use_the_legacy_key(monkeypatch):
    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)
    token = email_crypto.encrypt_email_password("x")[4:].encode()
    legacy_only = email_crypto._fernet_for(email_crypto.LEGACY_FALLBACK_SECRET)
    with pytest.raises(Exception):
        legacy_only.decrypt(token)


def test_email_settings_model_round_trip_with_legacy_value(monkeypatch):
    from modules.smart_email_listener.model import EmailSettings

    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)
    row = EmailSettings(email_address="a@b.c", username="a@b.c")
    row._password = _legacy_token("mailbox-secret")
    assert row.password == "mailbox-secret"
    row.password = "mailbox-secret-2"
    assert email_crypto.is_encrypted_with_current_key(row._password)
    assert row.password == "mailbox-secret-2"


def test_unknown_key_returns_stored_value_and_warns(monkeypatch, caplog):
    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)
    foreign = "enc:" + Fernet(Fernet.generate_key()).encrypt(b"x").decode()
    with caplog.at_level(logging.WARNING, logger="smart_email_listener.crypto"):
        assert email_crypto.decrypt_email_password(foreign) == foreign
        assert email_crypto.encrypt_email_password(foreign) == foreign  # never destroyed
    assert "could not be decrypted" in caplog.text


def test_plaintext_legacy_passwords_still_pass_through():
    assert email_crypto.decrypt_email_password("plain") == "plain"
    assert email_crypto.decrypt_email_password("") == ""


# ---------------------------------------------------------------- dev auth bypass

def test_dev_auth_bypass_ignored_in_production_build(monkeypatch, caplog):
    monkeypatch.setenv("ALLOW_DEV_AUTH_BYPASS", "true")
    with caplog.at_level(logging.CRITICAL, logger="settings"):
        assert settings.resolve_dev_auth_bypass(is_production_build=True) is False
    assert "IGNORED" in caplog.text


def test_dev_auth_bypass_honoured_in_dev(monkeypatch):
    monkeypatch.setenv("ALLOW_DEV_AUTH_BYPASS", "1")
    assert settings.resolve_dev_auth_bypass(is_production_build=False) is True
    monkeypatch.setenv("ALLOW_DEV_AUTH_BYPASS", "false")
    assert settings.resolve_dev_auth_bypass(is_production_build=True) is False


# ---------------------------------------------------------------- initial admin password in .env

@pytest.fixture
def user_db(tmp_path, monkeypatch):
    env_file = tmp_path / ".env"
    env_file.write_text("SECRET_KEY=" + "s" * 40 + "\nOTHER=keep\n", encoding="utf-8")
    monkeypatch.setattr(settings, "ENV_PATH", env_file)
    monkeypatch.setattr(mds, "ADMIN_INITIAL_PASSWORD", "Initial-Admin-1!")
    engine = create_engine(f"sqlite:///{(tmp_path / 'users.db').as_posix()}")
    Base.metadata.create_all(bind=engine, tables=[User.__table__])
    session = sessionmaker(bind=engine)()
    yield session, env_file
    session.close()
    engine.dispose()


def _add_leftover_env_line(env_file) -> None:
    """What an old 2.1.x install left in .env after seeding its random admin password."""
    with open(env_file, "a", encoding="utf-8") as fh:
        fh.write("ADMIN_INITIAL_PASSWORD=Initial-Admin-1!\n")


def test_seeding_never_writes_admin_password_to_env(user_db):
    session, env_file = user_db
    before = env_file.read_text(encoding="utf-8")
    assert mds.MasterDataSyncService(session).sync_system_users() == 1
    assert mds.MasterDataSyncService(session).sync_system_users() == 0  # second start: nothing seeded
    assert env_file.read_text(encoding="utf-8") == before
    assert not hasattr(settings, "persist_admin_initial_password")
    assert not hasattr(settings, "load_or_create_admin_password")


def test_frozen_build_removes_admin_password_after_it_was_changed(user_db, monkeypatch):
    session, env_file = user_db
    mds.MasterDataSyncService(session).sync_system_users()
    _add_leftover_env_line(env_file)
    monkeypatch.setattr(sys, "frozen", True, raising=False)

    mds.MasterDataSyncService(session).sync_system_users()  # unchanged password: line kept
    assert "ADMIN_INITIAL_PASSWORD=" in env_file.read_text(encoding="utf-8")

    admin = session.query(User).filter(User.username == "admin").one()
    admin.hashed_password = hash_password("Changed-By-Admin-9!")
    session.commit()
    mds.MasterDataSyncService(session).sync_system_users()

    text = env_file.read_text(encoding="utf-8")
    assert "ADMIN_INITIAL_PASSWORD=" not in text
    assert "OTHER=keep" in text and "SECRET_KEY=" in text


def test_dev_build_never_rewrites_the_developer_env(user_db, monkeypatch):
    session, env_file = user_db
    monkeypatch.delattr(sys, "frozen", raising=False)
    mds.MasterDataSyncService(session).sync_system_users()
    _add_leftover_env_line(env_file)
    admin = session.query(User).filter(User.username == "admin").one()
    admin.hashed_password = hash_password("Changed-By-Admin-9!")
    session.commit()
    mds.MasterDataSyncService(session).sync_system_users()
    assert "ADMIN_INITIAL_PASSWORD=" in env_file.read_text(encoding="utf-8")


def test_remove_env_key_keeps_other_lines(tmp_path):
    env_file = tmp_path / ".env"
    env_file.write_text("A=1\nADMIN_INITIAL_PASSWORD=x\nB=2\nADMIN_INITIAL_PASSWORD=y\n", encoding="utf-8")
    assert settings.remove_env_key(env_file, "ADMIN_INITIAL_PASSWORD") is True
    assert env_file.read_text(encoding="utf-8") == "A=1\nB=2\n"
    assert settings.remove_env_key(env_file, "ADMIN_INITIAL_PASSWORD") is False


# ---------------------------------------------------------------- system_observability paths (R11)

def test_system_observability_paths_follow_live_db():
    from modules.system_observability import service as obs

    live = Path(DB_PATH).resolve()
    assert obs.DB_PATH == live
    assert obs.BACKUPS_DIR == live.parent / "backups"


# ---------------------------------------------------------------- follow-up: rotation on save, admin password change

def _register_all_models() -> None:
    import importlib

    for model_file in sorted((Path(__file__).resolve().parents[2] / "modules").glob("*/model.py")):
        importlib.import_module(f"modules.{model_file.parent.name}.model")


@pytest.fixture
def full_db(tmp_path):
    _register_all_models()
    engine = create_engine(f"sqlite:///{(tmp_path / 'full.db').as_posix()}")
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    yield session
    session.close()
    engine.dispose()


def _email_row(session, stored_password: str):
    from modules.smart_email_listener.model import EmailSettings

    row = EmailSettings(email_address="ops@example.com", username="ops@example.com")
    row._password = stored_password
    session.add(row)
    session.commit()
    return row


def test_empty_password_update_moves_legacy_value_to_current_key(full_db, monkeypatch):
    from modules.smart_email_listener.repository import save_or_update_email_settings

    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)
    row = _email_row(full_db, _legacy_token("mailbox-secret"))

    saved = save_or_update_email_settings(full_db, {"password": "", "sender_display_name": "Ops"})

    assert email_crypto.is_encrypted_with_current_key(saved._password)
    assert saved.password == "mailbox-secret"
    assert saved.sender_display_name == "Ops"
    assert saved.settings_id == row.settings_id


def test_empty_password_update_encrypts_legacy_plaintext(full_db, monkeypatch):
    from modules.smart_email_listener.repository import save_or_update_email_settings

    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)
    _email_row(full_db, "plain-old-password")
    saved = save_or_update_email_settings(full_db, {"password": ""})
    assert saved._password.startswith("enc:")
    assert saved.password == "plain-old-password"


def test_empty_password_update_leaves_current_and_unknown_values_alone(full_db, monkeypatch):
    from modules.smart_email_listener.repository import save_or_update_email_settings

    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)
    current = email_crypto.encrypt_email_password("already-current")
    row = _email_row(full_db, current)
    assert save_or_update_email_settings(full_db, {"password": ""})._password == current

    foreign = "enc:" + Fernet(Fernet.generate_key()).encrypt(b"x").decode()
    row._password = foreign
    full_db.commit()
    assert save_or_update_email_settings(full_db, {"password": ""})._password == foreign


@pytest.fixture
def admin_env(full_db, tmp_path, monkeypatch):
    from modules.auth.permissions import invalidate_permission_cache

    env_file = tmp_path / "app.env"
    env_file.write_text("SECRET_KEY=" + "s" * 40 + "\nADMIN_INITIAL_PASSWORD=Initial-Admin-1!\nOTHER=keep\n",
                        encoding="utf-8")
    monkeypatch.setattr(settings, "ENV_PATH", env_file)
    monkeypatch.setattr(settings, "ADMIN_INITIAL_PASSWORD", "Initial-Admin-1!")
    admin = User(username="admin", email="admin@example.com", full_name="Admin",
                 hashed_password=hash_password("Initial-Admin-1!"), role="ADMIN", is_active=True)
    other = User(username="operator1", email="op1@example.com", full_name="Op",
                 hashed_password=hash_password("Operator-123"), role="OPERATOR", is_active=True)
    full_db.add_all([admin, other])
    full_db.commit()
    invalidate_permission_cache()
    yield full_db, env_file, admin, other
    invalidate_permission_cache()


def _change_password(session, target, actor, new_password):
    from modules.auth.schemas import UserUpdate
    from modules.auth.service import AuthService

    return AuthService(session).update_user(target.user_id, UserUpdate(password=new_password), actor=actor)


def test_frozen_admin_password_change_removes_initial_password_immediately(admin_env, monkeypatch):
    session, env_file, admin, _ = admin_env
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    _change_password(session, admin, admin, "Brand-New-Admin-7")
    text = env_file.read_text(encoding="utf-8")
    assert "ADMIN_INITIAL_PASSWORD=" not in text
    assert "OTHER=keep" in text and "SECRET_KEY=" in text


def test_dev_admin_password_change_never_touches_env(admin_env, monkeypatch):
    session, env_file, admin, _ = admin_env
    monkeypatch.delattr(sys, "frozen", raising=False)
    before = env_file.read_text(encoding="utf-8")
    _change_password(session, admin, admin, "Brand-New-Admin-7")
    assert env_file.read_text(encoding="utf-8") == before


def test_frozen_other_user_password_change_keeps_initial_password(admin_env, monkeypatch):
    session, env_file, admin, other = admin_env
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    _change_password(session, other, admin, "Operator-456")
    assert "ADMIN_INITIAL_PASSWORD=" in env_file.read_text(encoding="utf-8")


def test_frozen_admin_update_without_password_keeps_initial_password(admin_env, monkeypatch):
    from modules.auth.schemas import UserUpdate
    from modules.auth.service import AuthService

    session, env_file, admin, _ = admin_env
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    AuthService(session).update_user(admin.user_id, UserUpdate(full_name="Renamed"), actor=admin)
    assert "ADMIN_INITIAL_PASSWORD=" in env_file.read_text(encoding="utf-8")


def test_frozen_rejected_weak_password_keeps_initial_password(admin_env, monkeypatch):
    from fastapi import HTTPException

    session, env_file, admin, _ = admin_env
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    with pytest.raises(HTTPException):
        _change_password(session, admin, admin, "short")
    assert "ADMIN_INITIAL_PASSWORD=" in env_file.read_text(encoding="utf-8")
