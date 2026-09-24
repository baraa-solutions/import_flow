# مراجعة شاشات ImportFlow ERP — الفهرس

> **الصور محلية بس ومتعملهاش commit في git**: `docs/app-review/screenshots/` متضاف في `.gitignore`. لو الصور مش موجودة عندك أو عايز تحدّثها، شغّل الـ harness من جذر الـ worktree:

```bash
cd D:/projects/import_flow/.claude/worktrees/project-feedback-e6bfde && python scripts/app_review/capture_web.py --credentials "C:/Users/KAMALS~1/AppData/Local/Temp/claude/D--projects-import-flow--claude-worktrees-project-feedback-e6bfde/ec38e148-eaf2-459d-a583-6225835cc034/scratchpad/appreview/review_credentials.json" --debug-dir "C:/Users/KAMALS~1/AppData/Local/Temp/claude/D--projects-import-flow--claude-worktrees-project-feedback-e6bfde/ec38e148-eaf2-459d-a583-6225835cc034/scratchpad/appreview/debug"
```

- شغّله في الخلفية بـ timeout ساعتين على الأقل: 61 شاشة، وكل شاشة بتاخد من نص دقيقة لدقيقة ونص تقريباً.
- بدل `--credentials` ممكن تحط `REVIEW_USER` و `REVIEW_PASSWORD` كـ environment variables.
- `--group <key>` و `--only <slug|NN,...>` بيفلتروا الشاشات. كل run بيدمج نتايجه في `capture-manifest.json` و `runtime-errors.json`، فتقدر تعيد تشغيل جزء بس من غير مشاكل.
- الـ harness محتاج الباك إند شغال على `http://127.0.0.1:28080` على قاعدة **scratch** (بـ `DATABASE_PATH`، مش `sorour_logistics.db` الحقيقية)، ونسخة web release من الفرونت شغالة على `http://127.0.0.1:8088`.

**الملفات:** [findings.md](findings.md) (كل الملاحظات مرتبة حسب الخطورة، وأهم 10 تتصلح الأول) · `inventory.json` (جرد الشاشات) · `capture-manifest.json` (حالة التصوير لكل شاشة) · `runtime-errors.json` (أخطاء التشغيل) · `elements/` (جرد العناصر لكل صورة) · `screens/` (شرح كل شاشة).

## المراجعة اتعملت إزاي

- **المنصة:** الـ spec (`docs/prompts/app-review.md`) كان طالب تصوير تطبيق **Windows desktop**. الجهاز مفيهوش Visual Studio، فـ `flutter build windows` مش هيشتغل. عشان كده التصوير اتعمل على **نسخة Flutter Web (release)** شغالة في Chromium عن طريق Playwright (`scripts/app_review/capture_web.py`)، بمقاس 1600×1000 و device scale 1.5، واللغة عربي (اتغيرت من الـ UI).
- **البيانات:** الباك إند (FastAPI) اشتغل على بورت 28080 على **نسخة scratch** من قاعدة البيانات، متملية ببيانات تجريبية. الـ harness ملمسش `sorour_logistics.db` الحقيقية ولا `.env`. (استثناء اتسجل كـ Critical: شاشة Production Sync بتتجاهل `DATABASE_PATH` واتعمل منها نسختين backup من القاعدة الحقيقية أثناء المراجعة. شوف [57-production-sync](screens/57-production-sync.md).)
- **الشرح:** لكل مجموعة مراحل agent قرا الصور و `elements/*.json` والكود (الشاشة والـ provider والـ router والـ service) وكتب `screens/<NN>-<screen>.md`. وبعده agent تحقق راجع إن كل عنصر ظاهر متشرح وإن كل ملاحظة ليها دليل (صورة أو ملف:سطر)، وشال 12 ملاحظة ملهاش دليل.
- **مراجعة وتوثيق بس:** مفيش أي تعديل في كود التطبيق (`frontend/lib` و `modules/`). كل bug اتسجل في التقرير.

### ملاحظة: تشغيل نسخة الديسكتوب (Windows)

عشان تبني وتشغّل التطبيق كـ Windows desktop (وتنفّذ الـ spec الأصلي بالتصوير على الديسكتوب)، محتاج تسطّب:

