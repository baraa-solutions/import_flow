"""App-review capture harness for the ImportFlow Flutter WEB build.

Drives the real app in Chromium (Playwright), exactly as a user would:
log in through the login screen, switch the UI to Arabic with the language
toggle, then open every screen listed in docs/app-review/inventory.json by
clicking sidebar / tab / command-palette entries found in the Flutter
semantics (accessibility) tree.

For each screen it writes:
  docs/app-review/screenshots/<NN>-<slug>-<state>.png   (or .jpg, see --format)
  docs/app-review/elements/<NN>-<slug>-<state>.json     (semantics inventory)
and, for the whole run:
  docs/app-review/runtime-errors.json    (console errors, page errors, HTTP >= 400)
  docs/app-review/capture-manifest.json  (status + files + failure reason per screen)

States: main, tab-<n>-<slug>, dialog-add, dialog-add-validation.

Credentials are never stored in the repo: REVIEW_USER / REVIEW_PASSWORD env
vars, or --credentials <json with username/password>.

Usage:
  python scripts/app_review/capture_web.py --credentials <path>
  python scripts/app_review/capture_web.py --only import-companies,customs-clearance
  python scripts/app_review/capture_web.py --group reference
  python scripts/app_review/capture_web.py --base-url http://127.0.0.1:8089   # e.g. a debug build
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sys
import time
import traceback
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

from playwright.async_api import Page, async_playwright

REPO = Path(__file__).resolve().parents[2]
REVIEW_DIR = REPO / "docs" / "app-review"
INVENTORY = REVIEW_DIR / "inventory.json"

VIEWPORT = {"width": 1600, "height": 1000}
SCALE = 1.5
SIZE_LIMIT_BYTES = 100 * 1024 * 1024

# --------------------------------------------------------------------------- #
# Semantics helpers
# --------------------------------------------------------------------------- #

SNAPSHOT_JS = r"""
() => {
  const out = [];
  const vw = window.innerWidth, vh = window.innerHeight;
  document.querySelectorAll('flt-semantics, input, textarea').forEach(e => {
    const r = e.getBoundingClientRect();
    if (r.width <= 0 || r.height <= 0) return;
    let own = '';
    e.childNodes.forEach(c => {
      if (c.nodeType === 3) own += c.textContent;
      else if (c.tagName === 'SPAN') own += c.textContent;
    });
    out.push({
      id: e.id || null,
      tag: e.tagName.toLowerCase(),
      role: e.getAttribute('role') || e.getAttribute('data-semantics-role'),
      aria: e.getAttribute('aria-label'),
      placeholder: e.getAttribute('placeholder'),
      value: (e.tagName === 'INPUT' && e.type !== 'password') || e.tagName === 'TEXTAREA' ? e.value : null,
      input_type: e.tagName === 'INPUT' ? e.type : null,
      text: own.trim(),
      tap: e.hasAttribute('flt-tappable'),
      x: r.x, y: r.y, w: r.width, h: r.height,
      in_view: r.x < vw && r.y < vh && r.x + r.width > 0 && r.y + r.height > 0,
      selected: e.getAttribute('aria-selected'),
      checked: e.getAttribute('aria-checked'),
      disabled: e.getAttribute('aria-disabled'),
      expanded: e.getAttribute('aria-expanded'),
      invalid: e.getAttribute('aria-invalid'),
      required: e.getAttribute('aria-required'),
      tooltip: e.getAttribute('title'),
    });
  });
  return out;
}
"""

_EMOJI_RE = re.compile(
    "[\U0001F000-\U0001FAFF☀-➿️‍←-⇿⬀-⯿]"
)


def norm(s: str | None) -> str:
    """Normalize a label for matching: drop emoji/symbols, unify Arabic forms, collapse spaces."""
    if not s:
        return ""
    s = unicodedata.normalize("NFKC", s)
    s = _EMOJI_RE.sub("", s)
    s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ى", "ي").replace("ة", "ه")
    s = s.replace("ـ", "")
    s = re.sub(r"[\"'“”«»()\[\]{}:：،,.\-–—+*✨↗️]", " ", s)
    s = re.sub(r"\s+", " ", s)
    return s.strip().lower()


def node_label(n: dict) -> str:
    return (n.get("text") or n.get("aria") or "").strip()


def first_line(s: str) -> str:
    return s.split("\n", 1)[0].strip() if s else ""


def is_ar(label: str | None) -> str:
    """Arabic half of an 'ar / en' inventory label."""
    if not label:
        return ""
    return label.split(" / ")[0].strip()


class OffscreenError(RuntimeError):
    pass


class Flutter:
    """Thin driver around a Flutter-web page's semantics tree."""

    def __init__(self, page: Page, settle_ms: int):
        self.page = page
        self.settle_ms = settle_ms
        self.inflight: set = set()
        self.last_net = time.monotonic()

    # ---- network idle tracking (Flutter web never triggers load events after boot)
    def attach_network(self):
        def on_req(r):
            if r.resource_type in ("xhr", "fetch"):
                self.inflight.add(r)
                self.last_net = time.monotonic()

        def on_done(r):
            self.inflight.discard(r)
            self.last_net = time.monotonic()

        self.page.on("request", on_req)
        self.page.on("requestfinished", on_done)
        self.page.on("requestfailed", on_done)

    async def wait_idle(self, timeout_s: float = 20.0, quiet_ms: int = 800):
        t0 = time.monotonic()
        while time.monotonic() - t0 < timeout_s:
            if not self.inflight and (time.monotonic() - self.last_net) * 1000 >= quiet_ms:
                break
            await self.page.wait_for_timeout(150)
        # let progress indicators disappear
        t1 = time.monotonic()
        while time.monotonic() - t1 < 8:
            nodes = await self.snapshot()
            if not any(n["role"] == "progressbar" and n["in_view"] for n in nodes):
                break
            await self.page.wait_for_timeout(300)
        await self.page.wait_for_timeout(self.settle_ms)

    async def enable_semantics(self):
        for _ in range(20):
            ok = await self.page.evaluate(
                "(() => { const p = document.querySelector('flt-semantics-placeholder');"
                " if (p) { p.click(); return true; }"
                " return !!document.querySelector('flt-semantics-host flt-semantics'); })()"
            )
            if ok:
                break
            await self.page.wait_for_timeout(500)
        await self.page.wait_for_timeout(800)

    async def snapshot(self) -> list[dict]:
        try:
            return await self.page.evaluate(SNAPSHOT_JS)
        except Exception:
            return []

    async def find(self, labels, *, tappable=True, region=None, exact_first=True,
                   role=None, nodes=None) -> dict | None:
        """Find the best node whose label matches one of `labels`."""
        if isinstance(labels, str):
            labels = [labels]
        wanted = [norm(l) for l in labels if l]
        wanted = [w for w in wanted if w]
        if not wanted:
            return None
        nodes = nodes if nodes is not None else await self.snapshot()
        cands = []
        for n in nodes:
            if tappable and not (n["tap"] or n["role"] in ("tab", "button", "link", "menuitem", "checkbox", "radio")):
                continue
            if role and n["role"] != role:
                continue
            if region and not region(n):
                continue
            lab = node_label(n)
            full = norm(lab)
            fl = norm(first_line(lab))
            if not full:
                continue
            for w in wanted:
                score = None
                if fl == w or full == w:
                    score = 0
                elif fl.startswith(w) or w.startswith(fl) and len(fl) >= max(6, len(w) * 0.6):
                    score = 1
                elif w in full:
                    score = 2
                elif fl and fl in w and len(fl) >= max(6, len(w) * 0.5):
                    score = 3
                if score is not None:
                    area_pen = 0 if n["in_view"] else 10
                    cands.append((score + area_pen, n["w"] * n["h"], n))
                    break
        if not cands:
            return None
        cands.sort(key=lambda c: (c[0], c[1]))
        return cands[0][2]

    async def click_node(self, n: dict, wait=True):
        W, H = VIEWPORT["width"], VIEWPORT["height"]
        x = n["x"] + n["w"] / 2
        y = n["y"] + n["h"] / 2
        if not (0 <= x < W and 0 <= y < H):
            # scroll the node into view with the mouse wheel over its (clamped) position,
            # vertically and/or horizontally (e.g. horizontally scrolling button bars)
            stuck = 0
            for _ in range(30):
                prev = (x, y)
                dx = 500 if x >= W else (-500 if x < 0 else 0)
                dy = 400 if y >= H else (-400 if y < 0 else 0)
                px = min(max(x, 40), W - 40) if dx == 0 else W / 2
                py = min(max(y, 40), H - 40)
                await self.page.mouse.move(px, py)
                await self.page.mouse.wheel(dx, dy)
                await self.page.wait_for_timeout(200)
                fresh = await self.refind(n)
                if not fresh:
                    break
                n = fresh
                x, y = n["x"] + n["w"] / 2, n["y"] + n["h"] / 2
                if 0 <= x < W and 0 <= y < H:
                    break
                stuck = stuck + 1 if (x, y) == prev else 0
                if stuck >= 3:
                    break
            if not (0 <= x < W and 0 <= y < H):
                raise OffscreenError(
                    f"{first_line(node_label(n))!r} exists in the semantics tree at ({round(x)},{round(y)}) but is "
                    f"outside the {W}x{H} viewport and wheel scrolling does not bring it into view "
                    "(clipped / overflowing layout - a user cannot reach it)")
        await self.page.mouse.click(x, y)
        if wait:
            await self.wait_idle()

    async def find_wait(self, labels, timeout_s: float = 10.0, **kw) -> dict | None:
        t0 = time.monotonic()
        while True:
            n = await self.find(labels, **kw)
            if n or time.monotonic() - t0 > timeout_s:
                return n
            await self.page.wait_for_timeout(500)

    async def refind(self, n: dict) -> dict | None:
        nodes = await self.snapshot()
        for m in nodes:
            if n.get("id") and m.get("id") == n["id"]:
                return m
        return None

    async def click(self, labels, **kw) -> dict | None:
        n = await self.find(labels, **kw)
        if n:
            await self.click_node(n)
        return n

    async def type_into(self, field: dict, text: str, clear=True):
        await self.page.mouse.click(field["x"] + field["w"] / 2, field["y"] + field["h"] / 2)
        await self.page.wait_for_timeout(200)
        if clear:
            await self.clear_focused()
        if text:
            await self.page.keyboard.type(text, delay=35)
            await self.page.wait_for_timeout(150)

    async def focused_value(self):
        return await self.page.evaluate(
            "(() => { const e = document.activeElement;"
            " return e && (e.tagName === 'INPUT' || e.tagName === 'TEXTAREA') ? e.value : null; })()")

    async def clear_focused(self):
        """Clear the focused Flutter text field key by key (Ctrl+A is not reliable on Flutter web)."""
        for _ in range(4):
            v = await self.focused_value()
            if not v:
                return
            await self.page.keyboard.press("End")
            for _ in range(len(v) + 2):
                await self.page.keyboard.press("Backspace")
            await self.page.wait_for_timeout(150)

    async def dialog_open(self) -> bool:
        nodes = await self.snapshot()
        return any(n["role"] in ("dialog", "alertdialog") for n in nodes)

    async def close_overlays(self, max_tries=4):
        for _ in range(max_tries):
            if not await self.dialog_open():
                return True
            await self.page.keyboard.press("Escape")
            await self.page.wait_for_timeout(600)
            if not await self.dialog_open():
                return True
            # Unsaved-changes guard ("تنبيه تعديلات غير محفوظة") pops up over a
            # dirty form: discard, so the next screen starts clean.
            n = await self.find(["تجاهل التعديلات والمتابعة", "تجاهل التعديلات", "Discard changes", "Discard"])
            if n:
                await self.click_node(n, wait=False)
                await self.page.wait_for_timeout(600)
                continue
            n = await self.find(["إلغاء", "إغلاق", "الغاء", "Cancel", "Close"], region=in_dialog_region(await self.snapshot()))
            if n:
                await self.click_node(n, wait=False)
                await self.page.wait_for_timeout(600)
        return not await self.dialog_open()


