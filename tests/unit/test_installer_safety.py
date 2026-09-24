"""
Installer safety invariants for installer/importflow_setup.iss (plan docs/plans/update-system-plan.md, section 0).

R1  no [Files] entry ships a database / .env, the wildcard entry excludes them, there is no
    [UninstallDelete], and [InstallDelete] only removes the 3 legacy destructive scripts by exact name.
    One install mode only (no PrivilegesRequiredOverridesAllowed); PrepareToInstall aborts when the DB
    lives in another install folder but not in the chosen {app}.
R2  PrepareToInstall stops frontend.exe/backend.exe, copies .db + -wal + -shm into
    {app}\\backups\\pre_install_<version>_<timestamp>\\, verifies the copies and aborts on any failure.
R3  uninstall keeps the data: data folders carry uninsneveruninstall, the DB is never a Setup file.
C11 a silent install relaunches the app only with /RELAUNCH=1; the interactive checkbox is unchanged.
K2  StopRunningApp kills by image name without /T (Setup is a child of backend.exe during an in-app update).

These are static checks on the script text; ISCC compiles it in CI (build_and_release.yml).
"""
import re
from pathlib import Path

import pytest

PROJECT_DIR = Path(__file__).resolve().parents[2]
ISS_PATH = PROJECT_DIR / "installer" / "importflow_setup.iss"
RAW_BYTES = ISS_PATH.read_bytes()
ISS_TEXT = RAW_BYTES.decode("utf-8-sig")

SECTION_RE = re.compile(r"^\[([A-Za-z]+)\]\s*$", re.M)
DATA_NAME_RE = re.compile(r"(\.db\b|\.db-wal|\.db-shm|\.sqlite|(^|[\\/\"])\.env\b|\\backups\b|\\updates\b)", re.I)


def _sections() -> dict:
    """Section name (lower) -> body text; [Code] keeps everything up to the end of the file."""
    matches = list(SECTION_RE.finditer(ISS_TEXT))
    result = {}
    for index, match in enumerate(matches):
        name = match.group(1).lower()
        end = len(ISS_TEXT) if name == "code" else (matches[index + 1].start() if index + 1 < len(matches) else len(ISS_TEXT))
        result[name] = ISS_TEXT[match.end():end]
        if name == "code":
            break
    return result


SECTIONS = _sections()
CODE = SECTIONS["code"]


def _entries(section: str) -> list:
    body = SECTIONS.get(section, "")
    return [line.strip() for line in body.splitlines() if line.strip() and not line.strip().startswith(";")]


def _param(entry: str, key: str) -> str:
    match = re.search(rf'\b{key}\s*:\s*("(?:[^"]|"")*"|[^;]*)', entry, re.I)
    return match.group(1).strip().strip('"') if match else ""


def _pascal_routine(name: str) -> str:
    """Body of a top-level function/procedure in [Code], up to its closing `end;` at column 0."""
    match = re.search(rf"^(function|procedure)\s+{name}\b.*?^end;", CODE, re.S | re.M)
    assert match, f"[Code] has no routine {name}"
    return match.group(0)


# ------------------------------------------------------------------------------------------------
# R1
# ------------------------------------------------------------------------------------------------
def test_no_files_entry_ships_a_database_or_env():
    entries = _entries("files")
    assert entries, "[Files] section is empty"
    for entry in entries:
        for key in ("Source", "DestName"):
            value = _param(entry, key)
            assert not DATA_NAME_RE.search(value), f"[Files] {key} ships data or secrets: {entry}"


def test_old_database_files_line_is_gone():
    assert "sorour_logistics.db\"; DestDir" not in ISS_TEXT
    assert not re.search(r"^Source:.*sorour_logistics\.db", ISS_TEXT, re.M | re.I)


@pytest.mark.parametrize(
    "pattern",
    ["*.db", "*.db-wal", "*.db-shm", "*.sqlite*", ".env", ".env.*", "*.key", "*.pem",
     "backups\\*", "updates\\*",
     "reset_clean_production_db.py", "clean_and_isolate_databases.py", "sync_to_production.py",
     "restore_database.py", "prepare_uat_environment.py", "seed.py"],
)
def test_wildcard_files_entry_excludes_data_and_destructive_scripts(pattern):
    wildcard_entries = [e for e in _entries("files") if _param(e, "Source").endswith("*")]
    assert wildcard_entries, "expected the Standalone\\* entry"
    for entry in wildcard_entries:
        excludes = [x.strip().lower() for x in _param(entry, "Excludes").split(",")]
        assert pattern.lower() in excludes, f"Excludes misses {pattern}: {entry}"


