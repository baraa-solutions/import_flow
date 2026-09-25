# اعتمادات الميزانية وسداد الموردين (Finance Approvals & Budget)
![](../screenshots/20-financial-approvals-main.png)

> التصوير اتعمل على **Flutter Web (release)** مش Windows desktop، لأن Visual Studio مش متسطّب على جهاز المراجعة. قاعدة البيانات scratch ومفيهاش ميزانيات ولا طلبات سداد متسجّلة، عشان كده السجلات فاضية في الصور.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** شاشة المرحلة المالية للملف. من خلالها بيتعمل طلب سداد (دفعة مقدمة أو تحويل) للمورد، وبتتعمل ميزانية الملف التقديرية وبتتعتمد (بضاعة + نولون + جمارك وضرايب + تخليص ونقل)، وبتتسجّل الطلبات والميزانيات، ومنها بيتفتح تاب مطابقة السويفت MT103.
- **المستخدمين:** الإدارة المالية (بتعمل الطلب وبتعتمده)، والمدير المالي (بيعتمد الميزانية)، ومسؤول الاستيراد (بيربط الطلب بملف الشحنة وأوامر الشراء).
- **المرحلة:** المرحلة 2، "بداية الشحنة والتسجيل المسبق" في الـ sidebar، و Phase 2 في `docs/phase_02_financial_approval.md`.
  - **BP-012** Create Payment Request: تاب طلبات السداد + سجل طلبات السداد.
  - **BP-013** Approve Import Budget: تاب اعتماد الميزانية + سجل الميزانيات.
  - اعتماد الميزانية بينادي `sync_budget_lifecycle_stage` عشان يحدّث مرحلة الملف في دورة الحياة (`modules/financial_approval/service.py:622`).

## طريقة الوصول والصلاحية
- **الـ Sidebar:** "المرحلة 2: بداية الشحنة والتسجيل المسبق" ← "اعتمادات الميزانية وسداد الموردين" (index 8). الـ indices 9 و 10 بيفتحوا نفس الشاشة على التاب 2 و 3، ومالهمش عنصر في الـ sidebar (`inventory.json`).
- **Scaffold:** `VerticalStageScaffold` (Type A)، ومعاه تابات رأسية، وأزرار التحكم في دورة حياة المرحلة (`financial_approval_screen.dart:2640`).
- **الصلاحية:** الـ router كله محمي بـ `Depends(get_current_user)` (`modules/financial_approval/router.py:43`)، يعني أي مستخدم مسجّل دخول. مفيش RBAC على الاعتماد ولا السداد. `PUT /settings/variance-threshold` بس هو اللي محتاج `require_admin` (`router.py:455`).
- **اختصار:** `Ctrl+D` في تاب طلبات السداد بيفتح "بحث واستنساخ طلب سداد".

## مكونات الشاشة

### الحقول
**تاب 1: طلبات السداد المالي للمورد** (الصورة: `20-financial-approvals-main.png`)

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| نص رسالة السويفت (لصق) | TextField متعدد الأسطر | لا | مفيش | لصق يدوي، أو `POST /financial-approval/swift/smart-extract` لتعبئة الفورم |
| ملف الشحنة | `SearchableDropdownField<int?>` | عليه `*` بس **مش متحقق منه** | مفيش validator، واختيار "-- غير مرتبط --" مقبول | `importFilesProvider` ← `GET /import-files`؛ لما تختار ملف بينادي `GET /financial-approval/prefill/{id}` |
| عنوان طلب السداد | TextFormField | نعم | مش فاضي (الباك إند: min_length=3) | إدخال يدوي |
| اختر المورد من البيانات المرجعية | `SearchableDropdownField<int?>` | لا | مفيش | `suppliersProvider` ← `GET /suppliers` |
| المورد المستفيد | TextFormField | نعم | مش فاضي (الباك إند: min_length=2) | بيتملي من المورد المختار أو يدوي |
| طريقة / نوع السداد | **TextFormField نص حر** | عليه `*` | مفيش validator | القيمة الافتراضية "Advance Payment" |
| نسبة الدفعة المقدمة (10/20/30/50/100%) | ChoiceChips | لا | 0–100 في الباك إند | بتظهر لما يبقى فيه أوامر شراء مربوطة بالملف |
| المبلغ المطلوب بالعملة | TextFormField رقمي | نعم | رقم > 0 | يدوي أو محسوب من النسبة |
| العملة | `SearchableDropdownField<String>` | نعم | مفيش | `currenciesProvider` ← `GET /currencies` |
| سعر الصرف (EGP) | TextFormField رقمي | نعم | مفيش validator في الواجهة (الباك إند: > 0) | `latestCommercialRate` للعملة، ولو مش موجود بيرجع **50.0** ثابت |
| تاريخ تقديم الطلب | Date picker | نعم | — | افتراضي النهارده |
| تاريخ الاستحقاق المطلوب | Date picker | نعم | — | افتراضي النهارده + 12 يوم |
| اسم بنك المورد / كود السويفت / رقم الحساب أو الآيبان | TextFormField ×3 | لا | مفيش | من بيانات المورد، أو يدوي، أو من استخراج السويفت |
| ملاحظات طلب السداد | TextFormField | لا | — | يدوي |

