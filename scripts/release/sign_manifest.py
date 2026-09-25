"""
Stand-alone update-manifest signer (docs/plans/update-system-plan.md sections 4.2, 4.3, 9; security review).

This is the ONLY code that touches the Ed25519 private key. It deliberately imports nothing from the app
(no fastapi / sqlalchemy / httpx / pydantic / modules.*): the standard library plus `cryptography` only, so CI runs it
in an isolated venv installed with `pip install --require-hashes -r scripts/release/requirements-sign.txt`, before any
application dependency is installed. Full client-rule verification happens afterwards, in a separate step without
secrets, with scripts/release/verify_manifest.py (the app's ManifestVerifier).

Sign (CI publish job / manual fallback):
  python -I scripts/release/sign_manifest.py --in manifest.unsigned.json --out manifest.json \
      [--installer Sorour_Logistics_Setup_v2.1.0.exe] [--key-file key.pem] [--key-id k2026a] \
      [--expires-days 90 | --expires-at 2027-01-01T00:00:00Z] [--previous-from-manifest live-manifest.json] \
      [--mandatory] [--min-supported-version 2.0.0]
  The key comes from --key-file or the env var UPDATE_SIGNING_KEY_ED25519 (unencrypted PKCS#8 PEM, or base64 of the
  raw 32-byte seed). It is never printed, logged or echoed in an error.

  Fields set before signing:
    expires_at  REQUIRED, ISO-8601 UTC 'Z', after released_at. Kept from the build payload (build_manifest.py writes
                released_at + 90 days) unless --expires-days (released_at + N) or --expires-at is given.
    previous    OPTIONAL {"version", "installer": {"path", "size_bytes", "sha256"}}: the release currently live (read
                from the published manifest, whose signature must verify with this key), for the app's rollback
                path. Omitted on the first release or after a key rotation.

Re-sign the published manifest before it expires (CI workflow resign_update_manifest.yml / manual):
  python -I scripts/release/sign_manifest.py --resign live-manifest.json --out manifest.json [--expires-days 90]
  The live manifest must verify with this key; only expires_at changes (now + N days, default 90).

Generate a key pair (once, offline):
  python scripts/release/sign_manifest.py --generate-key --key-out D:/secure/importflow_update_k2026a.pem

Exit code: 0 = written, 1 = validation / signing failure, 2 = bad arguments.
"""
from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, Mapping, Optional, Sequence, Tuple

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey

KEY_ENV_VAR = "UPDATE_SIGNING_KEY_ED25519"
DEFAULT_KEY_ID = "k2026a"
DEFAULT_EXPIRES_DAYS = 90
MAX_EXPIRES_DAYS = 365
# Must equal modules/app_update/validators.MANIFEST_MAX_BYTES (a test pins it; no app import here by design).
MANIFEST_MAX_BYTES = 64 * 1024
MANIFEST_SCHEMA = 1
MANIFEST_APP = "sorour-logistics"

KEY_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,32}$")
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
INSTALLER_PATH_RE = re.compile(r"^releases/\d+\.\d+\.\d+/[A-Za-z0-9][A-Za-z0-9._-]*\.exe$")
_HASH_CHUNK = 1024 * 1024


class SignerError(Exception):
    """User-facing failure. Messages never contain key material."""


# ─── small helpers ────────────────────────────────────────────────────────────

def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(_HASH_CHUNK), b""):
            digest.update(chunk)
    return digest.hexdigest()


def atomic_write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    with open(tmp, "wb") as fh:
        fh.write(data)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)


def parse_version(value: object) -> Tuple[int, int, int]:
    if not isinstance(value, str) or not VERSION_RE.match(value):
        raise SignerError(f"invalid version {value!r}")
    major, minor, patch = (int(p) for p in value.split("."))
    return major, minor, patch


