# مسودة شهادة المنشأ و EUR.1 (Draft COO & EUR.1 Review)
![](../screenshots/27-draft-coo-review-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
الشاشة بتحدد نوع شهادة المنشأ المطلوبة (Standard COO، أو Form A / GSP، أو EUR.1، أو شهادة الصين CCPIT، أو أغادير، أو GAFTA) حسب بلد المنشأ والاتفاقيات. وبعدين بتولّد مسودة رسمية للشهادة من بيانات الملف والفاتورة والباكينج والبوليصة، وتقارن الدرافت اللي جاي من المورد بيها، وتحفظ سجل مراجعات المنشأ. والغرض من ده كله إن الشحنة تستفيد من الإعفاء الجمركي التفضيلي، زي عبارة "REVISED RULES" في خانة 7 في EUR.1.

- **المستخدمين:** موظف التوثيق، والمخلص الجمركي.
- **المرحلة:** المرحلة 3، الخطوة 4 (`stageCode: 'STEP_08_COO'`، `draft_coo_review_screen.dart:92`).
- **الكود:** `BP-022` و `BP-016`. قواعد تصنيف الشهادة موجودة في الكود بس (`classify_coo_certificate_type`، `service.py:2674`)، ومش متوثقة في `docs/01_master_data.md` ولا في `DOMAIN_RULES.md`.

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 3" ← "4. مسودة شهادة المنشأ و EUR.1" (index 19). وكمان كتاب رقم 5 في مصفوفة DC-04.
- **الصلاحية:** أي مستخدم عامل login (`router.py:14`)، ومفيش RBAC على الحفظ ولا الحذف (`router.py:541-583`).

## مكونات الشاشة
الغلاف `DedicatedStageScaffold` بلون `Colors.amber.shade800`. المحتوى `COOReviewTab`، وفيه 4 تابات أفقية على شكل pills.

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختر ملف الشحنة * | `SearchableDropdownField<int>` | نعم | — | `GET /import-files`، وأول ملف بيتختار تلقائي (FILE-2026-0006) |
| نوع شهادة المنشأ * | `SearchableDropdownField<String>` | نعم | — | القيمة الافتراضية في الـ widget هي `'EUR.1'` (`coo_review_tab.dart:42`)، وبعدين بتتغير حسب توصية الـ backend |
| Chips اختيار نوع الشهادة (Standard COO، Form A / GSP، EUR.1، شهادة منشأ الصين CCPIT، شهادة اتفاقية أغادير، GAFTA) | اختيار واحد | لما التصنيف يبقى "مطلوب اختيار يدوي" | — | `allowed_types` من `classify_coo_certificate_type` (`service.py:2674-2760`) |
| نص / OCR للدرافت (تاب 2) | `TextField` | — | — | لصق أو رفع (`_extractFromOcrText`، `:422`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة | دورة حياة الملف | `/import-files/{id}/hold` وغيره | أي مستخدم |
| بحث واستنساخ مسودة شهادة منشأ (Ctrl+D) | `SearchAndCloneCooDialog` (`:115`) وبعده `_cloneCOOReview` | `GET /import-documentation/coo` | — |
| توليد وميكنة المخاطبات والخطابات الرسمية | `FormalLetterGeneratorDialog` | `POST /formal-letters/generate` | — |
| إعادة فحص الاتفاقية | بيعيد تصنيف نوع الشهادة | `GET /import-documentation/coo/draft-template/{fileId}` | — |
| ⚡ فتح المعاينة المصورة والتصدير | `_generateOfficialDraft` (`:320`) | `GET /coo/draft-template/{fileId}?cert_type=` | — |
| التالي: إدخال الدرافت | بينقلك لتاب 2 | — | — |
| تحديث حي للبيانات المستدعاة | `_fetchAndApplyDraft` (`:273`) | draft-template | — |
| نسخ البيانات 📋 / حفظ إكسل (Excel) 📊 / حفظ وطباعة PDF 🖨️ | تصدير المسودة المصورة | Client، ومنه لـ `CooExportService` ثم `FileSaveHelper` | — |
| تشغيل المقارنة (تاب 3) | `_runComparison` (`:475`) | `POST /import-documentation/coo/compare` | — |
| حفظ / حفظ كمسودة | `_saveReview` (`:517`)، فيه `_isSavingDraft` و `_isCertifying` | `POST /coo` أو `PUT /coo/{id}` | — |
| حذف مراجعة (تاب 4) | `_deleteCOODraftSession` (`:2270`)، soft delete (`repository.py:613-617`) | `DELETE /coo/{id}` | أي مستخدم |

### الجداول
- **محرك اتخاذ القرار:** chips فيها بلد المنشأ بالفاتورة (India)، وحالة "⚠️ مطلوب اختيار يدوي (اتفاقيات متعددة)"، ورسالة الإعفاء.
- **بانر الملاحظة الجمركية** (فوق المعاينة): "ملاحظة جمركية: في مرحلة التخليص الجمركي بمصر، يُشترط أن يحتوي البند 11 على ختم وتوقيع المصدر، وأن يحتوي البند 12 على الختم الرسمي للجهة المعتمدة…"، والنص مقطوع بـ "…" في الصورة لأنه سطر واحد.
- **المعاينة المصورة لـ EUR.1** (`visual_draft_coo_sheet.dart`): MOVEMENT CERTIFICATE، والخانات من 1 لـ 12 (Exporter، Certificate used in preferential trade between، …)، ورقم المسودة `DRAFT-4012026040100222`.
- **مصفوفة المقارنة** (تاب 3) و **سجل مراجعات المنشأ** (تاب 4، فيه تصدير Excel و PDF و TSV، `:2443-2513`): متصوروش.

### التابات
1. **متطلبات شهادة المنشأ و EUR.1**: `27-draft-coo-review-main.png`.
2. **إدخال واستخراج الدرافت**: متصورش.
3. **مصفوفة المقارنة والفروق**: متصورش.
4. **سجل مراجعات المنشأ**: متصورش.

الـ harness مسجلش التابات دي كتابات، لأنها أزرار pills داخلية.

### الـ Dialogs
مفيش dialog إضافة (`capture-manifest.json`: "no add/create button found")، فمفيش صورة validation. الـ dialogs اللي في الكود: `SearchAndCloneCooDialog`، و `CloneEntityReviewDialog`، و `_showCOOReviewDetailsDialog` (`:2303`)، و `FormalLetterGeneratorDialog`. ولا واحد فيهم اتصور.

### التصدير والطباعة
مسودة الشهادة: نسخ، و Excel، و PDF مع طباعة (`CooExportService`). السجل: Excel و PDF و TSV (`TableExportService`). كلهم بيعدوا على `FileSaveHelper`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Critical | غلط جمركي: شحنة منشأها **الهند** بيتعملها افتراضياً مسودة EUR.1 خانة 4 فيها "EU"، ورسالة "مؤهلة للإعفاء الجمركي التفضيلي الكامل (ضريبة وارد 0%) … بموجب اتفاقية الشراكة المصرية الأوروبية". الهند مش طرف في الاتفاقية. السبب إن لو التصنيف مرجعش نوع موصى بيه، الـ backend بيرجع لـ EUR.1. ده ممكن يوصل لإقرار جمركي بإعفاء مش مستحق | `27-draft-coo-review-main.png`، `modules/import_documentation/service.py:3112-3117`، `:3480-3536` (`box_4_country_origin: "EU"` والرسالة)، والقيمة الافتراضية في الواجهة `coo_review_tab.dart:42` | لو المنشأ مش من الـ EU، الـ fallback يبقى "Standard COO" من غير رسالة إعفاء، ورسالة الإعفاء تطلع بس لو المنشأ فعلاً طرف في الاتفاقية |
| High | رسايل متناقضة في نفس الكارت: الـ chip بيقول "مؤهلة للإعفاء…"، وتحتها بانر بيقول "لا يوجد تصنيف تفضيلي تلقائي لهذا المنشأ — يُترك الاختيار للمستخدم"، والشهادة المعروضة EUR.1 | `27-draft-coo-review-main.png` | الرسالة تتبني من نتيجة التصنيف بس |
| Medium | نسبة ضريبة القيمة المضافة 14% مكتوبة ثابتة في نص قالب الـ Standard COO، وده مخالف لقاعدة "ممنوع Hard-Code أي نسبة ضريبية" | `modules/import_documentation/service.py:3478` | النسبة تيجي من جدول الضرائب / التعريفة |
| Medium | لون الـ header `Colors.amber.shade800`، مش من `AppTheme`. وفي التاب 26 `ElevatedButton` و 130 `Colors.xxx` | `draft_coo_review_screen.dart:96`، `coo_review_tab.dart:918` | `AppTheme` و `AppButton` |
| Medium | 4 تابات أفقية (pills). المعيار بيمنع TabBar أفقي لما يبقى عدد التابات 4 أو أكتر | `27-draft-coo-review-main.png`، `.agents/skills/ui-screen-standards/SKILL.md` (§9 Anti-Patterns) | قايمة رأسية زي Draft B/L |
| Low | خلط لغات وإيموجي في labels الأزرار ("نسخ البيانات 📋"، "حفظ إكسل (Excel) 📊"، "حفظ وطباعة PDF 🖨️") | `27-draft-coo-review-main.png` | labels موحدة من غير إيموجي |
| Low | الـ breadcrumb بيقول "مراجعة مسودات بوالص الشحن"، والعنوان "Draft COO & EUR.1 Review" بالإنجليزي. ده من مشكلة الـ locale المعروفة | `27-draft-coo-review-main.png` | `supportedLocales` |
| Low | console (ويب بس): `Refused to set unsafe header "Accept-Encoding"` | `runtime-errors.json` ← `27-draft-coo-review` | — |
