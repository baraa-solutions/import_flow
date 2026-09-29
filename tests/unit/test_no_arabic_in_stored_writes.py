"""
Single-language storage, Phase C: backend ratchet against Arabic text flowing into STORED writes.

The database stores system text in English (plus a message code / enum code); Arabic is a display concern
of the Flutter client. This AST scan finds Arabic string expressions (``Constant`` and f-strings, one hit
per string expression) that reach a stored write in the backend write paths:

  S1 an ORM model constructor keyword (``SmartTask(title=...)``, any column)
  S2 a keyword named like a stored text field (``STORED_FIELDS``) on any other call
     (``create_task(notes=...)``, ``SmartTaskCreate(title=...)``, ``save_or_update_activity(notes=...)``)
  S3 an attribute assignment / ``+=`` / ``setattr`` on an ORM column or stored field (``rec.notes = ...``),
     and ``row["notes"] = ...`` subscript assignments
  S4 a dict literal value under a stored-field key (repository create/update dicts, JSON columns,
     ``**payload``), or under an ORM column attribute key (``query.update({Model.notes: ...})``)
  S5 ``Column(default= / server_default= / onupdate=)`` and ``mapped_column(...)``

Values are followed through local variables of the same function and module-level constants. Calls are
opaque except string building (``str``, ``.format``, ``.join``, ``.upper`` ...) and ``dict.get`` defaults.

Not flagged (not stored):
- anything inside ``raise`` / ``assert`` / ``HTTPException`` / logger / ``print`` / ``*Error(...)``;
- response-only Pydantic models (any ``BaseModel`` subclass whose name is not a request/input name, see
  ``INPUT_SCHEMA_SUFFIXES``), FastAPI route decorators (``summary=``) and ``Field(description=)``;
- dict literals that only end up returned or inside response models (followed through local names,
  ``.append`` and list literals);
- keys ending with ``_ar`` and ``RESPONSE_ONLY_KEYS``;
- literals used for matching legacy rows (comparisons, ``in``, ``like/ilike/contains/startswith/...``, the
  ``old`` argument of ``replace``, dict/subscript lookup keys, ``if`` tests); comments and docstrings.

Ratchet: ``tests/unit/fixtures/arabic_stored_writes_baseline.json`` holds per-file counts that may only go
down. A file that grows, a new file, or a file that shrank without lowering the baseline fails. Regenerate
after a real fix:  UPDATE_STORED_ARABIC_BASELINE=1 python -m pytest tests/unit/test_no_arabic_in_stored_writes.py
Print the current sites:  python tests/unit/test_no_arabic_in_stored_writes.py

Also here: every ``msg("CODE")`` / ``SysMsg("CODE")`` / ``render_en("CODE")`` / ``msg_code="CODE"`` literal in
the backend codebase names a code of the catalog.
"""
from __future__ import annotations

import ast
import json
import os
import re
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterator, List, Optional, Set, Tuple

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:  # allows `python tests/unit/test_no_arabic_in_stored_writes.py`
    sys.path.insert(0, str(ROOT))

from modules.common.system_messages import CATALOG  # noqa: E402

BASELINE_PATH = ROOT / "tests" / "unit" / "fixtures" / "arabic_stored_writes_baseline.json"
UPDATE_ENV = "UPDATE_STORED_ARABIC_BASELINE"

ARABIC = re.compile("[؀-ۿ]")

STORED_FIELDS = frozenset({
    "notes", "title", "description", "message", "content", "next_action", "current_stage", "current_module",
    "custom_stage_title", "custom_module_name", "custom_next_action", "hold_reason", "hold_notes",
    "evidence_summary", "reason_why", "remarks", "status", "default", "body", "comment", "comments",
    "stage_name", "phase_name", "task_name", "category", "summary", "reason", "action", "details",
    "commercial_notes", "savings_notes", "last_sync_message", "completion_notes", "rejection_reason",
})

# Response-only keys that share a stored-field name. Keep this list short and justified.
RESPONSE_ONLY_KEYS: frozenset = frozenset()

# Pydantic models with these name endings carry client input that services store.
INPUT_SCHEMA_SUFFIXES = ("Create", "Update", "Request", "Payload", "Input", "In", "Upsert", "Patch", "Base")

