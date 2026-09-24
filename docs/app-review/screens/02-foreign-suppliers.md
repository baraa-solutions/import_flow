# دليل الموردين والمصدرين الأجانب (Foreign Suppliers)
![](../screenshots/02-foreign-suppliers-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الكود:** `MD-002` Supplier (Foreign Exporters) (`doc.md` سطر 373، و`docs/01_master_data.md`).
- **الغرض:** سجل موحد للموردين الأجانب. بيحفظ اسم الشركة، ونوع المورد، ونوع التسجيل، ومعرّف المصدر الأجنبي على نافذة، ومعرّف CargoX، والدولة وكودها، والعنوان، وبيانات التواصل، وبيانات البنك المستفيد (SWIFT و IBAN)، وعلامات الامتثال (ISO، والقرار 43، والقائمة البيضاء)، والعلامات التجارية. كل مورد بيتولد له كود عمل `SUP-XXXXXX`.
- **ليه مهم:** `doc.md` بيعتبر البيانات دي **Legal Master Data**. أي اختلاف في Registration Type أو Exporter ID أو Country Code ممكن يوقف طلب ACID.
- **المستخدمين:** إدارة المشتريات والاستيراد. البيانات بتتسحب بعد كده في المشاريع، وملفات الاستيراد، و ACID، ومستندات CargoX.
- **المرحلة:** بيانات مرجعية قبل الدورة، وبتخدم BP الخاصة بـ ACID والتوثيق (المرحلة 2 وما بعدها).

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar افتح "البيانات والجداول الأساسية" واختار "دليل الموردين الأجانب" (index 33).
- **الصلاحية:** أي مستخدم عامل تسجيل دخول. الحماية الوحيدة `dependencies=[Depends(get_current_user)]` على الـ router (`modules/suppliers/router.py:22-26`)، ومفيش RBAC.
- **التحميل:** `initState` بيستدعي `fetchSuppliers()`، وده بينادي `GET /api/v1/suppliers` (`suppliers_screen.dart:38-41`، `suppliers_provider.dart:37-38`).

## مكونات الشاشة

> **عناصر الإطار المشترك (مش جزء من الشاشة نفسها):** الـ elements JSON فيه عناصر ثابتة في كل الشاشات، ومش بتتشرح هنا بالتفصيل: الـ sidebar (أقسام "البيانات والجداول الأساسية" ومراحل الدورة 1 لـ 6 و"استعلامات" و"لوحة القيادة"، وحقل "بحث سريع..."، وزرار "إخفاء القائمة لتوسيع الشاشة")، والشريط العلوي (Home، وساعات العالم، والأوامر Ctrl+K، ومساعد الاستيراد الذكي، والمستمع الذكي للبريد، وإعدادات البريد IMAP/SMTP، وتبديل اللغة EN، والوضع الداكن، والإعدادات، وكثافة عرض الجدول، ووضع التركيز، ودليل الاختصارات، وملء الشاشة، والإشعارات)، وشريط تبويبات الـ workspace (كل شاشة مفتوحة بتظهر تاب عليه ✕، و⋯ "خيارات النوافذ والتبويبات")، وكارت المستخدم "Review Admin / ADMIN" و"خيارات المستخدم"، والإصدار `v2.0.3 (Build 205)` والبورت. كمان أي dialog في header بتاعه زرار ✕ ("إغلاق النافذة") بيقفل من غير حفظ، والنصوص اللي بتبدأ بـ "مثال: ..." جوه الحقول هي hints بس ومش قيم.

### الحقول

**شريط الأدوات:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث باسم المورد، الكود، معرف كارجو إكس، رقم القيد، أو الدولة... | Text (فلترة محلية) | لا | الفلترة شغالة على الاسم، والكود، و`foreignExporterId`، والدولة، والعلامات التجارية (`:360-366`). **معرّف CargoX مش داخل في البحث، مع إن الـ hint مكتوب فيه** | القائمة المحملة |
| عرض الموردين المتوقفين | Switch | لا | — | provider (القيمة الافتراضية ظاهرة On في الصورة) |

**Dialog إضافة / تعديل مورد (`_showSupplierDialog`):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اسم شركة المورد | Text | نعم | مش فاضي | `company_name` |
| نوع المورد | `SearchableDropdownField<String>` (قائمة ثابتة: Manufacturer / Foreign Supplier / Trader / Authorized Agent / Distributor / Exporter) | نعم | من القائمة | `supplier_type` |
| نوع التسجيل والتوثيق | `SearchableDropdownField<String>` (6 قيم ثابتة) | نعم | من القائمة | `registration_type` |
| معرف المصدر الأجنبي (نافذة) | Text | نعم | مش فاضي، ومفيش تحقق من الصيغة | `foreign_exporter_id` |
| معرف منصة كارجو إكس | Text | لا | — | `cargox_platform_id` |
| دولة المورد | Text حر | نعم | مش فاضي | `foreign_exporter_country` (نص) |
| كود الدولة المعتمد | Text حر (الـ hint بيقول "كود الدولة حرفين") | نعم | مش فاضي بس. **مفيش تحقق إنه حرفين** | `foreign_exporter_country_code` |
| العنوان بالكامل | Text | نعم | مش فاضي | `address` |
| البريد الإلكتروني الرئيسي / بريد إلكتروني إضافي | Text | لا | **مفيش تحقق من صيغة الإيميل** (لا في الفرونت ولا في `schemas.py:37-39`) | `email` / `secondary_email` |
| رقم الهاتف الأرضي / المحمول / الفاكس | Text | لا | — | `phone` / `mobile` / `fax` |
| الموقع الإلكتروني | Text | لا | — | `website` |
| اسم البنك المستفيد / كود السويفت / رقم الحساب / IBAN | Text (جوه بلوك "بيانات البنك المستفيد والسويفت") | لا | **مفيش تحقق** من صيغة SWIFT ولا IBAN | `bank_name`, `swift_code`, `account_number`, `iban` |
| حاصل على ISO / مسجل بالقرار 43 / مسجل بالقائمة البيضاء | Checkbox | لا | — | `has_iso`, `registered_decree_43`, `white_list_registered` |
| العلامات التجارية وخطوط الإنتاج | Text | لا | — | `brands` |
| ملاحظات | Text | لا | — | `notes` |

> زرار النسخ جوه الحقول هنا بيظهر بس لما الحقل يكون فيه قيمة (`buildCopySuffix`، `:704-717`). ده أحسن من شاشة الشركات المستوردة.

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| إضافة مورد أجنبي جديد | بيفتح dialog الإضافة | — | أي مستخدم مسجل |
| ⚡ الاستخراج والترميز الذكي | `UniversalEntityExtractorDialog.showSupplierExtractor`: بيستخرج بيانات المورد من نص أو ملف، وبعدها بيحفظ | `POST /api/v1/smart-upload/parse-text/{module}` أو `.../upload/{module}`، وبعدين `POST /api/v1/suppliers` | أي مستخدم مسجل |
| إجراءات إضافية ⋮ | قائمة فيها: Excel، و PDF، و TSV، والنموذج، والاستيراد | راجع قسم التصدير | أي مستخدم مسجل |
| إعادة تحميل حية 🔄 | `fetchSuppliers()` | `GET /api/v1/suppliers` | — |
| تصدير الموردين (جدول) | بينسخ كل الموردين TSV للحافظة | — | — |
| العودة للداش بورد | بيرجع للوحة التحكم | — | — |
| **صف:** عرض التفاصيل 👁 | `SupplierDetailsDialog.show` | — | — |
| **صف:** تعديل السجل ✏ | بيفتح dialog التعديل، وبعده dialog مقارنة التغييرات | `PUT /api/v1/suppliers/{id}` | أي مستخدم مسجل |
| **صف:** طباعة وتصدير PDF 🖨 | بيولّد PDF في الـ client (`printOrSaveSupplierPdf`) | — | — |
| **صف:** إيقاف / تفعيل المورد 🗑 | تأكيد، وبعده soft delete أو restore | `DELETE /api/v1/suppliers/{id}` / `PATCH .../{id}/restore` | أي مستخدم مسجل |
| **صف:** نسخ ملخص بيانات المورد | بينسخ ملخص نصي | — | — |
| **صف:** بطاقة ذكاء المسار والمورد والتاريخ التفاوضي ✨ | `RouteIntelligenceDialog` | `GET /api/v1/route-intelligence/supplier/{id}` | — |
| **صف:** بطاقة تقييم أداء المورد 🏅 | `SupplierScorecardDialog` | **`GET /api/v1/suppliers//scorecard`** (الـ ID مش موجود في الـ URL، شوف الملاحظات) | — |
| **صف:** فحص الرقابة على الصادرات والواردات والقرار 43 🛡 | `GOEICVerificationDialog` | `POST /api/v1/integrations/goeic/verify-compliance` | — |
| **صف:** كود المورد / نسخ | بينسخ `SUP-00000X` أو القيمة | — | — |
| كليك يمين | نفس قائمة السياق المشتركة، ومعاها سجل التعديلات (`RowHistoryDialog`) | `/api/v1/audit-logs/...` | — |
| **Dialog:** حفظ بيانات المورد الأجنبي | validate، وبعدين create أو update. لو فيه خطأ بيظهر SnackBar | `POST /api/v1/suppliers` / `PUT .../{id}` | أي مستخدم مسجل |
| **Dialog:** إلغاء وإغلاق | بيقفل الـ dialog | — | — |

### الجداول

قائمة كروت (مش `DataTable`). كل صف فيه:
- **8 أيقونات إجراءات:** 4 في الـ pill (عرض، وتعديل، وطباعة، وإيقاف)، وبعدهم نسخ الملخص، وذكاء المسار، وبطاقة التقييم، وفحص GOEIC. وبعدها أيقونة المصنع.
- **شارة الكود** `SUP-000001` + اسم الشركة + شارة "نشطة".
- **سطر فرعي:** "معرف المصدر" | "العنوان" | "علامات" (لو موجودة).
- **على الطرف التاني:** كود الدولة في شارة برتقالي (CN / TR / DE / IN) + اسم الدولة، وتحتها "النوع: <نوع المورد> (<نوع التسجيل>)".
- **الفلترة:** البحث + switch المتوقفين. **الترتيب:** زي ما جاي من الـ API.

### التابات

الشاشة مفيهاش تابات.

### الـ Dialogs

**1) إضافة مورد ومصدّر أجنبي جديد**
![](../screenshots/02-foreign-suppliers-dialog-add.png)

