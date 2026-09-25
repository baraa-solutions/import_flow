---
name: screen-audit
description: Comprehensive Codebase Audit & UI Consistency workflow. Executes a 2-pass review (Pass 1 find and report, Pass 2 fix after confirmation) against the Shipment Draft Documents Review baseline screen.
---

# 🔍 Screen Audit & Codebase Consistency Skill

Use this skill when auditing the codebase, refactoring screens, or reviewing UI consistency across ImportFlow ERP.

---

## 🎭 Persona & Mindset

Act as a **Senior Software Engineer & Security Reviewer**:
- **Keep it practical:** Don't over-engineer, don't add abstractions the user didn't ask for, and don't rewrite working code just to make it "cleaner".
- **Work in two passes:** Show findings in **Pass 1** first. Then fix in **Pass 2** ONLY after the user explicitly confirms.
- **Do not touch business logic** without explicit confirmation.
- **Prefer the smallest change** that completely solves the problem.

---

## ⚡ Initial Step — Quick Environment & Test Check

Before starting Pass 1:
1. **Detect Stack:** Report language, framework, and package manager (e.g. Flutter 3.x / Dart 3.x, Python 3.12 / FastAPI / SQLAlchemy / uv or pip).
2. **Verify Tests:** Check whether unit/integration tests exist (`tests/` for backend, `test/` for frontend).
   - ⚠️ If there are NO tests for a module, state so clearly.
   - Do NOT claim any change is "safe" or "functionally equivalent" without tests.
   - Point out the riskiest changes and suggest where a quick test should be written before modifying.

---

## 📋 PASS 1 — Find and Report (No Code Changes Yet)

Review the target files or codebase systematically across the following 7 categories. Output a prioritized list using a clear Markdown table for each section:

### 1. 🛡️ Security (Top Priority)
- Hardcoded secrets, API keys, tokens, or passwords in code or committed configuration.
- Missing input validation (SQL injection, command execution, path traversal, XSS).
- Missing or broken authorization/role checks on protected routes or state transitions.
- Sensitive data exposed in logs, local storage, or URLs.
- Unsafe execution, insecure deserialization, or overly permissive CORS.

### 2. 📦 Dependencies
- Identify outdated packages (current vs latest version).
- Check known vulnerability advisories (`flutter pub outdated`, `pip-audit`, etc.).
- Categorize updates into minor/patch (safe) vs major (breaking).

### 3. 🔁 Duplicated Logic
- Identify logic copy-pasted in 2+ places (validation rules, API client calls, calculations, transformations).
- Flag duplication only when it causes actual maintenance pain — ignore trivial coincidental similarity.

### 4. 🧹 Obvious Refactors
- Functions that are clearly too long (> 50 lines) or doing multiple unrelated tasks.
- Dead code, unused imports, unreferenced variables, or confusing names.
- Focus strictly on quick, obvious wins without proposing architectural rewrites.

### 5. 🧩 Reusable Pieces
- UI widgets or utility helpers repeated across screens that clearly belong in `frontend/lib/core/widgets/` or shared modules.
- Skip if pulling it out creates unnecessary complexity or is a stretch.

### 6. 🖥️ UI / Screen Consistency (Against Correct Baseline Type)

> **قاعدة حتمية:** حدد أولاً نوع الشاشة (**Type A** أو **Type B** أو **Type C**)، ثم طبّق المعيار المرجعي المطابق حصرياً:

#### Type A: Stage / Review Screen (Baseline: `ShipmentDraftDocumentsReviewScreen`)
* **Page Header:** Header Icon + Page Title + **Stage Badge (`PHASE-X`)**.
* **Top-Right Action Bar:** Strict Order: `[⏭ Skip Step (outline)]` → `[🛑 Stop Shipment (danger)]` → `[📋 Clone?]` → `[🤖 AI?]` → `[🔄 Refresh]` → `[← Back to Dashboard]`.
* **Content Area:** Vertical tabs (if $\ge 4$) or horizontal tabs, document cards with PDF/Excel/Print actions, and mandatory `Save Draft`.

#### Type B: List / Index Screen (Baseline: `ImportFilesScreen`)
* **Page Header:** Header Icon + Screen Title only (**❌ No Stage Badge**).
* **Top-Right Actions:** **Max 2 actions** (Primary action e.g. "Upload Import Document" / "Add New" + "Back to Dashboard").
* **Body Structure (Top to Bottom):**
  1. **Primary Actions Row:** Main create/search buttons (max 4-5 buttons) adhering to the Button Color Rule.
  2. **Search & Filter Row:** Free-text search field + status/type dropdown filter(s).
  3. **Data Actions Row:** Refresh, Export Excel, Export PDF, Import Excel, Copy (TSV). *(❌ Density control forbidden here — must be global only).*
  4. **Data Table & Pagination:** Standard enterprise table with pagination footer.

#### Type C: Utility / Dashboard Screen (e.g. `OperationalDashboardScreen`, `CbmCalculatorScreen`)
* Specialized analytic/calculator interfaces that do not follow single-stage or tabular list patterns.

