# مشاريع الاستيراد ومراكز التكلفة (Projects & Cost Centers)
![](../screenshots/04-projects-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الكود:** `MD-007` Projects (`doc.md` سطر 790). في جدول الحالة في `doc.md` (سطر 4344) مكتوب كمان `PRJ-001`.
- **الغرض:** المشروع هو نقطة البداية لأي عملية استيراد. بيربط شركة مستوردة أو أكتر، ومورد رئيسي، و Incoterm افتراضي، ونوع الاستيراد، والأولوية، وأنواع الشحنات المسموح بيها، والميزانية التقديرية بالدولار، وتاريخ الانتهاء المستهدف. وبيعرض الالتزامات والمتبقي من الميزانية (مركز تكلفة).
- **المستخدمين:** مدير الاستيراد ومدير المشروع والمالية.
- **المرحلة:** قبل المرحلة 1 (التخطيط). ملفات الاستيراد وأوامر الشراء بتتسجل تحت المشروع.

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar، افتح "البيانات والجداول الأساسية" واختار "المشاريع ومراكز التكلفة" (index 31).
- **الصلاحية:** أي مستخدم مسجل. الـ router فيه `get_current_user` بس (`modules/projects/router.py:11`)، ومفيش RBAC.
- **التحميل:** `initState` بعد أول frame بيحمّل المشاريع والشركات والموردين والـ Incoterms (`projects_screen.dart:35-54`) بالطلبات دي: `GET /api/v1/projects` و`/import-companies` و`/suppliers` و`/incoterms`.

## مكونات الشاشة

> **عناصر الإطار المشترك (مش جزء من الشاشة نفسها):** الـ elements JSON فيه عناصر ثابتة في كل الشاشات، ومش بتتشرح هنا بالتفصيل: الـ sidebar (أقسام "البيانات والجداول الأساسية" ومراحل الدورة 1 لـ 6 و"استعلامات" و"لوحة القيادة"، وحقل "بحث سريع..."، وزرار "إخفاء القائمة لتوسيع الشاشة")، والشريط العلوي (Home، وساعات العالم، والأوامر Ctrl+K، ومساعد الاستيراد الذكي، والمستمع الذكي للبريد، وإعدادات البريد IMAP/SMTP، وتبديل اللغة EN، والوضع الداكن، والإعدادات، وكثافة عرض الجدول، ووضع التركيز، ودليل الاختصارات، وملء الشاشة، والإشعارات)، وشريط تبويبات الـ workspace (كل شاشة مفتوحة بتظهر تاب عليه ✕، و⋯ "خيارات النوافذ والتبويبات")، وكارت المستخدم "Review Admin / ADMIN" و"خيارات المستخدم"، والإصدار `v2.0.3 (Build 205)` والبورت. كمان أي dialog في header بتاعه زرار ✕ ("إغلاق النافذة") بيقفل من غير حفظ، والنصوص اللي بتبدأ بـ "مثال: ..." جوه الحقول هي hints بس ومش قيم.

### الحقول

**شريط الأدوات:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث بكود المشروع، الاسم، المسؤول... | Text (فلترة محلية) | لا | — | القائمة المحملة |
| فلتر الحالة ("جميع الحالات" / مفتوح / مغلق / معلق) | Dropdown (4 قيم ثابتة) | لا | — | `_statuses` (`:32`) |

**Dialog إنشاء / تعديل مشروع (`_showProjectDialog`):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اسم المشروع | `TextFormField` | نعم | مش فاضي (`:936`) | `project_name` |
| مدير أو مسؤول المشروع | `TextFormField` | نعم | مش فاضي (`:950`) | `project_owner` (نص حر، مش FK لمستخدم) |
| الشركات المستوردة للمشروع | `FilterChip` متعدد | نعم (≥ 1) | SnackBar لو القائمة فاضية (`:1239-1243`) | `/import-companies` → `company_ids` + `company_id` = أول شركة |
| المورد الرئيسي | `SearchableDropdownField<int?>` | نعم | **أول مورد بيتختار لوحده** (`:889`) | `/suppliers` → `supplier_id` |
| شرط الشحن الدولي الافتراضي | `SearchableDropdownField<int?>` | نعم | **أول Incoterm بيتختار لوحده** (`:890`) | `/incoterms` → `incoterm_id` |
| نوع الاستيراد | `SearchableDropdownField<String>` (تجاري مباشر / منطقة حرة / سماح مؤقت / دروباك / معدات مشروعات) | نعم | ثابت | `import_type` |
| مستوى الأولوية | `SearchableDropdownField<String>` (Low / Medium / High / Urgent) | نعم | ثابت | `priority` |
| حالة المشروع | `SearchableDropdownField<String>` (Open / Closed / On Hold) | نعم | ثابت | `status`. **بيتبعت في التعديل بس، في الإنشاء لأ** (`:1259-1275`) |
| أنواع الشحنات المتاحة للمشروع | `FilterChip` متعدد (حاوية كاملة، شحن بحري مجزأ، جوي، صب، متعدد الوسائط) | نعم (≥ 1) | مينفعش تلغي آخر واحد | `shipment_category` (نص مفصول بفواصل، `:1255`) |
| الميزانية التقديرية بالدولار | `TextFormField` رقمي | لا | **مفيش validator**. أي نص مش رقم بيتحول لـ `null` من غير ما حد يعرف (`:1254`) | `total_budget_usd` |
| تاريخ الانتهاء المستهدف | `TextFormField` readOnly + `showDatePicker` | لا | 2020 لـ 2040 | `target_end_date` |
| السماح بالشحن على دفعات متتابعة | `CheckboxListTile` (القيمة الافتراضية ✓) | لا | — | `allow_multi_shipment` |
| السماح بتعدد الكيانات والشركات | `CheckboxListTile` (القيمة الافتراضية ✓) | لا | — | `allow_multi_company` |
| ملاحظات ووصف المشروع | `TextFormField` سطرين | لا | — | `notes` |

> كود المشروع (`PRJ-YYYY-NNN`) بيتولد في الباك إند. الفرونت بيبعت `projectCode: ''` (`:1260`).

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| إنشاء مشروع جديد | بيفتح dialog الإنشاء | — | أي مستخدم مسجل |
| إجراءات إضافية ⋮ | Excel، و PDF، و TSV، والنموذج، والاستيراد | راجع قسم التصدير | — |
| إعادة تحميل حية 🔄 | `fetchProjects()` | `GET /api/v1/projects` | — |
| تصدير المشاريع (جدول) | نسخ TSV | — | — |
| العودة للداش بورد | بيرجع للوحة التحكم | — | — |
| **صف:** 👁 "عرض التفاصيل" | **بيفتح `RowHistoryDialog`** (سجل التعديلات)، ومش بيفتح تفاصيل المشروع (`:560-569`) | `/api/v1/audit-logs/...` | — |
| **صف:** ✏ تعديل السجل | dialog التعديل | `PUT /api/v1/projects/{id}` | أي مستخدم مسجل |
| **صف:** 🖨 (tooltip "نسخ ملخص المشروع") | **بينسخ الملخص للحافظة، ومش بيطبع** (`:571-575`) | — | — |
| **صف:** 🗑 إيقاف / تفعيل | تأكيد، وبعدها soft delete أو restore | `DELETE /api/v1/projects/{id}` / `POST /api/v1/projects/{id}/restore` | أي مستخدم مسجل |
| **صف:** كود المشروع | نسخ (`CopyableText`) | — | — |
| **Dialog:** إنشاء المشروع / حفظ التغييرات | validate، وبعدها create أو update، مع spinner (`isSubmitting`) | `POST /api/v1/projects` / `PUT .../{id}` | أي مستخدم مسجل |
| **Dialog:** إلغاء | `TextButton` بيقفل الـ dialog | — | — |

### الجداول

`Table` بـ header غامق فيه 8 أعمدة:

| العمود | المعنى |
|---|---|
| الإجراءات | pill فيه 4 أيقونات (👁 ✏ 🖨 🗑)، وعرضه 170px |
| كود المشروع | `PRJ-2026-00X`. **عرضه 120px، والكود بيتقص ("PRJ-2026-0...")** |
| اسم المشروع والمسؤول | الاسم (بيتقص) + "المسؤول: ..." |
| الشركة المستوردة والمورد | الشركة + "المورد: ..." |
| النوع والتصنيف | نوع الاستيراد + التصنيف (Incoterm) |
| الميزانية بالدولار | الميزانية + الالتزامات + المتبقي + التاريخ المستهدف |
| المحددات والمزايا | شارتين: "متعدد الشحنات" و"متعدد الشركات" |
| الحالة | مفتوح / مغلق / معلق |

**الفلترة:** بحث + حالة. **الترتيب:** حسب الكود تنازلي زي ما باين في الصورة.

### التابات

الشاشة مفيهاش تابات.

### الـ Dialogs

**1) إنشاء مشروع استيراد جديد**
![](../screenshots/04-projects-dialog-add.png)

