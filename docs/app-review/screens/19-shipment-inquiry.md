# استعلام وسجل الشحنات والتكاليف التاريخية (Shipment History & Inquiry)
![](../screenshots/19-shipment-inquiry-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الكود:** `KB-INQ-013` (حسب `inventory.json`). شاشة استعلام وخبرة تاريخية بتخدم التخطيط المسبق (BP-006 إلى BP-008) لما تقارن بالشحنات القديمة.
- **الغرض:** البحث في الشحنات السابقة بالمورد، والمستورد، وبند التعريفة أو الصنف، والـ Incoterm، والموانئ، ووسيلة الشحن، والناقل. وعرض مسار الشحن والتكلفة، والاستنساخ الذكي لشحنة قديمة كنقطة بداية لشحنة جديدة، مع تقرير وتصدير.
- **المستخدمين:** مسؤول الاستيراد / التخطيط / الإدارة.
- **نوع الشاشة:** Type B / C (استعلام بجدول).

## طريقة الوصول والصلاحية

- **الوصول:** عنصر الـ sidebar "استعلامات" ← "استعلام وسجل الشحنات والتكاليف التاريخية" **مش شغال**: `selectNavigationIndex` بيرجع من غير ما يعمل حاجة لأن `_totalScreens = 68`، والشاشة على index 68 (`core/providers/navigation_provider.dart:102`، و`:188`). الطريقة الوحيدة اللي بتشتغل هي لوحة الأوامر Ctrl+K ("الاستعلام الذكي عن الشحنات وسجل الأسعار"، `command_palette_registry.dart:430`)، ودي اللي الـ harness استخدمها (`capture-manifest.json`: `navigation: command_palette`).
- **الصلاحية:** بتستخدم `import-files` (`import_files.view`)، و`suppliers`، و`import-companies`. الاستنساخ بيحتاج `import_files.create` (`POST /import-files/{id}/clone`).
- **تحميل البيانات:** `initState` بيجيب ملفات الاستيراد والموردين والشركات (`shipment_inquiry_screen.dart:31-33`). الفلترة والإحصائيات بتتعمل في الـ client (`providers/shipment_inquiry_provider.dart`).

## مكونات الشاشة

### الحقول

**لوحة الفلاتر (`widgets/shipment_inquiry_filter_panel.dart`):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| المورد (جميع الموردين الأجانب) | `SearchableDropdownField<int?>` | لا | — | `/api/v1/suppliers` (`:120`) |
| المستورد (جميع الشركات المستوردة) | `SearchableDropdownField<int?>` | لا | — | `/api/v1/import-companies` (`:168`) |
| بند التعريفة الجمركية أو كود أو وصف الصنف | TextField | لا | — | بحث نصي (`:207`) |
| (فلاتر إضافية) Incoterm | `SearchableDropdownField<String?>` | لا | — | (`:306`) |
| ميناء التحميل / ميناء الوصول | **TextField حر** | لا | — | (`:345`، و`:371`) |
| وسيلة الشحن | `SearchableDropdownField<String?>` | لا | — | (`:393`) |
| الناقل | **TextField حر** | لا | — | (`:428`) |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| العودة للداش بورد | رجوع | — | — |
| تحديث البيانات حيا من السيرفر (🔄) | `fetchImportFiles()` (`:173`) | `GET /api/v1/import-files` | `import_files.view` |
| بحث | تطبيق الفلاتر | — (في الـ client) | — |
| طباعة أو تصدير التقرير | منيو الطباعة / التصدير (`onExportPrint`، `:197`) | في الـ client | — |
| فلاتر إضافية ولوجستية (⚙) | يفتح الفلاتر الإضافية | — | — |
| طباعة تقرير رسمي / تصدير إكسيل / تصدير جدول بتاب / نسخ ملخص الحافظة النصي بالكامل | `_handlePrintPdf` / `_handleExportExcel` / `_handleExportTsv` / `_handleCopyDossier` (`:81-110`) | في الـ client | — |
| **في كل صف:** نسخ ملخص الصف | نسخ TSV | — | — |
| استنساخ ذكي | `SmartCloneShipmentDialog` | `POST /api/v1/import-files/{id}/clone` | `import_files.create` |
| عرض التفاصيل (👁) | `_openDetails` ← `ImportFileDetailsDialog` | `GET /import-files/{id}` | view |
| نسخ كود الشحنة / روابط المورد والشركة | نسخ / تنقل | — | — |

### الجداول

- **مؤشرات:** إجمالي الشحنات المطابقة (6)، ومتوسط سعر النولون (55567 دولار أمريكي)، وإجمالي التكاليف المسجلة (333400 دولار أمريكي).
- **"١. جدول استعلام وسجل الشحنات والتكاليف التاريخية"** ("عرض 6 شحنة مطابقة"): Checkbox، والإجراءات، واسم الشحنة + الكود، والمورد الأجنبي، والشركة المستوردة، والصنف وبند التعريفة، ومسار الشحن (POL → POD)، ووسيلة الشحن، والـ Incoterm، وتكلفة النولون. أعمدة الترتيب بتستخدم `_buildSortableHeader` (`:370`).
- على 1600px آخر عمود ظاهر هو "مسار الشحن" (مقصوص). وسيلة الشحن والـ Incoterm والتكلفة محتاجين scroll أفقي.

### التابات

مفيش.

### الـ Dialogs

- مفيش زرار إضافة (`capture-manifest.json`: "no add/create button found")، فمفيش صورة dialog ولا validation.
- من الكود: `ImportFileDetailsDialog`، و`SmartCloneShipmentDialog`.

### التصدير والطباعة

`ShipmentInquiryExportService`: CSV / TSV عبر `FileSaveHelper.saveBytes` (`services/shipment_inquiry_export_service.dart:137`، و`:198`)، وPDF عبر `Printing.layoutPdf` (`:407`)، ونسخ Dossier للحافظة.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | عنصر الـ sidebar بتاع الشاشة مش بيفتح حاجة، لأن `_totalScreens = 68` والشاشة على index 68، فالتحقق `index >= _totalScreens` بيرجع على طول. متوصلش غير بـ Ctrl+K | `core/providers/navigation_provider.dart:102`، و`:188`؛ `inventory.json` (screen 19 notes) | ارفع `_totalScreens` لـ 70 أو احسبه من طول القائمة |
| High | "متوسط سعر النولون" و"إجمالي التكاليف" وعمود "تكلفة النولون" بيتحسبوا من `estimatedCost` بتاع ملف الاستيراد (إجمالي تكلفة الشحنة / قيمة البضاعة)، مش من النولون. عشان كده الإجمالي (333400) هو نفس إجمالي قيمة أوامر الشراء في شاشة 11 | `providers/shipment_inquiry_provider.dart:274-277`؛ `services/shipment_inquiry_export_service.dart:66`؛ `19-shipment-inquiry-main.png` مقابل `11-purchase-orders-main.png` ($333400) | اسحب النولون من العرض المرسّى / الحجز الملاحي |
| Medium | المؤشرات بتكتب "دولار أمريكي" على طول (`inqCurrencyUsd`) مع إن كل صف ليه عملته (`estimatedCostCurrency`)، فالجمع بيخلط العملات | `shipment_inquiry_screen.dart:231`، و`:238`؛ `services/shipment_inquiry_export_service.dart:67` | حوّل للعملة الأساسية أو اجمع لكل عملة |
| Medium | فلاتر الموانئ والناقل TextField حر، مع إن دي بيانات مرجعية لازم تبقى `SearchableDropdownField` (CORE_RULES §5) | `widgets/shipment_inquiry_filter_panel.dart:345`، و`:371`، و`:428` | dropdown على `/transport-locations` و`/external-service-providers` |
| Medium | Placeholders فلاتر المورد والمستورد في الشريط الغامق شبه مش باينة (contrast ضعيف: `Colors.white.withOpacity(0.08)` كخلفية)، وزرار "العودة للداش بورد" باهت | `19-shipment-inquiry-main.png`؛ `widgets/shipment_inquiry_filter_panel.dart:127-136` | ألوان `AppTheme` بتباين مقبول |
| Medium | "العودة للداش بورد" أول عنصر في الهيدر (قبل الأيقونة والعنوان)، والقاعدة إنه يبقى الأخير | `shipment_inquiry_screen.dart:136-140`؛ `19-shipment-inquiry-main.png` | انقله لآخر الـ actions |
| Low | التصدير متكرر في مكانين: "طباعة أو تصدير التقرير" في شريط البحث، والأزرار الـ 4 في شريط المؤشرات | `19-shipment-inquiry-main.png`؛ `shipment_inquiry_screen.dart:197`، و`:249-263` | مكان واحد |
| Low | الجدول أعرض من الشاشة وعمود "مسار الشحن" مقصوص | `19-shipment-inquiry-main.png` | قلّل الأعمدة أو ثبّت الإجراءات |
| Low | Console: `Accept-Encoding` (3 مرات). **فرق Web بس** | `runtime-errors.json` | — |