EXTRA_SCOPE = (
    "database/master_data_sync_service.py",
    "modules/notifications/expiry_checker.py",
    "modules/experience_guide/autonomous_engine.py",
    "modules/import_documentation/ai_document_parser.py",  # comparison matrices stored as JSON
    "modules/customs_tariff/nafeza_text_parser.py",
)
EXTRA_SCOPE_DIRS = ("modules/system_observability", "modules/smart_email_listener")
MODULE_FILE_NAMES = ("service.py", "repository.py", "model.py")

LOGGER_METHODS = frozenset({"debug", "info", "warning", "error", "exception", "critical", "log", "warn"})
LOGGER_NAMES = frozenset({"logger", "logging", "log", "_logger", "LOGGER", "_log", "warnings"})
NON_STORED_CALLEES = frozenset({
    "HTTPException", "print", "JSONResponse", "PlainTextResponse", "HTMLResponse", "StreamingResponse",
    "FileResponse", "Response",
})
ROUTE_DECORATORS = frozenset({"get", "post", "put", "patch", "delete", "api_route", "websocket", "head", "options"})
FIELD_FACTORIES = frozenset({"Field", "Query", "Path", "Body", "Header", "Form", "File", "Cookie"})
# Methods whose (first) argument is a pattern / needle, not output.
MATCH_METHODS = frozenset({
    "like", "ilike", "notlike", "notilike", "contains", "startswith", "endswith", "in_", "notin_", "not_in",
    "find", "rfind", "index", "rindex", "count", "split", "rsplit", "partition", "rpartition", "match",
    "search", "fullmatch", "sub", "subn", "findall", "finditer", "compile", "op", "is_", "isnot",
})
# Calls whose result is built from their receiver and arguments (everything else is opaque).
STRING_BUILDERS = frozenset({
    "str", "format", "join", "upper", "lower", "title", "capitalize", "strip", "lstrip", "rstrip",
    "removeprefix", "removesuffix", "ljust", "rjust", "center", "zfill", "casefold", "swapcase", "f",
})
COLUMN_FACTORIES = frozenset({"Column", "mapped_column"})
COLUMN_DEFAULT_KWARGS = frozenset({"default", "server_default", "onupdate", "server_onupdate"})
CONTAINERS = (ast.List, ast.Tuple, ast.Set, ast.Starred)


# --------------------------------------------------------------------------------------------- scope
def scanned_files() -> List[Path]:
    files: Set[Path] = set()
    for name in MODULE_FILE_NAMES:
        files.update(p for p in (ROOT / "modules").rglob(name) if "__pycache__" not in p.parts)
    for rel in EXTRA_SCOPE:
        files.add(ROOT / rel)
    for rel in EXTRA_SCOPE_DIRS:
        files.update((ROOT / rel).glob("*.py"))
    return sorted(p for p in files if p.is_file())


def _rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def _parse(path: Path) -> ast.Module:
    return ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))


def _callee_name(func: ast.AST) -> Optional[str]:
    if isinstance(func, ast.Name):
        return func.id
    if isinstance(func, ast.Attribute):
        return func.attr
    if isinstance(func, ast.Call):
        return _callee_name(func.func)
    return None


# ----------------------------------------------------------------------------------------- class index
@dataclass(frozen=True)
class ClassIndex:
    models: frozenset        # SQLAlchemy ORM classes
    columns: frozenset       # their column attribute names
    schemas: frozenset       # Pydantic BaseModel subclasses
    json_columns: frozenset = frozenset()  # names of JSON columns (payload dicts nested under them are stored)

    def is_response_schema(self, name: Optional[str]) -> bool:
        return bool(name) and name in self.schemas and not name.endswith(INPUT_SCHEMA_SUFFIXES)


