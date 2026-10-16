# import_documentation — مستندات الاستيراد والتسجيل الحكومي

> Last verified: 2026-10-16 against 87ac0597 + uncommitted changes · Phase: phase_03 · Codes: BP-014, BP-015, BP-016 (والـ router بيذكر كمان BP-017, BP-018, BP-019)

## 🎯 الغرض
الـ module ده هو قلب المرحلة الثالثة: بيدير تسجيل ACID على نافذة، ونموذج 4 / L/C البنكي، ودورة حياة مستندات الشحنة (Draft B/L، COO/EUR.1، شهادة الفحص، فاتورة + Packing List). بيستخرج البيانات من الملفات المرفوعة (PDF/Word/Excel/OCR) ويقارنها بداتا السيستم (Import File / PO / Booking / Supplier) ويطلع مصفوفة فروقات ورسايل تصحيح. بيستخدمه موظف اللوجستيات، الـ Customs Broker والمراجع المالي/الامتثال.

## 🗺️ الخريطة
| Layer | Path | ملاحظات |
|---|---|---|
| Model | `modules/import_documentation/model.py` (625 سطر) | 9 جداول SQLAlchemy |
| Schemas | `modules/import_documentation/schemas.py` (1128) | Pydantic v2، 71 class |
| Repository | `modules/import_documentation/repository.py` (870) | CRUD + توليد الأكواد بـ `next_yearly_code` + soft delete (`_soft_delete`) |
| Service | `modules/import_documentation/service.py` (6088) | كل الـ business logic؛ **ملف ضخم** (انظر الفجوات) |
| Validators | `modules/import_documentation/validators.py` (204) | صيغة ACID، منع تكرار ACID/Form 4، whitelists الحالات، فحص الرفع |
| Router | `modules/import_documentation/router.py` (899) | prefix `/api/v1/import-documentation`، 62 route، متسجل في `main.py:356` |
| Extra: parser | `modules/import_documentation/ai_document_parser.py` (3428) | استخراج + مطابقة (خارج قاعدة الـ 6 ملفات) |
| Extra: ACID parser | `modules/import_documentation/nafeza_acid_parser.py` (454) | تحليل نص إشعار نافذة + قوالب WhatsApp/Email |
| Extra: OCR | `modules/import_documentation/arabic_ocr_engine.py` (232) + `models/arabic_ocr/` (`rec.onnx`, `dict.txt`) | OCR عربي؛ بيتنادى من `modules/import_documentation/service.py:1578` مع fallback لـ RapidOCR/pytesseract |
| Flutter feature | `frontend/lib/features/import_documentation/` | `models/ providers/ screens/ services/ widgets/` (مفيش `utils/`) |
| Providers | `frontend/lib/features/import_documentation/providers/import_documentation_provider.dart` (1089)، `docs_customs_approval_provider.dart`، `original_documents_collection_provider.dart` | Riverpod `StateNotifier`؛ الـ dio من `dioProvider` (بيحط `Authorization: Bearer` في `frontend/lib/core/network/api_client.dart:47`) |
| يعتمد على | `import_files`, `purchase_orders`, `suppliers`, `import_companies`, `freight_booking`, `cargo_shipping`, `customs_clearance` (Tracker), `lifecycle_board`, `smart_tasks`, `notifications`, `docs_customs_approval`, `audit_logs`, `import_requirements`, `currencies`, `incoterms`, `modules/auth` | بعض الاستيرادات lazy جوه الدوال (مثلاً `modules/import_documentation/service.py:294`, `:2001`) |
| بيستخدمه | `frontend/lib/features/home/home_screen.dart` (تسجيل الشاشات)، `experience_guide` (Flutter: `matchShipment`) | |

## 🧱 Data Model
كل الجداول فيها `is_active` (soft delete) و`created_at`/`updated_at` (UTC) و`created_by`/`updated_by` (String(100)، nullable). ⚠️ الأعمدة `created_by`/`updated_by` موجودة (مثلاً `modules/import_documentation/model.py:111-112`) لكن **مفيش كود في `repository.py` أو `service.py` بيكتبها** على كيانات الـ module؛ الـ audit بيتسجل في `audit_logs` لـ Draft B/L وPO reconciliation فقط (انظر الفجوات). مفيش `deleted_at`/`deleted_by`.

| Table / Model | أهم الحقول | علاقات | Soft delete / Audit |
|---|---|---|---|
| `acid_registration_sessions` / `AcidRegistrationSession` (`modules/import_documentation/model.py:12`) | `acid_code` (unique)، `acid_number` (19 رقم أو PENDING)، `requested_date`, `generated_date`, `expiry_date`, `execution_days`, `status` (default `Generated` `:100`) | `import_file_id`, `po_id`, `company_id`, `supplier_id`, provider | `is_active` `:104` |
| `banking_document_sessions` / `BankingDocumentSession` (`modules/import_documentation/model.py:115`) | `bank_doc_code` (unique)، `doc_type` (default `Form 4`)، `doc_reference_number` (default PENDING)، `request_date`, `received_date`, `execution_days`, `status` (default `Requested` `:158`) | `import_file_id`, `po_id`, provider | `is_active` `:163` |
| `shipment_document_items` / `ShipmentDocumentItem` (`modules/import_documentation/model.py:174`) | `document_code` (unique)، `doc_name`, `doc_number`, `status` (default `Approved` `:203`)، `is_cargox_uploaded`, `cargox_envelope_id`, `is_bl_endorsed`, `endorsement_number` | `import_file_id`, `po_id` | `is_active` `:216` |
| `customs_declaration_drafts` / `CustomsDeclarationDraft` (`modules/import_documentation/model.py:227`) | `declaration_code`, `declaration_status` (default `Draft Prepared` `:257`) | `import_file_id`, `po_id` | `is_active` `:261` |
| `draft_bl_review_sessions` / `DraftBLReviewSession` (`modules/import_documentation/model.py:272`) | `bl_review_code` (unique)، `version_number`, `parent_session_id`, `stage`, `status` (default `AUTO_COMPARISON_RUN` `:356`)، `checklist_data`/`comparison_matrix` (JSON)، `open_discrepancies_count`, `has_blocking_mismatch`, `importer_approval_status`, `broker_approval_status` (default `Pending`)، `approved_by/at` | `import_file_id`, `po_id`, `booking_id`, self-FK للنسخ | `is_active` `:366` |
| `certificate_of_origin_review_sessions` / `CertificateOfOriginReviewSession` (`modules/import_documentation/model.py:377`) | `coo_review_code`, `certificate_type` (default EUR.1)، `status` (default `Draft Generated` `:430`)، مصفوفة مقارنة، `override_reason`, `is_draft` | `import_file_id`, `po_id` | `is_active` `:438` |
| `inspection_certificate_review_sessions` / `InspectionCertificateReviewSession` (`modules/import_documentation/model.py:449`) | `inspection_review_code`, `inspection_agency` (default SGS)، `status` (default `Required_Draft_Generated` `:493`) | `import_file_id`, `po_id` | `is_active` `:500` |
| `po_packing_reconciliation_sessions` / `POPackingReconciliationSession` (`modules/import_documentation/model.py:511`) | `session_code`, `overall_status` (default `FULLY_MATCHED` `:544`)، `is_safe_for_certification`, counters، header/items JSON، `certified_by` | `import_file_id` **unique** (`:528`) | `is_active` `:560` |
| `invoice_bl_match_sessions` / `InvoiceBLMatchSession` (`modules/import_documentation/model.py:571`) | `session_code` (unique)، `overall_status` (default `FULLY_MATCHED` `:597`)، `is_draft`، `invoice_data`/`bl_data` | `import_file_id` (غير unique) | `is_active` `:615` |