1. **Visual Studio 2022** (نسخة Community المجانية كفاية) من https://visualstudio.microsoft.com/downloads/
2. أثناء التسطيب اختار الـ workload اللي اسمه **"Desktop development with C++"**.
3. بعد التسطيب شغّل `flutter doctor` واتأكد إن سطر Visual Studio بقى أخضر. بعدها `flutter run -d windows` هيشتغل.

### حدود نسخة الويب (Web-only limitations)

- الـ release build بيشيل الـ debug asserts، فأخطاء **RenderFlex overflow** ومعظم `FlutterError` **مش بتتسجل** في `runtime-errors.json`. الـ overflow اللي في التقرير اتلاحظ من الصور، أو من إن الـ harness ملقاش زرار جوه الـ viewport (`OffscreenError`). عشان تمسك الـ overflow، ابني `flutter build web --debug` وشغّل الـ harness بـ `--base-url`.
- أي حاجة خاصة بـ Windows (`window_manager`، ونوافذ حفظ الملفات الـ native، و `Process.run` / `launchUrlNative`، والـ platform channels) مينفعش تتجرب على الويب. الملاحظات دي متعلّمة **(Web-only)** في التقرير (19 ملاحظة).
- الـ console على الويب فيه ضوضاء مالهاش أثر على الديسكتوب، أشهرها `Refused to set unsafe header "Accept-Encoding"` من Dio.
- **مشكلة الـ locale المعروفة:** `main.dart` بيحدد `locale: ar` من غير `supportedLocales`، فـ `Localizations.localeOf` بيرجع `en_US`، وعناصر كتير (عناوين الـ headers، والتابات الرأسية، ونصوص Material) بتظهر إنجليزي حتى في الوضع العربي. محتوى الشاشات نفسه بيترسم RTL، بس الـ sidebar فاضل على الشمال. دي مشكلة واحدة في `main.dart`، اتسجلت ومتصلحتش.

## إحصائيات التصوير

| البند | القيمة |
|---|---|
| إجمالي الشاشات في الجرد | 61 |
| شاشات اتشرحت (`screens/*.md`) | 61 / 61 |
| شاشات اتصورت (فيها صورة واحدة على الأقل) | 56 / 61 |
| حالة التصوير | ok 46 · partial 10 · failed 2 · skipped 3 |
| عدد الصور | 182 صورة PNG (58.2 MB، تحت حد الـ 100 MB) |
| أحداث أخطاء التشغيل (`runtime-errors.json`) | 526 حدث (console errors و HTTP ≥ 400) |
| الملاحظات | 597: Critical 12 · High 84 · Medium 240 · Low 261 |

**الشاشات اللي فشل تصويرها أو اتخطّت (اتشرحت من الكود بس):**

- [15-freight-quotations-comparison-legacy](screens/15-freight-quotations-comparison-legacy.md): اتخطّت: مش ممكن توصلها، الـ widget مش متستخدم في أي مكان في `frontend/lib`.
- [31-shipment-draft-docs-matrix](screens/31-shipment-draft-docs-matrix.md): فشل (bug حقيقي): زرار "مصفوفة المستندات (DC-04)" في صف عنوان `ImportFileDetailsDialog` بيترسم عند x≈4290 في viewport عرضه 1600، ومفيش scroll يوصله (`import_file_details_dialog.dart` حوالين سطر 498 و 658).
- [32-import-documentation-wrapper](screens/32-import-documentation-wrapper.md): اتخطّت: wrapper رفيع حوالين `ShipmentDraftDocsScreen` ومش متستخدم.
- [60-system-observability](screens/60-system-observability.md): فشل (bug معروف): عنصر الـ sidebar بينادي index 69، و `_totalScreens = 68`، فالشاشة مبتتغيرش.
- [61-streamlit-board-legacy](screens/61-streamlit-board-legacy.md): اتخطّت: مش متستخدمة في أي مكان في `frontend/lib`.

**الشاشات الـ partial** (الصورة الرئيسية موجودة بس فيه حالة ناقصة، والسبب في `capture-manifest.json`):

