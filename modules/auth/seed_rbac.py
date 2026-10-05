"""
Seed RBAC Catalog & Standard Roles
==================================
Idempotently seeds:
1. Complete system permissions catalog (~38 atomic permissions).
2. Standard 6 system roles:
   - ADMIN
   - GENERAL_MANAGER
   - LOGISTICS_OPERATOR
   - CUSTOMS_OFFICER
   - FINANCE_OFFICER
   - AUDITOR_VIEWER
3. Assigns corresponding role_permissions to each role.
4. Migrates existing system users to link them to their standard role_id.
"""
from typing import Any, Dict, List, Tuple
from sqlalchemy.orm import Session
from modules.common.system_parameters import SystemParameter
from modules.users.model import User, Role, Permission, RolePermission, UserPermission


PERMISSIONS_CATALOG = [
    # 1. Import Files
    {"code": "import_files.view", "module": "import_files", "action": "view", "en": "View Import Files", "ar": "عرض ملفات الاستيراد", "desc": "Can view import files list, filters, and full file overview"},
    {"code": "import_files.create", "module": "import_files", "action": "create", "en": "Create Import File", "ar": "إنشاء ملف استيراد جديد", "desc": "Can create new import operation files"},
    {"code": "import_files.edit", "module": "import_files", "action": "edit", "en": "Edit Import File", "ar": "تعديل بيانات ملف الاستيراد", "desc": "Can update import file metadata, link POs, and change parameters"},
    {"code": "import_files.close", "module": "import_files", "action": "close", "en": "Close Import File", "ar": "إغلاق ملف الاستيراد نهائياً", "desc": "Can perform final administrative closure and lock the import file"},

    # 2. Lifecycle Board
    {"code": "lifecycle_board.view", "module": "lifecycle_board", "action": "view", "en": "View Lifecycle Board", "ar": "عرض لوحة دورة حياة الشحنات", "desc": "Can view 6-phase / 21-step operational board"},
    {"code": "lifecycle_board.advance", "module": "lifecycle_board", "action": "advance", "en": "Advance Lifecycle Step", "ar": "تحريك خطوة الشحنة يدوياً", "desc": "Can manually transition shipment phases and steps"},

    # 3. Purchase Orders
    {"code": "purchase_orders.view", "module": "purchase_orders", "action": "view", "en": "View Purchase Orders", "ar": "عرض أوامر الشراء", "desc": "Can view purchase orders and line item items"},
    {"code": "purchase_orders.create", "module": "purchase_orders", "action": "create", "en": "Create Purchase Order", "ar": "إنشاء أمر شراء", "desc": "Can issue new purchase orders"},
    {"code": "purchase_orders.edit", "module": "purchase_orders", "action": "edit", "en": "Edit Purchase Order", "ar": "تعديل أمر شراء", "desc": "Can modify line items, quantities, and terms in POs"},
    {"code": "purchase_orders.delete", "module": "purchase_orders", "action": "delete", "en": "Delete / Restore Purchase Order", "ar": "حذف واستعادة أمر شراء", "desc": "Can soft-delete purchase orders and restore deleted ones"},

    # 3b. Import planning tools (Phase 1)
    {"code": "cbm.manage", "module": "cbm_calculator", "action": "manage", "en": "Manage CBM Calculations", "ar": "إدارة حسابات الحجم والأوزان (CBM)", "desc": "Can create, edit, delete and link CBM calculations to purchase orders"},
    {"code": "shipping_scenarios.manage", "module": "shipping_scenarios", "action": "manage", "en": "Manage Shipping Scenarios", "ar": "إدارة سيناريوهات الشحن", "desc": "Can create, edit, delete and select shipping scenario evaluations"},
    {"code": "customs_consultation.manage", "module": "customs_consultation", "action": "manage", "en": "Manage Customs Consultations", "ar": "إدارة الاستشارات الجمركية", "desc": "Can create and edit customs consultation sessions, broker quotes and price lists"},
    {"code": "import_requirements.manage", "module": "import_requirements", "action": "manage", "en": "Manage Import Requirements", "ar": "إدارة متطلبات الاستيراد", "desc": "Can create and edit import requirement assessments"},

    # 4. Freight Booking
    {"code": "freight_booking.view", "module": "freight_booking", "action": "view", "en": "View Freight Bookings", "ar": "عرض حجوزات الشحن", "desc": "Can view freight booking requests and reservations"},
    {"code": "freight_booking.create", "module": "freight_booking", "action": "create", "en": "Create Freight Booking", "ar": "طلب وحجز الشحن", "desc": "Can initiate freight bookings with forwarders"},
    {"code": "freight_booking.confirm", "module": "freight_booking", "action": "confirm", "en": "Confirm Freight Booking", "ar": "تأكيد حجز الشحن واعتماد البوليصة", "desc": "Can confirm booking and register Master/House Bill of Lading"},

    # 5. Cargo Shipping & Tracking
    {"code": "cargo_shipping.view", "module": "cargo_shipping", "action": "view", "en": "View Cargo Shipping", "ar": "عرض حركة الشحن وتتبع البواخر", "desc": "Can view vessel schedules and tracking waypoints"},
    {"code": "cargo_shipping.update", "module": "cargo_shipping", "action": "update", "en": "Update Shipping Status", "ar": "تحديث حالة السفينة وتتبع المسار", "desc": "Can log arrival notices, vessel discharge, and milestones"},
    {"code": "cargo_shipping.approve", "module": "cargo_shipping", "action": "approve", "en": "Approve Shipping Documents (Level 2)", "ar": "الاعتماد الثاني لمستندات الشحن وتقدم CargoX", "desc": "Can grant level-2 approval of cargo shipping documents and advance CargoX stages"},
    {"code": "cargo_insurance.view", "module": "cargo_insurance", "action": "view", "en": "View Cargo Insurance", "ar": "عرض وثائق تأمين البضائع", "desc": "Can view cargo insurance certificates and premium calculations"},
    {"code": "cargo_insurance.manage", "module": "cargo_insurance", "action": "manage", "en": "Manage Cargo Insurance", "ar": "إصدار وتعديل وثائق تأمين البضائع", "desc": "Can create, edit, issue and cancel cargo insurance certificates"},

    # 6. Customs Clearance
    {"code": "customs_clearance.view", "module": "customs_clearance", "action": "view", "en": "View Customs Files", "ar": "عرض ملفات التخليص الجمركي", "desc": "Can view customs clearance records, 46 forms, and declarations"},
    {"code": "customs_clearance.update", "module": "customs_clearance", "action": "update", "en": "Update Customs Status", "ar": "تحديث الكشف ونموذج 46", "desc": "Can record inspection dates, tariff reviews, and clearance stages"},
    {"code": "customs_clearance.release", "module": "customs_clearance", "action": "release", "en": "Issue Customs Release", "ar": "إصدار الإفراج الجمركي النهائي", "desc": "Can finalize clearance and register formal release certificate"},

    # 7. Customs Tariff & HS Codes
    {"code": "customs_tariff.view", "module": "customs_tariff", "action": "view", "en": "View Customs Tariff", "ar": "استعراض جدول التعريفة الجمركية", "desc": "Can browse Egyptian HS codes, duties, and taxes schedule"},
    {"code": "customs_tariff.edit", "module": "customs_tariff", "action": "edit", "en": "Edit Customs Tariff", "ar": "تعديل بنود التعريفة والضرائب", "desc": "Can update duty percentages, VAT, fees, and trade agreements"},

    # 8. CargoX & Nafeza ACID
    {"code": "cargox_nafeza.view", "module": "cargox_nafeza", "action": "view", "en": "View CargoX & ACID", "ar": "عرض بيانات كارجو إكس ورقم ACID", "desc": "Can view ACID registration numbers, envelopes, and dispatch logs"},
    {"code": "cargox_nafeza.manage", "module": "cargox_nafeza", "action": "manage", "en": "Manage CargoX & ACID", "ar": "إدارة ورفع مستندات كارجو إكس ونافذة", "desc": "Can request ACID numbers and transmit digital envelopes on CargoX"},

    # 9. Import Documentation
    {"code": "import_documentation.view", "module": "import_documentation", "action": "view", "en": "View Shipping Documents", "ar": "استعراض مستندات الشحن والمطابقة", "desc": "Can view packing lists, commercial invoices, and certificates of origin"},
    {"code": "import_documentation.upload", "module": "import_documentation", "action": "upload", "en": "Upload & Approve Docs", "ar": "رفع واعتماد مستندات الشحنة", "desc": "Can upload original documents and execute reconciliation"},
    {"code": "import_documentation.approve", "module": "import_documentation", "action": "approve", "en": "Approve Shipping Documents", "ar": "اعتماد مستندات الشحن (البوليصة المسودة)", "desc": "Can approve draft B/L reviews and sign off shipping documents"},

    # 10. Financial Approval
    {"code": "financial_approval.view", "module": "financial_approval", "action": "view", "en": "View Payment Requests", "ar": "عرض طلبات الصرف وموازنات الاستيراد", "desc": "Can review budget requests, customs duty vouchers, and payments"},
    {"code": "financial_approval.approve", "module": "financial_approval", "action": "approve", "en": "Approve Payments", "ar": "اعتماد طلبات الصرف المالي", "desc": "Can grant financial approval for customs duties, freight, and invoices"},
    {"code": "financial_approval.manage", "module": "financial_approval", "action": "manage", "en": "Create & Edit Payment Requests", "ar": "إنشاء وتعديل طلبات الصرف والموازنات", "desc": "Can create, edit and delete draft payment requests and import budgets (approval needs financial_approval.approve)"},
    {"code": "budget.sync_variance", "module": "financial_approval", "action": "sync_variance", "en": "Sync Budget Variance", "ar": "مزامنة فوارق الميزانية بالتكاليف الحية", "desc": "Can synchronize live upstream variances, override hard blocks with justification, and manage budget revisions"},

    # 11. Financial Settlement & Landed Cost
    {"code": "financial_settlement.view", "module": "financial_settlement", "action": "view", "en": "View Landed Cost", "ar": "عرض تسويات التكلفة الكلية", "desc": "Can view landed cost calculations and cost breakdowns"},
    {"code": "financial_settlement.calculate", "module": "financial_settlement", "action": "calculate", "en": "Calculate Landed Cost", "ar": "حساب واعتماد تكلفة الوصول", "desc": "Can execute and lock final per-unit landed cost settlement"},

    # 12. Warehouse Receiving
    {"code": "warehouse_receiving.view", "module": "warehouse_receiving", "action": "view", "en": "View Warehouse Receiving", "ar": "عرض استلامات المخازن", "desc": "Can view delivery vouchers and warehouse receipts"},
    {"code": "warehouse_receiving.receive", "module": "warehouse_receiving", "action": "receive", "en": "Receive Goods", "ar": "فحص وتسجيل الاستلام بالمستودع", "desc": "Can log physical inspection, container de-stuffing, and damages"},

    # 13. Demurrage & Detention
    {"code": "demurrage_detention.view", "module": "demurrage_detention", "action": "view", "en": "View Demurrage", "ar": "متابعة غرامات الأرضيات والحاويات", "desc": "Can view container free time countdowns and demurrage penalties"},
    {"code": "demurrage_detention.manage", "module": "demurrage_detention", "action": "manage", "en": "Manage Demurrage", "ar": "إدارة سياسات وتتبع الأرضيات", "desc": "Can configure free time tiers and calculate demurrage accruals"},

    # 14. Quotations
    {"code": "quotations.view", "module": "quotations", "action": "view", "en": "View Quotations", "ar": "عرض عروض أسعار الشحن والتخليص", "desc": "Can view shipping and clearance rate comparisons"},
    {"code": "quotations.manage", "module": "quotations", "action": "manage", "en": "Manage Quotations", "ar": "إنشاء ومقارنة وترسية عروض الأسعار", "desc": "Can request RFQs, record freight quotes, and award shipments"},

    # 15. Master Data
    {"code": "master_data.view", "module": "master_data", "action": "view", "en": "View Master Data", "ar": "عرض البيانات المرجعية والشركات والموانئ", "desc": "Can view companies, suppliers, ports, currencies, and incoterms"},
    {"code": "master_data.edit", "module": "master_data", "action": "edit", "en": "Edit Master Data", "ar": "إضافة وتعديل البيانات المرجعية الأساسية", "desc": "Can create and modify companies, suppliers, ports, and currencies"},

    # 16. Users & Security
    {"code": "users.view", "module": "users_and_security", "action": "view", "en": "View Users & Roles", "ar": "استعراض قائمة المستخدمين والأدوار", "desc": "Can view users list and role assignments"},
    {"code": "users.manage", "module": "users_and_security", "action": "manage", "en": "Manage Users & Permissions", "ar": "إدارة المستخدمين والأدوار والصلاحيات", "desc": "Can create, modify, deactivate users and assign permissions"},

    # 17. Audit Logs
    {"code": "audit_logs.view", "module": "audit_logs", "action": "view", "en": "View Audit Logs", "ar": "استعراض سجل العمليات والرقابة", "desc": "Can view full system audit trails and user activity logs"},

    # 18. Reports & Analytics
    {"code": "reports.view", "module": "reports_and_analytics", "action": "view", "en": "View Reports & Dashboards", "ar": "استعراض التقارير الإدارية والتحليلات", "desc": "Can view operational KPIs and summary dashboards"},
    {"code": "reports.export", "module": "reports_and_analytics", "action": "export", "en": "Export Reports", "ar": "تصدير التقارير المالية والتشغيلية", "desc": "Can export reports to Excel, PDF, or CSV"},

    # 19. System Updates (granted to ADMIN only, through the "*" wildcard)
    {"code": "system.update", "module": "system", "action": "update", "en": "Install System Updates", "ar": "تنزيل وتثبيت تحديثات النظام", "desc": "Can download, install and roll back application updates"},
]