الأكواد بتتولد في الـ repository بـ `next_yearly_code`: `ACID`, `FORM4`, `DOC`, `DEC46`, `BL-REV`, `COO`, `INSP`, `REC`, `MATCH` (`modules/import_documentation/repository.py:93`, `:229`, `:308`, `:358`, `:387`, `:508`, `:598`, `:677`, `:795`). نسخ Draft B/L بتاخد اللاحقة `-v<N>` (`modules/import_documentation/service.py:2540`).

## 🔌 API Endpoints
Prefix: `/api/v1/import-documentation`. الـ router كله محمي: `dependencies=[Depends(get_current_user)]` على مستوى الـ `APIRouter` (`modules/import_documentation/router.py:78`) **و** كل route بيعلن `require_permission` واحد من التلاتة (`:80-86`): `import_documentation.view` (قراءة + compare/parse/templates)، `import_documentation.upload` (كل كتابة + كل رفع/استخراج)، `import_documentation.approve` (اعتماد Draft B/L فقط). الـ acting user دايمًا المستخدم المسجل (`user=current_user.username`) وحقول الهوية اللي بيبعتها العميل (`approved_by`, `reviewer_name`, `reviewed_by`, `certified_by`) بتتجاهل (`modules/import_documentation/router.py:4-12`). القاعدة متثبتة بتست `tests/unit/test_phase03a_import_documentation.py:183`. الـ dev-bypass (`ALLOW_DEV_AUTH_BYPASS`) افتراضيه false ومقفول في الـ production build (`settings.py:123`). الرفع بيتفحص بـ `validators.validate_upload` (20MB، امتدادات محددة) و`validate_status` بيتنادى في routes محددة بس.

القيمة في عمود Auth: V = `view`، U = `upload`، A = `approve`. (`approve` بيتمنح مرة واحدة عند الترحيل للأدوار اللي عندها `upload` عبر `DERIVED_GRANTS` في `modules/auth/seed_rbac.py:262`).

| Method | Path | الغرض | Auth | Request → Response |
|---|---|---|---|---|
| GET | `/acid/tracker` | Tracker صلاحية ACID لكل الملفات | V | → `AcidTrackerSummary` |
| POST | `/acid/parse-text` | تحليل نص إشعار نافذة + مقارنة اختيارية بالملف | V | `AcidTextParseRequest` → `AcidTextParseResponse` |
| POST | `/acid/compare` | مصفوفة فروقات requested vs generated | V | `AcidComparisonRequest` → dict |
| POST | `/acid/templates` | قوالب WhatsApp/Email للمخلص | V | `dict` → `AcidRequestTemplateResponse` |
| POST/GET | `/acid-sessions` | إنشاء (upsert لو فيه جلسة نشطة للملف) / قائمة (`include_inactive, search, import_file_id, status`) | U / V | `AcidRegistrationCreate` → `AcidRegistrationResponse` |
| GET/PUT/DELETE | `/acid-sessions/{acid_id}` | قراءة / تعديل (+`validate_status`) / soft delete (204) | V / U / U | `AcidRegistrationUpdate` |
| PATCH | `/acid-sessions/{acid_id}/restore` | استرجاع | U | → `AcidRegistrationResponse` |
| POST/GET | `/banking-documents` | Form 4 / Form 9 / L/C | U / V | `BankingDocumentCreate` → `BankingDocumentResponse` |
| GET/PUT/DELETE | `/banking-documents/{bank_doc_id}` | قراءة / تعديل (+`validate_status`) / soft delete | V / U / U | `BankingDocumentUpdate` |
| POST | `/banking-documents/{bank_doc_id}/receive` | تسجيل استلام النموذج | U | `BankingDocumentReceive` |
| POST/GET | `/shipment-documents` | سجل مستندات الشحنة (لا يوجد PUT/DELETE) | U / V | `ShipmentDocumentCreate` |
| POST | `/shipment-documents/{doc_id}/cargox-bl` | CargoX envelope + B/L endorsement (query params) | U | → `ShipmentDocumentResponse` |
| POST | `/customs-declarations` | مسودة إقرار 46 | U | `CustomsDeclarationCreate` |
| POST | `/po-reconciliation` | تسوية PO نهائية (يعدل PO lines/packing فعليًا) | U | `POFinalAdjustmentRequest` |
| POST | `/po-reconciliation/extract-and-compare` | استخراج Invoice+PL ومقارنة 4-way | U | `POExtractAndCompareRequest` → `POExtractAndCompareResponse` |
| POST | `/po-reconciliation/extract-files-and-compare` | نفس السابق بملفات (multipart) | U | |
| POST/GET/GET/PUT/DELETE | `/po-reconciliation/sessions[/{id}]` | CRUD جلسات (يمنع تكرار الجلسة لنفس الملف) | U / V / V / U / U | `POReconciliationSession*` |
| POST | `/draft-bl/extract-file` | استخراج B/L من ملف + مقارنة اختيارية | U | multipart |
| POST | `/draft-bl/compare` | مقارنة درافت B/L | V | `DraftBLComparisonRequest` |
| POST/GET | `/draft-bl` | إنشاء (مسودة أو معتمدة) / قائمة | U / V | `DraftBLReviewCreate` |
| GET/PUT/DELETE | `/draft-bl/{review_id}` | قراءة (تشمل المحذوفة) / تعديل / soft delete | V / U / U | |
| PUT | `/draft-bl/{review_id}/checklist` | تحديث الـ checklist (المراجع = المستخدم المسجل) | U | `List[DraftBLChecklistItem]` |
| POST | `/draft-bl/dual-approval` | موافقة/رفض من importer أو customs_broker | A | `DualApprovalRequest` |
| POST | `/draft-bl/new-version` | نسخة جديدة مع قفل البنود المطابقة | U | `NewDraftVersionRequest` |
| POST | `/draft-bl/{review_id}/approve` | يكمل الدور الناقص الوحيد (المعتمد = المستخدم المسجل) | A | |
| POST | `/coo/compare` | مقارنة COO/EUR.1 | V | `COOComparisonRequest` |
| POST/GET/PUT/DELETE | `/coo`, `/coo/{review_id}` | إنشاء / قائمة / تعديل / حذف (لا يوجد GET بالـ id) | U / V / U / U | `CertificateOfOriginReview*` |
| GET | `/coo/draft-template/{import_file_id}` | قالب COO جاهز (`cert_type`) | V | → `COODraftTemplateResponse` |
| POST | `/inspection/compare` | مقارنة شهادة الفحص | V | `InspectionComparisonRequest` |
| POST/GET/PUT/DELETE | `/inspection`, `/inspection/{review_id}` | إنشاء / قائمة / تعديل / حذف (لا يوجد GET بالـ id) | U / V / U / U | `InspectionCertificateReview*` |
| GET | `/inspection/draft-template/{import_file_id}` | قالب COTECNA/TÜV/SGS (`agency`, `cert_type`) | V | → `InspectionDraftTemplateResponse` |
| POST | `/extract-certificate` / `/extract-certificate-file` | استخراج حقول شهادة (نص / ملف) | U | `DocumentExtractRequest` → `DocumentExtractResponse` |
| POST | `/cross-match-certificates` | مطابقة COO+Inspection+Invoice+PL+B/L | V | `ThreeWayCrossMatchRequest` |
| GET | `/legal-compliance/{import_file_id}` | صلاحية ACID/مستندات الشركة (+30 يوم من ETA) | V | → `LegalDocsExpiryComplianceResponse` |
| POST | `/invoice-bl/extract-and-match` / `/extract-files-and-match` | مصفوفة 10 نقاط Invoice vs B/L (نص / ملفات متعددة) | U | `InvoiceBLExtractAndMatchRequest` |
| POST | `/invoice-bl/certify-and-sync` | اعتماد ومزامنة مع Import File | U | `InvoiceBLSyncRequest` |
| POST/GET/GET | `/invoice-bl/sessions[/{id}]` | جلسات المطابقة (لا DELETE/PUT) | U / V / V | `InvoiceBLMatchSession*` |
| GET | `/central-archive/{import_file_id}` | الأرشيف المركزي + الفروقات المفتوحة | V | → `CentralArchiveResponse` |

