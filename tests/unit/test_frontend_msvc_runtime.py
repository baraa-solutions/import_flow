"""
frontend.exe must ship the MSVC runtime app-local.

A clean Windows (no Visual C++ Redistributable, e.g. Windows Sandbox) refused to start frontend.exe with
"MSVCP140.dll was not found", so backend.exe was never launched either. frontend/windows/CMakeLists.txt
installs the CRT of the building toolset (InstallRequiredSystemLibraries) next to frontend.exe and fails
the build when msvcp140 / vcruntime140 / vcruntime140_1 can't be found.

The build output is not in git, so the rule is checked statically; when a local Release build exists it is
also checked for the DLLs.
"""
import re
from pathlib import Path

import pytest

PROJECT_DIR = Path(__file__).resolve().parents[2]
CMAKE_PATH = PROJECT_DIR / "frontend" / "windows" / "CMakeLists.txt"
CMAKE_TEXT = CMAKE_PATH.read_text(encoding="utf-8")
RELEASE_DIR = PROJECT_DIR / "frontend" / "build" / "windows" / "x64" / "runner" / "Release"
REQUIRED_DLLS = ("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")


def _code_lines() -> str:
    """CMake text without comments."""
    return "\n".join(line.split("#", 1)[0] for line in CMAKE_TEXT.splitlines())


def test_system_runtime_libraries_are_collected():
    code = _code_lines()
    assert re.search(r"include\(\s*InstallRequiredSystemLibraries\s*\)", code), \
        "include(InstallRequiredSystemLibraries) missing"
    # Collect only; our own install() below decides the destination.
    assert re.search(r"set\(\s*CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP\s+TRUE\s*\)", code)
    skip_at = code.index("CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP")
    include_at = code.index("InstallRequiredSystemLibraries)")
    assert skip_at < include_at, "the SKIP flag must be set before the include"


def test_runtime_libs_are_installed_next_to_the_executable():
    code = _code_lines()
    m = re.search(
        r"install\(\s*PROGRAMS\s+\$\{CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS\}\s+"
        r"DESTINATION\s+\"\$\{CMAKE_INSTALL_PREFIX\}\"",
        code,
    )
    assert m, "install(PROGRAMS ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS} DESTINATION \"${CMAKE_INSTALL_PREFIX}\") missing"
    # Same component as frontend.exe so `flutter build windows` runs it, and not limited to Debug.
    tail = code[m.start(): code.index(")", m.end()) + 1]
    assert "COMPONENT Runtime" in tail
    assert "CONFIGURATIONS" not in tail or "Release" in tail


def test_build_fails_when_a_required_dll_is_missing():
    code = _code_lines()
    for dll in REQUIRED_DLLS:
        assert dll in code, f"{dll} is not in the required-runtime guard"
    assert "FATAL_ERROR" in code[code.index("_REQUIRED_MSVC_RUNTIME"):], \
        "a missing runtime DLL must fail the build, not ship a broken app"


def test_ucrt_is_not_bundled():
    # The Universal CRT is part of Windows 10+; bundling it is unnecessary.
    assert re.search(r"set\(\s*CMAKE_INSTALL_UCRT_LIBRARIES\s+FALSE\s*\)", _code_lines())


@pytest.mark.skipif(not (RELEASE_DIR / "frontend.exe").exists(), reason="no local Release build")
def test_local_release_build_contains_the_runtime():
    present = {p.name.lower() for p in RELEASE_DIR.iterdir()}
    missing = [dll for dll in REQUIRED_DLLS if dll not in present]
    assert not missing, f"{RELEASE_DIR} lacks {missing}; rebuild with `flutter build windows --release`"
