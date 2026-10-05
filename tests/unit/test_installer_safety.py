"""
Installer safety invariants for installer/importflow_setup.iss (plan docs/plans/update-system-plan.md, section 0).

R1  no [Files] entry ships a database / .env, the wildcard entry excludes them, there is no
    [UninstallDelete], and [InstallDelete] only removes the legacy destructive scripts and the old
    script launchers by exact name.
    One install mode only (no PrivilegesRequiredOverridesAllowed).
R2m chosen {app} without a DB + exactly one other install folder with a DB: the DB (+ -wal/-shm) is copied
    read-only into {app}\\backups\\pre_migrate_*\\ (kept) and \\staging\\, verified by size + SHA-256, moved into
    {app} with RenameFile (never overwrites, .db last, moved back on failure). Interactive installs only,
    only from a still-registered install (App Path + unins###.exe), never twice for the same DB (HKCU marker).
    The old install is retired in ssPostInstall (app stopped, source re-fingerprinted, uninstaller run
    elevated with 'runas'). Several other folders with a DB, an unregistered one or a silent install: abort.
R2  PrepareToInstall stops frontend.exe/backend.exe, copies .db + -wal + -shm into
    {app}\\backups\\pre_install_<version>_<timestamp>\\, verifies the copies and aborts on any failure.
R3  uninstall keeps the data: data folders carry uninsneveruninstall, the DB is never a Setup file.
C11 a silent install relaunches the app only with /RELAUNCH=1; the interactive checkbox is unchanged.
K2  StopRunningApp kills by image name without /T (Setup is a child of backend.exe during an in-app update).
L1  shortcuts, the launch checkbox and the silent relaunch start {app}\\frontend.exe directly; nothing in the
    script launches the .vbs/.bat launchers (Windows is removing VBScript). They are only named to be
    excluded from [Files] and removed by [InstallDelete]: their port-28080 taskkill closed the open app.

These are static checks on the script text; ISCC compiles it in CI (build_and_release.yml).
"""
import importlib.util
import re
import sys
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


LEGACY_LAUNCHERS = ("Launch_ImportFlow.vbs", "Launch_Sorour_Logistics.vbs", "Sorour_Logistics_App.bat")


def test_install_delete_removes_only_the_legacy_destructive_scripts():
    entries = _entries("installdelete")
    targets = sorted(_param(e, "Name") for e in entries)

    assert targets == sorted([
        "{app}\\clean_and_isolate_databases.py",
        "{app}\\reset_clean_production_db.py",
        "{app}\\seed.py",
        "{app}\\sync_to_production.py",
        *("{app}\\" + name for name in LEGACY_LAUNCHERS),
    ])
    assert all(_param(e, "Type").lower() == "files" for e in entries)


# comment-free [Code] and call parsing come from the release guard, so both read the script the same way
GUARD_PATH = PROJECT_DIR / "scripts" / "release" / "bundle_guard.py"