@lru_cache(maxsize=1)
def class_index() -> ClassIndex:
    classes: Dict[str, Tuple[List[str], List[str], List[str]]] = {}
    for base_dir in ("modules", "database"):
        for path in (ROOT / base_dir).rglob("*.py"):
            if "__pycache__" in path.parts:
                continue
            try:
                tree = _parse(path)
            except SyntaxError:
                continue
            for node in ast.walk(tree):
                if not isinstance(node, ast.ClassDef):
                    continue
                columns, json_columns = [], []
                for stmt in node.body:
                    target, value = None, None
                    if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1:
                        target, value = stmt.targets[0], stmt.value
                    elif isinstance(stmt, ast.AnnAssign):
                        target, value = stmt.target, stmt.value
                    if isinstance(target, ast.Name) and isinstance(value, ast.Call):
                        if _callee_name(value.func) in COLUMN_FACTORIES:
                            columns.append(target.id)
                            if any(_callee_name(n) == "JSON" for n in ast.walk(value) if isinstance(n, (ast.Name, ast.Attribute))):
                                json_columns.append(target.id)
                bases = [_callee_name(b) or "" for b in node.bases]
                old = classes.get(node.name, ([], [], []))
                classes[node.name] = (old[0] + bases, old[1] + columns, old[2] + json_columns)

    def closure(roots: Set[str]) -> Set[str]:
        found: Set[str] = set()
        changed = True
        while changed:
            changed = False
            for name, (bases, _, _) in classes.items():
                if name not in found and any(b in roots or b in found for b in bases):
                    found.add(name)
                    changed = True
        return found

    models = closure({"Base", "DeclarativeBase"})
    schemas = closure({"BaseModel"}) - models
    columns = {c for name in models for c in classes[name][1]}
    json_columns = {c for name in models for c in classes[name][2]}
    return ClassIndex(frozenset(models), frozenset(columns), frozenset(schemas), frozenset(json_columns))


# ------------------------------------------------------------------------------------------- scanner
def _is_arabic_str(node: ast.AST) -> bool:
    return isinstance(node, ast.Constant) and isinstance(node.value, str) and bool(ARABIC.search(node.value))


def _is_non_stored_call(call: ast.Call, index: ClassIndex) -> bool:
    name = _callee_name(call.func)
    if name is None:
        return False
    if name in NON_STORED_CALLEES or name.endswith(("Error", "Exception", "Warning")):
        return True
    if index.is_response_schema(name):
        return True
    if isinstance(call.func, ast.Attribute):
        receiver = call.func.value
        receiver_name = (receiver.id if isinstance(receiver, ast.Name) else _callee_name(receiver)) or ""
        if name in LOGGER_METHODS and (receiver_name in LOGGER_NAMES or receiver_name.lower().endswith("logger")):
            return True
        if name in ROUTE_DECORATORS and ("router" in receiver_name.lower() or receiver_name == "app"):
            return True
    return False


@dataclass(frozen=True)
class Finding:
    file: str
    line: int
    col: int
    sink: str
    text: str

    def __str__(self) -> str:
        return f"{self.file}:{self.line} [{self.sink}] {self.text[:100]!r}"


