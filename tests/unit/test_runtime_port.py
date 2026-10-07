"""Backend listen-port resolution (`utils.runtime_port`), its use in backend_runner, and the dev launchers'
port guard (`scripts/check_backend_port.bat`): production backend.exe owns 127.0.0.1:28080 on the same laptop."""
from pathlib import Path

import pytest

import backend_runner as br
from utils.runtime_port import DEFAULT_PORT, InvalidPortError, resolve_port

ROOT = Path(__file__).resolve().parents[2]
LAUNCHERS = ["Launch_Track1_Dev.bat", "run.bat", "Launch_ImportFlow_Desktop.bat", "Launch_SorourLogistics_Live.bat"]
HELPER = "scripts/check_backend_port.bat"
DART_DEFINE = "--dart-define=importflow_server_url=http://127.0.0.1:%port%"


def _code_lines(name):
    """Lower-cased, stripped, non-comment lines of a .bat file."""
    text = (ROOT / name).read_text(encoding="utf-8", errors="replace").lower()
    return [line.strip() for line in text.splitlines()
            if line.strip() and not line.strip().startswith(("::", "rem "))]


# ------------------------------------------------------------------------------------------------
# resolve_port
# ------------------------------------------------------------------------------------------------
@pytest.mark.parametrize("environ", [{}, {"PORT": ""}, {"PORT": "   "}, {"PORT": "\t"}, {"PORT": " \r\n "}])
def test_unset_empty_or_whitespace_is_the_production_default(environ):
    assert DEFAULT_PORT == 28080
    assert resolve_port(environ) == 28080


@pytest.mark.parametrize("raw, expected", [("28090", 28090), (" 28090 ", 28090), ("1", 1), ("65535", 65535)])
def test_valid_override(raw, expected):
    assert resolve_port({"PORT": raw}) == expected


@pytest.mark.parametrize("raw", [
    # non-integer
    "abc", "28090x", "28 090", "-1", "+8080", "8_080", "80.5", "８０",
    # out of range
    "0", "65536", "99999999",
])
def test_invalid_value_fails_fast_naming_port_and_value(raw):
    with pytest.raises(InvalidPortError) as info:
        resolve_port({"PORT": raw})
    message = str(info.value)
    assert "PORT" in message
    assert repr(raw) in message


def test_reads_process_environment_by_default(monkeypatch):
    monkeypatch.setenv("PORT", "28091")
    assert resolve_port() == 28091
    monkeypatch.delenv("PORT")
    assert resolve_port() == 28080


# ------------------------------------------------------------------------------------------------
# backend_runner
# ------------------------------------------------------------------------------------------------
class _Lock:
    def __init__(self):
        self.released = False

    def release(self):
        self.released = True


def test_backend_runner_invalid_port_exits_before_lock_and_main_import(monkeypatch, tmp_path, capsys):
    monkeypatch.setenv("PORT", "65536")
    calls = []

    def lock_factory(app_dir, frozen):
        calls.append("lock")
        return _Lock()

    code = br.run(frozen=False, app_dir=tmp_path, lock_factory=lock_factory,
                  import_app=lambda: calls.append("import") or "APP",
                  serve=lambda app: calls.append("serve"))
    assert code == 2
    assert calls == []  # no lock, no `from main import app` (startup upgrade), no serve
    out = capsys.readouterr().out
    assert "PORT" in out and "'65536'" in out


@pytest.mark.parametrize("env_value, expected", [(None, 28080), ("28092", 28092)])
def test_backend_runner_serves_on_resolved_port(monkeypatch, tmp_path, env_value, expected):
    import uvicorn

    if env_value is None:
        monkeypatch.delenv("PORT", raising=False)
    else:
        monkeypatch.setenv("PORT", env_value)
    seen = {}
    monkeypatch.setattr(uvicorn, "run", lambda app, **kw: seen.update(kw))
    lock = _Lock()
    assert br.run(frozen=False, app_dir=tmp_path, lock_factory=lambda d, f: lock, import_app=lambda: "APP") == 0
    assert seen["port"] == expected
    assert seen["host"] == "127.0.0.1"
    assert lock.released


# ------------------------------------------------------------------------------------------------
# Dev launchers + shared guard
# ------------------------------------------------------------------------------------------------
@pytest.mark.parametrize("name", LAUNCHERS + [HELPER])
def test_backend_port_is_never_killed(name):
    for line in _code_lines(name):
        if "taskkill" in line:
            # run.bat keeps its legacy port-3000 (web dev server) cleanup only
            assert name == "run.bat" and ":3000" in line and "28080" not in line and "%port%" not in line, line


@pytest.mark.parametrize("name", LAUNCHERS)
def test_launcher_uses_port_and_calls_the_guard(name):
    lines = _code_lines(name)
    assert "if not defined port set port=28080" in lines
    assert any(line.startswith("call ") and "scripts\\check_backend_port.bat" in line for line in lines), name
    for line in lines:
        if "uvicorn" in line and "--port" in line:
            assert "--port %port%" in line, line
        # the guard owns the reuse / busy warnings: no copies left in the launchers
        assert "production backend" not in line and "does not answer the health check" not in line, line


@pytest.mark.parametrize("name", LAUNCHERS)
def test_local_flutter_clients_target_the_same_backend_port(name):
    runs = [line for line in _code_lines(name) if "flutter run" in line and not line.startswith("echo ")]
    assert any("flutter run -d windows" in line for line in runs), name
    for line in runs:
        if "--web-hostname 0.0.0.0" in line:
            # LAN web server: browsers on other machines must keep using their own host
            assert "importflow_server_url" not in line, line
        else:
            assert DART_DEFINE in line, line


def test_run_bat_web_mode_refuses_non_default_port_before_starting_anything():
    """The LAN web client has no per-port define (it uses its own host on 28080): on another PORT run.bat
    must stop before the guard call, the backend start and the web server start."""
    lines = _code_lines("run.bat")
    web = lines[lines.index(":launch_web") + 1:]
    web = web[:next(i for i, line in enumerate(web) if line.startswith("exit /b 0"))]
    gate = web.index('if "%port%"=="28080" goto launch_web_backend')
    refuse = web.index("exit /b 1", gate)
    assert any("web / lan mode only supports" in line for line in web[gate:refuse])
    first_action = min(i for i, line in enumerate(web)
                       if line.startswith(("call ", "start ")) or "uvicorn" in line or "flutter run" in line)
    assert gate < refuse < first_action
    assert web[refuse + 1] == ":launch_web_backend"


def test_guard_contract():
    text = (ROOT / HELPER).read_text(encoding="utf-8")
    lines = _code_lines(HELPER)
    assert not any("setlocal" in line for line in lines)  # PORT / USE_RELEASE_EXE must survive the `call`
    assert "!" not in text  # callers run with delayed expansion
    assert 'if not defined port set "port=28080"' in lines
    netstat = [line for line in lines if "netstat" in line]
    assert len(netstat) == 1
    assert 'findstr /c:":%port% "' in netstat[0] and "listening" in netstat[0]
    assert "-p tcp" not in netstat[0]  # `-p tcp` hides IPv6 ([::]:PORT) listeners
    assert any('findstr /c:"sorour logistics erp"' in line for line in lines)
    # The prebuilt Release exe always talks to 28080: the guard enables it only on PORT 28080.
    enable = [i for i, line in enumerate(lines) if 'set "use_release_exe=1"' in line]
    assert len(enable) == 1 and lines[enable[0] - 1] == 'if "%port%"=="28080" ('
    assert text.count("PRODUCTION backend") == 1 and "REAL data" in text and "set PORT=28090" in text