def test_no_uninstall_delete_section():
    assert "uninstalldelete" not in SECTIONS


def test_install_delete_removes_only_the_legacy_destructive_scripts():
    entries = _entries("installdelete")
    targets = sorted(_param(e, "Name") for e in entries)

    assert targets == [
        "{app}\\clean_and_isolate_databases.py",
        "{app}\\reset_clean_production_db.py",
        "{app}\\seed.py",
        "{app}\\sync_to_production.py",
    ]
    assert all(_param(e, "Type").lower() == "files" for e in entries)


def test_code_deletes_only_its_tmp_scratch_file():
    for match in re.finditer(r"\b(DeleteFile|DelTree|DelayDeleteFile|RemoveDir|RenameFile)\s*\(", CODE):
        line = CODE[match.start():CODE.find("\n", match.start())]
        if line.lstrip().startswith("//"):
            continue
        assert line.startswith("DeleteFile(ExpandConstant('{tmp}\\process_check_"), line


def test_no_brace_comment_contains_a_constant():
    """`{ ... {app} ... }` ends at the first `}` in Pascal and breaks the compile."""
    in_string = False
    i = 0
    while i < len(CODE):
        ch = CODE[i]
        if ch == "'":
            in_string = not in_string
        elif not in_string and ch == "{":
            close = CODE.index("}", i)
            assert "{" not in CODE[i + 1:close], CODE[i:close + 1]
            i = close
        elif not in_string and CODE.startswith("//", i):
            i = CODE.index("\n", i)
            continue
        i += 1


# ------------------------------------------------------------------------------------------------
# Install mode (security review #1)
# ------------------------------------------------------------------------------------------------
def test_install_mode_cannot_be_switched():
    setup = SECTIONS["setup"]
    assert re.search(r"^PrivilegesRequired=lowest\s*$", setup, re.M)
    assert not re.search(r"^\s*PrivilegesRequiredOverridesAllowed", setup, re.M | re.I)


def test_prepare_to_install_aborts_when_db_lives_in_another_install_folder():
    body = _pascal_routine("PrepareToInstall")
    missing = re.search(r"if not FileExists\(DbFile\) then\s*begin(.*?)\n  end;", body, re.S)
    assert missing, "no branch for a missing DB in {app}"
    block = missing.group(1)
    assert "OtherDir := FindDatabaseOutsideApp(AppDir);" in block
    assert re.search(r"if OtherDir <> '' then\s*begin\s*Result := WrongFolderAbortMessage\(OtherDir, AppDir\);\s*Exit;", block)


def test_other_install_folders_are_all_searched():
    body = _pascal_routine("FindDatabaseOutsideApp")
    for location in ("RegisteredAppPath(HKCU)", "RegisteredAppPath(HKLM32)", "RegisteredAppPath(HKLM64)",
                     "{userpf}\\{#MyAppName}", "{commonpf32}\\{#MyAppName}", "{commonpf64}\\{#MyAppName}"):
        assert location in body, location
    assert "IsWin64" in body  # 64-bit constants/views only on 64-bit Windows

    other = _pascal_routine("DatabaseFolderIfOther")
    assert "NormalizeDir(Dir) = NormalizeDir(AppDir)" in other  # the chosen {app} itself is not "another" folder


def test_wrong_folder_message_is_arabic_and_english():
    body = _pascal_routine("WrongFolderAbortMessage")
    assert re.search(r"[\u0600-\u06FF]", body)
    assert "found in a different installation folder" in body
    assert "Existing data: " in body and "Selected folder: " in body


# ------------------------------------------------------------------------------------------------
# R2
# ------------------------------------------------------------------------------------------------
def test_prepare_to_install_backs_up_db_wal_and_shm_after_stopping_the_app():
    body = _pascal_routine("PrepareToInstall")

    stop = body.index("StopRunningApp")
    wait = body.index("WaitForAppExit")
    first_copy = body.index("BackupOneFile(")
    assert stop < wait < first_copy, "processes must be stopped and gone before the copy"

    assert "BackupOneFile(DbFile, BackupStamp, True" in body  # the DB itself is required
    assert "BackupOneFile(DbFile + '-wal', BackupStamp, False" in body
    assert "BackupOneFile(DbFile + '-shm', BackupStamp, False" in body
    assert "{app}\\backups\\pre_install_" in body
    assert "GetInstalledVersion" in body
    assert "GetDateTimeString('yyyymmdd_hhnnss'" in body