ROLES_CONFIG = [
    {
        "code": "ADMIN",
        "name_en": "System Administrator",
        "name_ar": "مدير النظام",
        "desc": "Full unrestricted system access with superuser privileges",
        "is_system": True,
        "permissions": ["*"],  # All permissions
    },
    {
        "code": "GENERAL_MANAGER",
        "name_en": "General Logistics Manager",
        "name_ar": "مدير عام اللوجستيات",
        "desc": "Comprehensive oversight, approvals, reports export, and closure rights",
        "is_system": True,
        "permissions": [
            "import_files.view", "import_files.close",
            "lifecycle_board.view", "lifecycle_board.advance",
            "purchase_orders.view", "purchase_orders.create", "purchase_orders.edit",
            "purchase_orders.delete", "cbm.manage", "shipping_scenarios.manage",
            "customs_consultation.manage", "import_requirements.manage",
            "freight_booking.view", "freight_booking.confirm",
            "cargo_insurance.view",
            "cargo_shipping.view", "cargo_shipping.approve",
            "customs_clearance.view", "customs_clearance.release",
            "customs_tariff.view",
            "cargox_nafeza.view",
            "import_documentation.view", "import_documentation.approve",
            "financial_approval.view", "financial_approval.approve", "financial_approval.manage", "budget.sync_variance",
            "financial_settlement.view", "financial_settlement.calculate",
            "warehouse_receiving.view",
            "demurrage_detention.view",
            "quotations.view", "quotations.manage",
            "master_data.view",
            "users.view",
            "audit_logs.view",
            "reports.view", "reports.export",
        ],
    },
    {
        "code": "LOGISTICS_OPERATOR",
        "name_en": "Logistics Operations Specialist",
        "name_ar": "أخصائي عمليات لوجستية",
        "desc": "Operational booking, tracking, receiving, and order coordination",
        "is_system": True,
        "permissions": [
            "import_files.view", "import_files.create", "import_files.edit",
            "lifecycle_board.view", "lifecycle_board.advance",
            "purchase_orders.view", "purchase_orders.create", "purchase_orders.edit",
            "cbm.manage", "shipping_scenarios.manage", "import_requirements.manage",
            "customs_clearance.view",  # requirements / shipment-update screens read GET /customs-consultations
            "financial_approval.view", "financial_approval.manage",  # advance / duty payment requests raised from operational screens
            "freight_booking.view", "freight_booking.create", "freight_booking.confirm",
            "cargo_insurance.view", "cargo_insurance.manage",
            "cargo_shipping.view", "cargo_shipping.update", "cargo_shipping.approve",
            "import_documentation.view", "import_documentation.upload", "import_documentation.approve",
            "warehouse_receiving.view", "warehouse_receiving.receive",
            "demurrage_detention.view", "demurrage_detention.manage",
            "quotations.view", "quotations.manage",
            "master_data.view",
            "reports.view",
        ],
    },
    {
        "code": "CUSTOMS_OFFICER",
        "name_en": "Customs Clearance Officer",
        "name_ar": "أخصائي تخليص جمركي",
        "desc": "Customs clearance, 46 forms, CargoX/Nafeza, and tariff classifications",
        "is_system": True,
        "permissions": [
            "import_files.view",
            "lifecycle_board.view", "lifecycle_board.advance",
            "customs_clearance.view", "customs_clearance.update", "customs_clearance.release",
            "customs_consultation.manage",
            "financial_approval.view", "financial_approval.manage",  # customs duty payment requests
            "quotations.view", "quotations.manage",  # consultation screen: shipping scenarios + broker RFQs / price lists
            "customs_tariff.view", "customs_tariff.edit",
            "cargox_nafeza.view", "cargox_nafeza.manage",
            "import_documentation.view", "import_documentation.upload", "import_documentation.approve",
            "demurrage_detention.view",
            "master_data.view",
            "reports.view",
        ],
    },
    {
        "code": "FINANCE_OFFICER",
        "name_en": "Financial Officer",
        "name_ar": "مسؤول مالي",
        "desc": "Payment vouchers, budget approvals, and landed cost settlements",
        "is_system": True,
        "permissions": [
            "import_files.view",
            "lifecycle_board.view",
            "purchase_orders.view",
            "financial_approval.view", "financial_approval.approve", "financial_approval.manage", "budget.sync_variance",
            "financial_settlement.view", "financial_settlement.calculate",
            "quotations.view",
            "master_data.view",
            "reports.view", "reports.export",
        ],
    },
    {
        "code": "AUDITOR_VIEWER",
        "name_en": "Auditor / Read-Only Viewer",
        "name_ar": "مراجع ومشاهد",
        "desc": "Read-only access across operational modules, audit logs, and reports",
        "is_system": True,
        "permissions": [
            "import_files.view",
            "lifecycle_board.view",
            "purchase_orders.view",
            "freight_booking.view",
            "cargo_insurance.view",
            "cargo_shipping.view",
            "customs_clearance.view",
            "customs_tariff.view",
            "cargox_nafeza.view",
            "import_documentation.view",
            "financial_approval.view",
            "financial_settlement.view",
            "warehouse_receiving.view",
            "demurrage_detention.view",
            "quotations.view",
            "master_data.view",
            "users.view",
            "audit_logs.view",
            "reports.view",
        ],
    },
]


