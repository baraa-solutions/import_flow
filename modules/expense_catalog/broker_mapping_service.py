"""
Broker Expense Mapping Memory Service (M1-4)
Allows customs brokers to have remembered mappings between their specific raw line item names
and canonical expense catalog codes.
"""

from __future__ import annotations

import difflib
import json
import logging
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from modules.expense_catalog.seed_data import EXPENSE_CATALOG_SEED_DATA

logger = logging.getLogger(__name__)

# Data directory for persistent broker mappings
DATA_DIR = Path(__file__).resolve().parent.parent.parent / "data"
MAPPINGS_FILE = DATA_DIR / "broker_mappings.json"

_EASTERN_TO_WESTERN = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def normalize_arabic_for_matching(text: str) -> str:
    """
    High-accuracy normalization for Arabic text and numbers:
    - Normalizes eastern Arabic-Indic digits to standard western digits (٠-٩ -> 0-9)
    - Strips tashkeel / harakat (fathatan, dammatan, kasratan, fatha, damma, kasra, shadda, sukun)
    - Strips tatweel / kashida (ـ)
    - Normalizes all Alif forms (أ, إ, آ, ٱ) -> ا
    - Normalizes Taa Marbuta (ة) -> ه
    - Normalizes Yaa / Alif Maqsura (ى, ي, ئ) -> ي
    - Normalizes Waw with Hamza (ؤ) -> و
    - Replaces punctuation, parentheses, brackets, symbols with spaces
    - Collapses multiple whitespace to single space
    """
    if not text:
        return ""

    t = text.strip().lower()

    # 1. Eastern digits to western digits
    t = t.translate(_EASTERN_TO_WESTERN)

    # 2. Remove harakat / tashkeel & tatweel
    t = re.sub(r"[\u064B-\u065F\u0670\u0640]", "", t)

    # 3. Normalize Alef variants
    t = re.sub(r"[أإآٱ]", "ا", t)

    # 4. Normalize Taa Marbuta
    t = t.replace("ة", "ه")

    # 5. Normalize Yaa / Alif Maqsura / Hamza on nabira
    t = re.sub(r"[ىيئ]", "ي", t)

    # 6. Normalize Waw with Hamza
    t = t.replace("ؤ", "و")

    # 7. Strip non-alphanumeric except word characters and Arabic range
    t = re.sub(r"[^\w\s\u0600-\u06FF]", " ", t)

    # 8. Collapse spaces
    return re.sub(r"\s+", " ", t).strip()