def test_prepare_to_install_aborts_on_every_failure():
    body = _pascal_routine("PrepareToInstall")
    guarded = re.findall(r"if not (\w+)\((?:[^()]|\([^()]*\))*\)\s*then\s*begin(.*?)end;", body, re.S)
    guarded += re.findall(r"if not (WaitForAppExit)\s*then\s*begin(.*?)end;", body, re.S)
    by_call = {}
    for call, block in guarded:
        by_call.setdefault(call, []).append(block)

    assert len(by_call.get("BackupOneFile", [])) == 3
    for call in ("BackupOneFile", "ForceDirectories", "WaitForAppExit"):
        assert call in by_call, f"PrepareToInstall does not check {call}"
        for block in by_call[call]:
            assert "Result := BackupAbortMessage(" in block, f"{call} failure does not abort Setup"
            assert "Exit;" in block


def test_fresh_install_without_database_proceeds():
    body = _pascal_routine("PrepareToInstall")
    fresh = re.search(r"if not FileExists\(DbFile\) then\s*begin(.*?)\n  end;", body, re.S)
    assert fresh
    tail = fresh.group(1).split("end;")[-1]  # after the other-folder check
    assert "Log('No existing database" in tail and tail.strip().endswith("Exit;")
    assert body.index("Result := '';") < fresh.start()


def test_backup_copy_is_verified_by_existence_and_size():
    body = _pascal_routine("BackupOneFile")
    # destination written literally under {app}\\backups\\pre_install_ (bundle_guard proves it statically);
    # FailIfExists=True: never overwrite an older backup
    assert ("if not CopyFile(SourceFile, ExpandConstant('{app}\\backups\\pre_install_') + BackupStamp + '\\' + "
            "ExtractFileName(SourceFile), True) then") in body
    assert "GetFileSizeParts(Target" in body
    assert "(DstHigh <> SrcHigh) or (DstLow <> SrcLow)" in body
    # a missing optional file is fine, a missing required file is not
    assert re.search(r"if Required then\s*ErrorText := .*?else\s*Result := True;", body, re.S)


def test_every_file_copy_result_is_checked():
    assert "FileCopy(" not in CODE, "FileCopy is deprecated in Inno Setup 6.x: use CopyFile"
    for match in re.finditer(r"CopyFile\(", CODE):
        line_start = CODE.rfind("\n", 0, match.start()) + 1
        assert CODE[line_start:match.start()].strip().endswith("if not"), CODE[line_start:match.end() + 40]


def test_app_processes_are_killed_and_waited_for():
    stop = _pascal_routine("StopRunningApp")
    assert "taskkill.exe'), '/F /IM frontend.exe" in stop
    assert "taskkill.exe'), '/F /IM backend.exe" in stop

    wait = _pascal_routine("WaitForAppExit")
    assert "IsProcessRunning('frontend.exe')" in wait and "IsProcessRunning('backend.exe')" in wait
    assert "Sleep(" in wait

    running = _pascal_routine("IsProcessRunning")
    assert re.search(r"begin\s*Result := True;", running), "an unknown process state must count as running"


def test_stop_running_app_never_kills_the_process_tree():
    """K2: during an in-app update Setup is a child of backend.exe; a tree kill (/T) would kill Setup itself."""
    stop = _pascal_routine("StopRunningApp")
    assert "taskkill" in stop
    assert not re.search(r"/T\b", stop, re.IGNORECASE), stop
    assert "'/F /IM frontend.exe'" in stop and "'/F /IM backend.exe'" in stop
    assert not re.search(r"taskkill[^\r\n]*/T\b", ISS_TEXT, re.IGNORECASE), "no taskkill anywhere may use /T"


def test_abort_message_is_arabic_and_english():
    body = _pascal_routine("BackupAbortMessage")
    assert re.search(r"[؀-ۿ]", body), "no Arabic text in the abort message"
    assert "could not be backed up before installation" in body
    assert "Details: " in body and "Database: " in body


def test_old_silent_backup_is_removed():
    assert "CurStepChanged" not in CODE
    assert "sorour_logistics_backup_" not in CODE


def test_uninstall_key_matches_app_id():
    app_id = re.search(r"^AppId=\{\{([0-9A-F-]+)\}", ISS_TEXT, re.M | re.I).group(1)
    assert f"Uninstall\\{{{app_id}}}_is1" in CODE


