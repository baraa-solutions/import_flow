# الشركاء ومقدمو الخدمات الخارجية (Partners & Banks)
![](../screenshots/03-partners-banks-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الأكواد:** `MD-003` External Service Providers (`doc.md` سطر 414)، ومعاه `MD-004` Shipping Lines و`MD-024` Carrier Master، لأنهم اتدمجوا في نفس الجدول (`doc.md` سطر 4339: "دمج شامل"). ملاحظة: `MD-004` في `doc.md` معناه Shipping Lines، لكن في `docs/01_master_data.md` معناه Currencies، فيه تعارض في الترقيم بين الملفين.
- **الغرض:** جدول واحد لكل الجهات الخارجية: البنوك (SWIFT)، والخطوط الملاحية (SCAC و Free Days وموقع التتبع)، والمخلصين الجمركيين (رقم الترخيص والموانئ المعتمدة)، ووكلاء الشحن (FIATA وطرق الشحن)، والنقل البري (الترخيص والأسطول ومناطق التغطية)، وهيئات الفحص (رقم الاعتماد ونطاق الفحص)، وشركات التأمين (الترخيص وأنواع التغطية).
- **المستخدمين:** إدارة الاستيراد والمشتريات والمالية. الجدول ده هو المرجع لاختيار الـ Forwarder والمخلص في الشحنة، ولطلبات عروض الأسعار، وكشف الحساب، وتقييم الأداء.
- **المرحلة:** بيانات مرجعية، وبتخدم المراحل 3 (الحجز) و5 (الميناء والتخليص) والتسوية المالية.

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar افتح "البيانات والجداول الأساسية"، واختار "الشركاء والبنوك ومقدمو الخدمات" (index 34).
- **الصلاحية:** أي مستخدم مسجل. على الـ router فيه `get_current_user` بس (`modules/external_service_providers/router.py:12-16`)، ومفيش RBAC.
- **التحميل:** `initState` بيعمل refresh للـ provider (`partners_screen.dart:238`)، وده بيبعت `GET /api/v1/external-service-providers`.

## مكونات الشاشة

> **عناصر الإطار المشترك (مش جزء من الشاشة نفسها):** الـ elements JSON فيه عناصر ثابتة في كل الشاشات، ومش بتتشرح هنا بالتفصيل: الـ sidebar (أقسام "البيانات والجداول الأساسية" ومراحل الدورة 1 لـ 6 و"استعلامات" و"لوحة القيادة"، وحقل "بحث سريع..."، وزرار "إخفاء القائمة لتوسيع الشاشة")، والشريط العلوي (Home، وساعات العالم، والأوامر Ctrl+K، ومساعد الاستيراد الذكي، والمستمع الذكي للبريد، وإعدادات البريد IMAP/SMTP، وتبديل اللغة EN، والوضع الداكن، والإعدادات، وكثافة عرض الجدول، ووضع التركيز، ودليل الاختصارات، وملء الشاشة، والإشعارات)، وشريط تبويبات الـ workspace (كل شاشة مفتوحة بتظهر تاب عليه ✕، و⋯ "خيارات النوافذ والتبويبات")، وكارت المستخدم "Review Admin / ADMIN" و"خيارات المستخدم"، والإصدار `v2.0.3 (Build 205)` والبورت. كمان أي dialog في header بتاعه زرار ✕ ("إغلاق النافذة") بيقفل من غير حفظ، والنصوص اللي بتبدأ بـ "مثال: ..." جوه الحقول هي hints بس ومش قيم.

### الحقول

**شريط الأدوات:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث باسم الشريك، الكود، كود السويفت، رقم الترخيص، البطاقة الضريبية، أو الدولة... | Text (فلترة محلية) | لا | الاسم، والكود، و SWIFT، وترخيص التخليص، و `taxId`، والدولة (`:511-516`) | القائمة المحملة |
| فلتر التصنيف ("الكل") | `DropdownButton<String>` (8 قيم ثابتة) | لا | — | `selectedPartnerCategoryProvider` |
| عرض المتوقفين | Switch | لا | — | `showInactivePartnersProvider` |

**Dialog إضافة / تعديل شريك (`_showPartnerDialog`).** الحقول بتظهر وتختفي حسب التصنيفات اللي اتختارت:

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| تصنيفات الشريك (بنك، خط ملاحي، مخلص جمركي، وكيل شحن، نقل بري، هيئة فحص ومعاينة، شركة تأمين) | `FilterChip` متعدد الاختيار | نعم (≥ 1) | مينفعش تلغي آخر chip متعلّم (`:1461-1466`) | بيتحفظ كنص مفصول بفاصلة في `partner_type` (`:1965`) |
| اسم الشريك أو الشركة | Text | نعم | مش فاضي | `partner_name` |
| **لو مخلص جمركي:** رقم ترخيص مزاولة التخليص الجمركي | Text | نعم | مش فاضي | `clearance_license_number` |
| **لو مخلص جمركي:** الموانئ والمنافذ الجمركية المعتمدة | Text حر | لا | — | `authorized_ports` (نص، مش FK لجدول الموانئ MD-009) |
| **لو خط ملاحي:** SCAC، وفترة السماح الافتراضية (Free Days)، ورابط التتبع | Text / Number | Free Days إلزامي | رقم صحيح ≥ 0 (`:1571-1576`) | `scac_code`, `default_free_days`, `tracking_url` |
| **لو وكيل شحن:** FIATA، وطرق الشحن، والعملات المدعومة | Text | حسب الكود | — | `fiata_id`, `shipping_modes`, `supported_currencies` |
| **لو بنك:** SWIFT، وبيانات الحساب | Text | حسب الكود | مفيش تحقق من صيغة SWIFT | `swift_code`, ... |
| **لو نقل بري:** رقم الترخيص، وأنواع الأسطول، ومناطق التغطية | Text | الترخيص إلزامي | — | `transport_license_number`, `fleet_types`, `coverage_areas` |
| **لو هيئة فحص:** رقم الاعتماد، ونطاق الفحص | Text | الاعتماد إلزامي (`:1710`) | — | `inspection_accreditation_number`, `inspection_scope` |
| **لو تأمين:** رقم الترخيص، وأنواع التغطية | Text | نعم (`:1789, 1798`) | — | `insurance_license_number`, `insurance_coverage_types` |
| رقم التسجيل الضريبي / رقم السجل التجاري | Text | لا | — | `tax_id`, `commercial_register` |
| البريد الإلكتروني الرئيسي / الإضافي | Text | لا | **مفيش تحقق من الصيغة** (`schemas.py:38-39` بيتحقق من الطول بس) | `email`, `secondary_email` |
| رقم الهاتف / المحمول / الفاكس / الموقع الإلكتروني | Text | لا | — | ... |
| العنوان | Text | لا | — | `address` |
| الدولة | Text حر (القيمة الافتراضية `Egypt`) | نعم | مش فاضي | `country` (نص) |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| إضافة شريك خارجي جديد | بيفتح dialog الإضافة | — | أي مستخدم مسجل |
| تكويد شريك بالذكاء الاصطناعي ✨ | بيفتح extractor مخصص حسب التصنيف المختار في الفلتر (بنك، أو خط ملاحي، أو مخلص، إلخ) (`:180-235`) | `/api/v1/smart-upload/...`، وبعده `POST /api/v1/external-service-providers` | أي مستخدم مسجل |
| إجراءات إضافية ⋮ | Excel، و PDF، و TSV، والنموذج، والاستيراد | راجع قسم التصدير | — |
| إعادة تحميل حية 🔄 | refresh للقائمة | `GET /api/v1/external-service-providers` | — |
| تصدير الشركاء (جدول بيانات) 📊 | نسخ TSV | — | — |
| العودة للداش بورد | بيرجع للوحة التحكم | — | — |
| **صف:** كشف حساب | `PartnerStatementOfAccountDialog`: الأرصدة بالعملات | `GET /api/v1/external-service-providers/{id}/statement-of-account` | — |
| **صف:** تقييم الأداء | `PartnerScorecardDialog` | `GET /api/v1/external-service-providers/{id}/scorecard` | — |
| **صف:** نسخ ملخص الشريك | بينسخ ملخص للحافظة | — | — |
| **صف:** عرض 👁 / تعديل ✏ / طباعة 🖨 / إيقاف 🗑 | التفاصيل، أو التعديل وبعده مقارنة التغييرات، أو PDF في الـ client، أو soft delete و restore | `PUT .../{id}`، `DELETE .../{id}`، `PATCH .../{id}/restore` | أي مستخدم مسجل |
| **صف:** كود الشريك `ESP-0000xx` | بينسخ الكود | — | — |
| **Dialog:** حفظ بيانات الشريك | validate، وبعدها create أو update. فيه loading ("جاري الحفظ...")، وزرار الإلغاء بيتقفل أثناء الحفظ (`:1945-1961`) | `POST` / `PUT` | أي مستخدم مسجل |

### الجداول

دي الشاشة الوحيدة في المجموعة اللي فيها **جدول حقيقي** (`Table`)، وليه header غامق. عرضه الأدنى 1350px (`:526`)، وفيه scroll أفقي ورأسي.

| العمود | المعنى |
|---|---|
| الإجراءات | 3 أزرار نصية (كشف حساب، وتقييم الأداء، ونسخ ملخص) + الـ pill بتاع العرض والتعديل والطباعة والإيقاف |
| الكود | `ESP-XXXXXX` + زرار نسخ |
| اسم الشريك والتصنيف | الاسم (بيتقص بـ "...") + شارة ملونة لكل تصنيف |
| بيانات القيد والترخيص | حاجات بتختلف حسب النوع: فترة السماح، والترخيص، والاعتماد، و FIATA، والموانئ، والأسطول، والتغطية، و SWIFT، والدولة |
| بيانات التواصل | الإيميل والهاتف، أو "لا يوجد بريد" / "لا يوجد هاتف" |
| الحالة | نشطة / متوقفة |

**الفلترة:** بحث + تصنيف + المتوقفين. **الترتيب:** حسب الـ ID تنازلي زي ما باين (ESP-000042 في الأول). مفيش ترتيب بالضغط على عنوان العمود.

### التابات

الشاشة مفيهاش تابات.

### الـ Dialogs

**1) إضافة شريك خارجي وبنك جديد**
![](../screenshots/03-partners-banks-dialog-add.png)