class FileScanner:
    def __init__(self, source: str, rel: str, index: Optional[ClassIndex] = None):
        self.rel = rel
        self.tree = ast.parse(source)
        self.index = index or class_index()
        self.parents: Dict[int, ast.AST] = {}
        for node in ast.walk(self.tree):
            for child in ast.iter_child_nodes(node):
                self.parents[id(child)] = node
        self.excluded: Set[int] = set()
        for node in ast.walk(self.tree):
            if isinstance(node, (ast.Raise, ast.Assert)) or (
                isinstance(node, ast.Call) and _is_non_stored_call(node, self.index)
            ):
                self.excluded.update(id(n) for n in ast.walk(node))
        self.module_names = self._assignments(
            [s for s in self.tree.body if not isinstance(s, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))]
        )
        self._function_cache: Dict[int, Dict[str, List[ast.AST]]] = {}
        self.findings: Dict[Tuple[int, int], Finding] = {}

    # -- name resolution --------------------------------------------------------------------------------
    @staticmethod
    def _assignments(statements) -> Dict[str, List[ast.AST]]:
        names: Dict[str, List[ast.AST]] = {}
        for statement in statements:
            for node in ast.walk(statement):
                if isinstance(node, ast.Assign):
                    for target in node.targets:
                        if isinstance(target, ast.Name):
                            names.setdefault(target.id, []).append(node.value)
                elif isinstance(node, (ast.AnnAssign, ast.AugAssign)) and isinstance(node.target, ast.Name):
                    if node.value is not None:
                        names.setdefault(node.target.id, []).append(node.value)
                elif isinstance(node, ast.NamedExpr):
                    names.setdefault(node.target.id, []).append(node.value)
        return names

    def _enclosing_function(self, node: ast.AST) -> Optional[ast.AST]:
        current = self.parents.get(id(node))
        while current is not None:
            if isinstance(current, (ast.FunctionDef, ast.AsyncFunctionDef)):
                return current
            current = self.parents.get(id(current))
        return None

    def _function_names(self, func: ast.AST) -> Dict[str, List[ast.AST]]:
        if id(func) not in self._function_cache:
            self._function_cache[id(func)] = self._assignments(func.body)
        return self._function_cache[id(func)]

    def _resolve(self, name: ast.Name) -> List[ast.AST]:
        func = self._enclosing_function(name)
        candidates = self._function_names(func).get(name.id, []) if func is not None else []
        return candidates or self.module_names.get(name.id, [])

    # -- literal collection (forward flow) --------------------------------------------------------------
    def _literals(self, expr: Optional[ast.AST], depth: int = 0, seen: Optional[Set[int]] = None) -> Iterator[ast.AST]:
        """Arabic string expressions whose text ends up in the value of ``expr``."""
        seen = set() if seen is None else seen
        if expr is None or id(expr) in seen or depth > 6 or id(expr) in self.excluded:
            return
        seen.add(id(expr))
        if _is_arabic_str(expr):
            yield expr
        elif isinstance(expr, ast.JoinedStr):
            if any(_is_arabic_str(v) for v in expr.values):
                yield expr
            for value in expr.values:
                if isinstance(value, ast.FormattedValue):
                    yield from self._literals(value.value, depth, seen)
        elif isinstance(expr, ast.Name):
            for value in self._resolve(expr):
                yield from self._literals(value, depth + 1, seen)
        elif isinstance(expr, ast.Subscript):
            yield from self._literals(expr.value, depth, seen)  # the slice is a lookup key
        elif isinstance(expr, ast.IfExp):
            yield from self._literals(expr.body, depth, seen)
            yield from self._literals(expr.orelse, depth, seen)
        elif isinstance(expr, (ast.BoolOp, ast.BinOp)):
            for child in (expr.values if isinstance(expr, ast.BoolOp) else (expr.left, expr.right)):
                yield from self._literals(child, depth, seen)
        elif isinstance(expr, (ast.List, ast.Tuple, ast.Set)):
            for child in expr.elts:
                yield from self._literals(child, depth, seen)
        elif isinstance(expr, ast.Starred):
            yield from self._literals(expr.value, depth, seen)
        elif isinstance(expr, (ast.ListComp, ast.SetComp, ast.GeneratorExp)):
            yield from self._literals(expr.elt, depth, seen)
        elif isinstance(expr, ast.DictComp):
            yield from self._literals(expr.value, depth, seen)
        elif isinstance(expr, ast.Dict):
            for key, value in zip(expr.keys, expr.values):
                if not (isinstance(key, ast.Constant) and isinstance(key.value, str) and _is_response_only_key(key.value)):
                    yield from self._literals(value, depth, seen)
        elif isinstance(expr, ast.Call):
            yield from self._call_literals(expr, depth, seen)
        # Compare / UnaryOp / Attribute / Lambda / Constant(non-Arabic): no stored text

    def _call_literals(self, call: ast.Call, depth: int, seen: Set[int]) -> Iterator[ast.AST]:
        name = _callee_name(call.func)
        receiver = call.func.value if isinstance(call.func, ast.Attribute) else None
        if name in ("get", "setdefault", "pop") and receiver is not None:
            yield from self._literals(receiver, depth, seen)  # dict values are output, keys are not
            for arg in call.args[1:]:
                yield from self._literals(arg, depth, seen)
        elif name == "replace" and receiver is not None:
            yield from self._literals(receiver, depth, seen)
            for arg in call.args[1:2]:  # args[0] is the needle
                yield from self._literals(arg, depth, seen)
        elif name in STRING_BUILDERS:
            if receiver is not None:
                yield from self._literals(receiver, depth, seen)
            for arg in list(call.args) + [kw.value for kw in call.keywords]:
                yield from self._literals(arg, depth, seen)

    def _flag(self, sink: str, expr: ast.AST) -> None:
        for literal in self._literals(expr):
            key = (literal.lineno, literal.col_offset)
            if key not in self.findings:
                text = literal.value if isinstance(literal, ast.Constant) else "".join(
                    v.value if isinstance(v, ast.Constant) else "{}" for v in literal.values
                )
                self.findings[key] = Finding(self.rel, literal.lineno, literal.col_offset, sink, str(text))

    # -- destination of a dict literal (backward flow) --------------------------------------------------
    def _only_reaches_responses(self, node: ast.AST, depth: int = 0) -> bool:
        """True when the value of ``node`` is only returned / handed to response models (never stored)."""
        if depth > 4:
            return False
        current = node
        while True:
            parent = self.parents.get(id(current))
            if isinstance(parent, ast.Dict) and current in parent.values:
                key = parent.keys[parent.values.index(current)]
                if isinstance(key, ast.Constant) and key.value in self.index.json_columns:
                    return False  # a payload nested under a JSON column name is a row being built
                current = parent
            elif isinstance(parent, CONTAINERS):
                current = parent
            elif isinstance(parent, (ast.ListComp, ast.GeneratorExp)) and current is parent.elt:
                current = parent
            elif isinstance(parent, ast.keyword):
                current = parent
            else:
                break
        if parent is None:
            return False
        if isinstance(parent, (ast.Return, ast.Yield)):
            return True
        if id(parent) in self.excluded:
            return True
        if isinstance(parent, ast.Call):
            if _is_non_stored_call(parent, self.index):
                return True
            name = _callee_name(parent.func)
            if name in ("append", "extend", "insert") and isinstance(parent.func, ast.Attribute):
                target = parent.func.value
                if isinstance(target, ast.Name):
                    return self._name_only_reaches_responses(target.id, parent, depth + 1)
            return False
        if isinstance(parent, (ast.Assign, ast.AnnAssign)) and current is parent.value:
            targets = parent.targets if isinstance(parent, ast.Assign) else [parent.target]
            if all(isinstance(t, ast.Name) for t in targets):
                return all(self._name_only_reaches_responses(t.id, parent, depth + 1) for t in targets)
        return False

    def _name_only_reaches_responses(self, name: str, anchor: ast.AST, depth: int) -> bool:
        func = self._enclosing_function(anchor)
        if func is None:
            return False
        for node in ast.walk(func):
            if not (isinstance(node, ast.Name) and node.id == name and isinstance(node.ctx, ast.Load)):
                continue
            parent = self.parents.get(id(node))
            if isinstance(parent, (ast.Attribute, ast.Subscript)) and node is parent.value:
                # x.get(...), x["k"], len(x) style reads do not move the dict into storage,
                # but x["k"] = ... / x.attr = ... writes into it and does not move it either.
                continue
            if isinstance(parent, (ast.Compare, ast.comprehension, ast.For, ast.If, ast.While, ast.BoolOp, ast.UnaryOp)):
                continue
            if isinstance(parent, ast.Call) and _callee_name(parent.func) in ("len", "bool", "sum", "sorted", "any", "all", "enumerate"):
                continue
            if not self._only_reaches_responses(node, depth):
                return False
        return True

    # -- sinks ----------------------------------------------------------------------------------------------
    def scan(self) -> List[Finding]:
        for node in ast.walk(self.tree):
            if id(node) in self.excluded:
                continue
            if isinstance(node, ast.Call):
                self._scan_call(node)
            elif isinstance(node, (ast.Assign, ast.AugAssign, ast.AnnAssign)):
                self._scan_assign(node)
            elif isinstance(node, ast.Dict):
                self._scan_dict(node)
        return sorted(self.findings.values(), key=lambda f: (f.line, f.col))

    def _scan_call(self, call: ast.Call) -> None:
        name = _callee_name(call.func)
        if name in COLUMN_FACTORIES:
            for kw in call.keywords:
                if kw.arg in COLUMN_DEFAULT_KWARGS:
                    self._flag("S5 column default", kw.value)
        elif name in self.index.models:
            for kw in call.keywords:
                if kw.arg and not _is_response_only_key(kw.arg):
                    self._flag(f"S1 {name}({kw.arg}=)", kw.value)
        elif name == "setattr" and len(call.args) == 3:
            attr = call.args[1]
            if isinstance(attr, ast.Constant) and isinstance(attr.value, str) and self._stored_attr(attr.value):
                self._flag(f"S3 setattr {attr.value}", call.args[2])
        elif name in FIELD_FACTORIES:
            for kw in call.keywords:
                if kw.arg == "default":
                    self._flag(f"S2 {name}(default=)", kw.value)
            if call.args:
                self._flag(f"S2 {name}(default)", call.args[0])
        else:
            for kw in call.keywords:
                if _is_stored_key(kw.arg):
                    self._flag(f"S2 {name}({kw.arg}=)", kw.value)

    def _stored_attr(self, attr: str) -> bool:
        return not _is_response_only_key(attr) and (attr in self.index.columns or attr in STORED_FIELDS)

    def _scan_assign(self, node: ast.AST) -> None:
        if node.value is None:
            return
        targets = node.targets if isinstance(node, ast.Assign) else [node.target]
        for target in targets:
            if isinstance(target, ast.Attribute):
                owner = target.value
                if isinstance(owner, ast.Name) and owner.id in ("self", "cls"):
                    continue
                if self._stored_attr(target.attr):
                    self._flag(f"S3 .{target.attr} =", node.value)
            elif isinstance(target, ast.Subscript):
                key = target.slice
                if isinstance(key, ast.Constant) and isinstance(key.value, str) and _is_stored_key(key.value):
                    if not (isinstance(target.value, ast.Name) and self._name_only_reaches_responses(target.value.id, node, 0)):
                        self._flag(f"S3 [{key.value!r}] =", node.value)

    def _scan_dict(self, node: ast.Dict) -> None:
        stored_items = []
        for key, value in zip(node.keys, node.values):
            if isinstance(key, ast.Constant) and isinstance(key.value, str) and _is_stored_key(key.value):
                stored_items.append((f"S4 {{{key.value!r}: }}", value))
            elif isinstance(key, ast.Attribute) and key.attr in self.index.columns:
                stored_items.append((f"S4 {{.{key.attr}: }}", value))
        if not stored_items or self._only_reaches_responses(node):
            return
        for sink, value in stored_items:
            self._flag(sink, value)