`validate_status` (whitelists في `modules/import_documentation/validators.py:120`) بيتنادى فقط على: تعديل ACID/Banking، إنشاء وتعديل COO/Inspection، جلسات PO reconciliation، وجلسة Invoice-BL (`modules/import_documentation/router.py:199`, `:244`, `:390`, `:586`, `:662`, `:852`). إنشاء ACID/Banking/Shipment Document وCustomsDeclaration ما بيمرش عليه، والـ whitelists `draft_bl` و`shipment_doc` موجودة بس مش بتتنادى من أي route.

## ⚙️ قواعد الـ Business والحالات

### أساسيات مشتركة
- الـ actor: `_actor(user, legacy)` في `modules/import_documentation/service.py:101` (المستخدم المسجل ثم الحقل القديم ثم `system`). الـ routes دايمًا بتمرر `user`.
- Follow-ups بعد الـ commit (Lifecycle، SmartTask، Notification، sync لـ `CustomsDocumentApproval`) كلها best-effort: `_commit_follow_up` (`modules/import_documentation/service.py:148`) و`_lifecycle_follow_up` (`:158`) — فشل خطوة ما بيوقفش اللي بعدها.
- عتبات الأيام ثوابت في الكود (مش من Settings): `ACID_DEFAULT_VALIDITY_DAYS=90`, `ACID_EXPIRING_SOON_DAYS=14`, `DEFAULT_ETA_DAYS=21`, `ETA_SAFETY_MARGIN_DAYS=30`, `COMPANY_DOC_EXPIRING_SOON_DAYS=60` (`modules/import_documentation/service.py:67-71`).

### BP-014 — ACID
- **صيغة الرقم**: 19 رقم بالضبط أو `PENDING/REQUESTED/DRAFT` (`modules/import_documentation/validators.py:13`). تاريخ الانتهاء لازم يكون بعد تاريخ الإصدار/الطلب/اليوم (`:35`). منع جلسة ACID نشطة تانية لنفس الملف (`:49`) بيتفرض على **التعديل** (`modules/import_documentation/service.py:519`)، أما **الإنشاء** فبيعمل upsert على الجلسة النشطة الموجودة (`:464-487`).
- **قيم مشتقة من السيرفر** (`modules/import_documentation/service.py:439`): `execution_days = generated − requested` (min 0)، ورقم pending/فاضي ما يقدرش يشيل حالة issued (يرجع `Requested`). بدون expiry بيتحط `issue/request + 90 يوم` (`:494-498`).
- **Workflow عند الإصدار** (`modules/import_documentation/service.py:294`): لو الرقم 19 رقم → مزامنة `acid_number/dates/execution_days` إلى `ImportFile`. ولو الحالة ∈ {Verified, Discrepancy_Accepted, Generated, Issued, ACID Issued} (`:338`) → تقدم Lifecycle `STEP_05→STEP_06`، يقفل SmartTasks القديمة، ينشئ SmartTask "Freight Booking" (due +3 أيام `:388`)، ويبعت SystemNotification (`target_role=LOGISTICS_OFFICER`).
- **Tracker** (`modules/import_documentation/service.py:587`): لو مفيش expiry يفترض `issue + 90 يوم` (`:624-625`)، وdefault 90 يوم لو التواريخ ناقصة (`:636-637`). الحالات من `_acid_tracker_status` (`:568`): `Customs Released` (معفى من التنبيه) / `Pending Issue` / `Expired` (≤0) / `Expiring Soon` (≤14 يوم) / `Valid`. "Released" = `imp.is_customs_released` أو clearance فيه `dispatch_authorized`/`release_permit_no`/حالة نهائية أو مرحلة ≥ Phase 8 (`:628-632`).
- **Legal compliance** (`modules/import_documentation/service.py:4644`): ETA من Booking ثم `required_eta` ثم `today+21` (`:4657-4666`). ACID `EXPIRED` لو منتهي، `CRITICAL_BREACH` لو `expiry ≤ ETA + 30 يوم` (`:4679`)، غير كده `VALID`. بدون جلسة ACID → `CRITICAL_BREACH` (`:4706-4720`). مستندات الشركة (البطاقة الاستيرادية، السجل التجاري، البطاقة الضريبية) نفس القاعدة + `EXPIRING_SOON` لو ≤ 60 يوم (`:4745`).

