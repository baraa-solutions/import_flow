# متابعة التخليص والكشف والعينات والرسوم (Customs Clearance Hub)
![](../screenshots/39-customs-clearance-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب. قاعدة البيانات الـ scratch **مفيهاش سجلات تخليص**، فكل التابات ظاهرة بحالة "فاضي". اللي مش باين في الصور متوثّق من الكود.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** شاشة مركزية لمتابعة التخليص في الميناء: تسجيل معاملة تخليص (الدائرة الجمركية، المسار أحمر/أصفر/أخضر، إذن التسليم، أيام السماح، مطالبة الرسوم)، وسحب العينات ومحاضر العجز، ومحاضر الفاقد والتلف، وسداد الرسوم النهائية والإفراج.
- **المستخدمين:** المستخلص الجمركي، ومسؤول العمليات في الميناء، والمالية (في جزء السداد).
- **المرحلة:** المرحلة 5 "الميناء والتخليص الجمركي" (`stageCode: 'PHASE-5'`). بتغطي **BP-029** (متابعة الكشف والمعاينة)، و **BP-030** (إذن السداد والاستخلاص من نافذة)، و **BP-031** (تسجيل السداد والمطابقة)، و **BP-032** (الإفراج النهائي)، حسب `docs/phase_07_customs_clearance.md`. وأزرار الهيدر كمان بتغطي CS-01 و CS-02 و CS-03 و CL-01 لحد CL-05. المستخلص من **MD-003** (Partners).

## طريقة الوصول والصلاحية
- **Sidebar:** "المرحلة 5: الميناء والتخليص الجمركي" ← "متابعة التخليص والكشف والعينات والرسوم" (index 27). الـ indices 60 و 61 و 62 بتفتح التابات 2 و 3 و 4 مباشرة، ومالهمش عناصر في الـ sidebar.
- **Scaffold:** `VerticalStageScaffold` (Type A) بأربع تابات رأسية.
- **الصلاحية:** أي مستخدم عامل login: `APIRouter(..., dependencies=[Depends(get_current_user)])` (`modules/customs_clearance/router.py:49`). مفيش RBAC code.

## مكونات الشاشة

### الحقول
**فورم "تسجيل معاملة تخليص جمركي وميناء جديدة"** (`_CustomsClearanceFormDialog`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة الاستيرادية المرتكز عليه | `SearchableDropdownField<int>` | أيوه | `val == null` ← "يرجى اختيار ملف الشحنة" (`customs_clearance_screen.dart:1516`) | `importFilesProvider` ← `GET /api/v1/import-files` |
| رقم الإقرار الجمركي (46) | TextFormField + نسخ | لأ | – | يدوي أو من مستخلص نافذة |
| رقم إذن التسليم | TextFormField + نسخ | لأ | – | يدوي |
| أيام السماح بالميناء | TextFormField رقمي | لأ | – | افتراضي 14 |
| اسم الجمرك والدائرة الجمركية | TextFormField | أيوه (*) | مش فاضي (`:1567`) | افتراضي "Alexandria Port Customs" |
| المسار الجمركي | `DropdownButtonFormField<String>` | أيوه (*) | – | قيم ثابتة: Red / Green / Yellow Channel |
| ضريبة الوارد، ضريبة القيمة المضافة، ضريبة الجدول، أرباح تجارية وصناعية، رسوم معملية وخدمات، التقديري من النظام | 6 حقول رقمية | لأ | – (`double.tryParse ?? 0`) | يدوي، أو من الاستخلاص الذكي (`_applyExtractedNafezaData`) |

**فلاتر الشاشة:** بحث نصي (كود التخليص / رقم 46) + `DropdownButton` للحالة (الكل، قيد الكشف، مطالبة رسوم، تم السداد، إفراج نهائي) (`:900`).

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تكويد مستخلص جمركي بالذكاء الاصطناعي ✨ (الهيدر) | `UniversalEntityExtractorDialog.showCustomsBrokerExtractor` وبعدها refresh للـ partners | external-service-providers | Authenticated |
| تفويض المخلص (CS-01) | `CustomsBrokerAuthorizationDialog` | `POST /api/v1/customs-clearance/authorize-broker` | Authenticated |
| سداد إذن التسليم (CS-02) | `DeliveryOrderPaymentDialog` | `POST .../delivery-order-payment` | Authenticated |
| قيد إقرار 46 (CS-03) | `CustomsDeclaration46Dialog` | `POST .../register-declaration-46` | Authenticated |
| الكشف والمعاينة (CL-01) | `CustomsInspectionSamplingDialog` | `POST .../record-inspection-sampling` | Authenticated |
| حساب الرسوم (CL-02) | `FinalDutyAssessmentDialog` | `POST .../assess-final-duties` | Authenticated |
| سداد الرسوم (CL-03) | `CustomsDutyPaymentDialog` | `POST .../record-duty-payment` | Authenticated |
| إذن الإفراج (CL-04) | `CustomsFinalReleaseDialog` | `POST .../issue-final-release` | Authenticated |
| فواتير التخليص (CL-05) | `ClearanceExpensesDialog` | `POST/GET/DELETE .../invoices` | Authenticated |
| تخطي المرحلة / إيقاف الشحنة | أزرار `VerticalStageScaffold` | stage-status | Authenticated |
| تسجيل معاملة تخليص | فورم الإضافة | `POST /api/v1/customs-clearance` | Authenticated |
| بحث واستنساخ بيان تخليص سابق | `SearchAndCloneCustomsClearanceDialog` وبعده فورم مسودة | `POST /api/v1/customs-clearance` | Authenticated |
| نسخ الجدول / Excel / PDF / تحديث (أيقونات) | تصدير السجلات المفلترة / `_refreshData` | `GET /api/v1/customs-clearance` | Authenticated |
| (كارت السجل) تعديل / نسخ / استنساخ / إفراج تحت التحفظ / سداد / إفراج / فواتير | `_showAddEditDialog(record)` / TSV / Clone / `showUnderBondReleaseDialog` / `_DutyPaymentDialog` / `_FinalReleaseDialog` / `ClearanceExpensesDialog` | `POST /api/v1/customs-clearance` (حتى في التعديل)، `POST /{id}/under-bond-release`، `POST /{id}/pay-duty`، `POST /{id}/complete-release` | Authenticated |

### الجداول
- **تاب المتابعة:** مش جدول، ده **قايمة كروت** (`_buildClearanceCard`، `:1071`). كل كارت فيه: كود التخليص والحالة بلون (إفراج نهائي أخضر، تم السداد أزرق، مطالبة رسوم برتقالي)، والملف، والجمرك، ورقم 46، وإذن التسليم، وأيام السماح، وإجمالي الرسوم EGP، والتقديري والفرق (Δ و %)، وحالة السداد. الفلترة بالبحث والحالة، ومفيش ترتيب.
- **تاب العينات:** جدول العينات (كود العينة، الجهة الرقابية، تاريخ السحب، رقم الإيصال، نوع الفحص، الحالة، ملاحظات، نسخ) وجدول محاضر العجز (كود المحضر، الحاوية/الطرد، الوصف، كمية المانيفست، المفرّغ، العجز، النسبة، الإجراء، ملاحظات) (`drawing_samples_and_shortage_tab.dart:747` و `:891`). وفيه فلتر chips: كافة العينات / مطابقة فقط / قيد الفحص فقط.
- **تاب الفاقد والتلف:** "ملخص المحضر الجمركي" مع chips للحالة (كافة الحالات / مقدمة للتأمين / معتمدة للتعويض / قيد التحقيق والمعاينة) وبحث.
- **تاب السداد النهائي:** "سجل أذون سداد نافذة المعتمدة ومطابقة الرسوم" مع chips (كافة المعاملات / تم السداد / قيد السداد / إفراج نهائي) وعدّاد 0/0.

### التابات
1. **متابعة الكشف والتثمين والتفتيش الجمركي (Customs Clearance Follow-up)**: ![](../screenshots/39-customs-clearance-tab-1-customs-clearance-follow-up.png). فاضي: "لا توجد سجلات تخليص جمركي مطابقة للبحث حالياً".
2. **سحب العينات وتحديد عجز البضائع (Drawing Samples & Shortage Tracking)**: ![](../screenshots/39-customs-clearance-tab-2-drawing-samples-shortage-tracking.png). فيه 4 KPIs (إجمالي العينات، المطابقة، قيد الفحص، حالات العجز)، وأزرار "تسجيل سحب عينة" و "إثبات محضر عجز جديد"، وتصدير (تصدير جدول تبويب مفصول، تصدير جدول أكسيل، طباعة تقرير الفحص والعجز، نسخ ملف الحافظة الشامل) وزرار "تحديث البيانات"، وأيقونات "نسخ القيمة" على الـ KPIs.
3. **إثبات الفاقد والتلف الجمركي ومحاضر النقص (Discrepancy & Damage Registry)**: ![](../screenshots/39-customs-clearance-tab-3-discrepancy-damage-registry.png). فيه 4 KPIs (إجمالي المحاضر، إجمالي الخسائر المقدرة، قيد المتابعة، معتمدة للتعويض) وزرار "تحرير محضر مشترك جديد"، وتصدير (تصدير جدول نصي، تصدير جدول إكسيل، طباعة تقرير بي دي إف، نسخ حافظة المحاضر).
4. **سداد الرسوم والضرائب الجمركية النهائية (Final Customs Duty Payment & Release)**: ![](../screenshots/39-customs-clearance-tab-4-final-customs-duty-payment-release.png). فيه 4 KPIs (المطلوبة، المسددة، قيد السداد، صافي الفروقات) وتصدير (تصدير جدول، تصدير إكسل، طباعة تقرير، نسخ الحافظة) وأيقونات "نسخ القيمة".

### الـ Dialogs
- **تسجيل معاملة تخليص جمركي وميناء جديدة:** ![](../screenshots/39-customs-clearance-dialog-add.png). الحقول في الجدول اللي فوق، وفيه أيقونة رفع/استخلاص إذن نافذة فوق. أخطاء الـ validation (رسالة حمرا تحت الملف "يرجى اختيار ملف الشحنة"): ![](../screenshots/39-customs-clearance-dialog-add-validation.png). أزرار الـ dialog: "إلغاء" و "حفظ المعاملة"، وزرار الحفظ عليه loading spinner (`:1704`).
- **`_DutyPaymentDialog`**: المبلغ المسدد فعلياً (إلزامي)، ورقم إيصال السداد البنكي (إلزامي)، وسبب الفرق. عليه loading. مش متصوّر (مفيش سجلات).
- **`_FinalReleaseDialog`**: رقم تصريح الإفراج. عليه loading. مش متصوّر.
- **Dialogs أزرار الهيدر** (CS-01 لحد CL-05)، و `UnderBondReleaseDialog`، و `SearchAndCloneCustomsClearanceDialog`: مش متصوّرين. أزرار الهيدر مش باينة أصلاً في الصورة (شوف الملاحظات).

### التصدير والطباعة
- Excel و PDF لسجل التخليص: `TableExportService` ← `FileSaveHelper.exportAndSaveFile` (`:398` و `:439`)، بعنوان PDF "Customs Clearance & Port Operations Registry".
- تصدير منفصل في كل تاب (TSV، Excel، PDF، نسخ).
- على الويب الحفظ بيتم بـ File System Access API أو `<a download>` (فرق خاص بالويب).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| Critical | العينات المسحوبة ومحاضر العجز ومحاضر الفاقد والتلف **متخزنة في state محلي بس** (`List<Map>` جوه الـ State)، ومبتتبعتش للباك إند. أول ما المستخدم يقفل الشاشة كل المحاضر بتضيع | `customs_clearance_screen.dart:57`، `:58`، `:59`، `:60`، `:1036`، `:1053` | اعمل endpoints وجداول للعينات والمحاضر (مع Alembic migration) واربط التابات بيها |
| High | "تعديل" معاملة التخليص بينادي `createRecord` (`POST`) بدل التعديل. الباك إند بيرفض أي بيان تاني لنفس الملف بـ 400 ("يوجد بالفعل بيان تخليص جمركي مسجل لهذا الملف")، فـ **التعديل من الشاشة مبيشتغلش خالص** وبيطلّع خطأ. الـ provider مفيهوش update أصلاً، مع إن `PUT /{record_id}` موجود | `:1691`، `providers/customs_clearance_provider.dart:219`، `modules/customs_clearance/service.py:61`–`:69`، `modules/customs_clearance/router.py:124` | ضيف `updateRecord` بـ `PUT` واستخدمه لما يكون `recordToEdit != null && !isCloneDraft` |
| High | زرار "تسجيل نتيجة الفحص المعملي" في `UnderBondReleaseDialog` بيبعت لـ `/lab-inspection-result`، والباك إند مسجّل `/lab-test-result`، فالطلب هيرجع **404** دايماً | `widgets/under_bond_release_dialog.dart:142`، `modules/customs_clearance/router.py:156` | وحّد اسم المسار |
| High | أزرار الهيدر التسعة (CS-01 لحد CL-05) مش باينة: بيظهر بس زرار الذكاء الاصطناعي وجزء مقطوع من "تفويض المخلص"، والباقي خارج الشاشة من غير overflow menu | `39-customs-clearance-main.png` (الهيدر)، `:517` (9 أزرار في `headerActions`) | انقلهم لـ toolbar جوه التاب أو لـ `PopupMenuButton` "إجراءات المرحلة" |
| High | لما الشاشة تتفتح من الـ sidebar (من غير `initialImportFileId`)، أزرار الهيدر بتشتغل على **أول ملف في القايمة** (`files.first`) من غير ما المستخدم يختار (الـ dialog بيعرض اسم الملف بس ومفيهوش اختيار)، فالمستخدم ممكن يفوّض مخلص أو يسجل سداد على ملف غلط | `:546`، `:547`، `:548`، `:549`، `:550`، `:551` (ونفس النمط في باقي الأزرار) | اطلب اختيار الملف صراحة (SearchableDropdown) قبل فتح الـ dialog |
| Medium | خطأ الحفظ بيظهر كـ `e.toString()` خام (DioException) بدل رسالة `detail` من الباك إند | `:1698` | استخرج `response.data['detail']` |
| Medium | مفيش زرار حذف (Soft Delete) أو استرجاع للسجلات في الكارت، مع إن الـ provider والـ router فيهم `softDeleteRecord` و `/restore` | `providers/customs_clearance_provider.dart:261`، `:270`؛ tooltips الكارت `:1111`–`:1154` | ضيف حذف ناعم مع تأكيد |
| Low | فلتر الحالة `DropdownButton` عادي، والمسار الجمركي `DropdownButtonFormField`. القيم enum مش reference data، بس ده مخالف لتوحيد الـ Skill، وشاشة 40 بتستخدم `SearchableDropdownField` لنفس الغرض | `:900`، `:1572` | وحّدها على `SearchableDropdownField` |
| Low | كل الأزرار `ElevatedButton` بدل `AppButton` | `:518`، `:917`، `:1657` | استخدم `AppButton` مع `isLoading` |
| Low | نصوص أزرار الهيدر ورسايلها عربي hard-coded مش من l10n (زي "تفويض المخلص (CS-01)" و "لا توجد ملفات شحنات مسجلة")، فمش هتتترجم في الوضع الإنجليزي | `:538`، `:543`، `:1154` | انقلها لـ ARB |
| Low | عنوان الهيدر والتابات الرأسية و "Operations & Stages" بالإنجليزي في الوضع العربي، بسبب مشكلة الـ locale العامة في `main.dart` (`supportedLocales` مش محددة) | `39-customs-clearance-main.png` | إصلاح عام واحد في `main.dart` |
| Low | label "رقم الإقرار الجمركي (46)" مقطوع في الـ dialog | `39-customs-clearance-dialog-add.png` | label أقصر أو عرض أكبر للحقل |
| Low (ويب) | `Refused to set unsafe header "Accept-Encoding"` ×6: سلوك خاص بالمتصفح، مش bug على الديسك توب | `runtime-errors.json` ← `39-customs-clearance` | متبعتش الهيدر لما يكون `kIsWeb` |
