# الشركات المستوردة المصرية (Import Companies)
![](../screenshots/01-import-companies-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الكود:** `MD-001` — Company (Egyptian Importers) (`doc.md` سطر 300، و`docs/01_master_data.md`).
- **الغرض:** سجل الشركات المصرية اللي بيتم الاستيراد باسمها: الاسم القانوني، والعنوان، ورقم البطاقة الاستيرادية، والتسجيل الضريبي، والسجل التجاري، وتاريخ انتهاء كل واحد منهم. الشاشة بتحسب الأيام الباقية على الانتهاء وقت العرض (مش بتتخزن في الـ DB، زي ما `doc.md` طالب).
- **المستخدمين:** مسؤول البيانات المرجعية / إدارة الاستيراد. البيانات دي بتتسحب بعد كده في المشاريع (`MD-007`) وملفات الاستيراد وطلبات ACID والمراسلات الرسمية.
- **المرحلة:** بيانات مرجعية بتتجهز قبل الدورة. مفيش ملف استيراد ولا مشروع يتعمل من غير شركة.

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar افتح "البيانات والجداول الأساسية"، وبعدين "الشركات المستوردة" (navigation index 32). الشاشة بتفتح كـ tab في الـ workspace، زي ما باين في الصورة ("الشركات المستوردة ✕").
- **الصلاحية:** أي مستخدم عامل تسجيل دخول. الـ router عليه `dependencies=[Depends(get_current_user)]` بس (`modules/import_companies/router.py:30`)، ومفيش أي permission code (RBAC) على الإضافة ولا التعديل ولا الإيقاف.
- **تحميل البيانات:** `initState` بينادي `fetchCompanies()` لما الشاشة تفتح (`import_companies_screen.dart:34-42`)، وده بيعمل `GET /api/v1/import-companies?include_inactive=<switch>`.

## مكونات الشاشة

> **عناصر الإطار المشترك (مش جزء من الشاشة نفسها):** الـ elements JSON فيه عناصر ثابتة في كل الشاشات، ومش بتتشرح هنا بالتفصيل: الـ sidebar (أقسام "البيانات والجداول الأساسية" ومراحل الدورة 1 لـ 6 و"استعلامات" و"لوحة القيادة"، وحقل "بحث سريع..."، وزرار "إخفاء القائمة لتوسيع الشاشة")، والشريط العلوي (Home، وساعات العالم، والأوامر Ctrl+K، ومساعد الاستيراد الذكي، والمستمع الذكي للبريد، وإعدادات البريد IMAP/SMTP، وتبديل اللغة EN، والوضع الداكن، والإعدادات، وكثافة عرض الجدول، ووضع التركيز، ودليل الاختصارات، وملء الشاشة، والإشعارات)، وشريط تبويبات الـ workspace (كل شاشة مفتوحة بتظهر تاب عليه ✕، و⋯ "خيارات النوافذ والتبويبات")، وكارت المستخدم "Review Admin / ADMIN" و"خيارات المستخدم"، والإصدار `v2.0.3 (Build 205)` والبورت. كمان أي dialog في header بتاعه زرار ✕ ("إغلاق النافذة") بيقفل من غير حفظ، والنصوص اللي بتبدأ بـ "مثال: ..." جوه الحقول هي hints بس ومش قيم.

### الحقول

**حقول الشاشة الرئيسية (شريط الأدوات):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث باسم المستورد، رقم القيد، أو رقم التسجيل الضريبي... | Text (بحث محلي) | لا | مفيش. الفلترة بتحصل في الـ client على `importerName` و`importerId` و`registrationNumber` بس (`:326-330`). **رقم التسجيل الضريبي `vatId` مش داخل في البحث رغم إن الـ hint بيقول إنه داخل.** | القائمة اللي اتحملت في الذاكرة |
| عرض الشركات المتوقفة | Switch | لا | — | `showInactiveCompaniesProvider`، والقيمة الافتراضية `true` (`import_companies_provider.dart:9`) |

**حقول Dialog الإضافة / التعديل (`_showCompanyDialog`):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اسم الشركة المستوردة | Text (`CustomTextField`) | نعم | لازم ميكونش فاضي بس (الـ validator الافتراضي في `custom_text_field.dart:31-37`) | إدخال يدوي → `importer_name` |
| العنوان | Text | نعم | لازم ميكونش فاضي | إدخال يدوي → `address` |
| الدولة | Text حر (قيمته الافتراضية `Egypt`) | نعم | لازم ميكونش فاضي. **مش dropdown** | إدخال يدوي → `country` (نص، مش FK) |
| رقم البطاقة الاستيرادية (9 أرقام) | Text | نعم | لازم ميكونش فاضي بس. **مفيش تحقق إنه 9 أرقام** | إدخال يدوي → `importer_id` (الباك إند بيتأكد إنه مش متكرر، بس الفحص بيتلغي للقيم اللي بتبدأ بـ `IMP-`، `validators.py:34-36`) |
| تاريخ انتهاء البطاقة الاستيرادية | Date picker (`InkWell` + `showDatePicker`) | نعم | من 2020 لـ 2040. **القيمة الافتراضية النهارده + 365 يوم** (`:650`) | `importer_id_expiry` |
| رقم التسجيل الضريبي (9 أرقام) | Text | نعم | لازم ميكونش فاضي بس | `vat_id` |
| تاريخ انتهاء التسجيل الضريبي | Date picker | نعم | القيمة الافتراضية النهارده + 365 (`:651`) | `vat_id_expiry` |
| رقم السجل التجاري (15 رقم) | Text | نعم | لازم ميكونش فاضي بس | `registration_number` |
| تاريخ انتهاء السجل التجاري | Date picker | نعم | القيمة الافتراضية النهارده + 365 (`:652`) | `registration_expiry` |
| رقم الهاتف | Text | لا | — | `phone` |

> كل حقل نصي فيه زرار نسخ (`نسخ البيانات إلى الحافظة`) جوه الحقل نفسه، وده موجود حتى في dialog الإضافة والحقل لسه فاضي. الـ elements JSON فيه 7 أزرار نسخ في dialog الإضافة.

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| إضافة شركة مستوردة | بيفتح dialog الإضافة | — | أي مستخدم مسجل |
| تكويد الشركة بالذكاء الاصطناعي ✨ | بيفتح `UniversalEntityExtractorDialog.showImporterExtractor` لاستخراج بيانات الشركة من نص أو مستند، وبعدين بيعمل refresh للقائمة | `POST /api/v1/smart-upload/parse-text/{module}` أو `POST /api/v1/smart-upload/upload/{module}`، وبعدين `POST /api/v1/import-companies` (`universal_entity_extractor_dialog.dart:321, 405, 662`) | أي مستخدم مسجل |
| إجراءات إضافية (⋮) | قائمة فيها: تصدير Excel، وتصدير PDF، ونسخ الجدول (TSV)، وتنزيل نموذج إكسل، واستيراد Excel | راجع قسم التصدير | أي مستخدم مسجل |
| إعادة تحميل حية (🔄) | `fetchCompanies()` | `GET /api/v1/import-companies` | أي مستخدم مسجل |
| تصدير الشركات (جدول) | بينسخ كل الشركات كـ TSV للحافظة | — (في الـ client) | — |
| العودة للداش بورد | بيرجع للوحة التحكم | — | — |
| **في كل صف:** نسخ ملخص الشركة | بينسخ ملخص نصي للشركة للحافظة (`_buildCompanySummary`) | — | — |
| عرض التفاصيل (👁) | `ImportCompanyDetailsDialog.show` | — (البيانات موجودة في الصف) | — |
| تعديل السجل (✏) | بيفتح نفس الـ dialog بوضع التعديل. لو فيه تغييرات بيظهر `showChangeDiffConfirmationDialog` الأول | `PUT /api/v1/import-companies/{id}` | أي مستخدم مسجل |
| طباعة وتصدير PDF (🖨) | بيولّد PDF للشركة في الـ client ويفتح نافذة الطباعة (`MasterDataExportService.printOrSaveImporterPdf` ← `Printing.layoutPdf`) | — | — |
| إيقاف / تفعيل الشركة (أيقونة 🗑 حمرا) | بيطلب تأكيد، وبعدين soft delete أو restore | `DELETE /api/v1/import-companies/{id}` / `PATCH /api/v1/import-companies/{id}/restore` | أي مستخدم مسجل |
| نسخ (جنب الاسم، وجنب كل رقم) | بينسخ القيمة للحافظة | — | — |
| كليك يمين على الصف | قائمة سياق فيها: نسخ الكود، وتعديل، وسجل التعديلات (`RowHistoryDialog`، `entityType: 'ImportCompany'`)، وتفعيل / إيقاف | `/api/v1/audit-logs/...` | أي مستخدم مسجل |
| **Dialog:** حفظ بيانات الشركة / تحديث | بيعمل validate للفورم، وبعدين create أو update. لو فيه خطأ بيظهر SnackBar أحمر. فيه loading spinner جوه الزرار (`isSubmitting`) | `POST /api/v1/import-companies` / `PUT .../{id}` | أي مستخدم مسجل |
| **Dialog:** إلغاء وإغلاق ✕ | بيقفل الـ dialog | — | — |

### الجداول

مفيش `DataTable`. العرض عبارة عن **قائمة كروت** (`ListView.separated`)، وكل صف فيه:
- **يسار الصف:** أيقونة نسخ الملخص، وبعدها pill فيه 4 أيقونات (عرض / تعديل / طباعة / إيقاف)، وبعدها أيقونة الشركة.
- **الاسم** (عربي / إنجليزي زي ما اتسجل) + شارة الحالة (نشطة / متوقفة). الشركة المتوقفة بتظهر شفافة 60% وعليها خط.
- **شارات الأرقام:** بطاقة استيرادية، وتسجيل ضريبي، وسجل تجاري، وجنب كل واحد زرار نسخ.
- **شارات الصلاحية (3):** البطاقة الاستيرادية، والتسجيل الضريبي، والسجل التجاري، ولونها حسب الأيام الباقية: أحمر لو منتهية، وبرتقالي لو فاضل ≤ 30 يوم، وأخضر لو أكتر من كده (`_buildExpiryBadge`، `:563-591`). في الصورة كل الشركات "سارٍ (1558 يوم)".
- **الفلترة:** البحث النصي + switch المتوقفة. **الترتيب:** زي ما البيانات جاية من الـ API، ومفيش ترتيب بالأعمدة.

### التابات

الشاشة مفيهاش تابات.

### الـ Dialogs

**1) إضافة شركة استيراد مصرية جديدة**
![](../screenshots/01-import-companies-dialog-add.png)

