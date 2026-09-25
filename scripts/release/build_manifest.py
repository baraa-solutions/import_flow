"""
Build the update manifest payload (docs/plans/update-system-plan.md sections 4.2, 4.3, 9).

The manifest is one JSON envelope {key_id, signature, signed}. `signed` is a JSON string and the signature is
Ed25519 over its exact UTF-8 bytes, so the client (modules/app_update/service.py ManifestVerifier) can verify it
without any canonicalisation. This script applies the same client rules to the payload it builds.

All private-key handling lives in the stand-alone signer scripts/release/sign_manifest.py (no app imports; CI runs it
in an isolated, hash-pinned venv). This script only delegates to it for the local conveniences below.

Modes
-----
1) Unsigned payload (CI build job, no key):
     python scripts/release/build_manifest.py --installer dist/releases/Sorour_Logistics_Setup_v2.1.0.exe \
         --version 2.1.0 --build 210 --notes-ar notes.ar.txt --notes-en notes.en.txt \
         [--mandatory] [--min-supported-version 2.0.0] [--db-schema-revision <head>] \
         [--expires-days 90 | --expires-at 2027-01-01T00:00:00Z] \
         --out dist/update/manifest.unsigned.json
   or take {version, build, filename, size, sha256} from `--release-info dist/releases/release_info.json`
   (add `--installer` too and the file is re-hashed and compared).
   Then sign with: python -I scripts/release/sign_manifest.py --in <unsigned> --out manifest.json ...

2) Build + sign in one go (manual fallback on the CTO's machine): mode 1 arguments plus
     --sign --key-file <pem> [--previous-from-manifest live-manifest.json]
   The key may also come from the env var UPDATE_SIGNING_KEY_ED25519. It is never printed.

3) Generate the signing key pair (same as sign_manifest.py --generate-key):
     python scripts/release/build_manifest.py --generate-key --key-out D:/secure/importflow_update_k2026a.pem

Release notes files: UTF-8 text, one note per line; blank lines and lines starting with '#' are ignored and a
leading "- ", "* " or "• " bullet is stripped.

Exit code: 0 = written, 1 = validation / signing failure, 2 = bad arguments.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Sequence

PROJECT_DIR = Path(__file__).resolve().parents[2]
RELEASE_DIR = Path(__file__).resolve().parent
for _path in (str(PROJECT_DIR), str(RELEASE_DIR)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import sign_manifest as signer  # noqa: E402  (stand-alone signer next to this file)

from modules.app_update.service import ManifestVerifier  # noqa: E402
from modules.app_update.validators import (  # noqa: E402
    INSTALLER_PATH_PREFIX,
    MANIFEST_APP,
    MANIFEST_SCHEMA,
    ManifestError,
    is_newer,
    is_valid_version,
    validate_installer_path,
    validate_sha256,
    validate_size,
)

KEY_ENV_VAR = signer.KEY_ENV_VAR
DEFAULT_KEY_ID = signer.DEFAULT_KEY_ID
UNSIGNED_MARKER = "unsigned"
MAX_NOTES_PER_LANGUAGE = 50
MAX_NOTE_LENGTH = 500
_BULLETS = ("- ", "* ", "\u2022 ")

sha256_file = signer.sha256_file
serialise_payload = signer.serialise_payload
public_key_b64 = signer.public_key_b64


class ReleaseToolError(Exception):
    """A user-facing failure. Messages never contain key material."""


# ─── helpers ──────────────────────────────────────────────────────────────────

def read_release_notes(path: Optional[str]) -> List[str]:
    if not path:
        return []
    file = Path(path)
    if not file.is_file():
        raise ReleaseToolError(f"release notes file not found: {file}")
    notes: List[str] = []
    for line in file.read_text(encoding="utf-8-sig").splitlines():
        item = line.strip()
        if not item or item.startswith("#"):
            continue
        for bullet in _BULLETS:
            if item.startswith(bullet):
                item = item[len(bullet):].strip()
                break
        if not item:
            continue
        if len(item) > MAX_NOTE_LENGTH:
            raise ReleaseToolError(f"release note longer than {MAX_NOTE_LENGTH} characters in {file}")
        notes.append(item)
    if len(notes) > MAX_NOTES_PER_LANGUAGE:
        raise ReleaseToolError(f"more than {MAX_NOTES_PER_LANGUAGE} release notes in {file}")
    return notes


def _normalise_released_at(value: Optional[str]) -> str:
    if not value:
        return signer.iso_utc(datetime.now(timezone.utc))
    try:
        return signer.iso_utc(signer.parse_iso_utc(value, "--released-at"))
    except signer.SignerError as exc:
        raise ReleaseToolError(str(exc)) from None


# ─── release info ─────────────────────────────────────────────────────────────

def resolve_release_info(
    release_info_path: Optional[str],
    installer: Optional[str],
    version: Optional[str],
    build: Optional[int],
) -> Dict[str, object]:
    """Return {version, build, filename, size, sha256}, re-hashing the installer when it is given."""
    info: Dict[str, object] = {}
    if release_info_path:
        path = Path(release_info_path)
        if not path.is_file():
            raise ReleaseToolError(f"release info not found: {path}")
        try:
            loaded = json.loads(path.read_text(encoding="utf-8-sig"))
        except ValueError:
            raise ReleaseToolError(f"release info is not valid JSON: {path}") from None
        if not isinstance(loaded, dict):
            raise ReleaseToolError("release info must be a JSON object")
        info = {k: loaded.get(k) for k in ("version", "build", "filename", "size", "sha256")}

    if version is not None:
        if info.get("version") not in (None, version):
            raise ReleaseToolError("--version does not match release info")
        info["version"] = version
    if build is not None:
        if info.get("build") not in (None, build):
            raise ReleaseToolError("--build does not match release info")
        info["build"] = build

    if installer:
        exe = Path(installer)
        if not exe.is_file():
            raise ReleaseToolError(f"installer not found: {exe}")
        actual = {"filename": exe.name, "size": exe.stat().st_size, "sha256": sha256_file(exe)}
        for key, value in actual.items():
            expected = info.get(key)
            if expected is not None and (str(expected).lower() if key == "sha256" else expected) != value:
                raise ReleaseToolError(f"installer {key} does not match release info")
            info[key] = value

    if not is_valid_version(info.get("version")):
        raise ReleaseToolError("version must be X.Y.Z (pass --version or --release-info)")
    build_no = info.get("build")
    if isinstance(build_no, bool) or not isinstance(build_no, int) or build_no < 0:
        raise ReleaseToolError("build must be a non-negative integer (pass --build or --release-info)")
    if not info.get("filename"):
        raise ReleaseToolError("installer filename missing (pass --installer or --release-info)")
    try:
        info["size"] = validate_size(info.get("size"))
        info["sha256"] = validate_sha256(info.get("sha256"))
    except ManifestError as exc:
        raise ReleaseToolError(f"invalid installer metadata: {exc}") from None
    return info


def build_payload(
    info: Dict[str, object],
    notes_ar: List[str],
    notes_en: List[str],
    *,
    mandatory: bool = False,
    min_supported_version: Optional[str] = None,
    db_schema_revision: Optional[str] = None,
    released_at: Optional[str] = None,
    expires_days: Optional[int] = None,
    expires_at: Optional[str] = None,
) -> Dict[str, object]:
    version = str(info["version"])
    if min_supported_version:
        if not is_valid_version(min_supported_version):
            raise ReleaseToolError("--min-supported-version must be X.Y.Z")
        if is_newer(min_supported_version, version):
            raise ReleaseToolError("--min-supported-version cannot be newer than the release version")
    try:
        path = validate_installer_path(f"{INSTALLER_PATH_PREFIX}{version}/{info['filename']}")
    except ManifestError as exc:
        raise ReleaseToolError(f"installer filename not allowed: {exc}") from None

    released = _normalise_released_at(released_at)
    try:
        expiry = signer.resolve_expires_at(signer.parse_iso_utc(released, "released_at"), expires_days, expires_at)
    except signer.SignerError as exc:
        raise ReleaseToolError(str(exc)) from None

    payload: Dict[str, object] = {
        "schema": MANIFEST_SCHEMA,
        "app": MANIFEST_APP,
        "channel": "stable",
        "version": version,
        "build_number": info["build"],
        "released_at": released,
        "expires_at": signer.iso_utc(expiry),
        "min_supported_version": min_supported_version or None,
        "mandatory": bool(mandatory),
        "db_schema_revision": db_schema_revision or None,
        "release_notes": {"ar": notes_ar, "en": notes_en},
        "installer": {"path": path, "size_bytes": info["size"], "sha256": info["sha256"]},
    }
    try:
        ManifestVerifier._parse_payload(payload, "unsigned", b"")
    except ManifestError as exc:
        raise ReleaseToolError(f"manifest payload rejected by the client rules: {exc}") from None
    return payload


# ─── CLI ──────────────────────────────────────────────────────────────────────

def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Build (and optionally sign) the ImportFlow update manifest.")
    p.add_argument("--generate-key", action="store_true", help="create a new Ed25519 signing key pair")
    p.add_argument("--key-out", help="with --generate-key: where to write the private key (must not exist)")
    p.add_argument("--public-out", help="with --generate-key: optional file for '<key_id> <public key>'")
    p.add_argument("--key-id", default=DEFAULT_KEY_ID, help=f"signing key id (default {DEFAULT_KEY_ID})")

    p.add_argument("--release-info", help="release_info.json {version, build, filename, size, sha256}")
    p.add_argument("--installer", help="installer .exe (hashed and compared)")
    p.add_argument("--version", dest="release_version", help="release version X.Y.Z")
    p.add_argument("--build", type=int, help="build number")
    p.add_argument("--notes-ar", help="Arabic release notes file")
    p.add_argument("--notes-en", help="English release notes file")
    p.add_argument("--mandatory", action="store_true", help="mark the update as mandatory")
    p.add_argument("--min-supported-version", help="installs older than this must update")
    p.add_argument("--db-schema-revision", help="alembic head shipped by this release")
    p.add_argument("--released-at", help="ISO-8601 UTC release time (default: now)")
    p.add_argument("--expires-days", type=int,
                   help=f"expires_at = released_at + N days (default {signer.DEFAULT_EXPIRES_DAYS})")
    p.add_argument("--expires-at", help="explicit ISO-8601 UTC expires_at (overrides --expires-days)")

    p.add_argument("--sign", action="store_true", help="sign too (manual fallback; CI uses sign_manifest.py)")
    p.add_argument("--key-file", help=f"private key file (default: env {KEY_ENV_VAR})")
    p.add_argument("--previous-from-manifest", help="with --sign: currently published manifest.json")
    p.add_argument("--out", help="output file")
    return p


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.generate_key:
            if not args.key_out:
                print("error: --generate-key needs --key-out PATH", file=sys.stderr)
                return 2
            signer.print_generated_key(signer.generate_key(args.key_out, args.key_id, args.public_out))
            return 0

        if not args.out:
            print("error: --out PATH is required", file=sys.stderr)
            return 2

        info = resolve_release_info(args.release_info, args.installer, args.release_version, args.build)
        payload = build_payload(
            info,
            read_release_notes(args.notes_ar),
            read_release_notes(args.notes_en),
            mandatory=args.mandatory,
            min_supported_version=args.min_supported_version,
            db_schema_revision=args.db_schema_revision,
            released_at=args.released_at,
            expires_days=args.expires_days,
            expires_at=args.expires_at,
        )
        unsigned = (
            json.dumps({UNSIGNED_MARKER: True, "signed": serialise_payload(payload)}, ensure_ascii=False, indent=2)
            + "\n"
        ).encode("utf-8")
        out = Path(args.out)

        if not args.sign:
            signer.atomic_write_bytes(out, unsigned)
            print(f"Unsigned manifest payload written to {out}")
        else:
            key = signer.load_private_key(args.key_file)
            staging = out.with_name(out.name + ".unsigned")
            signer.atomic_write_bytes(staging, unsigned)
            try:
                raw, reason = signer.sign_file(
                    str(staging), str(out), key, signer.validate_key_id(args.key_id),
                    installer=args.installer, live_manifest=args.previous_from_manifest,
                )
            finally:
                staging.unlink(missing_ok=True)
            # Same client code path as the app, with the key that just signed it.
            try:
                ManifestVerifier({args.key_id: public_key_b64(key)}).verify(raw)
            except ManifestError as exc:
                out.unlink(missing_ok=True)
                raise ReleaseToolError(f"signed manifest rejected by the client verifier: {exc}") from None
            print(f"Signed manifest written to {out} (key_id {args.key_id}, {len(raw)} bytes); {reason}")
        installer = payload["installer"]
        print(f"version {payload['version']} build {payload['build_number']}")
        print(f"installer {installer['path']} size {installer['size_bytes']} sha256 {installer['sha256']}")
        return 0
    except (ReleaseToolError, signer.SignerError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