- تابات مش موجودة في الـ semantics tree (شرطية، أو متداخلة، أو اتشالت من الـ UI): 16 (تاب 5 و 6)، 34 (تاب 2 و 3)، 35 (تاب 3 و 4)، 43 (التابين)، 44.
- مفيش زرار حفظ في dialog الإضافة: 18، 22، 29.
- 17: زرار "إضافة بند لقائمة الأسعار" عند x=1715 برا الـ viewport (overflow حقيقي في صف أزرار الهيدر).
- 37: modal "إصدار شهادة" مبيتقفلش بـ Escape.

## فهرس الشاشات حسب مراحل دورة الاستيراد

عمود الملاحظات: Critical / High / Medium / Low.

### البيانات المرجعية (Master Data)

| # | الشاشة | صورة | التصوير | الملاحظات (C/H/M/L) |
|---|---|---|---|---|
| 01 | [الشركات المستوردة المصرية (Import Companies)](screens/01-import-companies.md) | <img src="screenshots/01-import-companies-main.png" width="240" alt="01-import-companies"> | ok (صور: 3) | 0 / 1 / 7 / 10 |
| 02 | [دليل الموردين والمصدرين الأجانب (Foreign Suppliers)](screens/02-foreign-suppliers.md) | <img src="screenshots/02-foreign-suppliers-main.png" width="240" alt="02-foreign-suppliers"> | ok (صور: 3) | 0 / 1 / 7 / 5 |
| 03 | [الشركاء ومقدمو الخدمات الخارجية (Partners & Banks)](screens/03-partners-banks.md) | <img src="screenshots/03-partners-banks-main.png" width="240" alt="03-partners-banks"> | ok (صور: 3) | 0 / 0 / 7 / 7 |
| 04 | [مشاريع الاستيراد ومراكز التكلفة (Projects & Cost Centers)](screens/04-projects.md) | <img src="screenshots/04-projects-main.png" width="240" alt="04-projects"> | ok (صور: 3) | 0 / 2 / 6 / 7 |
| 05 | [الموانئ والمنافذ الجمركية (Ports & Locations)](screens/05-ports-locations.md) | <img src="screenshots/05-ports-locations-main.png" width="240" alt="05-ports-locations"> | ok (صور: 3) | 0 / 1 / 3 / 7 |
| 06 | [الشروط التجارية الدولية (Incoterms Rules)](screens/06-incoterms.md) | <img src="screenshots/06-incoterms-main.png" width="240" alt="06-incoterms"> | ok (صور: 6) | 0 / 1 / 2 / 7 |
| 07 | [جدول التعريفة الجمركية وبنود HS (Customs Tariff & HS Codes)](screens/07-customs-tariff.md) | <img src="screenshots/07-customs-tariff-main.png" width="240" alt="07-customs-tariff"> | ok (صور: 5) | 0 / 2 / 4 / 6 |
| 08 | [مستكشف البنود الجمركية وحاسبة الرسوم (HS Code Explorer & Duty Calculator)](screens/08-hs-code-explorer.md) | <img src="screenshots/08-hs-code-explorer-main.png" width="240" alt="08-hs-code-explorer"> | ok (صور: 6) | 0 / 2 / 4 / 8 |
| 09 | [العملات وأسعار الصرف (Currencies & Rates)](screens/09-currencies.md) | <img src="screenshots/09-currencies-main.png" width="240" alt="09-currencies"> | ok (صور: 3) | 0 / 2 / 3 / 7 |

### التخطيط والدراسات المسبقة وأوامر الشراء