def _load_guard():
    spec = importlib.util.spec_from_file_location("importflow_bundle_guard_for_installer_tests", GUARD_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclasses resolve annotations through sys.modules
    spec.loader.exec_module(module)
    return module


guard = _load_guard()
_split_arguments = guard._split_arguments
CODE_ONLY = guard.strip_pascal_comments(CODE)


def _calls(function: str) -> list:
    """Argument text of every call to `function` in comment-free [Code]."""
    return [args.strip() for args in guard._call_arguments(CODE_ONLY, function)]


def test_code_deletes_only_its_tmp_scratch_file():
    for args in _calls("DeleteFile") + _calls("DelTree") + _calls("DelayDeleteFile") + _calls("RemoveDir"):
        assert args.startswith("ExpandConstant('{tmp}\\process_check_"), args


def test_code_never_deletes_anything_but_the_tmp_scratch_file():
    deletes = [a for f in ("DeleteFile", "DelTree", "DelayDeleteFile", "RemoveDir") for a in _calls(f)]
    assert deletes == ["ExpandConstant('{tmp}\\process_check_' + ExeName + '.txt')"], deletes


STAGED = "ExpandConstant('{app}\\backups\\pre_migrate_') + Stamp + '\\staging\\{name}'"
LIVE = "ExpandConstant('{app}\\{name}')"
DB_NAMES = ("sorour_logistics.db", "sorour_logistics.db-wal", "sorour_logistics.db-shm")


def test_rename_is_used_only_for_the_six_migration_moves():
    """3 forward moves (staging -> {app}) in PlaceMigratedFile, 3 reverse ones only in UndoPlacedFiles."""
    forward = sorted([STAGED.replace("{name}", n), LIVE.replace("{name}", n)] for n in DB_NAMES)
    reverse = sorted([LIVE.replace("{name}", n), STAGED.replace("{name}", n)] for n in DB_NAMES)
    assert sorted(_split_arguments(a) for a in _calls("RenameFile")) == sorted(forward + reverse)
    place = _pascal_routine("PlaceMigratedFile")
    undo = _pascal_routine("UndoPlacedFiles")
    assert sorted(_split_arguments(a) for a in guard._call_arguments(place, "RenameFile")) == forward
    assert sorted(_split_arguments(a) for a in guard._call_arguments(undo, "RenameFile")) == reverse


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


def _missing_db_branch() -> str:
    body = _pascal_routine("PrepareToInstall")
    missing = re.search(r"if not FileExists\(DbFile\) then\s*begin(.*?)\n  end;", body, re.S)
    assert missing, "no branch for a missing DB in {app}"
    return missing.group(1)


def test_prepare_to_install_aborts_when_several_other_folders_hold_a_db():
    """Ambiguous: more than one other folder has a DB and {app} has none -> abort, nothing copied."""
    body = _pascal_routine("PrepareToInstall")
    assert body.index("OtherDirs := FindDatabasesOutsideApp(AppDir);") < body.index("if not FileExists(DbFile) then")
    block = _missing_db_branch()
    ambiguous = re.search(
        r"if GetArrayLength\(OtherDirs\) > 1 then\s*begin\s*"
        r"Result := WrongFolderAbortMessage\(JoinFolders\(OtherDirs\), AppDir, '[^']+'\);\s*Exit;\s*end;", block)
    assert ambiguous, block
    assert ambiguous.start() < block.index("GetArrayLength(OtherDirs) = 1")


def test_one_other_folder_is_migrated_only_when_allowed():
    block = _missing_db_branch()
    one = re.search(
        r"if GetArrayLength\(OtherDirs\) = 1 then\s*begin\s*"
        r"if not MigrationAllowed\(OtherDirs\[0\], Reason\) then\s*begin\s*"
        r"Result := WrongFolderAbortMessage\(JoinFolders\(OtherDirs\), AppDir, Reason\);\s*Exit;\s*end;\s*"
        r"Result := MigrateFromOldInstall\(OtherDirs\[0\], AppDir\);\s*Exit;\s*end;", block)
    assert one, block
    assert CODE_ONLY.count("MigrateFromOldInstall(") == 2  # definition + this single call


def test_silent_installs_never_migrate():
    """Migration (and the UAC prompt after it) is interactive-only; a silent install aborts instead."""
    gate = _pascal_routine("MigrationAllowed")
    silent = re.search(r"if WizardSilent then\s*begin(.*?)\n  end;", gate, re.S)
    assert silent, gate
    production = silent.group(1).split("#else", 1)[1].split("#endif", 1)[0]  # what a normal build compiles
    assert "Reason := 'silent install:" in production and "Exit;" in production
    assert "#ifdef RehearsalAllowSilentMigration" in silent.group(1)
    assert gate.index("if WizardSilent then") < gate.index("FindOldUninstaller(")


def test_only_a_registered_installation_is_migrated():
    """A leftover DB in a folder that is no longer a registered install (e.g. after an earlier migration
    and uninstall) goes back to the wrong-folder abort."""
    gate = _pascal_routine("MigrationAllowed")
    assert re.search(r"if not FindOldUninstaller\(OldDir, RootKey, Key, Exe, Elevate\) then\s*begin\s*"
                     r"Reason := '[^']*not a registered installation[^']*';\s*Exit;", gate)
    assert re.search(r"Result := True;\s*end;$", gate.strip())


def test_the_same_database_is_never_migrated_twice():
    migrate = _pascal_routine("MigrateDatabaseFromOtherFolder")
    check = migrate.index("if AlreadyMigrated(Source.HashDb, Where) then")
    assert migrate.index("ReadSourceFingerprint(SrcDb, Source, ErrorText)") < check < migrate.index("ForceDirectories(")
    assert migrate.index("WriteMigrationMarker(OldDir, Source.HashDb);") > migrate.rindex("PlaceMigratedFile(")
    marker = _pascal_routine("WriteMigrationMarker")
    for value in ("'MigratedFrom', OldDir", "'SourceSha256', HashDb", "'MigratedTo'"):
        assert f"RegWriteStringValue(HKCU, MigrationMarkerKey, {value}" in marker
    already = _pascal_routine("AlreadyMigrated")
    assert "RegQueryStringValue(HKCU, MigrationMarkerKey, 'SourceSha256', Stored)" in already
    assert "CompareText(Stored, HashDb) <> 0" in already
    assert re.search(r"^  MigrationMarkerKey = 'Software\\\{#MyAppPublisher\}\\\{#MyAppName\}\\InstallerMigration';", CODE, re.M)


def test_target_with_db_continues_and_only_logs_other_folders():
    body = _pascal_routine("PrepareToInstall")
    after_branch = body[body.index("if not FileExists(DbFile) then"):]
    assert after_branch.index("LogOtherDatabases(OtherDirs, DbFile);") < after_branch.index("StopRunningApp")
    logger = _pascal_routine("LogOtherDatabases")
    assert "continuing with it" in logger and "Log(" in logger
    assert "Result" not in logger  # a procedure: it can never abort


def test_other_install_folders_are_all_searched():
    body = _pascal_routine("FindDatabasesOutsideApp")
    for location in ("RegisteredAppPath(HKCU)", "RegisteredAppPath(HKLM32)", "RegisteredAppPath(HKLM64)",
                     "{userpf}\\{#MyAppName}", "{commonpf32}\\{#MyAppName}", "{commonpf64}\\{#MyAppName}"):
        assert location in body, location
    assert "IsWin64" in body  # 64-bit constants/views only on 64-bit Windows

    other = _pascal_routine("DatabaseFolderIfOther")
    assert "NormalizeDir(Dir) = NormalizeDir(AppDir)" in other  # the chosen {app} itself is not "another" folder

    add = _pascal_routine("AddDatabaseFolder")  # the registered path and the Program Files default are one folder
    assert "if NormalizeDir(Dirs[I]) = NormalizeDir(Found) then" in add


def test_wrong_folder_message_is_arabic_and_english():
    body = _pascal_routine("WrongFolderAbortMessage")
    assert re.search(r"[؀-ۿ]", body)
    assert "found in a different installation folder" in body
    assert "Reason: " in body and "Existing data: " in body and "Selected folder: " in body


# ------------------------------------------------------------------------------------------------
# R2m: migration from the one other install folder
# ------------------------------------------------------------------------------------------------
SOURCE_NAMES = ("OldDir", "SrcDb", "SourceFile")


def test_old_folder_is_never_written_moved_or_deleted():
    """The source DB (old install) is only read: no write/move/delete call takes a source path as target."""
    targets = [_split_arguments(a)[1] for a in _calls("CopyFile")]
    targets += [part for a in _calls("RenameFile") for part in _split_arguments(a)]  # both ends of a move
    targets += [_split_arguments(a)[0] for f in ("SaveStringToFile", "SaveStringsToFile", "SaveStringsToUTF8File",
                                                 "SaveStringToUTF8File", "DeleteFile", "DelTree", "RemoveDir",
                                                 "DelayDeleteFile") for a in _calls(f)]
    assert targets
    for target in targets:
        # ExtractFileName(SourceFile) only borrows the NAME of the source for the copy in {app}
        folder_part = re.sub(r"ExtractFileName\(\w+\)", "", target)
        assert not any(name in folder_part for name in SOURCE_NAMES), target
        assert target.startswith(("ExpandConstant('{app}\\", "ExpandConstant('{tmp}\\")), target
    assert "FileCopy(" not in CODE_ONLY and "MoveFile" not in CODE_ONLY


def test_migration_never_overwrites():
    for args in _calls("CopyFile"):
        assert _split_arguments(args)[2] == "True", f"CopyFile must use FailIfExists=True: {args}"
    migrate = _pascal_routine("MigrateDatabaseFromOtherFolder")
    precheck = re.search(r"if FileExists\(ExpandConstant\('\{app\}\\sorour_logistics\.db'\)\) or "
                         r"FileExists\(ExpandConstant\('\{app\}\\sorour_logistics\.db-wal'\)\)\s*"
                         r"or FileExists\(ExpandConstant\('\{app\}\\sorour_logistics\.db-shm'\)\) then\s*begin\s*"
                         r"ErrorText := .*?;\s*Exit;", migrate, re.S)
    assert precheck
    assert precheck.start() < migrate.index("ForceDirectories(")
    assert "if DirExists(BackupDir) then" in migrate  # a fresh migration folder, never reused
    copy = _pascal_routine("CopyToMigrationFolder")
    assert copy.index("if FileExists(Target) then") < copy.index("CopyFile(")


def test_migration_copies_are_verified_by_size_and_sha256():
    size = _pascal_routine("FileSizeMatches")
    assert "GetFileSizeParts(FileName, High, Low)" in size and "(High <> SizeHigh) or (Low <> SizeLow)" in size
    matches = _pascal_routine("FileMatches")
    assert "FileSizeMatches(FileName, SizeHigh, SizeLow, ErrorText)" in matches
    assert "TryFileSha256(FileName, Actual, ErrorText)" in matches
    assert "CompareText(Actual, Hash) <> 0" in matches
    assert "GetSHA256OfFile(FileName)" in _pascal_routine("TryFileSha256")

    copy = _pascal_routine("CopyToMigrationFolder")
    assert ("if not CopyFile(SourceFile, ExpandConstant('{app}\\backups\\pre_migrate_') + Stamp + SubDir + "
            "ExtractFileName(SourceFile), True) then") in copy
    assert "if not FileMatches(Target, SizeHigh, SizeLow, Hash, ErrorText) then" in copy


def test_source_fingerprint_covers_db_wal_and_shm():
    read = _pascal_routine("ReadSourceFingerprint")
    assert "F.HasWal := FileExists(SrcDb + '-wal');" in read and "F.HasShm := FileExists(SrcDb + '-shm');" in read
    for call in ("ReadFileFingerprint(SrcDb, F.DbHigh, F.DbLow, F.HashDb, ErrorText)",
                 "ReadFileFingerprint(SrcDb + '-wal', F.WalHigh, F.WalLow, F.HashWal, ErrorText)",
                 "ReadFileFingerprint(SrcDb + '-shm', F.ShmHigh, F.ShmLow, F.HashShm, ErrorText)"):
        assert f"if not {call} then" in read, call
    same = _pascal_routine("SameFingerprint")
    for part in ("A.HasWal = B.HasWal", "A.HasShm = B.HasShm", "CompareText(A.HashDb, B.HashDb) = 0",
                 "CompareText(A.HashWal, B.HashWal) = 0", "CompareText(A.HashShm, B.HashShm) = 0"):
        assert part in same, part


def test_migration_copies_to_backup_and_staging_then_rechecks_the_source():
    migrate = _pascal_routine("MigrateDatabaseFromOtherFolder")
    assert "if not CopyAllToMigrationFolder(SrcDb, Stamp, '\\', Source, ErrorText) then" in migrate
    assert "if not CopyAllToMigrationFolder(SrcDb, Stamp, '\\staging\\', Source, ErrorText) then" in migrate
    copy_all = _pascal_routine("CopyAllToMigrationFolder")
    for suffix, part in (("", "Db"), (" + '-wal'", "Wal"), (" + '-shm'", "Shm")):
        assert f"CopyToMigrationFolder(SrcDb{suffix}, Stamp, SubDir, F.{part}High, F.{part}Low, F.Hash{part}, ErrorText)" in copy_all
    assert "ExpandConstant('{app}\\backups\\pre_migrate_') + Stamp" in migrate
    assert "MakeFolderTag(OldDir) + '_' + GetDateTimeString('yyyymmdd_hhnnss'" in migrate
    last_copy = migrate.rindex("CopyAllToMigrationFolder(")
    recheck = migrate.index("ReadSourceFingerprint(SrcDb, Recheck, ErrorText)")
    assert last_copy < recheck < migrate.index("PlaceMigratedFile(")
    assert "if not SameFingerprint(Source, Recheck) then" in migrate


def test_every_migration_failure_exits_with_an_error():
    migrate = _pascal_routine("MigrateDatabaseFromOtherFolder")
    checks = re.findall(r"if not (?:CopyAllToMigrationFolder|ReadSourceFingerprint|SameFingerprint|ForceDirectories|PlaceMigratedFile)"
                        r"\((?:[^()]|\([^()]*\))*\) then\s*(begin.*?end;|Exit;)", migrate, re.S)
    assert len(checks) == 9, len(checks)
    for block in checks:
        assert "Exit;" in block, block
    assert re.search(r"Result := True;\s*end;$", migrate.strip())  # success only at the very end
    assert migrate.count("Result := True;") == 1


def test_migrated_files_are_placed_side_files_first_db_last_and_undone_on_failure():
    migrate = _pascal_routine("MigrateDatabaseFromOtherFolder")
    wal, shm, db = (migrate.index(f"PlaceMigratedFile(Stamp, {s})") for s in ("'-wal'", "'-shm'", "''"))
    assert wal < shm < db
    after = migrate[wal:]
    assert after.count("UndoPlacedFiles(Stamp, PlacedDb, PlacedWal, PlacedShm)") == 4
    # flags are set only after a successful move, so only files THIS run placed are moved back
    for flag, call in (("PlacedWal", "'-wal'"), ("PlacedShm", "'-shm'"), ("PlacedDb", "''")):
        assert migrate.index(f"PlaceMigratedFile(Stamp, {call})") < migrate.index(f"{flag} := True;")
    undo = _pascal_routine("UndoPlacedFiles")
    for flag, name in (("PlacedDb", "sorour_logistics.db'"), ("PlacedWal", "sorour_logistics.db-wal'"),
                       ("PlacedShm", "sorour_logistics.db-shm'")):
        assert re.search(rf"if {flag} then\s*if not RenameFile\(ExpandConstant\('\{{app\}}\\{re.escape(name)}\)", undo)
    assert undo.index("PlacedDb") < undo.index("PlacedWal")  # the .db leaves first
    # after a same-volume move only existence + size are re-checked
    final = migrate[migrate.index("PlacedDb := True;"):]
    assert final.count("FileSizeMatches(") == 3 and "FileMatches(" not in final.replace("FileSizeMatches(", "")


def test_prepare_to_install_never_retires_the_old_install():
    for routine in ("PrepareToInstall", "MigrateFromOldInstall", "MigrateDatabaseFromOtherFolder", "MigrationAllowed"):
        body = _pascal_routine(routine)
        assert "RetireOldInstall" not in body and "ShellExec" not in body, routine


def test_old_install_is_retired_only_after_the_new_install():
    step = _pascal_routine("CurStepChanged")
    assert re.search(r"if \(CurStep = ssPostInstall\) and \(MigratedFromDir <> ''\) then\s*RetireOldInstallAfterInstall;", step)
    assert CODE_ONLY.count("RetireOldInstallAfterInstall") == 2  # definition + the ssPostInstall call
    assert CODE_ONLY.count("RetireOldInstall(") == 2  # definition + the call in RetireOldInstallAfterInstall
    assert CODE_ONLY.count("ShellExec(") == 1
    # MigratedFromDir is set only after a verified migration
    migrate = _pascal_routine("MigrateFromOldInstall")
    assert migrate.index("if not MigrateDatabaseFromOtherFolder(OldDir, MigratedSource, ErrorText) then") < \
        migrate.index("MigratedFromDir := OldDir;")
    failure = re.search(r"if not MigrateDatabaseFromOtherFolder\(OldDir, MigratedSource, ErrorText\) then\s*begin(.*?)end;",
                        migrate, re.S).group(1)
    assert "Result := MigrationAbortMessage(ErrorText, OldDir, AppDir);" in failure and "Exit;" in failure


def test_retire_stops_the_app_and_rechecks_the_source_first():
    retire = _pascal_routine("RetireOldInstallAfterInstall")
    order = [retire.index(s) for s in ("StopRunningApp;", "if not WaitForAppExit then",
                                       "ReadSourceFingerprint(AddBackslash(MigratedFromDir) + DbFileName, Current, Detail)",
                                       "if not SameFingerprint(MigratedSource, Current) then",
                                       "RetireOldInstall(MigratedFromDir, Detail)")]
    assert order == sorted(order)
    # every earlier check is an `else if` in front of the uninstall: a failed one skips it
    assert re.search(r"if not WaitForAppExit then\s*Detail := .*?\s*else if not ReadSourceFingerprint.*?\s*"
                     r"Detail := .*?\s*else if not SameFingerprint.*?\s*Detail := .*?\s*"
                     r"else if RetireOldInstall\(MigratedFromDir, Detail\) then\s*Exit;", retire, re.S)
    tail = retire[retire.index("else if RetireOldInstall"):]
    assert "OldInstallStillPresent := True;" in tail
    assert "Log('NOTICE: ' + OldInstallNotice(MigratedFromDir, Detail));" in tail
    assert re.search(r"if not WizardSilent then\s*MsgBox\(OldInstallNotice\(MigratedFromDir, Detail\)", tail)


def test_old_uninstaller_runs_elevated_and_silently():
    retire = _pascal_routine("RetireOldInstall")
    assert re.search(r"#else\s*Verb := 'runas';\s*#endif", retire)
    assert ("ShellExec(Verb, Exe, '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_SHOWNORMAL, "
            "ewWaitUntilTerminated, ErrorCode)") in retire
    find = _pascal_routine("FindOldUninstaller")
    assert find.index("HKLM32") < find.index("Elevate := False;")  # all-users registrations need elevation


def test_uninstaller_must_be_an_inno_uninstaller_inside_the_old_folder():
    key = _pascal_routine("UninstallerFromKey")
    assert "NormalizeDir(Path) <> NormalizeDir(OldDir)" in key
    assert "NormalizeDir(ExtractFileDir(Value)) <> NormalizeDir(OldDir)" in key
    assert "if not IsInnoUninstallerName(ExtractFileName(Value)) then" in key
    name = _pascal_routine("IsInnoUninstallerName")
    assert "(Length(Name) = 12) and (Copy(Name, 1, 5) = 'unins') and (Copy(Name, 9, 4) = '.exe')" in name
    assert "for I := 6 to 8 do" in name and "(Name[I] < '0') or (Name[I] > '9')" in name


def test_notices_and_messages_are_arabic_and_english():
    notice = _pascal_routine("OldInstallNotice")
    assert re.search(r"[؀-ۿ]", notice)
    assert "Settings → Apps" in notice and "do not use it any more" in notice and "Details: " in notice
    body = _pascal_routine("MigrationAbortMessage")
    assert re.search(r"[؀-ۿ]", body)
    assert "could not be migrated from the old installation" in body
    assert "The database in the old folder was not changed." in body
    assert "Details: " in body and "Existing data: " in body and "Selected folder: " in body


def test_finish_page_and_log_state_where_the_data_came_from():
    summary = _pascal_routine("MigrationSummary")
    assert "'Data was migrated from: ' + AddBackslash(MigratedFromDir) + DbFileName" in summary
    assert re.search(r"[؀-ۿ]", summary)
    page = _pascal_routine("CurPageChanged")
    assert "(CurPageID = wpFinished) and (MigratedFromDir <> '')" in page
    assert "WizardForm.FinishedLabel.Caption + #13#10#13#10 + MigrationSummary" in page
    assert "if OldInstallStillPresent then" in page
    assert "Log(MigrationSummary);" in _pascal_routine("DeinitializeSetup")


def test_rehearsal_hooks_exist_only_behind_ifdef():
    """ISCC /DRehearsal... is for scratch rehearsals; the #else branch of such a block is production code."""
    in_rehearsal = []  # stack: True while inside the #ifdef Rehearsal... branch
    for line in CODE.splitlines():
        stripped = line.strip()
        if stripped.startswith("#if"):
            in_rehearsal.append(stripped.startswith("#ifdef Rehearsal"))
            continue
        if stripped.startswith("#else"):
            in_rehearsal[-1] = False  # production branch
            continue
        if stripped.startswith("#endif"):
            in_rehearsal.pop()
            continue
        if "Rehearsal" in line and not stripped.startswith("//"):
            assert in_rehearsal and in_rehearsal[-1], line
    assert not in_rehearsal
    assert not re.search(r"^#define\s+Rehearsal", ISS_TEXT, re.M)


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
    # CurStepChanged exists again, but only to retire the old install after a migration: it copies nothing
    step = _pascal_routine("CurStepChanged")
    assert "CopyFile" not in step and "Backup" not in step
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
    assert _expand(_param(silent[0], "Filename")).lower() == "{app}\\frontend.exe"
    assert _param(silent[0], "WorkingDir") == "{app}"
    assert "nowait" in flags and "runasoriginaluser" in flags

    check = _pascal_routine("ShouldRelaunchAfterSilentInstall")
    assert "WizardSilent and (ExpandConstant('{param:RELAUNCH|0}') = '1')" in check


# ------------------------------------------------------------------------------------------------
# L1 launch target: frontend.exe, never VBScript
# ------------------------------------------------------------------------------------------------
SCRIPT_LAUNCHER_RE = re.compile(r"(\.vbs|\.vbe|\.wsf|\.wsh|\.js|\.bat|\.cmd)\b|wscript|cscript|Launch_Sorour_Logistics|Launch_ImportFlow", re.I)


def _define(name: str) -> str:
    match = re.search(rf'^#define\s+{name}\s+"([^"]*)"', ISS_TEXT, re.M)
    assert match, f"no #define {name}"
    return match.group(1)


def _expand(value: str) -> str:
    return re.sub(r"\{#(\w+)\}", lambda m: _define(m.group(1)), value)


def _app_launch_entries() -> list:
    """[Icons] and [Run] entries that start the app (the uninstall shortcut is not one)."""
    icons = [e for e in _entries("icons") if _param(e, "Filename") != "{uninstallexe}"]
    return icons + _entries("run")


def test_app_exe_is_frontend_exe():
    assert _define("MyAppExeName") == "frontend.exe"


def test_no_icons_or_run_entry_references_a_script_launcher():
    for section in ("icons", "run"):
        entries = _entries(section)
        assert entries, f"[{section}] is empty"
        for entry in entries:
            assert not SCRIPT_LAUNCHER_RE.search(_expand(entry)), f"[{section}] references a script launcher: {entry}"


def test_script_never_references_the_vbs_launcher_outside_comments():
    """Only [InstallDelete] (removal) and the [Files] Excludes may name a launcher."""
    removal_lines = set(_entries("installdelete"))
    for line in ISS_TEXT.splitlines():
        stripped = line.strip()
        if stripped.startswith(";") or stripped.startswith("//") or stripped in removal_lines:
            continue
        without_excludes = re.sub(r'\bExcludes\s*:\s*"[^"]*"', "", stripped, flags=re.I)
        assert not SCRIPT_LAUNCHER_RE.search(without_excludes), line


@pytest.mark.parametrize("launcher", LEGACY_LAUNCHERS)
def test_legacy_launchers_are_never_shipped_and_removed_from_app(launcher):
    # they killed every PID on a netstat line with :28080, i.e. also the running frontend.exe
    wildcard_entries = [e for e in _entries("files") if "*" in _param(e, "Source")]
    assert wildcard_entries
    for entry in wildcard_entries:
        excludes = [x.strip().lower() for x in _param(entry, "Excludes").split(",")]
        assert launcher.lower() in excludes, f"[Files] would ship {launcher} again: {entry}"
    deletes = [e for e in _entries("installdelete") if _param(e, "Name").lower() == "{app}\\" + launcher.lower()]
    assert len(deletes) == 1 and _param(deletes[0], "Type").lower() == "files", deletes


def test_every_app_launch_starts_frontend_exe_in_app_dir():
    entries = _app_launch_entries()
    # start menu + desktop shortcut + interactive checkbox + silent relaunch
    assert len(entries) == 4, entries
    for entry in entries:
        assert _expand(_param(entry, "Filename")).lower() == "{app}\\frontend.exe", entry
        assert _param(entry, "WorkingDir") == "{app}", entry
        assert "shellexec" not in _param(entry, "Flags").lower(), f"an .exe needs no shellexec: {entry}"


def test_start_menu_and_desktop_shortcuts_keep_their_names():
    # same names as the shortcuts older installers created, so the upgrade overwrites them
    names = {_param(e, "Name") for e in _entries("icons")}
    assert "{group}\\{#MyAppName}" in names
    assert "{autodesktop}\\{#MyAppName}" in names


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