**تاب 2: اعتماد الميزانية الاستيرادية** (الصورة: `20-financial-approvals-tab-2-import-budget-approval.png`)

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة | `SearchableDropdownField<int?>` | عليه `*` بس مش متحقق منه | مفيش | `GET /import-files`، وبعدها `GET /financial-approval/prefill/{id}` |
| عنوان الميزانية الاستيرادية | TextFormField | نعم | مش فاضي | يدوي |
| قيمة الفاتورة المبدئية (USD) | رقمي | لا | مفيش (الباك إند: ≥ 0) | prefill من أوامر الشراء |
| تكلفة النولون المقدرة (USD) | رقمي | لا | مفيش | prefill من عروض النولون |
| سعر الصرف (EGP) | رقمي | لا | مفيش | prefill، أو 50.0 افتراضي |
| الضرائب والجمارك والـ VAT (EGP) | رقمي | لا | مفيش | prefill من الدراسة الجمركية |
| أتعاب التخليص والنقل (EGP) | رقمي | لا | مفيش | prefill من عرض التخليص |
| ملاحظات وتوجيهات اعتماد الميزانية | نص | لا | — | يدوي |

**تاب 3 و 4 (السجلات):** مربع بحث نصي ("البحث بكود الميزانية أو العنوان أو كود الشحنة..." في تاب 3، و "البحث بكود الطلب أو اسم المورد أو رقم الملف أو العنوان..." في تاب 4)، وفلتر حالة: Chips في تاب 3 ("جميع الحالات" / "ميزانيات معتمدة" / "قيد المراجعة / مسودة"، وكل chip جنبه العدد)، و "تصفية حسب الحالة" `SearchableDropdownField` في تاب 4 (All/Draft/Approved/Paid/Reconciled).