| # | الشاشة | صورة | التصوير | الملاحظات (C/H/M/L) |
|---|---|---|---|---|
| 10 | [ملفات الشحنات الاستيرادية (Import Files)](screens/10-import-files.md) | <img src="screenshots/10-import-files-main.png" width="240" alt="10-import-files"> | ok (صور: 3) | 0 / 2 / 7 / 6 |
| 11 | [أوامر الشراء وإثبات المنشأ (Purchase Orders & Origin)](screens/11-purchase-orders.md) | <img src="screenshots/11-purchase-orders-main.png" width="240" alt="11-purchase-orders"> | ok (صور: 3) | 0 / 2 / 6 / 4 |
| 12 | [حاسبة الأحجام وتوزيع الحاويات (Cargo Measurement Engine (CBM))](screens/12-cbm-calculator.md) | <img src="screenshots/12-cbm-calculator-main.png" width="240" alt="12-cbm-calculator"> | ok (صور: 5) | 0 / 0 / 5 / 4 |
| 13 | [دراسة النولون والجدول الزمني وسيناريوهات الشحن (Freight Studies & Shipping Scenarios)](screens/13-shipping-scenarios.md) | <img src="screenshots/13-shipping-scenarios-main.png" width="240" alt="13-shipping-scenarios"> | ok (صور: 5) | 0 / 1 / 3 / 4 |
| 14 | [طلب ومقارنة عروض النولون والترسية (Freight RFQ & Quotations Comparison)](screens/14-freight-rfq-quotations.md) | <img src="screenshots/14-freight-rfq-quotations-main.png" width="240" alt="14-freight-rfq-quotations"> | ok (صور: 3) | 0 / 1 / 4 / 4 |
| 15 | [مقارنة عروض النولون - نسخة غير مستخدمة (Freight Quotations Comparison (orphan))](screens/15-freight-quotations-comparison-legacy.md) | مفيش صورة | skipped (صور: 0) | 0 / 0 / 2 / 3 |
| 16 | [الدراسات الجمركية وعروض التخليص ومراجعة الضرائب (Customs Studies & Clearance RFQ)](screens/16-customs-studies.md) | <img src="screenshots/16-customs-studies-main.png" width="240" alt="16-customs-studies"> | partial (صور: 7) | 1 / 2 / 5 / 4 |
| 17 | [طلب ومقارنة عروض التخليص الجمركي (Clearance RFQs & Quotations)](screens/17-clearance-quotations.md) | <img src="screenshots/17-clearance-quotations-main.png" width="240" alt="17-clearance-quotations"> | partial (صور: 3) | 0 / 3 / 2 / 2 |
| 18 | [متطلبات واشتراطات الاستيراد للشحنة (Import Regulatory Requirements)](screens/18-import-requirements.md) | <img src="screenshots/18-import-requirements-main.png" width="240" alt="18-import-requirements"> | partial (صور: 4) | 0 / 1 / 5 / 4 |
| 19 | [استعلام وسجل الشحنات والتكاليف التاريخية (Shipment History & Inquiry)](screens/19-shipment-inquiry.md) | <img src="screenshots/19-shipment-inquiry-main.png" width="240" alt="19-shipment-inquiry"> | ok (صور: 1) | 0 / 2 / 4 / 3 |

### الموافقات المالية والسداد

| # | الشاشة | صورة | التصوير | الملاحظات (C/H/M/L) |
|---|---|---|---|---|
| 20 | [اعتمادات الميزانية وسداد الموردين (Finance Approvals & Budget)](screens/20-financial-approvals.md) | <img src="screenshots/20-financial-approvals-main.png" width="240" alt="20-financial-approvals"> | ok (صور: 8) | 0 / 3 / 8 / 8 |
| 21 | [استخراج ومطابقة السويفت (SWIFT MT103 Reconciliation)](screens/21-swift-reconciliation.md) | <img src="screenshots/21-swift-reconciliation-main.png" width="240" alt="21-swift-reconciliation"> | ok (صور: 1) | 0 / 0 / 5 / 5 |

### المستندات والتوثيق (ACID / نموذج 4 / المسودات / CargoX)