# ------------------------------------------------------------------------------------------------
# R3
# ------------------------------------------------------------------------------------------------
def test_data_folders_are_never_uninstalled():
    dirs = {_param(e, "Name").lower(): _param(e, "Flags").lower() for e in _entries("dirs")}
    for folder in ("{app}\\backups", "{app}\\updates"):
        assert folder in dirs, f"[Dirs] misses {folder}"
        assert "uninsneveruninstall" in dirs[folder]


# ------------------------------------------------------------------------------------------------
# C11 relaunch
# ------------------------------------------------------------------------------------------------
def test_interactive_launch_checkbox_is_unchanged():
    interactive = [e for e in _entries("run") if "postinstall" in _param(e, "Flags")]
    assert len(interactive) == 1
    assert "skipifsilent" in _param(interactive[0], "Flags")


def test_silent_install_relaunches_only_with_relaunch_param():
    silent = [e for e in _entries("run") if "ShouldRelaunchAfterSilentInstall" in _param(e, "Check")]
    assert len(silent) == 1
    flags = _param(silent[0], "Flags")
    assert "postinstall" not in flags and "skipifsilent" not in flags
    assert "{#MyAppExeName}" in _param(silent[0], "Filename")

    check = _pascal_routine("ShouldRelaunchAfterSilentInstall")
    assert "WizardSilent and (ExpandConstant('{param:RELAUNCH|0}') = '1')" in check


# ------------------------------------------------------------------------------------------------
# File format contracts
# ------------------------------------------------------------------------------------------------
def test_script_is_utf8_with_bom_for_the_arabic_strings():
    assert RAW_BYTES.startswith(b"\xef\xbb\xbf")


def test_version_manager_contract_lines_are_intact():
    # version_manager.py rewrites these two lines with regexes on every bump
    assert re.search(r'^#define MyAppVersion "[\d.]+"', ISS_TEXT, re.M)
    assert re.search(r"^OutputBaseFilename=Sorour_Logistics_Setup_v[\d.]+\s*$", ISS_TEXT, re.M)


# ------------------------------------------------------------------------------------------------
# {app}\data\ and {app}\dist\ on the production laptop (Q1 answer, 2026-09-24)
# ------------------------------------------------------------------------------------------------
PROTECTED_APP_SUBFOLDERS = ("data", "dist")


def _refs_to(folder: str, text: str) -> list:
    return re.findall(rf"\{{app\}}\\{folder}\b[^\s\"']*", text, re.I)


@pytest.mark.parametrize("folder", PROTECTED_APP_SUBFOLDERS)
def test_no_delete_dir_run_or_code_entry_references_app_data_or_dist(folder):
    for section in ("installdelete", "uninstalldelete", "dirs", "run", "uninstallrun", "icons"):
        for entry in _entries(section):
            assert not _refs_to(folder, entry), f"[{section}] touches {{app}}\\{folder}: {entry}"
    code_without_comments = "\n".join(line for line in CODE.splitlines() if not line.lstrip().startswith("//"))
    assert not _refs_to(folder, code_without_comments), f"[Code] references {{app}}\\{folder}"
    assert f"'{folder}'" not in code_without_comments.lower()


@pytest.mark.parametrize("folder", PROTECTED_APP_SUBFOLDERS)
def test_no_files_entry_targets_app_data_or_dist_directly(folder):
    for entry in _entries("files"):
        dest = _param(entry, "DestDir").lower().rstrip("\\")
        assert not dest.startswith(f"{{app}}\\{folder}"), entry


def test_stray_dist_folder_in_staging_is_excluded():
    # anchored pattern: excludes <staging>\dist\* only, not Flutter's data\...\dist\ assets
    wildcard = [e for e in _entries("files") if _param(e, "Source").endswith("*")]
    for entry in wildcard:
        excludes = [x.strip().lower() for x in _param(entry, "Excludes").split(",")]
        assert "\\dist\\*" in excludes


def test_files_never_delete_anything_in_app_data():
    # [Files] only overwrites the Flutter runtime files it ships (data\app.so, icudtl.dat,
    # flutter_assets); flags that would remove other files are forbidden.
    for entry in _entries("files"):
        flags = _param(entry, "Flags").lower()
        assert "deleteafterinstall" not in flags
        assert "uninsremovereadonly" not in flags
