# العملات وأسعار الصرف (Currencies & Rates)
![](../screenshots/09-currencies-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الكود:** العملة ليها كود مختلف حسب المرجع: `MD-005` Currency في `doc.md` (سطر 540)، و`MD-004` Currency Master في `docs/01_master_data.md`. والـ router نفسه متسمي `"Currencies & Exchange Rates (MD-004)"`.
- **الغرض:** سجل العملات (الكود ISO، والاسم، والرمز)، ولكل عملة سعرين صرف قصاد الجنيه: **سعر البنك التجاري** و**سعر الجمارك الرسمي**، ومعاهم تاريخ السريان والتاريخ القديم. الجنيه المصري هو عملة الأساس، وسعره ثابت 1.0000 ومينفعش يتوقف. الشاشة فيها كمان محول عملات، وحاسبة أرباح وخسائر فروق العملة، ومحاكي What-If، ومزامنة لأسعار الجمارك الرسمية من نافذة.
- **المستخدمين:** المالية والمحاسبة والجمارك. سعر الجمارك بيدخل في تقدير الرسوم و Landed Cost، والسعر التجاري بيستخدم في الفواتير والتسوية.
- **المرحلة:** بيانات مرجعية. بتخدم المرحلة 1 (التقدير)، والمرحلة 5 (التخليص)، والتسوية المالية (فروق العملة).

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar افتح "البيانات والجداول الأساسية"، وبعدين "العملات وأسعار الصرف" (index 38).
- **الصلاحية:** على مستوى الـ router كله فيه `get_current_user` (`modules/currencies/router.py:22`). و`POST /api/v1/currencies/rates` بس اللي محتاج كمان `require_permission("master_data.edit")` (`router.py:112-116`). دي الشاشة الوحيدة في المجموعة اللي فيها صلاحية على إجراء معين.
- **التحميل:** `initState` بيستدعي `fetchCurrencies()`، وده بيعمل `GET /api/v1/currencies` (`currencies_screen.dart:35-40`). وفيه pagination في الـ client ("1 - 10 / 10").

## مكونات الشاشة

> **عناصر الإطار المشترك (مش جزء من الشاشة نفسها):** الـ elements JSON فيه عناصر ثابتة في كل الشاشات، ومش بتتشرح هنا بالتفصيل: الـ sidebar (أقسام "البيانات والجداول الأساسية" ومراحل الدورة 1 لـ 6 و"استعلامات" و"لوحة القيادة"، وحقل "بحث سريع..."، وزرار "إخفاء القائمة لتوسيع الشاشة")، والشريط العلوي (Home، وساعات العالم، والأوامر Ctrl+K، ومساعد الاستيراد الذكي، والمستمع الذكي للبريد، وإعدادات البريد IMAP/SMTP، وتبديل اللغة EN، والوضع الداكن، والإعدادات، وكثافة عرض الجدول، ووضع التركيز، ودليل الاختصارات، وملء الشاشة، والإشعارات)، وشريط تبويبات الـ workspace (كل شاشة مفتوحة بتظهر تاب عليه ✕، و⋯ "خيارات النوافذ والتبويبات")، وكارت المستخدم "Review Admin / ADMIN" و"خيارات المستخدم"، والإصدار `v2.0.3 (Build 205)` والبورت. كمان أي dialog في header بتاعه زرار ✕ ("إغلاق النافذة") بيقفل من غير حفظ، والنصوص اللي بتبدأ بـ "مثال: ..." جوه الحقول هي hints بس ومش قيم.

### الحقول

**شريط الأدوات:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث بكود العملة أو الاسم... | Text | لا | — | القائمة المحملة |

> مفيش switch "عرض المتوقف" هنا، مع إن باقي شاشات المجموعة فيها.

**Dialog إضافة / تعديل عملة (`_showCurrencyDialog`):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| كود العملة القياسي (3 أحرف) | `TextFormField` بـ `maxLength: 3`، وبيتقفل في التعديل | نعم | لازم الطول يبقى 3 بالظبط (`:724`) | `currency_code` (بيتحوّل UPPERCASE) |
| اسم العملة | `TextFormField` | نعم | مش فاضي | `currency_name` |
| رمز العملة | `TextFormField` | نعم (في `doc.md` مكتوب إنه **اختياري**) | مش فاضي | `currency_symbol` |

> حقل "Decimal Places" مش موجود في الفورم، مع إن `doc.md` بيعتبره Required.

**Dialog تحديث سعر صرف جديد (`_showAddRateDialog`):** العملة (`SearchableDropdownField<int?>`)، والسعر التجاري، وسعر الجمارك (الاتنين عليهم validators رقمية، `:1298, 1317`)، وتاريخ السريان.

**محول العملات الحي (`_showCurrencyConverterDialog`):** المبلغ، ومن عملة، ولعملة، ونوع السعر (تجاري أو جمارك). **قوائم العملات فيها 7 أكواد ثابتة** مكتوبة في الكود (`DropdownButtonFormField`، `:1448-1481`).

**حاسبة أرباح وخسائر فروق العملة (`_showGainLossCalculatorDialog`):** المبلغ، والعملة (`DropdownButtonFormField`)، وسعر البداية، وسعر التسوية.

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| إضافة عملة جديدة | بيفتح dialog العملة | `POST /api/v1/currencies` | أي مستخدم مسجل |
| تحديث أسعار الصرف | بيفتح dialog السعر | `POST /api/v1/currencies/rates` | `master_data.edit` |
| محول العملات الحي | بيفتح المحول | `POST /api/v1/currencies/convert` | أي مستخدم مسجل |
| إجراءات إضافية ⋮ | قائمة فيها: حاسبة فروق العملة، ومحاكي What-If، ومزامنة أسعار الجمارك الرسمية، و Excel، و PDF، و TSV، والنموذج، والاستيراد | `POST /api/v1/currencies/gain-loss`، و`/api/v1/simulation/...`، و`POST /api/v1/integrations/nafeza/exchange-rates/sync`، والتصدير | — |
| إعادة تحميل حية 🔄 / تصدير العملات (جدول نصوص) | بيعمل refresh وبينسخ TSV | `GET /api/v1/currencies` | — |
| **صف:** نسخ الملخص / 👁 / ✏ / 🖨 / 🗑 | 👁 بيفتح **سجل أسعار الصرف التاريخي** (`_showCurrencyRateHistoryDialog`)، و✏ للتعديل، و🖨 بيعمل PDF في الـ client، و🗑 للإيقاف. الجنيه المصري زرار الإيقاف بتاعه مقفول، والـ tooltip بيقول "لا يمكن تعطيل عملة الأساس" | `PUT .../{id}`، و`DELETE .../{id}`، و`POST .../{id}/restore` | أي مستخدم مسجل |
| **صف:** اسم العملة | بيفتح سجل الأسعار كمان (`:537`) | — | — |
| **سجل الأسعار:** إضافة سعر جديد | بيفتح dialog السعر والعملة متختارة جاهزة | `POST /api/v1/currencies/rates` | `master_data.edit` |
| **Dialogs:** حفظ | فيه spinner (`isSubmitting`) | — | — |

### الجداول

`Table` الـ header بتاعه غامق، وتحته footer فيه pagination:

| العمود | المعنى |
|---|---|
| الإجراءات | نسخ + pill |
| كود العملة | `EGP` ★ (الأساس)، `AED`، `CNY`... + نسخ |
| اسم العملة | Egyptian Pound، UAE Dirham... (بالإنجليزي من البيانات) + أيقونة السجل |
| الرمز | E£، €، £، ¥، ₹... |
| سعر البنك التجاري | "1 AED = 13.3300 جنيه"، أو "غير محدد" لو مفيش سعر |
| سعر الجمارك الرسمي | "1 AED = 13.2400 جنيه"، أو "غير محدد" |
| الحالة | نشطة / متوقفة |

الجدول مرتب أبجدياً بالكود، والجنيه المصري في الأول. في البيانات التجريبية INR و JPY من غير أسعار.

### التابات

الشاشة مفيهاش تابات.

### الـ Dialogs

**1) إضافة عملة جديدة**
![](../screenshots/09-currencies-dialog-add.png)
ده `AlertDialog` فيه 3 حقول، وتحت حقل الكود عداد "0/3". جوه الحقول زرار "نسخ القيمة" للحافظة، وتحت زرارين: "إلغاء" (`TextButton`، بيقفل من غير حفظ) و"حفظ" (فيه spinner أثناء الطلب).

