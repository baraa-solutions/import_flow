"""
Release bundle guard (plan docs/plans/update-system-plan.md, section 0, rules R1 and R4).

Fails the release when anything that holds or controls production data would ship to the laptop:
  - SQLite databases and their side files: *.db, *.db-wal, *.db-shm, *.db-journal, *.sqlite*
  - secrets: .env, .env.*, *.key, *.pem, *.pfx, *.p12
  - data folders: backups/, updates/
  - destructive maintenance scripts (audit A4 / A13) that can wipe or overwrite the DB

Three inputs, any combination:
  --dir PATH   scan a staged folder recursively (e.g. dist/Sorour_Logistics_Standalone)
  --zip PATH   scan the member names of an archive (e.g. the portable zip)
  --iss PATH   statically check an Inno Setup script:
                 - no [Files] source/destination names data or secrets; wildcard sources exclude them
                 - [UninstallDelete] must not touch data; [InstallDelete] may ONLY remove the legacy
                   destructive scripts by exact name ({app}\\reset_clean_production_db.py, ...)
                 - [Code] may only delete/rename under {tmp} (DeleteFile/DelTree/RemoveDir/RenameFile/
                   DelayDeleteFile), may only write (CopyFile/FileCopy/RenameFile/SaveString(s)ToFile)
                   under {tmp} or {app}\\backups\\pre_install_*, and must not Exec/ShellExec a command that
                   deletes, moves or overwrites files (del, rd, move, copy, robocopy, sqlite3, ...)
                 - R2m (migration from an old install folder) only: CopyFile(..., True) into
                   {app}\\backups\\pre_migrate_*, and RenameFile between a pre_migrate_ staging file and the
                   same-named live DB file in {app} (MoveFile never overwrites) - nothing else
                 - [Run]/[UninstallRun] must not run a delete command or a destructive script

Usage:
  python scripts/release/bundle_guard.py --iss installer/importflow_setup.iss \
      --dir dist/Sorour_Logistics_Standalone --zip dist/releases/Sorour_Logistics_v2.0.3_Windows_Portable.zip

Exit code: 0 = clean, 1 = forbidden content found, 2 = bad arguments / missing input.
Read-only: never modifies, moves or deletes anything it scans.
"""
from __future__ import annotations

import argparse
import fnmatch
import re
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath, PureWindowsPath
from typing import Iterable, List, Optional, Sequence

# Lower-case fnmatch patterns matched against a single path component (file or folder name).
FORBIDDEN_FILE_PATTERNS: dict[str, str] = {
    "*.db": "SQLite database",
    "*.db-wal": "SQLite write-ahead log",
    "*.db-shm": "SQLite shared-memory index",
    "*.db-journal": "SQLite rollback journal",
    "*.sqlite*": "SQLite database or side file",
    ".env": "environment secrets file",
    ".env.*": "environment file",
    "*.key": "private key",
    "*.pem": "certificate / private key",
    "*.pfx": "certificate bundle",
    "*.p12": "certificate bundle",
}

FORBIDDEN_DIR_NAMES: dict[str, str] = {
    "backups": "database backups folder",
    "updates": "downloaded updates folder",
}

# Audit A4 (shipped by package_production.py) and A13 (repo-root scripts that wipe tables).
DESTRUCTIVE_SCRIPTS: frozenset[str] = frozenset(
    {
        "reset_clean_production_db.py",
        "clean_and_isolate_databases.py",
        "sync_to_production.py",
        "execute_user_database_updates.py",
        "populate_all_world_transport_locations.py",
        "clean_transport_locations.py",
        "update_db_schema.py",
        "restore_database.py",
        "prepare_uat_environment.py",
        "seed.py",  # dev seeder with fixed demo passwords
    }
)

# Scripts that installers before Phase 0b copied into {app}: the new installer removes exactly these
# ([InstallDelete] Type: files, exact name). Nothing else may be deleted by the installer.
LEGACY_SCRIPTS_TO_REMOVE: frozenset[str] = frozenset(
    {"reset_clean_production_db.py", "clean_and_isolate_databases.py", "sync_to_production.py", "seed.py"}
)
ALLOWED_INSTALL_DELETE_NAMES: frozenset[str] = frozenset("{app}\\" + name for name in LEGACY_SCRIPTS_TO_REMOVE)

