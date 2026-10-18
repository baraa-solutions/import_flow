import sqlite3
import json

con = sqlite3.connect('sorour_logistics.db')
con.row_factory = sqlite3.Row
cur = con.cursor()

row = cur.execute("SELECT * FROM import_files WHERE import_file_id = 4").fetchone()
for k in row.keys():
    print(f"{k}: {row[k]}")
