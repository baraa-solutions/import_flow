"""
app_update has no database tables.

The update state lives in files under the update data dir (last_manifest.json, update_history.jsonl,
staging/), deliberately outside the database so it survives a database restore (plan §4.10, §5).
"""