فوق فيه chips التصنيفات، و"مخلص جمركي" متعلّم لوحده من الأول. تحتها الاسم، وبعده بلوك برتقالي "🛂 ترخيص التخليص الجمركي والموانئ المعتمدة" (بيظهر عشان التصنيف مخلص)، وبعدين الضريبي والسجل التجاري، والإيميلات، والتليفونات، والموقع، والعنوان، والدولة.

**2) أخطاء الـ validation**
![](../screenshots/03-partners-banks-dialog-add-validation.png)

خطأين: "اسم الشريك أو الشركة * is required"، و"رقم ترخيص مزاولة التخليص الجمركي * is required". حقل الدولة مظهرش فيه خطأ لأن قيمته الافتراضية `Egypt`.

**3) Dialogs متصورتش:** `PartnerDetailsDialog`، و`PartnerStatementOfAccountDialog`، و`PartnerScorecardDialog`، و`UniversalEntityExtractorDialog`، و`RowHistoryDialog`، ومقارنة التغييرات، وتأكيد الإيقاف.

### التصدير والطباعة

| الإجراء | الطريقة | الملف الافتراضي |
|---|---|---|
| تصدير Excel | `GET /api/v1/external-service-providers/export-excel` ← `FileSaveHelper.saveBytes` | `Partners_Banks_Report.xlsx` |
| تصدير PDF | `GET .../export-pdf` | `Partners_Banks_Report.pdf` |
| النموذج | `GET .../excel-template` | `Partners_Banks_Template.xlsx` |
| استيراد | `POST .../import-excel` | — |
| TSV | في الـ client | — |
| طباعة شريك واحد | `MasterDataExportService.printOrSavePartnerPdf` ← `Printing.layoutPdf` | — |

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | عمود "الحالة" بيتقص على الحافة اليمين عند عرض 1600px (شارة "نشطة" باينة نصها)، والمستخدم لازم يعمل scroll أفقي عشان يشوف الحالة. السبب إن عمود الإجراءات عرضه ثابت 480px. | `03-partners-banks-main.png` (العمود الأخير)؛ `partners_screen.dart:526, 552-559` | تصغير عمود الإجراءات (الأزرار النصية التلاتة تبقى أيقونات أو في قائمة ⋮)، وتثبيت عمود الحالة. |
| Medium | شارة "14 يوم سماح" ظاهرة لكل الشركاء (هيئة الفحص، والتأمين، والنقل البري، والمخلصين)، مع إن Free Days خاصة بالخطوط الملاحية بس. السبب إن الـ schema والـ model بيحطوا `default_free_days = 14` لأي شريك، والفرونت بيعرضها لما القيمة تبقى `!= null`. | `03-partners-banks-main.png`؛ `modules/external_service_providers/schemas.py:18`؛ `model.py:41`؛ `partners_screen.dart:874-884` | القيمة الافتراضية تبقى `None`، وتتملى بس لما التصنيف يكون Shipping Line، والشارة تظهر للخطوط الملاحية بس. |
| Medium | التصنيف بيتحفظ كنص مفصول بفواصل (`"Customs Broker, Freight Forwarder"`) في `partner_type`، مش Lookup table زي ما `doc.md` (MD-003 Notes for Developer) طالب. وفيه قيم جاية من البيانات مش معروفة للفرونت، زي "Insurance"، بتظهر خام بالإنجليزي في الشارة. | `03-partners-banks-main.png` (شارة "Insurance" لمصر للتأمين)؛ `partners_screen.dart:44-65, 1965`؛ `model.py:23` | جدول `partner_types` + جدول ربط many-to-many، و migration للقيم الحالية. |
| Medium | SWIFT وبيانات البنك مش داخلين في dialog مقارنة التغييرات. الـ diff بيغطي الترخيص والتواصل والدولة بس، فتعديل SWIFT بنك بيعدّي من غير تأكيد. | `partners_screen.dart:2006-2045` (مفيش `swiftCode`) | إضافة حقول البنك لقائمة `changes`. |
| Medium | مفيش تحقق من صيغة الإيميل ولا SWIFT، و`doc.md` MD-003 بيطلب تحقق الإيميل صراحة. | `modules/external_service_providers/schemas.py:29, 38-39`؛ `03-partners-banks-dialog-add.png` | `EmailStr` و regex لـ SWIFT (8 أو 11 حرف). |
| Medium | "الموانئ المعتمدة" للمخلص و"الدولة" نصوص حرة، مع إن جدول الموانئ `MD-009` موجود. ده مخالف لقاعدة FK و`SearchableDropdownField`. | `03-partners-banks-dialog-add.png`؛ `partners_screen.dart:1344, 1915-1919` | multi-select من `transport_locations` واختيار الدولة من جدول. |
| Medium | مفيش RBAC على الكتابة. أي مستخدم يقدر يعدّل SWIFT بنك أو يوقف مخلص. | `modules/external_service_providers/router.py:12-16` | `require_permission("master_data.edit")`. |
| Low | فلتر التصنيف معمول بـ `DropdownButton` خام، مش `SearchableDropdownField`. القائمة ثابتة وصغيرة (8 قيم) فمقبولة وظيفياً، لكنها مش ماشية على شكل المكوّن الموحد. | `03-partners-banks-main.png` (فلتر "الكل")؛ `partners_screen.dart:391-409` | اختياري: توحيد المكوّن. |
| Low | اختيار "مخلص جمركي" بيحصل لوحده في dialog الإضافة، فممكن يتسجل بنك بتصنيف مخلص لو المستخدم مخدش باله. | `elements/03-partners-banks-dialog-add.json` (checkbox "مخلص جمركي" checked=true)؛ `03-partners-banks-dialog-add.png` | يبدأ من غير اختيار (أو ياخد تصنيف الفلتر الحالي)، ويبقى required بـ validator ظاهر. |
| Low | رسائل الـ validation مختلطة (`... * is required`)، ونجمتين في الـ label. | `03-partners-banks-dialog-add-validation.png`؛ `core/widgets/custom_text_field.dart:34, 57-61` | نفس اقتراح شاشة 01. |
| Low | أسماء الشركاء بتتقص ("Cairo Pre-Shipment Inspect...") رغم إن فيه مساحة فاضية في عمود الكود. | `03-partners-banks-main.png` | إعادة توزيع عرض الأعمدة. |
| Low | مخالفات المعايير: `ElevatedButton` و`OutlinedButton` و`Colors.amber.shade800` و`Colors.black26`، ونصوص عربي مكتوبة في الكود لعناوين الحفظ، و emoji (🛂، 📊) جوه نصوص الواجهة. | `partners_screen.dart:285-301, 331, 341, 356, 396, 659, 1940-1950` | `AppButton` و`AppTheme` و l10n. |
| Low | زرار الإلغاء عليه ✕ مرتين. | `03-partners-banks-dialog-add-validation.png`؛ `partners_screen.dart:1940-1948` | شيل ✕ من النص. |
| Low (Web-only) | `Refused to set unsafe header "Accept-Encoding"` ظهرت مرتين في الـ console. | `runtime-errors.json` → `03-partners-banks`؛ `core/network/api_client.dart:27` | الـ header ميتحطش لما يكون `kIsWeb`. |
