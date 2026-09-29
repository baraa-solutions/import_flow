"""
Service for Smart Email Listener & Task Generator (INT-EMAIL-010)
"""

import re
from datetime import datetime, date
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

import imaplib
import smtplib
import ssl
import base64
import email
from email.header import decode_header
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication

from .crypto import decrypt_email_password
from .schemas import (
    InboundEmailCreate,
    InboundEmailParsePreviewRequest,
    ArrivalNoticeParseResult,
    InboundEmailLogResponse,
    EmailSettingsCreate,
    EmailSettingsUpdate,
    EmailSettingsResponse,
    EmailConnectionTestRequest,
    EmailConnectionTestResult,
    InboxFetchRequest,
    InboxFetchResult,
    OutboundEmailSendRequest,
    OutboundEmailSendResult,
    TasksBatchApprovalRequest,
    TasksBatchApprovalResult,
)
from .validators import validate_email_payload
from . import repository
from modules.common.system_messages import msg as sys_msg, render_en


def parse_date_string(date_str: str) -> Optional[date]:
    clean = re.sub(r"[^\d/.-]", "", date_str).strip()
    formats = ["%Y-%m-%d", "%Y/%m/%d", "%d-%m-%Y", "%d/%m/%Y", "%Y.%m.%d", "%d.%m.%Y"]
    for fmt in formats:
        try:
            return datetime.strptime(clean, fmt).date()
        except ValueError:
            continue
    return None


COMMON_EXCLUDED_BL_WORDS = {
    "SIGNED", "LOADING", "DESCRIPTION", "ATTACHED", "CONFIRMED", "DRAFT", "COPY",
    "ORIGINAL", "TELEX", "SURRENDERED", "EXPRESS", "UEMAIL", "ACKADDIE", "RELEASE",
    "REQUEST", "DELIVERY", "CONTAINER", "SHIPMENT", "DETAILS", "STATUS", "UPDATE",
    "ISSUED", "INVOICE", "NOTICE", "ARRIVAL", "SUBJECT", "NUMBER", "REGARDS",
    "THANKS", "PLEASE", "DEAR", "CUSTOMER", "NOTIFIED", "VESSEL", "VOYAGE",
    "CARRIER", "AGENCY", "AGREEMENT", "SCHEDULE", "FORWARDER", "CUSTOMS",
}