def _is_response_only_key(key: Optional[str]) -> bool:
    return bool(key) and (key.endswith("_ar") or key in RESPONSE_ONLY_KEYS)


def _is_stored_key(key: Optional[str]) -> bool:
    return bool(key) and key in STORED_FIELDS and not _is_response_only_key(key)


def scan_file(path: Path) -> List[Finding]:
    return FileScanner(path.read_text(encoding="utf-8-sig"), _rel(path)).scan()


def current_findings() -> Dict[str, List[Finding]]:
    result: Dict[str, List[Finding]] = {}
    for path in scanned_files():
        findings = scan_file(path)
        if findings:
            result[_rel(path)] = findings
    return result


def _load_baseline() -> Dict[str, int]:
    if not BASELINE_PATH.exists():
        return {}
    return json.loads(BASELINE_PATH.read_text(encoding="utf-8"))


def _write_baseline(counts: Dict[str, int]) -> None:
    BASELINE_PATH.parent.mkdir(parents=True, exist_ok=True)
    BASELINE_PATH.write_text(json.dumps(dict(sorted(counts.items())), indent=2) + "\n", encoding="utf-8")


# ------------------------------------------------------------------------------------------------ tests
def test_stored_arabic_writes_only_go_down():
    findings = current_findings()
    counts = {path: len(items) for path, items in findings.items()}
    if os.environ.get(UPDATE_ENV) == "1":
        _write_baseline(counts)
        return
    baseline = _load_baseline()
    problems = []
    for path, count in sorted(counts.items()):
        allowed = baseline.get(path)
        sites = "\n    ".join(str(f) for f in findings[path])
        if allowed is None:
            problems.append(f"{path}: NEW file with stored Arabic ({count}). Store English / a message code:\n    {sites}")
        elif count > allowed:
            problems.append(f"{path}: {count} > baseline {allowed}. Store English / a message code:\n    {sites}")
        elif count < allowed:
            problems.append(f"{path}: {count} < baseline {allowed}. Lower the baseline ({UPDATE_ENV}=1).")
    for path, allowed in sorted(baseline.items()):
        if path not in counts:
            problems.append(f"{path}: 0 < baseline {allowed}. Lower the baseline ({UPDATE_ENV}=1).")
    assert not problems, "\n".join(problems)