def in_dialog_region(nodes: list[dict]):
    dlg = [n for n in nodes if n["role"] in ("dialog", "alertdialog")]
    if not dlg:
        return None
    d = max(dlg, key=lambda n: n["y"])  # topmost-last approximation
    d = dlg[-1]

    def inside(n):
        cx, cy = n["x"] + n["w"] / 2, n["y"] + n["h"] / 2
        return d["x"] - 2 <= cx <= d["x"] + d["w"] + 2 and d["y"] - 2 <= cy <= d["y"] + d["h"] + 2

    return inside


# --------------------------------------------------------------------------- #
# Element inventory from the semantics tree
# --------------------------------------------------------------------------- #

def _overlap_x(a: dict, b: dict) -> bool:
    return min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"]) > 10


def build_elements(nodes: list[dict], screen: dict, state: str, file_name: str) -> dict:
    texts, merged, buttons, fields, tabs, headers, checks = [], [], [], [], [], [], []
    seen_text = set()
    vis = [n for n in nodes if n["in_view"]]
    plain = [n for n in vis if n["tag"] not in ("input", "textarea") and not n["tap"]
             and n["role"] not in ("button", "link", "menuitem", "tab", "checkbox", "radio", "switch", "group")
             and node_label(n)]
    for n in vis:
        lab = node_label(n)
        role = n["role"]
        if n["tag"] in ("input", "textarea"):
            parts = [p.strip() for p in (n.get("aria") or "").split("\n") if p.strip()]
            # Flutter drops the floating label into the aria-label; when the label is drawn outside the
            # decoration (custom label widget) look for the text right above / the error text right below.
            above = [t for t in plain if _overlap_x(t, n) and 0 <= n["y"] - (t["y"] + t["h"]) <= 40]
            below = [t for t in plain if _overlap_x(t, n) and 0 <= t["y"] - (n["y"] + n["h"]) <= 30]
            outer_label = node_label(max(above, key=lambda t: t["y"])) if above else ""
            error_text = node_label(min(below, key=lambda t: t["y"])) if below else ""
            label = parts[0] if parts else ""
            hint = n.get("placeholder") or (" | ".join(parts[1:]) if len(parts) > 1 else "")
            fields.append({
                "label": label,
                "label_above": outer_label or None,
                "hint": hint,
                "required": ("*" in (n.get("aria") or "")) or ("*" in outer_label) or n.get("required") == "true",
                "invalid": n.get("invalid") == "true",
                "error_text_below": error_text or None,
                "type": n.get("input_type") or n["tag"],
                "value": n.get("value"),
                "bounds": [round(n["x"]), round(n["y"]), round(n["w"]), round(n["h"])],
            })
            continue
        if role == "tab":
            tabs.append({"label": lab, "selected": n.get("selected") == "true"})
            continue
        if role in ("columnheader",):
            headers.append(lab)
            continue
        if role in ("checkbox", "radio", "switch"):
            checks.append({"label": lab, "role": role, "checked": n.get("checked"),
                           "enabled": n.get("disabled") != "true"})
            continue
        if role in ("button", "link", "menuitem") or n["tap"]:
            lines = [l for l in lab.split("\n") if l.strip()]
            buttons.append({
                "label": lines[0] if lines else "",
                "tooltip": n.get("tooltip") or (" | ".join(lines[1:]) if len(lines) > 1 else None),
                "enabled": n.get("disabled") != "true",
                "icon_only": not lab,
                "bounds": [round(n["x"]), round(n["y"]), round(n["w"]), round(n["h"])],
            })
            continue
        if lab and lab not in seen_text:
            seen_text.add(lab)
            if role == "group" or lab.count("\n") >= 3:
                merged.append(lab)  # container whose semantics merge many descendants
            else:
                texts.append({"text": lab, "role": role} if role else {"text": lab})
    # Table header heuristic (Flutter DataTable/custom tables expose headers as plain texts on one row):
    rows: dict[int, list[dict]] = {}
    for t in plain:
        if "\n" in node_label(t) or len(node_label(t)) > 40:
            continue
        rows.setdefault(round((t["y"] + t["h"] / 2) / 6), []).append(t)
    header_rows = []
    for key in sorted(rows):
        r = sorted(rows[key], key=lambda t: t["x"])
        if len(r) >= 3 and (r[-1]["x"] - r[0]["x"]) > 300:
            header_rows.append({"y": round(r[0]["y"]), "cells_left_to_right": [node_label(t) for t in r]})
    return {
        "screen_nn": screen["nn"],
        "screen_slug": screen["slug"],
        "state": state,
        "screenshot": f"../screenshots/{file_name}",
        "source": "Flutter web semantics tree (flt-semantics / input nodes in viewport)",
        "visible_texts": texts,
        "merged_containers": merged,
        "buttons": buttons,
        "text_fields": fields,
        "tabs": tabs,
        "checkboxes_radios": checks,
        "table_column_headers": headers,
        "table_header_candidates": header_rows[:6],
        "counts": {"texts": len(texts), "buttons": len(buttons), "fields": len(fields),
                   "tabs": len(tabs), "headers": len(headers), "header_rows": len(header_rows)},
    }