def extract_arrival_notice_data(subject: str, body: str) -> Dict[str, Any]:
    combined_text = f"{subject}\n{body}"

    # 1. Extract B/L Number
    bl_number = None
    # Priority 1: Keyword followed by delimiter and candidate alphanumeric string
    kw_bl_match = re.search(
        r"(?:B/?L|Bill\s*of\s*Lading|بوليصة\s*(?:الشحن)?|رقم\s*البوليصة)\s*(?:No\.?|Number|#|كود|رقم)?[:\s#-]+([A-Z0-9/-]{6,25})\b",
        combined_text,
        re.IGNORECASE,
    )
    if kw_bl_match:
        candidate = kw_bl_match.group(1).upper().strip("-/ ")
        if (
            candidate not in COMMON_EXCLUDED_BL_WORDS
            and (any(c.isdigit() for c in candidate) or "-" in candidate or len(candidate) >= 8)
        ):
            bl_number = candidate

    # Priority 2: Standard ocean carrier code + identifier (excluding 11-char ISO container format)
    if not bl_number:
        for match in re.finditer(
            r"\b((?:MSC|MAEU|CMAU|COSU|ONEY|HLCU|EGLV|ZIMU|OOLU|SMLU|MEDU)[A-Z0-9]{6,18})\b",
            combined_text,
            re.IGNORECASE,
        ):
            candidate = match.group(1).upper()
            # If 4 letters ending in U + exactly 7 digits, it is an ISO container (e.g. MSCU1234567)
            if re.match(r"^[A-Z]{4}\d{7}$", candidate):
                continue
            if candidate not in COMMON_EXCLUDED_BL_WORDS:
                bl_number = candidate
                break

    # 2. Extract Egyptian ACID Number (10 to 20 digits)
    acid_number = None
    acid_match = re.search(
        r"(?:ACID|نافذة|القيد\s*المسبق|رقم\s*الـ?\s*ACID)[\s:#-]*([0-9]{9,20})\b",
        combined_text,
        re.IGNORECASE,
    )
    if acid_match:
        acid_number = acid_match.group(1).strip()

    # 3. Extract Purchase Order Number (PO / Order)
    po_number = None
    po_match = re.search(
        r"(?:P/?O\s*(?:No\.?|Number)?|Purchase\s*Order|أمر\s*(?:الشراء|التوريد)|Order(?:\s*No\.?)?)[\s:#-]*([A-Za-z0-9_/-]{4,25})\b",
        combined_text,
        re.IGNORECASE,
    )
    if po_match:
        candidate_po = po_match.group(1).strip()
        if candidate_po.upper() not in COMMON_EXCLUDED_BL_WORDS:
            po_number = candidate_po

    # 4. Extract Explicit Import File Code (IMP-YYYY-NNNN)
    file_code_match = re.search(r"\b(IMP-\d{4}-\d{4,5})\b", combined_text, re.IGNORECASE)
    extracted_file_code = file_code_match.group(1).upper() if file_code_match else None

    # 5. Extract ETA
    extracted_eta = None
    eta_match = re.search(
        r"(?:Estimated\s*Time\s*of\s*Arrival|\(?ETA\)?|Arrival\s*Date|Est\.?\s*Arrival|تاريخ\s*الوصول|الموعد\s*المتوقع|تاريخ\s*متوقع)[\s():-]*(\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{4})",
        combined_text,
        re.IGNORECASE,
    )
    if eta_match:
        extracted_eta = parse_date_string(eta_match.group(1))

    # 6. Extract Vessel Name
    vessel_name = None
    vessel_match = re.search(
        r"(?:Vessel|Ship|Feeder|باخرة|السفينة|الباخرة)[:\s]*([A-Za-z0-9\s.-]{3,35}?)(?=\s*(?:Voyage|Voy|رحلة|ETA|Discharge|\n|$))",
        combined_text,
        re.IGNORECASE,
    )
    if vessel_match:
        vessel_name = vessel_match.group(1).strip()

    # 7. Extract Voyage
    voyage_name = None
    voyage_match = re.search(r"(?:Voyage|Voy|رحلة)[:\s]*([A-Za-z0-9/-]{2,20})", combined_text, re.IGNORECASE)
    if voyage_match:
        voyage_name = voyage_match.group(1).strip()

    # 8. Extract ISO Container Numbers
    containers = list(set(re.findall(r"\b([A-Z]{4}\d{7})\b", combined_text)))

    return {
        "bl_number": bl_number,
        "acid_number": acid_number,
        "po_number": po_number,
        "file_code": extracted_file_code,
        "eta": extracted_eta,
        "vessel": vessel_name,
        "voyage": voyage_name,
        "containers": containers,
    }


def preview_arrival_notice_service(req: InboundEmailParsePreviewRequest) -> ArrivalNoticeParseResult:
    extracted = extract_arrival_notice_data(req.subject, req.body_text)
    return ArrivalNoticeParseResult(
        extracted_bl_number=extracted["bl_number"],
        extracted_eta=extracted["eta"],
        extracted_vessel=extracted["vessel"],
        extracted_voyage=extracted["voyage"],
        extracted_containers=extracted["containers"],
        is_matched_file=False,
        import_file_id=None,
        import_file_code=None,
        payment_task_created=False,
        task_id=None,
        summary_message="تمت المعاينة والاستخراج بنجاح من نص الإيميل.",
    )


