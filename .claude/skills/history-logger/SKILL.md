---
name: history-logger
description: Log completed tasks into the daily history files following the append-only protocol.
---

# History Logger Skill

Use this skill after completing any task in the codebase.

## Log File Location
- Folder: `history/`
- File Pattern: `YYYY-MM-DD.md` (e.g., `history/2026-08-07.md`)

## Append-Only Rule
- NEVER delete or overwrite existing history entries.
- ALWAYS append new tasks to the end of the file.

## Template
```markdown
## 📝 [Timestamp] - Completed Task: [Task Title]

### 📌 Overview
- **Task Code:** [Task Code]
- **Description:** [Brief summary]

### 📁 Files Changed
- `path/to/file` — Created/Modified

### 📊 Technical Changes
- [Change 1]
- [Change 2]

### 🧪 Validation / Testing
- [Verification performed]

### 🏁 Next Steps
- [Next task]
```
