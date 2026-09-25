# مراجعة واعتماد مسودة بوليصة الشحن (Draft B/L Review & Approval)
![](../screenshots/25-draft-bl-review-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
الشاشة بتسحب البيانات المرجعية للشحنة (المورد والمستورد من الـ master data، وبيان العبوة، والحجز الملاحي، ورقم ACID) وتعرضها على شكل بوليصة شحن مرجعية. وبعدين تقارنها بمسودة الخط الملاحي اللي بتترفع كملف (PDF / Word / Excel / Text-OCR) أو بتتلصق كنص. بعد كده في checklist تعديلات، وخطاب للخط الملاحي، وإدارة نسخ المسودة، واعتماد ثنائي (المستورد والمخلص)، وسجل نهائي.

- **المستخدمين:** مسؤول الاستيراد (Import Manager) والمخلص الجمركي. دي أساس "الاعتماد الثنائي".
- **المرحلة:** المرحلة 3، الخطوة 2 (`stageCode: 'STEP_08_BL'`، `draft_bl_review_screen.dart:87`).
- **الكود:** `BP-022` (Review & Dual Approval of Shipping Documents) و `BP-016`.

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 3" ← "2. مراجعة واعتماد مسودة بوليصة الشحن" (index 18). ونفس المحتوى موجود كتاب رقم 3 في مصفوفة DC-04 (شاشة 31).
- **الصلاحية:** أي مستخدم عامل login (`router.py:14`). الاعتماد `POST /draft-bl/{id}/approve` بياخد `approved_by` كـ query param وقيمته الافتراضية `"Kamal"` (`router.py:528-531`)، والـ checklist بياخد `reviewer_name="Kamal"` (`router.py:502-507`). يعني هوية اللي بيعتمد مش جاية من المستخدم اللي عامل login.

## مكونات الشاشة
الغلاف `DedicatedStageScaffold` بلون `AppTheme.emerald`. المحتوى `DraftBLReviewTab`، وفيه قايمة خطوات رأسية جوه الصفحة (5 خطوات).

الخطوة 1 فيها 3 كروت ظاهرة في الصورة: كارت "ورقة مراجعة واعتماد مسودة بوليصة الشحن" (اختيار الملف، والـ badge بتاع حالة المطابقة، وأزرار التنزيل والبحث عن مسودة سابقة)، وكارت "📥 استخراج ذكي من ملفات ومسودات البوليصة" (chips للصيغ المدعومة PDF / Word (.docx) / Excel (.xlsx) / Text / OCR، وزرار الرفع، وقسم "أو الصق نص المسودة يدوياً" اللي بيتطوي)، وكارت "1. ملخص الشحنة المرجعي كشكل بوليصة شحن" (البوليصة المرجعية).

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة الاستيرادي * | `SearchableDropdownField<int>` | نعم | — | `GET /import-files`، وبيتختار أول ملف تلقائي. في الصورة: FILE-2026-0006 |
| أو الصق نص المسودة يدوياً | `TextField` قابل للطي | لا | — | لصق |
| حقول المسودة (رقم البوليصة، رقم الحاوية، الختم، عدد الطرود، CBM…) | `TextFormField` | — | — | الاستخراج / يدوي (`draft_bl_review_tab.dart:52-56`) |
| الطرف المسؤول عن التعديل (في جدول الـ checklist) | `DropdownButtonFormField<String>` (خط ملاحي / مورد / مستورد / مخلص) | — | — | قايمة ثابتة (`:1706`) |
| اسم المعتمد عن المستورد / عن المخلص، وملاحظاتهم | `TextFormField` | — | — | **متملية مسبقاً بـ `'Kamal (Import Manager)'` و `'Ahmed (Customs Broker)'`** (`:58-60`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة | دورة حياة الملف | `/import-files/{id}/hold` وغيره | أي مستخدم |
| أيقونة الاستنساخ (Ctrl+D)، و "البحث ونسخ مسودة سابقة" | `SearchAndCloneDraftBlDialog` | `GET /draft-bl` | — |
| توليد وميكنة المخاطبات والخطابات الرسمية | `FormalLetterGeneratorDialog` | `POST /formal-letters/generate` | — |
| تنزيل PDF / تنزيل Excel (مرتين: في كارت المراجعة وفي كارت ملخص الشحنة) | تصدير البوليصة المرجعية / ورقة المراجعة | Client، ومنه لـ `DraftBLExportService` ثم `FileSaveHelper` | — |
| تحديث ومقارنة البيانات | `_runComparison` (`:108`) | `POST /import-documentation/draft-bl/compare` | — |
| 📁 رفع واستخراج ملف المسودة (PDF، Word، Excel) | `_pickAndExtractFile` (`:315`)، فيه `_isUploadingFile` | `POST /import-documentation/draft-bl/extract-file` | — |
| طباعة البوليصة | طباعة البوليصة المرجعية | Client | — |
| تحديث (في كارت الملخص) | إعادة تحميل البيانات المرجعية | compare | — |
| حفظ / حفظ كمسودة | `_saveReview` (`:401`)، فيه `_isSavingDraft` | `POST /draft-bl` أو `PUT /draft-bl/{id}` | — |
| تحديث صف في الـ checklist | `_updateChecklistRow` (`:527`) | `PUT /draft-bl/{id}/checklist` | — |
| اعتماد / رفض (مستورد / مخلص) | `_submitApproval` (`:581`) | `POST /draft-bl/dual-approval` | أي مستخدم |
| نسخة جديدة من المسودة | إصدار جديد | `POST /draft-bl/new-version` | — |
| الاعتماد النهائي | — | `POST /draft-bl/{id}/approve` | أي مستخدم |
| حذف جلسة (من السجل) | `_deleteDraftBLSession` (`:3036`)، soft delete (`repository.py:505-509`) | `DELETE /draft-bl/{id}` | أي مستخدم |

### الجداول
- **البوليصة المرجعية** (Visual sheet، `visual_draft_bl_sheet.dart`) ظاهرة في الصورة: BILL OF LADING (DRAFT)، و NON-NEGOTIABLE، و B/L NO: DRAFT-BL، و BOOKING REF: BKG-REF، وخانات SHIPPER / EXPORTER و CONSIGNEE و NOTIFY PARTY و CARRIER'S AGENTS ENDORSEMENTS و PORT OF DISCHARGE AGENT.
- **جدول الـ checklist / التعديلات** (الخطوة 2): البند، قيمة السستم، قيمة المسودة، الحالة، الطرف المسؤول. متصورش.
- **السجل النهائي** (الخطوة 5): تصدير Excel و PDF (`:3215`، `:3260`). متصورش.

### التابات
قايمة الخطوات الرأسية الداخلية (ظاهرة في `25-draft-bl-review-main.png`، والـ harness صوّر الخطوة 1 بس):
1. **ورقة المراجعة والتدقيق**: البوليصة المرجعية والاستخراج من ملف المسودة (الصورة الرئيسية).
2. **تقرير التعديلات وخطاب الخط الملاحي**: متصورش.
3. **إدارة النسخ والإصدارات**: متصورش.
4. **الاعتماد الثنائي**: متصورش.
5. **السجل النهائي المعتمد**: متصورش.

### الـ Dialogs
مفيش dialog إضافة (`capture-manifest.json`: "no add/create button found")، فمفيش صورة لأخطاء validation. الـ dialogs اللي في الكود: `SearchAndCloneDraftBlDialog`، و `CloneEntityReviewDialog` (الكود المقترح `DRAFT-BL-2026-`، `:245`)، و `FormalLetterGeneratorDialog`، وتأكيد الحذف. ولا واحد فيهم اتصور.

### التصدير والطباعة
تنزيل PDF وتنزيل Excel للبوليصة المرجعية ولورقة المراجعة، وطباعة البوليصة، وتصدير السجل. كله عن طريق `DraftBLExportService` / `TableExportService`، وبيوصل لـ `FileSaveHelper`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | الاعتماد الثنائي مش مربوط بهوية المستخدم. اسم معتمد المستورد والمخلص نص حر ومتملي مسبقاً ("Kamal (Import Manager)" و "Ahmed (Customs Broker)")، والـ backend بيقبل `approved_by` و `reviewer_name` من الـ client وقيمتهم الافتراضية "Kamal". أي مستخدم يقدر يعتمد باسم المخلص | `widgets/draft_bl_review_tab.dart:58-60`، `:589`، `modules/import_documentation/router.py:506`، `:530`، `schemas.py:370`، `service.py:1905` | الـ approver ياخد `current_user` من الـ token، والاعتماد يبقى بـ role (IMPORT_MANAGER / BROKER) |
| High | الـ badge بيقول "مطابقة تامة 100% جاهزة للاعتماد" رغم إن مفيش مسودة خط ملاحي اترفعت خالص (جدول `draft_bl_review_sessions` فاضي في قاعدة المراجعة). المقارنة الصامتة بتشتغل على بيانات فاضية ومش بتلاقي "blocking mismatch" | `25-draft-bl-review-main.png`، `draft_bl_review_tab.dart:94`، `:844-846` | لو مفيش بيانات مسودة، تظهر حالة "بانتظار مسودة الخط الملاحي" |
| Medium | البوليصة المرجعية بتعرض placeholders زي `DRAFT-BL` و `BKG-REF` و "Port of Discharge (POD)" بدل البيانات الفعلية أو "غير متوفر" | `25-draft-bl-review-main.png` | إظهار "—" مع تنبيه بالنواقص |
| Medium | `DropdownButtonFormField` في عمود "الطرف المسؤول" جوه جدول الـ checklist | `draft_bl_review_tab.dart:1706` | `SearchableDropdownField` أو segmented control |
| Medium | مخالفات UI كتير في التاب: 48 `ElevatedButton`، و 245 `Colors.xxx`، و 9 `Color(0x…)`. والـ header لونه `AppTheme.emerald`، والمعيار charcoal أو cobalt | `draft_bl_review_tab.dart`، `draft_bl_review_screen.dart:91`، `.agents/skills/ui-screen-standards/SKILL.md` (Zone A) | `AppButton`، و `AppTheme`، ولون header قياسي |
| Low | أزرار "تنزيل PDF" و "تنزيل Excel" متكررة مرتين في نفس الصفحة | `25-draft-bl-review-main.png` | شريط تصدير واحد |
| Low | الـ breadcrumb "مراجعة مسودات بوالص الشحن" وعنوان الـ header مقطوع بالإنجليزي "Draft B/L Review & Appr…". ده من مشكلة الـ locale المعروفة | `25-draft-bl-review-main.png` | `supportedLocales`، ومساحة للعنوان |
| Low | console (ويب بس): `Refused to set unsafe header "Accept-Encoding"` | `runtime-errors.json` ← `25-draft-bl-review` | — |
