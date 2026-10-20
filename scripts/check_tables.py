import sqlite3
import json

con = sqlite3.connect('sorour_logistics.db')
con.row_factory = sqlite3.Row
cur = con.cursor()

def dump_table(name, where="import_file_id = 4"):
    try:
        rows = cur.execute(f"SELECT * FROM {name} WHERE {where}").fetchall()
        if rows:
            print(f"=== {name} ({len(rows)} rows) ===")
            for r in rows:
                print(dict(r))
    except Exception as e:
        pass

# Tables of interest
tables = [
    'import_files',
    'purchase_orders',
    'po_line_items',
    'packing_list_items',
    'po_packing_reconciliation_sessions',
    'cargox_standard_invoice_sessions',
    'invoice_bl_match_sessions',
    'shipment_document_items',
    'container_loader_sessions',
    'container_specs',
    'financial_settlement_records',
    'file_closure_records',
    'customs_clearance_records',
]

for t in tables:
    dump_table(t)