def process_inbound_email_service(
    db: Session, req: InboundEmailCreate, user: str = "SmartEmailListener"
) -> ArrivalNoticeParseResult:
    validate_email_payload(req.sender_email, req.subject, req.body_text)
    extracted = extract_arrival_notice_data(req.subject, req.body_text)

    bl_number = extracted["bl_number"]
    acid_number = extracted["acid_number"]
    po_number = extracted["po_number"]
    file_code = extracted["file_code"]
    eta_date = extracted["eta"]
    vessel = extracted["vessel"]
    voyage = extracted["voyage"]
    containers_str = ", ".join(extracted["containers"]) if extracted["containers"] else None

    # Multi-criteria search for matching import file
    matched_file, match_reason = repository.find_matching_import_file(
        db,
        bl_number=bl_number,
        acid_number=acid_number,
        po_number=po_number,
        file_code=file_code,
        containers=extracted["containers"],
        subject=req.subject,
        body=req.body_text,
    )
    task_created = False
    task_id = None
    created_task = None
    status_str = "Processed"

    if matched_file:
        status_str = "Matched"
        # Update ETA if different
        if eta_date:
            repository.update_import_file_eta(db, matched_file.import_file_id, eta_date)

        # Generate Payment Task for Delivery Order
        created_task = repository.create_delivery_order_payment_task(
            db,
            matched_file,
            bl_number=bl_number,
            eta_date=eta_date,
            match_reason=match_reason,
        )
        task_id = created_task.task_id
        task_created = True
        status_str = "Task_Created"
        msg = f"تم مطابقة الإيميل بنجاح استناداً إلى {match_reason} مع الشحنة [{matched_file.import_file_code}] وتوليد مهمة المتابعة/السداد (#{created_task.task_code})."
        log_msg = sys_msg(
            "EMAIL_PARSE_MATCHED",
            import_file_code=matched_file.import_file_code,
            reference=bl_number or repository._reference_value(match_reason) or matched_file.import_file_code,
            task_code=created_task.task_code,
        )
    else:
        if bl_number:
            status_str = "Unmatched_BL"
            msg = f"تم استخراج البوليصة [{bl_number}] ولكن لم يتم العثور على شحنة نشطة مسجلة بهذا الرقم."
            log_msg = sys_msg("EMAIL_PARSE_UNMATCHED_BL", bl_number=bl_number)
        elif acid_number:
            status_str = "Unmatched_ACID"
            msg = f"تم استخراج رقم ACID [{acid_number}] ولكن لم يتم العثور على شحنة نشطة مسجلة به."
            log_msg = sys_msg("EMAIL_PARSE_UNMATCHED_ACID", acid_number=acid_number)
        elif po_number:
            status_str = "Unmatched_PO"
            msg = f"تم استخراج أمر الشراء [{po_number}] ولم يتم العثور على شحنة نشطة مرتبطة به."
            log_msg = sys_msg("EMAIL_PARSE_UNMATCHED_PO", po_number=po_number)
        else:
            status_str = "No_Shipment_Reference"
            msg = "تم استلام الإيميل ولم يُعثر على رقم بوليصة أو ACID أو أمر شراء أو مشروع لشحنة مسجلة."
            log_msg = sys_msg("EMAIL_PARSE_NO_REFERENCE")

    # Save Inbound Log
    log_record = repository.create_email_log(
        db,
        {
            "sender_email": req.sender_email,
            "subject": req.subject,
            "body_text": req.body_text,
            "email_type": req.email_type or "Arrival Notice",
            "extracted_bl_number": bl_number,
            "extracted_eta": eta_date,
            "extracted_vessel": vessel,
            "extracted_voyage": voyage,
            "extracted_containers": containers_str,
            "import_file_id": matched_file.import_file_id if matched_file else None,
            "processing_status": status_str,
            "task_id": task_id,
            "notes": render_en(log_msg.code, log_msg.params, "note"),
            "msg_code": log_msg.code,
            "msg_params": log_msg.params,
        },
        user=user,
    )

    return ArrivalNoticeParseResult(
        extracted_bl_number=bl_number,
        extracted_eta=eta_date,
        extracted_vessel=vessel,
        extracted_voyage=voyage,
        extracted_containers=extracted["containers"],
        is_matched_file=matched_file is not None,
        import_file_id=matched_file.import_file_id if matched_file else None,
        import_file_code=matched_file.import_file_code if matched_file else None,
        payment_task_created=task_created,
        task_id=task_id,
        summary_message=msg,
        email_id=log_record.email_id if log_record else None,
        sender_email=req.sender_email,
        subject=req.subject,
        shipment_title=(matched_file.custom_file_number or matched_file.import_file_code) if matched_file else None,
        match_reason=match_reason if matched_file else None,
        task_code=created_task.task_code if (matched_file and created_task) else None,
        task_title=created_task.title if (matched_file and created_task) else None,
        assigned_user=created_task.assigned_user if (matched_file and created_task) else "Finance Team",
        priority=created_task.priority if (matched_file and created_task) else "High",
        due_date=created_task.due_date if (matched_file and created_task) else (eta_date.isoformat() if eta_date else None),
    )


