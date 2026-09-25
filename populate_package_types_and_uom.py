"""
Populate Package Types and Units of Measure on ONE explicit database.

Upserts (overwrites the names of existing codes). Safety (update-system-plan A13/R12):
    python populate_package_types_and_uom.py --db <path/to/db> --confirm
The target must not be in use, and a verified pre_migration_ backup is taken first (abort on failure).
"""
import sqlite3
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Optional

ROOT_DIR = Path(__file__).resolve().parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.db_script_guard import add_target_arguments, guard_target, run_cli_action  # noqa: E402

SCRIPT_TAG = "populate_package_types_and_uom"

PACKAGE_TYPES = [
    ("B4", "Belt", "حزام / سير"),
    ("BD", "Board", "لوح"),
    ("BE", "Bundle", "حزمة"),
    ("BG", "Bag", "كيس / شوال"),
    ("BK", "Basket", "سلة"),
    ("BL", "Bale, compressed", "بالة مضغوطة"),
    ("BX", "Box", "صندوق"),
    ("CA", "Can, rectangular", "صفيحة مستطيلة"),
    ("CH", "Chest", "صندوق خشب كبير"),
    ("CL", "Coil", "لفافة / كويل"),
    ("CR", "Crate", "قفص خشبي"),
    ("CT", "Carton", "كرتونة"),
    ("DR", "Drum", "برميل"),
    ("PF", "Pen", "قلم / حاوية خاصة"),
    ("PG", "Plate", "صفيحة / لوح مسطح"),
    ("PK", "Package", "طرد / عبوة"),
    ("PL", "Pail", "سطل / جردل"),
    ("PR", "Receptacle, plastic", "وعاء بلاستيكي"),
    ("RL", "Reel", "بكرة"),
    ("RO", "Roll", "رول / لفة"),
    ("TN", "Tin", "علبة صفيح"),
    ("VQ", "Bulk, liquefied gas (at abnormal temperature/pressure)", "صب، غاز مسال"),
    # Additional common logistics package types
    ("PLT", "Pallet", "بالتة خشبية/بلاستيكية"),
    ("IBC", "Intermediate Bulk Container (IBC Tank)", "خزان سوائل IBC"),
]

UNITS_OF_MEASURE = [
    ("GRM", "gram", "جرام"),
    ("KGM", "kilogram", "كيلوجرام"),
    ("SET", "set", "طقم / مجموعة"),
    ("STN", "ton (US) or short ton (UK/US)", "طن قصير"),
    # Standard international trade units
    ("PCS", "Piece", "قطعة"),
    ("PCE", "Piece", "قطعة"),
    ("CTN", "Carton", "كرتونة"),
    ("TON", "Metric Ton (1,000 kg)", "طن متري"),
    ("MTR", "Meter", "متر"),
    ("LTR", "Liter", "لتر"),
    ("BOX", "Box", "صندوق"),
    ("PKG", "Package", "طرد"),
    ("LOT", "Lot / Shipment Batch", "دفعة شحنة"),
    ("CBM", "Cubic Meter", "متر مكعب"),
    ("SQM", "Square Meter", "متر مربع"),
]

def populate_db(db_path: Path, *, confirm: bool = False, backups_dir: Optional[Path] = None) -> bool:
    """confirm=True: in-use check + verified backup first. confirm=False: never the live app DB."""
    db_path = Path(db_path)
    guard_target(db_path, confirm=confirm, tag=SCRIPT_TAG, backups_dir=backups_dir)

    print(f"--- Updating Package Types & UOM on: {db_path} ---")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute("""
    CREATE TABLE IF NOT EXISTS package_types (
        package_type_id INTEGER PRIMARY KEY AUTOINCREMENT,
        code VARCHAR(10) NOT NULL UNIQUE,
        name VARCHAR(150) NOT NULL,
        name_ar VARCHAR(150),
        is_active BOOLEAN NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS units_of_measure (
        unit_id INTEGER PRIMARY KEY AUTOINCREMENT,
        code VARCHAR(10) NOT NULL UNIQUE,
        name VARCHAR(150) NOT NULL,
        name_ar VARCHAR(150),
        is_active BOOLEAN NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    """)

    now_iso = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Insert Package Types
    for code, name, name_ar in PACKAGE_TYPES:
        cur.execute(
            """INSERT INTO package_types (code, name, name_ar, is_active, created_at, updated_at)
               VALUES (?, ?, ?, 1, ?, ?)
               ON CONFLICT(code) DO UPDATE SET
                   name=excluded.name,
                   name_ar=excluded.name_ar,
                   updated_at=excluded.updated_at;""",
            (code, name, name_ar, now_iso, now_iso)
        )

    # Insert Units of Measure
    for code, name, name_ar in UNITS_OF_MEASURE:
        cur.execute(
            """INSERT INTO units_of_measure (code, name, name_ar, is_active, created_at, updated_at)
               VALUES (?, ?, ?, 1, ?, ?)
               ON CONFLICT(code) DO UPDATE SET
                   name=excluded.name,
                   name_ar=excluded.name_ar,
                   updated_at=excluded.updated_at;""",
            (code, name, name_ar, now_iso, now_iso)
        )

    conn.commit()

    cur.execute("SELECT COUNT(*) FROM package_types;")
    pkg_cnt = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM units_of_measure;")
    uom_cnt = cur.fetchone()[0]
    print(f"   [OK] package_types: {pkg_cnt} records | units_of_measure: {uom_cnt} records")
    conn.close()
    return True


def main(argv: Optional[List[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Populate package types and units of measure on ONE database.")
    add_target_arguments(parser, target_help="Database file to update")
    args = parser.parse_args(argv)

    def _run(target: Path, backups_dir: Optional[Path]):
        populate_db(target, confirm=True, backups_dir=backups_dir)
        print("\n[SUCCESS] Package types and Units of measure successfully populated!")
        return True

    return run_cli_action(args, _run)


if __name__ == "__main__":
    sys.exit(main())
