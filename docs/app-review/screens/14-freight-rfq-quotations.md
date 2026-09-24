# طلب ومقارنة عروض النولون والترسية (Freight RFQ & Quotations Comparison)
![](../screenshots/14-freight-rfq-quotations-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الأكواد:** `BP-008` إدارة طلبات عروض أسعار الشحن (RFQ)، و`BP-017` اختيار مقدم خدمة الشحن، و`MD-026` (حسب `inventory.json`). بتعتمد على `MD-003` (مزودي خدمة الشحن).
- **الغرض:** إنشاء طلب عرض سعر نولون (RFQ) لشحنة (المسار، والموانئ، والحجم، والوزن، ونوع الرص)، وإدخال عروض الخطوط الملاحية يدوياً أو باستخراج AI، ومقارنتها (أقل سعر، وأسرع ترانزيت)، وترسية العرض الفايز.
- **المستخدمين:** مسؤول الشحن / المشتريات اللوجستية.
- **نوع الشاشة:** Type C (Utility / workspace)، بهيدر مخصوص.

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar: "استعلامات" ← "طلب ومقارنة عروض النولون والترسية" (index 49). تعليقات `navigation_provider.dart` بتقول إن index 49 هو `FreightQuotationsComparisonScreen`، لكن اللي بيتركّب فعلاً هو `FreightQuotationsScreen` (`inventory.json`).
- **الصلاحية:** أي مستخدم مسجل (`modules/freight_quotations/router.py`، على مستوى الـ router: `get_current_user`)، ومن غير RBAC.
- **تحميل البيانات:** `initState` بيجيب الـ RFQs وملفات الاستيراد (`freight_quotations_screen.dart:79-82`).

## مكونات الشاشة

### الحقول

**بيانات شحنة طلب عرض الأسعار (Freight RFQ Setup):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة الاستيرادية (Import File) | `SearchableDropdownField` | لا | — | `/api/v1/import-files` |
| عنوان طلب عرض الأسعار | Text | نعم | "يرجى إدخال العنوان" (`:1918`). **قيمته الافتراضية نص تجريبي** | إدخال |
| وسيلة الشحن (Shipping Method) | `SearchableDropdownField` (Ocean FCL …) | نعم | — | ثابتة |
| تاريخ جاهزية البضاعة (CRD) | Date | نعم | — | — |
| ميناء التحميل (POL) / ميناء الوصول (POD) | `SearchableDropdownField` | نعم | — | `/api/v1/transport-locations` |
| إجمالي الحجم (CBM) / الوزن القائم (Gross Wt kg) | Number | لا | — | **افتراضي 128.5 / 48500.0** (`:45-46`) |
| نوع التحميل والتخزين | Toggle: بضائع قابلة للرص / غير قابلة للرص | — | — | يأثر على اقتراح الحاويات |

**Dialog إضافة عرض سعر ناقل (`_addQuotationDialog`، `:455-660`):** شركة الشحن أو الخط الملاحي (إلزامي)، واسم السفينة، ورقم الرحلة، ونولون الشحن البحري بالدولار (إلزامي، **افتراضي 3000**)، والمصاريف المحلية (**افتراضي 400**)، والنقل الداخلي، وتاريخ الإبحار، وتاريخ الوصول، وفترة السماح (**افتراضي 14**)، وملاحظات وشروط العرض.

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| دراسات النولون والسجلات (هيدر) | `selectNavigationIndex(ref, 4)`، بيفتح شاشة 13 | — | — |
| طلب جديد (هيدر) | `_resetRFQForm` | — | — |
| استدعاء طلب مسجل (هيدر) | `_showLoadSavedRFQDialog` | `GET /api/v1/freight-quotations` | مستخدم مسجل |
| حفظ وتثبيت طلب مقارنة النولون | `_saveRFQ` (فيه spinner `_isSaving`، `:1854-1855`) | `POST /api/v1/freight-quotations` / `PUT /{rfqId}` | مستخدم مسجل |
| أداة AI "استخراج وقراءة عروض أسعار الشحن والنولون (Freight Quotation AI)": لصق نص العرض، وتفريغ، ونموذج تجريبي، ورفع مستند عرض السعر، واستخراج وتحليل عروض السعر، و"طي الأداة" (⌃ لطي اللوحة) | استخراج عروض من نص أو ملف | `POST /api/v1/smart-upload/parse-text/freight-quotation`، و`/smart-upload/upload` | مستخدم مسجل |
| مقارنة الحالتين | `_showContainerComparisonDialog` (رص / بدون رص) | — | — |
| استخراج عروض الأسعار الذكي | `FreightQuotationsExtractorDialog` | `/smart-upload/...` | — |
| إضافة عرض سعر ناقل | `_addQuotationDialog` | — (بيتحفظ مع الـ RFQ) | — |
| (لما تبقى فيه عروض) ترسية، وBenchmark، وتصدير TSV / Excel / PDF | ترسية العرض، والمقارنة بالسوق، والتصدير | `POST /{rfqId}/award/{quotationId}`، و`GET /{id}/benchmark` | مستخدم مسجل |

### الجداول

- **مؤشرات:** أقل سعر شحن متوفر، وأسرع زمن ترانزيت، وعدد عروض الناقلين.
- **عروض أسعار الخطوط الملاحية والشركات المنافسة:** بتظهر بعد إضافة عروض (الناقل، والسفينة / الرحلة، والنولون، والمصاريف المحلية، والنقل الداخلي، والإجمالي، والإبحار / الوصول، وأيام السماح، والحالة / الترسية). في الصورة القائمة فاضية، ومن غير رسالة empty-state.
- اقتراح الحاويات التلقائي: "2 x 40HC Container(s) ... استغلال المساحة 94.9%".

### التابات

مفيش تابات. وضع "قابلة للرص / غير قابلة للرص" segments مش تابات.

### الـ Dialogs

- **"طلب جديد" مش dialog.** بيفضّي الفورم inline (`capture-manifest.json`)، والصورة `14-freight-rfq-quotations-dialog-add.png`.
- **الـ validation:** `14-freight-rfq-quotations-dialog-add-validation.png`. بعد "طلب جديد" بقى العنوان "طلب عرض سعر شحن جديد" والـ CBM / الوزن 0.0. الحفظ طلّع SnackBar برتقالي "⚠️ يرجى إضافة عرض سعر واحد على الأقل للمقارنة"، ومفيش أخطاء inline لأن كل الحقول الإلزامية متعبّية افتراضياً.
- من الكود: `_showLoadSavedRFQDialog`، و`_addQuotationDialog`، و`_showRFQDetailsDialog`، و`RFQBenchmarkDialog`، و`FreightQuotationsExtractorDialog`، ومقارنة الحاويات.

### التصدير والطباعة

- تصدير TSV / Excel(CSV) / PDF للمقارنة عن طريق `FreightQuotationsExportService` (`freight_quotations_screen.dart:2203-2231`): TSV وCSV عبر `FileSaveHelper.saveText` بأسماء `Freight_Quotations_<code>_<date>.tsv/.csv`، والـ PDF عبر `Printing.layoutPdf` (`services/freight_quotations_export_service.dart:210`، و`:271`، و`:423`).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | الشاشة بتفتح بقيم تجريبية ثابتة: عنوان "طلب عرض سعر شحن حاويات لمعدات وآلات خط الإنتاج"، وCBM 128.5، ووزن 48500. ودي بتطلع اقتراح حاويات وهمي (2 x 40HC)، وممكن تتحفظ على إنها بيانات حقيقية | `freight_quotations_screen.dart:45-46`، و`:1778-1781`؛ `14-freight-rfq-quotations-main.png` | ابدأ الحقول فاضية أو من ملف الاستيراد المختار |
| Medium | Dialog إضافة العرض بيملى أسعار افتراضية (نولون 3000$، ومحلي 400$، وسماح 14 يوم). عرض ممكن يتحفظ بأرقام محدش أدخلها | `freight_quotations_screen.dart:461-464` | خلّيها فاضية مع required validator |
| Medium | مفيش زرار "العودة للداش بورد" ولا 🔄 Refresh في الهيدر (إلزاميين في كل الشاشات، Skill §2) | `14-freight-rfq-quotations-main.png`؛ `freight_quotations_screen.dart:1770-1830` (عدّ `BackToDashboardButton` = 0) | أضف `BackToDashboardButton` في الآخر و🔄 |
| Medium | الشاشة فيها 144 ternary بـ `isArabic ? '...' : '...'` بنصوص ثابتة بدل l10n، والـ SnackBar بتاع الحفظ عربي ثابت | `freight_quotations_screen.dart:1584`، و`:524-653`، و`:1886-2012` | `context.l10n` |
| Medium | Labels مخلوطة لغتين في نفس النص: "ملف الشحنة الاستيرادية (Import File)"، و"وسيلة الشحن (Shipping Method)"، و"(Freight RFQ Setup)" | `14-freight-rfq-quotations-main.png`؛ `freight_quotations_screen.dart:1886`، و`:1926` | لغة واحدة |
| Low | قائمة العروض الفاضية من غير أي رسالة ("لا توجد عروض") | `14-freight-rfq-quotations-main.png` | empty-state |
| Low | الـ Excel بيطلع CSV، والـ picker بيسمح بـ `xlsx`، وأسماء الملفات مش على المعيار `[Stage] - [File]` | `services/freight_quotations_export_service.dart:270-276` | امتداد صح واسم قياسي |
| Low | Console: `Accept-Encoding` (مرتين). **فرق Web بس** | `runtime-errors.json` | — |
| Low | 22 `ElevatedButton` و114 `Colors.` بدل `AppButton` / `AppTheme` | `freight_quotations_screen.dart` (عدّ grep) | توحيد |