# --------------------------------------------------------------------------- #
# Capture run
# --------------------------------------------------------------------------- #

ADD_WORDS = ["إضافة", "اضافة", "إنشاء", "جديد", "جديدة", "تسجيل"]
AI_WORDS = ["الذكاء", "ذكي", "تكويد", "AI"]
SAVE_WORDS = ["حفظ", "حفظ البيانات", "حفظ التغييرات", "إضافة", "إنشاء", "تأكيد", "تسجيل", "إصدار", "Save", "Create", "Submit"]


def slugify(s: str) -> str:
    s = unicodedata.normalize("NFKD", s or "")
    s = re.sub(r"[^A-Za-z0-9]+", "-", s).strip("-").lower()
    return s[:40] or "tab"


def add_dialog_labels(screen: dict) -> list[str]:
    out = []
    for d in screen.get("dialogs", []):
        lab = is_ar(d.get("opens_from_button_label"))
        if not lab:
            continue
        if any(w in lab for w in AI_WORDS):
            continue
        if any(w in lab for w in ADD_WORDS):
            out.append(lab)

    def prio(l):
        for i, w in enumerate(["إضافة", "إنشاء", "جديد", "تسجيل"]):
            if w in l:
                return i
        return 9

    return sorted(dict.fromkeys(out), key=prio)