# ---------------------------------------------------------
# IMAP / MIME Parsing Helpers
# ---------------------------------------------------------

def _decode_mime_header(val: Optional[str]) -> str:
    if not val:
        return ""
    try:
        decoded_chunks = decode_header(val)
        parts = []
        for chunk, encoding in decoded_chunks:
            if isinstance(chunk, bytes):
                try:
                    parts.append(chunk.decode(encoding or "utf-8", errors="replace"))
                except Exception:
                    parts.append(chunk.decode("latin1", errors="replace"))
            else:
                parts.append(str(chunk))
        return "".join(parts).strip()
    except Exception:
        return str(val)


def _extract_body_from_email_message(msg: email.message.Message) -> str:
    body_plain = ""
    body_html = ""

    if msg.is_multipart():
        for part in msg.walk():
            content_type = part.get_content_type()
            content_disposition = str(part.get("Content-Disposition") or "")
            if "attachment" in content_disposition.lower():
                continue
            try:
                payload = part.get_payload(decode=True)
                if not payload:
                    continue
                charset = part.get_content_charset() or "utf-8"
                text = payload.decode(charset, errors="replace")
                if content_type == "text/plain":
                    body_plain += "\n" + text
                elif content_type == "text/html":
                    body_html += "\n" + text
            except Exception:
                continue
    else:
        try:
            payload = msg.get_payload(decode=True)
            if payload:
                charset = msg.get_content_charset() or "utf-8"
                text = payload.decode(charset, errors="replace")
                if msg.get_content_type() == "text/html":
                    body_html = text
                else:
                    body_plain = text
        except Exception:
            body_plain = str(msg.get_payload() or "")

    if body_plain.strip():
        return body_plain.strip()

    if body_html.strip():
        clean_html = re.sub(r"<[^>]+>", " ", body_html)
        return re.sub(r"\s+", " ", clean_html).strip()

    return ""


# ---------------------------------------------------------
# Connection Test & Live Sync Services
# ---------------------------------------------------------

def get_local_outlook_info() -> Dict[str, Any]:
    """
    Connect to local Microsoft Outlook Desktop instance via Windows COM / MAPI.
    Requires zero passwords or IT approvals.
    """
    try:
        import win32com.client
        import pythoncom
    except ImportError:
        return {
            "available": False,
            "error": "مكتبة pywin32 غير متوفرة. يرجى تثبيتها لتفعيل الربط المباشر مع Outlook.",
        }

    try:
        pythoncom.CoInitialize()
        try:
            outlook = win32com.client.Dispatch("Outlook.Application")
            ns = outlook.GetNamespace("MAPI")
            current_user = ns.CurrentUser
            user_name = current_user.Name if current_user else "Outlook User"

            email_address = ""
            try:
                email_address = current_user.AddressEntry.GetExchangeUser().PrimarySmtpAddress
            except Exception:
                try:
                    email_address = current_user.Address or ""
                except Exception:
                    email_address = ""

            inbox = ns.GetDefaultFolder(6)  # 6 = olFolderInbox
            count = inbox.Items.Count

            return {
                "available": True,
                "user_name": user_name,
                "email_address": email_address,
                "inbox_count": count,
            }
        finally:
            pythoncom.CoUninitialize()
    except Exception as e:
        return {
            "available": False,
            "error": f"تعذر الاتصال بتطبيق Microsoft Outlook: {str(e)}",
        }


