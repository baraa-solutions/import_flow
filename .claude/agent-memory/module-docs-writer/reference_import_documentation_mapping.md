---
name: import-documentation-module-mapping
description: Mapping quirks for documenting the import_documentation module (extra files, Flutter registration, how to check auth)
metadata:
  type: reference
---

- Backend `modules/import_documentation/` has extra files beyond the 6-file convention: `ai_document_parser.py`, `nafeza_acid_parser.py`, `arabic_ocr_engine.py`, `models/arabic_ocr/`.
- Flutter feature has the same name; screens are registered by index in `frontend/lib/features/home/home_screen.dart` (not go_router paths). Other providers live in `experience_guide` and `docs_customs_approval`.
- To check auth, read each route's `Depends(...)` in `router.py`, then `main.py`: the `include_router(...)` call (router-level `dependencies`) and the `@app.middleware` functions. Re-check on every run; auth on this router has changed before.
- Docs go in `docs/modules/`; phase link goes under `## 📚 Module Docs` before the closing footer line in `docs/phase_XX_*.md`.