| # | الشاشة | صورة | التصوير | الملاحظات (C/H/M/L) |
|---|---|---|---|---|
| 22 | [الرقم التعريفي المبدئي للشحنة ACID (ACID Operations (Nafeza))](screens/22-nafeza-acid.md) | <img src="screenshots/22-nafeza-acid-main.png" width="240" alt="22-nafeza-acid"> | partial (صور: 7) | 0 / 2 / 7 / 4 |
| 23 | [النموذج الإحصائي والتحويل البنكي نموذج 4 (Bank Form 4)](screens/23-bank-form-4.md) | <img src="screenshots/23-bank-form-4-main.png" width="240" alt="23-bank-form-4"> | ok (صور: 5) | 0 / 2 / 4 / 4 |
| 24 | [مطابقة الفاتورة والباكينج مع أمر الشراء (PO & Packing Reconciliation)](screens/24-po-packing-reconciliation.md) | <img src="screenshots/24-po-packing-reconciliation-main.png" width="240" alt="24-po-packing-reconciliation"> | ok (صور: 1) | 0 / 0 / 5 / 3 |
| 25 | [مراجعة واعتماد مسودة بوليصة الشحن (Draft B/L Review & Approval)](screens/25-draft-bl-review.md) | <img src="screenshots/25-draft-bl-review-main.png" width="240" alt="25-draft-bl-review"> | ok (صور: 1) | 0 / 2 / 3 / 3 |
| 26 | [المطابقة الذكية بين الفاتورة والبوليصة (Smart Invoice vs B/L Match)](screens/26-smart-invoice-bl-match.md) | <img src="screenshots/26-smart-invoice-bl-match-main.png" width="240" alt="26-smart-invoice-bl-match"> | ok (صور: 1) | 0 / 0 / 3 / 4 |
| 27 | [مسودة شهادة المنشأ و EUR.1 (Draft COO & EUR.1 Review)](screens/27-draft-coo-review.md) | <img src="screenshots/27-draft-coo-review-main.png" width="240" alt="27-draft-coo-review"> | ok (صور: 1) | 1 / 1 / 3 / 3 |
| 28 | [شهادات الفحص والتفتيش والمطابقة (Inspection Review (COC))](screens/28-inspection-review.md) | <img src="screenshots/28-inspection-review-main.png" width="240" alt="28-inspection-review"> | ok (صور: 1) | 0 / 0 / 5 / 2 |
| 29 | [مركز اعتماد المستندات وتعديلات المورد (Docs Customs Approval Hub)](screens/29-docs-customs-approval.md) | <img src="screenshots/29-docs-customs-approval-main.png" width="240" alt="29-docs-customs-approval"> | partial (صور: 2) | 0 / 1 / 3 / 4 |
| 30 | [الأرشيف المركزي لمستندات وتعديلات الشحنة (Central Docs & Rectifications Hub)](screens/30-central-docs-archive.md) | <img src="screenshots/30-central-docs-archive-main.png" width="240" alt="30-central-docs-archive"> | ok (صور: 1) | 0 / 0 / 2 / 4 |
| 31 | [مصفوفة مستندات الشحنة (المسودات والاعتماد) (Shipment Draft Documents Matrix (DC-04))](screens/31-shipment-draft-docs-matrix.md) | مفيش صورة | failed (صور: 0) | 0 / 1 / 2 / 3 |
| 32 | [غلاف مستندات الاستيراد، غير مستخدم (Import Documentation Wrapper (orphan))](screens/32-import-documentation-wrapper.md) | مفيش صورة | skipped (صور: 0) | 0 / 0 / 0 / 2 |
| 33 | [أصول المستندات ومنظومة CargoX الرقمية (Original Docs & CargoX Hub)](screens/33-original-docs-cargox.md) | <img src="screenshots/33-original-docs-cargox-main.png" width="240" alt="33-original-docs-cargox"> | ok (صور: 3) | 0 / 1 / 4 / 1 |
| 34 | [منظومة كارجو إكس والمانيفست الرقمي (CargoX Blockchain & ACI Hub)](screens/34-cargox-hub.md) | <img src="screenshots/34-cargox-hub-main.png" width="240" alt="34-cargox-hub"> | partial (صور: 3) | 0 / 1 / 4 / 5 |

### حجز الشحن والتحميل والتأمين

| # | الشاشة | صورة | التصوير | الملاحظات (C/H/M/L) |
|---|---|---|---|---|
| 35 | [حجز النولون وتأكيد الخط الملاحي (Freight Booking)](screens/35-freight-booking.md) | <img src="screenshots/35-freight-booking-main.png" width="240" alt="35-freight-booking"> | partial (صور: 5) | 0 / 3 / 9 / 6 |
| 36 | [حركة وتتبع الشحن وتوزيع الحاويات (Cargo Shipping & Tracking)](screens/36-cargo-shipping.md) | <img src="screenshots/36-cargo-shipping-main.png" width="240" alt="36-cargo-shipping"> | ok (صور: 5) | 1 / 2 / 7 / 6 |
| 37 | [شهادات ووثائق التأمين على البضائع (Cargo Insurance)](screens/37-cargo-insurance.md) | <img src="screenshots/37-cargo-insurance-main.png" width="240" alt="37-cargo-insurance"> | partial (صور: 5) | 0 / 2 / 8 / 8 |