ده `AlertDialog` عادي. شكله مختلف عن باقي dialogs المجموعة: مفيهوش banner غامق، وزرار "إلغاء" نص بس. أول شركة متعلّمة لوحدها، والمورد "Shenzhen Brightway"، والـ Incoterm "CFR"، ونوع الشحنة "حاوية كاملة"، وكمان الـ checkboxes التانيين متعلّمين.

**2) أخطاء الـ validation**
![](../screenshots/04-projects-dialog-add-validation.png)

حقلين بس ظهر فيهم "هذا الحقل مطلوب" (الاسم والمسؤول). الرسالة هنا عربي سليم لأنها جاية من `l10n.requiredField`، ومش من `CustomTextField`. الـ elements JSON فيه نص `Alert`، وده الـ semantics label الافتراضي بتاع `AlertDialog` بالإنجليزي (Bug الـ locale المعروف).

**3) متصورش:** `RowHistoryDialog`، وتأكيد الإيقاف، و date picker.

### التصدير والطباعة

| الإجراء | الطريقة | الملف |
|---|---|---|
| تصدير Excel | `GET /api/v1/projects/export-excel` | `Projects_CostCenters_Report.xlsx` |
| تصدير PDF | `GET /api/v1/projects/export-pdf` | `Projects_CostCenters_Report.pdf` |
| النموذج | `GET /api/v1/projects/excel-template` | `Projects_CostCenters_Template.xlsx` |
| استيراد | `POST /api/v1/projects/import-excel` | — |
| TSV | في الـ client | — |
| طباعة مشروع واحد | **مش موجودة.** أيقونة 🖨 بتنسخ ملخص للحافظة بس | — |