def test_baseline_file_is_well_formed():
    assert BASELINE_PATH.exists(), f"missing {BASELINE_PATH}; run with {UPDATE_ENV}=1"
    scope = {_rel(p) for p in scanned_files()}
    for path, count in _load_baseline().items():
        assert path in scope, f"baseline entry outside the scanned scope: {path}"
        assert isinstance(count, int) and count > 0, (path, count)


def test_scope_and_class_index_cover_the_planned_files():
    scope = {_rel(p) for p in scanned_files()}
    for rel in EXTRA_SCOPE + (
        "modules/system_observability/alert_dispatcher.py",
        "modules/system_observability/daily_report_service.py",
        "modules/smart_email_listener/service.py",
        "modules/smart_email_listener/repository.py",
        "modules/lifecycle_board/service.py",
        "modules/smart_tasks/repository.py",
        "modules/import_files/model.py",
    ):
        assert rel in scope, rel
    index = class_index()
    assert {"SmartTask", "SystemNotification", "ImportFile", "GuideEntry"} <= index.models
    assert {"notes", "title", "next_action", "current_stage"} <= index.columns
    assert "NotificationCreate" in index.schemas and not index.is_response_schema("NotificationCreate")
    assert index.is_response_schema("DemurrageSimulationResponse")


# --- detector self-test on a synthetic source ------------------------------------------------------------
_AR = "ملاحظة"  # an Arabic word
_SYNTHETIC = f'''
from sqlalchemy import Column, String
from fastapi import HTTPException
import logging
logger = logging.getLogger(__name__)
LEGACY_PREFIX = "{_AR} legacy"
STORED_PREFIX = "{_AR} stored"

class SmartTask(Base):
    title = Column(String, default="{_AR} S5")

def write_paths(db, rec, repo, code):
    db.add(SmartTask(title=f"{_AR} S1 {{code}}"))
    rec.notes = STORED_PREFIX + code
    note = "{_AR} S2 via local"
    repo.save_or_update_activity(db, notes=note)
    repo.create(db, {{"description": "{_AR} S4", "code": code}})
    history = []
    history.append({{"notes": rec.notes or "{_AR} S4 via append"}})
    rec.tracking = history
    rec.remarks = " ".join([code, "{_AR} S3 via join"])

def not_stored(db, rec, code):
    if rec.notes and rec.notes.startswith(LEGACY_PREFIX):
        rec.status = "DONE"
    rows = db.query(SmartTask).filter(SmartTask.title.ilike("%{_AR}%")).all()
    if rec.status in ("{_AR}",):
        pass
    logger.info("{_AR} %s", code)
    if not rows:
        raise HTTPException(status_code=400, detail="{_AR}")
    rec.notes = rec.notes.replace(LEGACY_PREFIX, "Approval")
    rec.status = {{"{_AR}": "COMPLETED"}}.get(rec.status, "OPEN")
    rec.category = normalize("{_AR}")
    items = []
    items.append({{"details": "{_AR} response"}})
    summary = {{"status": "{_AR} response"}}
    return ReportResponse(items=items, summary=summary, message="{_AR}")

def returns_message():
    return {{"message": "{_AR}", "title_ar": "{_AR}"}}
'''