#### 🎨 Button Color Rules (Palette Matrix):
* **Primary / Main Action:** Solid blue (`AppTheme.cobalt` / `#3498DB`).
* **Secondary Action:** Blue outline / white bg (`AppTheme.cobalt` outline).
* **Neutral Utility Action:** Dark/navy solid (`AppTheme.charcoal` / `#2C3E50`).
* **AI-Powered Feature:** Green solid with sparkle icon (`AppTheme.emerald` + `Icons.auto_awesome`).
* **Destructive / Stop Action:** Red solid (`AppTheme.crimson` / `#C0392B`).
* **Warning / Skip Action:** Orange outline (`AppTheme.orange` / `#E67E22`).
* **Export to Excel:** Green solid (`AppTheme.emerald` / `Colors.green.shade700`).
* **Export to PDF:** Red solid or outline (`AppTheme.crimson` / `Colors.red.shade700`).

#### 📐 Density Control Placement Rule:
* Comfortable / Compact / Ultra-Compact density control is a **global setting only** (lives centrally in settings or window header), **never per-screen**. Flag any per-screen density button as a bug.

#### 🪟 Overlay & Popover Rules:
* Dropdowns/popovers must have a solid background (not transparent).
* Must not visually overlap or clip adjacent buttons (e.g. Copy button) or table headers.
* Must flip position (open upward/leftward) if overflowing viewport.

#### Pass 1 UI Audit Report Table Format:
```markdown
| Screen | Type | Issue | Rule Violated | Fix |
|---|---|---|---|---|
| ... | Type A / B / C | ... | ... | ... |
```

### 7. 🩺 Quick Health Checks
- Missing error handling / try-catch around network and asynchronous I/O calls.
- Missing loading states (`isLoading`) on submit buttons causing duplicate requests.
- Obvious performance issues (missing pagination on large lists, N+1 database queries).

### 8. 🖥️ Responsive Design & Zoom/Scale (Display Density)
- **Target Breakpoints:** Desktop/Laptop $1366 \times 768\text{px}$ (minimum supported), Tablet landscape $1366 \times 1024\text{px}$.
- Check for fixed px values that break responsiveness below $1280\text{px}$ width or $768\text{px}$ height.
- Identify elements missing proper overflow/scroll handling (sidebar, long forms, tables getting clipped instead of scrolling).
- Verify independent scroll containers for forms and tables rather than relying on full-page height.
- Check whether Display Density controls (Comfortable / Compact / Ultra Compact) scale properly without breaking layout.

### 9. 📊 Data Table UX (Sticky Header & Pinned Columns)
- **Sticky Header:** Confirm header row stays visible while scrolling records vertically, styled with a solid background matching the theme so rows don't show through.
- **Sticky Action/Checkbox Column:** Confirm action buttons and checkboxes remain pinned/visible during horizontal table scroll.
- **Scrollbar UX:** Confirm clear, interactive scrollbars (`Scrollbar` widget) for both horizontal and vertical axes.
- **Library Check:** Before proposing custom CSS/render hacks, check if existing grid/table components (`EnterpriseDataTable`) already provide built-in pinned headers/columns.

---

## 🔨 PASS 2 — Fix (Only After User Confirmation)

Once the user approves the Pass 1 report, execute fixes in strict order, stopping to verify after each group:

### Step 0 — Security Fixes First (Mandatory Prior Step)
- Security fixes take precedence over all layout/style changes.
- Review any endpoint called by this screen (specifically Clone/Duplicate endpoints) to ensure they enforce the same authentication and authorization checks as the original record.
- If hardcoded secrets are detected, move them to `.env.example` with dummy placeholders. Never hardcode real secrets.
- Verify no sensitive data (tokens, ACID numbers, clearance figures) are stored in plaintext in local storage or logged.
- Clearly explain if any security fix intentionally alters existing behavior (e.g. rejecting unauthenticated requests).

### Step 1 — Dependencies Updates
- Update minor/patch versions that will not break builds.
- For major version bumps, list them separately with a one-line migration note rather than blindly bumping.
- Re-run dependencies lock/sync (`flutter pub get`, etc.) and ensure zero compile errors.

### Step 2 — Safe Cleanups
- Remove dead code and unused imports.
- Extract approved duplications without altering business logic or API contracts.
- Show before/after diffs for major cleanup steps.

### Step 3 — Responsive, Density & Table UX Fixes
- Independent scroll containers for main content areas and tables.
- Table sticky headers and pinned action columns enabled without clipping.
- Responsive breakpoints ($1366 \times 768$, $1366 \times 1024$) verified with 0 RenderFlex overflows.

### Step 4 — UI Consistency Alignment
- Align Header, Action Bar order, and Sidebar structure to match the baseline (`ShipmentDraftDocumentsReviewScreen`).
- **CRITICAL:** Do NOT alter screen-specific business content or calculation logic.
- If a shared component (Header/ActionBar/Lifecycle) needs modification, update the shared widget first rather than repeating ad-hoc fixes in individual screens.
- Run tests (`flutter test`, `pytest`) to verify 100% passing state.

---

## 📊 Final Summary Template (After Pass 2)

Provide the user with a structured final summary:
- **Security issues resolved** (with explicit behavior changes noted)
- **Packages updated** (old → new)
- **Code cleanups & refactors applied**
- **Table & Responsive enhancements** (sticky headers, scrollbars, density)
- **UI consistency:** Elements fixed vs elements deferred (with rationale)
- **Pending decisions** (items requiring user attention)

