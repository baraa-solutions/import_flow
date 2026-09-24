# حاسبة الأحجام وتوزيع الحاويات (Cargo Measurement Engine (CBM))
![](../screenshots/12-cbm-calculator-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الأكواد:** `BP-004` حساب الحجم (CBM) والوزن الخاضع للشحن، و`BP-005` تخطيط تحميل الحاويات ومحاكاة الرص (`docs/phase_01_import_planning.md`). بتعتمد على بيانات مرجعية `MD-010`، و`MD-011`، و`MD-012`، و`MD-019` (أنواع الطرود والحاويات والوحدات)، حسب `inventory.json`.
- **الغرض:** إدخال الطرود (النوع، والوحدة، والعدد، والأبعاد، والرص، ووزن الوحدة)، وحساب إجمالي الـ CBM، والوزن القائم، والوزن الجوي المحاسبي (Volumetric)، واقتراح وسيلة الشحن (Sea LCL / FCL / Air). ومنها بتقارن الحاويات، وتعرض مخطط الرص، وتحفظ "جلسة تشغيلية" وتربطها بملف استيراد.
- **المستخدمين:** مسؤول الشحن / التخطيط.
- **نوع الشاشة:** Type C (Utility)، ومذكورة بالاسم كمثال في الـ Skill.

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar: "استعلامات" ← "حاسبة الأحجام وتوزيع الحاويات (CBM)" (index 3).
- **الصلاحية:** أي مستخدم مسجل. الـ router عليه `dependencies=[Depends(get_current_user)]` بس، ومفيش RBAC (`modules/cbm_calculator/router.py:18`).
- **تحميل البيانات:** `initState` بيجيب الحسابات المحفوظة والمشاريع وأوامر الشراء وملفات الاستيراد (`cbm_calculator_screen.dart:88-107`).

## مكونات الشاشة

### الحقول

**تاب الحاسبة (لكل سطر طرد):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| نوع الطرد | `SearchableDropdownField` (Carton…) | نعم (افتراضي) | — | قيم ثابتة |
| الوحدة | Dropdown (cm…) | نعم | — | ثابتة |
| العدد | Number | — | — | إدخال |
| الطول / العرض / الارتفاع (cm) | Number | — | — | إدخال |
| الرص | Dropdown (قابل للرص / غير قابل للرص) | — | — | ثابتة |
| وزن الوحدة (كجم) | Number | — | — | إدخال |
| تعليمات التحميل والرص | Text | لا | — | إدخال |

**Toggles:** شحن بحري / شحن جوي، وقابل للرص / غير قابل للرص (على مستوى الجلسة).

**Dialog حفظ الجلسة التشغيلية (`_showSaveCalcDialog`، `:1198`):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| رقم ملف الاستيراد | `SearchableDropdownField` | لا | — | `GET /api/v1/import-files` (الخيار الفاضي اسمه "-- جميع الحالات --"، `:1252`) |
| عنوان جلسة الحساب | Text | نعم | `l.requiredField` (`:1266`)، وقيمته الافتراضية `l.calculationSessionTitle` (`:1203`) | إدخال |
| ملاحظات ومواصفات البضاعة | Text | لا | — | إدخال |

**تاب السجل:** بحث "ابحث بكود الحساب، العنوان، ملف الشحنة، أو الملاحظات..."، وCheckbox "إخفاء الملغية".

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| العودة للداش بورد | رجوع | — | — |
| مقارنة خيارات الحاويات | `_showContainerComparisonDialog` (`:591`، و`:1395`) | — (حساب في الـ client) | — |
| مخطط ومحاكاة رص الحاويات | `_showVisualLoadPlanDialog` (`:600`، و`:1573`) | `/api/v1/container-loader` | مستخدم مسجل |
| إضافة سطر طرد | يضيف سطر جديد (inline، مش dialog) | — | — |
| حفظ الجلسة التشغيلية | يفتح dialog الحفظ ← إنشاء أو تعديل | `POST /api/v1/cbm-calculator` / `PUT /{calc_id}` | مستخدم مسجل |
| Export Excel / Export PDF / Copy Packages | تصدير الطرود | `TableExportService` ← `FileSaveHelper.exportAndSaveFile` (`:2086-2185`) | — |
| استنساخ هذا الطرد (Ctrl + D) / حذف السطر | تكرار / حذف سطر | — | — |
| **تاب السجل:** تحديث السجل | إعادة تحميل | `GET /api/v1/cbm-calculator` | مستخدم مسجل |
| بحث واستنساخ دراسة CBM | بحث واستنساخ | `POST /{calc_id}/clone` | مستخدم مسجل |
| Export Excel / Export PDF / Copy Table | تصدير السجل | في الـ client | — |
| (من الكود) ربط بملف / حذف / استرجاع | — | `POST /{id}/link`، و`DELETE /{id}`، و`POST /{id}/restore` | مستخدم مسجل |

### الجداول

- **شريط النتائج:** إجمالي الحجم (CBM)، والوزن الجوي المحاسبي (وتحته سطر "الوزن الحجمي" بالكجم = الوزن الحجمي المحسوب من الأبعاد)، والوزن القائم (Gross)، ووسيلة الشحن المقترحة.
- **جدول الطرود:** #، ونوع الطرد، والوحدة، والعدد، والطول، والعرض، والارتفاع، والرص، ووزن الوحدة، والنتائج المحسوبة (CBM، والإجمالي، والوزن الجوي لكل سطر).
- **السجل:** شريط مؤشرات (إجمالي الحسابات، وجلسات نشطة، وإجمالي الحجم، وإجمالي الوزن القائم) وقائمة كروت (`ListView.builder`، `:1938`). في الـ scratch DB مكانش فيه جلسات محفوظة، فالسجل ظهر فاضي ("لا توجد بيانات مسجلة").

### التابات

1. **حاسبة القياسات التشغيلية السريعة:** `12-cbm-calculator-tab-1-quick-operational-calculator.png` (زي الـ main). فيها الحاسبة والنتائج وأزرار المقارنة والمخطط.
2. **سجل دراسة وحسابات الشحن المحفوظة:** `12-cbm-calculator-tab-2-saved-calculations-history-log.png`. فيه مؤشرات، وبحث، وإخفاء الملغية، وتصدير، واستنساخ.

### الـ Dialogs

- **"إضافة سطر طرد" مش dialog.** بيضيف سطر inline (`capture-manifest.json`: "add button did not open a modal dialog"). الصورة `12-cbm-calculator-dialog-add.png` فيها سطر #2 مضاف.
- **Dialog حفظ الجلسة التشغيلية:** `12-cbm-calculator-dialog-add-validation.png`. الـ harness داس "حفظ الجلسة التشغيلية" فظهر الـ dialog. **مفيش خطأ validation ظهر** لأن حقل العنوان متعبّي بقيمة افتراضية. الزرار الأساسي مكتوب عليه "حفظ التعديلات" مع إن ده إنشاء جديد، وجنبه "إلغاء" بيقفل الـ dialog (`Navigator.pop`، `:1280`).
- من الكود: مقارنة خيارات الحاويات، ومخطط رص الحاويات.

### التصدير والطباعة

- Export Excel / Export PDF للطرود وللسجل عبر `TableExportService.exportTableToExcel/Pdf` ← `FileSaveHelper.exportAndSaveFile` (`:2134`، و`:2181`).
- Copy Packages / Copy Table: نسخ TSV للحافظة.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | Exception وقت التشغيل: `Bad state: Cannot use "ref" after the widget was disposed.` اتسجل مرة وقت فتح الشاشة دي (10:08:32). نفس الـ JS frame بالظبط (`main.dart.js:192335`) ظهر في شاشة 17، يعني المصدر غالباً widget أو callback مشترك مش كود الحاسبة نفسه، والـ release build متصغّر فمش ممكن نحدد السطر. مفيش أثر ظاهر على الشاشة في الصور | `runtime-errors.json` (12-cbm-calculator و17-clearance-quotations: نفس الـ stack) | شغّل debug build (`flutter build web --debug`) عشان تحدد الـ callback، وافحص `mounted` قبل أي `ref` بعد `await` أو في `addPostFrameCallback` |
| Medium | في dialog الحفظ، الخيار الفاضي لحقل "رقم ملف الاستيراد" اسمه "-- جميع الحالات --" (نص فلتر مش مناسب لحقل اختيار) | `cbm_calculator_screen.dart:1252`؛ `12-cbm-calculator-dialog-add-validation.png` | `-- None / غير مرتبط --` |
| Medium | زرار الإنشاء في dialog الحفظ اسمه "حفظ التعديلات" (`l.saveChanges`) مع إن مفيش جلسة بتتعدل | `cbm_calculator_screen.dart:1357`؛ `12-cbm-calculator-dialog-add-validation.png` | `l.saveCalculationSession` |
| Medium | عنوان الجلسة متعبّي افتراضياً باسم الحقل، فالـ required validator عمره ما هيشتغل، والجلسات كلها هتتحفظ بنفس العنوان | `cbm_calculator_screen.dart:1203`؛ `12-cbm-calculator-dialog-add-validation.png` | خلّيه فاضي أو اقترح عنوان مميز (كود + تاريخ) |
| Medium | أزرار الحفظ في الـ dialog من غير loading state، وممكن تتداس مرتين | `cbm_calculator_screen.dart:1283-1300` (`onPressed: () async` من غير `isLoading`) | `AppButton(isLoading:)` |
| Low | "Export Excel" و"Export PDF" و"Copy Packages" و"Copy Table" ظاهرين بالإنجليزي في الوضع العربي رغم إن الشاشة RTL. الكود بيختار النص بـ `Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(...)`، ومرتبط بالـ bug المعروف بتاع الـ locale (`Localizations.localeOf` = en_US) | `12-cbm-calculator-main.png`، و`12-cbm-calculator-tab-2-saved-calculations-history-log.png`؛ `cbm_calculator_screen.dart:743-773` | `context.l10n` |
| Low | مفيش 🔄 Refresh في تاب الحاسبة (إلزامي في كل الشاشات حسب الـ Skill §2)، موجود في تاب السجل بس | `12-cbm-calculator-main.png` | أضف refresh في الهيدر |
| Low | Console: `Accept-Encoding` (12 مرة). **فرق Web بس** | `runtime-errors.json` | — |
| Low | 16 `ElevatedButton` و93 `Colors.` بدل `AppButton` / `AppTheme` | `cbm_calculator_screen.dart` (عدّ grep) | توحيد |