def test_detector_flags_only_the_stored_synthetic_sites():
    index = ClassIndex(
        models=frozenset({"SmartTask"}),
        columns=frozenset({"title", "notes", "status", "tracking", "remarks", "category"}),
        schemas=frozenset({"ReportResponse", "TaskCreate"}),
    )
    findings = FileScanner(_SYNTHETIC, "synthetic.py", index).scan()
    labels = sorted(f.text.split(" ", 1)[1] for f in findings)
    assert labels == sorted([
        "S5", "S1 {}", "stored", "S2 via local", "S4", "S4 via append", "S3 via join",
    ]), [str(f) for f in findings]


# --- sites fixed by Phase C (seeded master data stored in English) ----------------------------------------
def _session_with(tables):
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from sqlalchemy.pool import StaticPool

    from database.database import Base

    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine, tables=[t.__table__ for t in tables])
    return sessionmaker(bind=engine)()


def test_guide_seed_is_english_and_skips_a_legacy_arabic_seed():
    from database import master_data_sync_service as mds
    from modules.experience_guide.model import GuideEntry, GuideEntryScope

    session = _session_with([GuideEntry, GuideEntryScope])
    try:
        assert mds.MasterDataSyncService(session).sync_experience_guide_seeds() == {"added": 1}
        entry = session.query(GuideEntry).one()
        assert entry.title == mds.ACOUSTIC_GUIDE_SEED_TITLE
        assert not ARABIC.search(entry.title + entry.content)
        assert mds.MasterDataSyncService(session).sync_experience_guide_seeds() == {"added": 0}

        entry.title = mds.LEGACY_ACOUSTIC_GUIDE_SEED_TITLE  # a DB seeded by an older version
        session.commit()
        assert mds.MasterDataSyncService(session).sync_experience_guide_seeds() == {"added": 0}
        assert session.query(GuideEntry).count() == 1
    finally:
        session.close()