فيه الحقول اللي في الجدول فوق. الـ header لونه charcoal، وتحت فيه زرارين: "إلغاء وإغلاق" و"حفظ بيانات الشركة". الدولة جاية مكتوب فيها `Egypt`، وتواريخ الانتهاء التلاتة جاية بـ `2027-09-24` (يعني سنة من تاريخ التصوير).

**2) أخطاء الـ validation (حفظ الفورم وهو فاضي)**
![](../screenshots/01-import-companies-dialog-add-validation.png)

5 حقول ظهر فيها خطأ: الاسم، والعنوان، والبطاقة الاستيرادية، والتسجيل الضريبي، والسجل التجاري. الرسالة بتطلع بالشكل ده: `اسم الشركة المستوردة * is required`، يعني نص الـ label وجواه النجمة وبعده جملة إنجليزي. التواريخ مظهرش فيها خطأ لأنها أصلاً ليها قيمة افتراضية.

**3) Dialogs متصورتش:** `ImportCompanyDetailsDialog` (عرض التفاصيل)، و`RowHistoryDialog` (سجل التعديلات)، و`UniversalEntityExtractorDialog` (التكويد بالذكاء الاصطناعي)، ودايالوج مقارنة التغييرات قبل التعديل (`change_diff_dialog.dart`)، ودايالوج تأكيد الإيقاف (`AlertDialog`). كلهم موثقين من الكود بس.

