"""
Repository for Inbound Email Logs & Smart Task Generation (INT-EMAIL-010)
"""

from typing import List, Optional, Tuple
from datetime import datetime, timezone, date
from sqlalchemy.orm import Session
from sqlalchemy import desc

from .model import InboundEmailLog, EmailSettings
from .crypto import encrypt_email_password, is_encrypted_with_current_key
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask


def create_email_log(db: Session, data: dict, user: str = "SmartEmailListener") -> InboundEmailLog:
    log = InboundEmailLog(
        sender_email=data.get("sender_email", ""),
        subject=data.get("subject", ""),
        body_text=data.get("body_text", ""),
        email_type=data.get("email_type", "Arrival Notice"),
        extracted_bl_number=data.get("extracted_bl_number"),
        extracted_eta=data.get("extracted_eta"),
        extracted_vessel=data.get("extracted_vessel"),
        extracted_voyage=data.get("extracted_voyage"),
        extracted_containers=data.get("extracted_containers"),
        import_file_id=data.get("import_file_id"),
        processing_status=data.get("processing_status", "Processed"),
        task_id=data.get("task_id"),
        notes=data.get("notes"),
        created_by=user,
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


def get_email_logs(db: Session, limit: int = 50, offset: int = 0) -> List[InboundEmailLog]:
    return (
        db.query(InboundEmailLog)
        .filter(InboundEmailLog.is_active == True)
        .order_by(desc(InboundEmailLog.received_at))
        .offset(offset)
        .limit(limit)
        .all()
    )


def get_email_log_by_id(db: Session, email_id: int) -> Optional[InboundEmailLog]:
    return (
        db.query(InboundEmailLog)
        .filter(InboundEmailLog.email_id == email_id, InboundEmailLog.is_active == True)
        .first()
    )


def find_import_file_by_bl(db: Session, bl_number: str) -> Optional[ImportFile]:
    if not bl_number:
        return None
    clean_bl = bl_number.strip().upper()

    # 1. Search in CustomsDeclarationDraft
    from modules.import_documentation.model import CustomsDeclarationDraft, DraftBLReviewSession
    decl = (
        db.query(CustomsDeclarationDraft)
        .filter(
            CustomsDeclarationDraft.is_active == True,
            CustomsDeclarationDraft.bl_number.ilike(f"%{clean_bl}%"),
            CustomsDeclarationDraft.import_file_id.isnot(None),
        )
        .first()
    )
    if decl and decl.import_file_id:
        file = db.query(ImportFile).filter(ImportFile.import_file_id == decl.import_file_id).first()
        if file:
            return file

    # 2. Search in DraftBLReviewSession
    bl_rev = (
        db.query(DraftBLReviewSession)
        .filter(
            DraftBLReviewSession.is_active == True,
            DraftBLReviewSession.draft_bl_number.ilike(f"%{clean_bl}%"),
            DraftBLReviewSession.import_file_id.isnot(None),
        )
        .first()
    )
    if bl_rev and bl_rev.import_file_id:
        file = db.query(ImportFile).filter(ImportFile.import_file_id == bl_rev.import_file_id).first()
        if file:
            return file

    # 3. Search in CargoXEnvelope
    from modules.cargox.model import CargoXEnvelope
    envelope = (
        db.query(CargoXEnvelope)
        .filter(
            CargoXEnvelope.is_active == True,
            CargoXEnvelope.bl_number.ilike(f"%{clean_bl}%"),
            CargoXEnvelope.import_file_id.isnot(None),
        )
        .first()
    )
    if envelope and envelope.import_file_id:
        file = db.query(ImportFile).filter(ImportFile.import_file_id == envelope.import_file_id).first()
        if file:
            return file

    # 4. Fallback search on ImportFile notes or custom_file_number
    return (
        db.query(ImportFile)
        .filter(
            ImportFile.is_active == True,
            (ImportFile.custom_file_number.ilike(f"%{clean_bl}%"))
            | (ImportFile.notes.ilike(f"%{clean_bl}%")),
        )
        .first()
    )


def find_matching_import_file(
    db: Session,
    bl_number: Optional[str] = None,
    acid_number: Optional[str] = None,
    po_number: Optional[str] = None,
    file_code: Optional[str] = None,
    containers: Optional[List[str]] = None,
    subject: Optional[str] = None,
    body: Optional[str] = None,
) -> tuple[Optional[ImportFile], str]:
    """
    Smart multi-criteria import file matcher.
    Returns (matched_file, match_reason_description).
    """
    # 1. Explicit File Code (e.g. IMP-2026-0002)
    if file_code:
        clean_code = file_code.strip().upper()
        f = db.query(ImportFile).filter(ImportFile.is_active == True, ImportFile.import_file_code.ilike(clean_code)).first()
        if f:
            return f, f"كود الشحنة [{clean_code}]"

    # 2. Bill of Lading (B/L)
    if bl_number:
        f = find_import_file_by_bl(db, bl_number)
        if f:
            return f, f"بوليصة الشحن [{bl_number}]"

    # 3. Egyptian ACID Number (Advance Cargo Information)
    if acid_number:
        clean_acid = acid_number.strip()
        if len(clean_acid) >= 9:
            prefix = clean_acid[:11] if len(clean_acid) >= 11 else clean_acid
            f = db.query(ImportFile).filter(
                ImportFile.is_active == True,
                ImportFile.acid_number.isnot(None),
                ImportFile.acid_number.like(f"%{prefix}%"),
            ).first()
            if f:
                return f, f"رقم القيد الجمركي ACID [{clean_acid}]"

            # Also search in CustomsDeclarationDraft
            from modules.import_documentation.model import CustomsDeclarationDraft
            decl = (
                db.query(CustomsDeclarationDraft)
                .filter(
                    CustomsDeclarationDraft.is_active == True,
                    CustomsDeclarationDraft.acid_number.isnot(None),
                    CustomsDeclarationDraft.acid_number.like(f"%{prefix}%"),
                    CustomsDeclarationDraft.import_file_id.isnot(None),
                )
                .first()
            )
            if decl and decl.import_file_id:
                file = db.query(ImportFile).filter(ImportFile.import_file_id == decl.import_file_id).first()
                if file:
                    return file, f"رقم القيد الجمركي ACID [{clean_acid}]"

    # 4. Purchase Order Number (PO)
    if po_number:
        clean_po = po_number.strip().upper()
        if len(clean_po) >= 4:
            f = db.query(ImportFile).filter(
                ImportFile.is_active == True,
                (
                    (ImportFile.po_number.isnot(None) & ImportFile.po_number.ilike(f"%{clean_po}%"))
                    | (ImportFile.po_ids.isnot(None) & ImportFile.po_ids.ilike(f"%{clean_po}%"))
                ),
            ).first()
            if f:
                return f, f"أمر الشراء PO [{clean_po}]"

    # 5. ISO Containers
    if containers:
        for c in containers:
            clean_c = c.strip().upper()
            if len(clean_c) == 11:
                # Search notes or bookings
                f = db.query(ImportFile).filter(
                    ImportFile.is_active == True,
                    ImportFile.notes.isnot(None),
                    ImportFile.notes.ilike(f"%{clean_c}%"),
                ).first()
                if f:
                    return f, f"رقم الحاوية [{clean_c}]"

    # 6. Commercial Project / Shipment Name Keyword Match (Subject + Body)
    combined = f"{subject or ''} {body or ''}".lower()
    if combined.strip():
        active_files = (
            db.query(ImportFile)
            .filter(ImportFile.is_active == True)
            .order_by(desc(ImportFile.import_file_id))
            .all()
        )
        for f in active_files:
            # Check custom_file_number (e.g. "Monorail Orascom", "PET Stock")
            if f.custom_file_number and len(f.custom_file_number.strip()) >= 4:
                cfn = f.custom_file_number.strip().lower()
                # Check full phrase or significant words
                if cfn in combined:
                    return f, f"الاسم التجاري للملف [{f.custom_file_number}]"
                words = [w for w in cfn.split() if len(w) >= 4]
                if len(words) >= 2 and all(w in combined for w in words):
                    return f, f"الاسم التجاري للملف [{f.custom_file_number}]"
            # Check project_names
            if f.project_names and len(f.project_names.strip()) >= 4:
                pn = f.project_names.strip().lower()
                if pn in combined:
                    return f, f"اسم المشروع [{f.project_names}]"

    return None, ""


def update_import_file_eta(db: Session, import_file_id: int, new_eta: date) -> Optional[ImportFile]:
    file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if file:
        file.required_eta = new_eta
        file.updated_at = datetime.now(timezone.utc)

        # Also update linked ShipmentBooking if exists
        from modules.freight_booking.model import ShipmentBooking
        booking = db.query(ShipmentBooking).filter(ShipmentBooking.import_file_id == import_file_id).first()
        if booking:
            booking.eta = datetime.combine(new_eta, datetime.min.time())
            booking.updated_at = datetime.now(timezone.utc)

        db.commit()
        db.refresh(file)
    return file


def create_delivery_order_payment_task(
    db: Session,
    import_file: ImportFile,
    bl_number: Optional[str] = None,
    eta_date: Optional[date] = None,
    match_reason: Optional[str] = None,
) -> SmartTask:
    ref_display = bl_number if bl_number else (match_reason or import_file.import_file_code)
    
    # Check if a pending payment task already exists for this import file to avoid redundant duplication
    existing_task = (
        db.query(SmartTask)
        .filter(
            SmartTask.import_file_id == import_file.import_file_id,
            SmartTask.reminder_type == "Arrival Notice Payment",
            SmartTask.status.in_(["Pending", "In Progress"]),
            SmartTask.is_active == True,
        )
        .first()
    )
    if existing_task:
        return existing_task

    task_count = db.query(SmartTask).count() + 1
    task_code = f"TSK-ARV-{task_count:05d}"
    due_str = eta_date.isoformat() if eta_date else (date.today()).isoformat()

    title = f"سداد مصاريف إذن التسليم للشحنة ({import_file.import_file_code})"
    desc = (
        f"تم رصد إشعار وصول / متابعة بريدية رسمية مرتبطة بـ [{ref_display}]. "
        f"مطلوب المتابعة الفورية مع التوكيل الملاحي لسداد مصاريف إذن التسليم "
        f"والعوائد المينائية قبل وصول السفينة المتوقع بتاريخ {due_str} لتفادي أي غرامات تأخير أو أرضيات."
    )

    task = SmartTask(
        task_code=task_code,
        title=title,
        description=desc,
        task_type="System Generated",
        import_file_id=import_file.import_file_id,
        import_file_code=import_file.import_file_code,
        phase_name="Shipping & Transit",
        assigned_user="Finance Team",
        priority="High",
        reminder_type="Arrival Notice Payment",
        due_date=due_str,
        reminder_date=due_str,
        status="Pending",
        notes=f"تم التوليد التلقائي عبر المستمع الذكي للإيميلات استناداً إلى: {ref_display}",
        created_by="SmartEmailListener",
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


# ---------------------------------------------------------
# Email Settings Repository
# ---------------------------------------------------------

def get_email_settings(db: Session) -> Optional[EmailSettings]:
    return db.query(EmailSettings).filter(EmailSettings.is_active == True).first()


def save_or_update_email_settings(db: Session, data: dict, user: str = "Admin") -> EmailSettings:
    settings = db.query(EmailSettings).first()
    if not settings:
        settings = EmailSettings(
            provider_type=data.get("provider_type", "CUSTOM"),
            email_address=data["email_address"],
            username=data.get("username", data["email_address"]),
            password=data.get("password", ""),
            imap_host=data.get("imap_host", "imap.gmail.com"),
            imap_port=data.get("imap_port", 993),
            imap_use_ssl=data.get("imap_use_ssl", True),
            smtp_host=data.get("smtp_host", "smtp.gmail.com"),
            smtp_port=data.get("smtp_port", 587),
            smtp_use_tls=data.get("smtp_use_tls", True),
            smtp_use_ssl=data.get("smtp_use_ssl", False),
            sender_display_name=data.get("sender_display_name", "Sorour Logistics Operations"),
            auto_fetch_enabled=data.get("auto_fetch_enabled", False),
            fetch_interval_minutes=data.get("fetch_interval_minutes", 15),
            is_active=True,
            created_by=user,
            updated_by=user,
        )
        db.add(settings)
    else:
        for k, v in data.items():
            if hasattr(settings, k) and v is not None:
                # If password is empty string in update, don't overwrite existing, but move a value
                # stored with an older key (or legacy plaintext) to the current SECRET_KEY.
                if k == "password" and v == "":
                    stored = settings._password
                    if stored and not is_encrypted_with_current_key(stored):
                        settings._password = encrypt_email_password(stored)
                    continue
                setattr(settings, k, v)
        settings.updated_at = datetime.now(timezone.utc)
        settings.updated_by = user

    db.commit()
    db.refresh(settings)
    return settings


def rotate_stored_email_passwords(db: Session) -> int:
    """Move every stored mailbox password that is not on the current SECRET_KEY (legacy-key token or
    legacy plaintext) to the current key. Idempotent; undecryptable values are left unchanged.
    Returns the number of rows rewritten."""
    rotated = 0
    for row in db.query(EmailSettings).all():
        stored = row._password
        if not stored or is_encrypted_with_current_key(stored):
            continue
        new_value = encrypt_email_password(stored)
        if new_value != stored:
            row._password = new_value
            rotated += 1
    if rotated:
        db.commit()
    return rotated


def update_email_settings_sync_status(
    db: Session, status_str: str, message: str
) -> Optional[EmailSettings]:
    settings = db.query(EmailSettings).first()
    if settings:
        settings.last_sync_at = datetime.now(timezone.utc)
        settings.last_sync_status = status_str
        settings.last_sync_message = message
        db.commit()
        db.refresh(settings)
    return settings


def batch_approve_and_route_tasks(
    db: Session,
    tasks_list: List[dict],
    user_name: str = "User",
) -> Tuple[int, List[int]]:
    """
    Approve, route, and commit user-selected tasks with customized assigned user, priority, and due date.
    """
    approved_count = 0
    task_ids = []

    for item in tasks_list:
        file_id = item.get("import_file_id")
        file_code = item.get("import_file_code")
        title = item.get("title")
        description = item.get("description")
        assigned_user = item.get("assigned_user") or "Finance Team"
        priority = item.get("priority") or "High"
        due_date = item.get("due_date")
        reminder_type = item.get("reminder_type") or "Arrival Notice Payment"
        email_id = item.get("email_id")
        task_id = item.get("task_id")

        task = None
        if task_id:
            task = db.query(SmartTask).filter(SmartTask.task_id == task_id).first()

        if not task and file_id:
            task = (
                db.query(SmartTask)
                .filter(
                    SmartTask.import_file_id == file_id,
                    SmartTask.reminder_type == reminder_type,
                    SmartTask.status.in_(["Pending", "In Progress"]),
                    SmartTask.is_active == True,
                )
                .first()
            )

        if task:
            task.assigned_user = assigned_user
            task.priority = priority
            if due_date:
                task.due_date = due_date
                task.reminder_date = due_date
            if title:
                task.title = title
            if description:
                task.description = description
            task.updated_by = user_name
            task.updated_at = datetime.now(timezone.utc)
            db.commit()
            db.refresh(task)
        else:
            task_count = db.query(SmartTask).count() + 1
            task_code = f"TSK-ARV-{task_count:05d}"
            task = SmartTask(
                task_code=task_code,
                title=title or f"سداد مصاريف إذن التسليم ({file_code})",
                description=description or "تم الاعتماد والتوجيه عبر مراجعة البريد الذكي.",
                task_type="System Generated",
                import_file_id=file_id,
                import_file_code=file_code,
                phase_name="Shipping & Transit",
                assigned_user=assigned_user,
                priority=priority,
                reminder_type=reminder_type,
                due_date=due_date or date.today().isoformat(),
                reminder_date=due_date or date.today().isoformat(),
                status="Pending",
                notes=f"تم الاعتماد والتوجيه بواسطة المستخدم: {user_name}",
                created_by=user_name,
            )
            db.add(task)
            db.commit()
            db.refresh(task)

        approved_count += 1
        task_ids.append(task.task_id)

        if email_id:
            email_log = db.query(InboundEmailLog).filter(InboundEmailLog.email_id == email_id).first()
            if email_log:
                email_log.task_id = task.task_id
                email_log.processing_status = "Task_Created"
                db.commit()

    return approved_count, task_ids