### الميناء والتخليص الجمركي

| # | الشاشة | صورة | التصوير | الملاحظات (C/H/M/L) |
|---|---|---|---|---|
| 38 | [شهادة الإجراءات الجمركية إقرار 46 ك.م (Customs Declaration 46)](screens/38-customs-declaration-46.md) | <img src="screenshots/38-customs-declaration-46-main.png" width="240" alt="38-customs-declaration-46"> | ok (صور: 5) | 2 / 2 / 5 / 4 |
| 39 | [متابعة التخليص والكشف والعينات والرسوم (Customs Clearance Hub)](screens/39-customs-clearance.md) | <img src="screenshots/39-customs-clearance-main.png" width="240" alt="39-customs-clearance"> | ok (صور: 7) | 1 / 4 / 2 / 6 |
| 40 | [تتبع غرامات الأرضيات وحراسات الحاويات (Demurrage & Detention)](screens/40-demurrage-detention.md) | <img src="screenshots/40-demurrage-detention-main.png" width="240" alt="40-demurrage-detention"> | ok (صور: 6) | 1 / 2 / 4 / 3 |

### الاستلام المخزني والتسوية المالية والإغلاق

| # | الشاشة | صورة | التصوير | الملاحظات (C/H/M/L) |
|---|---|---|---|---|
| 41 | [مركز الاستلام والمخازن والبضاعة بالطريق (Inbound & Warehouse Hub)](screens/41-inbound-warehouse-hub.md) | <img src="screenshots/41-inbound-warehouse-hub-main.png" width="240" alt="41-inbound-warehouse-hub"> | ok (صور: 6) | 0 / 1 / 1 / 4 |
| 42 | [رصيد ومطابقة البضاعة في الطريق (Goods In Transit (GIT) Ledger)](screens/42-goods-in-transit.md) | <img src="screenshots/42-goods-in-transit-main.png" width="240" alt="42-goods-in-transit"> | ok (صور: 2) | 1 / 2 / 3 / 4 |
| 43 | [استلام المخازن وأذون الإضافة (Warehouse Receiving & GRN)](screens/43-warehouse-receiving-grn.md) | <img src="screenshots/43-warehouse-receiving-grn-main.png" width="240" alt="43-warehouse-receiving-grn"> | partial (صور: 3) | 1 / 6 / 8 / 2 |
| 44 | [تقرير ومطابقة الشحنات المستلمة (Received Shipments Audit Report)](screens/44-warehouse-received-report.md) | <img src="screenshots/44-warehouse-received-report-main.png" width="240" alt="44-warehouse-received-report"> | partial (صور: 1) | 0 / 2 / 3 / 4 |
| 45 | [تكلفة الوصول والتسوية المالية ومقارنة الفروق (Landed Cost & Settlement Hub)](screens/45-financial-settlement.md) | <img src="screenshots/45-financial-settlement-main.png" width="240" alt="45-financial-settlement"> | ok (صور: 6) | 0 / 7 / 5 / 3 |
| 46 | [مقارنة التكلفة التقديرية والفعلية (Estimated vs Actual Landed Cost)](screens/46-landed-cost-comparison.md) | <img src="screenshots/46-landed-cost-comparison-main.png" width="240" alt="46-landed-cost-comparison"> | ok (صور: 1) | 1 / 1 / 3 / 3 |
| 47 | [الإغلاق المالي والإداري لملف الاستيراد (Import File Final Closure)](screens/47-file-closure.md) | <img src="screenshots/47-file-closure-main.png" width="240" alt="47-file-closure"> | ok (صور: 5) | 0 / 4 / 8 / 2 |

### لوحات القيادة والتقارير وإعدادات النظام