# Pascal support functions that delete or move files/folders.
CODE_DELETE_FUNCTIONS: tuple[str, ...] = ("DelTree", "DeleteFile", "DelayDeleteFile", "RemoveDir", "RenameFile")
# Pascal support functions that WRITE a file, with the index of their destination argument.
CODE_WRITE_FUNCTIONS: dict[str, int] = {
    "CopyFile": 1,
    "FileCopy": 1,
    "RenameFile": 1,
    "SaveStringToFile": 0,
    "SaveStringsToFile": 0,
    "SaveStringsToUTF8File": 0,
    "SaveStringToUTF8File": 0,
}
CODE_EXEC_FUNCTIONS: tuple[str, ...] = ("Exec", "ExecAsOriginalUser", "ShellExec", "ShellExecAsOriginalUser")
# Deleting sources may only live under {tmp}; written destinations under {tmp} or a fresh pre-install
# backup folder. Arguments must START with one of these literal expressions (whitespace/case ignored).
DELETE_ALLOWED_PREFIXES: tuple[str, ...] = ("expandconstant('{tmp}\\",)
WRITE_ALLOWED_PREFIXES: tuple[str, ...] = ("expandconstant('{tmp}\\", "expandconstant('{app}\\backups\\pre_install_')")
# R2m migration from an old install folder (installer PrepareToInstall): a fresh
# {app}\backups\pre_migrate_<tag>_<ts>\ folder receives verified READ-ONLY copies of the old database.
# CopyFile/FileCopy may write there only with FailIfExists=True (never overwrite).
MIGRATION_PREFIX = "expandconstant('{app}\\backups\\pre_migrate_')"
# The live database files in {app}. The ONLY operation allowed on them is a RenameFile (MoveFile: atomic,
# fails when the target exists, so it never overwrites) between the same-named file in a pre_migrate_
# staging folder and {app} - in either direction (place the migrated copy / move it back on failure).
LIVE_DB_NAMES: tuple[str, ...] = ("sorour_logistics.db", "sorour_logistics.db-wal", "sorour_logistics.db-shm")
# Shell commands that delete, move, rename, overwrite or rewrite files, as a separate word.
DELETE_COMMAND_RE = re.compile(
    r"(?<![\w.-])(del|erase|rd|rmdir|remove-item|rm|ri|deltree"
    r"|move|ren|rename|copy|xcopy|robocopy|mv|cp|move-item|copy-item|rename-item|set-content|out-file"
    r"|sqlite3(?:\.exe)?)(?![\w.-])",
    re.I,
)

# Representative data names in {app}: an [InstallDelete]/[UninstallDelete] glob that matches any of
# them (or a folder above them) would delete production data.
PROTECTED_DATA_SAMPLES: tuple[str, ...] = (
    "sorour_logistics.db",
    "sorour_logistics.db-wal",
    "sorour_logistics.db-shm",
    "sorour_logistics.db-journal",
    "sorour_logistics_backup_20260101_000000.db",
    "data.sqlite",
    ".env",
    "backups",
    "updates",
)

# File names a wildcard [Files] source must list in its Excludes.
PROTECTED_FILE_SAMPLES: tuple[str, ...] = (
    "sorour_logistics.db",
    "sorour_logistics.db-wal",
    "sorour_logistics.db-shm",
    "sorour_logistics.db-journal",
    "data.sqlite",
    ".env",
    ".env.production",
    "server.key",
    "server.pem",
    *sorted(DESTRUCTIVE_SCRIPTS),
)


@dataclass(frozen=True)
class Violation:
    location: str
    reason: str

    def __str__(self) -> str:
        return f"{self.location}: {self.reason}"