class Runner:
    def __init__(self, args, inventory):
        self.args = args
        self.inv = inventory
        self.screens_dir = REVIEW_DIR / "screenshots"
        self.elements_dir = REVIEW_DIR / "elements"
        self.screens_dir.mkdir(parents=True, exist_ok=True)
        self.elements_dir.mkdir(parents=True, exist_ok=True)
        self.errors_bucket: list[dict] = []
        self.current_screen = "boot"
        self.manifest: dict = {}
        self.runtime: dict = {}
        self.ext = "jpg" if args.format == "jpg" else "png"
        self.fl: Flutter | None = None
        self.sidebar_x_max = 330

    # ---- runtime error collection
    def attach_errors(self, page: Page):
        def rec(kind, **kw):
            self.errors_bucket.append({"kind": kind, "screen": self.current_screen,
                                       "time": datetime.now(timezone.utc).isoformat(timespec="seconds"), **kw})

        page.on("console", lambda m: rec("console." + m.type, text=m.text[:2000])
                if m.type in ("error", "assert") or "EXCEPTION CAUGHT" in m.text
                or "RenderFlex overflowed" in m.text or "FlutterError" in m.text else None)
        page.on("pageerror", lambda e: rec("pageerror", text=str(e)[:2000]))

        def on_resp(r):
            if r.status >= 400:
                rec("http", status=r.status, method=r.request.method, url=r.url)

        page.on("response", on_resp)
        page.on("requestfailed", lambda r: rec("requestfailed", method=r.method, url=r.url,
                                                failure=(r.failure or "")) if r.resource_type in ("xhr", "fetch") else None)

    def take_errors(self) -> list[dict]:
        out, self.errors_bucket = self.errors_bucket, []
        return out

    # ---- capture one state
    async def shot(self, screen: dict, state: str, rec: dict):
        name = f"{screen['nn']}-{screen['slug']}-{state}"
        file_name = f"{name}.{self.ext}"
        path = self.screens_dir / file_name
        # park the pointer so hover tooltips / highlights do not leak into the screenshot
        await self.fl.page.mouse.move(VIEWPORT["width"] - 2, VIEWPORT["height"] - 2)
        await self.fl.page.wait_for_timeout(500)
        kw = {"path": str(path), "full_page": False}
        if self.ext == "jpg":
            kw.update(type="jpeg", quality=80)
        await self.fl.page.screenshot(**kw)
        nodes = await self.fl.snapshot()
        el = build_elements(nodes, screen, state, file_name)
        (self.elements_dir / f"{name}.json").write_text(json.dumps(el, ensure_ascii=False, indent=1), encoding="utf-8")
        rec["files"].append({"state": state, "screenshot": f"screenshots/{file_name}",
                             "elements": f"elements/{name}.json"})
        print(f"    [ok] {file_name}  (texts={el['counts']['texts']} buttons={el['counts']['buttons']} fields={el['counts']['fields']})")
        return nodes

    # ---- session
    async def at_login(self) -> bool:
        nodes = await self.fl.snapshot()
        return any(n["tag"] == "input" and n.get("input_type") == "password" for n in nodes)

    async def ensure_arabic_on_login(self):
        # login screen shows "العربية" while in English, "English" while in Arabic
        n = await self.fl.find(["العربية"], tappable=True)
        if n and first_line(node_label(n)) == "العربية":
            await self.fl.click_node(n)

    async def login(self, user: str, pwd: str):
        page = self.fl.page
        await self.ensure_arabic_on_login()
        for attempt in range(3):
            nodes = await self.fl.snapshot()
            u = next((n for n in nodes if n["tag"] == "input" and n.get("input_type") == "text"), None)
            p = next((n for n in nodes if n["tag"] == "input" and n.get("input_type") == "password"), None)
            if not u or not p:
                raise RuntimeError("login fields not found in semantics tree")
            await self.fl.type_into(u, user)
            await self.fl.type_into(p, pwd)
            val_u = await page.eval_on_selector("input[type=text]", "e => e.value")
            val_p = await page.eval_on_selector("input[type=password]", "e => e.value.length")
            if val_u == user and val_p == len(pwd):
                break
        btn = await self.fl.find(["تسجيل الدخول إلى النظام", "تسجيل الدخول", "Sign In", "Login"])
        if btn:
            await self.fl.click_node(btn)
        else:
            await page.keyboard.press("Enter")
        for _ in range(60):
            await page.wait_for_timeout(500)
            if not await self.at_login():
                break
        else:
            raise RuntimeError("still on login screen after submitting credentials")
        await self.fl.wait_idle()

    @staticmethod
    def sidebar_search(nodes):
        """The sidebar quick-search box (its aria-label drops the hint once it has text)."""
        cands = [n for n in nodes if n["tag"] == "input" and n["x"] + n["w"] / 2 < 330 and 60 < n["y"] < 180]
        return cands[0] if cands else None

    async def ensure_arabic_in_app(self):
        nodes = await self.fl.snapshot()
        arabic = any(n["x"] < 300 and ("البيانات والجداول الأساسية" in node_label(n) or "لوحة القيادة" in node_label(n))
                     for n in nodes)
        if not arabic:
            tog = next((n for n in nodes if "English / العربية" in node_label(n) or "تغيير اللغة" in node_label(n)
                        or "Switch Language" in node_label(n) or "Toggle UI Language" in node_label(n)), None)
            if tog is None:
                raise RuntimeError("language toggle not found in the app header")
            await self.fl.click_node(tog)
        qs = self.sidebar_search(await self.fl.snapshot())
        if qs:
            self.sidebar_x_max = qs["x"] + qs["w"] + 20
            if qs.get("value"):
                await self.fl.type_into(qs, "")

    async def recover(self, user, pwd):
        """Reload the app and get back to a logged-in Arabic home screen."""
        page = self.fl.page
        await page.goto(self.args.base_url, wait_until="networkidle")
        await page.wait_for_timeout(2500)
        await self.fl.enable_semantics()
        if await self.at_login():
            await self.login(user, pwd)
        await self.ensure_arabic_in_app()

    # ---- navigation
    def in_sidebar(self, n):
        return n["x"] + n["w"] / 2 < self.sidebar_x_max and n["y"] > 80

    def in_main(self, n):
        return n["x"] + n["w"] / 2 >= self.sidebar_x_max

    async def main_signature(self) -> str:
        nodes = await self.fl.snapshot()
        return "|".join(sorted({node_label(n)[:60] for n in nodes if self.in_main(n) and node_label(n)}))[:20000]

    async def open_sidebar(self, label_ar: str, parent_ar: str | None):
        fl = self.fl
        nodes = await fl.snapshot()
        qs = self.sidebar_search(nodes)
        before = await self.main_signature()
        item = None
        if qs:
            query = label_ar
            await fl.type_into(qs, query)
            await fl.page.wait_for_timeout(900)
            item = await fl.find([label_ar], region=lambda n: self.in_sidebar(n) and n["tag"] != "input")
            if not item:  # shorter query helps when the label wraps / is truncated
                await fl.type_into(qs, " ".join(label_ar.split()[:3]))
                await fl.page.wait_for_timeout(900)
                item = await fl.find([label_ar], region=lambda n: self.in_sidebar(n) and n["tag"] != "input")
        if not item and parent_ar:
            if qs:
                await fl.type_into(qs, "")
                await fl.page.wait_for_timeout(600)
            hub = await fl.find([parent_ar], region=self.in_sidebar)
            if hub:
                await fl.click_node(hub, wait=False)
                await fl.page.wait_for_timeout(800)
                item = await fl.find([label_ar], region=lambda n: self.in_sidebar(n) and n["y"] > hub["y"])
        if not item:
            raise LookupError(f"sidebar item not found: {label_ar!r}")
        await fl.click_node(item)
        # clear the quick search so the sidebar is back to normal
        nodes = await fl.snapshot()
        qs = self.sidebar_search(nodes)
        if qs and qs.get("value"):
            await fl.type_into(qs, "")
            await fl.page.wait_for_timeout(400)
        await fl.wait_idle()
        after = await self.main_signature()
        return before != after

    async def navigate(self, screen: dict) -> str:
        ov = screen["open_via"]
        t = ov["type"]
        fl = self.fl
        if t in ("sidebar", "sidebar_broken"):
            changed = await self.open_sidebar(ov["sidebar_label_ar"], (ov.get("parent_menu") or {}).get("ar"))
            if not changed and t == "sidebar_broken":
                raise RuntimeError("sidebar item clicked but the main area did not change "
                                   "(known bug: navigation index out of range)")
            if not changed:
                return "clicked sidebar item, main area unchanged (screen may already have been open)"
            return "sidebar"
        if t == "embedded_tab":
            await self.open_sidebar(ov["sidebar_label_ar"], (ov.get("parent_menu") or {}).get("ar"))
            n = await fl.find_wait([ov.get("tab_or_button_ar"), ov.get("tab_or_button_en")], 8, region=self.in_main)
            if not n:
                raise LookupError(f"embedded tab/button not found: {ov.get('tab_or_button_ar')!r}")
            await fl.click_node(n)
            return "embedded_tab"
        if t == "command_palette":
            await fl.page.mouse.click(VIEWPORT["width"] / 2, VIEWPORT["height"] - 5)
            await fl.page.keyboard.press("Control+K")
            await fl.page.wait_for_timeout(1200)
            nodes = await fl.snapshot()
            inp = next((n for n in reversed(nodes) if n["tag"] in ("input", "textarea")
                        and n is not self.sidebar_search(nodes)), None)
            if not inp:
                raise LookupError("command palette search field not found after Ctrl+K")
            await fl.type_into(inp, " ".join(ov["palette_label_ar"].split()[:4]))
            await fl.page.wait_for_timeout(1000)
            n = await fl.find([ov["palette_label_ar"], ov.get("palette_label_en")])
            if n and n["tag"] not in ("input", "textarea"):
                await fl.click_node(n)
            else:
                await fl.page.keyboard.press("Enter")
                await fl.wait_idle()
            if await fl.dialog_open():
                raise RuntimeError("command palette still open after selecting the entry")
            return "command_palette"
        if t == "callback":
            # Import Files -> View Details -> Document Matrix (DC-04)
            await self.open_sidebar("ملفات الشحنات الاستيرادية", "تخطيط الشحنة وأوامر الشراء")
            d = await fl.find_wait(["عرض التفاصيل", "View Details"], 10, region=self.in_main)
            if not d:
                raise LookupError("'عرض التفاصيل' button not found on Import Files (no import file rows?)")
            await fl.click_node(d)
            m = await fl.find_wait(["مصفوفة المستندات (DC-04)", "Document Matrix (DC-04)"], 15)
            if not m:
                raise LookupError("'مصفوفة المستندات (DC-04)' button not found in ImportFileDetailsDialog")
            await fl.click_node(m)
            return "callback"
        raise RuntimeError(f"unsupported open_via type {t}")

    # ---- per-screen states
    async def capture_tabs(self, screen: dict, rec: dict):
        fl = self.fl
        tabs = screen.get("tabs") or []
        for i, tab in enumerate(tabs, start=1):
            label_ar, label_en = tab.get("ar"), tab.get("en")
            state = f"tab-{i}-{slugify(label_en or label_ar)}"
            n = await fl.find([label_ar, label_en], region=self.in_main)
            if not n:
                rec["issues"].append(f"{state}: tab label not found in semantics tree ({label_ar!r})")
                continue
            try:
                # some "tabs" open a modal (e.g. cargo-insurance "new certificate")
                # that Escape does not close: reload before the next step.
                self.needs_reset = True
                await fl.click_node(n)
                await self.shot(screen, state, rec)
            except Exception as e:  # noqa: BLE001
                rec["issues"].append(f"{state}: {type(e).__name__}: {e}")
            await fl.close_overlays()

    async def find_add_button(self, screen: dict):
        fl = self.fl
        for lab in add_dialog_labels(screen):
            btn = await fl.find([lab], region=self.in_main)
            if btn:
                return btn
        # fall back to any visible "add/new" button in the main area
        for n in await fl.snapshot():
            lab = first_line(node_label(n))
            if not ((n["tap"] or n["role"] == "button") and self.in_main(n) and n["in_view"] and lab):
                continue
            looks_add = (lab.startswith("إضافة") or lab.startswith("+ إضافة") or lab.startswith("إنشاء")
                         or re.search(r"(^|\s)(جديد|جديدة)(\s|$)", lab))
            if looks_add and not any(w in lab for w in AI_WORDS):
                return n
        return None

    async def capture_add_dialog(self, screen: dict, rec: dict):
        fl = self.fl
        btn = await self.find_add_button(screen)
        if not btn and screen.get("tabs"):
            # the add button may live on another tab: walk the tabs looking for it
            for i, tab in enumerate(screen["tabs"], start=1):
                t = await fl.find([tab.get("ar"), tab.get("en")], region=self.in_main)
                if not t:
                    continue
                await fl.click_node(t)
                btn = await self.find_add_button(screen)
                if btn:
                    rec["add_button_tab"] = i
                    break
        if not btn:
            rec["notes"].append("no add/create button found (screen has no add dialog or it is hidden)")
            return
        rec["add_button"] = first_line(node_label(btn))
        # an add dialog (or dirty inline form) may survive Escape/Cancel - e.g.
        # an unsaved-changes guard or an X-only dialog without semantics role -
        # and block the next screen; reload the app before the next screen.
        self.needs_reset = True
        await fl.click_node(btn)
        if not await fl.dialog_open():
            # some "add" buttons open inline forms / new pages instead of dialogs
            await self.shot(screen, "dialog-add", rec)
            rec["notes"].append("add button did not open a modal dialog (inline form or page); captured as dialog-add")
            save_region = self.in_main
        else:
            await self.shot(screen, "dialog-add", rec)
            save_region = in_dialog_region(await fl.snapshot())
        # press save with the empty form
        nodes = await fl.snapshot()
        save = None
        for w in SAVE_WORDS:
            cands = [n for n in nodes if (n["tap"] or n["role"] == "button") and n["in_view"]
                     and (save_region is None or save_region(n))
                     and norm(first_line(node_label(n))).startswith(norm(w))]
            if cands:
                save = max(cands, key=lambda n: (n["y"], n["x"]))  # footer buttons are lowest
                break
        if not save:
            rec["issues"].append("dialog-add-validation: no save/submit button found in the add dialog")
        else:
            rec["save_button"] = first_line(node_label(save))
            await fl.click_node(save)
            await fl.page.wait_for_timeout(700)
            await self.shot(screen, "dialog-add-validation", rec)
        if not await fl.close_overlays():
            rec["issues"].append("dialog could not be closed with Escape/Cancel")

    async def capture_screen(self, screen: dict, user: str, pwd: str):
        nn, slug = screen["nn"], screen["slug"]
        t = screen["open_via"]["type"]
        rec = {"nn": nn, "slug": slug, "name_ar": screen.get("name_ar"), "name_en": screen.get("name_en"),
               "group": screen.get("group"), "open_via": t, "status": "pending", "files": [],
               "issues": [], "notes": []}
        self.manifest[nn] = rec
        self.current_screen = f"{nn}-{slug}"
        print(f"[{nn}] {slug} ({t})")
        t0 = time.monotonic()
        if t == "unreachable":
            rec["status"] = "skipped"
            rec["reason"] = "unreachable in the running app: " + (screen["open_via"].get("notes") or "")
            return
        try:
            if t == "app_start" and slug == "login":
                page = self.fl.page
                # fresh context shows the login screen; captured before logging in (see run())
                if not rec["files"]:
                    rec["notes"].append("captured before login")
                rec["status"] = "ok" if rec["files"] else "failed"
                return
            if getattr(self, "needs_reset", False):
                self.needs_reset = False
                await self.recover(user, pwd)
            await self.fl.close_overlays()
            if t == "app_start":
                how = "home shell after login"
                # nothing to navigate: sidebar + dashboard are the shell
            else:
                how = await asyncio.wait_for(self.navigate(screen), timeout=self.args.screen_timeout)
            rec["navigation"] = how
            await self.fl.close_overlays() if t != "callback" else None
            await self.shot(screen, "main", rec)
            await asyncio.wait_for(self.capture_tabs(screen, rec), timeout=self.args.screen_timeout * 3)
            if t != "app_start":
                if getattr(self, "needs_reset", False) and t != "callback":
                    # start the add-dialog step from a clean, freshly navigated screen
                    self.needs_reset = False
                    await self.recover(user, pwd)
                    await asyncio.wait_for(self.navigate(screen), timeout=self.args.screen_timeout)
                await asyncio.wait_for(self.capture_add_dialog(screen, rec), timeout=self.args.screen_timeout)
            rec["status"] = "ok" if not rec["issues"] else "partial"
        except Exception as e:  # noqa: BLE001
            rec["status"] = "failed" if not rec["files"] else "partial"
            rec["reason"] = f"{type(e).__name__}: {e}"
            rec["trace"] = traceback.format_exc(limit=3)[-1500:]
            print(f"    [FAIL] {rec['reason']}")
            if self.args.debug_dir:
                try:
                    dd = Path(self.args.debug_dir)
                    dd.mkdir(parents=True, exist_ok=True)
                    await self.fl.page.screenshot(path=str(dd / f"{nn}-{slug}-fail.png"))
                    (dd / f"{nn}-{slug}-fail.json").write_text(
                        json.dumps(await self.fl.snapshot(), ensure_ascii=False, indent=0), encoding="utf-8")
                except Exception:  # noqa: BLE001
                    pass
            try:
                await self.recover(user, pwd)
            except Exception as e2:  # noqa: BLE001
                rec["notes"].append(f"recovery failed: {e2}")
        finally:
            rec["seconds"] = round(time.monotonic() - t0, 1)
            errs = self.take_errors()
            if errs:
                self.runtime.setdefault(f"{nn}-{slug}", []).extend(errs)
            # leave nested navigations (callback screens are pushed routes)
            if t == "callback":
                try:
                    await self.recover(user, pwd)
                except Exception:  # noqa: BLE001
                    pass

    # ---- main
    async def run(self, screens: list[dict], user: str, pwd: str):
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=not self.args.headed)
            ctx = await browser.new_context(viewport=VIEWPORT, device_scale_factor=SCALE, locale="ar-EG")
            page = await ctx.new_page()
            self.fl = Flutter(page, self.args.settle_ms)
            self.fl.attach_network()
            self.attach_errors(page)
            await page.goto(self.args.base_url, wait_until="networkidle")
            await page.wait_for_timeout(2500)
            await self.fl.enable_semantics()
            await self.ensure_arabic_on_login()
            await self.fl.wait_idle(quiet_ms=300)
            login_screen = next((s for s in screens if s["slug"] == "login"), None)
            if login_screen:
                rec = {"nn": login_screen["nn"], "slug": "login", "name_ar": login_screen.get("name_ar"),
                       "name_en": login_screen.get("name_en"), "group": login_screen.get("group"),
                       "open_via": "app_start", "status": "ok", "files": [], "issues": [], "notes": []}
                self.current_screen = f"{login_screen['nn']}-login"
                if await self.at_login():
                    await self.shot(login_screen, "main", rec)
                    # empty submit -> validation state
                    b = await self.fl.find(["تسجيل الدخول إلى النظام", "تسجيل الدخول"])
                    if b:
                        await self.fl.click_node(b)
                        await self.shot(login_screen, "dialog-add-validation", rec)
                        rec["notes"].append("dialog-add-validation = login submitted with empty fields")
                else:
                    rec["status"] = "failed"
                    rec["reason"] = "login screen not shown at start"
                errs = self.take_errors()
                if errs:
                    self.runtime.setdefault(f"{login_screen['nn']}-login", []).extend(errs)
                self.manifest[login_screen["nn"]] = rec
                # reload so the login form is clean
                await page.goto(self.args.base_url, wait_until="networkidle")
                await page.wait_for_timeout(2500)
                await self.fl.enable_semantics()
            self.current_screen = "login"
            if await self.at_login():
                await self.login(user, pwd)
            await self.ensure_arabic_in_app()
            self.take_errors_into("session-login")
            for s in screens:
                if s["slug"] == "login":
                    continue
                await self.capture_screen(s, user, pwd)
                self.write_outputs(partial=True)
            await browser.close()
        self.maybe_convert_to_jpeg()
        self.write_outputs(partial=False)

    def take_errors_into(self, key):
        errs = self.take_errors()
        if errs:
            self.runtime.setdefault(key, []).extend(errs)

    def maybe_convert_to_jpeg(self):
        if self.ext != "png" or self.args.format != "auto":
            return
        files = list(self.screens_dir.glob("*.png"))
        total = sum(f.stat().st_size for f in files)
        if total <= SIZE_LIMIT_BYTES:
            return
        from PIL import Image
        print(f"screenshots total {total / 1e6:.1f} MB > 100 MB: converting to JPEG q80")
        for f in files:
            Image.open(f).convert("RGB").save(f.with_suffix(".jpg"), "JPEG", quality=80, optimize=True)
            f.unlink()
        for rec in self.manifest.values():
            for fi in rec["files"]:
                fi["screenshot"] = fi["screenshot"][:-4] + ".jpg"
        for j in self.elements_dir.glob("*.json"):
            d = json.loads(j.read_text(encoding="utf-8"))
            if d.get("screenshot", "").endswith(".png"):
                d["screenshot"] = d["screenshot"][:-4] + ".jpg"
                j.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")

    def write_outputs(self, partial: bool):
        # merge with existing files so --only / --group runs accumulate
        man_path = REVIEW_DIR / "capture-manifest.json"
        err_path = REVIEW_DIR / "runtime-errors.json"
        old = {}
        if man_path.exists():
            try:
                old = {s["nn"]: s for s in json.loads(man_path.read_text(encoding="utf-8")).get("screens", [])}
            except Exception:  # noqa: BLE001
                old = {}
        old.update(self.manifest)
        all_nn = [s["nn"] for s in self.inv["screens"]]
        screens = []
        for nn in all_nn:
            if nn in old:
                screens.append(old[nn])
            else:
                s = next(x for x in self.inv["screens"] if x["nn"] == nn)
                screens.append({"nn": nn, "slug": s["slug"], "status": "not_run", "files": []})
        shots = list(self.screens_dir.glob("*.png")) + list(self.screens_dir.glob("*.jpg"))
        summary = {}
        for s in screens:
            summary[s["status"]] = summary.get(s["status"], 0) + 1
        manifest = {
            "generated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "in_progress": partial,
            "target": {"base_url": self.args.base_url, "platform": "Flutter web (Chromium via Playwright)",
                       "viewport": VIEWPORT, "device_scale_factor": SCALE, "language": "ar (toggled via UI)"},
            "summary": summary,
            "screenshots_total_mb": round(sum(f.stat().st_size for f in shots) / 1e6, 1),
            "screens": screens,
        }
        man_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
        olde = {}
        if err_path.exists():
            try:
                olde = json.loads(err_path.read_text(encoding="utf-8")).get("by_screen", {})
            except Exception:  # noqa: BLE001
                olde = {}
        for k in self.runtime:
            olde[k] = dedupe_errors(self.runtime[k])
        err = {
            "generated": manifest["generated"],
            "notes": [
                "Collected from the Flutter WEB build in Chromium: browser console errors/asserts, uncaught page "
                "errors, failed XHR/fetch requests and HTTP responses with status >= 400, bucketed per screen.",
                "The release web build (flutter build web --release) strips debug asserts, so RenderFlex/layout "
                "OVERFLOW errors and most FlutterError reports are NOT emitted here. To catch overflows, build "
                "with `flutter build web --debug -o <dir>`, serve it and re-run with --base-url.",
                "Windows-desktop-only issues (window_manager, file dialogs, platform channels) cannot appear on web.",
            ],
            "base_url": self.args.base_url,
            "by_screen": olde,
            "counts": {k: sum(e.get("count", 1) for e in v) for k, v in olde.items()},
        }
        err_path.write_text(json.dumps(err, ensure_ascii=False, indent=1), encoding="utf-8")