**عناصر مشتركة في كل التابات:** شارة "Budget Approval" تحت العنوان، وقايمة التابات الرأسية "Operations & Stages" وزرار "إخفاء القائمة لتوسيع الشاشة" بتاعها. الـ sidebar والـ top bar بتوع الـ shell مشروحين في شاشة الـ home shell.

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة (Header) | بيفتح dialog تختار فيه الملف وبعدها بيتخطى المرحلة (`ShipmentStageLifecycleControl`) | `POST /lifecycle-board/stages/skip` | أي مستخدم مسجّل |
| إيقاف الشحنة عند هذه المرحلة (Header) | بيوقف الملف عند المرحلة دي | عن طريق `ShipmentStageLifecycleControl` | أي مستخدم مسجّل |
| محاكي الأزمات وتذبذب الصرف | بيفتح `WhatIfSimulatorDialog` | `/api/v1/simulation/*` | أي مستخدم مسجّل |
| تحديث (أيقونة) | بيعيد تحميل الطلبات والميزانيات والملفات وأوامر الشراء والموردين والعملات | GETs متعددة | — |
| العودة للداش بورد | رجوع للوحة التحكم | — | — |
| بحث واستنساخ طلب سداد | `SearchAndClonePaymentDialog`، وبعدها مراجعة الاستنساخ | `POST /payment-requests/{id}/clone` | أي مستخدم مسجّل |
| رفع مستند السويفت | FilePicker (bytes، بيشتغل على الويب) واستخراج | `POST /financial-approval/swift/smart-extract-file` | — |
| تنفيذ المطابقة والاعتماد المالي / لصق نص رسالة السويفت / تفريغ | استخراج بيانات السويفت من النص وتعبئة الفورم | `POST /financial-approval/swift/smart-extract` | — |
| إصدار طلب السداد للإدارة المالية | بيحفظ الطلب (إنشاء أو تعديل) وبيفتح dialog التفاصيل. **فيه loading state** | `POST /payment-requests` / `PUT /payment-requests/{id}` | أي مستخدم مسجّل |
| بحث واستنساخ اعتماد ميزانية | `SearchAndCloneBudgetDialog` | `POST /import-budgets/{id}/clone` | — |
| تحديث / تفريغ (تاب 2) | بيعيد الـ prefill، أو بيفضّي الفورم | `GET /prefill/{id}` | — |
| حفظ مؤقت | بينادي `_saveImportBudget` | `POST /import-budgets` | — |
| التصديق واعتماد الميزانية | **بينادي نفس `_saveImportBudget` بنفس الـ payload** (`financial_approval_screen.dart:3739` و `:3753`)، يعني بيعمل مسودة بس. الاعتماد الفعلي بيحصل من الـ dialog بعد كده | `POST /import-budgets`، وبعدها من الـ dialog `POST /import-budgets/{id}/approve` | أي مستخدم |
| تصدير Excel (تاب 2) | `FinancialExportService.exportBudgetToExcel`، وده بيطلع **CSV** | — (محلي) | — |
| طباعة وتصدير | `printOrSaveBudgetPdf` عن طريق `Printing.layoutPdf` | — | — |
| مزامنة (بانر فرق التكلفة) | بيحدّث الميزانية من التكاليف الحية | `POST /import-budgets/{id}/sync` | — |
| اعتماد ميزانية جديدة (تاب 3، في الـ header) و "اعتماد ميزانية جديدة الآن" (في الحالة الفاضية) | بيرجعوا لتاب 2 | — | — |
| تحديث (تاب 3) | بيعيد جلب الميزانيات (`saved_budgets_registry_tab.dart:158`) | `GET /financial-approval/import-budgets` | — |
| تصدير Excel (تاب 3) | `exportBudgetsListToExcel` للقايمة المفلترة، وبيطلع **CSV** (`saved_budgets_registry_tab.dart:276`، `financial_export_service.dart:534`) | — (محلي) | — |
| إجراءات الصف في سجل الطلبات (عرض/تعديل/استنساخ/طباعة/حذف) | `onView/onEdit/onClone/onPrint/onDelete` (`financial_approval_screen.dart:4020-4024`) | `GET`، `PUT`، `clone`، والحذف `DELETE /payment-requests/{id}` (soft delete) | — |
| شريط "عمليات البيانات" (تاب 4): إعادة تحميل حية / تصدير Excel / تصدير PDF / استيراد Excel | `MasterDataToolbarWidget(moduleEndpoint: 'financial-approval')` | endpoints الـ toolbar المشتركة | — |

### الجداول
- **سجل طلبات السداد والتحويلات (تاب 4):** `DataTable`، والأعمدة: الإجراءات، كود الطلب، ملف الشحنة، المورد المستفيد (+ العنوان)، البنك/السويفت، نوع السداد، المبلغ المطلوب بالعملة، المعادل بالجنيه، تاريخ الطلب/الاستحقاق، الحالة. البحث بالكود أو اسم المورد أو العنوان أو كود الملف. الفلترة بالحالة. **مفيش ترتيب** بالضغط على العمود (مفيش `onSort`).
- **سجل الميزانيات المعتمدة (تاب 3):** قايمة كروت (`ListView`) مش جدول. فوقيها KPIs: إجمالي الميزانيات، معتمدة، قيد المراجعة/مسودة، إجمالي القيمة التقديرية. وفيه Chips حالة: الكل/معتمدة/قيد المراجعة. البحث بالكود أو العنوان أو كود الملف أو المعتمِد.
- **تقرير توزيع بنود الميزانية (تاب 2):** جدولين للقراءة بس: (1) الفاتورة والنولون بالعملة الأجنبية ومعادلهم بالجنيه، (2) الجمارك والتخليص بالجنيه والجهة المسؤولة، وتحتهم إجمالي الميزانية المعتمدة.
- **أوامر الشراء المربوطة (تاب 1):** بيظهر بس لما يكون فيه ملف مربوط. الأعمدة: رقم الأمر، المشروع، نوع السداد، العملة، القيمة، الحالة، الإجراءات.