def classify_name(name: str, is_dir: bool = False) -> Optional[str]:
    """Return why a single path component is forbidden, or None when it may ship."""
    lowered = name.strip().lower()
    if not lowered:
        return None
    if is_dir:
        reason = FORBIDDEN_DIR_NAMES.get(lowered)
        return f"{reason} must never ship" if reason else None
    if lowered in DESTRUCTIVE_SCRIPTS:
        return "destructive maintenance script (can wipe or overwrite the production DB) must never ship"
    for pattern, label in FORBIDDEN_FILE_PATTERNS.items():
        if fnmatch.fnmatchcase(lowered, pattern):
            return f"{label} ({pattern}) must never ship"
    return None


def classify_relative_path(parts: Sequence[str], is_dir: bool) -> Optional[str]:
    """Check every component: folders by folder rules, the last one by file rules when it is a file."""
    for index, part in enumerate(parts):
        last = index == len(parts) - 1
        reason = classify_name(part, is_dir=(is_dir or not last))
        if reason:
            return reason
    return None


def scan_directory(root: Path) -> List[Violation]:
    root = Path(root)
    violations: List[Violation] = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        reason = classify_relative_path(relative.parts, path.is_dir())
        if reason:
            violations.append(Violation(f"{root.name}/{relative.as_posix()}", reason))
    return _drop_nested(violations)


def scan_zip(archive: Path) -> List[Violation]:
    violations: List[Violation] = []
    with zipfile.ZipFile(archive) as zf:
        for member in zf.namelist():
            is_dir = member.endswith("/")
            parts = [p for p in PurePosixPath(member.replace("\\", "/")).parts if p not in ("", "/")]
            reason = classify_relative_path(parts, is_dir)
            if reason:
                violations.append(Violation(f"{Path(archive).name}!{member}", reason))
    return _drop_nested(violations)


def _drop_nested(violations: List[Violation]) -> List[Violation]:
    """Report a forbidden folder once instead of once per file inside it."""
    kept: List[Violation] = []
    for violation in violations:
        if any(violation.location.startswith(k.location.rstrip("/") + "/") for k in kept):
            continue
        kept.append(violation)
    return kept


# ---------------------------------------------------------------------------------------------------
# Inno Setup script checks
# ---------------------------------------------------------------------------------------------------
_SECTION_RE = re.compile(r"^\s*\[([A-Za-z]+)\]\s*$")
_PARAM_RE = re.compile(r'(\w+)\s*:\s*("(?:[^"]|"")*"|[^;]*)')


def parse_iss_sections(text: str) -> dict[str, List[str]]:
    """Map lower-case section name -> non-comment lines. [Code] is kept verbatim (comments included)."""
    sections: dict[str, List[str]] = {}
    current: Optional[str] = None
    for raw in text.lstrip("\ufeff").splitlines():
        match = _SECTION_RE.match(raw)
        if match and (current != "code" or match.group(1).lower() != "code"):
            current = match.group(1).lower()
            sections.setdefault(current, [])
            continue
        if current is None:
            continue
        if current != "code":
            stripped = raw.strip()
            if not stripped or stripped.startswith(";") or stripped.startswith("#"):
                continue
        sections[current].append(raw)
    return sections


def parse_iss_entry(line: str) -> dict[str, str]:
    """Parse `Name: "value"; Other: value` into a lower-case-keyed dict (quotes removed)."""
    entry: dict[str, str] = {}
    for key, value in _PARAM_RE.findall(line):
        value = value.strip()
        if len(value) >= 2 and value.startswith('"') and value.endswith('"'):
            value = value[1:-1].replace('""', '"')
        entry[key.lower()] = value
    return entry


def _last_component(inno_path: str) -> str:
    return PureWindowsPath(inno_path.replace("/", "\\")).name