def test_email_connection_service(req: EmailConnectionTestRequest) -> EmailConnectionTestResult:
    # 0. Check Local Outlook Integration first
    if req.provider_type in ("LOCAL_OUTLOOK", "LOCAL", "OUTLOOK_DESKTOP"):
        info = get_local_outlook_info()
        if info.get("available"):
            user = info.get("user_name", "User")
            email_addr = info.get("email_address", "")
            count = info.get("inbox_count", 0)
            account_display = f"{user} ({email_addr})" if email_addr else user
            return EmailConnectionTestResult(
                imap_connected=True,
                imap_message=f"تم الاتصال بنجاح ببرنامج Outlook على جهازك لحساب {user} — يتوفر {count} رسالة في صندوق الوارد.",
                smtp_connected=True,
                smtp_message=f"خدمة الإرسال الصادر جاهزة عبر ملف تعريف Outlook لحساب {user} بدون قيود أو كلمات مرور.",
                overall_success=True,
                details=f"Local Outlook MAPI: OK | Profile: {account_display} | Inbox: {count}",
            )
        else:
            err = info.get("error", "Outlook غير متوفر")
            return EmailConnectionTestResult(
                imap_connected=False,
                imap_message=f"فشل الاتصال بـ Outlook على هذا الجهاز: {err}",
                smtp_connected=False,
                smtp_message="تعذر تفعيل خدمة الإرسال عبر Outlook",
                overall_success=False,
                details=f"Local Outlook Error: {err}",
            )

    imap_ok = False
    imap_msg = ""
    smtp_ok = False
    smtp_msg = ""

    # 1. Test IMAP
    try:
        if req.imap_use_ssl:
            imap_client = imaplib.IMAP4_SSL(req.imap_host, req.imap_port)
        else:
            imap_client = imaplib.IMAP4(req.imap_host, req.imap_port)
        imap_client.login(req.username, req.password)
        imap_client.logout()
        imap_ok = True
        imap_msg = f"تم الاتصال بنجاح بخادم الاستقبال ({req.imap_host}:{req.imap_port}) والمصادقة سليمة."
    except Exception as e:
        err = str(e)
        err_lower = err.lower()
        if "authentication" in err_lower or "invalid credentials" in err_lower or "password" in err_lower or "login" in err_lower:
            imap_msg = f"فشل تسجيل الدخول: يرجى التحقق من اسم المستخدم أو استخدام App Password. [رد الخادم: {err}]"
        else:
            imap_msg = f"فشل الاتصال بـ IMAP: {err}"

    # 2. Test SMTP
    try:
        if req.smtp_use_ssl:
            smtp_client = smtplib.SMTP_SSL(req.smtp_host, req.smtp_port, timeout=10)
        else:
            smtp_client = smtplib.SMTP(req.smtp_host, req.smtp_port, timeout=10)
            if req.smtp_use_tls:
                smtp_client.starttls()
        smtp_client.login(req.username, req.password)
        smtp_client.quit()
        smtp_ok = True
        smtp_msg = f"تم الاتصال بنجاح بخادم الإرسال ({req.smtp_host}:{req.smtp_port}) والمصادقة سليمة."
    except Exception as e:
        err = str(e)
        err_lower = err.lower()
        if "authentication" in err_lower or "username and password not accepted" in err_lower or "535" in err_lower:
            smtp_msg = f"فشل مصادقة SMTP: يرجى التحقق من بيانات الدخول أو إعدادات الحساب. [رد الخادم: {err}]"
        else:
            smtp_msg = f"فشل الاتصال بـ SMTP: {err}"

    overall = imap_ok and smtp_ok
    details = f"IMAP: {'OK' if imap_ok else 'FAILED'} | SMTP: {'OK' if smtp_ok else 'FAILED'}"

    return EmailConnectionTestResult(
        imap_connected=imap_ok,
        imap_message=imap_msg,
        smtp_connected=smtp_ok,
        smtp_message=smtp_msg,
        overall_success=overall,
        details=details,
    )