### BP-015 — Form 4 / L/C
- Workflow (`modules/import_documentation/service.py:806`): مزامنة `form4_no/request/received/execution_days` للـ ImportFile. لو المرجع مش PENDING والحالة ∈ {Received, Approved by Bank, Form Issued, Verified, Endorsed} (`:849`) → Lifecycle `STEP_12→STEP_13`، SmartTask لإعداد إقرار 46 (due +2 يوم)، وإشعار لـ `CUSTOMS_BROKER`.
- منع تكرار Form 4 لنفس الملف عند الإنشاء والتعديل: `modules/import_documentation/validators.py:83` (بيتنادى من `modules/import_documentation/service.py:963`, `:987`).
- `receive`: `execution_days = received − (request|issue|today)`، الحالة تبقى `Received` (`modules/import_documentation/service.py:999-1022`).

### BP-016 — مستندات الشحنة والمراجعات
- **حالات ShipmentDocumentItem**: تعليق الموديل `Draft, Received, Under Review, Approved, Rejected, Endorsed` (`modules/import_documentation/model.py:203`) والـ default هو `Approved`؛ مفيش validator للانتقالات. `cargox-bl` بيحط `Endorsed` لما يتبعت `endorsement_number` (`modules/import_documentation/service.py:1082`).
- **تسوية PO النهائية** (`modules/import_documentation/service.py:1229`): بتتأكد إن كل `po_item_id`/`packing_item_id` يخص PO نشط ومفتوح (مش CLOSED/CANCELLED) لنفس الملف (`:1192`)، ترفض القيم السالبة (`:1236`)، القيمة الصفرية = "من غير تغيير"، تحدّث بنود الـ PO والـ packing بالـ id الخاص بكل واحد، وتعيد حساب إجماليات الـ PO وتزود `version` وتكتب `updated_by` على الـ PO (`:1318-1331`).
- **Draft B/L compare** (`modules/import_documentation/service.py:1803`): 20 حقل في `fields_spec` (`:1825`)؛ أنواع المطابقة: `fuzzy` (عتبة **0.85** `:1877`)، `text` (تطابق حرفي بعد upper)، `numeric_05` (سماحية **0.5%** `:1898`)، `numeric_strict`. الحقول الحرجة: consignee, booking_no, acid_number, importer_tax_id, container_summary. حقل حرج فاضي صراحةً (""): `BLOCKING` (`:1866`). `open_discrepancies` = البنود بحالة `Incorrect` فقط (`:1963`)، وبيتولد `correction_request_letter` إنجليزي تلقائي (`:1977`).
- **حفظ المراجعة** (`modules/import_documentation/service.py:2203`): status/stage/الموافقات **مملوكة للسيرفر** (`_reset_server_owned_draft_bl_fields` `:2156`)؛ `_draft_bl_stage_and_status` (`:2193`): مسودة → `Stage 1` / `DRAFT`؛ فيه بند مفتوح أو blocking → `Stage 2: Revision Required` / `REVISION_REQUIRED`؛ غير كده `Stage 4: Dual Approval` / `REVIEWED_PENDING_APPROVAL`. `has_blocking_mismatch` بيتحسب من الـ checklist: `Incorrect` أو `Missing` على حقل حرج (`_checklist_has_blocking` `:2177`). بند `Incorrect` في حفظ نهائي لازم `required_correction` و`reason` (`:2223`). مراجعة معتمدة واحدة فقط لكل ملف (`:2278-2286`). أي تعديل بيصفّر الموافقات السابقة (`_DRAFT_BL_APPROVAL_RESET` `:2170`, `:2349`) والمراجعة `FINAL`/`APPROVED` مقفولة (409) (`_reject_terminal_draft_bl` `:2308`).
- **Dual approval** (`modules/import_documentation/service.py:2411`): role ∈ {`importer`, `customs_broker`} وaction ∈ {`Approved`, `Rejected`}؛ يشترط `REVIEWED_PENDING_APPROVAL` بدون blocking (`_require_pending_approval` `:2184`) و`open_discrepancies_count == 0` (`:2426`). نفس الشخص ما يقدرش يعتمد الدورين (409 `:2443`). رفض أي طرف → رجوع `Stage 2`. الاتنين Approved → `Stage 5: Final` / `FINAL` (`:2470`) + `_complete_draft_bl_review_workflow` (`:2001`): تحديث ImportFile (bl_number، booking_no، vessel، progress ≥ 65)، `CustomsDocumentApproval` (B/L)، تقدم Lifecycle `STEP_08_BL→STEP_08_COO`، SmartTask SH-03 (CargoX)، إشعار.
- **Approve مباشر** (`modules/import_documentation/service.py:2584`): بيكمل دور واحد ناقص فقط (409 لو مفيش أي دور معتمد أو الاتنين معتمدين، أو نفس المعتمد)، ويرفض لو فيه بنود مفتوحة أو blocking.
- **New version** (`modules/import_documentation/service.py:2495`): من أحدث نسخة نشطة فقط (409 غير كده `:2507`)، كود `<root>-v<N>`، البنود `Correct` اللي draft_value ما اتغيرش تتقفل (`is_locked` `:2529-2532`).
- **COO compare** (`modules/import_documentation/service.py:2658`): fuzzy 0.85 على exporter_reg_id (غير حرج) / exporter_name (حرج) / country_of_origin (حرج) / importer_name (حرج) / destination_country (حرج) / invoice_number (حرج) / certificate_type (`:2689`). استثناء EUR.1: "EU" يطابق أي دولة من `EU_27_COUNTRIES` (`:2733`). قيمة مفقودة في حقل حرج = `EXTRACTION_FAILED`/`BLOCKING`. الحالة المحسوبة: `Verified` / `Discrepancy_Accepted` / `Correction Requested` (`:2769`).
- **حفظ COO** (`modules/import_documentation/service.py:2870`): الحفظ المعتمد بيعيد المقارنة في السيرفر دايمًا (`:2878`)، وأي فرق يحتاج `override_reason` (400) (`:2907`)، ولازم بلد منشأ معروف (`:2909`)، والحالة تبقى `Approved`. بعد الاعتماد الدراسة **مقفولة**: يسمح بتعديل `notes`/`override_reason` فقط (`:2949`)، والحذف مرفوض (`:5488`). بعد الاعتماد: sync لـ `CustomsDocumentApproval` وLifecycle `STEP_08_COO→STEP_09` (`_coo_certified_follow_ups` `:2822`).
- **Inspection** (`modules/import_documentation/service.py:3016`): حقول حرجة agency/importer/exporter/regulatory_authority/invoice_number؛ الحقول غير الحرجة الفاضية تعدي كـ MATCH (`:3063`). كل حفظ بيعيد المقارنة في السيرفر؛ `_inspection_status` (`:3156`): نظيف → `Verified`، أي فرق يحتاج `override_reason` ثم `Discrepancy_Accepted` (الحالة `Correction Requested` ما بتتولدش من الحفظ). حالة ∈ {Verified, Approved, Discrepancy_Accepted} → Lifecycle `STEP_08_COC→STEP_09` (`:3201`).
- **PO/Packing 4-way** (`modules/import_documentation/ai_document_parser.py:1706`): system invoice / system packing / uploaded invoice / uploaded packing. سماحيات الـ header: المبلغ **0.01%** (`:1856`)، Gross/Net Weight **2%** (`:1911`, `:1928`)، CBM **3%** (`:1945`). ACID و Tax ID → `CRITICAL_VARIANCE` (`:1762`, `:1782`، يمنع `is_safe_for_certification` `:2135`)؛ رقم الفاتورة → `MAJOR_VARIANCE` (`:1741`)؛ الباقي `MINOR_VARIANCE`. تحذير على مستوى البند لو فرق كمية/سعر > **5%** (`:2041`) أو عدد طرود/وزن قائم > **5%** (`:2102`). مصدر `system_packing_items` هو Packing List من الـ DB لـ POs النشطة (`modules/import_documentation/service.py:5177-5203`)؛ لو مفيش بنود نظام → `overall_status=DRAFT` و`system_items_missing=true` (`:5231-5247`).
- **PO reconciliation sessions** (`modules/import_documentation/service.py:5350`): جلسة نشطة واحدة لكل ملف (400 `:5359`)، والمحذوفة منطقيًا بتتعاد تفعيلها وتتكتب فوقها (لأن `import_file_id` unique `:5369`). لو الحالة ∈ {MATCHED, APPROVED, CERTIFIED, PASS, CONFORMING} أو `is_safe_for_certification` → Lifecycle `STEP_08_PO→STEP_08_BL` (`_po_recon_lifecycle` `:5336`). بيتسجل Audit Log لـ CREATE/UPDATE/DELETE (`_audit_po_recon` `:5317`).
- **Invoice vs B/L** (`modules/import_documentation/ai_document_parser.py:2182`): 10 نقاط (ACID, Tax ID, Shipper, Consignee, Containers, Seals, Packages, Gross wt سماحية **1.0%** `:2389`، Net wt **1.5%** `:2413`، Incoterms). `match_score` = `(n − (2×critical + minor)) / n` مقيّد 0-100 (`:2455`). الاعتماد (`modules/import_documentation/service.py:5028`): جلسة معتمدة واحدة لكل ملف (409)، وأي حرج يحتاج مبرر في `notes` (400 `:5050`)؛ المزامنة (`_apply_invoice_bl_sync` `:4898`) بتتحقق من `currency` و`incoterm` في جداولها المرجعية (400 لو مجهول) وبتكتب `pi_number/incoterm_code/estimated_cost_currency/bl_number/booking_no/vessel_name` على الـ ImportFile، ثم Lifecycle `STEP_08_MATCH→STEP_08_COO` و`CustomsDocumentApproval` (`:4939`).
- **اختيار نوع الشهادة**: `classify_coo_certificate_type` (`modules/import_documentation/service.py:3319`) حسب الدولة (الصين CCPIT / EU EUR.1 / Agadir-GAFTA / Form A). نسب الإعفاء التفضيلي لا تُحسب هنا؛ `is_preferential_exemption_eligible` مجرد flag (انظر الفجوات).
- **Extraction dispatcher** (`modules/import_documentation/service.py:4395`): يوجّه حسب `document_type` إلى `extract_coo_china_ccpit_text / extract_eur1_certificate_text / extract_agadir_gafta_form_a_coo_text / extract_standard_coo_text / extract_psi_certificate_text / extract_coa_certificate_text / extract_inspection_voc_certificate_text / extract_draft_bl_data / extract_commercial_invoice_data`. استخراج الـ B/L (`extract_draft_bl_with_ai` — `modules/import_documentation/ai_document_parser.py:380`) بيجرب Gemini ثم Anthropic ثم OpenAI حسب متغيرات البيئة `GEMINI_API_KEY`/`ANTHROPIC_API_KEY`/`OPENAI_API_KEY` (`:387-389`)، وبعدين بيدمج نتيجة الـ heuristic extractor دايمًا (`:402-411`). مستخدمي النظام ما بيتحكموش في ده من Settings.