def check_iss_text(text: str, label: str = "installer") -> List[Violation]:
    violations: List[Violation] = []
    sections = parse_iss_sections(text)

    for line in sections.get("files", []):
        entry = parse_iss_entry(line)
        for key in ("source", "destname"):
            value = entry.get(key, "")
            if not value:
                continue
            name = _last_component(value)
            reason = classify_name(name)
            if reason is None:
                # a folder in the middle of the path (e.g. ...\backups\*) is just as bad
                components = PureWindowsPath(value.replace("/", "\\")).parts[:-1]
                for component in components:
                    reason = classify_name(component, is_dir=True)
                    if reason:
                        break
            if reason:
                violations.append(Violation(f"{label} [Files] {key}={value}", reason))

        # A wildcard source (e.g. Standalone\*) must exclude every data / secret file name explicitly,
        # so a stray DB in the staging folder can never reach the installer.
        source_name = _last_component(entry.get("source", "")).lower()
        if any(ch in source_name for ch in "*?"):
            excludes = [x.strip().lower() for x in entry.get("excludes", "").split(",") if x.strip()]
            uncovered = [
                sample
                for sample in PROTECTED_FILE_SAMPLES
                if fnmatch.fnmatchcase(sample, source_name) and not any(fnmatch.fnmatchcase(sample, ex) for ex in excludes)
            ]
            if uncovered:
                violations.append(
                    Violation(
                        f"{label} [Files] source={entry.get('source')}",
                        "wildcard source does not exclude " + ", ".join(uncovered) + " (add them to Excludes)",
                    )
                )

    for section in ("installdelete", "uninstalldelete"):
        for line in sections.get(section, []):
            entry = parse_iss_entry(line)
            target = entry.get("name", "")
            if (
                section == "installdelete"
                and entry.get("type", "").lower() == "files"
                and target.strip().lower().replace("/", "\\") in ALLOWED_INSTALL_DELETE_NAMES
            ):
                continue  # removes a legacy destructive script left in {app} by old installers
            name = _last_component(target).lower()
            path_lower = target.lower().replace("/", "\\")
            touches_data = (
                any(fnmatch.fnmatchcase(sample, name) for sample in PROTECTED_DATA_SAMPLES)
                or classify_name(name) is not None
                or "\\backups" in path_lower
                or "\\updates" in path_lower
                or path_lower.rstrip("\\") in ("{app}", "{userappdata}", "{localappdata}")
            )
            # Every other delete entry fails: data ones with the data message, the rest because the
            # allow-list is exact (security review: installers delete nothing but the legacy scripts).
            violations.append(
                Violation(
                    f"{label} [{'InstallDelete' if section == 'installdelete' else 'UninstallDelete'}] Name={target}",
                    "deletes (or may delete) production data: databases, .env, backups\\ or updates\\"
                    if touches_data
                    else "not allowed: [InstallDelete] may only remove "
                    + ", ".join(sorted(ALLOWED_INSTALL_DELETE_NAMES))
                    + " (Type: files) and [UninstallDelete] must stay empty",
                )
            )

    for section, title in (("run", "Run"), ("uninstallrun", "UninstallRun")):
        for line in sections.get(section, []):
            entry = parse_iss_entry(line)
            filename = entry.get("filename", "")
            command = f"{filename} {entry.get('parameters', '')}"
            script_reason = classify_name(_last_component(filename))
            if DELETE_COMMAND_RE.search(command) or script_reason:
                violations.append(
                    Violation(
                        f"{label} [{title}] Filename={filename} Parameters={entry.get('parameters', '')}",
                        script_reason or "runs a delete command; the installer must never delete files outside {tmp}",
                    )
                )

    violations.extend(check_iss_code("\n".join(sections.get("code", [])), label))
    return violations