فورم طويل فيه scroll (عرضه 650 وارتفاعه 90% من الشاشة). الحقول مترتبة في صفوف: الاسم، وبعده النوعين، وبعدهم معرف نافذة و CargoX، وبعدهم الدولة وكودها، والعنوان، والإيميلين، وبعدهم الهاتف والمحمول والفاكس، والموقع، وبعدين بلوك البنك، وبلوك الامتثال، والعلامات التجارية، والملاحظات.

**2) أخطاء الـ validation**
![](../screenshots/02-foreign-suppliers-dialog-add-validation.png)

5 حقول ظهر فيها خطأ: الاسم، ومعرف نافذة، والدولة، وكود الدولة، والعنوان. الرسالة بنفس الصيغة المختلطة `دولة المورد * is required`.

**3) Dialogs متصورتش** (موثقة من الكود بس): `SupplierDetailsDialog`، و`RouteIntelligenceDialog`، و`SupplierScorecardDialog`، و`GOEICVerificationDialog`، و`RowHistoryDialog`، و`UniversalEntityExtractorDialog`، ودايالوج مقارنة التغييرات، ودايالوج تأكيد الإيقاف.

### التصدير والطباعة

| الإجراء | الطريقة | الملف الافتراضي |
|---|---|---|
| تصدير Excel | `GET /api/v1/suppliers/export-excel` ← `FileSaveHelper.saveBytes` | `Foreign_Suppliers_Report.xlsx` |
| تصدير PDF | `GET /api/v1/suppliers/export-pdf` | `Foreign_Suppliers_Report.pdf` |
| تنزيل النموذج | `GET /api/v1/suppliers/excel-template` | `Foreign_Suppliers_Template.xlsx` |
| استيراد Excel | `POST /api/v1/suppliers/import-excel` | — |
| نسخ TSV | في الـ client | — |
| طباعة مورد واحد | PDF في الـ client (`Printing.layoutPdf`، وخط Cairo من `PdfGoogleFonts`) | — |

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | زرار "بطاقة تقييم أداء المورد" بينادي `'/suppliers//scorecard'`، والـ `supplierId` مش موجود في الـ URL رغم إنه متبعت للـ widget. الـ route في الباك هو `/{supplier_id}/scorecard`، فالطلب ده **عمره ما هينجح**، والبطاقة هتطلع error لكل المورّدين. | `features/suppliers/widgets/supplier_scorecard_dialog.dart:59`؛ `modules/suppliers/router.py:298` | `dio.get('/suppliers/${widget.supplierId}/scorecard')`. |
| Medium | زرار "حفظ بيانات المورد الأجنبي" **مفيهوش loading state ولا منع ضغط مزدوج**. لو المستخدم ضغط مرتين أثناء الطلب، الطلب التاني هيترفض غالباً من فحص تكرار الاسم ومعرّف المصدر في الباك (`modules/suppliers/validators.py:23, 36`)، فيظهر للمستخدم SnackBar خطأ تكرار مش مفهوم وهو فعلاً اتحفظ. (مش High لأن الباك بيمنع التكرار في معظم الحالات.) | `suppliers_screen.dart:1086-1183` (مفيش `isSubmitting` ولا `onPressed: null`) | `ValueNotifier<bool>` زي شاشة الشركات، أو `AppButton(isLoading: ...)`. |
| Medium | بيانات البنك المستفيد (SWIFT و IBAN ورقم الحساب) والعنوان وكود الدولة وعلامات الامتثال **مش داخلين في dialog مقارنة التغييرات**. يعني تغيير الحساب البنكي للمورد (وده حقل حساس ضد الاحتيال) بيتحفظ من غير ما يظهر في شاشة التأكيد. | `suppliers_screen.dart:1126-1150` | إضافة كل حقول البنك والامتثال لقائمة `changes`، ويا ريت يتطلب تأكيد صريح لتغيير البنك. |
| Medium | قيم نوع المورد ونوع التسجيل اللي جاية من الباك إند برّه القائمة الثابتة بتظهر خام بالإنجليزي. في الصورة: "النوع: Trader (Foreign Exporter)" لمورد Gujarat، و"(Foreign Exporter)" لكل الموردين. السبب إن القيمة الافتراضية في الـ schema هي `registration_type = "Foreign Exporter"`، وهي مش من الـ 6 قيم اللي الفرونت عارفها. وفي التعديل، الـ dropdown هيعرض أول قيمة في القائمة، بينما القيمة الفعلية اللي هتتحفظ غيرها. | `02-foreign-suppliers-main.png`؛ `modules/suppliers/schemas.py:17-19`؛ `suppliers_screen.dart:123-124, 143-144, 779, 798` | توحيد الـ enum بين الباك والفرونت (Pydantic `Literal` / Enum)، وعمل data migration للقيم القديمة. |
| Medium | "دولة المورد" و"كود الدولة المعتمد" نصين حرين منفصلين، فممكن يتكتب China مع كود `DE`. ده مخالف لقاعدة "Master Data كـ FK"، وكود الدولة قانوني لـ ACID. كمان مفيش تحقق إن الكود حرفين. | `02-foreign-suppliers-dialog-add.png`؛ `suppliers_screen.dart:841-865` | `SearchableDropdownField` للدولة يملأ الكود لوحده من جدول الدول. |
| Medium | مفيش تحقق من صيغة الإيميل، ولا SWIFT (8 أو 11 حرف)، ولا IBAN. و`doc.md` (MD-003 Validation) بينص صراحة على تحقق الإيميل. | `suppliers_screen.dart:879-999`؛ `modules/suppliers/schemas.py:37-39` (`str \| None` مش `EmailStr`) | validators في الفرونت + `EmailStr` و regex في Pydantic. |
| Medium | مفيش RBAC على إنشاء أو تعديل أو إيقاف المورد (بيانات قانونية). | `modules/suppliers/router.py:22-26` | `require_permission("master_data.edit")` على عمليات الكتابة. |
| Medium | رسائل الـ validation مختلطة (عربي وبعده `is required`)، وفيه نجمتين `* *` في الـ label (من الـ widget المشترك `CustomTextField`). | `02-foreign-suppliers-dialog-add-validation.png`؛ `core/widgets/custom_text_field.dart:34, 57-61` | نفس اقتراح شاشة 01. |
| Low | 8 أيقونات من غير نص في كل صف، ومعظمها ملوش tooltip واضح لما الأيقونات تتشابه (✨ و 🏅 و 🛡). ده بيخلي الصف مزدحم، ومخالف لفكرة Compact Toolbar والـ More menu. | `02-foreign-suppliers-main.png`؛ `suppliers_screen.dart:440-515` | الإجراءات الثانوية (ذكاء المسار، والتقييم، و GOEIC، والنسخ) تتنقل لقائمة ⋮ في الصف. |
| Low | البحث مش بيدور في معرّف CargoX، مع إن الـ hint مكتوب فيه "معرف كارجو إكس". | `elements/02-foreign-suppliers-main.json` (نص الـ hint)؛ `suppliers_screen.dart:360-366` | إضافة `cargoxPlatformId` لشرط الفلترة. |
| Low | مخالفات المعايير: `ElevatedButton` و`OutlinedButton` بدل `AppButton`، وألوان مكتوبة مباشرة (`Colors.amber`، `Colors.blueGrey.shade50`، `Colors.red.shade300`)، ونصوص عربي مكتوبة في الكود لعناوين الحفظ. | `suppliers_screen.dart:176-199, 223, 233, 248, 496, 946, 1076-1086` | `AppButton` و`AppTheme` و l10n. |
| Low | زرار الإلغاء عليه ✕ مرتين (أيقونة + نص). | `02-foreign-suppliers-dialog-add-validation.png`؛ `suppliers_screen.dart:1082-1083` | شيل ✕ من نص الترجمة. |
| Low (Web-only) | الـ console طلّع `Refused to set unsafe header "Accept-Encoding"` (مرة واحدة). المتصفح بيرفض الـ header، وملوش تأثير وظيفي. | `runtime-errors.json` → `02-foreign-suppliers`؛ `core/network/api_client.dart:27` | الـ header ميتحطش لما يكون `kIsWeb`. |