# Built-in roles: a code from ROLES_CONFIG is linked only when the role is created, or when the code itself is
# inserted into the catalog in the same run. Codes an admin removes from a built-in role stay removed after a
# restart. Grants added later to an existing code go through ONE_TIME_ROLE_GRANTS.

# New permission code -> the existing code whose holders get it ONCE, in the run that inserts the new code:
# every role (built-in or custom) holding the source code and every per-user override of it (a revoke is copied
# as a revoke). It never runs again, so removing the new code from any role afterwards sticks.
# purchase_orders.delete is deliberately absent: delete/restore is manager-level (ADMIN, GENERAL_MANAGER).
DERIVED_GRANTS: Dict[str, str] = {
    "cbm.manage": "purchase_orders.edit",
    "shipping_scenarios.manage": "quotations.manage",
    "customs_consultation.manage": "customs_clearance.update",
    "import_requirements.manage": "import_files.edit",
    "import_documentation.approve": "import_documentation.upload",
    "financial_approval.manage": "financial_approval.approve",
    "cargo_shipping.approve": "cargo_shipping.update",
    "cargo_insurance.view": "freight_booking.view",
    "cargo_insurance.manage": "freight_booking.create",
}


# Grants of EXISTING codes added to built-in roles after their creation: batch id -> {role code: codes}. Applied
# once per database (batch ids recorded in system_parameters[RBAC_GRANT_BATCHES_KEY]); fresh databases get the
# same links from ROLES_CONFIG and just record the batch.
RBAC_GRANT_BATCHES_KEY = "RBAC_ONE_TIME_GRANT_BATCHES"
ONE_TIME_ROLE_GRANTS: Dict[str, Dict[str, Tuple[str, ...]]] = {
    # Phase 1 read access for screens that read another module's list (lead decision 2026-10-05)
    "2026-10-05-phase1-read-grants": {
        "CUSTOMS_OFFICER": ("quotations.view",),
        "LOGISTICS_OPERATOR": ("customs_clearance.view",),
    },
    # Phase 2 review: operational roles raise payment requests and need the prefill / list reads
    "2026-10-05-phase2-financial-read-grants": {
        "LOGISTICS_OPERATOR": ("financial_approval.view",),
        "CUSTOMS_OFFICER": ("financial_approval.view",),
    },
    # Phase 6-7 review: the consultation screen embeds the broker RFQ / price-list tab (quotations.manage writes)
    "2026-10-05-phase67-customs-quotation-grants": {
        "CUSTOMS_OFFICER": ("quotations.manage",),
    },
    # Field report 2026-10-05: the General Logistics Manager raises purchase orders (403 on create since Phase 1)
    "2026-10-05-gm-purchase-order-grants": {
        "GENERAL_MANAGER": ("purchase_orders.create", "purchase_orders.edit"),
    },
}


