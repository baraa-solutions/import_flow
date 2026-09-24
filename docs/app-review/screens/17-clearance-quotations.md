# طلب ومقارنة عروض التخليص الجمركي (Clearance RFQs & Quotations)
![](../screenshots/17-clearance-quotations-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الأكواد:** `BP-009` الاستشارة الجمركية (عروض المخلصين)، و`BP-027` تجهيز التخليص الجمركي (`doc.md` سطر 1755).
- **الغرض:** إنشاء طلبات عروض أسعار تخليص (CRFQ) للشحنة (الميناء، ونوع الشحنة، والحاويات، والوزن، والحجم، وبند التعريفة)، وإدخال عروض المخلصين يدوياً أو باستخراج AI، ومقارنتها بالبنود (أتعاب التخليص، والنقل الداخلي، والفحص والعرض، والموانئ والتخزين، والنثريات، والإجمالي)، وترسية الأفضل. وكمان إدارة قائمة أسعار ثابتة لبنود التخليص.
- **المستخدمين:** مسؤول الجمارك / المشتريات.
- **الشاشة:** `CustomsClearanceQuotationsScreen` متركّبة **جوه** تاب "Clearance Quotes & AI Extractor" في شاشة 16 (`VerticalStageScaffold`)، فالهيدر والـ Skip / Stop جايين من شاشة 16.

## طريقة الوصول والصلاحية

- **الوصول:** افتح شاشة 16 من الـ sidebar وبعدين التاب الرابع (أو index 55). مالهاش عنصر مستقل في الـ sidebar.
- **الصلاحية:** أي مستخدم مسجل. `dependencies=[Depends(get_current_user)]` ومن غير RBAC (`modules/customs_clearance_quotations/router.py:27-31`).
- **تحميل البيانات:** `addPostFrameCallback` بيجيب الـ RFQs، وقائمة الأسعار، والشركاء، والملفات، والمواقع (`customs_clearance_quotations_screen.dart:42-48`).

## مكونات الشاشة

### الحقول

**شريط الأدوات (تاب 1):** بحث "بحث بكود الطلب، العنوان، أو الميناء..." وفلتر "جميع الحالات".

**Dialog إنشاء طلب عرض أسعار (`_showCreateRFQDialog`، `:832`):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| عنوان الطلب | Text | نعم | required. **القيمة الافتراضية = عنوان الـ dialog** (`:838-840`) | إدخال |
| ربط بملف استيراد (اختياري) | `SearchableDropdownField` | لا | — | `/api/v1/import-files` |
| ميناء التخليص الجمركي | `SearchableDropdownField` | نعم | افتراضي `'Alexandria Port'` (`:846`) | `/api/v1/transport-locations` |
| نوع الشحنة والحاوية | Dropdown | نعم | افتراضي `'Ocean FCL (40HQ)'` | ثابتة |
| عدد الحاويات | Number | نعم | افتراضي 1 | إدخال |
| الوزن القائم (كجم) / الحجم بالمتر المكعب | Number | لا | **افتراضي 10000 / 30** (`:843-844`) | إدخال |

**Dialog إضافة عرض يدوي (`_showAddQuotationDialog`، `:1033`):** المخلص الجمركي، وأتعاب التخليص، والنقل الداخلي، والفحص والعرض، ومصاريف الموانئ، والنثريات (كله بالجنيه)، والمدة المتوقعة بالأيام (`:1079-1192`).

**Dialog إضافة بند لقائمة الأسعار (`_showAddPriceItemDialog`، `:1283`):** المخلص، والميناء، وفئة الخدمة، ونوع الحاوية، والسعر القياسي بالجنيه (`:1313-1374`).

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| 🔄 (فوق) | `ref.invalidate` للـ RFQs وقائمة الأسعار والشركاء (`:80-92`) | GETs | مستخدم مسجل |
| استخراج ذكي لمقايسة تخليص | استخراج AI من نص أو ملف، ويفتح إضافة عرض أو إنشاء طلب بالقيم المستخرجة (`:1275-1277`) | `POST /api/v1/smart-upload/parse-text/clearance-quotation`، و`/smart-upload/upload` | مستخدم مسجل |
| إنشاء طلب عرض أسعار جديد | `_showCreateRFQDialog` | `POST /api/v1/customs-clearance-quotations/rfqs` | مستخدم مسجل |
| تصدير جدول نصوص / تصدير إكسيل / طباعة تقرير بي دي إف / نسخ ملخص المقايسات | تصدير الـ RFQs (معطّلة لو القائمة فاضية) | في الـ client (`CustomsClearanceQuotationsExportService`) | — |
| **في كارت الطلب:** نسخ الكود، ونسخ الطلب | نسخ | — | — |
| إضافة عرض يدوي / استخراج ذكي للعرض | إضافة عرض | `POST /rfqs/{rfq_id}/quotations` | مستخدم مسجل |
| **في صف العرض:** ترسية واعتماد | ترسية | `POST /rfqs/{rfq_id}/award` | مستخدم مسجل |
| 🗑 حذف العرض | حذف بعد تأكيد (`:1423-1446`) | `DELETE /quotations/{quotation_id}` | مستخدم مسجل |
| نسخ صف العرض | نسخ | — | — |
| **تاب 2:** تصدير جدول نصوص / إكسيل / PDF | تصدير قائمة الأسعار | في الـ client | — |
| إنشاء وإدارة قائمة أسعار المخلص الشاملة المؤرخة | يفتح `price_list_form_dialog` | `/api/v1/customs-consultations/price-lists` | مستخدم مسجل |
| إضافة بند لقائمة الأسعار | `_showAddPriceItemDialog` (**خارج الشاشة، شوف الملاحظات**) | `POST /price-list` | مستخدم مسجل |

### الجداول

- **كارت لكل CRFQ:** الكود، والعنوان، والحالة (مسودة / عروض مستلمة)، والميناء، ونوع الشحنة، والوزن، والحجم، وبند التعريفة، وأقل عرض، وأسرع مدة.
- **جدول العروض المستلمة من المخلصين:** الإجمالي التقديري، والنثريات، والموانئ والتخزين، والفحص والعرض، والنقل الداخلي، وأتعاب التخليص، والمخلص الجمركي، والحالة والإجراء.
- **قائمة الأسعار الثابتة (تاب 2):** كانت فاضية ("لا توجد بنود أسعار مسجلة بعد.").

### التابات

1. **طلب ومقارنة عروض التخليص الجمركي:** `17-clearance-quotations-tab-1-clearance-rfqs-quotations-evaluator.png`.
2. **قوائم أسعار بنود التخليص الثابتة:** `17-clearance-quotations-tab-2-master-clearance-price-lists.png`.

### الـ Dialogs

- **إنشاء طلب عرض أسعار:** اتصوّر من شاشة 16، راجع `16-customs-studies-dialog-add.png` و`16-customs-studies-dialog-add-validation.png`. الحفظ من غير أي إدخال أنشأ `CRFQ-000002` بالقيم الافتراضية، وده ظاهر هنا في `17-clearance-quotations-main.png`.
- **إضافة بند لقائمة الأسعار: مفيش screenshot.** الـ harness ماقدرش يوصل للزرار: `OffscreenError: 'إضافة بند لقائمة الأسعار' ... at (1715,352) ... outside the 1600x1000 viewport and wheel scrolling does not bring it into view` (`capture-manifest.json`، screen 17، `status: partial`). يعني المستخدم نفسه مش هيقدر يوصله على الشاشة دي.
- **إضافة عرض يدوي:** من الكود بس.

### التصدير والطباعة

- TSV وExcel عبر `FileSaveHelper.saveText` (TSV باسم `clearance_rfqs_<timestamp>.tsv`)، وPDF عبر `Printing.layoutPdf` (`services/customs_clearance_quotations_export_service.dart:90`، و`:181`، و`:404`، و`:521`، و`:564`، و`:660`).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | صف أزرار الهيدر في تاب قائمة الأسعار أعرض من المساحة (`Row` من غير `Wrap`). زرار "إنشاء وإدارة قائمة أسعار المخلص الشاملة المؤرخة" مقصوص، و"إضافة بند لقائمة الأسعار" **برا الشاشة خالص ومش ممكن توصله** | `17-clearance-quotations-tab-2-master-clearance-price-lists.png`؛ `capture-manifest.json` (OffscreenError)؛ `customs_clearance_quotations_screen.dart:674-745` | `Wrap` أو `ActionToolbar` مع منيو ⋮ |
| High | حذف عرض التخليص **حذف نهائي** (`db.delete`) مش Soft Delete، وده مخالف لـ CORE_RULES §6 | `modules/customs_clearance_quotations/repository.py:129-133` | `is_active=False` زي `delete_rfq` |
| High | Dialog إنشاء الطلب بيحفظ بقيم افتراضية ثابتة (العنوان = عنوان الـ dialog، وAlexandria، و10000 كجم، و30 م³)، وزرار الإنشاء من غير loading state ولا try/catch، فالضغط مرتين بيعمل طلبين | `customs_clearance_quotations_screen.dart:838-846`، و`:1000-1024`؛ `17-clearance-quotations-main.png` (`CRFQ-000002`) | حقول فاضية + `isLoading` + معالجة أخطاء |
| Medium | Exception: `Bad state: Cannot use "ref" after the widget was disposed.` اتسجل مرة أثناء تصوير الشاشة دي (09:37:24)، وبنفس الـ JS frame (`main.dart.js:192335`) اللي ظهر في شاشة 12، فالمصدر غالباً كود مشترك. مرشح محتمل (مش مؤكد): `addPostFrameCallback` بيستخدم `ref.read` من غير فحص `mounted` | `runtime-errors.json` (17-clearance-quotations)؛ `customs_clearance_quotations_screen.dart:42-48` | حدد المصدر بـ debug build، وحط `if (!mounted) return;` في أول الـ callback |
| Medium | 35 `ElevatedButton` و26 `Color(0x..)` و77 `Colors.`، ومفيش ولا `AppButton` | `customs_clearance_quotations_screen.dart` (عدّ grep) | توحيد |
| Low | اسم ملف تصدير TSV عام بـ timestamp (`clearance_rfqs_<ms>.tsv`) ومخالف لقاعدة التسمية `[Stage] - [File]` | `services/customs_clearance_quotations_export_service.dart:90-96` | اسم قياسي |
| Low | Console: `Accept-Encoding` (7 مرات). **فرق Web بس** | `runtime-errors.json` | — |