def fetch_from_local_outlook_service(
    db: Session, max_emails: int = 20, only_unseen: bool = False
) -> InboxFetchResult:
    try:
        import win32com.client
        import pythoncom
    except ImportError:
        return InboxFetchResult(
            total_fetched=0,
            matched_files_count=0,
            tasks_created_count=0,
            results=[],
            message="مكتبة pywin32 غير متوفرة للاتصال بـ Outlook.",
        )

    try:
        pythoncom.CoInitialize()
        try:
            outlook = win32com.client.Dispatch("Outlook.Application")
            ns = outlook.GetNamespace("MAPI")
            inbox = ns.GetDefaultFolder(6)  # 6 = olFolderInbox
            items = inbox.Items
            if only_unseen:
                try:
                    items = items.Restrict("[UnRead] = True")
                except Exception:
                    pass
            items.Sort("[ReceivedTime]", True)

            total_available = items.Count
            limit = min(max_emails, total_available)

            parse_results: List[ArrivalNoticeParseResult] = []
            matched_count = 0
            tasks_count = 0

            for i in range(1, limit + 1):
                try:
                    item = items.Item(i)
                    if getattr(item, "Class", 0) != 43:
                        continue

                    subject = str(getattr(item, "Subject", "No Subject") or "No Subject")

                    sender = ""
                    try:
                        sender = getattr(item, "SenderEmailAddress", "") or ""
                    except Exception:
                        pass
                    if not sender or "@" not in sender:
                        sender = str(getattr(item, "SenderName", "Unknown Sender") or "Unknown Sender")

                    body_text = str(getattr(item, "Body", "") or "")
                    if not body_text.strip():
                        body_text = subject

                    email_in = InboundEmailCreate(
                        sender_email=sender,
                        subject=subject,
                        body_text=body_text,
                        email_type="Arrival Notice",
                    )
                    parse_res = process_inbound_email_service(db, email_in, user="LocalOutlookListener")
                    parse_results.append(parse_res)

                    if parse_res.is_matched_file:
                        matched_count += 1
                    if parse_res.payment_task_created:
                        tasks_count += 1
                except Exception:
                    continue

            summary_msg = f"تم فحص {len(parse_results)} إيميل من تطبيق Microsoft Outlook، ومطابقة {matched_count} شحنة، وتوليد {tasks_count} مهمة سداد."
            repository.update_email_settings_sync_status(
                db,
                "SUCCESS",
                sys_msg("EMAIL_SYNC_SUMMARY_OUTLOOK", count=len(parse_results), matched_count=matched_count,
                        tasks_count=tasks_count),
            )

            return InboxFetchResult(
                total_fetched=len(parse_results),
                matched_files_count=matched_count,
                tasks_created_count=tasks_count,
                results=parse_results,
                message=summary_msg,
            )
        finally:
            pythoncom.CoUninitialize()
    except Exception as e:
        err_msg = f"خطأ أثناء جلب الرسائل من تطبيق Microsoft Outlook: {str(e)}"
        repository.update_email_settings_sync_status(db, "ERROR", sys_msg("EMAIL_SYNC_ERROR_OUTLOOK", error=str(e)))
        return InboxFetchResult(
            total_fetched=0,
            matched_files_count=0,
            tasks_created_count=0,
            results=[],
            message=err_msg,
        )


