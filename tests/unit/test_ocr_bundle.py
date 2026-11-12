"""RapidOCR bundled into backend.exe (Trello v9QVwJlh follow-up to PR #222).

Covers the PyInstaller command (RapidOCR models + config, onnxruntime binaries, Arabic rec model), the build-time
release gate, the pinned requirement, frozen (sys._MEIPASS) model path resolution, engine discovery with a mocked
rapidocr_onnxruntime, and the OCR self-check reported by the deep health probe. Tests that need the real RapidOCR
package skip where it is not installed (it has no wheels for Python >= 3.13).
"""

from __future__ import annotations

import importlib.util
import os
import re
import sys
import types
from pathlib import Path

import pytest
import yaml

import build_backend_exe
import modules.import_documentation.arabic_ocr_engine as arabic_engine
import modules.smart_document_upload.ocr_pipeline as pipeline
from modules.system_observability.service import DeepHealthProbeService

RAPIDOCR_INSTALLED = importlib.util.find_spec("rapidocr_onnxruntime") is not None
requires_rapidocr = pytest.mark.skipif(not RAPIDOCR_INSTALLED, reason="rapidocr_onnxruntime is not installed")


def _pairs(cmd, flag):
    return [cmd[i + 1] for i, item in enumerate(cmd) if item == flag]


# ─── PyInstaller command / release gate ───────────────────────────────────────

def test_command_collects_rapidocr_models_and_onnxruntime_binaries():
    cmd = build_backend_exe.build_pyinstaller_command()
    assert "rapidocr_onnxruntime" in _pairs(cmd, "--collect-data")  # det/cls/rec .onnx + config.yaml
    assert "rapidocr_onnxruntime" in _pairs(cmd, "--collect-submodules")
    assert "onnxruntime" in _pairs(cmd, "--collect-binaries")
    hidden = _pairs(cmd, "--hidden-import")
    for module in (
        "rapidocr_onnxruntime",
        "onnxruntime",
        "cv2",
        "bidi.algorithm",
        "modules.smart_document_upload.ocr_pipeline",
        "modules.import_documentation.arabic_ocr_engine",
    ):
        assert module in hidden, module


def test_command_bundles_arabic_rec_model_at_the_frozen_lookup_path():
    cmd = build_backend_exe.build_pyinstaller_command()
    # The build destination and the runtime lookup must stay the same folder.
    assert build_backend_exe.ARABIC_OCR_MODELS_SUBDIR == arabic_engine.ARABIC_OCR_MODELS_BUNDLE_SUBDIR
    bundled = {}
    for spec in _pairs(cmd, "--add-data"):
        source, dest = spec.split(os.pathsep)
        bundled[Path(source).name] = (Path(source), dest)
    for filename in ("rec.onnx", "dict.txt"):
        source, dest = bundled[filename]
        assert dest == arabic_engine.ARABIC_OCR_MODELS_BUNDLE_SUBDIR
        assert source.is_file(), source
    # Only the two model files of that folder are added (never a whole directory that could pick up other data)
    assert bundled["rec.onnx"][0].stat().st_size > 1_000_000


def test_missing_ocr_bundle_inputs_empty_when_everything_is_present(monkeypatch):
    monkeypatch.setattr(build_backend_exe.importlib.util, "find_spec", lambda name: object())
    assert build_backend_exe.missing_ocr_bundle_inputs() == []


def test_build_refuses_to_run_without_rapidocr(monkeypatch):
    real_find_spec = importlib.util.find_spec
    monkeypatch.setattr(
        build_backend_exe.importlib.util,
        "find_spec",
        lambda name: None if name in ("rapidocr_onnxruntime", "onnxruntime") else real_find_spec(name),
    )
    missing = build_backend_exe.missing_ocr_bundle_inputs()
    assert "python package 'rapidocr_onnxruntime'" in missing
    assert "python package 'onnxruntime'" in missing

    def fail_run(*args, **kwargs):
        raise AssertionError("PyInstaller must not run when the OCR bundle is incomplete")

    monkeypatch.setattr(build_backend_exe.subprocess, "run", fail_run)
    assert build_backend_exe.build_backend() is False