## 🖥️ الشاشات (Flutter)
كل الشاشات في `frontend/lib/features/import_documentation/screens/` ومسجلة بالـ index في `frontend/lib/features/home/home_screen.dart:120-203` (مش go_router paths). `ImportDocumentationScreen` و`ShipmentDraftDocsScreen` (حاويات تابات) موجودين لكن مش مسجلين مباشرة في `home_screen.dart` (grep = صفر). التصدير عبر `TableExportService` / `services/*_export_service.dart`. الكلام مع الـ API عبر `dioProvider` (JWT).

| Screen / Widget | بتعمل إيه | الـ API |
|---|---|---|
| `NafezaAcidScreen` (`screens/nafeza_acid_screen.dart`, 3683 سطر، 5 sub-tabs) | طلب/تدقيق ACID، Smart Parser، مصفوفة فروقات، Registry، Expiry Tracker + بانر Experience Guide | `/acid-sessions`, `/acid/*`, `/legal-compliance` |
| `BankForm4Screen` (2 sub-tabs) | طلب وسجل Form 4/L/C | `/banking-documents` |
| `DraftBLReviewScreen` → `widgets/draft_bl_review_tab.dart` (3307) | مراجعة الدرافت + dual approval + قوالب وخطاب تصحيح | `/draft-bl*` |
| `DraftCOOReviewScreen` → `widgets/coo_review_tab.dart` (2351) + `visual_draft_coo_sheet.dart` | مراجعة COO/EUR.1 وقوالب | `/coo*` |
| `DraftInspectionReviewScreen` → `widgets/inspection_review_tab.dart` | مراجعة شهادة الفحص | `/inspection*` |
| `POPackingReconciliationScreen` → `widgets/po_reconciliation_tab.dart` (4639) | مقارنة 4-way + حفظ جلسات | `/po-reconciliation*` |
| `SmartInvoiceBLMatchScreen` → `widgets/invoice_bl_matcher_tab.dart` (3049) + `smart_invoice_bl_extractor_dialog.dart` | رفع فواتير/بوالص متعددة ومطابقة 10 نقاط | `/invoice-bl/*` |
| `DocsCustomsApprovalScreen` → `widgets/customs_document_approval_tab.dart` | موافقات المستندات الجمركية وتذاكر الفروقات | module `docs_customs_approval` (`/docs-customs-approval/*`) |
| `CustomsDeclaration46Screen` (2 sub-tabs) + `services/customs_declaration46_calculator.dart` | مسودة إقرار 46 | لا يستدعي `/customs-declarations` (grep في `frontend/lib` = صفر) |
| `CentralDocsArchiveScreen` | الأرشيف المركزي | `/central-archive/{id}` |
| `OriginalDocsAndCargoXScreen` (sub-tab 0/1) → `widgets/original_documents_collection_tab.dart` | تحصيل المستندات الأصلية + CargoX | module `original_documents_collection` + `/shipment-documents/{id}/cargox-bl` |
| `widgets/legal_compliance_banner.dart` | بانر صلاحية ACID/مستندات الشركة | `/legal-compliance/{id}` |
| `widgets/search_and_clone_*_dialog.dart` (7 dialogs) | بحث واستنساخ جلسة سابقة | — |