### التصدير والطباعة

| الإجراء | الطريقة | الملف الافتراضي |
|---|---|---|
| تصدير Excel | `GET /api/v1/import-companies/export-excel` ← `FileSaveHelper.saveBytes` (بيفتح Save dialog) | `Import_Companies_Report.xlsx` |
| تصدير PDF | `GET /api/v1/import-companies/export-pdf` ← `FileSaveHelper.saveBytes` | `Import_Companies_Report.pdf` |
| تنزيل نموذج إكسل | `GET /api/v1/import-companies/excel-template` | `Import_Companies_Template.xlsx` |
| استيراد Excel | `FilePicker.pickFiles` ← `POST /api/v1/import-companies/import-excel`، وبعدها dialog بالنتيجة والأخطاء | — |
| نسخ TSV | في الـ client (`_copyCompaniesTsv`) | — |
| طباعة شركة واحدة | PDF بيتولد في الـ client بخط Cairo من `PdfGoogleFonts` ← `Printing.layoutPdf` | — |

> **على الويب:** `FileSaveHelper` بيستخدم `window.showSaveFilePicker` على Chromium. تسمية الملفات ثابتة (`Import_Companies_Report`)، ومش ماشية على الصيغة القياسية `[Stage Name] - [Code]`. الصيغة دي أصلاً معمولة لملفات الشحنات، فالنقطة دي مش مخالفة واضحة لشاشة بيانات مرجعية.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | رقم البطاقة الاستيرادية والتسجيل الضريبي والسجل التجاري مكتوب في الـ label إنهم "9 أرقام / 15 رقم"، لكن مفيش تحقق من الطول ولا إنهم أرقام، لا في الفرونت ولا في الباك. البيانات التجريبية دخلت `IMP-REG-104521` و`CR-88214` عادي. ودي بيانات قانونية بتروح لـ ACID. | `01-import-companies-main.png`؛ `import_companies_screen.dart:778-783, 828-833, 878-883` (مفيش `validator`)؛ `modules/import_companies/validators.py:34-36` (بيتحقق من التكرار بس) | validator بـ regex (`^\d{9}$` و`^\d{15}$`) في الفرونت، ونفس القاعدة في Pydantic schema في الباك. |
| Medium | رسالة الخطأ بتدمج الـ label العربي وجواه `*` مع جملة إنجليزي `is required`، والـ label نفسه بيظهر بنجمتين (`* *`) لأن نص الـ l10n فيه `*` والـ widget بيزود ` *` كمان. | `01-import-companies-dialog-add-validation.png`؛ `core/widgets/custom_text_field.dart:34` و`:57-61` | الرسالة تيجي من `context.l10n.fieldRequired(label)`، والنجمة تتشال من نصوص الـ l10n أو من الـ widget. (ده widget مشترك، فالمشكلة بتأثر على شاشات تانية.) |
| Medium | حقل "الدولة" نص حر قيمته الافتراضية `Egypt`، مش `SearchableDropdownField` مربوط بجدول دول. وده مخالف لقاعدة "ممنوع تخزين Master Data كنص حر". | `01-import-companies-dialog-add.png`؛ `import_companies_screen.dart:643, 733-745` | اختيار الدولة من `SearchableDropdownField<int>` مربوط بـ `country_id`. |
| Medium | تواريخ الانتهاء الإلزامية التلاتة بتتملى لوحدها بـ "النهارده + سنة"، فالمستخدم ممكن يحفظ تواريخ قانونية وهمية من غير ما ياخد باله، ومفيش validation يمسكها. | `01-import-companies-dialog-add-validation.png` (التواريخ `2027-09-24` ومفيش عليها خطأ)؛ `import_companies_screen.dart:650-652` | تبدأ فاضية وتبقى required، أو على الأقل يظهر تحذير لو المستخدم محطش تاريخ بنفسه. |
| Medium | فحص تكرار رقم البطاقة الاستيرادية **بيتلغي** لأي قيمة بتبدأ بـ `IMP-` أو `IMP-REG-` (الشرط `not imp_id.startswith("IMP-REG-") and not imp_id.startswith("IMP-")`). كل البيانات الحالية بالصيغة دي (`IMP-REG-104521`...)، فممكن تتسجل شركتين بنفس رقم البطاقة من غير أي رفض. | `01-import-companies-main.png` (القيم `IMP-REG-...`)؛ `modules/import_companies/validators.py:34-36` | فحص التكرار يتطبق على كل القيم، ومعاه `UNIQUE` على `importer_id` في الـ DB (migration). |
| Medium | مفيش RBAC على أي عملية. أي مستخدم مسجل (حتى لو read-only) يقدر يضيف أو يعدل أو يوقف شركة. | `modules/import_companies/router.py:27-31` | يتضاف `require_permission("master_data.edit")` على POST و PUT و DELETE و PATCH، زي ما معمول في `currencies/router.py:116`. |
| Medium | دايالوج مقارنة التغييرات قبل التعديل مش بيراجع الدولة ولا تاريخ انتهاء التسجيل الضريبي ولا تاريخ انتهاء السجل التجاري. يعني تعديل الحقول دي بيتحفظ من غير ما يظهر للمستخدم في شاشة التأكيد. | `import_companies_screen.dart:1004-1025` | إضافة `country` و`vatIdExpiry` و`registrationExpiry` لقائمة `changes`. |
| Medium | الشركة ملهاش Business Code (زي `IMP-000001`)، ونسخ TSV وملخص الشركة بيعرضوا `companyId` (الـ ID الداخلي بتاع الـ DB) في عمود "الكود". | `import_companies_screen.dart:69, 102`؛ `modules/import_companies/model.py:21` (مفيش عمود code) | يتضاف `company_code` بـ Alembic migration ويتعرض بداله. |
| Low | البحث مش بيدور في رقم التسجيل الضريبي، مع إن الـ hint بيقول "أو رقم التسجيل الضريبي". | `01-import-companies-main.png` (نص الـ hint)؛ `import_companies_screen.dart:326-330` | إضافة `c.vatId` لشرط الفلترة. |
| Low | زرار "إيقاف تفعيل الشركة" أيقونته سلة حمرا (🗑)، مع إن العملية soft deactivate ومش حذف. ده ممكن يلخبط المستخدم. | `01-import-companies-main.png`؛ `import_companies_screen.dart:423-445` | أيقونة `block` / `toggle_off` للإيقاف و`restore` للتفعيل. |
| Low | مخالفة معايير الـ UI: الأزرار `ElevatedButton` و`OutlinedButton` بدل `AppButton`، وفيه ألوان مكتوبة مباشرة (`Colors.white`، `Colors.grey`، `Color(0xFFF1F5F9)`، `Colors.red.shade300`). | `import_companies_screen.dart:143-175, 603, 956-960` | استخدام `AppButton` بالـ variants وألوان `AppTheme`. |
| Low | زرار الإلغاء عليه علامتين ✕: واحدة أيقونة `Icons.close`، والتانية جوه نص الـ l10n "إلغاء وإغلاق ✕". | `01-import-companies-dialog-add.png`؛ `import_companies_screen.dart:962-963` | شيل ✕ من نص الترجمة. |
| Low | أزرار نسخ جوه حقول فورم الإضافة وهي لسه فاضية (7 أزرار). ده زحمة ملهاش فايدة. | `01-import-companies-dialog-add.png`؛ `elements/01-import-companies-dialog-add.json` (7 × "نسخ البيانات إلى الحافظة") | زرار النسخ يظهر في وضع التعديل أو العرض بس. |
| Low | نصوص عربي مكتوبة في الكود مباشرة (عناوين Save dialog، وعناصر قائمة "نسخ الجدول (TSV)" و"تنزيل نموذج إكسل")، مش جاية من l10n. | `import_companies_screen.dart:190, 200, 215`؛ `core/helpers/master_data_action_helper.dart` (عنصرين `copy_tsv` و`download_template` بـ `isArabic ? ... : ...`) | تتنقل لملفات الـ l10n. |
| Low | switch "عرض الشركات المتوقفة" شغال من الأول، فالشركات المتوقفة بتظهر في القائمة الافتراضية. | `01-import-companies-main.png`؛ `providers/import_companies_provider.dart:9` | القيمة الافتراضية تبقى `false`. |
| Low | طباعة الشركة بتحمّل خط Cairo من الإنترنت (`PdfGoogleFonts`)، فالطباعة هتفشل لو مفيش نت. | `core/services/master_data_export_service.dart:28-29` | الخط يتحط كـ asset جوه التطبيق. |
| Low | Bug الـ locale المعروف: `showDatePicker` في dialog التواريخ هيطلع بالإنجليزي حتى في الوضع العربي، لأن `MaterialApp` مفيهوش `supportedLocales`. (الـ picker متصورش.) | `import_companies_screen.dart:757-762`؛ `main.dart` (ملاحظة الجرد) | تحديد `supportedLocales` و`localizationsDelegates` في `MaterialApp`. |
| Low (Web-only) | الـ console طلّع 4 مرات `Refused to set unsafe header "Accept-Encoding"`. الـ dio client بيبعت الـ header ده، والمتصفح بيرفضه على الويب. ملوش تأثير وظيفي. | `runtime-errors.json` → `01-import-companies`؛ `core/network/api_client.dart:27` | الـ header ميتحطش لما يكون `kIsWeb`. |
