---
name: acid-expiry-tracker
description: Automated Egyptian ACID Expiry & Validity Tracker with customs release auto-suppression, 14-day expiry warning triggers, and Import File synchronization.
---

# ⏱️ ACID Expiry & Validity Tracker Skill (BP-014 / Nafeza Integration)

Use this skill when managing, calculating, auditing, or tracking Egyptian **ACID (Advanced Cargo Information Declaration / نافذة)** validity lifecycles, remaining days, expiry status, and customs release waivers.

---

## 🎯 Skill Overview & Purpose

The **ACID Expiry Tracker** provides real-time lifecycle monitoring of ACID registration numbers issued by Nafeza to prevent shipment delays, port demurrage penalties, and expired entry permit rejections:

1. **ACID Lifecycle & Expiry Calculation:**
   - Evaluates the standard validity window (e.g. 90-180 days from `acid_issue_date` to `acid_expiry_date`).
   - Calculates exact `days_remaining` and elapsed/remaining progress percentage relative to the current date.
2. **Status Categorization & Alert Matrix:**
   - 🟢 **Valid (ساري وصالح):** More than 14 days remaining (`alert_required = False`).
   - 🟠 **Expiring Soon (يوشك على الانتهاء):** 14 days or fewer remaining before expiration (`alert_required = True`).
   - 🔴 **Expired (منتهي الصلاحية):** Expired without customs release (`alert_required = True`).
   - ⚪ **Customs Released (صُرفت من الجمرك - معفى من التنبيه):** Once the shipment is released from customs (`is_customs_released = True`), all expiry alerts are **immediately and permanently suppressed** (`alert_required = False`).
3. **Master Import File & Nafeza Sync:**
   - Synchronizes `acid_number`, `acid_issue_date`, `acid_expiry_date`, and `is_customs_released` directly into `import_files`.
   - Displays real-time operational KPI summary cards (Valid, Expiring Soon, Expired, Released) and actionable alert tables.

---

## 🏗️ Architecture & Data Flow

```text
ACID Registration Session / Nafeza API / Input
               │
               ▼
┌────────────────────────────────────────────────────────┐
│               import_files Database Table              │
├────────────────────────────────────────────────────────┤
│ • acid_number (VARCHAR 50)                             │
│ • acid_issue_date (DATE)                               │
│ • acid_expiry_date (DATE)                              │
│ • is_customs_released (BOOLEAN)                        │
│ • customs_released_at (DATETIME)                       │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│            get_acid_tracker_service Engine             │
├────────────────────────────────────────────────────────┤
│ 1. Compute days_remaining = (acid_expiry_date - today) │
│ 2. Compute progress percentage = elapsed / total_days  │
│ 3. If is_customs_released:                             │
│       status = "Customs Released", alert = False       │
│    Else if days_remaining < 0:                         │
│       status = "Expired", alert = True                 │
│    Else if days_remaining <= 14:                       │
│       status = "Expiring Soon", alert = True           │
│    Else:                                               │
│       status = "Valid", alert = False                  │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│               Flutter UI & KPI Dashboard               │
├────────────────────────────────────────────────────────┤
│ • 4 Summary KPI Metric Cards (Valid/Expiring/Expired)  │
│ • Interactive DataTable with Color-coded Badges        │
│ • Import File Details ACID Summary Card & Progress Bar │
└────────────────────────────────────────────────────────┘
```

---

## 📐 Egyptian Customs Business Rules

1. **Rule ACID-001 (Strict 14-Day Warning Threshold):** An alert trigger is activated when `days_remaining <= 14` to allow adequate time for amendment or customs filing before penalty imposition.
2. **Rule ACID-002 (Automatic Release Suppression):** As soon as customs release approval is recorded (`is_customs_released = True`), the shipment is legally cleared through customs, and ACID expiry warnings MUST be silenced.
3. **Rule ACID-003 (Bi-directional Synchronization):** Creating or modifying an ACID registration session in `import_documentation` automatically reflects in the linked `import_files` record.

---

## 🧪 Verification & Unit Testing

- Backend Unit Test: `tests/unit/test_acid_tracker.py`
- Frontend Unit Test: `frontend/test/acid_tracker_test.dart`