Providers الرئيسية في `providers/import_documentation_provider.dart`: `acidSessionsProvider` (`frontend/lib/features/import_documentation/providers/import_documentation_provider.dart:31`)، `bankingDocumentsProvider` (`:190`)، `shipmentDocumentsProvider` (`:287`)، `acidTrackerProvider` (`:346`)، `legalComplianceFamilyProvider` (`:388`)، `draftBLReviewsProvider` (`:398`)، `cooReviewsProvider` (`:587`)، `inspectionReviewsProvider` (`:715`)، `poReconciliationProvider`/`poReconciliationSessionsProvider` (`:841`, `:865`)، `centralArchiveProvider` (`:979`)، `invoiceBLMatchSessionsProvider` (`:999`). الـ endpoints اللي الواجهة لا تستدعيها: `/customs-declarations`, `/extract-certificate-file`, `/cross-match-certificates`, `/invoice-bl/certify-and-sync` (grep في `frontend/lib`).

## 🧪 الاختبارات
| Test file | بيغطي إيه |
|---|---|
| `tests/unit/test_phase03a_import_documentation.py` (40) | صلاحيات كل الـ routes (view/upload/approve)، تجاهل هوية العميل، رفض الملفات، whitelists الحالات، قواعد الـ repository (soft delete، الأكواد) |
| `tests/unit/test_phase03a_service.py` (52) | انحدار الـ service: DOC-02..25 (تسوية PO، اعتماد B/L، COO/Inspection justification، PO session reuse، ACID defaults، follow-ups) |
| `tests/unit/test_phase03a_characterization.py` (16) | تثبيت سلوك الـ service/repository |
| `tests/unit/test_import_documentation.py`, `test_dc01_acid_registration_verification.py`, `test_dc02_acid_expiry_radar_tracking.py`, `test_acid_tracker.py`, `test_acid_import_file_linkage.py`, `test_acid_discrepancy_service.py`, `test_nafeza_acid_parser.py` | ACID (تسجيل، Tracker، parser، مقارنة) |
| `tests/unit/test_banking_form4_workflow.py`, `test_dc03_bank_form4_lc_link.py` | Form 4 / L/C والربط بالملف |
| `tests/unit/test_sh02_draft_bl_dual_review.py`, `test_draft_bl_coo_sessions_parity.py`, `test_enhanced_bl_parser.py` | Draft B/L dual approval وتماثل الجلسات والـ parser |
| `tests/unit/test_coo_*.py` (multi_origin، recommendation_and_agreement_rules، and_inspection_anti_duplicate_and_justification), `test_inspection_cert_extractor.py`, `test_cl01_inspection_sampling.py` | COO/EUR.1 والفحص |
| `tests/unit/test_invoice_bl_matcher.py`, `test_invoice_bl_match_session.py`, `test_po_reconciliation_session.py`, `test_po_packing_extractor.py` | Invoice↔B/L وجلسات PO والـ extractors |
| `tests/unit/test_import_documentation_message_codes.py` (12) | تخزين رسائل المقارنة كأكواد (`details_code`/`reason_code`) |
| `frontend/test/import_documentation_provider_refresh_test.dart`, `import_documentation_model_test.dart`, `import_documentation_no_fabricated_defaults_test.dart` | Providers (refresh بعد التغيير)، النماذج، منع القيم الثابتة المخترعة |
| `frontend/test/draft_bl_single_step_approval_test.dart`, `draft_bl_blocking_reasons_test.dart`, `draft_bl_coo_sessions_parity_test.dart`, `phase6_draft_reviews_and_compliance_test.dart` | اعتماد B/L ورسائل الـ blocking وتماثل الجلسات |
| `frontend/test/coo_export_guard_test.dart`, `coded_item_text_test.dart`, `invoice_bl_matcher*_test.dart`, `invoice_bl_match_sessions_test.dart`, `po_reconciliation_*_test.dart`, `acid_tracker_test.dart`, `nafeza_acid_localization_test.dart`, `central_docs_archive_test.dart`, `customs_declaration46*_test.dart`, `original_documents_collection_test.dart`, `screen_58_original_docs_and_cargox_test.dart`, `responsive_and_clone_screen{11..24}_test.dart`, `perf/screen_13_*` | شاشات ووحدات الواجهة |

**فجوات التغطية** (بناءً على `grep` على أسماء الدوال في `tests/` — مش فحص كامل): `generate_coo_draft_template_service` / `generate_inspection_draft_template_service`, `cross_match_certificates_service`, `get_central_archive_service` مفيهمش اختبارات مخصصة ظاهرة؛ مفيش اختبار لـ `reconcile_po_documents_with_system` على حالات الـ severity المتضاربة (الفجوة 8 تحت).