> **مهم:** الـ endpoints التلاتة (Excel و PDF والنموذج) **مش شغالة**. شوف أول ملاحظة.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | تصدير Excel وتصدير PDF وتنزيل النموذج **هيفشلوا دايماً**. السبب إن `GET /{project_id}` (من نوع `int`) متعرف في الـ router **قبل** `/excel-template` و`/export-excel` و`/export-pdf`، فأي طلب زي `/api/v1/projects/export-excel` بيروح لـ `get_project_by_id` ويرجع 422. اتأكدت من ده بفحص الـ routes بـ Starlette `route.matches()`: التلاتة بيتطابقوا مع `/api/v1/projects/{project_id}`. | `modules/projects/router.py:33` (route الـ ID) قبل `:95, 152, 177`؛ `projects_screen.dart:308-341` | نقل الـ routes الثابتة فوق `/{project_id}`، أو استخدام `/{project_id:int}`. ويتضاف test تكامل للتصدير. |
| High | فشل الإنشاء أو التعديل **مش بيظهر للمستخدم خالص**. `createProject` و`updateProject` بيمسكوا أي exception ويرجعوا `false`، والـ dialog بيفضل مفتوح من غير أي رسالة، فالمستخدم مش هيعرف سبب رفض الباك إند (زي الكود المتكرر أو FK مش نشط). | `providers/projects_provider.dart:61-85`؛ `projects_screen.dart:1276-1277, 1296-1299` | رجوع رسالة الخطأ (`String?`) وعرضها SnackBar أحمر، زي شاشة الشركات. |
| Medium | كود المشروع (الـ Business Code الأساسي) بيتقص لـ "PRJ-2026-0..." في كل الصفوف، فالمستخدم مش شايف الكود الكامل. | `04-projects-main.png`؛ `projects_screen.dart:498` (`FixedColumnWidth(120)`) | توسيع العمود لحوالي 140px أو تصغير الخط. |
| Medium | أيقونة 👁 "عرض التفاصيل" بتفتح سجل التعديلات، وأيقونة 🖨 بتنسخ للحافظة. الأيقونات والـ tooltips مش بتعمل اللي مكتوب عليها، ومفيش طباعة PDF لمشروع واحد زي باقي الشاشات. | `04-projects-main.png`؛ `elements/04-projects-main.json` ("عرض التفاصيل"، "نسخ ملخص المشروع")؛ `projects_screen.dart:560-575` | 👁 تفتح dialog تفاصيل، والسجل يبقى في قائمة كليك يمين، و 🖨 تعمل PDF فعلاً أو أيقونتها تبقى copy. |
| Medium | "حالة المشروع" ظاهرة في dialog الإنشاء لكن قيمتها مش بتتبعت. `ProjectModel` في الإنشاء مفيهوش `status`، فلو المستخدم اختار "معلق" المشروع هيتسجل بالحالة الافتراضية بتاعة الباك. | `04-projects-dialog-add.png` (حقل "حالة المشروع *")؛ `projects_screen.dart:1259-1275` مقابل `:1293` | إرسال `status` في الإنشاء، أو إخفاء الحقل في وضع الإنشاء. |
| Medium | المورد والـ Incoterm والشركة بيتختاروا لوحدهم (أول عنصر في كل قائمة)، فالمشروع ممكن يتسجل بمورد غلط من غير ما المستخدم ياخد باله. ده بيخالف روح `doc.md` MD-007 ("لا يمكن إنشاء مشروع بدون Company وSupplier"، والمقصود اختيار واعي). | `04-projects-dialog-add.png`؛ `projects_screen.dart:885-890` | تبدأ فاضية ويبقى عليها validator إلزامي. |
| Medium | الميزانية مفيهاش validator. قيمة زي "100,000" أو "abc" بتتحول لـ `null` من غير أي تنبيه، فالمشروع بيتسجل من غير ميزانية. | `projects_screen.dart:1136-1148, 1254` | validator رقمي، و `inputFormatters`. |
| Medium | مفيش RBAC على إنشاء المشروع أو تعديله أو إيقافه (المشروع فيه ميزانية). | `modules/projects/router.py:11` | `require_permission(...)`. |
| Low | المبالغ معروضة من غير فاصل آلاف وبصيغة مش ثابتة (`$95000.00` و`62000.00$`)، ونصوص "الالتزامات" و"المتبقي" عربي مكتوب في الكود مباشرة. | `04-projects-main.png`؛ `projects_screen.dart:546, 721, 726` | `NumberFormat.currency` + l10n. |
| Low | شكل dialog المشروع (`AlertDialog` + `TextButton`) مختلف عن باقي dialogs البيانات المرجعية (banner charcoal + أزرار مخصصة)، ومفيش `StandardFormActionBar`. | `04-projects-dialog-add.png` مقارنة بـ `01-import-companies-dialog-add.png`؛ `projects_screen.dart:913, 1228-1234` | توحيد الـ dialog shell. |
| Low | "مدير أو مسؤول المشروع" نص حر ومش مربوط بجدول المستخدمين. | `projects_screen.dart:950` | `SearchableDropdownField` من `/users`. |
| Low | أنواع الشحنات بتتخزن نص مفصول بفواصل، مش lookup (زي ما `doc.md` بيقول: `Shipment Category ID FK`). | `projects_screen.dart:1255`؛ `doc.md` (MD-007 Main Fields) | جدول lookup + علاقة. |
| Low | Bug الـ locale المعروف ظاهر هنا في الـ semantics label `Alert` (إنجليزي) بتاع الـ dialog، وهيظهر كمان في `showDatePicker`. | `elements/04-projects-dialog-add.json` (نص "Alert")؛ `projects_screen.dart:1171` | `supportedLocales` في `MaterialApp`. |
| Low | مخالفات المعايير: `ElevatedButton` و`TextButton` بدل `AppButton`، و`Colors.grey.shade50` و`Colors.white`، ونصوص عربي مكتوبة في الكود لعناوين الحفظ. | `projects_screen.dart:286-287, 315, 325, 340, 1097, 1229-1234` | `AppButton`، `AppTheme`، l10n. |
| Low (Web-only) | `Refused to set unsafe header "Accept-Encoding"` ظهرت 4 مرات. | `runtime-errors.json` → `04-projects`؛ `core/network/api_client.dart:27` | الـ header ميتحطش لما يكون `kIsWeb`. |
