---
name: flutter-row-key-focus-loss
description: Flutter form fields lose focus after one keystroke when row widgets are keyed on identityHashCode(model) and onChanged does setState + copyWith; how to reproduce in a widget test
metadata:
  type: project
---

Symptom "field closes after every digit" in list-of-rows forms (seen in PO dialog, fixed 2026-10-05): row
Card / TextFormField keyed `ValueKey('..${identityHashCode(item)}')` while `onChanged` does
`setState(() => rows[i] = rows[i].copyWith(...))` -> new object -> new key -> field re-created with
`initialValue` (also turns "1." into "1.0." -> 0.0, so decimals look "not accepted").
Introduced in PO by dbb1966 (index keys -> identity keys, to fix stale values after clone/remove).

**Why:** both index keys (stale after remove) and identity keys (churn on edit) are wrong for immutable rows.
**How to apply:** look for `identityHashCode(` in ValueKeys of editable rows. Fix pattern in PO:
`utils/po_row_list.dart` (stable key carried across `[]=`) + a field widget owning its controller.
Reproduce: `tester.showKeyboard(field)` once, then `tester.testTextInput.updateEditingValue(...)` per
prefix (NOT `enterText`, which re-taps and hides the bug); assert controller text and EditableText focus.

Related trap: a provider writing mutation failures into the LIST state's `error` turns the screen behind a
dialog into an error page (403 on save). Mutations should return the error to the caller only.