### التابات
1. **طلبات السداد المالي للمورد:** فورم BP-012، وفوقه أداة استخراج السويفت.

   ![](../screenshots/20-financial-approvals-tab-1-payment-requests.png)
2. **اعتماد الميزانية الاستيرادية:** فورم BP-013، ومعاه تقرير التوزيع وأزرار الحفظ والاعتماد والتصدير.

   ![](../screenshots/20-financial-approvals-tab-2-import-budget-approval.png)
3. **سجل الميزانيات المعتمدة:** KPIs وفلاتر وقايمة كروت (فاضية في بيانات المراجعة)، ورسالة "لا توجد اعتمادات ميزانية مطابقة لمعايير البحث" مع زرار "اعتماد ميزانية جديدة الآن".

   ![](../screenshots/20-financial-approvals-tab-3-saved-budgets-registry.png)
4. **سجل طلبات السداد والتحويلات:** Toolbar وبحث وفلتر وجدول (فاضي، وبيظهر "لا توجد طلبات سداد مالي مطابقة لخيارات البحث والتصفية").

   ![](../screenshots/20-financial-approvals-tab-4-payment-requests-registry.png)
5. **استخراج ومطابقة السويفت (MT103):** بيعرض `SwiftReconciliationScreen` مدمجة، وشرحها في [21-swift-reconciliation.md](21-swift-reconciliation.md).

   ![](../screenshots/20-financial-approvals-tab-5-swift-mt103-reconciliation.png)

### الـ Dialogs
- **مفيش dialog إضافة:** زرار "اعتماد ميزانية جديدة" في تاب 3 بيرجّع للفورم اللي في تاب 2. عشان كده الـ harness صوّر الفورم نفسه على إنه dialog-add (`capture-manifest.json`: "add button did not open a modal dialog").
  - الفورم:

    ![](../screenshots/20-financial-approvals-dialog-add.png)
  - أخطاء الـ validation بعد "حفظ مؤقت" والفورم فاضي:

    ![](../screenshots/20-financial-approvals-dialog-add-validation.png)

    الخطأ الوحيد اللي ظهر هو "هذا الحقل مطلوب" تحت العنوان. ملف الشحنة عليه `*` ومظهرش عليه خطأ.
- **تفاصيل طلب السداد** `_showPaymentDetailsDialog` (`:1884`): فيه ملخص للمبالغ، وطباعة/حفظ PDF، وتحميل Excel، ومشاركة واتساب، ومشاركة بريد، واستخراج ومطابقة السويفت، وحقل مرجع السويفت. الإجراءات: "اعتماد الطلب" (`POST /payment-requests/{id}/approve`) و "تأشير كمدفوع" (`POST /payment-requests/{id}/pay`). **مفيش صورة** لأن مفيش طلبات في البيانات.
- **تفاصيل الميزانية** `_showBudgetDetailsDialog` (`:2243`): PDF و Excel وواتساب وبريد، وزرار "التصديق واعتماد الميزانية" (`POST /import-budgets/{id}/approve`). مفيش صورة.
- **مشاركة واتساب / بريد** (`:2086`، `:2161`، `:2419`، `:2494`): رقم أو إيميل، ومعاينة للرسالة، ونسخ، وفتح التطبيق.
- **بحث واستنساخ** (`SearchAndClonePaymentDialog` و `SearchAndCloneBudgetDialog`) ومعاهم `CloneEntityReviewDialog`.
- **تأكيد الحذف** (`:946`) و **ConcurrencyConflictDialog** لو رجع 409.

