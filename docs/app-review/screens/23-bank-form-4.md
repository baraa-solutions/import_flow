# النموذج الإحصائي والتحويل البنكي نموذج 4 (Bank Form 4)
![](../screenshots/23-bank-form-4-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
الشاشة دي بتسجل طلب توثيق "نموذج 4" (Form 4 للتحصيل أو الدفع المقدم) عند البنك، أو أي مستند بنكي تاني زي L/C، لملف شحنة معين: البنك، والمبلغ، والعملة، وتاريخ التقديم، وقايمة المستندات اللي هتتسلم للبنك. وبعدين بتتابع اعتماد البنك واستلام المستند في سجل النماذج البنكية.

- **المستخدمين:** موظف الاستيراد، والحسابات والبنوك.
- **المرحلة:** المرحلة 4 "التوثيق الرقمي والاعتماد البنكي" (`stageCode: 'PHASE-4: STEP_12'`، `bank_form4_screen.dart:435`).
- **الكود:** `BP-015` في `docs/phase_03_import_documentation.md` ("Process Letter of Credit (L/C) or Form 4")، لكن نفس العملية `BP-016` في `doc.md:1732`.

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 4: التوثيق الرقمي والاعتماد البنكي" ← "النموذج الإحصائي والتحويل البنكي نموذج 4" (index 16، و index 17 بيفتح تاب السجل).
- **الصلاحية:** أي مستخدم عامل login (`modules/import_documentation/router.py:14`). مفيش RBAC على الإنشاء ولا التعديل ولا الحذف ولا الاستلام (`router.py:136-192`).

## مكونات الشاشة
الـ header عبارة عن `VerticalStageScaffold` بعنوان "Bank Form 4 & Financial Endorsement" وبـ badge "Bank Form 4"، ومعاه تابين رأسيين.

### الحقول
تاب "طلب وتوثيق نموذج 4" (`23-bank-form-4-tab-1-form-4-request-checklist.png`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختر ملف الشحنة المرتبط بإصدار نموذج 4 | `SearchableDropdownField<int>` (`isRequired: true`) | نعم | بيتفحص وقت الحفظ بـ SnackBar "اختر ملف الشحنة أولاً" (`:1449-1454`)، مش جوه الفورم | `GET /api/v1/import-files` |
| Transaction / Bank Doc Type * | `SearchableDropdownField<String>` | نعم | — | قايمة ثابتة (الافتراضي: Form 4 - Collection / Advance Payment) |
| Bank Reference / Credit No. (If available) | `TextFormField` | لا | لو فاضي بيتبعت `'PENDING'` (`:1466`) | يدوي |
| البنك المصدر المعتمد | `SearchableDropdownField<int>` (`isRequired: true`) | نعم في الشكل | في صورة الـ validation مطلعش عليه خطأ | `GET /api/v1/external-service-providers` (البنوك) |
| المبلغ المطلوب توثيقه | `TextFormField` رقمي | نعم | غير فاضي: "هذا الحقل مطلوب" (`:762`) | **الافتراضي 62300.0 مكتوب ثابت في الكود** (`:51`) |
| عملة التحويل | `SearchableDropdownField<String>` | نعم | — | `GET /api/v1/currencies` (الافتراضي USD) |
| تاريخ تقديم الطلب للبنك | حقل تاريخ | نعم | — | افتراضي: النهارده |
| ملاحظات وتوجيهات خاصة لفرع البنك | `TextFormField` | لا | — | يدوي |
| قائمة المستندات المرفقة بملف نموذج 4 للبنك | 8 checkboxes (الفاتورة المبدئية المعتمدة *، قائمة التعبئة *، شهادة المنشأ الموثقة *، مسودة بوليصة الشحن *، إشعار التسجيل المسبق نافذة *، وثيقة التأمين البحري، طلب تحويل البنك موقع ومختوم *، إيصال سداد المصاريف الإدارية) | 6 منهم عليهم نجمة | مفيش أي تحقق إن المستندات الإلزامية متعلّم عليها | ثابتة (`:896-903`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة عند هذه المرحلة | أدوات دورة حياة الملف | `POST /api/v1/import-files/{id}/hold` وغيره | أي مستخدم |
| أيقونة الاستنساخ في الـ header، و "نسخ من نموذج سابق" | بيفتحوا `SearchAndCloneBankForm4Dialog` وبعده `CloneEntityReviewDialog` | `GET /banking-documents` | أي مستخدم |
| تحديث | إعادة تحميل | `GET /banking-documents`، `/import-files`، `/currencies`، `/external-service-providers` | — |
| العودة للداش بورد | رجوع | — | — |
| حفظ وتسجيل طلب نموذج 4 | `_saveBankingDoc` (`:1447`). فيه spinner (`_isSavingForm4`)، وبعد النجاح بيروح لتاب السجل | `POST /api/v1/import-documentation/banking-documents` أو `PUT .../{id}` | أي مستخدم |
| الانتقال لسجل النماذج البنكية | بيغير التاب | — | — |
| طلب نموذج 4 جديد (في السجل) | بيرجع للفورم فاضي | — | — |
| Copy Table / Export Excel / Export PDF (في السجل) | `TableExportService` وبعده `FileSaveHelper` | — | — |
| تعديل / Edit، واستلام / اعتماد (في صفوف السجل) | `_openReceiveBankDocDialog` | `POST /banking-documents/{id}/receive` | أي مستخدم |
| حذف (في صفوف السجل) | soft delete (`repository.py:288-289` بيحط `is_active = False`) | `DELETE /banking-documents/{id}` | أي مستخدم |

### الجداول
**سجل النماذج البنكية** (`23-bank-form-4-tab-2-bank-form-4-registry.png`): الأعمدة، بنفس ترتيب التصدير (`:1493-1500`): كود المستند، ملف الشحنة، البنك المعتمد، المبلغ والعملة، تاريخ الطلب، حالة الاعتماد ("تم الاعتماد" لو `Received`، أو "قيد الإجراء البنكي"). فيه بحث "بحث في سجل النماذج البنكية بالرمز، البنك، رقم الملف...". في بيانات المراجعة كان فاضي: "لم يتم العثور على نماذج بنكية مطابقة للبحث".

### التابات
1. **Form 4 Request & Checklist**: الفورم اللي فوق. الصور: `23-bank-form-4-main.png` و `23-bank-form-4-tab-1-form-4-request-checklist.png`.
2. **Bank Form 4 Registry**: السجل. الصورة: `23-bank-form-4-tab-2-bank-form-4-registry.png`.

### الـ Dialogs
- **الإضافة:** مفيش dialog. زرار "طلب نموذج 4 جديد" بيرجعك للفورم اللي في الصفحة (`capture-manifest.json`: "add button did not open a modal dialog"). الصورة: `23-bank-form-4-dialog-add.png`.
- **أخطاء الـ validation:** `23-bank-form-4-dialog-add-validation.png`. بعد ما تمسح المبلغ وتدوس حفظ، بيظهر "هذا الحقل مطلوب" بالأحمر تحت "المبلغ المطلوب توثيقه" بس. ملف الشحنة والبنك مطلعش عليهم خطأ، رغم إن الاتنين فاضيين.
- **استلام / اعتماد المستند البنكي** (`_openReceiveBankDocDialog`، `:255-345`، متصورش): Bank Reference No. * (إلزامي)، وتاريخ الاستلام / الاعتماد * (إلزامي)، وملاحظات التوثيق والفرع (اختياري)، وزراير إلغاء وتأكيد (فيها `isSubmitting`).
- `SearchAndCloneBankForm4Dialog` و `CloneEntityReviewDialog`: متصوروش، لأن السجل كان فاضي.

### التصدير والطباعة
Excel و PDF للسجل عن طريق `TableExportService` (`:1492-1570`)، وده بيستدعي `FileSaveHelper.exportAndSaveFile`. اسم المرحلة في الملف "سجل النماذج البنكية" أو "Bank Form 4 Registry"، والكود `Bank_Form4_Registry`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | المبلغ المطلوب توثيقه متملي تلقائياً بـ 62300.0، ده رقم وهمي hard-coded في فورم مالي، ومن غير ما يكون فيه ملف شحنة متختار. الرقم ده ممكن يتحفظ غلط | `23-bank-form-4-main.png`، `bank_form4_screen.dart:51` | يبدأ فاضي، أو يتملا من قيمة الفاتورة / أمر الشراء بتاع الملف المختار |
| High | checklist المستندات المرفقة مش بتتبعت في الـ payload بتاع الحفظ، فالعلامات بتضيع. كمان الحفظ مسموح حتى لو فيه مستندات إلزامية (*) مش متعلّم عليها | `bank_form4_screen.dart:1458-1468` (الـ payload من غير checklist)، `:896-903` | إضافة `checklist` للـ schema والـ payload، ومنع الحفظ لو ناقص مستند إلزامي |
| Medium | ملف الشحنة والبنك معمول عليهم `isRequired: true`، لكن مطلعش عليهم خطأ تحت الحقل. ملف الشحنة بيتفحص بـ SnackBar بعد الـ validate، والبنك مش بيتفحص خالص (`bank_id` ممكن يتبعت null) | `23-bank-form-4-dialog-add-validation.png`، `bank_form4_screen.dart:1448-1454`، `:1461` | `validator` حقيقي للحقلين جوه الـ `Form` |
| Medium | Labels إنجليزي hard-coded بتفرع على `isAr`: "Transaction / Bank Doc Type *" و "Bank Reference / Credit No. (If available)"، وعنوان الشاشة "Bank Form 4 & Financial Endorsement". بتطلع إنجليزي في الوضع العربي بسبب مشكلة الـ locale، وأصلاً مخالفة لقاعدة `l10n` | `23-bank-form-4-main.png`، `bank_form4_screen.dart:638`، `:671`، `:436` | مفاتيح `l10n` |
| Medium | نص الـ label والـ hint راكبين على بعض في dropdown ملف الشحنة والبنك (نصين فوق بعض) | `23-bank-form-4-main.png` (أعلى الفورم وحقل البنك) | إصلاح `SearchableDropdownField` لما مفيش قيمة |
| Medium | مخالفات UI: 8 `ElevatedButton`، و 74 `Colors.xxx`، و 10 `Color(0x…)`، ومفيش `AppButton`. والـ header لونه `AppTheme.wcagCobalt` | `bank_form4_screen.dart:338`، `:913`، `:1050`، `:439` | `AppButton` و `AppTheme` |
| Low | لو رقم مرجع البنك فاضي بيتحفظ كنص "PENDING" بدل null | `bank_form4_screen.dart:1466` | null وحالة منفصلة |
| Low | ترقيم الـ BP مش متسق: BP-015 في phase_03، و BP-016 في `doc.md` | `docs/phase_03_import_documentation.md`، `doc.md:1732` | توحيد الترقيم |
| Low | مشكلة الـ locale المعروفة: التابات الرأسية وعنوان الـ header بالإنجليزي، والتخطيط LTR | `23-bank-form-4-main.png` | `supportedLocales` |
| Low | console (ويب بس): `Refused to set unsafe header "Accept-Encoding"` | `runtime-errors.json` ← `23-bank-form-4` | — |