def test_contractual_incoterm_responsibility_note_is_english():
    from database import master_data_sync_service as mds
    from modules.incoterms.model import CostItem, Incoterm, IncotermResponsibility

    session = _session_with([Incoterm, CostItem, IncotermResponsibility])
    try:
        mds.MasterDataSyncService(session).sync_incoterms()
        notes = {r.notes for r in session.query(IncotermResponsibility).all()}
        assert mds.CONTRACTUAL_RESPONSIBILITY_NOTE in notes
        assert not any(ARABIC.search(n) for n in notes if n)
    finally:
        session.close()


# --- msg() codes across the backend ----------------------------------------------------------------------
MSG_SCAN_DIRS = ("modules", "database", "utils", "scripts", "app")
MSG_FACTORY_NAMES = {"msg", "SysMsg", "render_en"}


def _backend_py_files() -> Iterator[Path]:
    for rel in MSG_SCAN_DIRS:
        base = ROOT / rel
        if base.is_dir():
            yield from (p for p in base.rglob("*.py") if "__pycache__" not in p.parts)
    yield from ROOT.glob("*.py")


def _code_literals(tree: ast.AST) -> Iterator[Tuple[int, str]]:
    aliases = set(MSG_FACTORY_NAMES)
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and (node.module or "").endswith("system_messages"):
            aliases.update(a.asname for a in node.names if a.name in MSG_FACTORY_NAMES and a.asname)
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if _callee_name(node.func) in aliases and node.args:
            first = node.args[0]
            if isinstance(first, ast.Constant) and isinstance(first.value, str):
                yield node.lineno, first.value
        for kw in node.keywords:
            if kw.arg == "msg_code" and isinstance(kw.value, ast.Constant) and isinstance(kw.value.value, str):
                yield node.lineno, kw.value.value


def test_every_message_code_literal_in_the_backend_is_in_the_catalog():
    unknown, total = [], 0
    for path in _backend_py_files():
        try:
            tree = _parse(path)
        except SyntaxError:
            continue
        for line, code in _code_literals(tree):
            total += 1
            if code not in CATALOG:
                unknown.append(f"{_rel(path)}:{line} {code}")
    assert total >= 100, f"expected many message code literals, found {total}"
    assert unknown == []


if __name__ == "__main__":  # print every current site, grouped by file
    sys.stdout.reconfigure(encoding="utf-8")
    grand_total = 0
    for file_path, items in sorted(current_findings().items()):
        grand_total += len(items)
        print(f"== {file_path}: {len(items)}")
        for item in items:
            print(f"   {item.line:>5} {item.sink:<40} {item.text[:90]!r}")
    print("TOTAL", grand_total)
