# استخراج ومطابقة السويفت (SWIFT MT103 Reconciliation)
![](../screenshots/21-swift-reconciliation-main.png)

> التصوير اتعمل على **Flutter Web (release)** مش Windows desktop. قاعدة البيانات scratch ومفيهاش طلبات سداد، عشان كده الـ KPIs صفر والجدول فاضي. الشاشة اتصورت وهي مدمجة كتاب خامس جوه شاشة 20.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** بعد ما طلب السداد يتدفع، البنك بيبعت إشعار تحويل SWIFT MT103. الشاشة دي بتستخرج بياناته (المرجع، والتاريخ، والمبلغ، والعملة، والمستفيد) من نص ملصوق أو من ملف (PDF أو صورة أو Word أو Excel أو TXT)، وبتطابقها مع طلب السداد، وبتحسب الفرق (عجز أو زيادة) ومدة التنفيذ، وبعدها بتقفل الطلب على إنه "Reconciled".
- **المستخدمين:** الإدارة المالية والخزينة.
- **المرحلة:** المرحلة 2، وده امتداد لـ **BP-012** (Payment Request) بعد التنفيذ. مفيش كود BP منفصل للمطابقة في `doc.md` ولا في `docs/phase_02_financial_approval.md`.

## طريقة الوصول والصلاحية
- **الطريق الأساسي:** Sidebar ← "المرحلة 2" ← "اعتمادات الميزانية وسداد الموردين"، وبعدها التاب الخامس "استخراج ومطابقة السويفت (MT103)".
- **Index 46** بيفتح الشاشة لوحدها، بس **مالوش عنصر في الـ sidebar** (`inventory.json`).
- الشاشة **مالهاش Scaffold خاص بيها**، وبتعتمد على الـ `VerticalStageScaffold` بتاع شاشة 20.
- **الصلاحية:** `Depends(get_current_user)` على مستوى الـ router (`modules/financial_approval/router.py:43`)، يعني أي مستخدم مسجّل. مفيش RBAC على المطابقة.
- عند الفتح (`initState`) بتجيب طلبات السداد وملفات الاستيراد من جديد (`swift_reconciliation_screen.dart:65-75`، ولو الـ provider بيحمّل أصلاً بيتخطى الطلب).

## مكونات الشاشة

### الحقول
**محرك الاستخراج الذكي (الشاشة الرئيسية)**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| نص رسالة السويفت أو إشعار التحويل البنكي | TextField متعدد الأسطر | لا | لازم مايبقاش فاضي عشان الاستخراج | لصق يدوي، أو زرار "لصق واستخراج"، أو "تحميل نموذج سويفت تجريبي" |
| طلب السداد المستهدف (بيظهر بعد الاستخراج) | `SearchableDropdownField<int>` | لا | — | `paymentRequestsProvider` (الطلبات النشطة) (`:1282`) |
| مراجعة الحقول المستخرجة (`SwiftExtractionReviewWidget`) | حقول قابلة للتعديل، وكل حقل ليه إعادة استخراج | — | — | `/swift/review-batch/{id}/*` |
| بحث السجل | TextField | لا | — | بحث محلي بكود الطلب أو ملف الشحنة أو المورد أو رقم السويفت |
| فلاتر الحالة | Chips: الكل / بانتظار السويفت / مطابق / فروقات | — | — | محلي |

