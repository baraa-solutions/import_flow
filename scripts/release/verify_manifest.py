"""
Verify a signed update manifest with the exact client code path (docs/plans/update-system-plan.md sections 4.3, 4.4, 9).

Signature and client rules come from modules/app_update/service.py ManifestVerifier, and the trusted keys default
to its UPDATE_SIGNING_PUBLIC_KEYS, so a manifest that passes here is one the installed app will accept.

Usage:
  # local manifest (+ optional local installer: size and sha256)
  python scripts/release/verify_manifest.py --manifest manifest.json [--installer Sorour_Logistics_Setup_v2.1.0.exe]

  # local manifest + what clients will download: HTTPS HEAD (status 200, Content-Length) and GET (sha256)
  python scripts/release/verify_manifest.py --manifest manifest.json --url https://kamal-sroor.online/importflow/updates/

  # the published manifest itself (fetched from <url>/manifest.json); --expect-manifest asserts it is byte-identical
  python scripts/release/verify_manifest.py --url https://kamal-sroor.online/importflow/updates/ \
      [--expect-manifest manifest.json] [--head-only]

  --public-key KEY_ID=BASE64 (repeatable) replaces the embedded key map (tests / key-rotation rehearsal).
The URL must pass the client allow-list (https, allowed host). Redirects are never followed; every request carries a
cache-busting query so a CDN cannot answer with a stale copy.

Exit code: 0 = verified, 1 = verification failed, 2 = bad arguments.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Sequence

PROJECT_DIR = Path(__file__).resolve().parents[2]
if str(PROJECT_DIR) not in sys.path:
    sys.path.insert(0, str(PROJECT_DIR))

import httpx  # noqa: E402

from modules.app_update.service import ManifestVerifier, VerifiedManifest  # noqa: E402
from modules.app_update.validators import (  # noqa: E402
    MANIFEST_FILENAME,
    MANIFEST_MAX_BYTES,
    ManifestError,
    build_installer_url,
    validate_base_url,
)
from utils.db_safety import sha256_file  # noqa: E402

DEFAULT_TIMEOUT_SECONDS = 60.0
_HASH_CHUNK = 1024 * 1024


class VerificationError(Exception):
    """The manifest or installer does not match what clients expect."""


def _parse_public_keys(items: Optional[List[str]]) -> Optional[Dict[str, str]]:
    if not items:
        return None
    keys: Dict[str, str] = {}
    for item in items:
        key_id, sep, value = item.partition("=")
        if not sep or not key_id or not value:
            raise ValueError("--public-key must be KEY_ID=BASE64")
        keys[key_id.strip()] = value.strip()
    return keys


def _cache_bust(url: str) -> str:
    return f"{url}{'&' if '?' in url else '?'}nocache={time.time_ns()}"


def verify_manifest_bytes(raw: bytes, public_keys: Optional[Dict[str, str]] = None) -> VerifiedManifest:
    verifier = ManifestVerifier(public_keys)
    if not verifier.has_usable_key():
        raise VerificationError(
            "no usable public key: UPDATE_SIGNING_PUBLIC_KEYS still holds the placeholder (or pass --public-key)"
        )
    try:
        return verifier.verify(raw)
    except ManifestError as exc:
        raise VerificationError(f"manifest rejected: {exc}") from None


def verify_local_installer(manifest: VerifiedManifest, installer: Path) -> None:
    if not installer.is_file():
        raise VerificationError(f"installer not found: {installer}")
    if installer.name != manifest.installer.filename:
        raise VerificationError(
            f"installer name {installer.name!r} does not match the manifest ({manifest.installer.filename!r})"
        )
    size = installer.stat().st_size
    if size != manifest.installer.size_bytes:
        raise VerificationError(f"installer size {size} != manifest {manifest.installer.size_bytes}")
    digest = sha256_file(installer)
    if digest != manifest.installer.sha256:
        raise VerificationError(f"installer sha256 {digest} != manifest {manifest.installer.sha256}")


def fetch_manifest(client: httpx.Client, base_url: str) -> bytes:
    url = _cache_bust(validate_base_url(base_url) + MANIFEST_FILENAME)
    with client.stream("GET", url, headers={"Cache-Control": "no-cache"}) as response:
        if response.status_code != 200:
            raise VerificationError(f"GET manifest returned HTTP {response.status_code}")
        body = bytearray()
        for chunk in response.iter_bytes():
            body.extend(chunk)
            if len(body) > MANIFEST_MAX_BYTES:
                raise VerificationError("published manifest exceeds the client size cap")
    return bytes(body)


def verify_remote_installer(
    client: httpx.Client, base_url: str, manifest: VerifiedManifest, head_only: bool = False
) -> None:
    url = _cache_bust(build_installer_url(base_url, manifest.installer.path))
    headers = {"Accept-Encoding": "identity", "Cache-Control": "no-cache"}
    expected_size = manifest.installer.size_bytes

    head = client.head(url, headers=headers)
    if head.status_code != 200:
        raise VerificationError(f"HEAD installer returned HTTP {head.status_code}")
    length = head.headers.get("content-length")
    if length is None or not length.isdigit() or int(length) != expected_size:
        raise VerificationError(f"HEAD Content-Length {length!r} != manifest size {expected_size}")
    if head_only:
        return

    digest = hashlib.sha256()
    received = 0
    with client.stream("GET", url, headers=headers) as response:
        if response.status_code != 200:
            raise VerificationError(f"GET installer returned HTTP {response.status_code}")
        for chunk in response.iter_bytes(_HASH_CHUNK):  # same decoding as the app's download worker
            received += len(chunk)
            if received > expected_size:
                raise VerificationError("downloaded installer is larger than the manifest size")
            digest.update(chunk)
    if received != expected_size:
        raise VerificationError(f"downloaded {received} bytes, manifest says {expected_size}")
    if digest.hexdigest() != manifest.installer.sha256:
        raise VerificationError(
            f"downloaded installer sha256 {digest.hexdigest()} != manifest {manifest.installer.sha256}"
        )


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Verify an ImportFlow update manifest like the client does.")
    p.add_argument("--manifest", help="local manifest.json (default with --url: fetch <url>/manifest.json)")
    p.add_argument("--url", help="update base URL, e.g. https://kamal-sroor.online/importflow/updates/")
    p.add_argument("--installer", help="local installer to check against the manifest (size + sha256)")
    p.add_argument("--expect-manifest", help="with --url: the fetched manifest must be byte-identical to this file")
    p.add_argument("--head-only", action="store_true", help="with --url: HEAD the installer only, no download")
    p.add_argument("--public-key", action="append", help="KEY_ID=BASE64 trusted key (replaces the embedded map)")
    p.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT_SECONDS, help="HTTP timeout in seconds")
    return p


def main(argv: Optional[Sequence[str]] = None, transport: Optional[httpx.BaseTransport] = None) -> int:
    args = _parser().parse_args(argv)
    if not args.manifest and not args.url:
        print("error: pass --manifest and/or --url", file=sys.stderr)
        return 2
    if args.expect_manifest and not args.url:
        print("error: --expect-manifest needs --url", file=sys.stderr)
        return 2
    try:
        public_keys = _parse_public_keys(args.public_key)
        base_url = validate_base_url(args.url) if args.url else None
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    client: Optional[httpx.Client] = None
    try:
        if base_url:
            client = httpx.Client(
                transport=transport,
                follow_redirects=False,
                timeout=httpx.Timeout(args.timeout),
                headers={"User-Agent": "ImportFlow-ReleaseVerifier/1"},
            )

        if args.manifest:
            path = Path(args.manifest)
            if not path.is_file():
                raise VerificationError(f"manifest not found: {path}")
            raw = path.read_bytes()
            source = str(path)
        else:
            raw = fetch_manifest(client, base_url)
            source = base_url + MANIFEST_FILENAME
            if args.expect_manifest:
                expected = Path(args.expect_manifest)
                if not expected.is_file() or expected.read_bytes() != raw:
                    raise VerificationError("published manifest differs from the expected file")

        manifest = verify_manifest_bytes(raw, public_keys)
        print(f"OK signature  {source} key_id={manifest.key_id} version={manifest.version} "
              f"build={manifest.build_number} mandatory={manifest.mandatory}")
        print(f"   installer  {manifest.installer.path} size={manifest.installer.size_bytes} "
              f"sha256={manifest.installer.sha256}")
        expires_at = manifest.expires_at
        print(f"   expires_at {expires_at.isoformat()}"
              + (f"  previous={manifest.previous.version}" if manifest.previous else ""))
        if expires_at <= datetime.now(timezone.utc):
            raise VerificationError(f"manifest expired at {expires_at.isoformat()}: clients reject it (re-sign it)")

        if args.installer:
            verify_local_installer(manifest, Path(args.installer))
            print(f"OK installer  {args.installer} matches size and sha256")

        if base_url:
            verify_remote_installer(client, base_url, manifest, head_only=args.head_only)
            what = "HEAD 200 + Content-Length" if args.head_only else "HEAD + download sha256"
            print(f"OK public     {base_url}{manifest.installer.path} ({what})")
        return 0
    except VerificationError as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    except httpx.HTTPError as exc:
        print(f"FAIL HTTP error: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    finally:
        if client is not None:
            client.close()


if __name__ == "__main__":
    sys.exit(main())
