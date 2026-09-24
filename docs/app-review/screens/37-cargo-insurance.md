# شهادات ووثائق التأمين على البضائع (Cargo Insurance)
![](../screenshots/37-cargo-insurance-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب على الجهاز. أي فرق خاص بالويب متعلّم عليه كده.
> حالة التصوير في `capture-manifest.json`: **partial**. الـ harness مقدرش يقفل الدايلوج بـ Escape أو Cancel (الدايلوج `barrierDismissible: false` ومفيهوش زرار إلغاء، والقفل بأيقونة X بس)، فتاب "New Certificate" اتصوّر وهو فاتح نفس الدايلوج.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** إصدار وثيقة أو شهادة تأمين بحري / جوي / بري على البضاعة المشحونة: ربط ملف الاستيراد، وبيانات المؤمَّن له وشركة التأمين، وخط السير، وحساب القيمة المؤمَّنة (CIF × 110%)، والقسط الأساسي حسب بند التغطية (ICC A / B / C / Air All Risks)، وملحق الحروب والإضرابات، والحد الأدنى للقسط، ورسوم الإصدار، والضرائب والدمغات. بعد كده الوثيقة بتتعمل "إصدار" رسمي.
- **المستخدمين:** مسؤول الشحن / التأمين، والمالية (تكلفة التأمين بتدخل في CIF والـ Landed Cost)، والمستخلص الجمركي (وثيقة التأمين مطلوبة للشحنات FOB/CFR حسب `docs/phase_06_customs_preparation.md:14`).
- **المرحلة:** مربوطة بـ "المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي" (`stageCode: 'PHASE-3-INS'`، `cargo_insurance_screen.dart:137`). مفيش BP مخصوص للتأمين في `doc.md` أو ملفات الـ phases. التأمين مذكور كمستند "Insurance Certificate حسب Incoterm" (`doc.md:2635`) وكعنصر في CIF (`docs/phase_01_import_planning.md:78`). بتعتمد على **MD-001** (الشركات المستوردة)، و**MD-003** (الشركاء / شركات التأمين)، و**MD-004** (العملات)، و**MD-006** (مصفوفة مسؤولية التأمين في الـ Incoterms)، وملف الاستيراد، وحجز الشحن (35)، والشحن والتحميل (36).

## طريقة الوصول والصلاحية
- **Sidebar:** "المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي" ← "شهادات ووثائق التأمين على البضائع" (index 65). الـ breadcrumb وتاب النافذة بيعرضوا "تأمين الشحن البحري" (`navigation_provider.dart:180`) مع إن الشاشة بتغطي بحري وجوي وبري. الـ header: "Marine & Cargo Insurance Engine" والـ badge "Marine Cargo Insurance".
- **Scaffold:** `VerticalStageScaffold` (Type A) بتابين: "Certificates Registry" و"New Certificate" (`:124-133`). تاب "New Certificate" بيفتح دايلوج الإصدار على طول (`:183`).
- **مداخل تانية:** `CargoInsuranceScreen.showCreateDialog(context, initialImportFileId: ...)` (`:36`) بتفتح الدايلوج من شاشات تانية وبتملا بيانات الملف تلقائياً.
- **الصلاحية:** أي مستخدم عامل login، والـ router محمي بـ `Depends(get_current_user)` (`modules/cargo_insurance/router.py:20`). مفيش RBAC، حتى لعملية "إصدار الوثيقة" الرسمية.

## مكونات الشاشة

### الحقول
**شريط البحث والفلترة** (`37-cargo-insurance-main.png`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث برقم الوثيقة، رقم البوليصة، المستورد، شركة التأمين، الميناء | TextField | لا | - | فلترة |
| شرائح الحالة: الكل / معتمدة / مسودة / ملغاة | ChoiceChips | لا | - | `ISSUED` / `DRAFT` / `CANCELLED` (`:463-469`) |
| إخفاء المحذوف | FilterChip | لا | - | (`:474`) |
| عدّاد النتائج | Badge | - | - | عدد الوثائق المعروضة |

**دايلوج "إصدار شهادة تأمين البضائع المشحونة"** (`37-cargo-insurance-dialog-add.png`). تحت العنوان سطر فرعي: "حساب القيمة المؤمنة وقسط التأمين طبقاً لشروط معهد المكتتبين بلندن". الحقول متقسمة لأقسام: البيانات الأساسية، و"بيانات الشحن والرحلة وخط السير" (كارت أزرق)، والقيم والعملة، و"شروط التغطية التأمينية وملاحق المخاطر الإضافية" (كارت أخضر)، وعلى اليمين لوحة "📊 محاكاة وحساب قسط التأمين الفوري" ووصف البضاعة وزرار الحفظ:

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ربط ملف الشحنة الاستيرادية * | `SearchableDropdownField<int>` | مكتوب عليه * | **مفيش `validator`** (`:1445-1460`)، والباك إند بيقبل `import_file_id = null` (`schemas.py:46`) | `importFilesProvider`. لما تختاره بيملا وسيلة النقل والناقل والسفينة والموانئ والقيم من الحجز والشحن وأوامر الشراء (`:1231-1330`) |
| المؤمَّن له (المستورد) * | TextFormField | أيوه | مش فاضي: "اسم المستورد مطلوب" (`:1467-1473`) | إدخال حر (مع إن الشركات المستوردة MD-001 متحمّلة `importCompaniesProvider`) |
| نوع وثيقة التأمين * | `SearchableDropdownField<String>` | أيوه | - | ثابتة (وثيقة محددة لشحنة واحدة / ...) (`:1479`) |
| شركة التأمين المصدرة | TextFormField | لا | - | افتراضي ثابت `Misr Insurance Co.` (`:1068`)، إدخال حر مش من الشركاء |
| رقم وثيقة التأمين | TextFormField | لا | - | إدخال حر |
| وسيلة النقل * | `SearchableDropdownField<String>` | أيوه | الباك إند: OCEAN/AIR/ROAD (`validators.py:39-44`) | ثابتة (`:1546`) |
| الخط الملاحي أو الناقل | TextFormField | لا | - | إدخال حر (`:1576`) |
| اسم السفينة أو الرحلة | TextFormField | لا | - | إدخال حر (`:1586`) |
| ميناء الشحن والتصدير * | **TextFormField** | أيوه | مش فاضي: "حقل إلزامي" (`:1600-1606`) | إدخال حر، مش من الموانئ MD-009 |
| ميناء الوصول والتفريغ * | **TextFormField** | أيوه | مش فاضي (`:1611-1617`) | إدخال حر |
| رقم بوليصة الشحن والتتبع | TextFormField | لا | - | إدخال حر (`:1622`) |
| قيمة فاتورة البضاعة فوب * | TextFormField رقمي | مكتوب عليه * | **مفيش validator**، وبيقبل 0.0 (`:1642-1650`)؛ الباك إند `ge=0` (`schemas.py:62`) | إدخال / من أوامر الشراء |
| تكلفة النولون أو الشحن | TextFormField رقمي | لا | - | من الحجز (`:1655`) |
| العملة * | `SearchableDropdownField<String>` | أيوه | - | **قائمة ثابتة** USD/EUR/EGP/CNY/GBP (`:1668-1680`) |
| بند التغطية (شروط المعهد) * | `SearchableDropdownField<String>` | أيوه | الباك إند: ICC_A/AIR_ALL_RISKS/ICC_B/ICC_C | ثابتة ومعاها النسبة في الـ label (`:1705-1730`) |
| تضمين ملحق أخطار الحروب والإضرابات (+0.05%) | Checkbox | لا | - | افتراضي مفعّل. تحته نص توضيحي: "ملحق إلزامي للاعتمادات المستندية والتخليص الجمركي للشحنات" |
| وصف البضاعة والطرود المشحونة | TextFormField متعدد الأسطر | لا | - | (`:1872`) |
| عدد الطرود / الوزن القائم (كجم) | TextFormField رقمي | لا | - | (`:1884-1900`) |
| محاكاة حساب قسط التأمين الفوري | لوحة عرض | - | - | بتتحسب **في الفرونت** (`_runLiveCalculation`، `:1186-1228`): قيمة البضاعة شاملة النولون، والقيمة المؤمنة 110%، والقسط الأساسي 0.25%، والحرب 0.05%، وصافي القسط بعد الحد الأدنى (30)، ورسوم الإصدار (15)، والضرائب (5%)، والإجمالي |

حقول مخفية بقيم افتراضية بتتبعت في الـ payload: سعر الصرف **48.50** (`_exchangeRateCtrl`، `:1080`)، نسبة الزيادة 10%، الوجهة النهائية "Cairo, Alexandria, Egypt"، الحد الأدنى 30، رسوم الإصدار 15، الضريبة 0.05، نوع الطرود "Cartons and Pallets"، وكيل المعاينة "Lloyd's Agency Alexandria & Port Said"، ومكان سداد التعويض "Cairo, Egypt" (`:1085-1098`).

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| العودة للداش بورد | رجوع | - | أي مستخدم |
| تكويد شركة تأمين بالذكاء الاصطناعي ✨ | `UniversalEntityExtractorDialog.showInsuranceCompanyExtractor`، بيحفظ شركة التأمين كشريك (`:152-160`) | `/api/v1/external-service-providers` | أي مستخدم |
| التأمين الذكي (Smart Upload) | يرفع مستند ويستخرج رقم البوليصة، وبعدين يفتح دايلوج **فاضي** (`:167-184`). الـ tooltip "رفع واستخراج وثيقة التأمين الذكي"، والـ label مقصوص في الصورة | `smart-upload/parse/cargo-shipping` (الموديول غلط، شوف الملاحظات) | أي مستخدم |
| إيقاف الشحنة / تخطي المرحلة | تحكم دورة حياة المرحلة | lifecycle | أي مستخدم |
| إصدار وثيقة تأمين جديدة | يفتح الدايلوج (`:320`) | - | أي مستخدم |
| تحديث السجل | `_refreshData`، والـ tooltip "تحديث البيانات" | `GET /api/v1/cargo-insurance/certificates` | أي مستخدم |
| نسخ الملف الشامل | `copyDossierToClipboard` (`:385`) | - | - |
| طباعة تقرير بي دي إف | `printOrSaveCertificatesPdf` ← `Printing.layoutPdf` (`:370`) | - | - |
| تصدير أكسيل | `saveCertificatesCsvToFile`، بيطلع CSV (`:356`) | - | - |
| تصدير جدول البيانات | `saveCertificatesTsvToFile` (`:342`) | - | - |
| إعادة تحميل / تصدير Excel / تصدير PDF / استيراد Excel (شريط عمليات البيانات) | `MasterDataToolbarWidget` بـ `moduleEndpoint: 'cargo-insurance'` (`:398-402`) | `cargo-insurance/export-excel` و`export-pdf` و`import-excel`: **مش موجودين** | - |
| أيقونات الصف: نسخ الملخص، عرض، تعديل (للمسودة بس)، طباعة، حذف، إصدار الوثيقة | (`:606-630`) | `GET /certificates/{id}`، `PUT /certificates/{id}`، `DELETE /certificates/{id}` (soft)، `POST /certificates/{id}/issue` | أي مستخدم |
| حفظ وإصدار مسودة الوثيقة | validate وبعدين حفظ كـ DRAFT، مع spinner و"جاري الحفظ" (`:1912-1928`، `:1973-2045`) | `POST /api/v1/cargo-insurance/certificates` أو `PUT` | أي مستخدم |
| X (قفل الدايلوج) | `Navigator.pop` (`:1424`) | - | - |

الـ endpoint `POST /api/v1/cargo-insurance/calculate` موجود ومتعرّف في الـ provider، بس **الدايلوج مش بيستخدمه**. الحساب بيتكرر في الفرونت.

### الجداول
جدول سجل الوثائق (`DataTable`، `:565-576`). في بيانات المراجعة مفيش وثائق، فالصورة بتعرض empty state "لا توجد وثائق تأمين مسجلة حالياً".

| العمود | معناه |
|---|---|
| الإجراءات | نسخ + `RowActionsPill` + إصدار |
| # | مسلسل |
| كود الوثيقة | `certificate_code` |
| تاريخ الإصدار | |
| الوثيقة / الملف | رقم البوليصة وكود ملف الاستيراد |
| المؤمَّن له | اسم المستورد |
| شركة التأمين | افتراضي "Misr Insurance Co." لو فاضية (`:793-798`) |
| خط السير | وسيلة النقل وPOL ← POD |
| القيمة المؤمنة (110%) | |
| بند التغطية | ICC A / B / C / Air |
| إجمالي القسط | |
| الحالة | DRAFT / ISSUED / CANCELLED |

- **كروت KPI فوق الجدول:** إجمالي الوثائق، ووثائق معتمدة، وإجمالي القيمة المؤمنة، وإجمالي الأقساط (`:226-291`).
- **الفلاتر:** بحث + شرائح الحالة + إخفاء المحذوف. **الترتيب:** مفيش.

### التابات
- **Certificates Registry**: `37-cargo-insurance-tab-1-certificates-registry.png` (نفس الرئيسية: KPIs وأزرار التصدير والجدول الفاضي).

  ![](../screenshots/37-cargo-insurance-tab-1-certificates-registry.png)

- **New Certificate**: `37-cargo-insurance-tab-2-new-certificate.png` (بيفتح دايلوج الإصدار).

  ![](../screenshots/37-cargo-insurance-tab-2-new-certificate.png)


### الـ Dialogs
- **إصدار / تعديل شهادة تأمين**: `37-cargo-insurance-dialog-add.png`. الحقول متشرحة فوق، ولوحة المحاكاة على اليمين.

  ![](../screenshots/37-cargo-insurance-dialog-add.png)

- **أخطاء الـ validation**: `37-cargo-insurance-dialog-add-validation.png`. ظهر خطأ أحمر تحت "المؤمَّن له (المستورد)": "اسم المستورد مطلوب"، وتحت الميناءين: "حقل إلزامي". **مظهرش خطأ** تحت "ربط ملف الشحنة الاستيرادية *" ولا تحت "قيمة فاتورة البضاعة فوب *" مع إن الاتنين مكتوب عليهم نجمة وقيمة الفاتورة 0.0.

  ![](../screenshots/37-cargo-insurance-dialog-add-validation.png)

- **تأكيد الإصدار** (`:982-1015`)، و**تأكيد الحذف** (`:1021-1050`)، و**عرض / طباعة الوثيقة** (`_CargoInsuranceDetailsDialog`، `:2050`): مالهمش صور لأن مفيش وثائق.

### التصدير والطباعة
- TSV و CSV عن طريق `FileSaveHelper.saveText` باسم `cargo_insurance_registry_<timestamp>.tsv|csv` (`services/cargo_insurance_export_service.dart:199-226`).
- PDF عن طريق `Printing.layoutPdf` باسم `cargo_insurance_registry.pdf` (`:501-503`). على الويب ده بيفتح نافذة طباعة المتصفح (فرق خاص بالويب).
- طباعة وثيقة واحدة من دايلوج التفاصيل (`cargo_insurance_screen.dart:2240`).
- شريط "عمليات البيانات" بينادي endpoints مش موجودة.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| High | نسب ورسوم hard-coded: الضريبة 5%، والحد الأدنى للقسط 30، ورسوم الإصدار 15، ونسب التغطية (0.25 / 0.20 / 0.15 / 0.10%)، والحرب 0.05%، في الفرونت **وكمان** في الباك إند. ده مخالف لقاعدة "ممنوع Hard-Code أي نسبة ضريبية أو رسم"، والحساب متكرر في مكانين | `cargo_insurance_screen.dart:1089-1091`، `:1198-1205`؛ `modules/cargo_insurance/service.py:20-26`؛ `schemas.py:18-20`، `:69-71` | انقل النسب لجدول master (شركات التأمين / أسعار التغطية)، وخلي المحاكاة تنادي `POST /cargo-insurance/calculate` |
| High | شريط عمليات البيانات (Excel / PDF / استيراد Excel) بينادي `cargo-insurance/export-excel` و`export-pdf` و`import-excel`، والـ routes دي مش موجودة. وده كمان بيكرر أزرار التصدير اللي فوقه | `:398-402`، `core/widgets/master_data_toolbar.dart:253-278`، `modules/cargo_insurance/router.py`؛ الصورة `37-cargo-insurance-main.png` (مجموعتين أزرار تصدير) | شيل الشريط أو مرّر callbacks للتصدير الموجود |
| Medium | اللوحة بتعرض "إجمالي قسط التأمين المستحق 47.25 USD" والقيمة المؤمنة صفر، لأن الحد الأدنى والرسوم بيتطبقوا حتى من غير بضاعة. والفورم بيسمح بالحفظ بقيمة فاتورة 0 | الصورة `37-cargo-insurance-dialog-add.png`، `37-cargo-insurance-dialog-add-validation.png`؛ `:1642-1650` (مفيش validator)، `schemas.py:62` (`ge=0`) | validator `> 0` في الفرونت، و`gt=0` في الـ schema |
| Medium | "ربط ملف الشحنة الاستيرادية *" مكتوب عليه نجمة بس مفيش validator، والباك إند بيقبل null، فممكن تطلع وثيقة تأمين مش مربوطة بأي شحنة | `:1445-1460`، `modules/cargo_insurance/schemas.py:46`؛ الصورة `37-cargo-insurance-dialog-add-validation.png` | validator + `import_file_id` إلزامي في الـ create schema |
| Medium | حقول مرجعية كنص حر مش `SearchableDropdownField`: ميناء الشحن وميناء الوصول (MD-009)، والناقل، وشركة التأمين (MD-003)، والمؤمَّن له (MD-001). والعملة قائمة ثابتة مع إن `currenciesProvider` بيتحمّل | `:1600-1617`، `:1576`، `:1504-1510`، `:1467`، `:1668-1680`، `:76-77`؛ `elements/37-cargo-insurance-tab-2-new-certificate.json` (الحقول `type: text`) | `SearchableDropdownField` مربوط بالـ masters وتخزين FK |
| Medium | زرار "التأمين الذكي" بيستخدم `SmartUploadModule.cargoShipping` (parser الشحن، مش التأمين)، وبعد الاستخراج بيفتح دايلوج **فاضي** فالبيانات المستخرجة بتضيع | `:167-184`؛ `core/widgets/smart_upload_button.dart:22-34` (الـ enum مفيهوش موديول تأمين أصلاً) | أضف موديول تأمين للـ enum وللـ parser، ومرّر الحقول المستخرجة للدايلوج |
| Medium | الحذف مسموح حتى للوثيقة بعد إصدارها (ISSUED)، والتعديل بس هو اللي مقفول. والفلتر "ملغاة" (CANCELLED) مفيش endpoint يوصل للحالة دي | `:615-617` (`onDelete` من غير شرط)، `modules/cargo_insurance/service.py:248-250`، `router.py` (مفيش cancel) | امنع حذف ISSUED واعمل endpoint إلغاء (cancel) بسبب |
| Medium | Audit trail: `created_by` و`updated_by` دايماً `"system"` لأن الـ router مش بيمرر المستخدم للـ service | `modules/cargo_insurance/service.py:85`، `:153-154`، `:225`؛ `router.py:42-47` | مرّر `current_user` من `get_current_user` |
| Medium | كروت KPI بتجمع القيمة المؤمنة والأقساط لكل الوثايق بغض النظر عن العملة، وبتعرضها بعلامة `$` | `:226-227`، `:284`، `:291` | حوّل لعملة موحدة بسعر الصرف، أو اعرض الإجمالي لكل عملة |
| Medium | قيم افتراضية بتتحط كأنها بيانات حقيقية: شركة التأمين "Misr Insurance Co."، ووكيل المعاينة "Lloyd's Agency Alexandria & Port Said"، و"Cairo, Egypt". والجدول بيعرض "Misr Insurance Co." لو الحقل فاضي | `:1068`، `:1097-1098`، `:793-798`؛ الصورة `37-cargo-insurance-dialog-add.png` | اسيب الحقول فاضية، واعرض "—" في الجدول |
| Low | خطأ runtime: `Bad state: Cannot use "ref" after the widget was disposed` اتسجّل في الكونسول وقت محاولات الـ harness لقفل الدايلوج. السبب مش متحدد من الكود: الـ `addPostFrameCallback` اللي بيعمل `ref.read` (`:1142-1144`) بيشتغل بس لما الدايلوج يتفتح بـ `initialImportFileId`، وده مش حصل في التصوير. مفيش أثر ظاهر على المستخدم في الصور | `runtime-errors.json` ← `37-cargo-insurance` (10:11:33) | تتبّع الخطأ في debug build وضيف `if (!mounted) return;` قبل أي `ref` في callbacks الـ async |
| Low | الـ label والـ hint بتوع "ربط ملف الشحنة الاستيرادية" راكبين فوق بعض ومش مقروءين | الصورة `37-cargo-insurance-dialog-add.png` (أول حقل) | ظبط `floatingLabelBehavior` أو شيل الـ hint لما الـ label موجود |
| Low | نص زرار "حفظ وإصدار مسودة الوثيقة" مقصوص من تحت (ارتفاع ثابت 46) | الصورة `37-cargo-insurance-dialog-add.png`؛ `:1909-1912` | شيل `height: 46` الثابت أو استخدم `AppButton` |
| Low | الدايلوج مبيتقفلش بـ Escape (`barrierDismissible: false`) ومفيهوش زرار "إلغاء"، بس أيقونة X | `:39`، `:99`، `:1422-1425`؛ `capture-manifest.json` ("dialog could not be closed with Escape/Cancel") | زرار إلغاء في شريط الأكشن + تأكيد لو فيه تعديلات |
| Low | عنوان الـ header "Marine & Cargo Insurance Engine" والتابات الرأسية بالإنجليزي في الوضع العربي. ده **الـ bug المعروف** بتاع الـ locale | الصورة `37-cargo-insurance-main.png` | يتحل مركزياً في `main.dart` |
| Low | مخالفات UI standards: 17 `ElevatedButton` و9 `OutlinedButton` وصفر `AppButton`، و76 `Colors.xxx` (عدّ بـ grep) | `:152`، `:215`، `:308`، `:1912` | `AppButton` و`AppTheme` |
| Low | اسم ملفات التصدير `cargo_insurance_registry_<timestamp>` و`cargo_insurance_registry.pdf`، مش النمط `[Stage Name] - [Import File Code].ext`. والـ PDF مش بيعدي على `FileSaveHelper`، و"تصدير أكسيل" بيطلع CSV | `services/cargo_insurance_export_service.dart:199`، `:222`، `:501-503` | وحّد مع `TableExportService` و`FileSaveHelper.exportAndSaveFile` |
| Low (Web-only) | `Refused to set unsafe header "Accept-Encoding"` (27 مرة): قيد من المتصفح | `runtime-errors.json` ← `37-cargo-insurance` | شيل الـ header على `kIsWeb` |
