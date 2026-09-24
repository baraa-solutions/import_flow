# متطلبات واشتراطات الاستيراد للشحنة (Import Regulatory Requirements)
![](../screenshots/18-import-requirements-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الكود:** `BP-011` تقييم متطلبات ومستندات الاستيراد (`docs/phase_01_import_planning.md` سطر 84). بتعتمد على `MD-008` (التعريفة) والموردين.
- **الغرض:** تقييم امتثال الشحنة للاشتراطات الرقابية قبل الشحن على 5 محاور: (1) قرار 43 لسنة 2016 وتسجيل المصانع، و(2) شهادة المنشأ والاتفاقيات، و(3) فحص ما قبل الشحن، و(4) موافقات وتصاريح جهات العرض، و(5) الشهادات الفنية وتأكيد الإبحار. ومعاها مسار (إصدار الرقم المسبق ← الفحص ← الموافقات ← التصريح بالإبحار)، وسجل للدراسات المحفوظة.
- **المستخدمين:** مسؤول الامتثال الجمركي / الاستيراد.
- **نوع الشاشة:** شاشة مرحلة (BP-011)، لكنها مبنية بـ `AppBar` + `TabBar` عادي (`import_requirements_screen.dart:708-720`)، مش `VerticalStageScaffold`، ومن غير Stage badge ولا Skip / Stop.

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar: "المرحلة 1: التخطيط والدراسات المسبقة" ← "متطلبات واشتراطات الاستيراد للشحنة" (index 43). وبتتفتح كمان كصفحة كاملة من `LifecycleBoardScreen` ومن جرس الإشعارات.
- **الصلاحية:** أي مستخدم مسجل. `dependencies=[Depends(get_current_user)]` ومن غير RBAC (`modules/import_requirements/router.py:11`).
- **تحميل البيانات:** `initState` ← `refreshData()` للتقييمات، ومعاها الملفات والموردين والتعريفة والاستشارات وأوامر الشراء (`:205-220`). اختيار ملف بيعمل prefill: `GET /api/v1/import-requirements/prefill/{import_file_id}` (`:291`).

## مكونات الشاشة

### الحقول

**تاب التقييم:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة المربوط | `SearchableDropdownField` | نعم | `pleaseSelectImportFileError` (`:998`) | `/api/v1/import-files` |
| رقم القيد الجمركي المسبق للشحنة (اختياري) | Text + نسخ | لا | — | "يُستدعى آلياً من ملف الشحنة عند استخراجه لاحقاً" |
| المورد الخارجي والمصنع | `SearchableDropdownField` | لا | `validator: null` (`:1019`) | `/api/v1/suppliers` |
| بند التعريفة الجمركية | Text + نسخ | نعم | `hsCodeRequiredError` (`:1274`) | إدخال / prefill |
| وصف السلعة والصنف التجاري | Text | نعم | `commodityDescRequiredError` (`:1292`) | إدخال |
| بلد المنشأ والتصدير | Text حر | نعم | `countryOfOriginRequiredError` (`:1310`) | إدخال نصي، **مش dropdown** |
| العملة / القيمة بالعملة | Text / Number | نعم | — | افتراضي USD / 0.0 |
| (محور 1) يخضع الصنف لقرار 43 / المصنع مسجل بالقائمة البيضاء | Checkboxes | — | — | — |
| رقم قيد المصنع بالهيئة | Text | — | — | إدخال |
| (محاور 2-5) حقول وCheckboxes خاصة بكل محور | — | — | — | — |

**تاب السجل:** بحث "بحث برقم التقييم، البند الجمركي، رقم القيد المسبق، المورد، أو..."، وفلاتر: حالة المطابقة، ومستوى المخاطر، والسجلات النشطة والمحذوفة (chips "الكل" / "النشطة فقط").

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| العودة للداش بورد / 🔄 تحديث | رجوع / تحديث | `GET /api/v1/import-requirements` | مستخدم مسجل |
| تابات المحاور الخمسة (١..٥) | تبديل المحور المعروض | — | — |
| انقر لنسخ الحقل إلى الحافظة | نسخ | — | — |
| حفظ مسودة (`saveRequirementDraftBtn`) / حفظ التقييم | **الاتنين بينادوا `_saveAssessment`** (`:1933`، و`:1945`) | `POST` / `PUT /api/v1/import-requirements` | مستخدم مسجل |
| مبرر استثناء قرار 43 | `_showDecree43JustificationDialog` | — | — |
| **تاب السجل:** إعادة تحميل حية، وتصدير Excel، وتصدير PDF، واستيراد Excel (`MasterDataToolbarWidget`، `:1970-1971`) | عمليات البيانات | `/api/v1/import-requirements/export-excel`، و`/export-pdf`، و`/import-excel` | — |
| تصدير جدول نصوص / تصدير إكسيل / طباعة تقرير (بي دي إف) | تصدير في الـ client (`:1986-2015`) | — | — |
| إنشاء دراسة تقييم جديدة | يرجع لتاب التقييم بفورم فاضي | — | — |
| (في كل صف) تفاصيل، وطباعة إيصال PDF، وحذف / استرجاع | `_showRequirementDetailsDialog`، و`printOrSaveImportRequirementSlipPdf` | `GET /{id}`، و`DELETE /{id}`، و`POST /{id}/restore` | مستخدم مسجل |

### الجداول

- **مسار المتطلبات:** 4 خطوات، ومعاها شارة "حالة الإبحار: Pre-Sailing".
- **بنود التعريفة المرتبطة بالشحنة:** "0 بنود مسجلة"، و"إجمالي القيمة: 0.0 USD".
- **شريط الامتثال والتنبيهات الرقابية للبند:** الاشتراطات الإلزامية، والتنبيهات وحالة الامتثال، والإعفاءات.
- **السجل:** قائمة التقييمات، وكانت فاضية ("لا توجد تقييمات مسجلة مطابقة للبحث الحالي.").

### التابات

1. **📋 تقييم ومطابقة المتطلبات التنظيمية:** `18-import-requirements-tab-1-regulatory-requirements-assessment.png` (زي الـ main).
2. **📑 سجل دراسات المتطلبات المحفوظة:** `18-import-requirements-tab-2-saved-requirements-registry.png`.

### الـ Dialogs

- **"إنشاء دراسة تقييم جديدة" مش dialog.** بيرجع لتاب التقييم inline، والصورة `18-import-requirements-dialog-add.png` (نفس شكل الـ main).
- **صورة أخطاء الـ validation مش موجودة:** الـ harness ملقاش زرار حفظ في الـ viewport ("no save/submit button found"، `capture-manifest.json` screen 18، `status: partial`)، لأن أزرار الحفظ في آخر الصفحة تحت المحاور. قواعد التحقق موثقة من الكود في جدول الحقول.
- من الكود: `_showRequirementDetailsDialog` (تفاصيل الدراسة وما قبل الشحن) و`_showDecree43JustificationDialog`.

### التصدير والطباعة

- `MasterDataExportService.exportImportRequirementsToExcel` (CSV عبر `FileSaveHelper.saveText`)، و`printOrSaveImportRequirementsListPdf` و`printOrSaveImportRequirementSlipPdf` (`Printing.layoutPdf`) (`:2002`، و`:2015`، و`:2319`).
- نسخ TSV للحافظة (`:2493`).
- ومعاهم أزرار `MasterDataToolbarWidget` بتنادي endpoints في الباك إند (شوف الملاحظات).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | أزرار `MasterDataToolbarWidget` (تصدير Excel، وتصدير PDF، واستيراد Excel) بتنادي `/import-requirements/export-excel` و`/export-pdf` و`/import-excel`، والـ router **مفيهوش الـ routes دي**. `GET /export-excel` هيتطابق مع `/{assessment_id}` ويفشل 422 | `import_requirements_screen.dart:1970-1971`؛ `core/widgets/master_data_toolbar.dart:57`، و`:122`؛ `modules/import_requirements/router.py:14-73` | أضف الـ routes أو شيل الـ toolbar |
| Medium | تصدير مكرر في تاب السجل: صف "عمليات البيانات والتصدير / الاستيراد" (Excel / PDF / استيراد) وتحته صف تاني (تصدير جدول نصوص / تصدير إكسيل / طباعة تقرير) | `18-import-requirements-tab-2-saved-requirements-registry.png`؛ `import_requirements_screen.dart:1970-2015` | شريط واحد (`ActionToolbar`) |
| Medium | شاشة مرحلة (BP-011) مبنية بـ `AppBar` + `TabBar` عادي، من غير `VerticalStageScaffold`، ولا Stage badge، ولا Skip / Stop (Skill §9 anti-pattern) | `import_requirements_screen.dart:708-720`؛ `18-import-requirements-main.png` | `VerticalStageScaffold` + `showStageLifecycleControls` |
| Medium | "حفظ مسودة" و"حفظ التقييم" الاتنين بينادوا `_saveAssessment` | `import_requirements_screen.dart:1933`، و`:1945` | draft حقيقي |
| Medium | "بلد المنشأ والتصدير" Text حر وإلزامي بدل `SearchableDropdownField` على الدول (Master Data كنص حر ممنوع) | `import_requirements_screen.dart:1310`؛ `18-import-requirements-main.png` | dropdown على جدول الدول |
| Medium | أزرار الحفظ في آخر صفحة طويلة جداً، والـ harness نفسه ملقاهاش في الـ viewport. مفيش شريط حفظ ثابت | `capture-manifest.json` (screen 18)؛ `18-import-requirements-main.png` | `StandardFormActionBar` ثابت تحت |
| Low | شريط الامتثال بيكتب "HS-Code ()" بأقواس فاضية لو مفيش بند | `18-import-requirements-main.png`؛ `import_requirements_screen.dart:3006` | اخفي الأقواس أو اكتب "لم يُحدد" |
| Low | Labels فيها emoji (📋 و📑) في أسماء التابات، و"Pre-Sailing" إنجليزي في الوضع العربي | `18-import-requirements-main.png` | l10n من غير emoji |
| Low | Console: `Accept-Encoding` (9 مرات). **فرق Web بس** | `runtime-errors.json` | — |
| Low | 20 `ElevatedButton` و20 `Color(0x..)` و83 `Colors.` | `import_requirements_screen.dart` (عدّ grep) | توحيد |