def dedupe_errors(errs: list[dict]) -> list[dict]:
    """Collapse repeated identical errors into one entry with a count."""
    out: dict[tuple, dict] = {}
    for e in errs:
        key = (e.get("kind"), e.get("text"), e.get("url"), e.get("status"), e.get("method"))
        if key in out:
            out[key]["count"] = out[key].get("count", 1) + e.get("count", 1)
            out[key]["last_time"] = e.get("time")
        else:
            out[key] = dict(e, count=e.get("count", 1))
    return list(out.values())


def load_credentials(args) -> tuple[str, str]:
    user = os.environ.get("REVIEW_USER")
    pwd = os.environ.get("REVIEW_PASSWORD")
    if args.credentials:
        c = json.loads(Path(args.credentials).read_text(encoding="utf-8"))
        user = user or c.get("username")
        pwd = pwd or c.get("password")
    if not user or not pwd:
        sys.exit("Set REVIEW_USER and REVIEW_PASSWORD, or pass --credentials <json>.")
    return user, pwd


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base-url", default="http://127.0.0.1:8088")
    ap.add_argument("--credentials", help="JSON file with username/password (kept outside the repo)")
    ap.add_argument("--only", help="comma-separated slugs (or NN numbers)")
    ap.add_argument("--group", help="inventory group key, e.g. reference, customs")
    ap.add_argument("--format", choices=["auto", "png", "jpg"], default="auto",
                    help="auto = PNG, converted to JPEG q80 if the total exceeds 100 MB")
    ap.add_argument("--settle-ms", type=int, default=1500, help="extra settle delay after network idle")
    ap.add_argument("--screen-timeout", type=float, default=90.0)
    ap.add_argument("--headed", action="store_true")
    ap.add_argument("--debug-dir", help="on failure, save a screenshot + semantics dump here (keep outside the repo)")
    args = ap.parse_args()
    if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
        sys.stdout.reconfigure(encoding="utf-8")

    inv = json.loads(INVENTORY.read_text(encoding="utf-8"))
    screens = inv["screens"]
    if args.group:
        screens = [s for s in screens if s.get("group") == args.group]
    if args.only:
        want = {w.strip() for w in args.only.split(",") if w.strip()}
        screens = [s for s in screens if s["slug"] in want or s["nn"] in want]
    if not screens:
        sys.exit("No screens match the filters.")
    user, pwd = load_credentials(args)
    print(f"Capturing {len(screens)} screen(s) from {args.base_url}")
    asyncio.run(Runner(args, inv).run(screens, user, pwd))
    print("Done. See docs/app-review/capture-manifest.json")


if __name__ == "__main__":
    main()