| # | الشاشة | صورة | التصوير | الملاحظات (C/H/M/L) |
|---|---|---|---|---|
| 48 | [تسجيل الدخول (Login)](screens/48-login.md) | <img src="screenshots/48-login-main.png" width="240" alt="48-login"> | ok (صور: 2) | 1 / 0 / 3 / 3 |
| 49 | [الواجهة الرئيسية والقائمة الجانبية (Home Shell & Sidebar)](screens/49-home-shell.md) | <img src="screenshots/49-home-shell-main.png" width="240" alt="49-home-shell"> | ok (صور: 1) | 0 / 1 / 4 / 5 |
| 50 | [لوحة التحكم ومساحة العمليات (Operational Dashboard)](screens/50-operational-dashboard.md) | <img src="screenshots/50-operational-dashboard-main.png" width="240" alt="50-operational-dashboard"> | ok (صور: 1) | 0 / 0 / 1 / 4 |
| 51 | [لوحة تتبع ومتابعة مراحل الشحنات التفاعلية (Lifecycle Operations Board)](screens/51-lifecycle-board.md) | <img src="screenshots/51-lifecycle-board-main.png" width="240" alt="51-lifecycle-board"> | ok (صور: 1) | 0 / 0 / 3 / 3 |
| 52 | [تقرير ملف الاستيراد الشامل والمدمج (Master Shipment Report)](screens/52-master-shipment-report.md) | <img src="screenshots/52-master-shipment-report-main.png" width="240" alt="52-master-shipment-report"> | ok (صور: 1) | 0 / 0 / 1 / 4 |
| 53 | [مُنشئ التقارير الديناميكية والمخصصة (Dynamic Report Builder)](screens/53-dynamic-report-builder.md) | <img src="screenshots/53-dynamic-report-builder-main.png" width="240" alt="53-dynamic-report-builder"> | ok (صور: 1) | 0 / 1 / 1 / 3 |
| 54 | [محرك تحديث الشحنات التشغيلي واليومي (Quick Update Engine)](screens/54-quick-update-engine.md) | <img src="screenshots/54-quick-update-engine-main.png" width="240" alt="54-quick-update-engine"> | ok (صور: 1) | 0 / 1 / 2 / 4 |
| 55 | [إدارة المهام الذكية ومحرك التذكيرات (Smart Tasks & Alerts)](screens/55-smart-tasks.md) | <img src="screenshots/55-smart-tasks-main.png" width="240" alt="55-smart-tasks"> | ok (صور: 3) | 0 / 1 / 2 / 3 |
| 56 | [سجل التدقيق والتتبع التاريخي للنظام (System Audit Logs)](screens/56-audit-logs.md) | <img src="screenshots/56-audit-logs-main.png" width="240" alt="56-audit-logs"> | ok (صور: 1) | 0 / 0 / 3 / 4 |
| 57 | [مركز إدارة التحديثات والنسخ الاحتياطي (Production Sync Hub)](screens/57-production-sync.md) | <img src="screenshots/57-production-sync-main.png" width="240" alt="57-production-sync"> | ok (صور: 5) | 1 / 1 / 5 / 2 |
| 58 | [إدارة المستخدمين والصلاحيات (Users & Permissions)](screens/58-users-permissions.md) | <img src="screenshots/58-users-permissions-main.png" width="240" alt="58-users-permissions"> | ok (صور: 3) | 0 / 0 / 2 / 5 |
| 59 | [إعدادات تصنيف مخاطر المراحل وحوكمة التخطي (Step Risk & Skip Config)](screens/59-step-risk-config.md) | <img src="screenshots/59-step-risk-config-main.png" width="240" alt="59-step-risk-config"> | ok (صور: 1) | 0 / 0 / 1 / 4 |
| 60 | [مركز مراقبة وصحة النظام (System Observability & Health)](screens/60-system-observability.md) | مفيش صورة | failed (صور: 0) | 0 / 1 / 2 / 3 |
| 61 | [لوحة Streamlit القديمة (غير مستخدمة) (Streamlit Board (orphan))](screens/61-streamlit-board-legacy.md) | مفيش صورة | skipped (صور: 0) | 0 / 0 / 0 / 2 |

