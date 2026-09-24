# شهادات الفحص والتفتيش والمطابقة (Inspection Review (COC))
![](../screenshots/28-inspection-review-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
الشاشة دي بتجهز متطلبات شهادة الفحص المسبق قبل الشحن (COC / شهادة المطابقة النوعية) لجهة فحص دولية (SGS / Bureau Veritas / Intertek). بتولّد مسودة رسمية، وتستخرج بيانات الدرافت اللي جاي من جهة الفحص (نص أو OCR أو ملف)، وتقارنها ببيانات الشحنة، وتحفظ الشهادات المعتمدة في سجل.

- **المستخدمين:** موظف التوثيق / الجودة، والمخلص.
- **المرحلة:** المرحلة 3، الخطوة 5 (`stageCode: 'STEP_08_COC'`، `draft_inspection_review_screen.dart:63`).
- **الكود:** `BP-011` (Assess Import Requirements، اللي بيحدد إن الفحص مطلوب) و `BP-016`.

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 3" ← "5. شهادات الفحص والتفتيش والمطابقة" (index 53). وكمان كتاب رقم 6 في مصفوفة DC-04.
- **الصلاحية:** أي مستخدم عامل login (`router.py:14`). الحذف `DELETE /inspection/{id}` (`router.py:643`) من غير RBAC.

## مكونات الشاشة
الغلاف `DedicatedStageScaffold` بلون `Colors.indigo`. المحتوى `InspectionReviewTab`، وفيه 4 تابات أفقية. الـ header ده معندوش زرار استنساخ (Clone).

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختر ملف الشحنة * | `SearchableDropdownField<int>` | نعم | — | `GET /import-files`. في الصورة كان **فاضي** ومتختارش تلقائي زي باقي شاشات المرحلة |
| نوع شهادة الفحص * | `SearchableDropdownField<String>` | نعم | — | قايمة ثابتة، الافتراضي "شهادة المطابقة النوعية" |
| جهة الفحص الدولية * | `SearchableDropdownField<String>` | نعم | — | **قايمة ثابتة في الكود** (SGS International، Bureau Veritas (BV)، Intertek Testing Services…) (`inspection_review_tab.dart:626-629`، `:753-756`) |
| نص / OCR للدرافت (تاب 2) | `TextField` | — | — | لصق أو رفع (`_extractFromOcrText`، `:377`) |
| سبب تجاوز الفروقات | `TextField` | إلزامي لو فيه فروق | SnackBar برتقالي `overrideReasonMandatoryWarning` (`:225-233`) | يدوي |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة | دورة حياة الملف | `/import-files/{id}/hold` وغيره | أي مستخدم |
| توليد وميكنة المخاطبات والخطابات الرسمية | `FormalLetterGeneratorDialog` | `POST /formal-letters/generate` | — |
| تحديث / العودة للداش بورد | — | `GET /import-files` | — |
| فتح المعاينة والتصدير | `_generateOfficialDraft` (`:274`) | `GET /import-documentation/inspection/draft-template/{fileId}` | — |
| التالي: إدخال الدرافت | بينقلك لتاب 2 | — | — |
| استخراج من ملف / نص | — | `POST /import-documentation/extract-certificate` | — |
| تشغيل المقارنة | `_runComparison` (`:171`) | `POST /import-documentation/inspection/compare` | — |
| حفظ الشهادة ("حفظ في سجل الفحص") | `_saveReview` (`:217`) (`onPressed: _saveReview` في `:1153` و `:1282`)، **الزرار مش بيتعطل وقت الحفظ** | `POST /import-documentation/inspection` أو `PUT .../{id}` | — |
| تصدير Excel / PDF | `InspectionExportService.saveInspectionCsvToFile` وغيره (`:1061-1100`) | Client، ومنه لـ `FileSaveHelper` | — |
| حذف (من السجل) | `_confirmDeleteInspectionReview` (`:1621`)، soft delete (`repository.py:710-714`) | `DELETE /inspection/{id}` | أي مستخدم |

### الجداول
- **مصفوفة المقارنة والفروق** (تاب 3): فيها بيانات الشحنة مقارنةً بالدرافت، ومؤشرات فرق حرج أو تحذير. متصورتش.
- **سجل شهادات الفحص المعتمدة** (تاب 4): فيه أيقونة PDF لكل صف (`:1421`)، ودايالوج تفاصيل (`:1506`). متصورش.

### التابات
1. **متطلبات شهادة الفحص والمطابقة**: `28-inspection-review-main.png`.
2. **إدخال واستخراج الدرافت**: متصورش.
3. **مصفوفة المقارنة والفروق**: متصورش.
4. **سجل شهادات الفحص المعتمدة**: متصورش.

### الـ Dialogs
مفيش dialog إضافة (`capture-manifest.json`: "no add/create button found")، فمفيش صورة validation. الـ dialogs اللي في الكود: `_showInspectionReviewDetailsDialog` (`:1506`)، وتأكيد الحذف (`:1621`)، و `FormalLetterGeneratorDialog`. ولا واحد فيهم اتصور.

### التصدير والطباعة
تصدير المسودة Excel (CSV) و PDF عن طريق `InspectionExportService`، و PDF لكل شهادة من السجل. كله بيعدي على `FileSaveHelper` (`services/inspection_export_service.dart`).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | ملف الشحنة مش متختار في الصورة، مع إن شاشات 24 لـ 27 بتختار أول ملف. الكود نفسه ناوي يختار أول ملف (`:66-72`)، لكن لو `importFilesProvider` كان لسه بيحمّل ساعة الـ `initState`، الـ fetch بيتخطى و `valueOrNull` بيرجع فاضي، فالاختيار مبيحصلش ومفيش listener يعيده (race). النتيجة إن الشاشة كلها بتفضل فاضية لحد ما المستخدم يختار | `28-inspection-review-main.png` مقارنةً بـ `27-draft-coo-review-main.png`، `inspection_review_tab.dart:59-76` | توحيد السلوك، ويستحسن ميبقاش فيه اختيار تلقائي في كل الشاشات |
| Medium | جهات الفحص (SGS / BV / Intertek) قايمة مكتوبة ثابتة في الكود بدل ما تبقى Master Data (مزودي الخدمات) | `inspection_review_tab.dart:626-629`، `:753-756` | ربطها بـ `/external-service-providers` بنوع "Inspection Body" |
| Medium | زرار حفظ الشهادة مش بيتعطل وقت الحفظ: `_saveReview` بيحط `_isLoading = true` (`:236`)، لكن الزرار `onPressed: _saveReview` على طول ومش بيبص على `_isLoading`. والتاب مفيهوش أي `ref.invalidate`. ده بيفتح احتمال حفظ مكرر ومن غير refresh تلقائي | `inspection_review_tab.dart:1153`، `:1282` (عدد `ref.invalidate` = 0 في الملف) | `isLoading` و `ref.invalidate(inspectionReviewsProvider)` |
| Medium | لون الـ header `Colors.indigo`، مش من `AppTheme`. وفي التاب 22 `ElevatedButton` و 73 `Colors.xxx` | `draft_inspection_review_screen.dart:67`، `inspection_review_tab.dart` | `AppTheme` و `AppButton` |
| Medium | 4 تابات أفقية، والمعيار بيمنع ده. ومفيش زرار Clone في الـ header (شاشة Stage) | `28-inspection-review-main.png`، `draft_inspection_review_screen.dart:70-94` | قايمة رأسية، وإضافة Clone |
| Low | الـ breadcrumb بيقول "مراجعة مسودات بوالص الشحن"، والعنوان مقطوع بالإنجليزي "Inspection & Conformity Re…". ده من مشكلة الـ locale المعروفة | `28-inspection-review-main.png` | `supportedLocales` |
| Low | console (ويب بس): `Refused to set unsafe header "Accept-Encoding"` (18 مرة) | `runtime-errors.json` ← `28-inspection-review` | — |