def test_build_refuses_to_run_without_arabic_model(monkeypatch, tmp_path):
    monkeypatch.setattr(build_backend_exe.importlib.util, "find_spec", lambda name: object())
    monkeypatch.setattr(build_backend_exe, "ROOT_DIR", tmp_path)
    missing = build_backend_exe.missing_ocr_bundle_inputs()
    assert f"model file {build_backend_exe.ARABIC_OCR_MODELS_SUBDIR}/rec.onnx" in missing
    assert f"model file {build_backend_exe.ARABIC_OCR_MODELS_SUBDIR}/dict.txt" in missing


def test_requirements_pin_rapidocr_for_the_build_interpreter():
    text = (build_backend_exe.ROOT_DIR / "requirements.txt").read_text(encoding="utf-8")
    assert re.search(r'^rapidocr_onnxruntime==\d+\.\d+\.\d+; python_version < "3\.13"$', text, re.M)
    assert re.search(r'^onnxruntime==\d+\.\d+\.\d+; python_version < "3\.13"$', text, re.M)
    # The release build installs requirements.txt on Python 3.12, so the marker selects RapidOCR there.
    workflow = yaml.safe_load(
        (build_backend_exe.ROOT_DIR / ".github" / "workflows" / "build_and_release.yml").read_text(encoding="utf-8")
    )
    steps = workflow["jobs"]["build-and-release"]["steps"]
    python_versions = [s["with"]["python-version"] for s in steps if "setup-python" in str(s.get("uses", ""))]
    assert python_versions == ["3.12"]
    assert any("pip install -r requirements.txt" in str(s.get("run", "")) for s in steps)


# ─── Frozen model path resolution ─────────────────────────────────────────────

def test_models_dir_is_source_tree_when_not_frozen(monkeypatch):
    monkeypatch.delattr(sys, "frozen", raising=False)
    folder = arabic_engine.resolve_arabic_models_dir()
    assert folder == Path(arabic_engine.__file__).resolve().parent / "models" / "arabic_ocr"
    assert arabic_engine.arabic_rec_model_present(folder)


def test_models_dir_resolves_under_meipass_when_frozen(monkeypatch, tmp_path):
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "_MEIPASS", str(tmp_path), raising=False)
    folder = arabic_engine.resolve_arabic_models_dir()
    assert folder == tmp_path / "modules" / "import_documentation" / "models" / "arabic_ocr"
    assert not arabic_engine.arabic_rec_model_present(folder)
    folder.mkdir(parents=True)
    (folder / "rec.onnx").write_bytes(b"onnx")
    (folder / "dict.txt").write_text("a\n", encoding="utf-8")
    assert arabic_engine.arabic_rec_model_present()


# ─── Engine construction & discovery (mocked rapidocr_onnxruntime) ────────────

class _FakeRapidOCR:
    instances: list = []

    def __init__(self, config_path=None, **kwargs):
        self.kwargs = kwargs
        _FakeRapidOCR.instances.append(self)

    def __call__(self, image):
        return [([[0, 0], [10, 0], [10, 10], [0, 10]], "Nile Delta Trading Co", 0.99)], None


@pytest.fixture
def fake_rapidocr(monkeypatch):
    _FakeRapidOCR.instances = []
    module = types.ModuleType("rapidocr_onnxruntime")
    module.RapidOCR = _FakeRapidOCR
    monkeypatch.setitem(sys.modules, "rapidocr_onnxruntime", module)
    monkeypatch.setattr(arabic_engine, "_arabic_ocr_engine", None)
    monkeypatch.setattr(arabic_engine, "_arabic_rec_loaded", False)
    return _FakeRapidOCR


def test_build_engine_uses_arabic_rec_model_and_dictionary(fake_rapidocr):
    engine, arabic = arabic_engine.build_rapidocr_engine()
    assert arabic is True
    assert engine.kwargs["rec_model_path"].endswith("rec.onnx")
    assert engine.kwargs["rec_keys_path"].endswith("dict.txt")
    assert "det_model_path" not in engine.kwargs and "cls_model_path" not in engine.kwargs  # default det / cls


def test_build_engine_falls_back_to_default_models_without_arabic_files(fake_rapidocr, tmp_path):
    engine, arabic = arabic_engine.build_rapidocr_engine(tmp_path)
    assert arabic is False
    assert engine.kwargs == {}


def test_build_engine_uses_legacy_api_when_keywords_unsupported(monkeypatch, fake_rapidocr):
    def no_kwargs(self, config_path=None, **kwargs):
        if kwargs:
            raise TypeError("unexpected keyword")

    monkeypatch.setattr(_FakeRapidOCR, "__init__", no_kwargs)
    legacy = object()
    monkeypatch.setattr(arabic_engine, "_build_legacy_arabic_engine", lambda model, keys: legacy)
    assert arabic_engine.build_rapidocr_engine() == (legacy, True)