### التصدير والطباعة
- **PDF:** طلب السداد والميزانية وإيصال السويفت عن طريق `Printing.layoutPdf` (`financial_export_service.dart:245`، `:485`، `:1059`). ده بيفتح نافذة الطباعة/الحفظ بتاعة النظام، ومش بيعدّي على `FileSaveHelper.exportAndSaveFile`.
- **"Excel":** كله نص CSV بيتحفظ عن طريق `FileSaveHelper.saveText` بامتداد `['csv','xlsx']` (`financial_export_service.dart:301`، `:524`، `:566`، `:608`، `:805`).
- **واتساب/بريد:** `launchUrlNative` بيشتغل على Windows بس (`financial_export_service.dart:1065`).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | أي مستخدم مسجّل دخول يقدر يعتمد طلب سداد أو ميزانية أو يأشّر طلب إنه مدفوع أو يتجاوز الفرق. مفيش RBAC، وده ضد فصل المهام في العمليات المالية | `modules/financial_approval/router.py:43` (مفيش غير `get_current_user`)، approve `:269-274`، pay `:277-285`، budget approve `:365-373`، override-variance `:409-424` (بياخد المستخدم من `resolve_user` بس مش بيتحقق من الدور) | اعمل dependency صلاحية (FINANCE_MANAGER أو ADMIN) على approve و pay و override-variance |
| High | `execute_payment_service` بيحوّل الحالة لـ "Paid" من غير ما يتأكد إن الطلب اتعتمد، و `approve_payment_request_service` بيحط "Approved" من غير `validate_status_transition`، فممكن يترجع طلب Paid لحالة Approved | `modules/financial_approval/service.py:323`، `:363` | نادِ `validate_status_transition` في approve و pay |
| High | اسم المعتمِد متسجّل ثابت "Finance Manager" بدل المستخدم الحالي، وطلب السداد مش بيسجّل مين اعتمده خالص. ده كسر لـ Audit Trail | `router.py:370`، `service.py:546`، `:568`؛ و `model.py:11-90` (`PaymentRequestSession` مفيهوش `approved_by`) | خُد `current_user` من الـ dependency واكتب `approved_by` منه |
| Medium | زرار "التصديق واعتماد الميزانية" تحت الفورم بينادي نفس دالة "حفظ مؤقت" وبنفس الـ payload، فبيعمل مسودة بس وبعدها بيفتح dialog. الاسم مضلّل | `financial_approval_screen.dart:3739`، `:3753`، `:1786` | يا إما يحفظ وبعدها ينادي `/approve` مباشرة، يا إما يتغيّر اسمه لـ "حفظ ومراجعة" |
| Medium | "ملف الشحنة" عليه `*` في التابين، بس مفيش validator والباك إند بيقبل `null`. في صورة الـ validation مظهرش عليه خطأ | `20-financial-approvals-dialog-add-validation.png`، `financial_approval_screen.dart:2827`، `schemas.py:13` | يا إما تشيل الـ `*`، يا إما تضيف validator وتخلي الحقل إلزامي في الباك إند |
| Medium | سعر الصرف الافتراضي ثابت 50.0 لو العملة ملهاش سعر، ومش بيتقال للمستخدم. ده بيأثر على المعادل بالجنيه وعلى الميزانية | `financial_approval_screen.dart:125`، `:500`، `:1796`، `schemas.py:25` | متحطش قيمة افتراضية، وخلّي الحقل إلزامي وبرسالة واضحة لو مفيش سعر في `currencies` |
| Medium | "طريقة / نوع السداد" نص حر، مع إن الدوكيومنت محدد قيم ثابتة (SWIFT / L/C / CAD / Against B/L) | `financial_approval_screen.dart:2927`، `docs/phase_02_financial_approval.md` | خليه `SearchableDropdownField` بقيم enum |
| Medium | "تصدير Excel" بيطلع CSV وبيسمح بامتداد `.xlsx`، فلو اليوزر اختار xlsx هيتحفظ ملف تالف. واسم الملف فيه timestamp ومش ماشي على تسمية `[Stage Name] - [File Code]` | `financial_export_service.dart:299-306` | استخدم مكتبة xlsx أو خليه `.csv` بس، واستخدم `FileSaveHelper.exportAndSaveFile` بالتسمية القياسية |
| Medium | حقول مبالغ الميزانية مالهاش validators، فينفع تتحفظ ميزانية كل قيمها صفر وإجماليها 0.00 | `20-financial-approvals-tab-2-import-budget-approval.png`، `financial_approval_screen.dart:3490-3570` | لازم يبقى فيه قيمة فاتورة > 0 على الأقل قبل الحفظ أو الاعتماد |
| Medium | زرار الاعتماد جوه dialog الميزانية مالوش loading ولا try/catch. لو حصل خطأ مش بيبان لليوزر، والضغط أكتر من مرة ممكن يبعت الطلب أكتر من مرة | `financial_approval_screen.dart:2401-2408` | استخدم `AppButton(isLoading:)` وأظهر SnackBar بالخطأ |
| Medium | مخالفة لـ UI_SCREEN_STANDARDS: صفر `AppButton`، و 52 `ElevatedButton`، و 26 `OutlinedButton`، و 241 استخدام لـ `Colors.xxx`، و 27 `Color(0x...)` | `financial_approval_screen.dart` (مثلاً `:237`، `:829`، `:1992`) | انقلها لـ `AppButton` و `AppTheme` |
| Low | عنوان الـ header وأسماء التابات الرأسية ظاهرة بالإنجليزي في الوضع العربي. ده من المشكلة المعروفة إن `main.dart` مش محدد `supportedLocales`. نفس المشكلة بتقلب ترتيب "VAT الضرائب والجمارك والـ" (bidi) | `20-financial-approvals-main.png`، `20-financial-approvals-tab-2-import-budget-approval.png` | يتصلح مرة واحدة في `main.dart` (المشكلة المعروفة) |
| Low | زرار "بحث واستنساخ اعتماد ميزانية" متكرر مرتين في نفس التاب (في الـ header وفي صف الفلاتر) | `20-financial-approvals-tab-3-saved-budgets-registry.png`، `saved_budgets_registry_tab.dart:147`، `:265` | سيب واحد بس |
| Low | زرار "اعتماد ميزانية جديدة الآن" فيه أيقونة `+` وكمان إيموجي ➕ في النص | `20-financial-approvals-tab-3-saved-budgets-registry.png`، `app_localizations_ar.dart:1596` | شيل الإيموجي من الترجمة |
| Low | الـ stageCode `PHASE-1: STEP_04`، مع إن الشاشة في "المرحلة 2" في الـ sidebar والدوكيومنت | `financial_approval_screen.dart:2641` | وحّد الكود مع المرحلة 2 |
| Low | نص hard-coded مش مترجم: `'❌ Error: $err'`، وعناوين CSV وأسماء أعمدته بالعربي جوه service | `financial_approval_screen.dart:3919`، `financial_export_service.dart:290-297` | استخدم l10n |
| Low | التحقق في الواجهة بيقبل عنوان من حرف أو حرفين، والباك إند بيطلب 3 حروف على الأقل، فالخطأ بيظهر كـ 422 بعد الحفظ | `financial_approval_screen.dart:2848`، `schemas.py:12` | خلّي الـ validator ماشي على نفس القيود |
| Low (Web-only) | أزرار "فتح واتساب" و "فتح البريد" مش بتعمل حاجة على الويب، لأن `launchUrlNative` بيستخدم `Platform.isWindows` و `Process.run`. ده فرق بين الويب والديسكتوب ومش bug في الديسكتوب | `financial_export_service.dart:1065-1072` | لو الويب مطلوب استخدم `url_launcher` |
| Low (Web-only) | Console: `Refused to set unsafe header "Accept-Encoding"` ظهرت 8 مرات. المتصفح بيرفض الـ header ده، وده مالوش أثر على الديسكتوب | `runtime-errors.json` (20-financial-approvals) | متبعتش الـ header ده لما `kIsWeb` |
