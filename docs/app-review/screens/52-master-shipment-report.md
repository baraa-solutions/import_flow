# تقرير ملف الاستيراد الشامل والمدمج (Master Shipment Report)
![](../screenshots/52-master-shipment-report-main.png)

> التصوير اتعمل على **Flutter Web (release)**. الـ harness فتح الشاشة من غير ما يختار ملف استيراد، عشان كده الصورة بتوضح حالة "اختر ملف استيراد" بس. محتوى التقرير نفسه موصوف من الكود.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** تقرير Dossier مجمّع لملف استيراد واحد. بعد ما تختار الملف، بيعرض:
  - بانر رأس فيه بيانات الملف (`_buildHeaderBanner`)، و Pipeline المراحل مع عدد التحديثات في كل مرحلة (`_buildPhasePipeline`).
  - كروت: البيانات الأساسية، والمستندات، والفواتير، وقائمة التعبئة (الوزن و CBM)، والحالة، والملخص المالي، والملاحظات.
  - الخط الزمني للتحديثات التشغيلية مع تعديلات التكلفة (`_buildUpdateTimeline`).
  - قسم التخليص الجمركي (رقم 46، والقناة، والمكتب، وإذن الإفراج) وقسم الاستلام المخزني (GRN وجدول الكميات).
- **المستخدمين:** الإدارة، والمراجعة، ومسؤول الملف لما يحتاج صورة كاملة للشحنة أو يطبعها.
- **المرحلة:** تقرير عابر للمراحل. الأكواد من `inventory.json`: **BP-028، BP-029، BP-032، BP-033، BP-035، BP-036، BP-039، BP-040**.

## طريقة الوصول والصلاحية
- **Sidebar:** "لوحة القيادة والتقارير والرقابة" ← "تقرير الشحنة الشامل المدمج" (index 47).
- **Scaffold:** `Scaffold` + **`AppBar` عادي** بلون `AppTheme.charcoal` (`import_file_comprehensive_report_screen.dart:120-131`)، مش `PageHeader`.
- **الصلاحية:** أي مستخدم مسجّل (routers الـ import-files و shipment-updates و customs-clearance و warehouse-receiving كلها `Depends(get_current_user)`).
- **تحميل البيانات:** `initState` بيعمل fetch لملفات الاستيراد (`:58-63`). ولما تختار ملف بيجيب تحديثاته وسجلات التخليص والاستلام (`:74-76`).

## مكونات الشاشة

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختر ملف الاستيراد لعرض التقرير الشامل | `SearchableDropdownField<int>` | لا (من غيره التقرير مش بيظهر) | — | `importFilesProvider` ← `GET /api/v1/import-files`. الـ label: الاسم والكود، والمورد، والمرحلة، والحالة (`:221-231`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| العودة للداش بورد | index 0 | — | الكل |
| إضافة تحديث (بعد اختيار ملف) | `ShipmentUpdateDialog` للملف (`:192-194`) | `POST /api/v1/shipment-updates` | الكل |
| نسخ الملف الشامل (أيقونة + زرار) | `buildDossierText` ← الحافظة (`:140-147`) | — | الكل |
| تصدير TSV | `ComprehensiveReportExportService.exportToTsv` (`:153`) | — | الكل |
| تصدير Excel | `exportToExcel` (`:164`) | — | الكل |
| طباعة / حفظ PDF | `printOrSavePdf` (`:175`) | — | الكل |
| تصدير الملف الشامل (CLO-03) | `ComprehensiveDossierExportDialog.show` (`:331-332`) | — | الكل |

- **الحالة الفاضية (اللي في الصورة):** أيقونة ملف رمادية ورسالة "اختر ملف استيراد من القائمة أعلاه لعرض التقرير الشامل والمدمج"، وقبل قائمة الاختيار أيقونة فولدر.

الأزرار دي كلها (ما عدا "العودة") بتظهر بس لما يكون فيه ملف مختار (`if (_selectedFile != null)` في `:135`).

### الجداول
- **جدول الاستلام المخزني** (`:1511-1516`): الكود، والصنف، والكمية المفوترة، والمقبولة، والعجز، والتالف.
- الخط الزمني للتحديثات بيعرض لكل تحديث: التاريخ، والنوع، والمرحلة المستهدفة، والملاحظة، وتعديل التكلفة (`البند: القديم ← الجديد`).
- مفيش فلاتر ولا ترتيب. الترتيب حسب الباك إند.

### التابات
مفيش تابات.

### الـ Dialogs
`ShipmentUpdateDialog` و `ComprehensiveDossierExportDialog` (من `inventory.json`). **ما اتصورتش**: الـ harness ما اختارش ملف، ومفيش زرار إضافة ظاهر في الحالة الفاضية.

### التصدير والطباعة
TSV و Excel و PDF ونسخ Dossier و Dossier CLO-03. الحفظ عن طريق `FileSaveHelper` (`comprehensive_report_export_service.dart`)، والـ PDF عن طريق `Printing.layoutPdf`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | تعديل التكلفة في الخط الزمني بيتعرض دايماً بلاحقة `compReportCurrencyUsd` (USD) ثابتة. سجل التحديث في الباك إند مالوش حقل عملة أصلاً (`modules/shipment_updates/` مفيهاش `currency`)، فملف بعملة EUR (زي FILE-2026-0004 في لوحة المراحل) هيتعرض تعديله على إنه USD | `import_file_comprehensive_report_screen.dart:1211` | ضيف عملة للتعديل في الباك إند، أو اعرض عملة الملف `estimated_cost_currency` بدل USD الثابتة |
| Low | الهيدر `AppBar` عادي مش `PageHeader`، ومفيش زرار تحديث حي في الهيدر (ده إلزامي في كل الشاشات حسب الـ standard) | `52-master-shipment-report-main.png`؛ `import_file_comprehensive_report_screen.dart:120-131` | استخدم `PageHeader` وضيف 🔄 |
| Low | نص عربي hard-coded: `'تصدير الملف الشامل (CLO-03)'` من غير l10n | `import_file_comprehensive_report_screen.dart:331` | انقله لـ `app_ar.arb`/`app_en.arb` |
| Low | أسماء المراحل في قائمة اختيار الملف بتتحسب بـ `Localizations.localeOf(context)`، ودي بترجع `en_US` بسبب مشكلة الـ locale المعروفة، فالمرحلة هتظهر بالإنجليزي | `import_file_comprehensive_report_screen.dart:225` | صلّح `supportedLocales`، أو خد اللغة من `localeProvider` |
| Low | ألوان ثابتة: الخلفية `Color(0xFFF4F6F9)`، وسبب الإغلاق `Colors.black54` (مش هيبان في الوضع الداكن) | `import_file_comprehensive_report_screen.dart:120` و `:775` | استخدم `AppTheme` و `Theme.of(context)` |
