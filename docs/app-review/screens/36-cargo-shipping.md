# حركة وتتبع الشحن وتوزيع الحاويات (Cargo Shipping & Tracking)
![](../screenshots/36-cargo-shipping-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب على الجهاز. أي فرق خاص بالويب متعلّم عليه كده.
> حالة التصوير في `capture-manifest.json`: **ok**. زرار الإضافة مبيفتحش دايلوج، هو بيرجع للفورم inline، فصور `dialog-add` هي نفس فورم التاب الأول.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** تخصيص الحاويات الفعلية للشحنة (نوع الحاوية، العدد، الوزن الإجمالي المعتمد VGM، ورقم كل حاوية وسيلها)، مع توصية تلقائية بعدد ونوع الحاويات من حمولة قوائم التعبئة (CBM / kg). وبعد كده متابعة محطات التحميل لكل حاوية (وصول للمورد، بداية ونهاية التحميل، دخول الميناء) مع مهلة SLA 48 ساعة. ولشحنات LCL فيه متابعة التجميع في مخزن CFS.
- **المستخدمين:** مسؤول الشحن / العمليات، ومتابعة من مدير الاستيراد.
- **المرحلة:** "المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي". `stageCode` بيتغير حسب التاب: `STEP-07` لتخصيص الحاويات و`STEP-08` لمتابعة التحميل (`cargo_shipping_screen.dart:1117-1120`). بتغطي **BP-021** (تنفيذ التحميل: أرقام الحاويات والسيل والأوزان وVGM) وجزء من **BP-020** (جاهزية البضاعة) حسب `docs/phase_05_cargo_shipping.md`. الباك إند فيه كمان **BP-022** (Dual Approval) و**BP-024** (CargoX) بس الشاشة مش بتستخدمهم (شوف الملاحظات). بتعتمد على **MD-010..MD-015** (الحاويات والتعبئة)، وملف الاستيراد، وحجز الشحن (شاشة 35)، وأوامر الشراء / قوائم التعبئة.

## طريقة الوصول والصلاحية
- **Sidebar:** "المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي" ← "حركة وتتبع الشحن وتوزيع الحاويات" (index 26، وكمان index 52). لما الشاشة تتفتح، الـ breadcrumb وتاب النافذة بيعرضوا اسم تاني: "متابعة حركة الشحن البحري والجوي" (`cargoShippingTracking` في `app_localizations_ar.dart:50`).
- **عنوان الـ header:** بيتغير مع الـ stepper: "Freight Allocations & Cargo Shipping (VGM)" في الخطوة 1 و"Cargo Shipping Tracking (48h SLA)" في الخطوة 2 (`:1117-1120`)، والـ badge "Container Allocation".
- **Scaffold:** `VerticalStageScaffold` (Type A) بتابين رأسيين: "Loading & Tracking Form" و"Saved Cargo Registry" (`:1104-1113`). جوه تاب الفورم فيه stepper بخطوتين: "1. تخصيص الحاويات والوزن المعتمد" و"2. متابعة تحميل وتوريد الحاويات وضبط المهل" (`:1313-1314`).
- **الصلاحية:** أي مستخدم عامل login، والـ router محمي بـ `Depends(get_current_user)` (`modules/cargo_shipping/router.py:31`). مفيش RBAC. حتى endpoints الاعتماد الثنائي Level 1 و Level 2 متاحة لأي مستخدم.

## مكونات الشاشة

### الحقول
**الخطوة 1: تخصيص الحاويات والوزن المعتمد** (`36-cargo-shipping-tab-1-loading-tracking-form.png`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة الاستيرادية المربوط * | `SearchableDropdownField<int?>` | أيوه | `validator` بيرجع "يرجى اختيار ملف الشحنة" (`:1404-1420`) | `importFilesProvider`. الـ label بيعرض كود الملف والشركة وACID، وعلامة "مسجل سابقاً" لو فيه سجل |
| نوع الشحنة * | `SearchableDropdownField<String>` | أيوه | - | ثابتة: حاوية كاملة FCL / مجمّع LCL (`:1426-1431`) |
| حمولة الملف المجمعة من قوائم التعبئة | عرض فقط | - | - | مجموع CBM والوزن من قوائم التعبئة (`:1458`) |
| نوع التحميل والتخزين | زرارين (قابل للرص / غير قابل للرص) | - | - | بيأثر على التوصية (`:1471-1478`) |
| اقتراح الحاوية التلقائي | عرض فقط | - | - | مثال: "1 x 40HC (استغلال المساحة 52.4% / الوزن 8.6%)" (`:1493-1498`). لو مفيش حمولة بيتحسب من قيم ثابتة 40 CBM و2274 kg (`:1211-1219`، شوف الملاحظات) |
| نوع الحاوية (لكل بند) | `SearchableDropdownField<String>` | - | - | قائمة أنواع الحاويات (`:1610`) |
| عنوان القسم "بيانات تخصيص الحاويات وأرقام الأقفال والوزن الإجمالي المعتمد:" | عنوان | - | - | جنبه زرار "إضافة نوع حاوية جديد" |
| العدد | TextFormField رقمي | - | - | لما يتغير بيولّد صفوف وحدات جديدة (`:1651`) |
| الوزن الإجمالي المعتمد (كجم) VGM | TextFormField رقمي | - | - | افتراضي 24500 (`:119`، `:1693`) |
| رقم الحاوية (لكل وحدة) | TextFormField | - | مفيش validation لصيغة ISO 6346 | افتراضي `MSCU1234567` أو `MSCU` + جزء من الـ timestamp (`:115`، `:1799`) |
| رقم القفل الملاحي (السيل) | TextFormField | - | مفيش | افتراضي `SL-99001` (`:116`، `:1841`) |
| مستودع التجميع CFS (لو LCL) | TextFormField | - | - | إدخال حر (`:1572`) |

**الخطوة 2: متابعة التحميل وضبط المهل** (`_buildStep2ContainerLoadingTracking`، `:1892`): ملف الشحنة (`SearchableDropdownField` بـ validator، `:1932-1948`)، ونوع الشحنة، ولكل حاوية كارت محطات فيه date-time pickers (وصول للمورد، بداية التحميل، نهاية التحميل، دخول الميناء)، وحالة VGM، وملاحظات، وشارة SLA (في الموعد / متجاوز 48h). ولو LCL فيه كارت تجميع CFS بمحطاته. **الخطوة دي مالهاش صورة مستقلة**، الـ harness صوّر الخطوة 1 بس.

**فلاتر تاب السجل** (`36-cargo-shipping-tab-2-saved-cargo-registry.png`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث باسم أو كود ملف الاستيراد، اسم الشركة، كود الشحن، أو رقم الحاوية | TextField | لا | - | فلترة محلية (`:3535`) |
| حالة الشحن | `SearchableDropdownField` | لا | - | كافة الحالات / Cargo Ready / Completed |
| مهلة الـ 48 ساعة للتوريد | `SearchableDropdownField` | لا | - | كافة المهل / في الموعد / متجاوز |
| السجلات النشطة أو المحذوفة | `SearchableDropdownField` | لا | - | النشطة فقط / الكل / المحذوفة فقط |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| العودة للداش بورد | رجوع | - | أي مستخدم |
| استخراج بيانات بوليصة الشحن (Smart Upload) | يرفع ملف بوليصة ويستخرج رقمها (`:1154-1162`). الـ tooltip "رفع واستخراج بيانات بوليصة الشحن". الـ label مقصوص في الصورة ("تخراج...") | `POST /api/v1/smart-upload/parse/cargo-shipping` | أي مستخدم |
| المحلل الذكي للبوالص والفواتير | يفتح `SmartInvoiceBLExtractorDialog` (`:1134-1143`) | smart-upload | أي مستخدم |
| إيقاف الشحنة عند هذه المرحلة / تخطي المرحلة | تحكم دورة حياة المرحلة من الـ scaffold | lifecycle | أي مستخدم |
| إضافة نوع حاوية جديد | يضيف بند حاوية بقيم افتراضية (`:1541`) | - | - |
| أيقونة نسخ البند / حذف البند | تكرار أو حذف بند حاوية (`:1734-1777`). الـ tooltip بتاع التكرار "تكرار / استنساخ الحاوية (Ctrl + D)" (`elements/36-cargo-shipping-main.json`) | - | - |
| أيقونات النسخ جنب الحقول | نسخ القيمة للحافظة | - | - |
| ⚡ Smart Simulation ⚡ | **بيولّد تواريخ محطات وهمية** (وصول قبل 30 ساعة، تحميل قبل 24 و12 ساعة، دخول ميناء = الآن) ويحط الحالة `GATED_IN_AT_PORT` لكل الحاويات (`:910-970`) | - (في الفرونت، والحفظ بعدها) | - |
| نسخ بيان الحاويات والشحن | TSV للحافظة (`:3320-3330`) | - | - |
| إعادة تحميل حية | `_refreshAllData` | GETs | - |
| تفريغ وبدء تسجيل جديد | `_resetForm` | - | - |
| حفظ مؤقت ومتابعة لاحقة 💾 | `_submitForm(isDraftProgressive: true)` (`:3364`) | `POST /api/v1/cargo-shipping` أو `PUT /{id}` | أي مستخدم |
| حفظ واعتماد إنهاء المرحلة (STEP-07) / Save & Complete Step-07 | `_submitForm(isDraftProgressive: false)` مع spinner (`:3376-3388`) | نفس الـ endpoints | أي مستخدم |
| حفظ محطة حاوية / محطة LCL (في الخطوة 2) | حفظ سريع لمحطة واحدة (`:798-903`) | `PATCH /{id}/containers/{container_no}/loading-tracking`، `POST /{id}/loading-tracking/lcl` | أي مستخدم |
| تصدير SLA (TSV / CSV / PDF / نسخ الملف) | شريط تصدير SLA في الخطوة 2 (`:2072-2150`) | - | - |
| **تاب السجل:** تسجيل ومتابعة شحنة جديدة | يرجع لتاب الفورم | - | - |
| بحث واستنساخ شحنة سابقة | `SearchAndCloneCargoShippingDialog` | `GET /api/v1/cargo-shipping` | - |
| نسخ كجدول (TSV) / تصدير سجل الشحنات إلى Excel / PDF | `TableExportService` ← `FileSaveHelper.exportAndSaveFile` باسم "Cargo Shipping - Registry" (`:544-630`) | - | - |
| إعادة تحميل / تصدير Excel / تصدير PDF / استيراد Excel (شريط عمليات البيانات) | `MasterDataToolbarWidget` بـ `moduleEndpoint: 'cargo-shipping'` (`:3410-3414`) | `cargo-shipping/export-excel` و`export-pdf` و`import-excel`: **مش موجودين** في الـ router | - |
| أيقونات صف السجل: تعديل، نسخ الصف، استنساخ، حذف، استرجاع | (`:3800-3850`) | `GET /{id}`، `DELETE /{id}`، `PATCH|POST /{id}/restore` | أي مستخدم |

### الجداول
السجل معروض **كروت / صفوف مخصصة** (`_buildRegistryRow`، `:3709`) مش `DataTable`. كل صف فيه: كود الشحن، وكود ملف الاستيراد، والشركة، والمورد، ونوع الشحنة، وملخص الحاويات، وعدد الحاويات اللي دخلت الميناء، وشارة SLA، والحالة (Cargo Ready / Completed)، وشارة "محذوف". في بيانات المراجعة مفيش سجلات، فالصورة بتعرض empty state.
- **الفلاتر:** بحث + حالة + SLA + نشط/محذوف.
- **الترتيب:** مفيش ترتيب بيتحكم فيه المستخدم.

### التابات
- **Loading & Tracking Form**: `36-cargo-shipping-tab-1-loading-tracking-form.png` (الخطوة 1 من الـ stepper).

  ![](../screenshots/36-cargo-shipping-tab-1-loading-tracking-form.png)

- **Saved Cargo Registry**: `36-cargo-shipping-tab-2-saved-cargo-registry.png` (السجل فاضي، ومعروض empty state وزرار "تسجيل ومتابعة شحنة جديدة").

  ![](../screenshots/36-cargo-shipping-tab-2-saved-cargo-registry.png)


### الـ Dialogs
- **مفيش دايلوج إضافة.** زرار "تسجيل ومتابعة شحنة جديدة" بيرجع للفورم inline، فـ `36-cargo-shipping-dialog-add.png` هي نفس الفورم.

  ![](../screenshots/36-cargo-shipping-dialog-add.png)

- **أخطاء الـ validation**: `36-cargo-shipping-dialog-add-validation.png`. الحقل "ملف الشحنة الاستيرادية المربوط" اتعلّم بإطار أحمر ورسالة "يرجى اختيار ملف الشحنة"، وظهر SnackBar أحمر "يرجى التأكد من تعبئة جميع الحقول المطلوبة". السلوك ده سليم.

  ![](../screenshots/36-cargo-shipping-dialog-add-validation.png)

- **تحذير سجل مكرر لنفس الملف** (`:1068-1095`): فيه زرار "الذهاب للسجل المحفوظ".
- **تأكيد الحذف** (`:3869-3895`)، و**المحلل الذكي للبوالص**، و**استنساخ شحنة**، و**مراجعة الاستنساخ** (`CloneEntityReviewDialog`، `:339-360`): مالهمش صور.

### التصدير والطباعة
- السجل: Excel و PDF عن طريق `TableExportService` ← `FileSaveHelper.exportAndSaveFile` (مطابق للقاعدة)، ونسخ TSV.
- الخطوة 2 (SLA): TSV و CSV عن طريق `FileSaveHelper.saveText` باسم `Cargo_Shipping_SLA_<code>_<timestamp>.tsv|csv` (`cargo_shipping_sla_export_service.dart:193-202`، `:268-277`). الـ PDF بيروح لـ `Printing.layoutPdf` (`:438-440`). على الويب ده بيفتح نافذة طباعة المتصفح (فرق خاص بالويب).
- شريط "عمليات البيانات" بينادي endpoints مش موجودة (شوف الملاحظات).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| Critical | زرار "Smart Simulation" بيملا محطات التحميل ودخول الميناء بتواريخ **مخترعة** (قبل 30 و24 و12 ساعة والوقت الحالي) ويحط الحالة `GATED_IN_AT_PORT` لكل الحاويات، والرسالة بتطلب من المستخدم يضغط "Save & Complete Step-07" عشان تتسجل في الـ DB وتقدّم دورة الحياة. ده بيسمح بتسجيل بيانات تشغيلية مش حقيقية كأنها حصلت | `cargo_shipping_screen.dart:910-970`، `:3300-3320`؛ الصورة `36-cargo-shipping-main.png` (الزرار في شريط الأكشن) | شيل الزرار من الإنتاج، أو خليه demo-only بفلاج، أو امنع الحفظ بعد المحاكاة |
| High | بيانات افتراضية وهمية: أول بند حاوية بيتملى برقم `MSCU1234567` وسيل `SL-99001` ووزن 24500، وكمان `vgmStatus: 'Submitted'` و`vgmRefNo: 'VGM-9901'` كأن الـ VGM اتقدّم فعلاً (`:112-126`). ولما تضيف حاوية أو تزود العدد بيتولد رقم `MSCU<timestamp>` تلقائياً. أرقام الحاويات دي بتروح للبوليصة والجمارك | `:115-125`، `:255`، `:265`، `:1526-1533`، `:1662`، `:1742`؛ الصورة `36-cargo-shipping-tab-1-loading-tracking-form.png` | خلي أرقام الحاويات فاضية وإلزامية مع validator لصيغة ISO 6346 |
| High | شريط عمليات البيانات (Excel / PDF / استيراد Excel) بينادي `cargo-shipping/export-excel` و`export-pdf` و`import-excel`، والـ routes دي مش موجودة | `:3410-3414`، `core/widgets/master_data_toolbar.dart:253-278`، `modules/cargo_shipping/router.py`؛ الصورة `36-cargo-shipping-tab-2-saved-cargo-registry.png` | مرّر callbacks لـ `TableExportService` أو اعمل الـ endpoints |
| Medium | اقتراح الحاوية التلقائي بيتحسب من حمولة **وهمية** (40 CBM و2274 kg) لما الملف مالوش حمولة أو مفيش ملف مختار، فالصورة بتعرض "حمولة الملف: 0.00 m³ \| 0 kg" وتحتها مباشرة "1 x 40HC (استغلال المساحة 52.4% \| الوزن 8.6%)". التوصية دي بتتقارن بعدد الحاويات المحجوزة وممكن تضلّل المستخدم | `cargo_shipping_screen.dart:1211-1219`؛ الصورة `36-cargo-shipping-main.png` | لو الحمولة صفر، اعرض "مفيش بيانات تعبئة" بدل توصية |
| Medium | الاعتماد الثنائي لمستندات الشحن (BP-022 Level 1 و2) وقائمة CargoX: موجودين في الباك إند والـ provider بس **مفيش أي UI بيناديهم** | `providers/cargo_shipping_provider.dart:125-175`، `modules/cargo_shipping/router.py:82-96`؛ مفيش استخدام تاني في `frontend/lib` | اعرض قسم Dual Approval في السجل أو شاشة المراجعة، مع صلاحيات منفصلة لكل مستوى |
| Medium | زرار "حفظ مؤقت ومتابعة لاحقة" مش بيتقفل وقت الحفظ (`onPressed` من غير شرط `_isSaving`)، فممكن يتبعت أكتر من طلب ويتعمل سجلات مكررة | `:3364` مقابل `:3376` | `onPressed: _isSaving ? null : ...` |
| Medium | زرار "Save & Complete Step-07" مقصوص على حافة شريط الأكشن ("Save & Comple") ومحتاج scroll أفقي عشان يبان | الصورة `36-cargo-shipping-main.png`، `36-cargo-shipping-dialog-add-validation.png`؛ `:3296-3298` (`SingleChildScrollView` أفقي) | استخدم `Wrap` أو `StandardFormActionBar` |
| Medium | Audit trail: `created_by` و`updated_by` قيمتهم الافتراضية `"System"` | `modules/cargo_shipping/model.py:82`، `:84` | مرّر المستخدم الحالي من `get_current_user` |
| Medium | مخالفات UI standards: 30 `ElevatedButton` و20 `OutlinedButton` وصفر `AppButton`، و29 `Color(0x...)` و124 `Colors.xxx` (عدّ بـ grep) | `:1084`، `:1134`، `:3296-3395` | `AppButton` و`AppTheme` |
| Medium | أزرار الـ header مقصوصة: "استخراج بيانات بوليصة الشحن" ظاهرة "...تخراج بيانات بوليصة الشحن" | الصورة `36-cargo-shipping-main.png` | قصّر الـ labels أو حطها في overflow menu |
| Low | "Smart Simulation" و"Save & Complete Step-07" والـ header والتابات الرأسية ظاهرين بالإنجليزي في الوضع العربي، لأن الشاشة بتختار النص بـ `Directionality.of(context)`. ده **الـ bug المعروف** بتاع الـ locale (`supportedLocales` مش متعرّفة في `main.dart`) | `:3302-3317`، `:3381-3387`؛ الصورة `36-cargo-shipping-main.png` | اعتمد على `context.l10n` بدل `Directionality`، وصلّح الـ locale مركزياً |
| Low | رسالة الـ empty state في السجل بتقول "لا توجد **دراسات** متابعة..."، والكلمة غلط (منسوخة من شاشة الدراسات) | `core/localization/app_localizations_ar.dart:3111`؛ الصورة `36-cargo-shipping-tab-2-saved-cargo-registry.png` | "لا توجد شحنات مطابقة للبحث الحالي" |
| Low | تأكيد الحذف بينادي `softDeleteRecord` من غير try/catch، فلو الباك إند رجع خطأ مش هيظهر للمستخدم | `:3885-3893` | لف الاستدعاء في try/catch واعرض SnackBar |
| Low | ملفات تصدير SLA اسمها `Cargo_Shipping_SLA_<code>_<timestamp>`، مش النمط القياسي `[Stage Name] - [Import File Code].ext`، وتصدير "Excel" بيطلع CSV. والـ PDF بيعدي على `Printing.layoutPdf` مش `FileSaveHelper` | `services/cargo_shipping_sla_export_service.dart:194`، `:268`، `:438` | وحّد التسمية وخلي الحفظ عن طريق `FileSaveHelper.exportAndSaveFile` |
| Low | badge "Container Allocation" و`STEP-07` متشاركين مع شاشة حجز النولون (35) | `:1118`؛ الصورتين `36-cargo-shipping-main.png` و`35-freight-booking-main.png` | stage codes مستقلة |
| Low (Web-only) | `Refused to set unsafe header "Accept-Encoding"` (4 مرات): قيد من المتصفح، مش bug على الديسكتوب | `runtime-errors.json` ← `36-cargo-shipping` | شيل الـ header على `kIsWeb` |