**2) أخطاء الـ validation**
![](../screenshots/09-currencies-dialog-add-validation.png)
فيه 3 أخطاء: "يجب أن يتكون الكود من 3 أحرف"، و"هذا الحقل مطلوب" مرتين. في الـ semantics بيظهر النص الإنجليزي "3 characters remaining" بتاع عداد الـ `maxLength`، وده من bug الـ locale المعروف.

**3) متصورش:** سجل الأسعار التاريخي، وتحديث سعر الصرف، ومحول العملات، وحاسبة الأرباح والخسائر، و What-If Simulator، وتأكيد الإيقاف. كلهم اتوثقوا من الكود بس.

### التصدير والطباعة

| الإجراء | الطريقة | الحالة |
|---|---|---|
| تصدير "Excel" | CSV بيتعمل في الـ client (`exportCurrenciesToExcel` ← `saveText`)، واسمه `Currencies_<ts>.csv` | شغال، بس الملف CSV |
| تصدير PDF | `GET /api/v1/currencies/export-pdf` | **مكسور**: بيروح لـ `GET /{currency_id}` ويرجع 422 |
| تنزيل النموذج | `GET /api/v1/currencies/excel-template` | **مكسور**: نفس السبب |
| استيراد Excel | `POST /api/v1/currencies/import-excel` | **مكسور**: مفيش route، فبيرجع 405 |
| TSV | في الـ client | شغال |
| طباعة عملة واحدة | `printOrSaveCurrencyPdf` ← `Printing.layoutPdf` | شغال |

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | لو إضافة العملة أو تعديلها أو **إضافة سعر الصرف** فشلت، المستخدم مش بيعرف. الـ provider بيمسك الخطأ ويرجع `false`، والـ dialog بيفضل مفتوح من غير أي رسالة. والأخطر إن `POST /rates` محتاج صلاحية `master_data.edit`، فالمستخدم اللي معندوش الصلاحية هياخد 403 من غير ما يظهرله أي حاجة. | `providers/currencies_provider.dart:53-102`؛ `currencies_screen.dart:793, 805, 1363-1364`؛ `modules/currencies/router.py:112-116` | الـ provider يرجّع رسالة الخطأ (زي 403 أو كود متكرر)، وتظهر في SnackBar أحمر. |
| High | تصدير PDF، وتنزيل النموذج، والاستيراد كلهم مكسورين. فحص `route.matches()` بيبيّن إن `/export-pdf` و`/excel-template` بيروحوا لـ `/api/v1/currencies/{currency_id}` (422)، و`/import-excel` ملوش route كامل (405). | `currencies_screen.dart:262-292`؛ `modules/currencies/router.py:56-116` (مفيش routes تصدير) | إضافة الـ endpoints في الباك، أو شيل الاختيارات دي من القائمة. |
| Medium | محول العملات وحاسبة فروق العملة فيهم قوائم عملات **ثابتة (7 أكواد)** بـ `DropdownButtonFormField`، بدل ما تيجي من جدول العملات. العملات المتسجلة زي INR و JPY و TRY مش ظاهرة، وده كمان مخالف لقاعدة `SearchableDropdownField`. | `09-currencies-main.png` (10 عملات)؛ `currencies_screen.dart:1448-1481, 1649` | `SearchableDropdownField` مصدره `currenciesProvider`. |
| Medium | رسالة نجاح المزامنة بتختار `message_ar` أو `message_en` على حسب `Localizations.localeOf(context)`. وبسبب bug الـ locale المعروف ده بيرجع `en`، فالرسالة **هتظهر بالإنجليزي حتى في الوضع العربي**. | `currencies_screen.dart:111-113` | الاعتماد على `localeProvider`، أو حل مشكلة `supportedLocales`. |
| Medium | مفيش RBAC على إضافة العملة ولا تعديلها ولا إيقافها، مع إن إضافة السعر عليها صلاحية. ده مش متسق. | `modules/currencies/router.py:75-110` | `require_permission("master_data.edit")` على كل عمليات الكتابة. |
| Low | حقل Decimal Places مش موجود رغم إن `doc.md` بيقول إنه Required، والرمز إلزامي في الفورم مع إن `doc.md` بيقول إنه اختياري. | `09-currencies-dialog-add.png`؛ `currencies_screen.dart:714-760`؛ `doc.md` (MD-005 Main Fields) | مواءمة الفورم مع الـ spec. |
| Low | مفيش switch "عرض العملات المتوقفة"، بخلاف باقي شاشات البيانات المرجعية، فالعملة اللي اتوقفت ممكن متظهرش خالص عشان تتفعل تاني. | `09-currencies-main.png` (شريط الأدوات) مقارنة بـ `01-import-companies-main.png` | إضافة الفلتر. |
| Low | الـ `PageHeader` من غير أيقونة. | `09-currencies-main.png`؛ `currencies_screen.dart:143-150` | `icon: Icons.currency_exchange`. |
| Low | "تصدير Excel" بيطلع CSV. | `core/services/master_data_export_service.dart:1905-1911` | xlsx من الباك. |
| Low | مخالفات للمعايير: `ElevatedButton` و`TextButton` بدل `AppButton`، ونصوص عربي مكتوبة في الكود مباشرة لعناوين الحفظ. | `currencies_screen.dart:159-202, 269, 282, 770-778, 1349-1350` | `AppButton` + l10n. |
| Low | Bug الـ locale المعروف ظاهر هنا في عداد `maxLength` ("3 characters remaining") وفي label الـ `AlertDialog`. | `elements/09-currencies-dialog-add.json` | `supportedLocales` + `GlobalMaterialLocalizations`. |
| Low (Web-only) | الـ console طلّع مرة واحدة `Refused to set unsafe header "Accept-Encoding"`. | `runtime-errors.json` → `09-currencies`؛ `core/network/api_client.dart:27` | الـ header ميتبعتش لما يكون `kIsWeb`. |
