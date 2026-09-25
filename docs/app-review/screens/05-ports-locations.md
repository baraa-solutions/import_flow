# الموانئ والمنافذ الجمركية (Ports & Locations)
![](../screenshots/05-ports-locations-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الكود:** `MD-009` Transport Location Master / Ports & Airports (`doc.md` سطر 707 وسطر 920).
- **الغرض:** دليل موحد لكل مواقع النقل: الموانئ البحرية، والمطارات، والموانئ الجافة، والمنافذ البرية، و ICD، ومحطات السكة الحديد. كل موقع ليه كود UN/LOCODE مش بيتكرر. في البيانات التجريبية فيه **264 منفذ** (والعداد تحت مكتوب فيه "1 - 50 / 264").
- **المستخدمين:** كل اللي بيتعاملوا مع ملفات الاستيراد، و ACID، والحجز، وبوالص الشحن، والتتبع، والتخليص.
- **المرحلة:** بيانات مرجعية بتخدم المراحل 1 و3 و4 و5 (ميناء التحميل والوصول).

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar، ادخل "البيانات والجداول الأساسية" وبعدها "الموانئ والمنافذ الجمركية" (index 37).
- **الصلاحية:** أي مستخدم عامل تسجيل دخول. الحماية الوحيدة على الـ router هي `get_current_user` (`modules/transport_locations/router.py:16`).
- **التحميل:** `initState` بيستدعي `fetchLocations()`، وده بيعمل `GET /api/v1/transport-locations`. الصفحات بتتقسم في الـ client، كل صفحة 50 سطر (`transport_locations_screen.dart:31, 304-308`).

## مكونات الشاشة

> **عناصر الإطار المشترك (مش جزء من الشاشة نفسها):** الـ elements JSON فيه عناصر ثابتة في كل الشاشات، ومش بتتشرح هنا بالتفصيل: الـ sidebar (أقسام "البيانات والجداول الأساسية" ومراحل الدورة 1 لـ 6 و"استعلامات" و"لوحة القيادة"، وحقل "بحث سريع..."، وزرار "إخفاء القائمة لتوسيع الشاشة")، والشريط العلوي (Home، وساعات العالم، والأوامر Ctrl+K، ومساعد الاستيراد الذكي، والمستمع الذكي للبريد، وإعدادات البريد IMAP/SMTP، وتبديل اللغة EN، والوضع الداكن، والإعدادات، وكثافة عرض الجدول، ووضع التركيز، ودليل الاختصارات، وملء الشاشة، والإشعارات)، وشريط تبويبات الـ workspace (كل شاشة مفتوحة بتظهر تاب عليه ✕، و⋯ "خيارات النوافذ والتبويبات")، وكارت المستخدم "Review Admin / ADMIN" و"خيارات المستخدم"، والإصدار `v2.0.3 (Build 205)` والبورت. كمان أي dialog في header بتاعه زرار ✕ ("إغلاق النافذة") بيقفل من غير حفظ، والنصوص اللي بتبدأ بـ "مثال: ..." جوه الحقول هي hints بس ومش قيم.

### الحقول

**شريط الأدوات:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث بكود المنفذ، الاسم... (`searchTransportLocationsHint`) | Text (فلترة محلية) | لا | — | القائمة المحملة |
| فلتر النوع ("الكل") | `DropdownButton<String>`، وفيه 5 قيم: All / Sea Port / Airport / Dry Port / Land Border | لا | — | `_locationTypes` (`:33`) |

**Dialog إضافة / تعديل منفذ (`_showLocationDialog`):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| كود المنفذ الدولي (UN/LOCODE) | `TextFormField`، وبيتقفل في التعديل (`enabled: location == null`) | نعم | الفرونت بيتأكد إنه مش فاضي بس (`:690-693`). الباك بيقبل من 3 لـ 10 حروف (`schemas.py:8`)، مع إن المعيار 5 حروف. القيمة بتتحول لـ UPPERCASE قبل الحفظ | `un_locode` |
| نوع المنفذ أو الميناء | `SearchableDropdownField<String>`، وفيه 6 أنواع: Sea Port / Airport / Dry Port / Land Border / ICD / Rail Terminal | نعم | ثابت | `location_type` |
| اسم المنفذ أو الميناء | `TextFormField` | نعم | مش فاضي | `location_name` |
| الدولة | `TextFormField` نص حر | نعم | مش فاضي | `country` (نص) |
| المدينة | `TextFormField` | نعم | مش فاضي | `city` |
| ملاحظات وتفاصيل إضافية | `TextFormField` | لا | — | `notes` |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| إضافة منفذ أو ميناء جديد | بيفتح dialog الإضافة | — | أي مستخدم مسجل |
| إجراءات إضافية ⋮ | Excel (CSV)، و PDF، و TSV، والنموذج، والاستيراد | راجع قسم التصدير | — |
| إعادة تحميل حية 🔄 | `fetchLocations()` | `GET /api/v1/transport-locations` | — |
| تصدير المنافذ (جدول نصوص) | نسخ TSV | — | — |
| العودة للداش بورد | بيرجع للداش بورد | — | — |
| **صف:** نسخ ملخص بيانات المنفذ | بينسخ الملخص | — | — |
| **صف:** 👁 / ✏ / 🖨 / 🗑 | عرض التفاصيل، وتعديل، و PDF بيتولد في الـ client (`printOrSaveLocationPdf`)، وإيقاف أو تفعيل | `PUT .../{id}`، `DELETE .../{id}`، `POST .../{id}/restore` | أي مستخدم مسجل |
| **صف:** شارة الكود (EGRAM...) | نسخ | — | — |
| **Dialog (تعديل):** أيقونة PDF | بتطبع المنفذ | — | — |
| **Dialog:** إضافة المنفذ / حفظ | validate، وبعدها create أو update. الزرار بيعرض spinner (`isSubmitting`، `:811-855`) | `POST /api/v1/transport-locations` / `PUT .../{id}` | أي مستخدم مسجل |
| **Dialog:** إلغاء | بيقفل، وبيتقفل هو نفسه أثناء الحفظ | — | — |
| **Pagination:** الأولى / السابقة / "1 / 6" / التالية / الأخيرة | تنقّل بين الصفحات في الـ client | — | — |

### الجداول

`Table`، والـ header بتاعه غامق:

| العمود | المعنى |
|---|---|
| الإجراءات | أيقونة نسخ الملخص + pill فيه 4 أيقونات |
| كود المنفذ | UN/LOCODE (EGRAM، EGOCT...) + نسخ |
| اسم المنفذ أو الميناء | الاسم |
| النوع | شارة ملونة بأيقونة: ميناء جاف، ميناء بحري، مطار جوي، منفذ بري |
| الدولة | نص |
| المدينة | نص |
| الحالة | نشطة / متوقفة |

تحت الجدول فيه footer بيعرض "1 - 50 / 264"، وأزرار التنقل بين الصفحات. **الترتيب:** أبجدي حسب الاسم، زي ما باين في الصورة.

### التابات

الشاشة مفيهاش تابات.

### الـ Dialogs

**1) إضافة منفذ أو ميناء شحن جديد**
![](../screenshots/05-ports-locations-dialog-add.png)

