# مطابقة الفاتورة والباكينج مع أمر الشراء (PO & Packing Reconciliation)
![](../screenshots/24-po-packing-reconciliation-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
أول خطوة في تدقيق المسودات. بترفع أو بتلصق الفاتورة التجارية النهائية وقائمة التعبئة (Packing List)، والنظام بيستخرج البنود ويطابقها مطابقة ثلاثية مع أمر الشراء اللي في السستم: الكميات، والأسعار، والطرود، والأوزان، والحجم. وبعدين الأرقام المعتمدة هنا بتبقى "المرجع الحاكم" لدرافت البوليصة، والبضاعة اللي في الطريق، والإفراج، واستلام المخزن. ده النص اللي ظاهر في الصفحة نفسها.

- **المستخدمين:** موظف الاستيراد / التوثيق.
- **المرحلة:** المرحلة 3 "حجز الشحن والتدقيق المستندي المبدئي"، الخطوة 1 (`stageCode: 'STEP_08_PO'`، `po_packing_reconciliation_screen.dart:92`).
- **الكود:** `BP-016` (Manage Shipment Document Lifecycle)، و `BP-003` (أمر الشراء) مرجعاً، حسب `inventory.json`.

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 3" ← "1. مطابقة الفاتورة والباكينج مع أمر الشراء" (index 21). ونفس المحتوى موجود كتاب رقم 2 جوه مصفوفة المسودات DC-04 (شاشة 31).
- **الصلاحية:** أي مستخدم عامل login (`router.py:14`)، ومفيش RBAC على الاعتماد (`POST /po-reconciliation`، `router.py:267`).

## مكونات الشاشة
الغلاف `DedicatedStageScaffold`، والمحتوى `POReconciliationTab` (`widgets/po_reconciliation_tab.dart`، 4708 سطر).

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة المرجعي * | `SearchableDropdownField<int>` | نعم | لو فاضي بيطلع SnackBar `poRecSelectFileRequired` (`po_reconciliation_tab.dart:1154-1158`) | `GET /api/v1/import-files`، وبيتختار أول ملف تلقائي (`po_packing_reconciliation_screen.dart:54-58`) |
| رقم الفاتورة التجارية النهائية * | `TextFormField` | نعم | `Form` validator | يدوي أو من الاستخراج |
| رقم قائمة التعبئة النهائية (اختياري) | `TextFormField` | لا | — | يدوي أو من الاستخراج |
| نص الفاتورة التجارية | `TextField` متعدد الأسطر ("ألصق نص الفاتورة التجارية هنا أو ارفع الملف الرقمي...") | لا | — | لصق، أو رفع ملف (`_pickFile`، `:253`) |
| نص قائمة التعبئة | `TextField` متعدد الأسطر ("ألصق نص قائمة التعبئة هنا أو ارفع الملف الرقمي...") | لا | — | لصق أو رفع ملف |
| خلايا جدول البنود (الكمية النهائية، السعر النهائي، الطرود، الأوزان) | خلايا قابلة للتعديل | — | — | الاستخراج مقارنةً بأمر الشراء (`GET /api/v1/purchase-orders`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة عند هذه المرحلة | دورة حياة الملف | `/import-files/{id}/hold` وغيره | أي مستخدم |
| أيقونة الاستنساخ (Ctrl+D)، و "استنساخ جلسة مطابقة سابقة" | `SearchAndClonePoReconciliationDialog` | `GET /po-reconciliation/sessions` | — |
| توليد وميكنة المخاطبات والخطابات الرسمية | `FormalLetterGeneratorDialog` | `POST /api/v1/formal-letters/generate`، `GET /formal-letters/history/{fileId}` | أي مستخدم |
| تحديث / العودة للداش بورد | إعادة تحميل الملفات / رجوع | `GET /import-files` | — |
| تحميل نموذج تجريبي حقيقي (G.I. INDUSTRIAL) | بيملا نصوص فاتورة وباكينج تجريبية (`_loadSampleData`، `:235`) | — | — |
| إخفاء الأداة / السهم | بيطوي كارت الاستخراج | — | — |
| رفع ملف المستندات (للفاتورة وللباكينج) | `_pickFile` | `POST /po-reconciliation/extract-files-and-compare` | — |
| تنفيذ الاستخراج الذكي والمطابقة مع بيانات السستم | `_runSmartExtractionAndComparison` (`:408`)، فيه `_isExtracting` | `POST /po-reconciliation/extract-and-compare` | — |
| نسخ جدول المطابقة (TSV) / تصدير Excel / تصدير PDF | بيبقوا disabled لحد ما يبقى فيه بنود | Client، ومنه لـ `FileSaveHelper` | — |
| إعادة تعيين للقيم الأصلية | بيرجع الخلايا لقيم أمر الشراء | — | — |
| حفظ جلسة المطابقة | `_saveReconciliationSession` (`:955`)، فيه `_isSavingSession` | `POST` أو `PUT /po-reconciliation/sessions[/{id}]` | — |
| اعتماد ومطابقة البيانات النهائية | `_submitCertification` (`:1151`). لو فيه فروق بيطلب تأكيد، وفيه `_isSubmitting` | `POST /api/v1/import-documentation/po-reconciliation` | أي مستخدم |
| حذف جلسة (من السجل) | `_confirmDeleteSession` (`:4060`) | `DELETE /po-reconciliation/sessions/{id}` | أي مستخدم |

### الجداول
- **بطاقات المؤشرات:** إجمالي الفاتورة النهائية (`0.00 $`)، إجمالي الطرود الفعلية (`0 طرد`)، إجمالي الوزن القائم (`0 كجم`)، إجمالي الوزن الصافي (`0 كجم`)، إجمالي الحجم بالمتر المكعب (`0.000 م³`). كلها أصفار في الصورة لأن مفيش بنود. أزرار التصدير فوق الجدول اسمها في الواجهة "نسخ جدول المطابقة (TSV)" و "تصدير جدول المطابقة إلى Excel" و "تصدير تقرير المطابقة إلى PDF"، وظاهرين disabled.
- **جدول بنود الفاتورة:** الإجراءات، كود الصنف، الوصف، كمية أمر الشراء، الكمية النهائية، فرق الكمية، سعر الوحدة في أمر الشراء، سعر الوحدة النهائي، فرق السعر، الإجمالي النهائي، HS Code.
- **جدول الباكينج:** الإجراءات، كود الصنف، نوع العبوة، عدد الطرود في أمر الشراء، عدد الطرود النهائي، فرق الطرود، الوزن القائم، الوزن الصافي، CBM.
- **سجل الجلسات:** الإجراءات، #، كود الجلسة، ملف الاستيراد / المستورد، الفاتورة / الباكينج، القيمة الإجمالية، الطرود / الوزن، CBM، الحالة، تاريخ الحفظ.

الجداول دي متصورتش مليانة، لأن الملف التجريبي مكانش عليه بنود مستخرجة. الصورة بتوقف عند عنوان "1. مراجعة وتأكيد بنود وأسعار الفاتورة التجارية النهائية".

### التابات
مفيش تابات على مستوى الشاشة. المحتوى صفحة واحدة بتنزل لتحت: كارت الملف، وأداة الاستخراج، والمؤشرات، وجدول الفاتورة، وجدول الباكينج، والسجل.

### الـ Dialogs
- مفيش dialog إضافة (`capture-manifest.json`: "no add/create button found"). الإضافة بتحصل بالحفظ من الصفحة نفسها، فمفيش صورة لأخطاء validation.
- في الكود: `FormalLetterGeneratorDialog`، و `SearchAndClonePoReconciliationDialog`، وتأكيد الاعتماد لو فيه فروق (`:1169`)، وتأكيد الحذف. ولا واحد فيهم اتصور.

### التصدير والطباعة
Excel و PDF لبنود الفاتورة (`:1875`، `:1934`)، ولبنود الباكينج (`:2010`، `:2068`)، ولسجل الجلسات (`:1768`، `:1807`)، وكمان نسخ TSV. كله بيعدي على `TableExportService` / `FileSaveHelper`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | الشاشة بتختار أول ملف شحنة تلقائي (FILE-2026-0006) من غير ما المستخدم يختار، وده ممكن يخليه يعتمد بيانات على الملف الغلط | `24-po-packing-reconciliation-main.png`، `po_packing_reconciliation_screen.dart:54-58` | تبدأ من غير اختيار، أو تفتكر آخر ملف المستخدم اختاره |
| Medium | زرار "تحميل نموذج تجريبي حقيقي (G.I. INDUSTRIAL)" ظاهر في الواجهة الإنتاجية وبيحقن بيانات مورد حقيقي تجريبية | `24-po-packing-reconciliation-main.png`، `po_reconciliation_tab.dart:135`، `:235`، `:4233` | يستخبى ورا debug flag |
| Medium | الـ breadcrumb والتاب المفتوح مكتوب عليهم "مراجعة مسودات بوالص الشحن"، مع إن الشاشة مطابقة الفاتورة والباكينج | `24-po-packing-reconciliation-main.png` (أعلى الشاشة) | عنوان breadcrumb مخصص لكل شاشة |
| Medium | مخالفات UI: 27 `ElevatedButton`، و 138 `Colors.xxx`، و 10 `Color(0x…)` في التاب. وزرار الخطابات في الـ header `OutlinedButton` بدل `AppButton` | `po_reconciliation_tab.dart`، `po_packing_reconciliation_screen.dart:106` | `AppButton` و `AppTheme` |
| Medium | dialog الخطابات الرسمية المشترك بيستخدم `DropdownButtonFormField` لاختيار القالب | `widgets/formal_letter_generator_dialog.dart:290` | `SearchableDropdownField` |
| Low | عنوان الـ header مقطوع "PO & Packing Reconcilia…" وبالإنجليزي. ده من مشكلة الـ locale المعروفة، لأن `DedicatedStageScaffold` بيختار العنوان من `Directionality` | `24-po-packing-reconciliation-main.png`، `core/widgets/dedicated_stage_scaffold.dart:68`، `:91` | إصلاح `supportedLocales`، والعنوان ياخد مساحة كفاية |
| Low | الاعتماد النهائي متاح لأي مستخدم عامل login، من غير صلاحية اعتماد | `modules/import_documentation/router.py:14`، `:267` | permission code للاعتماد |
| Low | console (ويب بس): `Refused to set unsafe header "Accept-Encoding"` | `runtime-errors.json` ← `24-po-packing-reconciliation` | — |