def fetch_and_process_inbox_service(
    db: Session, max_emails: int = 20, folder: str = "INBOX", only_unseen: bool = False
) -> InboxFetchResult:
    settings = repository.get_email_settings(db)
    if not settings or not settings.is_active:
        # Fallback to local outlook if available
        outlook_info = get_local_outlook_info()
        if outlook_info.get("available"):
            return fetch_from_local_outlook_service(db, max_emails=max_emails, only_unseen=only_unseen)

        return InboxFetchResult(
            total_fetched=0,
            matched_files_count=0,
            tasks_created_count=0,
            results=[],
            message="لم يتم حفظ أو تفعيل إعدادات البريد الإلكتروني بعد. يرجى ضبط الإعدادات أولاً.",
        )

    if settings.provider_type in ("LOCAL_OUTLOOK", "LOCAL", "OUTLOOK_DESKTOP"):
        return fetch_from_local_outlook_service(db, max_emails=max_emails, only_unseen=only_unseen)

    try:
        if settings.imap_use_ssl:
            client = imaplib.IMAP4_SSL(settings.imap_host, settings.imap_port)
        else:
            client = imaplib.IMAP4(settings.imap_host, settings.imap_port)

        plain_pwd = decrypt_email_password(settings.password)
        client.login(settings.username, plain_pwd)
        typ, _ = client.select(folder, readonly=True)
        if typ != "OK":
            client.logout()
            return InboxFetchResult(
                total_fetched=0,
                matched_files_count=0,
                tasks_created_count=0,
                results=[],
                message=f"فشل الوصول للمجلد [{folder}].",
            )

        search_criteria = "UNSEEN" if only_unseen else "ALL"
        status_code, messages = client.search(None, search_criteria)

        if status_code != "OK" or not messages or not messages[0]:
            client.logout()
            repository.update_email_settings_sync_status(db, "SUCCESS", sys_msg("EMAIL_SYNC_EMPTY"))
            return InboxFetchResult(
                total_fetched=0,
                matched_files_count=0,
                tasks_created_count=0,
                results=[],
                message="لا توجد إيميلات جديدة تطابق شروط البحث.",
            )

        email_ids = messages[0].split()
        selected_ids = email_ids[-max_emails:]
        selected_ids.reverse()

        parse_results: List[ArrivalNoticeParseResult] = []
        matched_count = 0
        tasks_count = 0

        for mid in selected_ids:
            try:
                res, msg_data = client.fetch(mid, "(RFC822)")
                if res != "OK" or not msg_data:
                    continue

                raw_email = None
                for response_part in msg_data:
                    if isinstance(response_part, tuple) and len(response_part) > 1:
                        raw_email = response_part[1]
                        break

                if not raw_email:
                    continue

                email_msg = email.message_from_bytes(raw_email)
                subject = _decode_mime_header(email_msg.get("Subject", "No Subject"))
                sender = _decode_mime_header(email_msg.get("From", "Unknown Sender"))
                match_email = re.search(r"[\w.-]+@[\w.-]+\.\w+", sender)
                clean_sender = match_email.group(0) if match_email else sender

                body_text = _extract_body_from_email_message(email_msg)
                if not body_text.strip():
                    body_text = subject

                email_in = InboundEmailCreate(
                    sender_email=clean_sender,
                    subject=subject,
                    body_text=body_text,
                    email_type="Arrival Notice",
                )
                parse_res = process_inbound_email_service(db, email_in, user="ImapAutoListener")
                parse_results.append(parse_res)

                if parse_res.is_matched_file:
                    matched_count += 1
                if parse_res.payment_task_created:
                    tasks_count += 1
            except Exception:
                continue

        client.logout()

        summary_msg = f"تم فحص {len(parse_results)} إيميل، ومطابقة {matched_count} شحنة، وتوليد {tasks_count} مهمة سداد."
        repository.update_email_settings_sync_status(
            db,
            "SUCCESS",
            sys_msg("EMAIL_SYNC_SUMMARY", count=len(parse_results), matched_count=matched_count, tasks_count=tasks_count),
        )

        return InboxFetchResult(
            total_fetched=len(parse_results),
            matched_files_count=matched_count,
            tasks_created_count=tasks_count,
            results=parse_results,
            message=summary_msg,
        )
    except Exception as e:
        err_msg = f"خطأ أثناء جلب الإيميلات من الخادم: {str(e)}"
        repository.update_email_settings_sync_status(db, "ERROR", sys_msg("EMAIL_SYNC_ERROR", error=str(e)))
        return InboxFetchResult(
            total_fetched=0,
            matched_files_count=0,
            tasks_created_count=0,
            results=[],
            message=err_msg,
        )


