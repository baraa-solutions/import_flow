# 🖥️ UI Screen Standards — Moved to Skill

> **⚡ هذا الملف لم يعد يُحمَّل تلقائياً — تم تحويله إلى Skill.**

## للمهام التي تحتاج معايير UI:
اقرأ الـ Skill المخصص:
```
.agents/skills/ui-screen-standards/SKILL.md
```

## متى تفعّل الـ Skill:
أي مهمة تذكر: **شاشة، واجهة، UI، Flutter، Widget، Scaffold، Dialog، Form، Button، Layout، Screen**.

## Quick Reference (ملخص سريع):
- **Widgets الجاهزة:** `frontend/lib/core/widgets/`
- **ألوان:** `AppTheme.cobalt / emerald / crimson / orange / charcoal / cloudWhite`
- **أزرار:** `AppButton` فقط — ❌ ممنوع `ElevatedButton` أو ألوان Hard-coded
- **Dropdowns:** `SearchableDropdownField<T>` — ❌ ممنوع `DropdownButtonFormField`
- **Scaffold:** `VerticalStageScaffold` لـ Type A | `PageHeader` لـ Type B/C
- **Toolbar:** `MasterDataToolbarWidget` للقوائم | `StandardFormActionBar` للنماذج
- **File Save:** `FileSaveHelper.exportAndSaveFile(...)` — ❌ ممنوع Silent Download
- **Selection:** `SelectionArea` إلزامي لكل شاشة وDialog وحاسبة لتمكين التحديد الحر بالماوس
- **Clipboard:** `CopyHelper.copy` و `TableCopyHelper.copyTable` حصراً — ❌ ممنوع `Clipboard.setData` مباشر
- **Pure Views:** لغة نقية مفصولة 100% — ❌ ممنوع التكديس ثنائي اللغة بين أقواس مثل `(PO)` أو `(Terminal / Depot)`