def strip_pascal_comments(code: str) -> str:
    """Remove { }, (* *) and // comments while keeping 'string literals' (which may contain braces)."""
    out: List[str] = []
    i, n = 0, len(code)
    while i < n:
        ch = code[i]
        if ch == "'":
            end = i + 1
            while end < n:
                if code[end] == "'":
                    if end + 1 < n and code[end + 1] == "'":
                        end += 2
                        continue
                    break
                end += 1
            out.append(code[i:end + 1])
            i = end + 1
        elif ch == "{":
            close = code.find("}", i + 1)
            i = n if close < 0 else close + 1
            out.append(" ")
        elif code.startswith("(*", i):
            close = code.find("*)", i + 2)
            i = n if close < 0 else close + 2
            out.append(" ")
        elif code.startswith("//", i):
            close = code.find("\n", i)
            i = n if close < 0 else close
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def _call_arguments(code: str, function: str) -> List[str]:
    """Argument text of every call to `function` (balanced parentheses, string-aware)."""
    results: List[str] = []
    # search in a copy whose 'string literals' are blanked, so text like Log('... DeleteFile(x) ...')
    # is not mistaken for a call; offsets stay identical to `code`
    masked = re.sub(r"'(?:[^']|'')*'", lambda m: "'" + " " * (len(m.group(0)) - 2) + "'", code)
    for match in re.finditer(rf"(?<![\w.]){function}\s*\(", masked, re.I):
        depth, i, in_string = 1, match.end(), False
        while i < len(code) and depth:
            ch = code[i]
            if ch == "'":
                in_string = not in_string
            elif not in_string and ch == "(":
                depth += 1
            elif not in_string and ch == ")":
                depth -= 1
            i += 1
        results.append(code[match.end():i - 1])
    return results


def _split_arguments(args: str) -> List[str]:
    """Split call arguments at top-level commas (string- and parenthesis-aware)."""
    parts: List[str] = []
    depth, in_string, start = 0, False, 0
    for i, ch in enumerate(args):
        if ch == "'":
            in_string = not in_string
        elif not in_string and ch == "(":
            depth += 1
        elif not in_string and ch == ")":
            depth -= 1
        elif not in_string and depth == 0 and ch == ",":
            parts.append(args[start:i])
            start = i + 1
    parts.append(args[start:])
    return [p.strip() for p in parts]


def _path_allowed(expression: str, prefixes: Sequence[str]) -> bool:
    normalized = re.sub(r"\s+", "", expression).lower()
    if ".." in normalized:  # no climbing out of {tmp} or the backup folder
        return False
    return any(normalized.startswith(prefix) for prefix in prefixes)


def _normalize_expression(expression: str) -> str:
    return re.sub(r"\s+", "", expression).lower()


def _is_migration_copy(function: str, parts: Sequence[str]) -> bool:
    """CopyFile/FileCopy(Src, ExpandConstant('{app}\\backups\\pre_migrate_') + ..., True)."""
    if function not in ("CopyFile", "FileCopy") or len(parts) != 3:
        return False
    return _path_allowed(parts[1], (MIGRATION_PREFIX,)) and _normalize_expression(parts[2]) == "true"


def _live_db_expression(name: str) -> str:
    return f"expandconstant('{{app}}\\{name}')"


def _staged_db_expression(name: str) -> str:
    """The one accepted spelling (whitespace/case ignored) of a staging file: no other variable, no '..'."""
    return f"{MIGRATION_PREFIX}+stamp+'\\staging\\{name}'"


def _is_migration_move(args: str) -> bool:
    """RenameFile between {app}\\<live db file> and the SAME file name in a pre_migrate_ staging folder:
    ExpandConstant('{app}\\backups\\pre_migrate_') + Stamp + '\\staging\\sorour_logistics.db' <-> ExpandConstant('{app}\\sorour_logistics.db')."""
    parts = _split_arguments(args)
    if len(parts) != 2:
        return False
    source, destination = (_normalize_expression(p) for p in parts)
    return any(
        (source, destination) in ((_staged_db_expression(name), _live_db_expression(name)),
                                  (_live_db_expression(name), _staged_db_expression(name)))
        for name in LIVE_DB_NAMES
    )