def send_via_local_outlook_service(
    req: OutboundEmailSendRequest
) -> OutboundEmailSendResult:
    try:
        import win32com.client
        import pythoncom
    except ImportError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="مكتبة pywin32 غير متوفرة.",
        )

    pythoncom.CoInitialize()
    try:
        outlook = win32com.client.Dispatch("Outlook.Application")
        mail = outlook.CreateItem(0)  # 0 = olMailItem
        mail.To = "; ".join(req.recipient_emails)
        mail.Subject = req.subject
        if req.is_html:
            mail.HTMLBody = req.body_text
        else:
            mail.Body = req.body_text

        temp_files_created = []
        if req.attachments:
            import tempfile, os, uuid
            for att in req.attachments:
                raw_filename = att.get("filename", "attachment")
                safe_filename = os.path.basename(raw_filename) or "attachment"
                content_b64 = att.get("content_base64", "")
                if content_b64:
                    tmp_dir = tempfile.gettempdir()
                    tmp_file = os.path.join(tmp_dir, f"att_{uuid.uuid4().hex[:8]}_{safe_filename}")
                    with open(tmp_file, "wb") as f:
                        f.write(base64.b64decode(content_b64))
                    temp_files_created.append(tmp_file)
                    mail.Attachments.Add(tmp_file)

        mail.Send()
        return OutboundEmailSendResult(
            success=True,
            message=f"تم إرسال الإيميل بنجاح عبر Microsoft Outlook إلى: {', '.join(req.recipient_emails)}",
            sent_at=datetime.now(),
            recipients=req.recipient_emails,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل إرسال الإيميل عبر Outlook: {str(e)}",
        )
    finally:
        for tf in temp_files_created:
            try:
                if os.path.exists(tf):
                    os.remove(tf)
            except Exception:
                pass
        pythoncom.CoUninitialize()


def send_outbound_email_service(
    req: OutboundEmailSendRequest, db: Session
) -> OutboundEmailSendResult:
    settings = repository.get_email_settings(db)
    if not settings or not settings.is_active:
        # Fallback to local outlook if available
        outlook_info = get_local_outlook_info()
        if outlook_info.get("available"):
            return send_via_local_outlook_service(req)

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لم يتم تهيئة إعدادات البريد الإلكتروني بعد. يرجى ضبط الإعدادات أولاً.",
        )

    if settings.provider_type in ("LOCAL_OUTLOOK", "LOCAL", "OUTLOOK_DESKTOP"):
        return send_via_local_outlook_service(req)

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = req.subject
        msg["From"] = f"{settings.sender_display_name} <{settings.email_address}>"
        msg["To"] = ", ".join(req.recipient_emails)

        if req.is_html:
            msg.attach(MIMEText(req.body_text, "html", "utf-8"))
        else:
            msg.attach(MIMEText(req.body_text, "plain", "utf-8"))

        if req.attachments:
            for att in req.attachments:
                filename = att.get("filename", "attachment")
                content_b64 = att.get("content_base64", "")
                if content_b64:
                    raw_data = base64.b64decode(content_b64)
                    part = MIMEApplication(raw_data, Name=filename)
                    part["Content-Disposition"] = f'attachment; filename="{filename}"'
                    msg.attach(part)

        if settings.smtp_use_ssl:
            smtp_client = smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=15)
        else:
            smtp_client = smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15)
            if settings.smtp_use_tls:
                smtp_client.starttls()

        plain_pwd = decrypt_email_password(settings.password)
        smtp_client.login(settings.username, plain_pwd)
        smtp_client.send_message(msg)
        smtp_client.quit()

        return OutboundEmailSendResult(
            success=True,
            message=f"تم إرسال الإيميل بنجاح إلى: {', '.join(req.recipient_emails)}",
            sent_at=datetime.now(),
            recipients=req.recipient_emails,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل إرسال الإيميل: {str(e)}",
        )


def approve_and_route_tasks_service(
    db: Session,
    req: TasksBatchApprovalRequest,
    user_name: str = "User",
) -> TasksBatchApprovalResult:
    tasks_data = [item.model_dump() for item in req.tasks]
    count, ids = repository.batch_approve_and_route_tasks(db, tasks_data, user_name=user_name)
    return TasksBatchApprovalResult(
        approved_count=count,
        created_task_ids=ids,
        message=f"تم بنجاح اعتماد وتوجيه {count} مهمة ذكية وحفظها في النظام.",
    )