class BrokerMappingMemoryService:
    """
    In-memory and file-backed mapping memory service for customs brokers.
    Enables automatic recognition of broker-specific terminology for expense catalog codes.
    """

    _cache: Dict[str, Dict[str, Dict[str, Any]]] = {}
    _loaded: bool = False

    @classmethod
    def _ensure_loaded(cls) -> None:
        if cls._loaded:
            return
        cls._cache = {}
        if MAPPINGS_FILE.exists():
            try:
                with open(MAPPINGS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        cls._cache = data
            except Exception as e:
                logger.warning(f"Failed to read broker mappings from {MAPPINGS_FILE}: {e}")
        cls._loaded = True

    @classmethod
    def _save_to_file(cls) -> None:
        try:
            DATA_DIR.mkdir(parents=True, exist_ok=True)
            with open(MAPPINGS_FILE, "w", encoding="utf-8") as f:
                json.dump(cls._cache, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.warning(f"Failed to save broker mappings to {MAPPINGS_FILE}: {e}")

    @classmethod
    def normalize_broker_key(cls, broker_name: Optional[str]) -> str:
        if not broker_name or not broker_name.strip():
            return "_GLOBAL_"
        norm = normalize_arabic_for_matching(broker_name)
        # Handle common ACC aliases
        if "acc" in norm or "اسكندريه للاعمال الجمركيه" in norm:
            return "acc"
        return norm

    @classmethod
    def normalize_item_key(cls, raw_item_name: str) -> str:
        return normalize_arabic_for_matching(raw_item_name)

    @classmethod
    def remember_mapping(
        cls,
        broker_name: Optional[str],
        raw_item_name: str,
        catalog_code: str,
        canonical_name_ar: Optional[str] = None,
        canonical_name_en: Optional[str] = None,
        category: Optional[str] = None,
        unit_type: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Stores or updates an extracted item -> catalog code mapping for a specific broker.
        """
        cls._ensure_loaded()
        b_key = cls.normalize_broker_key(broker_name)
        i_key = cls.normalize_item_key(raw_item_name)
        code_upper = catalog_code.strip().upper()

        # If canonical details are not supplied, find them in EXPENSE_CATALOG_SEED_DATA
        if not canonical_name_ar or not category:
            seed_match = next((s for s in EXPENSE_CATALOG_SEED_DATA if s["code"].upper() == code_upper), None)
            if seed_match:
                canonical_name_ar = canonical_name_ar or seed_match["canonical_name_ar"]
                canonical_name_en = canonical_name_en or seed_match.get("canonical_name_en")
                category = category or seed_match["category"]
                unit_type = unit_type or seed_match.get("unit_type", "fixed")

        record: Dict[str, Any] = {
            "broker_name": broker_name or "Global",
            "broker_key": b_key,
            "raw_item_name": raw_item_name.strip(),
            "item_key": i_key,
            "catalog_code": code_upper,
            "code": code_upper,
            "canonical_name_ar": canonical_name_ar or raw_item_name.strip(),
            "canonical_name_en": canonical_name_en,
            "category": category or "Clearance Fees",
            "unit_type": unit_type or "fixed",
            "confidence_score": 1.0,
            "match_confidence": "high",
            "source": "broker_memory",
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }

        if b_key not in cls._cache:
            cls._cache[b_key] = {}
        cls._cache[b_key][i_key] = record

        cls._save_to_file()
        return record

    @classmethod
    def get_mapping(
        cls,
        broker_name: Optional[str],
        raw_item_name: str,
    ) -> Optional[Dict[str, Any]]:
        """
        Retrieves a remembered mapping for a broker and item name.
        Checks broker-specific memory first, then global memory.
        """
        cls._ensure_loaded()
        if not raw_item_name or not raw_item_name.strip():
            return None

        b_key = cls.normalize_broker_key(broker_name)
        i_key = cls.normalize_item_key(raw_item_name)

        # 1. Broker-specific memory
        if b_key in cls._cache and i_key in cls._cache[b_key]:
            return dict(cls._cache[b_key][i_key])

        # 2. Check slight variations / substrings within broker memory
        if b_key in cls._cache:
            for stored_key, record in cls._cache[b_key].items():
                if stored_key == i_key:
                    return dict(record)
                if len(stored_key) >= 4 and len(i_key) >= 4:
                    if stored_key in i_key or i_key in stored_key:
                        return dict(record)
                    # SequenceMatcher for very high similarity (>= 90%)
                    ratio = difflib.SequenceMatcher(None, stored_key, i_key).ratio()
                    if ratio >= 0.90:
                        return dict(record)

        # 3. Global fallback memory
        if "_GLOBAL_" in cls._cache and i_key in cls._cache["_GLOBAL_"]:
            return dict(cls._cache["_GLOBAL_"][i_key])

        return None

    @classmethod
    def list_mappings(cls, broker_name: Optional[str] = None) -> List[Dict[str, Any]]:
        """Lists all remembered mappings, optionally filtered by broker."""
        cls._ensure_loaded()
        results: List[Dict[str, Any]] = []
        if broker_name:
            b_key = cls.normalize_broker_key(broker_name)
            if b_key in cls._cache:
                results.extend(cls._cache[b_key].values())
        else:
            for b_dict in cls._cache.values():
                results.extend(b_dict.values())
        return results

    @classmethod
    def delete_mapping(cls, broker_name: Optional[str], raw_item_name: str) -> bool:
        """Deletes a remembered mapping."""
        cls._ensure_loaded()
        b_key = cls.normalize_broker_key(broker_name)
        i_key = cls.normalize_item_key(raw_item_name)
        if b_key in cls._cache and i_key in cls._cache[b_key]:
            del cls._cache[b_key][i_key]
            if not cls._cache[b_key]:
                del cls._cache[b_key]
            cls._save_to_file()
            return True
        return False

    @classmethod
    def clear_memory(cls) -> None:
        """Clears in-memory cache and optionally cleans file for test isolation."""
        cls._cache = {}
        cls._loaded = True
        if MAPPINGS_FILE.exists():
            try:
                os.remove(MAPPINGS_FILE)
            except Exception:
                pass