def iso_utc(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_iso_utc(value: str, what: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        raise SignerError(f"{what} must be ISO-8601, e.g. 2026-11-01T00:00:00Z") from None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def validate_key_id(key_id: str) -> str:
    if not isinstance(key_id, str) or not KEY_ID_RE.match(key_id):
        raise SignerError("key_id must be 1-32 characters of A-Z, a-z, 0-9, '_' or '-'")
    return key_id


def serialise_payload(payload: Mapping[str, object]) -> str:
    """The one serialisation of `signed` (compact, UTF-8, key order preserved)."""
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


# ─── keys ─────────────────────────────────────────────────────────────────────

def public_key_b64(private_key: Ed25519PrivateKey) -> str:
    raw = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw
    )
    return base64.b64encode(raw).decode("ascii")


def parse_private_key(material: str) -> Ed25519PrivateKey:
    """Unencrypted PKCS#8 PEM or base64 of the raw 32-byte seed. Errors never echo the input."""
    text = (material or "").strip()
    if not text:
        raise SignerError("signing key is empty")
    try:
        if text.startswith("-----BEGIN"):
            key = serialization.load_pem_private_key(text.encode("ascii"), password=None)
        else:
            raw = base64.b64decode(text, validate=True)
            if len(raw) != 32:
                raise ValueError("wrong length")
            key = Ed25519PrivateKey.from_private_bytes(raw)
    except (ValueError, TypeError, binascii.Error, UnicodeEncodeError):
        raise SignerError(
            "signing key could not be loaded (expected an unencrypted Ed25519 PKCS#8 PEM or base64 32-byte seed)"
        ) from None
    if not isinstance(key, Ed25519PrivateKey):
        raise SignerError("signing key is not an Ed25519 private key")
    return key


def load_private_key(key_file: Optional[str], env: Optional[Mapping[str, str]] = None) -> Ed25519PrivateKey:
    environ = os.environ if env is None else env
    if key_file:
        path = Path(key_file)
        if not path.is_file():
            raise SignerError(f"key file not found: {path}")
        return parse_private_key(path.read_text(encoding="ascii", errors="replace"))
    material = environ.get(KEY_ENV_VAR, "")
    if not material.strip():
        raise SignerError(f"no signing key: pass --key-file or set {KEY_ENV_VAR}")
    return parse_private_key(material)


def generate_key(key_out: str, key_id: str, public_out: Optional[str] = None) -> Dict[str, str]:
    """Write a new private key (0600, never overwrites) and return {key_id, public_key, key_file}."""
    validate_key_id(key_id)
    path = Path(key_out)
    if path.exists():
        raise SignerError(f"refusing to overwrite an existing key file: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    private_key = Ed25519PrivateKey.generate()
    pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    fd = os.open(str(path), os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0), 0o600)
    with os.fdopen(fd, "wb") as fh:
        fh.write(pem)
    public = public_key_b64(private_key)
    if public_out:
        Path(public_out).write_text(f"{key_id} {public}\n", encoding="ascii")
    return {"key_id": key_id, "public_key": public, "key_file": str(path)}


def print_generated_key(result: Mapping[str, str]) -> None:
    print(f"Private key written to: {result['key_file']}")
    print("Store it offline (password manager + USB) and in the GitHub environment secret")
    print(f"'{KEY_ENV_VAR}' (environment 'production-updates'). Never commit it.")
    print(f"key_id:     {result['key_id']}")
    print(f"public key: {result['public_key']}")
    print("Line for UPDATE_SIGNING_PUBLIC_KEYS in modules/app_update/service.py:")
    print(f'    "{result["key_id"]}": "{result["public_key"]}",')


# ─── payload ──────────────────────────────────────────────────────────────────

def _installer_block(block: object, where: str) -> Dict[str, object]:
    if not isinstance(block, dict):
        raise SignerError(f"{where}: installer block missing")
    path, size, digest = block.get("path"), block.get("size_bytes"), block.get("sha256")
    if not isinstance(path, str) or not INSTALLER_PATH_RE.match(path) or ".." in path:
        raise SignerError(f"{where}: installer path must be releases/<X.Y.Z>/<name>.exe")
    if isinstance(size, bool) or not isinstance(size, int) or size <= 0:
        raise SignerError(f"{where}: installer size_bytes must be a positive integer")
    if not isinstance(digest, str) or not SHA256_RE.match(digest):
        raise SignerError(f"{where}: installer sha256 must be 64 lower-case hex characters")
    return {"path": path, "size_bytes": size, "sha256": digest}


def parse_payload(signed: str, where: str = "payload") -> Dict[str, object]:
    try:
        payload = json.loads(signed)
    except ValueError:
        raise SignerError(f"{where} is not valid JSON") from None
    if not isinstance(payload, dict):
        raise SignerError(f"{where} must be a JSON object")
    if payload.get("schema") != MANIFEST_SCHEMA or payload.get("app") != MANIFEST_APP:
        raise SignerError(f"{where}: wrong schema or app")
    parse_version(payload.get("version"))
    _installer_block(payload.get("installer"), where)
    return payload


def read_unsigned(path: str) -> Dict[str, object]:
    file = Path(path)
    if not file.is_file():
        raise SignerError(f"unsigned manifest not found: {file}")
    try:
        data = json.loads(file.read_text(encoding="utf-8"))
    except ValueError:
        raise SignerError("unsigned manifest is not valid JSON") from None
    signed = data.get("signed") if isinstance(data, dict) else None
    if not isinstance(signed, str) or not signed:
        raise SignerError("unsigned manifest has no 'signed' payload string")
    return parse_payload(signed, "unsigned payload")


def check_installer(payload: Mapping[str, object], installer: str) -> None:
    block = payload["installer"]
    exe = Path(installer)
    if not exe.is_file():
        raise SignerError(f"installer not found: {exe}")
    if exe.name != str(block["path"]).rsplit("/", 1)[-1]:
        raise SignerError("installer file name does not match the manifest path")
    if exe.stat().st_size != block["size_bytes"]:
        raise SignerError("installer size does not match the manifest")
    if sha256_file(exe) != block["sha256"]:
        raise SignerError("installer sha256 does not match the manifest")


def build_previous_block(version: str, installer: Mapping[str, object]) -> Dict[str, object]:
    """
    Shape of the signed, optional `previous` block (single place to change it), as parsed by
    modules/app_update/service.py ManifestVerifier:
      {"version": "X.Y.Z" (strictly older), "installer": {"path", "size_bytes", "sha256"}}
    """
    return {
        "version": version,
        "installer": {
            "path": installer["path"],
            "size_bytes": installer["size_bytes"],
            "sha256": installer["sha256"],
        },
    }


def _previous_installer(block: Mapping[str, object]) -> Mapping[str, object]:
    """Nested `installer` object (current shape); a legacy flat block is still read."""
    nested = block.get("installer")
    return nested if isinstance(nested, dict) else block


def verify_envelope(raw: bytes, private_key: Ed25519PrivateKey, key_id: str, what: str) -> Dict[str, object]:
    """Check a published envelope was signed by THIS key (same key_id). Returns the parsed payload."""
    try:
        envelope = json.loads(raw.decode("utf-8"))
        live_key_id, signature, signed = envelope["key_id"], envelope["signature"], envelope["signed"]
        if not all(isinstance(v, str) for v in (live_key_id, signature, signed)):
            raise ValueError("envelope fields must be strings")
    except (UnicodeDecodeError, ValueError, KeyError, TypeError):
        raise SignerError(f"{what} is not a signed manifest envelope") from None
    if live_key_id != key_id:
        raise SignerError(f"{what} uses key_id {live_key_id!r}, not {key_id!r}")
    try:
        private_key.public_key().verify(base64.b64decode(signature, validate=True), signed.encode("utf-8"))
    except (InvalidSignature, binascii.Error, ValueError):
        raise SignerError(f"{what} signature does not verify with this key") from None
    return parse_payload(signed, what)


def previous_from_live_manifest(
    live_raw: bytes, private_key: Ed25519PrivateKey, key_id: str, new_version: str
) -> Tuple[Optional[Dict[str, object]], str]:
    """
    Derive `previous` from the currently published manifest. Returns (block or None, reason).
    A live manifest not signed by this key is ignored (key rotation / tampering): no previous block.
    A live version newer than the one being signed is an error (it would be a downgrade).
    """
    try:
        live = verify_envelope(live_raw, private_key, key_id, "live manifest")
    except SignerError as exc:
        return None, f"{exc}; no previous block"
    live_version = str(live["version"])
    if parse_version(live_version) > parse_version(new_version):
        raise SignerError(f"live manifest version {live_version} is newer than {new_version}: refusing a downgrade")
    if live_version == new_version:
        # Re-publishing the same version: keep whatever it already pointed back to.
        prev = live.get("previous")
        if not isinstance(prev, dict):
            return None, f"re-publishing {new_version}; live manifest had no previous block"
        prev_version = prev.get("version")
        if parse_version(prev_version) >= parse_version(new_version):
            raise SignerError("live manifest previous block is not older than the release")
        return build_previous_block(str(prev_version), _installer_block(_previous_installer(prev), "live previous")), (
            f"re-publishing {new_version}; previous stays {prev_version}"
        )
    return build_previous_block(live_version, _installer_block(live["installer"], "live manifest")), (
        f"previous = live release {live_version}"
    )


def resolve_expires_at(base: datetime, expires_days: Optional[int] = None, expires_at: Optional[str] = None) -> datetime:
    """Explicit --expires-at wins; otherwise base + N days (default DEFAULT_EXPIRES_DAYS)."""
    if expires_at:
        return parse_iso_utc(expires_at, "--expires-at")
    days = DEFAULT_EXPIRES_DAYS if expires_days is None else expires_days
    if not 1 <= days <= MAX_EXPIRES_DAYS:
        raise SignerError(f"--expires-days must be between 1 and {MAX_EXPIRES_DAYS}")
    return base + timedelta(days=days)


def released_at_of(payload: Mapping[str, object]) -> datetime:
    value = payload.get("released_at")
    if not isinstance(value, str) or not value:
        raise SignerError("payload has no released_at")
    return parse_iso_utc(value, "released_at")


def finalise_payload(
    payload: Mapping[str, object],
    *,
    expires_at: datetime,
    previous: Optional[Mapping[str, object]] = None,
    keep_previous: bool = False,
    now: Optional[datetime] = None,
) -> Dict[str, object]:
    """Set expires_at (required: after released_at and in the future) and the optional previous block."""
    current = now or datetime.now(timezone.utc)
    if expires_at <= released_at_of(payload):
        raise SignerError("expires_at must be after released_at")
    if expires_at <= current:
        raise SignerError("expires_at must be in the future")
    result = dict(payload)
    result["expires_at"] = iso_utc(expires_at)
    if previous is not None:
        prev_version = previous.get("version")
        if parse_version(prev_version) >= parse_version(result["version"]):
            raise SignerError("previous.version must be older than version")
        result["previous"] = dict(previous)
    elif not keep_previous:
        result.pop("previous", None)
    return result


# ─── signing ──────────────────────────────────────────────────────────────────

def sign_payload(signed: str, private_key: Ed25519PrivateKey, key_id: str) -> bytes:
    """Return the envelope bytes; the signature is re-verified with the derived public key."""
    validate_key_id(key_id)
    signature = private_key.sign(signed.encode("utf-8"))
    envelope = {
        "key_id": key_id,
        "signature": base64.b64encode(signature).decode("ascii"),
        "signed": signed,
    }
    raw = (json.dumps(envelope, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if len(raw) > MANIFEST_MAX_BYTES:
        raise SignerError(f"manifest is {len(raw)} bytes, the client cap is {MANIFEST_MAX_BYTES}")
    verify_envelope(raw, private_key, key_id, "signed manifest")
    return raw


def _read_capped(path: Path, what: str) -> bytes:
    if path.stat().st_size > MANIFEST_MAX_BYTES:
        raise SignerError(f"{what} exceeds the client size cap")
    return path.read_bytes()


def sign_file(
    unsigned_path: str,
    out_path: str,
    private_key: Ed25519PrivateKey,
    key_id: str,
    *,
    installer: Optional[str] = None,
    expires_days: Optional[int] = None,
    expires_at: Optional[str] = None,
    live_manifest: Optional[str] = None,
    mandatory: bool = False,
    min_supported_version: Optional[str] = None,
) -> Tuple[bytes, str]:
    """
    Sign a build payload. expires_at: explicit > released_at + expires_days > the payload's own value >
    released_at + DEFAULT_EXPIRES_DAYS. `mandatory` / `min_supported_version` are publish-time choices
    (Publish update workflow inputs); when given they replace the build payload's values.
    """
    payload = read_unsigned(unsigned_path)
    if installer:
        check_installer(payload, installer)
    if mandatory:
        payload["mandatory"] = True
    if min_supported_version:
        if parse_version(min_supported_version) > parse_version(payload["version"]):
            raise SignerError("--min-supported-version cannot be newer than the release version")
        payload["min_supported_version"] = min_supported_version
    if expires_at or expires_days is not None or not payload.get("expires_at"):
        expiry = resolve_expires_at(released_at_of(payload), expires_days, expires_at)
    else:
        expiry = parse_iso_utc(str(payload["expires_at"]), "expires_at")
    previous, reason = None, "no live manifest given; no previous block"
    if live_manifest:
        live_path = Path(live_manifest)
        if live_path.is_file() and live_path.stat().st_size > 0:
            previous, reason = previous_from_live_manifest(
                _read_capped(live_path, "live manifest"), private_key, key_id, str(payload["version"])
            )
        else:
            reason = "no published manifest yet; no previous block"
    final = finalise_payload(payload, expires_at=expiry, previous=previous)
    raw = sign_payload(serialise_payload(final), private_key, key_id)
    atomic_write_bytes(Path(out_path), raw)
    return raw, reason


def resign_file(
    live_path: str,
    out_path: str,
    private_key: Ed25519PrivateKey,
    key_id: str,
    *,
    expires_days: Optional[int] = None,
    expires_at: Optional[str] = None,
) -> Tuple[bytes, str]:
    """
    Re-sign the published manifest with a fresh expires_at (now + N days, default DEFAULT_EXPIRES_DAYS).
    It must verify with this key; every other field (version, installer, previous, notes) is kept unchanged.
    """
    path = Path(live_path)
    if not path.is_file():
        raise SignerError(f"published manifest not found: {path}")
    live = verify_envelope(_read_capped(path, "published manifest"), private_key, key_id, "published manifest")
    old_expiry = live.get("expires_at")
    expiry = resolve_expires_at(datetime.now(timezone.utc), expires_days, expires_at)
    final = finalise_payload(live, expires_at=expiry, keep_previous=True)
    raw = sign_payload(serialise_payload(final), private_key, key_id)
    atomic_write_bytes(Path(out_path), raw)
    return raw, f"re-signed {live['version']}: expires_at {old_expiry} -> {final['expires_at']}"


# ─── CLI ──────────────────────────────────────────────────────────────────────

def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Sign the ImportFlow update manifest (stand-alone signer).")
    p.add_argument("--generate-key", action="store_true", help="create a new Ed25519 signing key pair")
    p.add_argument("--key-out", help="with --generate-key: where to write the private key (must not exist)")
    p.add_argument("--public-out", help="with --generate-key: optional file for '<key_id> <public key>'")
    p.add_argument("--key-id", default=DEFAULT_KEY_ID, help=f"signing key id (default {DEFAULT_KEY_ID})")
    mode = p.add_mutually_exclusive_group()
    mode.add_argument("--in", dest="unsigned", help="unsigned payload file from build_manifest.py")
    mode.add_argument("--resign", help="published manifest.json to re-sign with a new expires_at")
    p.add_argument("--out", help="signed manifest output")
    p.add_argument("--installer", help="with --in: installer .exe; must match the payload size and sha256")
    p.add_argument("--key-file", help=f"private key file (default: env {KEY_ENV_VAR})")
    p.add_argument("--expires-days", type=int,
                   help=f"--in: released_at + N days; --resign: now + N days (default {DEFAULT_EXPIRES_DAYS})")
    p.add_argument("--expires-at", help="explicit ISO-8601 UTC expiry (overrides --expires-days)")
    p.add_argument("--previous-from-manifest", help="with --in: currently published manifest.json (missing = none)")
    p.add_argument("--mandatory", action="store_true", help="with --in: mark the update as mandatory")
    p.add_argument("--min-supported-version", help="with --in: installs older than X.Y.Z must update")
    return p


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.generate_key:
            if not args.key_out:
                print("error: --generate-key needs --key-out PATH", file=sys.stderr)
                return 2
            print_generated_key(generate_key(args.key_out, args.key_id, args.public_out))
            return 0
        if not (args.unsigned or args.resign) or not args.out:
            print("error: pass --in or --resign, and --out", file=sys.stderr)
            return 2
        key_id = validate_key_id(args.key_id)
        key = load_private_key(args.key_file)
        if args.resign:
            raw, reason = resign_file(
                args.resign, args.out, key, key_id, expires_days=args.expires_days, expires_at=args.expires_at
            )
        else:
            raw, reason = sign_file(
                args.unsigned, args.out, key, key_id, installer=args.installer,
                expires_days=args.expires_days, expires_at=args.expires_at,
                live_manifest=args.previous_from_manifest,
                mandatory=args.mandatory, min_supported_version=args.min_supported_version,
            )
        payload = json.loads(json.loads(raw.decode("utf-8"))["signed"])
        print(f"Signed manifest written to {args.out} (key_id {key_id}, {len(raw)} bytes)")
        print(f"version {payload['version']} expires_at {payload['expires_at']}; {reason}")
        return 0
    except SignerError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