def _apply_one_time_role_grants(db: Session, roles: Dict[str, Role], perms: Dict[str, Permission]) -> int:
    """Link every not yet applied ONE_TIME_ROLE_GRANTS batch and record it. No commit (caller commits)."""
    marker = db.query(SystemParameter).filter(SystemParameter.param_key == RBAC_GRANT_BATCHES_KEY).first()
    applied = set(filter(None, (marker.param_value if marker else "").split(",")))
    linked = 0
    for batch_id, grants in ONE_TIME_ROLE_GRANTS.items():
        if batch_id in applied:
            continue
        for role_code, codes in grants.items():
            role = roles.get(role_code)
            if role is None:
                continue
            have = {rp.permission_id for rp in db.query(RolePermission).filter(RolePermission.role_id == role.role_id)}
            for code in codes:
                perm = perms.get(code)
                if perm is not None and perm.permission_id not in have:
                    db.add(RolePermission(role_id=role.role_id, permission_id=perm.permission_id))
                    linked += 1
        applied.add(batch_id)
    value = ",".join(sorted(applied))
    if marker is None:
        db.add(SystemParameter(param_key=RBAC_GRANT_BATCHES_KEY, param_value=value, created_by="system", updated_by="system",
                               description="One-time RBAC grant batches already applied (seed_rbac)"))
    elif marker.param_value != value:
        marker.param_value = value
        marker.updated_by = "system"
    return linked


