"""
Backfill & Populate Master Items from Existing Purchase Orders (MD-ITEM-001)

Reads distinct items across po_line_items, seeds master_items catalog,
links po_line_items and packing_list_items via master_item_id,
provisions item_supplier_catalog links, and backfills item_price_history.
"""

from __future__ import annotations

import argparse
import os
import sys

# Ensure project root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from typing import Optional
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from database.database import DATABASE_URL
from modules.purchase_orders.model import PurchaseOrder, POLineItem, PackingListItem
from modules.master_items.model import (
    MasterItem,
    ItemSupplierCatalog,
    ItemPriceHistory,
)
from modules.customs_tariff.model import CustomsTariff


def backfill_master_items(
    db_url: Optional[str] = None,
    dry_run: bool = False,
) -> dict:
    url = db_url or DATABASE_URL
    print(f"[backfill] Connecting to database: {url}")
    engine = create_engine(url)
    SessionLocal = sessionmaker(bind=engine)
    session: Session = SessionLocal()

    stats = {
        "items_created": 0,
        "items_existing": 0,
        "po_lines_linked": 0,
        "packing_lines_linked": 0,
        "supplier_catalogs_linked": 0,
        "price_history_records": 0,
    }

    try:
        po_lines = session.query(POLineItem).all()
        print(f"[backfill] Found {len(po_lines)} po_line_items to inspect.")

        # Cache existing master items by item_code
        existing_items = {
            item.item_code: item
            for item in session.query(MasterItem).all()
        }

        # 1. Backfill master_items
        for line in po_lines:
            raw_code = (line.item_code or "").strip()
            if not raw_code:
                continue

            item = existing_items.get(raw_code)
            if not item:
                # Resolve tariff rates if tariff_id is present
                duty_rate = None
                vat_rate = None
                sched_rate = None
                if line.tariff_id:
                    tariff = session.query(CustomsTariff).filter(
                        CustomsTariff.tariff_id == line.tariff_id
                    ).first()
                    if tariff:
                        duty_rate = float(tariff.customs_duty_rate or 0.0)
                        vat_rate = float(tariff.vat_rate or 0.0)
                        sched_rate = float(tariff.schedule_tax_rate or 0.0)

                desc_ar = (line.description_ar or line.main_description or raw_code).strip()
                desc_en = (line.description_en or line.main_description or raw_code).strip()

                item = MasterItem(
                    item_code=raw_code,
                    description_ar=desc_ar,
                    description_en=desc_en,
                    tariff_id=line.tariff_id,
                    default_uom=line.unit_of_measure or "PCS",
                    cbm_per_unit=float(line.cbm_per_unit or 0.0),
                    gross_weight_kg=float(line.gross_weight_kg or 0.0),
                    net_weight_kg=float(line.net_weight_kg or 0.0),
                    last_customs_duty_pct=duty_rate,
                    last_vat_pct=vat_rate,
                    last_schedule_tax_pct=sched_rate,
                    created_by="system_backfill",
                )
                session.add(item)
                session.flush()
                existing_items[raw_code] = item
                stats["items_created"] += 1
            else:
                stats["items_existing"] += 1

            # Link po_line_item
            if line.master_item_id != item.item_id:
                line.master_item_id = item.item_id
                stats["po_lines_linked"] += 1

            # Get parent PO
            po = line.purchase_order
            if po and po.supplier_id:
                # Check / seed supplier catalog link
                cat_link = session.query(ItemSupplierCatalog).filter(
                    ItemSupplierCatalog.item_id == item.item_id,
                    ItemSupplierCatalog.supplier_id == po.supplier_id,
                ).first()

                price_fx = float(line.unit_price or 0.0)
                curr = po.currency.currency_code if po.currency else "USD"

                if not cat_link:
                    cat_link = ItemSupplierCatalog(
                        item_id=item.item_id,
                        supplier_id=po.supplier_id,
                        supplier_item_code=raw_code,
                        supplier_description=desc_en if 'desc_en' in locals() else item.description_en,
                        last_confirmed_price=price_fx,
                        last_confirmed_currency=curr,
                        last_confirmed_date=po.order_date.strftime("%Y-%m-%d") if po.order_date else None,
                        last_po_id=po.po_id,
                        is_preferred_supplier=True,
                    )
                    session.add(cat_link)
                    session.flush()
                    stats["supplier_catalogs_linked"] += 1

                # Check / seed price history record
                hist_exists = session.query(ItemPriceHistory).filter(
                    ItemPriceHistory.item_id == item.item_id,
                    ItemPriceHistory.po_id == po.po_id,
                ).first()

                if not hist_exists:
                    rate = float(po.exchange_rate or 1.0)
                    hist = ItemPriceHistory(
                        item_id=item.item_id,
                        supplier_id=po.supplier_id,
                        po_id=po.po_id,
                        import_file_id=po.import_file_id,
                        unit_price_fx=price_fx,
                        currency=curr,
                        exchange_rate=rate,
                        unit_price_egp=price_fx * rate,
                        quantity=float(line.quantity or 0.0),
                        po_date=po.order_date.strftime("%Y-%m-%d") if po.order_date else None,
                    )
                    session.add(hist)
                    stats["price_history_records"] += 1

        # 2. Link packing_list_items
        pkg_items = session.query(PackingListItem).all()
        for p_line in pkg_items:
            raw_code = (p_line.item_code or "").strip()
            item = existing_items.get(raw_code)
            if item and p_line.master_item_id != item.item_id:
                p_line.master_item_id = item.item_id
                stats["packing_lines_linked"] += 1

        if dry_run:
            print("[backfill] DRY RUN: rolling back changes.")
            session.rollback()
        else:
            session.commit()
            print("[backfill] Successfully committed all master_items backfill changes!")

    except Exception as exc:
        session.rollback()
        print(f"[backfill] ERROR: {exc}", file=sys.stderr)
        raise
    finally:
        session.close()

    return stats


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Backfill master_items from purchase orders.")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without committing.")
    parser.add_argument("--db-url", type=str, default=None, help="Custom database URL.")
    args = parser.parse_args()

    results = backfill_master_items(db_url=args.db_url, dry_run=args.dry_run)
    print("\n--- Backfill Results ---")
    for k, v in results.items():
        print(f"  {k}: {v}")