def check_iss_code(code: str, label: str = "installer") -> List[Violation]:
    """[Code] may delete/move only under {tmp}, write only under {tmp} or {app}\\backups\\pre_install_*,
    and may never shell out to a delete / move / copy / sqlite3 command.
    R2m exception (database migration from an old install folder): CopyFile(..., True) into
    {app}\\backups\\pre_migrate_*, and RenameFile between a pre_migrate_ staging file and the same-named
    live database file in {app} (MoveFile never overwrites)."""
    violations: List[Violation] = []
    code = strip_pascal_comments(code)
    for function in CODE_DELETE_FUNCTIONS:
        for args in _call_arguments(code, function):
            if function == "RenameFile" and _is_migration_move(args):
                continue
            if not _path_allowed(_split_arguments(args)[0], DELETE_ALLOWED_PREFIXES):
                violations.append(
                    Violation(
                        f"{label} [Code] {function}({args.strip()})",
                        "deletes or moves files outside {tmp}; the installer must never delete or move data "
                        "(only ExpandConstant('{tmp}\\...') arguments are allowed)",
                    )
                )
    for function, index in CODE_WRITE_FUNCTIONS.items():
        for args in _call_arguments(code, function):
            parts = _split_arguments(args)
            if (function == "RenameFile" and _is_migration_move(args)) or _is_migration_copy(function, parts):
                continue
            destination = parts[index] if index < len(parts) else ""
            if not _path_allowed(destination, WRITE_ALLOWED_PREFIXES):
                violations.append(
                    Violation(
                        f"{label} [Code] {function}({args.strip()})",
                        "writes a file outside {tmp} and {app}\\backups\\pre_install_*; the destination must start "
                        "with ExpandConstant('{tmp}\\...') or ExpandConstant('{app}\\backups\\pre_install_') "
                        "so it can never overwrite data",
                    )
                )
    for function in CODE_EXEC_FUNCTIONS:
        for args in _call_arguments(code, function):
            if DELETE_COMMAND_RE.search(args):
                violations.append(
                    Violation(
                        f"{label} [Code] {function}({args.strip()})",
                        "runs a command that deletes, moves or overwrites files (del/rd/move/copy/robocopy/sqlite3/...); "
                        "the installer must never touch data from a shell",
                    )
                )
    return violations


def check_iss_file(path: Path) -> List[Violation]:
    return check_iss_text(Path(path).read_text(encoding="utf-8-sig"), label=Path(path).name)


# ---------------------------------------------------------------------------------------------------
def run(dirs: Iterable[Path] = (), zips: Iterable[Path] = (), iss_files: Iterable[Path] = ()) -> List[Violation]:
    violations: List[Violation] = []
    for iss in iss_files:
        violations.extend(check_iss_file(Path(iss)))
    for directory in dirs:
        violations.extend(scan_directory(Path(directory)))
    for archive in zips:
        violations.extend(scan_zip(Path(archive)))
    return violations


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Fail when a release bundle would ship data, secrets or destructive scripts.")
    parser.add_argument("--dir", dest="dirs", action="append", default=[], type=Path, help="staged folder to scan")
    parser.add_argument("--zip", dest="zips", action="append", default=[], type=Path, help="archive to scan")
    parser.add_argument("--iss", dest="iss_files", action="append", default=[], type=Path, help="Inno Setup script")
    args = parser.parse_args(argv)

    if not (args.dirs or args.zips or args.iss_files):
        parser.print_usage(sys.stderr)
        print("bundle_guard: nothing to check (pass --dir, --zip and/or --iss)", file=sys.stderr)
        return 2
    missing = [
        str(p)
        for p in [*args.dirs, *args.zips, *args.iss_files]
        if not p.exists() or (p in args.dirs and not p.is_dir())
    ]
    if missing:
        print("bundle_guard: input not found: " + ", ".join(missing), file=sys.stderr)
        return 2

    violations = run(args.dirs, args.zips, args.iss_files)
    checked = ", ".join(str(p) for p in [*args.iss_files, *args.dirs, *args.zips])
    if violations:
        print(f"bundle_guard: FAIL - {len(violations)} forbidden item(s) in {checked}")
        for violation in violations:
            print(f"  - {violation}")
        print("Release blocked: production data, secrets and destructive scripts must never ship (plan section 0, R1/R4).")
        return 1
    print(f"bundle_guard: PASS - no databases, secrets, data folders or destructive scripts in {checked}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
