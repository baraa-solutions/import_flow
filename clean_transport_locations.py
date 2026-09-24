"""
Clean and Deduplicate Transport Locations (Ports, Airports, Dry Ports, Land Borders)
- Strictly English Only (No Arabic text)
- Zero duplicates across all ports, airports, dry ports, and land borders
- Applies to ONE explicit database (no longer loops over every candidate DB)

DESTRUCTIVE (deletes rows by id). Safety (update-system-plan A13/R12):
    python clean_transport_locations.py --db <path/to/db> --confirm
The target must not be in use, and a verified pre_migration_ backup is taken first (abort on failure).
Importing this module no longer changes anything.
"""
import re
import sqlite3
import sys
from pathlib import Path
from typing import List, Optional

ROOT_DIR = Path(__file__).resolve().parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.db_script_guard import add_target_arguments, guard_target, run_cli_action  # noqa: E402

SCRIPT_TAG = "clean_transport_locations"

arabic_re = re.compile(r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]')

DUPLICATE_LOCATION_IDS = [31, 32, 8, 34, 35, 98, 99, 30, 109, 57, 215, 230, 283, 285, 282, 68, 152, 251]

NAME_UPDATES = [
    ("Port of Singapore", "Sea Port", "Singapore", "Singapore", 193),
    ("Singapore Changi Cargo Airport", "Airport", "Singapore", "Singapore", 222),
    ("Incheon Port", "Sea Port", "South Korea", "Incheon", 198),
    ("Incheon International Cargo Airport", "Airport", "South Korea", "Incheon", 221),
    ("Bangkok Port (Khlong Toei)", "Sea Port", "Thailand", "Bangkok", 208),
    ("Bangkok Suvarnabhumi Cargo Airport", "Airport", "Thailand", "Bangkok", 235),
    ("Amsterdam Schiphol Cargo Airport", "Airport", "Netherlands", "Amsterdam", 119),
    ("Hong Kong International Cargo Airport", "Airport", "Hong Kong", "Hong Kong", 108),
    ("Marseille-Fos Port", "Sea Port", "France", "Marseille", 122),
    ("King Abdullah Port (Rabigh)", "Sea Port", "Saudi Arabia", "Rabigh", 137),
    ("Adabiya Port", "Sea Port", "Egypt", "Suez", 33),
    ("Safaga Port", "Sea Port", "Egypt", "Safaga", 7),
    ("Al Arish Port", "Sea Port", "Egypt", "Al Arish", 79),
    ("Qingdao Port", "Sea Port", "China", "Qingdao", 37),
    ("Tianjin Port / Xingang", "Sea Port", "China", "Tianjin", 38),
    ("Trieste Port", "Sea Port", "Italy", "Trieste", 54),
    ("Venice Port", "Sea Port", "Italy", "Venice", 53),
    ("Kobe Port", "Sea Port", "Japan", "Kobe", 202),
    ("Tanjung Priok Port (Jakarta)", "Sea Port", "Indonesia", "Jakarta", 209),
    ("Istanbul / Ambarli Port", "Sea Port", "Turkey", "Istanbul", 124),
    ("Khalifa Port (Abu Dhabi)", "Sea Port", "United Arab Emirates", "Abu Dhabi", 60),
    ("London Gateway Port (DP World)", "Sea Port", "United Kingdom", "London", 25),
    ("Salalah Port", "Sea Port", "Oman", "Salalah", 72),
    ("Rades Port (Tunis)", "Sea Port", "Tunisia", "Tunis", 160),
]


def clean_transport_locations(db_path: Path, *, confirm: bool = False, backups_dir: Optional[Path] = None) -> int:
    """Clean ``db_path`` only; returns the remaining transport_locations count.

    confirm=True: in-use check + verified backup first. confirm=False: never the live app DB.
    """
    db = Path(db_path)
    guard_target(db, confirm=confirm, tag=SCRIPT_TAG, backups_dir=backups_dir)

    print("\n=======================================================")
    print(f" Processing: {db}")
    print("=======================================================")
    conn = sqlite3.connect(db)
    try:
        cur = conn.cursor()

        # 1. Standardize Country Names and Types
        cur.execute("UPDATE transport_locations SET country = 'Libya' WHERE country = 'Libyan Arab Jamahiriya'")
        cur.execute("UPDATE transport_locations SET location_type = 'Sea Port' WHERE location_type IN ('Port', 'sea port', 'seaport')")
        cur.execute("UPDATE transport_locations SET location_type = 'Airport' WHERE location_type IN ('airport', 'Air Port')")
        cur.execute("UPDATE transport_locations SET location_type = 'Dry Port' WHERE location_type IN ('dry port', 'Dry port', 'ICD')")
        cur.execute("UPDATE transport_locations SET location_type = 'Land Border' WHERE location_type IN ('land border', 'Land border', 'Border Crossing')")

        # 2. Specific duplicates to delete by location_id or duplicate locode
        cur.execute(
            f"DELETE FROM transport_locations WHERE location_id IN ({','.join('?' * len(DUPLICATE_LOCATION_IDS))})",
            DUPLICATE_LOCATION_IDS,
        )

        # 3. Clean and Standardize Names
        for name, ltype, country, city, lid in NAME_UPDATES:
            cur.execute(
                "UPDATE transport_locations SET location_name = ?, location_type = ?, country = ?, city = ? WHERE location_id = ?",
                (name, ltype, country, city, lid)
            )

        # 4. Remove any Arabic from notes or other fields
        cur.execute("SELECT location_id, location_name, country, city, notes FROM transport_locations")
        rows = cur.fetchall()
        for lid, lname, lcountry, lcity, lnotes in rows:
            clean_name = arabic_re.sub('', lname or '').strip()
            clean_country = arabic_re.sub('', lcountry or '').strip()
            clean_city = arabic_re.sub('', lcity or '').strip()
            clean_notes = arabic_re.sub('', lnotes or '').strip() if lnotes else None
            cur.execute(
                "UPDATE transport_locations SET location_name = ?, country = ?, city = ?, notes = ? WHERE location_id = ?",
                (clean_name, clean_country, clean_city, clean_notes, lid)
            )

        conn.commit()
        cur.execute("SELECT COUNT(*) FROM transport_locations")
        total = cur.fetchone()[0]
        print(f"   [SUCCESS] Clean & Deduplicated records count: {total}")
        return total
    finally:
        conn.close()


def main(argv: Optional[List[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Clean and deduplicate transport locations on ONE database.")
    add_target_arguments(parser, target_help="Database file to clean")
    args = parser.parse_args(argv)

    def _run(target: Path, backups_dir: Optional[Path]):
        clean_transport_locations(target, confirm=True, backups_dir=backups_dir)
        print("\nDone cleaning the database!")
        return True

    return run_cli_action(args, _run)


if __name__ == "__main__":
    sys.exit(main())
