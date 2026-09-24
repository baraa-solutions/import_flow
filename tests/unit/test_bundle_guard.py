"""
Release bundle guard (plan docs/plans/update-system-plan.md section 0, R1/R4) and the CI workflow that runs it.

- scripts/release/bundle_guard.py passes a clean bundle and fails, with a clear message, on every
  database / secret / data folder / destructive script, in a folder, a zip or an Inno Setup script.
- .github/workflows/build_and_release.yml runs on version tags only, packages with --no-bump and runs
  the guard before the installer is built.
"""
import importlib.util
import re
import sys
import zipfile
from pathlib import Path

import pytest

PROJECT_DIR = Path(__file__).resolve().parents[2]
GUARD_PATH = PROJECT_DIR / "scripts" / "release" / "bundle_guard.py"
ISS_PATH = PROJECT_DIR / "installer" / "importflow_setup.iss"
WORKFLOW_PATH = PROJECT_DIR / ".github" / "workflows" / "build_and_release.yml"


def _load_guard():
    spec = importlib.util.spec_from_file_location("importflow_bundle_guard_under_test", GUARD_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclasses resolve annotations through sys.modules
    spec.loader.exec_module(module)
    return module


guard = _load_guard()


def _make_clean_bundle(root: Path) -> Path:
    bundle = root / "Sorour_Logistics_Standalone"
    (bundle / "data" / "flutter_assets" / "assets").mkdir(parents=True)
    (bundle / "frontend.exe").write_bytes(b"MZ")
    (bundle / "backend.exe").write_bytes(b"MZ")
    (bundle / "flutter_windows.dll").write_bytes(b"MZ")
    (bundle / "version.json").write_text('{"version": "2.0.3"}', encoding="utf-8")
    (bundle / "version_manager.py").write_text("# ok", encoding="utf-8")
    (bundle / "incoterms_data.json").write_text("[]", encoding="utf-8")
    (bundle / "Launch_Sorour_Logistics.vbs").write_text("' launcher", encoding="utf-8")
    (bundle / "app_icon.ico").write_bytes(b"\x00")
    # look-alikes that must NOT be flagged
    (bundle / "data" / "icudtl.dat").write_bytes(b"\x00")
    (bundle / "data" / "flutter_assets" / "assets" / "database_icon.png").write_bytes(b"\x00")
    (bundle / "data" / "flutter_assets" / "assets" / "keyboard.json").write_text("{}", encoding="utf-8")
    (bundle / "data" / "flutter_assets" / "assets" / "environment.json").write_text("{}", encoding="utf-8")
    (bundle / "db_helpers.txt").write_text("", encoding="utf-8")
    return bundle


# ------------------------------------------------------------------------------------------------
# Folder scan
# ------------------------------------------------------------------------------------------------
def test_clean_bundle_passes(tmp_path, capsys):
    bundle = _make_clean_bundle(tmp_path)

    assert guard.scan_directory(bundle) == []
    assert guard.main(["--dir", str(bundle)]) == 0
    assert "PASS" in capsys.readouterr().out


FORBIDDEN_FILES = [
    ("sorour_logistics.db", "SQLite database"),
    ("x.db", "SQLite database"),
    ("sorour_logistics.db-wal", "write-ahead log"),
    ("sorour_logistics.db-shm", "shared-memory"),
    ("sorour_logistics.db-journal", "rollback journal"),
    ("data.sqlite", "SQLite"),
    ("data.sqlite3", "SQLite"),
    ("SOROUR_LOGISTICS.DB", "SQLite database"),
    (".env", "environment secrets file"),
    (".env.production", "environment file"),
    ("update_signing.key", "private key"),
    ("server.pem", "certificate"),
    ("reset_clean_production_db.py", "destructive maintenance script"),
    ("clean_and_isolate_databases.py", "destructive maintenance script"),
    ("sync_to_production.py", "destructive maintenance script"),
    ("execute_user_database_updates.py", "destructive maintenance script"),
    ("update_db_schema.py", "destructive maintenance script"),
    ("restore_database.py", "destructive maintenance script"),
    ("prepare_uat_environment.py", "destructive maintenance script"),
    ("seed.py", "destructive maintenance script"),
]


@pytest.mark.parametrize("name,reason_fragment", FORBIDDEN_FILES)
def test_each_forbidden_file_fails_with_clear_message(tmp_path, capsys, name, reason_fragment):
    bundle = _make_clean_bundle(tmp_path)
    forbidden = bundle / name
    forbidden.write_bytes(b"secret or data")

    exit_code = guard.main(["--dir", str(bundle)])
    output = capsys.readouterr().out

    assert exit_code == 1
    assert "FAIL" in output
    assert name in output
    assert reason_fragment in output
    assert "must never ship" in output
    # read-only: the guard never deletes what it finds
    assert forbidden.exists()


def test_forbidden_file_in_a_subfolder_is_found(tmp_path):
    bundle = _make_clean_bundle(tmp_path)
    (bundle / "data" / "old_copy.db").write_bytes(b"x")

    violations = guard.scan_directory(bundle)

    assert [v.location for v in violations] == ["Sorour_Logistics_Standalone/data/old_copy.db"]


@pytest.mark.parametrize("folder", ["backups", "updates", "Backups"])
def test_data_folders_fail_once_per_folder(tmp_path, folder):
    bundle = _make_clean_bundle(tmp_path)
    (bundle / folder).mkdir()
    (bundle / folder / "daily_backup_20260101.zip").write_bytes(b"x")
    (bundle / folder / "notes.txt").write_text("x", encoding="utf-8")

    violations = guard.scan_directory(bundle)

    assert len(violations) == 1
    assert violations[0].location == f"Sorour_Logistics_Standalone/{folder}"
    assert "must never ship" in violations[0].reason


def test_several_problems_are_all_reported(tmp_path, capsys):
    bundle = _make_clean_bundle(tmp_path)
    (bundle / "sorour_logistics.db").write_bytes(b"x")
    (bundle / ".env").write_text("SECRET_KEY=x", encoding="utf-8")
    (bundle / "sync_to_production.py").write_text("", encoding="utf-8")

    assert guard.main(["--dir", str(bundle)]) == 1
    output = capsys.readouterr().out
    assert "3 forbidden item(s)" in output


# ------------------------------------------------------------------------------------------------
# Zip scan
# ------------------------------------------------------------------------------------------------
def _zip_of(bundle: Path, archive: Path) -> Path:
    with zipfile.ZipFile(archive, "w") as zf:
        for path in bundle.rglob("*"):
            if path.is_file():
                zf.write(path, path.relative_to(bundle.parent))
    return archive


def test_clean_zip_passes(tmp_path):
    bundle = _make_clean_bundle(tmp_path)
    archive = _zip_of(bundle, tmp_path / "Sorour_Logistics_v2.0.3_Windows_Portable.zip")

    assert guard.main(["--zip", str(archive)]) == 0


def test_zip_with_database_fails(tmp_path, capsys):
    bundle = _make_clean_bundle(tmp_path)
    (bundle / "sorour_logistics.db").write_bytes(b"x")
    archive = _zip_of(bundle, tmp_path / "portable.zip")

    assert guard.main(["--zip", str(archive)]) == 1
    assert "portable.zip!Sorour_Logistics_Standalone/sorour_logistics.db" in capsys.readouterr().out


# ------------------------------------------------------------------------------------------------
# Arguments
# ------------------------------------------------------------------------------------------------
def test_no_input_is_a_usage_error(capsys):
    assert guard.main([]) == 2
    assert "nothing to check" in capsys.readouterr().err


def test_missing_input_is_an_error_not_a_pass(tmp_path, capsys):
    assert guard.main(["--dir", str(tmp_path / "does_not_exist")]) == 2
    assert "input not found" in capsys.readouterr().err


# ------------------------------------------------------------------------------------------------
# Inno Setup script checks
# ------------------------------------------------------------------------------------------------
def test_real_installer_script_passes_the_guard():
    assert guard.check_iss_file(ISS_PATH) == []


SAFE_ISS = """
[Setup]
AppId={{D37B4254-8B6A-4A73-B5DF-719584C8A69E}
[Files]
Source: "..\\dist\\Sorour_Logistics_Standalone\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs; Excludes: "*.db,*.db-wal,*.db-shm,*.db-journal,*.sqlite*,.env,.env.*,*.key,*.pem,reset_clean_production_db.py,clean_and_isolate_databases.py,sync_to_production.py,execute_user_database_updates.py,populate_all_world_transport_locations.py,clean_transport_locations.py,update_db_schema.py,restore_database.py,prepare_uat_environment.py,seed.py"
[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
end;
"""


def test_safe_iss_passes():
    assert guard.check_iss_text(SAFE_ISS) == []


@pytest.mark.parametrize(
    "extra,expected",
    [
        ('Source: "..\\dist\\Sorour_Logistics_Standalone\\sorour_logistics.db"; DestDir: "{app}"; Flags: ignoreversion uninsneveruninstall',
         "sorour_logistics.db"),
        ('Source: "..\\.env"; DestDir: "{app}"', ".env"),
        ('Source: "..\\x.txt"; DestDir: "{app}"; DestName: "sorour_logistics.db"', "destname=sorour_logistics.db"),
        ('Source: "..\\sync_to_production.py"; DestDir: "{app}"', "sync_to_production.py"),
        ('Source: "..\\dist\\backups\\*"; DestDir: "{app}\\backups"', "backups"),
        ('Source: "..\\dist\\Other\\*"; DestDir: "{app}"; Flags: recursesubdirs', "wildcard source does not exclude"),
    ],
)
def test_iss_files_entry_shipping_data_fails(extra, expected):
    text = SAFE_ISS.replace("[Code]", extra + "\n[Code]", 1)

    violations = guard.check_iss_text(text)

    assert violations, f"guard missed: {extra}"
    assert any(expected in str(v) for v in violations)


@pytest.mark.parametrize("section", ["InstallDelete", "UninstallDelete"])
@pytest.mark.parametrize(
    "entry",
    [
        'Type: files; Name: "{app}\\sorour_logistics.db"',
        'Type: files; Name: "{app}\\*.db-wal"',
        'Type: files; Name: "{app}\\sorour_logistics.*"',
        'Type: files; Name: "{app}\\*"',
        'Type: files; Name: "{app}\\.env"',
        'Type: filesandordirs; Name: "{app}\\backups"',
        'Type: filesandordirs; Name: "{app}\\updates\\*"',
        'Type: filesandordirs; Name: "{app}"',
    ],
)
def test_delete_sections_touching_data_fail(section, entry):
    text = SAFE_ISS.replace("[Code]", f"[{section}]\n{entry}\n[Code]", 1)

    violations = guard.check_iss_text(text)

    assert violations, f"guard missed [{section}] {entry}"
    assert all("production data" in v.reason for v in violations)


LEGACY_DELETES = (
    'Type: files; Name: "{app}\\reset_clean_production_db.py"\n'
    'Type: files; Name: "{app}\\clean_and_isolate_databases.py"\n'
    'Type: files; Name: "{app}\\sync_to_production.py"\n'
    'Type: files; Name: "{app}\\seed.py"\n'
)


def test_install_delete_of_the_three_legacy_scripts_is_allowed():
    text = SAFE_ISS.replace("[Code]", "[InstallDelete]\n" + LEGACY_DELETES + "[Code]", 1)

    assert guard.check_iss_text(text) == []


@pytest.mark.parametrize(
    "section,entry",
    [
        ("InstallDelete", 'Type: files; Name: "{app}\\old_launcher.bat"'),  # allow-list is exact
        ("InstallDelete", 'Type: files; Name: "{app}\\reset_*.py"'),
        ("InstallDelete", 'Type: filesandordirs; Name: "{app}\\sync_to_production.py"'),
        ("InstallDelete", 'Type: files; Name: "{app}\\restore_database.py"'),
        ("InstallDelete", 'Type: filesandordirs; Name: "{app}\\data"'),
        ("InstallDelete", 'Type: filesandordirs; Name: "{app}\\dist"'),
        ("InstallDelete", 'Type: files; Name: "{app}\\data\\seed.py"'),
        ("InstallDelete", 'Type: files; Name: "{app}\\sub\\sync_to_production.py"'),
        ("UninstallDelete", 'Type: files; Name: "{app}\\sync_to_production.py"'),
        ("UninstallDelete", 'Type: files; Name: "{app}\\old_launcher.bat"'),
    ],
)
def test_any_other_delete_entry_fails(section, entry):
    text = SAFE_ISS.replace("[Code]", f"[{section}]\n{entry}\n[Code]", 1)

    violations = guard.check_iss_text(text)

    assert len(violations) == 1, f"guard missed [{section}] {entry}"


# ------------------------------------------------------------------------------------------------
# [Code], [Run], [UninstallRun] delete operations
# ------------------------------------------------------------------------------------------------
def _with_code(statement: str) -> str:
    return SAFE_ISS.replace("  Result := '';\n", "  Result := '';\n  " + statement + "\n", 1)


@pytest.mark.parametrize(
    "statement",
    [
        "DelTree(ExpandConstant('{app}\\backups'), True, True, True);",
        "DeleteFile(ExpandConstant('{app}\\sorour_logistics.db'));",
        "DeleteFile(DbFile);",
        "DeleteFile(ExpandConstant('{app}') + '\\{tmp}\\x');",
        "DelayDeleteFile(ExpandConstant('{app}\\.env'), 3);",
        "RemoveDir(ExpandConstant('{app}\\updates'));",
        "RenameFile(DbFile, DbFile + '.old');",
        "deletefile ( DbFile );",
    ],
)
def test_code_deleting_outside_tmp_fails(statement):
    violations = guard.check_iss_text(_with_code(statement))

    # RenameFile(DbFile, ...) is reported twice: its source leaves {tmp} and its destination is not allowed
    assert len(violations) == (2 if statement.startswith("RenameFile") else 1), statement
    assert "[Code]" in violations[0].location
    assert "outside {tmp}" in violations[0].reason


@pytest.mark.parametrize(
    "statement",
    [
        "Exec(ExpandConstant('{cmd}'), '/C del /Q \"' + DbFile + '\"', '', SW_HIDE, ewWaitUntilTerminated, R);",
        "Exec('cmd.exe', '/C rmdir /S /Q \"' + ExpandConstant('{app}\\backups') + '\"', '', SW_HIDE, ewWaitUntilTerminated, R);",
        "Exec('cmd.exe', '/C rd /S /Q backups', '', SW_HIDE, ewWaitUntilTerminated, R);",
        "Exec('cmd.exe', '/C erase *.db', '', SW_HIDE, ewWaitUntilTerminated, R);",
        "ShellExec('', 'powershell.exe', '-Command Remove-Item -Recurse backups', '', SW_HIDE, ewWaitUntilTerminated, R);",
        "ExecAsOriginalUser('cmd.exe', '/C DEL sorour_logistics.db-wal', '', SW_HIDE, ewWaitUntilTerminated, R);",
    ],
)
def test_code_exec_of_a_delete_command_fails(statement):
    violations = guard.check_iss_text(_with_code(statement))

    assert len(violations) == 1, statement
    assert "deletes, moves or overwrites" in violations[0].reason


@pytest.mark.parametrize(
    "statement",
    [
        "DeleteFile(ExpandConstant('{tmp}\\process_check.txt'));",
        "DeleteFile( ExpandConstant( '{tmp}\\a_' + Name + '.txt' ) );",
        "Exec(ExpandConstant('{sys}\\taskkill.exe'), '/F /IM backend.exe /T', '', SW_HIDE, ewWaitUntilTerminated, R);",
        "Exec(ExpandConstant('{cmd}'), '/C tasklist /NH /FI \"IMAGENAME eq backend.exe\"', '', SW_HIDE, ewWaitUntilTerminated, R);",
        "{ DelTree(ExpandConstant('{app}'), True, True, True); was removed }",
        "// DeleteFile(DbFile);",
        "(* RemoveDir(ExpandConstant('{app}\\backups')); *)",
        "Log('never call DeleteFile(DbFile) here');",
        "Msg := 'a { brace in a string'; Log(Msg);",
    ],
)
def test_harmless_code_passes(statement):
    assert guard.check_iss_text(_with_code(statement)) == []


# ------------------------------------------------------------------------------------------------
# [Code] writes (round-3 review): destinations only under {tmp} or {app}\backups\pre_install_*
# ------------------------------------------------------------------------------------------------
@pytest.mark.parametrize(
    "statement",
    [
        "CopyFile(ExpandConstant('{tmp}\\new.db'), ExpandConstant('{app}\\sorour_logistics.db'), False);",
        "CopyFile(Src, DbFile, False);",
        "CopyFile(Src, Target, True);",
        "FileCopy(Src, ExpandConstant('{app}\\.env'), False);",
        "CopyFile(Src, ExpandConstant('{app}\\backups\\daily_backup_1.db'), False);",
        "CopyFile(Src, ExpandConstant('{app}\\backups\\pre_install_') + '..\\..\\sorour_logistics.db', False);",
        "RenameFile(ExpandConstant('{tmp}\\x.db'), ExpandConstant('{app}\\sorour_logistics.db'));",
        "SaveStringToFile(ExpandConstant('{app}\\.env'), 'SECRET_KEY=x', False);",
        "SaveStringsToFile(DbFile, Lines, False);",
        "SaveStringsToUTF8File(ExpandConstant('{app}\\version.json'), Lines, False);",
        "SaveStringToFile(ExpandConstant('{tmp}\\..\\sorour_logistics.db'), 'x', False);",
    ],
)
def test_code_writing_outside_tmp_or_pre_install_backup_fails(statement):
    violations = guard.check_iss_text(_with_code(statement))

    assert len(violations) == 1, statement
    assert "writes a file outside" in violations[0].reason


@pytest.mark.parametrize(
    "statement",
    [
        "CopyFile(DbFile, ExpandConstant('{app}\\backups\\pre_install_') + Stamp + '\\' + ExtractFileName(DbFile), True);",
        "CopyFile( Src , ExpandConstant( '{app}\\backups\\pre_install_' ) + Stamp, True );",
        "CopyFile(Src, ExpandConstant('{tmp}\\probe.txt'), False);",
        "SaveStringToFile(ExpandConstant('{tmp}\\log.txt'), 'x', True);",
        "SaveStringsToFile(ExpandConstant('{tmp}\\a.txt'), Lines, False);",
        "Log('CopyFile(x, DbFile, False) would be wrong');",
        "// CopyFile(Src, DbFile, False);",
    ],
)
def test_code_writes_into_tmp_or_pre_install_backup_pass(statement):
    assert guard.check_iss_text(_with_code(statement)) == []


@pytest.mark.parametrize(
    "command",
    [
        "/C move /Y new.db sorour_logistics.db",
        "/C ren sorour_logistics.db old.db",
        "/C copy /Y x.db sorour_logistics.db",
        "/C xcopy /Y dist\\* .",
        "/C robocopy src . /MIR",
        "/C sqlite3 sorour_logistics.db \"DELETE FROM users\"",
        "/C sqlite3.exe sorour_logistics.db .dump",
        "-Command Move-Item a.db b.db",
        "-Command Copy-Item a.db sorour_logistics.db",
    ],
)
def test_code_exec_of_a_move_copy_or_sqlite_command_fails(command):
    statement = f"Exec('cmd.exe', '{command}', '', SW_HIDE, ewWaitUntilTerminated, R);"

    violations = guard.check_iss_text(_with_code(statement))

    assert len(violations) == 1, command
    assert "deletes, moves or overwrites" in violations[0].reason


def test_split_arguments_respects_strings_and_parentheses():
    parts = guard._split_arguments("A, ExpandConstant('{app}\\a,b') + F(x, y), True")

    assert parts == ["A", "ExpandConstant('{app}\\a,b') + F(x, y)", "True"]

def test_comment_stripper_keeps_strings_with_braces():
    stripped = guard.strip_pascal_comments("x := '{app}\\a'; { comment {tmp} } y := 1; // tail\nz := 2;")

    assert "'{app}\\a'" in stripped
    assert "comment" not in stripped and "tail" not in stripped
    assert "y := 1;" in stripped and "z := 2;" in stripped


@pytest.mark.parametrize(
    "section,entry",
    [
        ("Run", 'Filename: "{cmd}"; Parameters: "/C del /Q ""{app}\\sorour_logistics.db"""; Flags: runhidden'),
        ("Run", 'Filename: "cmd.exe"; Parameters: "/C rmdir /S /Q ""{app}\\backups"""'),
        ("Run", 'Filename: "powershell.exe"; Parameters: "-Command Remove-Item ""{app}\\.env"""'),
        ("Run", 'Filename: "{app}\\sync_to_production.py"; Flags: shellexec'),
        ("UninstallRun", 'Filename: "{cmd}"; Parameters: "/C rd /S /Q ""{app}"""; RunOnceId: "wipe"'),
        ("UninstallRun", 'Filename: "{app}\\reset_clean_production_db.py"; Flags: shellexec; RunOnceId: "x"'),
    ],
)
def test_run_sections_with_delete_operations_fail(section, entry):
    text = SAFE_ISS.replace("[Code]", f"[{section}]\n{entry}\n[Code]", 1)

    violations = guard.check_iss_text(text)

    assert len(violations) == 1, entry
    assert f"[{section}]" in violations[0].location


def test_normal_launch_in_run_passes():
    entry = 'Filename: "{app}\\Launch_Sorour_Logistics.vbs"; Flags: shellexec postinstall nowait skipifsilent'
    text = SAFE_ISS.replace("[Code]", f"[Run]\n{entry}\n[Code]", 1)

    assert guard.check_iss_text(text) == []


def test_cli_iss_mode_reports_the_line(tmp_path, capsys):
    iss = tmp_path / "bad.iss"
    iss.write_text(SAFE_ISS.replace("[Code]", '[UninstallDelete]\nType: files; Name: "{app}\\*.db"\n[Code]'), encoding="utf-8")

    assert guard.main(["--iss", str(iss)]) == 1
    assert "[UninstallDelete] Name={app}\\*.db" in capsys.readouterr().out


# ------------------------------------------------------------------------------------------------
# CI workflow
# ------------------------------------------------------------------------------------------------
WORKFLOW_TEXT = WORKFLOW_PATH.read_text(encoding="utf-8")


def _step_index(steps, predicate, description):
    matches = [i for i, step in enumerate(steps) if predicate(step)]
    assert matches, f"workflow has no step that {description}"
    return matches[0]


def _run(step) -> str:
    return str(step.get("run", ""))


def test_workflow_yaml_parses_with_tag_only_trigger():
    yaml = pytest.importorskip("yaml")
    workflow = yaml.safe_load(WORKFLOW_TEXT)
    triggers = workflow.get("on", workflow.get(True))  # YAML 1.1 reads a bare `on` key as True

    assert set(triggers) == {"push", "workflow_dispatch"}
    assert "branches" not in triggers["push"], "a push to main must not publish a release"
    assert triggers["push"]["tags"] == ["v*"]


def test_workflow_guard_runs_before_the_installer_build():
    yaml = pytest.importorskip("yaml")
    jobs = yaml.safe_load(WORKFLOW_TEXT)["jobs"]
    steps = jobs["build-and-release"]["steps"]

    iss_guard = _step_index(steps, lambda s: "bundle_guard.py" in _run(s) and "--iss" in _run(s), "guards the .iss")
    package = _step_index(steps, lambda s: "package_production.py" in _run(s), "runs package_production.py")
    staged_guard = _step_index(
        steps, lambda s: "bundle_guard.py" in _run(s) and "--dir dist/Sorour_Logistics_Standalone" in _run(s),
        "guards the staged bundle",
    )
    inno_install = _step_index(steps, lambda s: "choco install innosetup" in _run(s), "installs Inno Setup")
    iscc = _step_index(steps, lambda s: "ISCC.exe" in _run(s), "compiles the installer")

    assert iss_guard < package < staged_guard < inno_install < iscc
    assert "--zip" in _run(steps[staged_guard])

    # Anything that uploads or publishes happens after the installer is built: later in the same job,
    # or in a job that needs the build job.
    def publishes(step) -> bool:
        uses = str(step.get("uses", ""))
        return any(name in uses for name in ("upload-artifact", "action-gh-release"))

    first_publish = [i for i, s in enumerate(steps) if publishes(s)]
    assert all(i > iscc for i in first_publish)
    for name, job in jobs.items():
        if name == "build-and-release":
            continue
        needs = job.get("needs", [])
        needs = [needs] if isinstance(needs, str) else list(needs)
        assert "build-and-release" in needs, f"job {name} does not wait for the guarded build"

    release_jobs = [n for n, j in jobs.items() if any("action-gh-release" in str(s.get("uses", "")) for s in j.get("steps", []))]
    assert release_jobs and "build-and-release" not in release_jobs, "the GitHub Release must be its own job"


def test_workflow_packages_without_bumping_the_version():
    runs = re.findall(r"python package_production\.py[^\r\n]*", WORKFLOW_TEXT)

    assert runs, "package_production.py is not run"
    assert all("--no-bump" in run for run in runs)
    assert "--preserve-data" not in WORKFLOW_TEXT
    assert "--keep-operational-data" not in WORKFLOW_TEXT


def test_workflow_trigger_block_has_no_branch_push_text_check():
    """Same trigger rule without PyYAML (runs everywhere)."""
    on_block = WORKFLOW_TEXT.split("\non:", 1)[1].split("\npermissions:", 1)[0]

    assert "branches" not in on_block
    assert "- 'v*'" in on_block
    assert "workflow_dispatch" in on_block
