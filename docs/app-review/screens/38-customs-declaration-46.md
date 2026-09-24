# شهادة الإجراءات الجمركية إقرار 46 ك.م (Customs Declaration 46)
![](../screenshots/38-customs-declaration-46-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب على الجهاز. أي فرق خاص بالويب متعلّم عليه كده.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** تجهيز وقيد الإقرار الجمركي المبدئي (شهادة 46 ك.م) لملف الشحنة، وسحب ACID ونموذج 4 البنكي ورقم البوليصة تلقائياً، وعرض تقدير مبدئي للقيمة الجمركية CIF وضريبة الوارد والقيمة المضافة والرسوم، مع موقف الإعفاء (EUR.1 / MFN) والموافقات الرقابية لبنود التعريفة.
- **المستخدمين:** مسؤول التخليص / المستخلص الجمركي، ومدير الاستيراد للمتابعة.
- **المرحلة:** المرحلة 5 "الميناء والتخليص الجمركي" (`stageCode: 'PHASE-5: STEP_13'`). بتغطي **BP-027** (تجهيز التخليص) و **BP-028** (إعداد وتثبيت الإقرار 46)، حسب `docs/phase_06_customs_preparation.md`، وبتعتمد على جدول التعريفة **MD-008**.

## طريقة الوصول والصلاحية
- **Sidebar:** "المرحلة 5: الميناء والتخليص الجمركي" ← "شهادة الإجراءات الجمركية إقرار 46 ك.م" (index 23، وكمان index 24 للتاب التاني).
- **Scaffold:** `VerticalStageScaffold` (Type A) بتابين رأسيين.
- **اختصار:** `Ctrl+D` بيفتح Search & Clone (`customs_declaration46_screen.dart:722`).
- **الصلاحية:** أي مستخدم عامل login. كل الـ endpoints اللي الشاشة بتقراها محمية بـ `Depends(get_current_user)` على مستوى الـ router، ومفيش RBAC permission code (`modules/import_documentation/router.py:14`).

## مكونات الشاشة

### الحقول
التاب الأول (فورم القيد المبدئي):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة (اختيار ملف الاستيراد) | `SearchableDropdownField<int>` | أيوه (عملياً) | مفيش `validator`. التحقق بيحصل في `_saveDeclaration46` بـ SnackBar "يرجى اختيار ملف الشحنة أولاً" | `importFilesProvider` ← `GET /api/v1/import-files` |
| رقم الإقرار والشهادة الجمركية (46 ك.م) | TextFormField | أيوه (*) | مش فاضي (`:938`) | قيمة افتراضية `46-EG-2026-`، وبتتكتب تلقائياً `46-ALX-<كود الملف>` لما تختار الملف (`:264`) |
| تاريخ القيد المبدئي | TextFormField + date picker | أيوه (*) | – | تاريخ النهارده افتراضياً |
| رقم القيد الجمركي المبدئي المسبق (ACID) | TextFormField | لأ | – | `acidSessionsProvider` ← `GET /api/v1/import-documentation/acid-sessions`، ولو مفيش بيرجع لـ `file.acidNumber` |
| رقم نموذج 4 البنكي المعتمد | TextFormField | لأ | – | `bankingDocumentsProvider` (docType = Form 4)، ولو مفيش بيولّد `F4-<swiftNo>` أو `F4-ALX-<code>` (`:233`) |
| رقم بوليصة الشحن | TextFormField | لأ | – | Draft BL Review ← Freight Booking ← `customFileNumber` |
| القيمة للأغراض الجمركية سيف (جنيه) | TextFormField رقمي | لأ | – | بتتحسب في الفرونت (شوف الملاحظات) |
| ضريبة الوارد المقدرة (جنيه) | TextFormField رقمي | لأ | – | محسوبة: CIF × نسبة البند |
| ضريبة القيمة المضافة (جنيه) | TextFormField رقمي | لأ | – | محسوبة: (CIF + الوارد + الرسوم) × VAT |
| إجمالي الضرائب والرسوم المقدرة | TextFormField (قراءة، أحمر) | – | – | مجموع الحقول (`_calculateTotalDuties`) |

فوق الفورم فيه بانر معلومات (مسودة إقرار 46 ك.م الجاهزة للربط مع نافذة، وإن ACID ونموذج 4 والبوليصة بيتسحبوا تلقائياً). وكل حقل نصي جنبه أيقونة "نسخ القيمة إلى الحافظة" (9 أيقونات في الفورم).

كمان فيه كارت "موقف الإعفاء والاتفاقية" (EUR.1 أو MFN)، وجدول "الموافقات الرقابية لبنود التعريفة"، ودول بيظهروا بس بعد ما تختار ملف.

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة عند هذه المرحلة (الهيدر) | أزرار `VerticalStageScaffold` لتغيير حالة الشحنة في المرحلة | stage-status endpoints بتاعة ملف الاستيراد | Authenticated |
| أيقونة Search & Clone (الهيدر) + "استنساخ إقرار 46 جمركي" (فوق وتحت) | بيفتح `SearchAndCloneCustomsDeclaration46Dialog` وبعده `CloneEntityReviewDialog` وبيملا الفورم بمسودة | مفيش (client-side) | – |
| تحديث (الهيدر) | `_refreshData()`: بيعيد تحميل 7 providers | GETs: import-files, acid-sessions, banking-documents, customs-tariff, purchase-orders, draft-bl-reviews, freight-booking | Authenticated |
| العودة للداش بورد | رجوع للوحة التحكم | – | – |
| **حفظ وقيد الإقرار الجمركي المبدئي** | بيعمل validate، وبعدين **بيستنى 600ms بس** ويطلّع SnackBar نجاح وينقل للسجل. **مفيش أي API call** | **مفيش**. الباك إند فيه `POST /api/v1/import-documentation/customs-declarations` بس مش مستخدم | – |
| معاينة ونسخ ملخص الإقرار | بيفتح `_showDeclarationSummaryDialog` | – | – |
| نسخ كجدول (TSV) | بينسخ بيانات الفورم للـ clipboard | – | – |
| (التاب 2) قيد إقرار جديد | بيرجع للتاب الأول بس | – | – |
| (التاب 2) نسخ كجدول (TSV) / تصدير Excel / طباعة PDF | تصدير السجل | – (client-side) | – |
| (صف في الجدول) معاينة التقييم / نسخ الصف / استنساخ | `_showTariffAssessmentDialog` / `TableCopyHelper.copyRow` / Clone | – | – |

### الجداول
**سجل شهادات 46 ومتابعتها** (التاب 2)، ![](../screenshots/38-customs-declaration-46-tab-2-declaration-46-registry.png)
- **كروت KPI:** إجمالي الإقرارات (6)، إجمالي القيمة الجمركية سيف (17,695,980.66 EGP)، إجمالي الضرائب والرسوم (2,679,171.47 EGP)، إعفاءات الشراكة الأوروبية (6).
- **الأعمدة:** الإجراءات | رقم الإقرار (46 ك.م) | رقم الملف | المورد الأجنبي | بند التعريفة الجمركية | القيمة للأغراض الجمركية سيف | إجمالي الضرائب | الحالة. آخر عمودين مش باينين في الصورة (الجدول أعرض من المساحة).
- **الفلتر:** بحث نصي بكود الملف أو المورد أو الاسم (`:1879`). مفيش ترتيب.
- **مهم:** السجل **مش جاي من جدول إقرارات**. كل ملف استيراد بيتحول لـ "إقرار" محسوب في الفرونت (`_calculateAssessment`، `:1647`)، ورقم الإقرار مولّد `46-ALX-<code>`.

### التابات
1. **قيد الإقرار الجمركي المبدئي (Initial Declaration 46 Form)**: ![](../screenshots/38-customs-declaration-46-tab-1-initial-declaration-46-form.png). الفورم اللي فوق.
2. **سجل شهادات 46 ومتابعتها (Declaration 46 Registry)**: ![](../screenshots/38-customs-declaration-46-tab-2-declaration-46-registry.png). KPIs + جدول + تصدير.

### الـ Dialogs
- **مفيش dialog إضافة.** زرار "قيد إقرار جديد" بيرجّع للفورم اللي في نفس الصفحة، والـ harness سجّل ده كملاحظة ("add button did not open a modal dialog"). الصورة `dialog-add` هي نفس الفورم: ![](../screenshots/38-customs-declaration-46-dialog-add.png)
- **أخطاء الـ validation:** لما تحفظ من غير ما تختار ملف، بيظهر SnackBar أحمر "يرجى اختيار ملف الشحنة أولاً"، ومن غير أي رسالة تحت الحقل: ![](../screenshots/38-customs-declaration-46-dialog-add-validation.png)
- `_showTariffAssessmentDialog`: تفصيل حساب CIF والرسوم والإعفاء، مع أزرار نسخ الملخص / TSV / استنساخ (`:2299`). مش متصوّر.
- `_showDeclarationSummaryDialog`: ملخص الإقرار للمعاينة والنسخ. مش متصوّر.
- `SearchAndCloneCustomsDeclaration46Dialog` و `CloneEntityReviewDialog`: بحث واستنساخ إقرار كمسودة. مش متصوّرين.

### التصدير والطباعة
- **Excel / PDF للسجل:** عن طريق `TableExportService.exportTableToExcel/Pdf` ← `FileSaveHelper.exportAndSaveFile`، باسم stage "Customs Declarations 46 Registry" واسم ملف `ALL-FILES` (`:2830` و `:2860`). على الويب بيستخدم File System Access API أو `<a download>` (فرق خاص بالويب).
- **TSV:** نسخ للـ clipboard بس، مش ملف.
- **Excel/PDF للموافقات الرقابية:** `_exportApprovalsToExcel/Pdf` (`:547` و `:583`).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| Critical | زرار "حفظ وقيد الإقرار الجمركي المبدئي" **مبيحفظش حاجة**: بيعمل `Future.delayed(600ms)` وبعدين SnackBar نجاح. المستخدم فاكر إن الإقرار اتسجّل وهو متسجّلش | `customs_declaration46_screen.dart:2887`، `modules/import_documentation/router.py:229` (الـ endpoint موجود بس مش مستخدم) | اربط الحفظ بـ `POST /api/v1/import-documentation/customs-declarations` واعرض خطأ الباك إند كـ SnackBar |
| Critical | "سجل شهادات 46" معمول بالكامل في الفرونت من ملفات الاستيراد: كل ملف بيظهر كإقرار "مسجل على نافذة" برقم متولّد، وتاريخ القيد = النهارده، والحالة ثابتة | `:1658` (`declNo = '46-ALX-...'`)، `:1803`، `:1804`؛ الصورة `38-customs-declaration-46-tab-2-declaration-46-registry.png` (6 ملفات = 6 إقرارات) | اقرا الإقرارات الحقيقية من الباك إند (يتضاف GET list) واعرض الحالة الفعلية |
| High | نسب وأسعار hard-coded في حساب الرسوم: سعر صرف `50.7917`، نولون 2%، تأمين 2.5%، ضريبة وارد افتراضية 5%، VAT افتراضية 14%. ده مخالف لقاعدة "ممنوع Hard-Code أي نسبة ضريبية أو رسم جمركي"، وكمان منطق الحساب متكرر في مكانين | `:286`، `:288`، `:293`، `:300`، `:301` وكمان `:1732`، `:1733`، `:1738`، `:1748`، `:1749` | استخدم `/api/v1/customs-tariff/estimate` أو `simulate-file` وسعر الصرف من master العملات، في service واحد |
| High | لو الملف مالوش أوامر شراء فيها HS، بيتحط بندين وهميين `8471.30.00` و `8517.62.00`، ولو مفيش match بياخد أول بند في التعريفة. عشان كده كل صفوف السجل ظاهرة بنفس البند 8471.30.00 | `:279`، `:1724`؛ الصورة `38-...-tab-2-declaration-46-registry.png` | متفترضش بنود. اعرض "لا توجد بنود" واطلب من المستخدم يكمل البيانات |
| Medium | تحديد إعفاء EUR.1 بيتعمل بـ substring على اسم ميناء الشحن (`contains('IT'/'FR'/'DE'/'ES')`)، فأي اسم ميناء فيه الحروف دي (زي "ODESSA") هيتحسب معفي غلط | `:320`، `:1762` | اعتمد على بلد المنشأ (FK) وشهادة المنشأ واتفاقيات `/customs-tariff/check-duty-for-origin` |
| Medium | خطأ runtime: `Bad state: Cannot use "ref" after the widget was disposed` اتسجّل مرتين أثناء التنقل | `runtime-errors.json` ← `38-customs-declaration-46` | اتأكد من `mounted` قبل استخدام `ref` في callbacks الـ async (`_refreshData` / `onShipmentStatusChanged`) |
| Medium | حقل اختيار الملف: الـ label والـ hint بيترسموا فوق بعض (النص مش مقروء) | `38-customs-declaration-46-main.png` (أول حقل في الفورم) | اضبط `floatingLabelBehavior` أو شيل الـ hint لحد ما الحقل ياخد focus |
| Medium | اختيار الملف ملوش `validator`، والخطأ بيظهر SnackBar بس من غير رسالة حمرا تحت الحقل (مخالف لقاعدة Forms Validation) | `38-customs-declaration-46-dialog-add-validation.png`، `:2881` | ضيف `validator` للـ `SearchableDropdownField` |
| Medium | جدول السجل أعرض من المساحة: عمود القيمة مقطوع وأعمدة الضرائب والحالة مش باينة من غير scroll أفقي، ومفيش مؤشر scroll | `38-customs-declaration-46-tab-2-declaration-46-registry.png` | قلّل الأعمدة أو استخدم الجدول الموحد مع scroll ظاهر |
| Low | أزرار `ElevatedButton`/`OutlinedButton` وألوان `Colors.indigo` و `Color(0xFF...)` بدل `AppButton` و `AppTheme` | `:1572`، `:1575`، `:2037`، `:2040` | استخدم `AppButton` (variant primary/outline) |
| Low | عنوان الهيدر وأسماء التابات الرأسية و "Operations & Stages" ظاهرين بالإنجليزي في الوضع العربي. ده جزء من مشكلة الـ locale العامة (`main.dart` بيحدد `ar` من غير `supportedLocales`، فـ `Localizations.localeOf` بيرجع `en_US`) | `38-customs-declaration-46-main.png` | إصلاح `supportedLocales` في `main.dart` (مشكلة عامة واحدة) |
| Low | عنوان فرعي غلط في PDF السجل: "Customs Clearance Follow-up" بدل Declaration 46 | `:2868` | صحّح الـ subtitle |
| Low (ويب) | `Refused to set unsafe header "Accept-Encoding"` اتكررت 34 مرة: المتصفح بيرفض الهيدر ده. ده سلوك خاص بالويب ومش bug على الديسك توب | `runtime-errors.json` ← `38-customs-declaration-46` | متبعتش `Accept-Encoding` من Dio لما يكون `kIsWeb` |