**Dialog تعديل السويفت (`_showSwiftReconciliationDialog`، `:416`)**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| تاريخ استلام السويفت | Date picker | نعم (في الباك إند) | — | افتراضي النهارده أو القيمة المحفوظة |
| مرجع السويفت | TextFormField | نعم | مش فاضي (الباك إند: 2–100 حرف) | يدوي أو مستخرج |
| المبلغ المحوَّل | TextFormField رقمي | نعم | رقم > 0 | افتراضي نفس المبلغ المطلوب |
| العملة | **TextFormField نص حر** (`:745`) | لا | مفيش | عملة الطلب |
| ملاحظات المطابقة | TextFormField | لا | — | يدوي |
| لصق من الحافظة | زرار | — | — | `Clipboard.getData` (`:603`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تحميل نموذج سويفت تجريبي | بيملى الـ TextField برسالة MT103 تجريبية | — | — |
| طي / فتح المحرك (سهم) | بيقفل أو يفتح القسم | — | — |
| رفع مستند سويفت | FilePicker (`withData: true`، يعني bytes وبيشتغل على الويب) وبعدها استخراج. **فيه loading** | `POST /financial-approval/swift/smart-extract-file` | أي مستخدم مسجّل |
| استخراج فوري من النص | استخراج ومطابقة تلقائية، وبيطلع batch للمراجعة. **فيه loading** | `POST /financial-approval/swift/smart-extract` | — |
| لصق واستخراج | بيلصق من الحافظة وبعدها يستخرج | نفس اللي فوق | — |
| إلغاء | بيفضّي النص ونتيجة الاستخراج | — | — |
| انقر للنسخ (أيقونة جوه مربع النص) | بينسخ نص السويفت الملصوق للحافظة (`:1692-1695`) | — | — |
| نسخ (أيقونة جوه مربع البحث) | بينسخ نص البحث نفسه للحافظة (`:2073-2075`) | — | — |
| تأكيد وتنفيذ المطابقة (بعد المراجعة) | لو فيه batch: بيطابقه. غير كده بيعمل مطابقة ذكية مباشرة (`:354-375`) | `POST /swift/review-batch/{id}/reconcile` أو `POST /swift/smart-reconcile` | — |
| تعديل حقل / إعادة استخراج حقل / تأكيد / مطابقة (ويدجت المراجعة) | إدارة الـ batch | `PUT /swift/review-batch/{id}/field/{key}`، `POST .../re-extract-field/{key}`، `POST .../confirm`، `POST .../match` | — |
| تعديل السويفت (صف) | بيفتح dialog المطابقة اليدوي | `POST /payment-requests/{id}/reconcile-swift` | — |
| عرض التفاصيل (صف) | `_showSwiftDetailsDialog` (`:942`) | — | — |
| نسخ ملف الطلب (صف) | بينسخ ملخص الطلب للحافظة | — | — |
| نسخ بطاقة المطابقة | بينسخ ملخص السجل المفلتر | — | — |
| تصدير إكسيل | `exportSwiftReconciliationToExcel`، وده بيطلع **CSV** عن طريق `FileSaveHelper.saveText`. مقفول لو السجل فاضي | — | — |
| تصدير جدول نصوص | بينسخ TSV للحافظة (`:84-136`)، ومقفول لو السجل فاضي | — | — |
| تحديث | إعادة جلب الطلبات | `GET /financial-approval/payment-requests` | — |

### الجداول
- **KPIs (5 كروت):** إجمالي طلبات السداد، بانتظار السويفت، سويفت مطابق بالكامل، فروقات (عجز/زيادة)، متوسط مدة التنفيذ بالأيام.
- **مصفوفة المطابقة** (`_buildMatchingMatrixBox`، `:1200`): بعد الاستخراج بتقارن الطلب بالسويفت حقل بحقل (المبلغ، والعملة، والمستفيد، والبنك).
- **سجل طلبات السداد ومطابقة السويفت (N):** `DataTable`، والأعمدة: الإجراءات، كود الطلب (+ ملف الشحنة)، بنك المستفيد، تاريخ الطلب، تاريخ السويفت، مدة التنفيذ، المبلغ المطلوب، المبلغ المحوَّل، حالة الفرق (badge)، مرجع السويفت (`:2206-2215`). البحث نصي والفلترة بالـ Chips. **مفيش ترتيب** بالأعمدة.

### التابات
الشاشة نفسها مفيهاش تابات. هي التاب الخامس في شاشة 20، وصورتها هناك مطابقة للصورة الرئيسية هنا:

![](../screenshots/20-financial-approvals-tab-5-swift-mt103-reconciliation.png)

### الـ Dialogs
- **تعديل السويفت** (`_showSwiftReconciliationDialog`): الحقول مشروحة فوق، والأزرار "إلغاء" و "حفظ المطابقة". **مفيش صورة**: السجل فاضي في بيانات المراجعة، فمفيش صف أقدر أفتح منه الـ dialog، وكمان الشاشة مالهاش زرار إضافة (`capture-manifest.json`: "no add/create button found").
- **عرض تفاصيل السويفت** (`_showSwiftDetailsDialog`): للقراءة بس، وفيه بيانات الطلب والسويفت والفرق. مفيش صورة لنفس السبب.
- **مفيش صورة لأخطاء الـ validation**، لأن مفيش dialog إضافة. من الكود: "مرجع السويفت" فاضي بيطلع `swiftEnterSwiftRefError`، والمبلغ لازم يكون رقم > 0 (`:707`، `:733`).

### التصدير والطباعة
- "تصدير إكسيل" بيطلع CSV، وبيتحفظ عن طريق `FileSaveHelper.saveText` باسم `SWIFT_Reconciliation_<timestamp>.csv` (`financial_export_service.dart:804-811`).
- "تصدير جدول نصوص" بيعمل TSV للحافظة. و "نسخ بطاقة المطابقة" و "نسخ ملف الطلب" نصوص للحافظة برضه.
- إيصال السويفت PDF (`printOrSaveSwiftSlipPdf`) عن طريق `Printing.layoutPdf` (`financial_export_service.dart:1059`).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | زرار الحفظ في dialog المطابقة بيقفل الـ dialog **قبل** ما الطلب يتبعت، ومفيش loading. لو حصل خطأ بيظهر SnackBar بعد ما البيانات اللي اليوزر دخلها ضاعت | `swift_reconciliation_screen.dart:887-888` (`Navigator.pop` قبل `reconcileSwift`)، `:914-920` | خلّي الـ dialog مفتوح مع `AppButton(isLoading:)`، واقفله بس لما الحفظ ينجح |
| Medium | حقل "العملة" في dialog المطابقة نص حر مش `SearchableDropdownField`. ده بيخالف القاعدة في الحقول المرجعية، وممكن يتكتب كود عملة غلط | `swift_reconciliation_screen.dart:745-757` | استخدم `SearchableDropdownField<String>` من `currenciesProvider` |
| Medium | أي مستخدم مسجّل يقدر يعمل مطابقة ويقفل الطلب "Reconciled". مفيش صلاحية مالية | `modules/financial_approval/router.py:43`، `:289-298` | اعمل RBAC لدور المالية |
| Medium | "تصدير إكسيل" بيطلع CSV وبيسمح بامتداد `.xlsx` (ممكن يطلع ملف تالف). والاسم فيه timestamp ومش ماشي على `[Stage Name] - [File Code]`. وكمان مش بيعدّي على `exportAndSaveFile` | `financial_export_service.dart:804-811` | صدّر xlsx حقيقي عن طريق `FileSaveHelper.exportAndSaveFile` بالتسمية القياسية |
| Medium | مخالفة لـ UI_SCREEN_STANDARDS: صفر `AppButton`، و 16 `ElevatedButton`، و 12 `OutlinedButton`، و 148 `Colors.xxx` | `swift_reconciliation_screen.dart` | انقلها لـ `AppButton` و `AppTheme` |
| Low | شارة "التحديث التلقائي لملفات الشحنة مفعل" نص ثابت، ومفيش Timer ولا listener في الشاشة بيحدّث حاجة تلقائي | `21-swift-reconciliation-main.png`، `swift_reconciliation_screen.dart:2135-2138` | شيل الشارة أو اربطها بآلية تحديث حقيقية |
| Low | زرار "تحميل نموذج سويفت تجريبي" ظاهر في الواجهة الأساسية وجنب الإنتاج، وممكن يتلخبط مع بيانات حقيقية | `21-swift-reconciliation-main.png`، `swift_reconciliation_screen.dart:1573` | خبّيه ورا debug flag أو صلاحية ADMIN |
| Low | الشاشة مالهاش عنصر sidebar (index 46)، والوصول ليها من تاب 5 بس. عنوان الـ header ساعتها بيفضل "Budget Approval" | `21-swift-reconciliation-main.png`، `inventory.json` | لو الشاشة المستقلة مش مستخدمة شيل index 46، أو اعملها stage badge خاص بيها |
| Low | عنوان الـ header ("Financial Approvals & Budget Management") وأسماء التابات الرأسية بالإنجليزي في الوضع العربي، وده من المشكلة المعروفة إن `supportedLocales` مش متحدد في `main.dart` | `21-swift-reconciliation-main.png` | يتصلح مرة واحدة في `main.dart` |
| Low (Web-only) | Console: `Refused to set unsafe header "Accept-Encoding"` ظهرت مرتين. المتصفح بيرفض الـ header ده، ومالوش أثر على الديسكتوب | `runtime-errors.json` (21-swift-reconciliation) | متبعتش الـ header لما `kIsWeb` |