## ⚠️ ملاحظات وفجوات (Known issues & tech debt)
الأمان اتحسّن عن النسخة اللي اتوثقت قبل كده: الـ router بقى محمي بالكامل (auth + RBAC) وافتراض "Kamal" اتشال. النقاط التالية اتأكدت من الكود الحالي ومفيش task link متاح لها.

**Backend**
| # | المشكلة | المكان |
|---|---|---|
| 1 | مفتاحا `created_by`/`updated_by` موجودين في كل الجداول لكن مش بيتكتبوا (الـ `user` بيوصل للـ services بس مش بيتخزن في ACID/Banking/Shipment/Customs/COO/Inspection)؛ وللـ Draft B/L حذف المستخدم بيتسجل في `audit_logs` فقط. مخالفة لـ GP-004 | `modules/import_documentation/service.py:454`, `:956`, `:1044`, `:1089`, `:5473` |
| 2 | `required_correction` بيتحط على كل الصفوف (حتى المطابقة)، وحالة `Missing` بتتجاهل في `open_discrepancies` لكل الحقول غير الحرجة | `modules/import_documentation/service.py:1951-1952`, `:1963` |
| 3 | تحديث الـ checklist بيحسب الحالة من عدد `Incorrect` فقط → ممكن تبقى `REVIEWED_PENDING_APPROVAL` وفي نفس الوقت `has_blocking_mismatch=True` (الاعتماد بيترفض لاحقًا بـ 400)؛ عكس مسار الإنشاء/التعديل | `modules/import_documentation/service.py:2391`, `:2398-2404` مقابل `:2193` |
| 4 | Agadir extractor بيفترض `origin_country="Morocco"` و`is_preferential_exemption_eligible=True` دايمًا | `modules/import_documentation/ai_document_parser.py:3235`, `:3264` |
| 5 | PSI: وكالة افتراضية `SGS` ومطابقة `"BV" in text` حساسة لحالة الأحرف وبتلقط أي نص فيه BV | `modules/import_documentation/ai_document_parser.py:3279`, `:3282` |
| 6 | حقل `system_packing_items` في `POExtractAndCompareRequest` بيتتجاهل (السيرفس بيبنيها من الـ DB بس) | `modules/import_documentation/schemas.py:927`, `modules/import_documentation/service.py:5115` |
| 7 | `hs_codes` غير حتمي الترتيب (`set()` → `list`) في لقطة النظام | `modules/import_documentation/service.py:1378`, `:1526` |
| 8 | تناقض flags المقارنة: وزن قائم ناقص من جهة واحدة = `MISMATCH_CRITICAL`/`BLOCKING` بدون `has_critical` (فـ `is_safe_for_certification` تفضل true والـ `critical_discrepancies_count` يتحسب من الـ severity)؛ حالة `EXTRACTION_FAILED` للوزن مش قابلة للوصول (الصفرين = MATCH)؛ `MAJOR_VARIANCE` (رقم الفاتورة) مش محسوب في أي counter؛ `EXTRACTION_FAILED` للطرود بدون `has_warning` | `modules/import_documentation/ai_document_parser.py:2389-2401`, `:2367`, `:2136-2137`, `:1741` |
| 9 | `CHK_INCOTERMS` دايمًا `MATCH` (`inco_coherent = True` ثابتة) وبيفترض `EXW` و`Freight Prepaid` لو ناقصين؛ تعليق صافي الوزن بيقول 1.0% والكود 1.5% | `modules/import_documentation/ai_document_parser.py:2433-2436`, `:2408`, `:2413` |
| 10 | `disagreeing_sources` ثابتة `["Invoice","B/L"]` حتى لو الاختلاف مع ACID النظام | `modules/import_documentation/ai_document_parser.py:2206-2212` |
| 11 | لقطة النظام فيها `qty_pkg` بس (مش `total_packages_count`/`incoterm_code`) فأعمدة system في Invoice↔B/L بتبقى "غير محدد" | `modules/import_documentation/service.py:1527-1530` مقابل `modules/import_documentation/ai_document_parser.py:2362`, `:2432` |
| 12 | تنظيف exporter/importer بيتم على النص الكامل للمستند مش على الحقل | `modules/import_documentation/ai_document_parser.py:2962-2963`, `:3227-3228`, `:3295-3296` |
| 13 | `cross_match_certificates_service` و`get_central_archive_service` و`extract_and_match_invoice_bl_service` بيقروا الـ ImportFile بدون فلتر `is_active` | `modules/import_documentation/service.py:4448`, `:5522`, `:4853` |
| 14 | نص إعفاء "0% ضريبة وارد" للـ EUR.1 ثابت داخل الـ Central Archive (مش من جدول التعريفة)، وفallback للمنشأ `"European Union / International"` | `modules/import_documentation/service.py:5588`, `:5601`, `:5570` |
| 15 | `get_acid_tracker_service` بيحمّل كل الملفات والـ clearances في الذاكرة (single-laptop scale مقصود DOC-24) | `modules/import_documentation/service.py:597`, `:611` |

**Flutter**
- `frontend/lib/features/import_documentation/screens/nafeza_acid_screen.dart:299-306` `_loadAcidGuide` بيقرأ `file.shippingLine` والـ `file` من نوع `dynamic`؛ `ImportFileModel` (`frontend/lib/features/import_files/models/import_file_model.dart`) ما فيهوش `shippingLine` (grep = صفر) فبيرمي NoSuchMethodError واتبلع في `catch (_) {}` → **بانر Experience Guide مش بيظهر**. مفيش حماية من race غير `mounted`.
- قيم احتياطية مخترعة في تصدير/عرض COO: `?? 144` طرد، `?? 10510.0` كجم، `'1774,514 KG'` في `frontend/lib/features/import_documentation/services/coo_export_service.dart:255`, `:257`, `:480`, `:769`, `:863` و`frontend/lib/features/import_documentation/widgets/visual_draft_coo_sheet.dart:282`, `:284`, `:702`, `:1101` (القيم المقابلة في الـ backend اتشالت).
- تصدير Excel لمصفوفة Invoice↔B/L بيطلع 5 أعمدة (بدون `system_value` و`packing_list_value`) رغم إن الجدول بيعرضهم: `frontend/lib/features/import_documentation/widgets/invoice_bl_matcher_tab.dart:2942-2964` مقابل `:1205`.
- `frontend/lib/features/import_documentation/widgets/po_reconciliation_tab.dart:1571-1574` heuristic إعادة تحميل تلقائي لو مجموع الوزن القائم < 100 كجم — منطق business داخل widget.
- label `(+0)` لما مفيش ملفات اتقرأت: `frontend/lib/features/import_documentation/widgets/invoice_bl_matcher_tab.dart:185`.

