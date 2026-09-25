# مقارنة عروض النولون - نسخة غير مستخدمة (Freight Quotations Comparison (orphan))

> **مفيش screenshot للشاشة دي.** الكلاس `FreightQuotationsComparisonScreen` مش بيتعمله instantiate في أي مكان في `frontend/lib`، والإشارات ليه في التعليقات بس (`core/providers/navigation_provider.dart:81` وتعليقات ملفات الـ l10n `app_localizations*.dart:5275/5350`). يعني مفيش طريقة المستخدم يفتحها من التطبيق، والـ harness عمل لها skip (`capture-manifest.json`: `status: "skipped"`، `open_via: "unreachable"`). التوثيق هنا من الكود بس.

> **مفيش صورة:** مكان الصورة الرئيسية في القالب فاضي عن قصد، لأن الملف `screenshots/15-freight-quotations-comparison-legacy-main.png` مش موجود (الشاشة متصورتش). متحطش لينك لصورة مش موجودة.

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الكود:** `BP-008` إدارة عروض أسعار النولون (مقارنة وترسية).
- **الغرض (من الكود):** تختار ملف استيراد، والشاشة تجيب كل عروض النولون المرتبطة بيه من كل الـ RFQs، وتعرض **أول 4 عروض بس** في أعمدة جنب بعض، مع شريط مؤشرات (أرخص عرض، وأسرع عرض، والمختار حالياً)، وزرار ترسية لكل عرض.
- **المستخدمين:** مسؤول الشحن. الوظيفة دي اتنقلت لشاشة 14 (`FreightQuotationsScreen`)، اللي بتتركّب فعلاً على index 49.

## طريقة الوصول والصلاحية

- **الوصول:** مفيش (orphan). تعليق `navigation_provider.dart:81` بيقول `49 = FreightQuotationsComparisonScreen`، لكن `home_screen.dart` بيركّب `FreightQuotationsScreen` على نفس الـ index.
- **الصلاحية (لو اتفتحت):** أي مستخدم مسجل (`modules/freight_quotations/router.py`، على مستوى الـ router: `get_current_user`).

## مكونات الشاشة

### الحقول

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختيار ملف الاستيراد (`l10n.selectImportFileDropdownLabel`) | `SearchableDropdownField` | — | — | `importFilesProvider` ← `GET /api/v1/import-files` (`freight_quotations_comparison_screen.dart:33-38`) |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| العودة للداش بورد (في `AppBar`) | رجوع | — | — |
| كود الملف (chip) | نسخ الكود للحافظة | — | — |
| تصدير TSV / تصدير Excel / طباعة PDF / نسخ الملف (Dossier) | تصدير المقارنة (`:233-280`) | في الـ client (`FreightQuotationsExportService`) | — |
| ترسية العرض / تم الترسية (`awardQuoteBtn` / `quoteAwardedBtn`) | `_selectQuotation` | `POST /api/v1/freight-quotations/{rfqId}/award/{quotationId}` (`:106`) | مستخدم مسجل |
| (تلقائي) لما تختار ملف | `_fetchQuotations` | `GET /api/v1/freight-quotations?import_file_id=` (`:51`) | مستخدم مسجل |

### الجداول

مفيش جدول. فيه:
- **شريط مؤشرات:** أرخص عرض، وأسرع عرض، والمختار حالياً.
- **أعمدة مقارنة (بحد أقصى 4):** اسم الناقل، وشارة "أفضل سعر"، والنولون البحري، والمصاريف المحلية، وإجمالي التكلفة، وتاريخ الإبحار، وتاريخ الوصول، ومدة الترانزيت، والملاحظات، وزرار الترسية.

### التابات

مفيش.

### الـ Dialogs

مفيش dialogs.

### التصدير والطباعة

TSV وExcel(CSV) عبر `FileSaveHelper.saveText`، والـ PDF عبر `Printing.layoutPdf`، ونسخ Dossier للحافظة (`FreightQuotationsExportService`).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | كود ميت: 535 سطر مش بيتفتحوا من أي مكان، وبيكرروا منطق المقارنة والترسية والتصدير اللي في شاشة 14 (ممنوع حسب CORE_RULES: "تكرار Business Logic") | `features/freight_quotations/screens/freight_quotations_comparison_screen.dart` (مفيش instantiation؛ grep في `frontend/lib`) | امسحها، أو اربطها صراحةً وشيل التكرار |
| Medium | تعليق التنقل غلط: بيقول index 49 = `FreightQuotationsComparisonScreen`، والمركّب فعلاً `FreightQuotationsScreen` | `core/providers/navigation_provider.dart:81`؛ `inventory.json` (screen 14 notes) | صحّح التعليق |
| Low | (لو اتفعلت) بتقطع العروض لأول 4 من غير ما تنبّه المستخدم (`take(4)`) | `freight_quotations_comparison_screen.dart:66` | pagination أو تنبيه |
| Low | (لو اتفعلت) `_selectQuotation` بيعرض "تم الاختيار بنجاح" من غير ما يحفظ حاجة لما `rfq_id` يبقى null | `freight_quotations_comparison_screen.dart:97-101` | اعرض خطأ |
| Low | (لو اتفعلت) `AppBar` عادي بدل `PageHeader`، و`Colors.amber` / `Colors.red` / `Colors.white` بدل `AppTheme` | `freight_quotations_comparison_screen.dart:25`، و`:131-139`، و`:156` | المكونات الموحدة |