def test_pipeline_discovers_rapidocr_first_when_importable(monkeypatch, fake_rapidocr):
    monkeypatch.setattr(pipeline, "find_tesseract_binary", lambda: None)
    assert pipeline.available_ocr_engines() == ["rapidocr"]
    assert arabic_engine.arabic_rec_model_loaded() is True
    from PIL import Image

    text, engine_name = pipeline.run_ocr_on_image(Image.new("L", (40, 40), 255))
    assert engine_name == "rapidocr"
    assert "Nile Delta Trading Co" in text
    assert len(fake_rapidocr.instances) == 1  # singleton: built once


# ─── OCR self-check & deep health ─────────────────────────────────────────────

def _fake_rapidocr_package(root: Path) -> Path:
    package = root / "rapidocr_onnxruntime"
    (package / "models").mkdir(parents=True)
    (package / "models" / "ch_PP-OCRv4_det_infer.onnx").write_bytes(b"onnx")
    (package / "config.yaml").write_text("Global: {}\n", encoding="utf-8")
    return package


def test_self_check_ok_when_bundle_complete(monkeypatch, tmp_path):
    package = _fake_rapidocr_package(tmp_path)
    monkeypatch.setattr(pipeline, "_package_dir", lambda name: str(package) if name == "rapidocr_onnxruntime" else str(tmp_path))
    monkeypatch.setattr(pipeline, "find_tesseract_binary", lambda: None)
    report = pipeline.ocr_self_check()
    assert report["status"] == pipeline.OCR_STATUS_OK
    assert report["engines"] == ["rapidocr"]
    assert report["rapidocr_models_present"] and report["arabic_rec_model_present"]


def test_self_check_partial_when_rapidocr_models_missing(monkeypatch, tmp_path):
    package = tmp_path / "rapidocr_onnxruntime"
    package.mkdir()
    monkeypatch.setattr(pipeline, "_package_dir", lambda name: str(package))
    monkeypatch.setattr(pipeline, "find_tesseract_binary", lambda: "/usr/bin/tesseract")
    monkeypatch.setattr(pipeline, "_pytesseract_installed", lambda: False)
    report = pipeline.ocr_self_check()
    assert report["status"] == pipeline.OCR_STATUS_PARTIAL
    assert report["engines"] == ["tesseract-cli"]
    assert report["rapidocr_models_present"] is False


def test_self_check_unavailable_without_any_engine(monkeypatch):
    monkeypatch.setattr(pipeline, "_package_dir", lambda name: None)
    monkeypatch.setattr(pipeline, "find_tesseract_binary", lambda: None)
    report = pipeline.ocr_self_check()
    assert report["status"] == pipeline.OCR_STATUS_UNAVAILABLE
    assert report["engines"] == [] and report["rapidocr_installed"] is False


def test_deep_health_flags_incomplete_ocr_bundle_only_when_frozen(monkeypatch):
    monkeypatch.setattr(pipeline, "_package_dir", lambda name: None)
    monkeypatch.setattr(pipeline, "find_tesseract_binary", lambda: None)

    monkeypatch.delattr(sys, "frozen", raising=False)
    issues: list = []
    assert DeepHealthProbeService.check_ocr(issues) == (pipeline.OCR_STATUS_UNAVAILABLE, [])
    assert issues == []  # a dev machine without RapidOCR is not a health issue

    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "_MEIPASS", str(Path(arabic_engine.__file__).resolve().parents[2]), raising=False)
    issues = []
    status, engines = DeepHealthProbeService.check_ocr(issues)
    assert status == pipeline.OCR_STATUS_UNAVAILABLE
    assert len(issues) == 1 and "OCR bundle incomplete" in issues[0]


# ─── Real engine (only where rapidocr_onnxruntime is installed) ───────────────

@requires_rapidocr
def test_real_rapidocr_loads_arabic_recognizer(monkeypatch):
    monkeypatch.setattr(arabic_engine, "_arabic_ocr_engine", None)
    engine, arabic = arabic_engine.build_rapidocr_engine()
    assert arabic is True
    recognizer = getattr(engine, "text_rec", None) or getattr(engine, "text_recognizer", None)
    assert "ب" in recognizer.postprocess_op.character
    assert pipeline.ocr_self_check()["status"] == pipeline.OCR_STATUS_OK
