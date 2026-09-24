# حجز النولون وتأكيد الخط الملاحي (Freight Booking)
![](../screenshots/35-freight-booking-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب على الجهاز. أي فرق خاص بالويب متعلّم عليه كده.
> حالة التصوير في `capture-manifest.json`: **partial**. التابين الداخليين جوه دايلوج الحجز ("1. تفاصيل الحجز وعروض الشحن" و"2. بنود التكلفة والنولون") ملقاش الـ harness الـ label بتاعهم في شجرة الـ semantics، فتاب بنود التكلفة **مالوش صورة** ومشروح من الكود بس.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** تحويل عرض النولون المختار (من سيناريوهات الشحن وعروض الـ RFQ) لحجز فعلي على خط ملاحي أو وكيل شحن: رقم تأكيد الحجز، وميناء التحميل والوصول، وETD / ETA / ATD، وعدد ونوع الحاويات، والأيام المجانية، واسم السفينة ورقم الرحلة، وإذن الإفراج عن الحاويات، وبنود تكلفة النولون (17 بند). بعد كده تأكيد الحجز (BK-01) وتأكيد الإبحار والبوليصة.
- **المستخدمين:** مسؤول الشحن / اللوجستيات، ومدير الاستيراد للمتابعة.
- **المرحلة:** "المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي" (`stageCode: 'PHASE-3: STEP_07'`، `freight_booking_screen.dart:474`). بتغطي **BP-017** (اختيار مزود الشحن)، و**BP-018** (إنشاء مسودة الحجز)، و**BP-019** (تأكيد الحجز وتثبيت السفينة) حسب `docs/phase_04_freight_booking.md` و`doc.md:1737-1739`. بتعتمد على **MD-003** (الشركاء والخطوط الملاحية)، و**MD-009** (الموانئ)، و**MD-010..MD-015** (الحاويات)، و**MD-004** (العملات)، و**MD-020..MD-026** (أسعار وعقود الشحن).

## طريقة الوصول والصلاحية
- **Sidebar:** "المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي" ← "حجز النولون وتأكيد الخط الملاحي" (index 25). ممكن كمان تكتب الاسم في البحث السريع بتاع الـ sidebar.
- **Scaffold:** `VerticalStageScaffold` (Type A) بتابين رأسيين: "Freight Bookings Registry" و"New Booking Request" (`:461-470`). تاب "New Booking Request" بيفتح دايلوج الإنشاء نفسه (الصورة `35-freight-booking-tab-2-new-booking-request.png`).
- **الصلاحية:** أي مستخدم عامل login. الـ router كله محمي بـ `dependencies=[Depends(get_current_user)]` (`modules/freight_booking/router.py:20`)، ومفيش RBAC أو permission code لأي عملية (إنشاء، تأكيد، إبحار، حذف).

## مكونات الشاشة

### الحقول
**شريط الفلترة (تاب السجل):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث بكود الحجز أو رقم التأكيد | TextField | لا | مفيش | بيبعت `search` لـ `GET /api/v1/freight-booking` (`:630-655`) |
| تصفية حسب الحالة | `SearchableDropdownField<String>` | لا | مفيش | ثابتة: جميع الحالات / Draft / Booking Requested / Confirmed / Sailed (`:664-680`) |
| شريحة "تصفية: شحنة #ID" | Chip | لا | - | بتظهر لما الشاشة تتفتح بـ `initialImportFileId` (`:686`)، وبتعرض الـ ID الداخلي مش كود الملف |

**دايلوج "إنشاء حجز شحن ملاحي" ← تاب "1. تفاصيل الحجز وعروض الشحن"** (الصورة `35-freight-booking-dialog-add.png`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة الاستيرادية * | `SearchableDropdownField<int?>` | أيوه (مكتوب عليه *) | **مفيش `validator`** (`:2343-2386`). بيعمل فحص تكرار محلي: لو الملف ليه حجز نشط بيفتح دايلوج تحذير | `importFilesProvider` ← `GET /api/v1/import-files` |
| رقم تأكيد الحجز | TextFormField | أيوه | مش فاضي (`:2389`) | قيمة افتراضية ثابتة `MSC-CN-889001` (`:1284`) |
| الخط الملاحي * | `SearchableDropdownField<String>` | أيوه | مفيش؛ لو القيمة مش في القائمة بيختار أول عنصر تلقائياً (`:2593`) | `partnersProvider` (الشركاء من نوع خط ملاحي). بيتخزن **بالاسم** (`shipping_line_name`) مش `shipping_line_id` |
| وكيل الشحن | `SearchableDropdownField<String>` | لا | نفس سلوك أول عنصر (`:2607`) | `partnersProvider`، بيتخزن بالاسم |
| ميناء التحميل * | `SearchableDropdownField<String>` | أيوه | أول ميناء في القائمة افتراضياً (`:2625`) | `transportLocationsProvider` (MD-009)، بيتخزن كنص `pol_name` |
| ميناء الوصول * | `SearchableDropdownField<String>` | أيوه | تاني ميناء في القائمة افتراضياً (`:2639`) | نفس المصدر، بيتخزن كنص `pod_name` |
| تاريخ المغادرة المتوقع (ETD) * | Date picker | أيوه | الباك إند: ETA لازم بعد ETD (`modules/freight_booking/validators.py:8`) | افتراضي النهارده + 5 أيام |
| تاريخ الوصول المتوقع (ETA) * | Date picker | أيوه | نفس القاعدة | افتراضي النهارده + 23 يوم |
| تاريخ المغادرة الفعلي (ATD) | Date picker | لا | - | "لم يحدد بعد" لحد ما يتسجّل |
| بانر التأخير وموعد الوصول للمخزن | عرض فقط | - | - | بيتحسب من ETD/ATD + أيام الوصول للمخزن (`:2707-2730`) |
| الأيام المجانية بالميناء * | TextFormField رقمي | أيوه | لو فاضي أو غلط بيتبعت 14 (`:1848`) | افتراضي 14 |
| أيام الوصول للمخزن | TextFormField رقمي | لا | لو فاضي بيتبعت 7 | افتراضي 7 |
| حالة الحجز * | `SearchableDropdownField<String>` | أيوه | القائمة فيها Draft / Booking Requested / **Confirmed / Sailed** (`:2754-2765`) | ثابتة |
| اسم السفينة | TextFormField | لا | مفيش | افتراضي ثابت `MSC Oscar` |
| رقم الرحلة | TextFormField | لا | مفيش | افتراضي ثابت `VY-2026-X8` |
| إذن الإفراج عن الحاويات | TextFormField | لا | مفيش | افتراضي ثابت `RO-MSC-9912` |
| نوع الحاوية المطلوب حجزها | `SearchableDropdownField<String>` | لا | - | ثابتة: 20GP / 40GP / 40HC / 45HC / 20RF / 40RF (`:2803-2815`) |
| عدد الحاويات المحجوزة | TextFormField رقمي | لا | الباك إند: `quantity >= 1` | افتراضي 1 |

تحت نوع وعدد الحاويات فيه شريط معلومات ثابت: "ℹ️ ملاحظة: تخصيص الحاويات التفصيلي، أرقام السيل، أوزان VGM، والفحص يتم في مرحلة (متابعة وتجهيز التحميل)"، يعني التفاصيل دي بتتسجل في شاشة 36. وبانر التأخير في الصورة أخضر ومكتوب فيه "✅ تم الإبحار في الموعد المجدول (لا توجد تأخيرات)" مع "موعد الوصول للمخزن المتوقع: 24-10-2026" (ETA + 7 أيام).

فيه كمان (بيظهر لما تختار ملف له سيناريو شحن متقيّم) قسم "عروض الشحن المقيّمة" بكروت للعروض، وزرار "تطبيق العرض" على كل كارت، وعلامة "أفضل عرض" (`:2400-2580`).

**تاب "2. بنود التكلفة والنولون"** (مفيش صورة، من الكود `:2130-2220`): 17 بند تكلفة (حاوية 40، حاوية 20، LCL لكل CBM، شحن سريع، EUR.1/ATR، SOLAS VGM، إخطار VGM، Telex Release، تأمين، إلغاء، ICS2، رسوم أخرى، رسوم مستندات، Waiver، DTHC، تخزين أسبوعي، يوم تخزين إضافي). كل بند فيه: checkbox "ينطبق"، وسعر، وعملة (`SearchableDropdownField` بقائمة ثابتة USD/EUR/EGP/GBP/CNY، `:2163-2169`)، وكمية لبعض البنود. وفيه كارت مقارنة بين تكلفة العرض الأصلي والتكلفة الحالية (وفر / زيادة) (`:2044-2110`).

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| العودة للداش بورد | يرجع للوحة المتابعة | - | أي مستخدم |
| تكويد خط ملاحي بالذكاء الاصطناعي ✨ | يفتح `UniversalEntityExtractorDialog` لاستخراج بيانات خط ملاحي وحفظه كشريك (`:489`) | `/api/v1/external-service-providers` | أي مستخدم |
| تكويد شركة شحن بالذكاء الاصطناعي ✨ | نفس الفكرة لوكيل الشحن (`showFreightForwarderExtractor`، `:508-510`). الـ label الكامل من `elements/35-freight-booking-main.json`، وفي الصورة مقصوص وظاهر منه "...ذكاء الاصطناعي" بس | نفس المصدر | أي مستخدم |
| إيقاف الشحنة عند هذه المرحلة / تخطي المرحلة | تحكم دورة حياة المرحلة (`ShipmentStageLifecycleControl` جوه الـ scaffold) | lifecycle endpoints | أي مستخدم |
| إعادة تحميل حية / تصدير Excel / تصدير PDF / استيراد Excel | شريط `MasterDataToolbarWidget` (`:538-542`). بينادي `freight-booking/export-excel` و`export-pdf` و`import-excel` | **الـ endpoints دي مش موجودة** في `modules/freight_booking/router.py` | - |
| إنشاء حجز شحن جديد | يفتح دايلوج الإنشاء (`:560`) | - | أي مستخدم |
| بحث واستنساخ حجز سابق | يفتح `SearchAndCloneFreightBookingDialog` | `GET /api/v1/freight-booking` | أي مستخدم |
| نسخ كجدول (TSV) | ينسخ السجل للحافظة (`:598`) | - | أي مستخدم |
| تصدير سجل الحجوزات إلى Excel / PDF | `TableExportService` ← `FileSaveHelper.exportAndSaveFile` باسم "Freight Booking - Registry" (`:370-440`) | - (في الفرونت) | أي مستخدم |
| أيقونات الصف: نسخ الصف، استنساخ، تأكيد الحجز (BK-01)، تأكيد الإبحار، عرض الإبحار والبوليصة، مراجعة Draft B/L، سجل التدقيق، تعديل، حذف | (`:772-850`) | `POST /{id}/confirm`، `POST /{id}/depart`، `PUT /{id}`، `DELETE /{id}` (soft delete)، `PATCH /{id}/restore` | أي مستخدم |
| حفظ وتأكيد حجز الشحن | يعمل validate للفورم، ولو فيه اختلاف بين الحاويات والتوصية بيطلب سبب، وبعدين يحفظ (`:3174-3185`) | `POST /api/v1/freight-booking` أو `PUT /{id}` | أي مستخدم |
| حفظ مسودة ومتابعة لاحقة | **نفس الفانكشن بالظبط** بتاعة "حفظ وتأكيد" (`:3169` و`:3179`) | نفس الـ endpoint | أي مستخدم |
| تفريغ وبدء تسجيل جديد | يمسح الفورم | - | - |
| إعادة تحميل حية | يعيد جلب القوائم المرجعية | GETs | - |
| إغلاق وتراجع | يقفل الدايلوج | - | - |
| سجل التدقيق (في رأس الدايلوج عند التعديل) | يفتح `RowHistoryDialog` (`:2288-2295`) | audit logs | - |
| X (إغلاق النافذة) | أيقونة قفل الدايلوج في الرأس، الـ tooltip بتاعها "إغلاق النافذة" (`elements/35-freight-booking-dialog-add.json`) | - | - |

### الجداول
جدول سجل الحجوزات (`DataTable`، `:744-755`). في بيانات المراجعة مفيش حجوزات، فالصورة بتعرض رسالة "لا توجد حجوزات شحن مسجلة بالنظام" بس (`35-freight-booking-main.png`).

| العمود | معناه |
|---|---|
| الإجراءات | أيقونات الصف |
| كود الحجز | `booking_code` |
| ملف الاستيراد | كود واسم الملف |
| رقم التأكيد | رقم تأكيد الخط الملاحي |
| الناقل / الوكيل | الخط الملاحي + "وكيل: ..." |
| المسار | POL ← POD |
| السفينة / الرحلة | اسم السفينة ورقم الرحلة |
| المغادرة | ETD / ATD + شارة تأخير `+Nd` |
| الوصول | ETA + موعد الوصول للمخزن |
| الحاويات | ملخص الحاويات |
| إجمالي النولون | إجمالي بنود التكلفة |
| الحالة | Badge، والضغط عليها في حالة Confirmed/Sailed بيفتح دايلوج الإبحار |

- **الفلاتر:** بحث نصي + حالة + ملف استيراد (من الـ query).
- **الترتيب:** حسب رد الباك إند، ومفيش ترتيب بالضغط على الأعمدة.

### التابات
- **Freight Bookings Registry** — `35-freight-booking-tab-1-freight-bookings-registry.png`: السجل والفلاتر وأزرار التصدير (نفس الشاشة الرئيسية).

  ![](../screenshots/35-freight-booking-tab-1-freight-bookings-registry.png)

- **New Booking Request** — `35-freight-booking-tab-2-new-booking-request.png`: بيفتح دايلوج الإنشاء على طول.

  ![](../screenshots/35-freight-booking-tab-2-new-booking-request.png)

- جوه الدايلوج: "1. تفاصيل الحجز وعروض الشحن" (مصوّر) و"2. بنود التكلفة والنولون" (**من غير صورة**، الـ harness مالقاش التاب في الـ semantics tree).

### الـ Dialogs
- **إنشاء / تعديل حجز شحن ملاحي** — `35-freight-booking-dialog-add.png`. الحقول متشرحة فوق. لاحظ إن الفورم بيفتح **مليان بيانات تجريبية** (رقم تأكيد، سفينة، رحلة، إذن إفراج، حاوية `MSCU1234567`، سيل `SL-99001`، وزن 24500، owner "Kamal").

  ![](../screenshots/35-freight-booking-dialog-add.png)

- **أخطاء الـ validation** — `35-freight-booking-dialog-add-validation.png`: الـ harness ضغط "حفظ مسودة" والملف فاضي. **مظهرش أي خطأ أحمر تحت "ملف الشحنة الاستيرادية *"**، والطلب اتبعت للباك إند ورجع `422` (مسجل في `runtime-errors.json` ← `POST /api/v1/freight-booking`)، وظهر SnackBar أحمر بنص الـ exception الخام: `DioException [bad response]: ... original_freight_cost_usd ... Input should be a valid number, input: null`.

  ![](../screenshots/35-freight-booking-dialog-add-validation.png)

- **تحذير حجز مكرر لنفس الملف** (`:1905-2000`): بيعرض بيانات الحجز الموجود، وفيه زرار للتحويل لتعديله.
- **سبب اختلاف الحاويات عن التوصية** (`:1729-1812`): تأكيد، وبعده حقل سبب إلزامي.
- **تأكيد الحجز BK-01** (`_FreightBookingConfirmDialog`)، و**تأكيد الإبحار والبوليصة** (`departure_confirmation_dialog.dart`)، و**مراجعة Draft B/L**، و**عرض / طباعة الحجز**، و**تأكيد الحذف**: مالهمش صور لأن مفيش حجوزات في بيانات المراجعة.

### التصدير والطباعة
- تصدير السجل Excel / PDF عن طريق `TableExportService` ← `FileSaveHelper.exportAndSaveFile`، والاسم `Freight Booking - Registry` (مطابق للقاعدة). على الويب، الحفظ بيستخدم `showSaveFilePicker` أو `<a download>` (فرق خاص بالويب).
- أزرار Excel / PDF / استيراد Excel اللي في شريط "عمليات البيانات" بتنادي endpoints مش موجودة (شوف الملاحظات).
- نسخ TSV للصف وللجدول، ودايلوج طباعة الحجز (`_FreightBookingPrintDialog`).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| High | الحفظ من غير اختيار عرض بيبعت `original_freight_cost_usd: null`، والـ schema مستنية `float`، فبيرجع 422 | `freight_booking_screen.dart:1858`، `modules/freight_booking/schemas.py:57`، `runtime-errors.json` (POST 422)، الصورة `35-freight-booking-dialog-add-validation.png` | ابعت `?? 0.0` أو خلي الحقل `Optional[float]` في الـ schema |
| High | الفورم الجديد بيفتح مليان بيانات تجريبية ثابتة (رقم تأكيد `MSC-CN-889001`، سفينة `MSC Oscar`، رحلة، إذن إفراج، حاوية `MSCU1234567`، سيل، وزن 24500، سعر حاوية 40 = 8500). لو المستخدم محفظش بحرص، البيانات الوهمية دي بتتسجل كحجز حقيقي | `:1284-1325`، `:1208`؛ الصورة `35-freight-booking-dialog-add.png` | الحقول تبدأ فاضية، أو القيم تبقى hint بس |
| High | الشريط العام (إعادة تحميل / تصدير Excel / تصدير PDF / استيراد Excel) بينادي `freight-booking/export-excel` و`export-pdf` و`import-excel`، والـ endpoints دي مش موجودة في الـ router، فالأزرار هتفشل | `freight_booking_screen.dart:538`، `core/widgets/master_data_toolbar.dart:253-278`، `modules/freight_booking/router.py` (مفيش routes دي)، الصورة `35-freight-booking-main.png` | إما تضيف الـ endpoints، أو تمرر `onExportExcel` و`onExportPdf` لـ `TableExportService` وتخفي الاستيراد |
| Medium | "ملف الشحنة الاستيرادية" مكتوب عليه `*` بس مفيش `validator`، فالفورم بيعدّي من غير ملف والطلب بيروح للباك إند (والـ schema بيقبل `import_file_id = null`، `schemas.py:26`) | `freight_booking_screen.dart:2343`؛ الصورة `35-freight-booking-dialog-add-validation.png` (مفيش خطأ تحت الحقل) | أضف `validator: (v) => v == null ? ... : null` |
| Medium | "حفظ مسودة ومتابعة لاحقة" و"حفظ وتأكيد حجز الشحن" بينادوا نفس الفانكشن من غير أي فرق في الحالة، فزرار "تأكيد" مبيأكدش حاجة والمسودة ممكن تتحفظ بحالة Confirmed | `:3169`، `:3179`، `:1828-1860` | خلي المسودة تجبر `status='Draft'` من غير validation كامل، والتأكيد ينادي `/confirm` |
| Medium | قائمة "حالة الحجز" بتسمح تختار Confirmed أو Sailed مباشرة، وده بيتخطى workflow تأكيد الحجز (BK-01) وتأكيد الإبحار والبوليصة | `:2754-2765` | اقصر الحالات اليدوية على Draft و Booking Requested، والباقي من الأزرار المخصصة |
| Medium | الخط الملاحي والوكيل والموانئ بتتخزن كنص (`shipping_line_name` و`pol_name` و`pod_name`) مش FK (`shipping_line_id` و`pol_location_id` موجودين في الـ schema ومش بيتبعتوا). ولو القيمة مش في القائمة بيتختار أول عنصر من غير ما المستخدم ياخد باله | `:1840-1851`، `:2593`، `:2625`، `:2639`، `schemas.py:31-39`؛ الصورة `35-freight-booking-dialog-add.png` (الخط والوكيل الاتنين "Kuehne Line Logistics Egypt") | ابعت الـ IDs وخلي القيمة الابتدائية `null` |
| Medium | Audit trail: `owner` افتراضي "Kamal" في الفرونت والموديل والـ schema، وسجل التدقيق بيتكتب بـ `performed_by=owner or "Kamal"` مش المستخدم الحقيقي. ومفيش `created_by` / `updated_by` في الموديل | `:1292`، `modules/freight_booking/model.py:73`، `schemas.py:62`، `service.py:340`، `service.py:391` | خد المستخدم من `get_current_user` وأضف أعمدة الـ audit بـ Alembic migration |
| Medium | خطأ الباك إند بيظهر للمستخدم كنص `DioException` خام بالإنجليزي | `:1892`؛ الصورة `35-freight-booking-dialog-add-validation.png` | استخرج `detail` واعرض رسالة مترجمة |
| Medium | العملات في بنود التكلفة قائمة ثابتة (USD/EUR/EGP/GBP/CNY) مع إن الشاشة بتجيب `currenciesProvider` (MD-004) | `:2163-2169`، `:77` | استخدم master العملات |
| Medium | أزرار الـ header كتير ومقصوصة: "تكويد وكيل شحن بالذكاء الاصطناعي" ظاهر "ذكاء الاصطناعي" بس | الصورة `35-freight-booking-main.png` (الـ header) | انقل أزرار الـ AI لقائمة overflow أو قصّر الـ labels |
| Medium | مخالفات UI standards: 25 `ElevatedButton` و18 `OutlinedButton` وصفر `AppButton`، و29 `Color(0x...)` و116 `Colors.xxx` (عدّ بـ grep في الملف). وأكشن بار الدايلوج custom بدل `StandardFormActionBar` | `:489`، `:560-625`، `:3119-3185` | استخدم `AppButton` و`AppTheme` و`StandardFormActionBar` |
| Low | عنوان الـ header ("Freight Booking & Carrier Allocation") والتابات الرأسية والـ badge ظاهرين بالإنجليزي في الوضع العربي. ده **الـ bug المعروف** بتاع الـ locale (`supportedLocales` مش متعرّفة، فـ `Directionality`/`localeOf` بيرجعوا en) | الصورة `35-freight-booking-main.png`؛ `core/widgets/vertical_stage_scaffold.dart:76-99` | يتحل مركزياً في `main.dart` |
| Low | badge المرحلة بيقول "Container Allocation" لأن `STEP_07` متشارك مع شاشة الشحن والتحميل (36)، مع إن الشاشة دي حجز | `:474`، `core/services/display_name_resolver.dart:18`؛ الصورة `35-freight-booking-main.png` | اعمل stage code مستقل للحجز |
| Low | شريحة الفلتر بتعرض الـ ID الداخلي "شحنة #ID" بدل كود الملف | `:686-688` | اعرض `import_file_code` |
| Low | الـ tooltip بتاع زرار نسخ الصف هو رسالة النجاح `copyBookingRowSuccess` | `:800-802` | tooltip وصفي زي "نسخ الصف" |
| Low | الـ label بتاع "رقم تأكيد الحجز" متداري جزئياً تحت شريط التابات في الدايلوج | الصورة `35-freight-booking-dialog-add.png` (أعلى يمين الفورم) | زوّد padding أعلى الـ `SingleChildScrollView` |
| Low (Web-only) | `Refused to set unsafe header "Accept-Encoding"` في الكونسول (9 مرات): المتصفح بيمنع الـ header ده، وده مش bug على الديسكتوب | `runtime-errors.json` ← `35-freight-booking` | شيل الـ header على `kIsWeb` |