**Code ↔ Business doc**
- `docs/phase_03_import_documentation.md` (BP-016) بيقول دورة `Draft → Received → Under Review → Approved/Rejected`؛ الكود بيضيف `Endorsed` وdefault `Approved` (`modules/import_documentation/model.py:203-206`) وبدون validator للانتقالات، وwhitelist `shipment_doc` (`{Approved, Endorsed}`) مش مستخدمة.
- BP-014 بيقول "منع الشحن قبل ACID معتمد" — لا يوجد enforcement في الـ backend لهذا المنع (تحذيرات Tracker/Legal فقط).
- الـ business doc بيقول "تنبيهات تلقائية عند اقتراب انتهاء ACID" بدون رقم؛ الكود يستخدم 14 يوم في Tracker و+30 يوم من ETA في Legal Compliance (`modules/import_documentation/service.py:67-71`) — قيم ثابتة في الكود (التعليق بيقول هتتنقل لـ system_parameters لاحقًا).

**Tech debt**
- `service.py` ~6,100 سطر (مرشح للتقسيم: acid / banking / draft_bl / coo_inspection / reconciliation / archive). `from modules.import_documentation.schemas import *` في الأعلى (`modules/import_documentation/service.py:26`).
- `ai_document_parser.py` (3428) و`nafeza_acid_parser.py` و`arabic_ocr_engine.py` ملفات إضافية خارج قاعدة الـ 6 ملفات.
- ملفات Flutter عملاقة (`po_reconciliation_tab.dart` 4639، `nafeza_acid_screen.dart` 3683، `draft_bl_review_tab.dart` 3307).
- سماحيات المطابقة (0.5% / 1% / 1.5% / 2% / 3% / 5%، عتبات fuzzy 0.85/0.75/0.70) hard-coded في الكود ومش من Settings.
- استدعاءات LLM الخارجية (`_call_gemini_api/_call_anthropic_api/_call_openai_api` — `modules/import_documentation/ai_document_parser.py:2505`, `:2533`, `:2570`) بتبعت أول 8000 حرف من نص المستند لمزود خارجي لو مفتاحه موجود في البيئة؛ مفيش opt-in في الـ UI. لم يتم التحقق من سياسة الخصوصية المطلوبة للمستندات.

## 📝 Changelog
| التاريخ | Commit / Task | التغيير |
|---|---|---|
| 2026-09-30 | initial doc (base 24eaa01) | توثيق أولي للحالة الحالية للـ module (backend + Flutter + tests). |
| 2026-09-30 | simplify refactor – uncommitted on branch claude/who-are-you-and-team-7415cd | تبسيط behavior-preserving: `ai_document_parser.py` (helpers `_identity_check`, `_header_row`, `_extract_sold_to_party`, `_first_non_header_line`, `_extract_acid`, `_search_group`, `_SEVERITY_BY_STATUS`, `_CODE_STRIP_RE`/`_lazy_code_norms`)، `service.py` (`_extraction_failed_row`، نقل استعلام الـ PO إلى `repository.get_purchase_orders_for_file`)، Flutter (`utils/po_rec_header_checks.dart`, `widgets/extraction_match_status_chip.dart`, `FilePickerHelper.isPlainTextFile/tryDecodeText`, `DisplayDensityMode.byDensity`, `ExperienceGuide matchImportFile`, 17 مفتاح l10n عبر `AppLocalizations.forArabic`). اختبارات جديدة: `tests/unit/test_import_documentation_characterization.py` (+ golden json) و`frontend/test/features/import_documentation/po_rec_header_checks_test.dart` (+ golden). |
| 2026-10-16 | re-verify on company/main 96657fbd | إعادة تحقق كاملة: الـ router بقى محمي (`get_current_user` + `require_permission` view/upload/approve) وافتراض "Kamal" اتشال وهوية المستخدم بتيجي من الـ token؛ إزالة مراجع الـ refactor غير الموجود في الشجرة (helpers الـ parser، `utils/po_rec_header_checks.dart`، `extraction_match_status_chip.dart`، test الـ characterization القديم، `get_purchase_orders_for_file`)؛ تحديث الـ Data Model (أعمدة `created_by`/`updated_by` موجودة بس مش بتتكتب)، وقواعد Draft B/L (قيم السيرفر المملوكة، منع اعتماد مزدوج لنفس المستخدم، approve لدور واحد)، COO (قفل بعد الاعتماد + مبررات)، Inspection (إعادة مقارنة في السيرفر)، PO reconciliation (ملكية الصفوف + إعادة تفعيل الجلسة المحذوفة)، وإضافة لـ Invoice-BL sync (تحقق العملة/Incoterm). إعادة بناء جدول الفجوات (شطب الإصلاحات: أوزان COO في الـ backend، `pl_gw` ValueError، فلتر `is_active` على الـ PO، `supportedLocales`، أعمدة `rowSummary`) وإضافة فجوات جديدة؛ تحديث كل أرقام السطور وتحويل الاستشهادات لمسارات كاملة؛ إضافة الاختبارات الفعلية (`test_phase03a_*`) والرابط من `docs/phase_03_import_documentation.md`. |
| 2026-10-16 | PR #151 (7e10a963) | `POReconciliationItem.package_type` بقى `Optional[str]` (`modules/import_documentation/schemas.py:364`): سطر PO مالوش صف في الـ packing list بيرجع `package_type: null` بدل ما الـ response يفشل validation (كان HTTP 500). الـ Flutter `POReconciliationItemModel.fromJson` بيسيبه فاضي بدل `'Carton'` (`frontend/lib/features/import_documentation/models/import_documentation_model.dart:774`). مرجع `system_packing_items` اتحرك لـ `:927`. |
| 2026-10-16 | simplify refactor (re-applied a6d47051 on 87ac0597) | تبسيط من غير تغيير سلوك: `_header_row` و`_identity_check` و`_extraction_failed_row`، والـ PO lookup اتنقل لـ `get_active_purchase_orders_for_file` (`modules/import_documentation/repository.py:875`). اتضاف `tests/unit/test_import_documentation_characterization.py` (golden على main). 92 مرجع سطر اتحدّثوا لأماكنهم الجديدة. |
