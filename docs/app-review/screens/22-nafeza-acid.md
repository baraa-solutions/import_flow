# الرقم التعريفي المبدئي للشحنة ACID (ACID Operations (Nafeza))
![](../screenshots/22-nafeza-acid-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
الشاشة دي بتغطي دورة رقم الـ ACID كاملة (Advance Cargo Information) على منظومة نافذة (MTS): تجهيز بيانات طلب الرقم، وقراءة إشعار نافذة الخام واستخراج الرقم منه، ومقارنة بيانات الـ ACID بأمر الشراء والفاتورة، وسجل الأرقام المصدرة، ومتتبع صلاحية الرقم لحد الإفراج الجمركي.

- **المستخدمين:** موظف الاستيراد / التوثيق، والمخلص الجمركي اللي بيتابع صلاحية الـ ACID.
- **المرحلة:** المرحلة 2 "بداية الشحنة والتسجيل المسبق" (`stageCode: 'PHASE-2: STEP_05'` في `nafeza_acid_screen.dart:562`).
- **الكود:** `BP-014` في `docs/phase_03_import_documentation.md` ("Request & Verify ACID Number")، لكن نفس العملية اسمها `BP-015` في جدول `doc.md` (سطر 1731). الترقيم مش متسق بين المرجعين.

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 2: بداية الشحنة والتسجيل المسبق" ← "الرقم التعريفي المبدئي للشحنة ACID" (index 11). الـ indices من 12 لـ 15 بتفتح نفس الشاشة على التابات من 2 لـ 5. وكمان بتتفتح من `ImportDocumentationScreen` (case 0)، ودي wrapper مش مستخدمة.
- **الصلاحية:** أي مستخدم عامل login. الـ router `modules/import_documentation/router.py:14` عليه `dependencies=[Depends(get_current_user)]` بس، ومفيش RBAC permission code على الـ endpoints، ولا حتى على الحذف (`DELETE /acid-sessions/{id}`، `router.py:120`).

## مكونات الشاشة
الـ header عبارة عن `VerticalStageScaffold` لونه `AppTheme.charcoal`، وجنبه قايمة تابات رأسية فيها 5 تابات. ظاهر في الصورة إن العنوان "Nafeza Advance Cargo Information (ACID)"، والـ badge "Nafeza ACID Issue"، وعناوين التابات كلها بالإنجليزي (شوف ملاحظة الـ locale).

### الحقول
**تاب 1، طلب إصدار الرقم المبدئي** (`22-nafeza-acid-tab-1-acid-request-form.png`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختر ملف الشحنة لطلب ACID | `SearchableDropdownField<int>` | لا (بيملا الباقي تلقائي) | — | `GET /api/v1/import-files` |
| الشركة المستوردة | `SearchableDropdownField<int>` | — | — | `GET /api/v1/import-companies` |
| الرقم الضريبي للمستورد * | `TextFormField` | نعم | غير فاضي (رسالة الخطأ هي اسم الحقل نفسه، `nafeza_acid_screen.dart:1224`) | بيتملا من الشركة |
| عنوان المستورد المسجل بنافذة | `TextFormField` | لا | — | بيتملا من الشركة |
| المصدر الأجنبي | `SearchableDropdownField<int>` | — | — | `GET /api/v1/suppliers` |
| نوع التسجيل | `SearchableDropdownField<String>` (القيمة الافتراضية: الرقم الضريبي VAT) | — | — | قايمة ثابتة |
| رقم السجل / المعرف الضريبي بالخارج * | `TextFormField` | نعم | غير فاضي (`:1279`) | من المورد |
| دولة المنشأ / التصدير * | `TextFormField` نص حر | نعم | غير فاضي (`:1308`) | من المورد، ومش FK على جدول الدول |
| معرف منصة كارجو إكس (CargoX) | `TextFormField` | لا | — | من المورد |
| رقم الفاتورة المبدئية * | `TextFormField` | نعم | غير فاضي (`:834`) | يدوي أو من أمر الشراء |
| تاريخ الفاتورة * | حقل تاريخ | نعم | — | افتراضي: النهارده |
| نوع الفاتورة المقدمة | `SearchableDropdownField<String>` (مبدئية / تجارية) | — | — | قايمة ثابتة (`:846`) |
| ميناء الشحن (POL) * | `TextFormField` نص حر | نعم | غير فاضي (`:863`) | بيتملا من الملف، ومش dropdown مواني |
| ميناء الوصول والتفريغ (POD) * | `TextFormField` نص حر | نعم | غير فاضي (`:873`) | زي اللي قبله |
| المخلص الجمركي المسؤول | `SearchableDropdownField<int>` | لا | — | `GET /api/v1/external-service-providers` |
| هاتف المخلص للتواصل | `TextFormField` | لا | — | من المخلص |
| تاريخ تقديم الطلب بنافذة * | حقل تاريخ | نعم | — | افتراضي: النهارده |

**تاب 2، الإدخال الذكي من نافذة** (`22-nafeza-acid-tab-2-mts-smart-ai-parser.png`): فيه dropdown اسمه "ربط بنتيجة ملف شحنة"، وصندوق نص كبير "الصق نص إشعار نافذة الخام هنا" (الـ hint: `إشعار نافذة [رقم ACID: 19 رقماً]...`).

**تاب 4، سجل إصدارات ACID:** حقل بحث "بحث في سجل أرقام ACID برقم القيد، المورد، رقم الملف...".
**تاب 5، متتبع الصلاحية:** حقل بحث "بحث في متتبع الصلاحيات والإفراج الجمركي...".

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة | بيفتح dialog تخطي الخطوة (`ShipmentStageLifecycleControl` ← `SkipStepDialogHelper`) | import-files lifecycle | أي مستخدم |
| إيقاف الشحنة عند هذه المرحلة | بيوقف الملف عند المرحلة دي | `POST /api/v1/import-files/{id}/hold` | أي مستخدم |
| بحث واستنساخ طلب ACID (في الـ header وتحت الفورم) | بيفتح `SearchAndCloneAcidDialog`، واختصاره Ctrl+D | `GET /acid-sessions` | أي مستخدم |
| تحديث | بيعيد تحميل الملفات والشركات والموردين والشركاء وأوامر الشراء والـ sessions والمتتبع | عدة GET | أي مستخدم |
| العودة للداش بورد | بيرجع للوحة التحكم | — | — |
| حفظ بيانات الطلب وإرسالها للمطابقة | `_saveAcidRequest` (`:2977`) وفيه loading spinner (`_isSaving`) | `POST /api/v1/import-documentation/acid-sessions` أو `PUT .../{id}` | أي مستخدم |
| الانتقال للإدخال الذكي من نافذة | بينقلك لتاب 2 | — | — |
| تحميل نص إشعار نافذة نموذجي | بيملا نص تجريبي | `GET /acid/templates` | — |
| استيراد نص من جلسة سابقة | dialog `_openImportRawTextFromPreviousDialog` | `GET /acid-sessions` | — |
| لصق من الحافظة / مسح النص | بيتعامل مع الـ clipboard ومع صندوق النص | — | — |
| تشغيل المحلل الذكي واستخراج البيانات | `_parseMtsText` (`:3094`)، فيه spinner | `POST /api/v1/import-documentation/acid/parse-text` | أي مستخدم |
| تشغيل مصفوفة المطابقة الفورية (تاب 3) | `_runComparison` (`:3250`) | `POST /api/v1/import-documentation/acid/compare` | أي مستخدم |
| Copy Table / Export Excel / Export PDF (تاب 4 و5) | نسخ TSV وتصدير عن طريق `TableExportService`، وده بيستدعي `FileSaveHelper.exportAndSaveFile` | — (Client side) | — |
| طلب ACID جديد (تاب 4) | بيرجعك للفورم فاضي | — | — |
| استنساخ سجل ACID إلى مسودة جديدة (أيقونة في كل صف من صفوف المتتبع) | بيفتح `CloneEntityReviewDialog` | `POST /acid-sessions` بعد التأكيد | أي مستخدم |
| حذف (في صفوف السجل) | بيعمل soft delete وقبله تأكيد | `DELETE /acid-sessions/{id}` وبعدها `PATCH .../restore` | أي مستخدم، من غير RBAC |

### الجداول
- **سجل إصدارات ACID (تاب 4):** بيعرض `acid-sessions`. أعمدته حسب التصدير (`_exportAcidRegistryToExcel`، `:3921`): رقم ACID، ملف الشحنة، المصدر الأجنبي، الشركة المستوردة، تاريخ الإصدار، تاريخ الصلاحية، حالة الصلاحية (مصدر وساري / مسودة مؤقتة / تحت المراجعة). فيه بحث نصي. في بيانات المراجعة كان فاضي خالص: "لم يتم العثور على طلبات ACID مطابقة" (`22-nafeza-acid-tab-4-acid-issuance-registry.png`).
- **متتبع الصلاحية والإفراج (تاب 5)** (`22-nafeza-acid-tab-5-expiry-release-tracker.png`): فوقه 4 بطاقات مؤشرات: إجمالي أرقام ACID (5)، ساري أكتر من 14 يوم (2)، أوشك على الانتهاء في حدود 14 يوم (1)، منتهي الصلاحية (1). الأعمدة: الإجراءات، رقم ACID (link)، ملف الشحنة ومعاه أمر الشراء، المصدر الأجنبي، تاريخ الصلاحية، الأيام المتبقية (ملونة)، حالة الصلاحية (chip). المصدر `GET /api/v1/import-documentation/acid/tracker`، والـ backend بيجمع فيه ملفات الاستيراد اللي عليها رقم ACID مع الـ sessions (`service.py:414-500`). فيه بحث، والترتيب هو اللي راجع من الـ backend.

### التابات
1. **ACID Request Form**: الفورم اللي فوق. الصورة: `22-nafeza-acid-tab-1-acid-request-form.png` (هي نفسها `-main`).
2. **MTS Smart AI Parser**: لصق إشعار نافذة وتحليله، وبعدها حفظ النتيجة كـ session أو كمسودة (`_saveMtsResultAsAcidSession`، `:3432`). الصورة: `22-nafeza-acid-tab-2-mts-smart-ai-parser.png`.
3. **Discrepancy Matrix**: بتختار ملف وتشغّل المقارنة، والنتيجة جدول مطابق / غير مطابق لكل حقل. الصورة: `22-nafeza-acid-tab-3-discrepancy-matrix.png` (حالة فاضية فيها التعليمات بس).
4. **ACID Issuance Registry**: `22-nafeza-acid-tab-4-acid-issuance-registry.png`.
5. **Expiry & Release Tracker**: جنبه badge بعدد العناصر (5). الصورة: `22-nafeza-acid-tab-5-expiry-release-tracker.png`.

### الـ Dialogs
- **Clone ACID, Review & Confirm** (`CloneEntityReviewDialog`): الصورة `22-nafeza-acid-dialog-add.png`. الـ harness اتسجل الـ dialog ده على إنه dialog-add لأن الشاشة معندهاش dialog إضافة منفصل، والإضافة بتتم من فورم تاب 1. الحقول: Target New Reference Code (افتراضي `ACID-EG-2026-DRAFT`)، Target Title / Name، Additional Clone Notes (اختياري). فيه لوحة بالبيانات اللي هتتنسخ (المستورد، المصدر، الدولة، رقم الفاتورة المبدئية، المواني)، ولوحة بالحقول اللي بتتصفر إجباري (رقم ACID، حالة الإفراج، تاريخ الطلب، الـ session السابقة)، ومعاهم traceability للمصدر. الأزرار: Cancel، و Confirm Clone & Create Record.
- **صورة أخطاء الـ validation:** مش موجودة. الـ harness سجل "no save/submit button found in the add dialog" (`capture-manifest.json`، شاشة 22)، لأن التسجيل الفعلي في تاب 1 وزرار الحفظ جوه الصفحة نفسها، مش في dialog.
- Dialogs تانية في الكود ومتصورتش: `SearchAndCloneAcidDialog`، و `_openImportRawTextFromPreviousDialog`، و `_showEditMtsDataDialog`، وتأكيد الحذف (`:3386`).

### التصدير والطباعة
- سجل الإصدارات: Excel و PDF عن طريق `TableExportService` (`:3952`، `:3992`)، واسم المرحلة في الملف "سجل أرقام ACID" أو "ACID Registry" حسب اللغة.
- المتتبع: Excel و PDF (`:4034`، `:4069`).
- Copy Table: بينسخ TSV للـ clipboard.
- كل ده بيعدي على `FileSaveHelper.exportAndSaveFile` (`core/services/table_export_service.dart:124`، `:406`). على الويب ده بيفتح `showSaveFilePicker` أو بيرجع لـ `<a download>`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | المتتبع بيعرض الـ ACID على إنه "ساري وصالح، متبقي 90 يوم" حتى لو مفيش تاريخ صلاحية ولا تاريخ إصدار خالص. الـ fallback ثابت على 90، والصف الأول ظاهر من غير تاريخ صلاحية | `22-nafeza-acid-tab-5-expiry-release-tracker.png` (صف FILE-2026-0002)، `modules/import_documentation/service.py:461` | لو مفيش تاريخ، الحالة تبقى "تاريخ الصلاحية غير مسجل" من غير أيام، وتطلع تنبيه |
| High | سجل الإصدارات فاضي، والمتتبع في نفس الوقت فيه 5 أرقام. المتتبع بيقرا `import_files.acid_number` كمان، والسجل بيقرا `acid_registration_sessions` بس، فالمستخدم بيشوف مصدرين للحقيقة مختلفين | `22-nafeza-acid-tab-4-acid-issuance-registry.png` مقابل `22-nafeza-acid-tab-5-expiry-release-tracker.png`، `service.py:431-445` | يتوحد المصدر، أو يتعمل session تلقائي لأي رقم ACID متسجل على الملف |
| Medium | الصف اللي الملف بتاعه اتصرف من الجمرك بيطلع عليه label "منتهي الصلاحية" بس بلون أخضر وعلامة صح (FILE-2026-0006، -82 يوم). الـ label في الفرونت بيتحسب من الأيام بس ومش بيبص على `isCustomsReleased`، والـ badge بيتلوّن حسب الإفراج، فالرسالة متناقضة. وكمان بطاقة "منتهي الصلاحية" فيها 1 بس رغم إن فيه صفين بأيام بالسالب | `22-nafeza-acid-tab-5-expiry-release-tracker.png` (آخر صفين)، `nafeza_acid_screen.dart:2774`، `:2782`، `:2860-2863`، `service.py:467-469` | الـ label يبقى "صُرفت من الجمرك" لما `isCustomsReleased` يكون true، زي `status_label_ar` اللي راجع من الباك إند |
| Medium | الموانئ (POL/POD) ودولة المنشأ نص حر في `TextFormField`، ومش `SearchableDropdownField` مربوط بالـ master data. ده مخالف لقاعدة "Master Data كـ FK" | `nafeza_acid_screen.dart:856-874`، `:1302-1309`، الصورة `22-nafeza-acid-main.png` | يتحولوا لـ `SearchableDropdownField` على `/ports` و `/countries` |
| Medium | رسالة خطأ الـ validation هي اسم الحقل نفسه (مثلاً "رقم الفاتورة المبدئية")، مش "هذا الحقل مطلوب" | `nafeza_acid_screen.dart:834`، `:863`، `:873`، `:1224`، `:1279`، `:1308` | استخدام `context.l10n.requiredField` |
| Medium | الـ hint بتاع dropdown الشركة المستوردة والمصدر الأجنبي والمخلص هو "ابحث برقم الملف أو اسم المورد أو الشركة..."، وده hint مكتوب لملف الشحنة ومتكرر غلط. كمان نص الـ label والـ hint راكبين على بعض جوه الحقل | `22-nafeza-acid-main.png` (الحقول الفاضية)، `elements/22-nafeza-acid-main.json` (tooltip الأزرار) | hint مخصص لكل حقل، وإصلاح تداخل الـ label مع الـ hint في `SearchableDropdownField` |
| Medium | مخالفات UI Standards كتير: 36 استخدام لـ `ElevatedButton`، و 178 لـ `Colors.xxx`، و 22 لـ `Color(0x…)`، ومفيش ولا `AppButton` | `nafeza_acid_screen.dart:1032`، `:1464`، `:1631`، `:663` | التحويل لـ `AppButton` وألوان `AppTheme` |
| Medium | نصوص عربي/إنجليزي hard-coded بـ `Localizations.localeOf(context).languageCode == 'ar' ? … : …` بدل `l10n`، زي Copy Table و Export Excel و Export PDF. ومع مشكلة الـ locale بتطلع إنجليزي في الوضع العربي | `nafeza_acid_screen.dart:2178-2198`، `22-nafeza-acid-tab-5-expiry-release-tracker.png` | مفاتيح `l10n` |
| Medium | dialog الاستنساخ ظاهر كله بالإنجليزي وبـ LTR في الوضع العربي (Clone Advance Cargo Information…، Cancel…). ده جاي من مشكلة الـ locale، لأن الـ dialog بيحدد اللغة من `Localizations`/`Directionality` | `22-nafeza-acid-dialog-add.png`، `core/widgets/clone_entity_review_dialog.dart:63-66` | يتحل مع إصلاح `supportedLocales` |
| Low | مشكلة الـ locale المعروفة (`main.dart` بيحدد `ar` من غير `supportedLocales`، فبيتحل لـ `en_US`): عنوان الشاشة والـ badge والتابات الرأسية بالإنجليزي، والـ sidebar على الشمال (LTR) | `22-nafeza-acid-main.png` | إضافة `supportedLocales` |
| Low | زرار "بحث واستنساخ طلب ACID" متكرر مرتين في نفس الشاشة، مرة في الـ header ومرة تحت الفورم | `22-nafeza-acid-main.png` | الاكتفاء بواحد في الـ header |
| Low | الحذف والاسترجاع متاحين لأي مستخدم عامل login، من غير RBAC | `modules/import_documentation/router.py:14`، `:120`، `:130` | permission code للحذف |
| Low | console: `Refused to set unsafe header "Accept-Encoding"`. ده خاص بالويب بس (المتصفح بيمنع الـ header)، ومش bug على الديسكتوب | `runtime-errors.json` ← `22-nafeza-acid` | شيل الـ header في build الويب |