ده `AlertDialog` بسيط: فيه الكود والنوع، وبعدين الاسم، وبعدين الدولة والمدينة، وبعدين الملاحظات. كل حقل فيه زرار نسخ.

**2) أخطاء الـ validation**
![](../screenshots/05-ports-locations-dialog-add-validation.png)

4 أخطاء، وكلهم "هذا الحقل مطلوب" بالعربي: الكود، والاسم، والدولة، والمدينة. الـ elements فيه نص `Alert`، وده الـ semantics label الافتراضي (Bug الـ locale).

**3) متصورش:** dialog التفاصيل، وتأكيد الإيقاف، ونتيجة الاستيراد.

### التصدير والطباعة

| الإجراء | الطريقة | الملف |
|---|---|---|
| تصدير "Excel" | **CSV بيتولد في الـ client** (`MasterDataExportService.exportLocationsToExcel` ← `FileSaveHelper.saveText`) | `Transport_Locations_<timestamp>.csv` |
| تصدير PDF | `GET /api/v1/transport-locations/export-pdf` ← `saveBytes` | `Transport_Locations_Report.pdf` |
| النموذج | `GET /api/v1/transport-locations/excel-template` | `Transport_Locations_Template.xlsx` |
| استيراد | `FilePicker` (xlsx / xls / csv) ← `POST /api/v1/transport-locations/import-excel`، وبعدها dialog بالنتيجة | — |
| TSV | في الـ client | — |
| طباعة منفذ واحد | `printOrSaveLocationPdf` ← `Printing.layoutPdf` | — |

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | لو الإضافة أو التعديل فشلوا، المستخدم مش بيعرف. `createLocation` و`updateLocation` بيمسكوا الخطأ ويرجعوا `false` وخلاص. فلو كود UN/LOCODE متكرر، والباك رافضه أصلاً (MD-009: "لا يسمح بتكرار UN/LOCODE")، الـ dialog هيفضل مفتوح من غير أي رسالة. | `providers/transport_locations_provider.dart:56-80`؛ `transport_locations_screen.dart:830, 846` | الخطأ يرجع كـ message ويظهر في SnackBar أحمر. |
| Medium | في dialog الإضافة، لما المستخدم يغيّر "نوع المنفذ" مش بيحصل `setDialogState`: الكود فيه `onChanged: (v) => selectedType = v`. و`SearchableDropdownField` بيعرض قيمة `value` اللي جاية من الـ constructor، مش `state.value`. النتيجة إن الحقل **بيفضل عارض "ميناء بحري"** مع إن اللي هيتحفظ هو النوع الجديد. | `transport_locations_screen.dart:713`؛ `core/widgets/searchable_dropdown_field.dart:49-56` | `onChanged: (v) => setDialogState(() => selectedType = v ?? 'Sea Port')`. ويا ريت الـ widget نفسه يعرض `state.value`. |
| Medium | "الدولة" نص حر، و`doc.md` MD-009 بيعرّفها `FK / Lookup`. ده بيسمح بكتابة نفس الدولة بأكتر من شكل ("Cote D Ivoire" / "Côte d'Ivoire")، وده بيبوّظ الفلترة والتقارير. | `05-ports-locations-main.png`؛ `transport_locations_screen.dart:750-756` | جدول دول + `SearchableDropdownField`. |
| Medium | "تصدير Excel" بيطلّع CSV، مش xlsx. وقائمة الامتدادات المسموحة فيها `xlsx`، فلو المستخدم حفظ الملف كـ `.xlsx` هيطلع ملف Excel بايظ. كمان الـ BOM بيتكتب مرتين: مرة في `buffer.write('\uFEFF')` ومرة تانية في `saveText(addUtf8Bom: true)`، فأول عمود بيبدأ بحرف مخفي. | `core/services/master_data_export_service.dart:1573-1601`؛ `core/services/file_save_helper.dart:443` | استخدام `GET /api/v1/transport-locations/export-excel`، وده موجود في الباك (`router.py:109`)، زي باقي الشاشات. |
| Low | اسم ملف التصدير الافتراضي فيه timestamp عشوائي (`Transport_Locations_<millis>.csv`)، وده ضد قاعدة "ممنوع أسماء ملفات عشوائية أو عامة" في CORE_RULES (Task I). | `core/services/master_data_export_service.dart:1594` | اسم ثابت مفهوم زي `Transport_Locations_Report.xlsx`، زي باقي الشاشات. |
| Low | فلتر النوع مفيهوش ICD ولا Rail Terminal، مع إن الـ dialog بيسمح بيهم، فمينفعش تفلتر عليهم. | `transport_locations_screen.dart:33` مقارنة بـ `:702-707` | القائمتين يبقوا من مصدر واحد. |
| Low | UN/LOCODE مفيش عليه تحقق من الصيغة (المعيار: حرفين للدولة + 3 للموقع = 5). الباك بيقبل من 3 لـ 10. | `transport_locations_screen.dart:690-693`؛ `modules/transport_locations/schemas.py:8` | regex `^[A-Z]{2}[A-Z0-9]{3}$`. |
| Low | مفيش RBAC على الكتابة. | `modules/transport_locations/router.py:16` | `require_permission("master_data.edit")`. |
| Low | مخالفات المعايير: `ElevatedButton` و`TextButton`، و`DropdownButton` خام في الفلتر، ونصوص عربي مكتوبة في الكود لعناوين الحفظ. | `transport_locations_screen.dart:155-156, 188, 201, 232-233, 803-810` | `AppButton`، و l10n. |
| Low | Bug الـ locale المعروف: الـ `AlertDialog` بيطلع semantics label إنجليزي (`Alert`). | `elements/05-ports-locations-dialog-add.json` | `supportedLocales`. |
| Low (Web-only) | الـ console فيه `Refused to set unsafe header "Accept-Encoding"` مرة واحدة. | `runtime-errors.json` → `05-ports-locations`؛ `core/network/api_client.dart:27` | الـ header ميتبعتش لما يكون `kIsWeb`. |

> **حاجة كويسة:** الشاشة فيها pagination وعداد إجمالي ("1 - 50 / 264")، زي شاشة العملات (09)، والجدول بيبان من غير overflow على 1600px.
