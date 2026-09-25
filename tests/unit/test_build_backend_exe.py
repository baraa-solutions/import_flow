"""build_backend_exe.build_pyinstaller_command (update-system-phase2-5-spec.md A.6): the Alembic scripts are
bundled for startup migrations, and nothing data-bearing (*.db, .env, .ini) is ever added."""
import os
from pathlib import Path

import build_backend_exe


def _pairs(cmd, flag):
    return [cmd[i + 1] for i, item in enumerate(cmd) if item == flag]


def test_command_bundles_alembic_scripts_and_migration_runner():
    cmd = build_backend_exe.build_pyinstaller_command()
    add_data = _pairs(cmd, "--add-data")
    assert f"{build_backend_exe.ROOT_DIR / 'alembic'}{os.pathsep}alembic" in add_data
    collect = _pairs(cmd, "--collect-submodules")
    assert "alembic" in collect and "mako" in collect
    hidden = _pairs(cmd, "--hidden-import")
    assert "database.migration_runner" in hidden
    assert "database.models" in hidden  # imported by alembic/env.py, which PyInstaller cannot analyse
    assert cmd[-1].endswith("backend_runner.py")


def test_command_adds_no_data_bearing_files():
    cmd = build_backend_exe.build_pyinstaller_command()
    for flag in ("--add-data", "--add-binary"):
        for spec in _pairs(cmd, flag):
            source = Path(spec.split(os.pathsep)[0])
            assert source.suffix.lower() not in (".db", ".env", ".ini"), spec
            assert source.name.lower() not in (".env", "alembic.ini"), spec
            assert not source.name.lower().endswith(".db"), spec