def _copy_grants(db: Session, new_perm: Permission, source_perm: Permission) -> int:
    """Grant ``new_perm`` to every role holding ``source_perm`` and copy per-user overrides of it."""
    linked = 0
    role_ids = {rp.role_id for rp in db.query(RolePermission).filter(RolePermission.permission_id == source_perm.permission_id)}
    have = {rp.role_id for rp in db.query(RolePermission).filter(RolePermission.permission_id == new_perm.permission_id)}
    for role_id in sorted(role_ids - have):
        db.add(RolePermission(role_id=role_id, permission_id=new_perm.permission_id))
        linked += 1
    user_have = {up.user_id for up in db.query(UserPermission).filter(UserPermission.permission_id == new_perm.permission_id)}
    for up in db.query(UserPermission).filter(UserPermission.permission_id == source_perm.permission_id).all():
        if up.user_id not in user_have:
            db.add(UserPermission(user_id=up.user_id, permission_id=new_perm.permission_id,
                                  is_granted=up.is_granted, granted_by=up.granted_by))
            linked += 1
    return linked


def seed_rbac(db: Session) -> Dict[str, Any]:
    """
    Idempotent seeding of permissions, standard roles, role_permissions,
    and user role linkages. One transaction (flushes, single final commit): codes inserted in this run and their
    role links / grant copies are committed together, so a crash never leaves a "known" code without its links.
    """
    perms_added = 0
    roles_added = 0
    role_perms_linked = 0
    users_migrated = 0

    # 1. Upsert Permissions
    existing_perms = {p.permission_code: p for p in db.query(Permission).all()}
    new_codes = set()
    for item in PERMISSIONS_CATALOG:
        code = item["code"]
        if code not in existing_perms:
            perm = Permission(
                permission_code=code,
                module_name=item["module"],
                action=item["action"],
                name_en=item["en"],
                name_ar=item["ar"],
                description=item.get("desc"),
            )
            db.add(perm)
            perms_added += 1
            new_codes.add(code)
        else:
            # Update fields if modified
            perm = existing_perms[code]
            perm.module_name = item["module"]
            perm.action = item["action"]
            perm.name_en = item["en"]
            perm.name_ar = item["ar"]
            perm.description = item.get("desc")

    db.flush()

    # Re-fetch all permissions map
    all_perms_map = {p.permission_code: p for p in db.query(Permission).all()}

    # 1b. One-time grant copy for newly introduced dedicated codes (existing DBs only: the source code
    # must already exist, otherwise this is a fresh catalog and the role config below is authoritative).
    for new_code, source_code in DERIVED_GRANTS.items():
        if new_code in new_codes and source_code in existing_perms:
            role_perms_linked += _copy_grants(db, all_perms_map[new_code], all_perms_map[source_code])
    db.flush()

    # 2. Upsert Roles & Role Permissions
    existing_roles = {r.role_code: r for r in db.query(Role).all()}

    for role_data in ROLES_CONFIG:
        code = role_data["code"]
        role = existing_roles.get(code)
        role_created = role is None
        if not role:
            role = Role(
                role_code=code,
                name_en=role_data["name_en"],
                name_ar=role_data["name_ar"],
                description=role_data.get("desc"),
                is_system_role=role_data.get("is_system", False),
                is_active=True,
            )
            db.add(role)
            db.flush()
            db.refresh(role)
            roles_added += 1
            existing_roles[code] = role
        else:
            role.name_en = role_data["name_en"]
            role.name_ar = role_data["name_ar"]
            role.description = role_data.get("desc")
            role.is_system_role = role_data.get("is_system", False)
            db.flush()

        # Link permissions to the role: all of them for a new role, only codes inserted in this run otherwise
        target_perm_codes = role_data["permissions"]
        if "*" in target_perm_codes:
            target_perm_codes = list(all_perms_map)
        perm_ids = [
            all_perms_map[c].permission_id
            for c in target_perm_codes
            if c in all_perms_map and (role_created or c in new_codes)
        ]

        current_rp_perm_ids = {
            rp.permission_id for rp in db.query(RolePermission).filter(RolePermission.role_id == role.role_id).all()
        }

        for pid in perm_ids:
            if pid not in current_rp_perm_ids:
                rp = RolePermission(role_id=role.role_id, permission_id=pid)
                db.add(rp)
                role_perms_linked += 1

    db.flush()  # the one-time batches must see the links added above (no duplicate rows)
    role_perms_linked += _apply_one_time_role_grants(db, existing_roles, all_perms_map)
    db.flush()

    # 3. Migrate / Link Existing Users to their Roles
    admin_role = existing_roles.get("ADMIN")
    manager_role = existing_roles.get("GENERAL_MANAGER")
    operator_role = existing_roles.get("LOGISTICS_OPERATOR")

    users = db.query(User).all()
    for u in users:
        if u.role_id is None:
            if (u.role or "").upper() == "ADMIN" and admin_role:  # same case-insensitive rule as is_admin_user
                u.role_id = admin_role.role_id
                users_migrated += 1
            elif u.role == "MANAGER" and manager_role:
                u.role_id = manager_role.role_id
                users_migrated += 1
            elif u.role == "OPERATOR" and operator_role:
                u.role_id = operator_role.role_id
                users_migrated += 1

    db.commit()  # the whole seed is one transaction: a failure anywhere leaves nothing half-linked

    return {
        "permissions_catalog_total": len(PERMISSIONS_CATALOG),
        "permissions_added": perms_added,
        "roles_added": roles_added,
        "role_permissions_linked": role_perms_linked,
        "users_migrated": users_migrated,
    }
