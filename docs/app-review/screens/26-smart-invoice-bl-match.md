# المطابقة الذكية بين الفاتورة والبوليصة (Smart Invoice vs B/L Match)
![](../screenshots/26-smart-invoice-bl-match-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
أداة بتستخرج الحقول المهمة من 3 مستندات: الفاتورة التجارية النهائية، وكشف التعبئة النهائي، ومسودة بوليصة الشحن. وبعدين بتطابقهم مع بعض عشان تمنع أي تعارض جمركي أو بنكي قبل اعتماد المستندات (النص ظاهر في الصفحة: "استخراج الحقول المستهدفة ومطابقة الفاتورة النهائية مع البوليصة ومنع أي تعارض جمركي أو بنكي").

- **المستخدمين:** موظف التوثيق، والمخلص.
- **المرحلة:** المرحلة 3، الخطوة 3 (`stageCode: 'STEP_08_MATCH'`، `smart_invoice_bl_match_screen.dart:63`).
- **الكود:** `BP-022` و `BP-026` (Review Final Shipment Documents).

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 3" ← "3. المطابقة الذكية بين الفاتورة والبوليصة" (index 22). وكمان موجودة كتاب رقم 4 في مصفوفة DC-04 (شاشة 31).
- **الصلاحية:** أي مستخدم عامل login (`router.py:14`)، ومفيش RBAC.

## مكونات الشاشة
الغلاف `DedicatedStageScaffold` بلون `Colors.deepPurple`. المحتوى `InvoiceBLMatcherTab`، وفيه تابين أفقيين: "⚡ فحص ومطابقة الفاتورة والبوليصة"، و "📋 سجل جلسات المطابقة السابقة" وجنبه badge بالعدد 0.

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ربط بملف استيراد | `SearchableDropdownField<int>` | لا | — | `GET /import-files`. في الصورة: "FILE-2026-0006 (IMP-2026-0006) - Guja…" |
| 1. الفاتورة التجارية النهائية | `TextField` متعدد الأسطر ("الصق نص الفاتورة هنا أو اضغط رفع ملف تجاري...") | عملياً نعم عشان التشغيل | — | لصق أو رفع ملف (`_pickFile`، `:160`) |
| 2. كشف التعبئة النهائي | `TextField` متعدد الأسطر ("الصق نص كشف التعبئة هنا أو اضغط رفع كشف التعبئة...")، وجنبه زرار X لإخفاء الكارت | لا | — | لصق أو رفع |
| 3. مسودة بوليصة الشحن | `TextField` متعدد الأسطر ("الصق مسودة البوليصة هنا أو اضغط رفع ملف الخط الملاحي...") | عملياً نعم | — | لصق أو رفع ملف الخط الملاحي |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة | دورة حياة الملف | `/import-files/{id}/hold` وغيره | أي مستخدم |
| توليد وميكنة المخاطبات والخطابات الرسمية | `FormalLetterGeneratorDialog` | `POST /formal-letters/generate` | — |
| تحديث / العودة للداش بورد | — | `GET /import-files` | — |
| رفع ملف (×3) | اختيار ملف لكل مستند | — | — |
| إلغاء وإخفاء كشف التعبئة (X) | بيشيل المستند التاني من المطابقة | — | — |
| تنفيذ الاستخراج الذكي والمطابقة الفورية | `_runCrossMatching` (`:269`)، والزرار بيتعطل وقت التحميل (`:977`) | `POST /api/v1/import-documentation/invoice-bl/extract-files-and-match` (multipart) أو `.../extract-and-match` (نص) | أي مستخدم |
| تحميل نموذج تجريبي حقيقي | بيملا نصوص فاتورة Shaw وبوليصة MSC تجريبية (`_loadSampleData`، `:246`) | — | — |
| إعادة تعيين | بيمسح المدخلات، ومتعطل لو مفيش مدخلات | — | — |
| 💾 حفظ مؤقت للجلسة / حفظ نهائي | `_saveSession` (`:415`) | `POST /invoice-bl/sessions` | — |
| عرض / تحميل / استنساخ / حذف جلسة (من السجل) | `_showSessionDetailsDialog` (`:2573`)، `_loadSessionIntoMatcher` (`:2926`)، `_cloneSession` (`:2965`)، `_deleteSession` (`:3012`) | `GET` أو `DELETE /invoice-bl/sessions/{id}` | أي مستخدم |

### الجداول
- **مصفوفة المطابقة** (بعد التشغيل): بند الفحص، قيمة الفاتورة، قيمة البوليصة، حالة المطابقة، الإجراء المطلوب. ومعاها نسخ TSV وتصدير Excel و PDF (`:3138-3201`). متصورتش لأن المطابقة متشغلتش.
- **سجل الجلسات:** فيه نسخ وتصدير Excel و PDF (`:3044-3105`). وكان فاضي (badge = 0).

### التابات
1. **⚡ فحص ومطابقة الفاتورة والبوليصة**: `26-smart-invoice-bl-match-main.png`.
2. **📋 سجل جلسات المطابقة السابقة**: متصورش كتاب منفصل (الـ harness مسجلوش كتاب، لأنه segmented control جوه الصفحة).

### الـ Dialogs
مفيش dialog إضافة (`capture-manifest.json`: "no add/create button found")، فمفيش صورة validation. الـ dialogs اللي في الكود: `_showExportReportDialog` (`:1816`)، و `_showSessionDetailsDialog`، و `FormalLetterGeneratorDialog`. ولا واحد فيهم اتصور.

### التصدير والطباعة
تصدير مصفوفة المطابقة وسجل الجلسات Excel و PDF، ونسخ TSV، وتقرير تصدير (`_showExportReportDialog`). كله عن طريق `TableExportService` / `FileSaveHelper`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | زرار "تحميل نموذج تجريبي حقيقي" ظاهر للمستخدم النهائي، وبيحقن مستندات مورد وخط ملاحي حقيقيين | `26-smart-invoice-bl-match-main.png`، `invoice_bl_matcher_tab.dart:246-252`، `:997` | يستخبى ورا debug flag |
| Medium | الـ widget بيستدعي Dio مباشرةً (`_uploadDio.post` / `_dio.post`) من غير provider أو repository، وده مخالف لقاعدة "Flutter → API عبر طبقة Provider" وبيصعّب الاختبار | `invoice_bl_matcher_tab.dart:364-372` | نقل الاستدعاء لـ `importDocumentationProvider` |
| Medium | لون الـ header `Colors.deepPurple`، مش من `AppTheme`. وفي التاب 17 `ElevatedButton`، و 118 `Colors.xxx`، و 16 `Color(0x…)` | `smart_invoice_bl_match_screen.dart:67` | `AppTheme.charcoal/cobalt` و `AppButton` |
| Low | الشاشة دي معندهاش زرار استنساخ / Clone في الـ header، مع إن أخواتها في نفس المرحلة (24، 25، 27، 29) عندهم، رغم إن فيه `_cloneSession` في السجل | `26-smart-invoice-bl-match-main.png`، `smart_invoice_bl_match_screen.dart:62-100` | إضافة زرار Clone لتوحيد شريط الإجراءات |
| Low | `DropdownButtonFormField` في dialog الخطابات المشترك | `widgets/formal_letter_generator_dialog.dart:290` | `SearchableDropdownField` |
| Low | الـ breadcrumb بيقول "مراجعة مسودات بوالص الشحن"، وعنوان الـ header "Smart Invoice vs B/L Match" بالإنجليزي. ده من مشكلة الـ locale المعروفة | `26-smart-invoice-bl-match-main.png` | `supportedLocales` |
| Low | console (ويب بس): `Refused to set unsafe header "Accept-Encoding"` | `runtime-errors.json` ← `26-smart-invoice-bl-match` | — |
