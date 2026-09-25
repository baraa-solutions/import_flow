# دراسة النولون والجدول الزمني وسيناريوهات الشحن (Freight Studies & Shipping Scenarios)
![](../screenshots/13-shipping-scenarios-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الأكواد:** `BP-006` تحديد وسيلة الشحن، و`BP-007` تقييم سيناريوهات الشحن، و`BP-008` إدارة عروض أسعار النولون (`doc.md` سطر 1714-1716، و`docs/phase_01_import_planning.md`).
- **الغرض:** دراسة مقارنة بين خيارات الشحن (الخط الملاحي، والوكيل، والباخرة / الرحلة، والموانئ، وETD / ETA، وأيام التأخير، والمخاطر، والتكلفة)، وحساب متوسط موعد الوصول للمخزن، وأسرع وأبطأ خط، والخط الموصى به. وفيها أداة AI لاستخراج عروض النولون من نص أو مستند.
- **المستخدمين:** مسؤول الشحن / اللوجستيات.
- **نوع الشاشة:** Type A (Stage Screen)، مبنية على `VerticalStageScaffold` بـ `stageCode: 'STEP_01'` (`shipping_scenarios_screen.dart:1292-1306`).

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar: "المرحلة 1: التخطيط والدراسات المسبقة" ← "دراسة النولون والجدول الزمني والسجلات المحفوظة" (index 4). والـ index 5 هو نفس الشاشة مفتوحة على تاب السجل، ومن غير عنصر في الـ sidebar.
- **الصلاحية:** أي مستخدم مسجل. `dependencies=[Depends(get_current_user)]` ومن غير RBAC (`modules/shipping_scenarios/router.py:15-19`).
- **تحميل البيانات:** `_refreshData` بيجيب الجلسات والشركاء والمشاريع وأوامر الشراء والمواقع وملفات الاستيراد والعملات (`:299-320`).

## مكونات الشاشة

### الحقول

**إعدادات ومعلمات دراسة الشحن:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| مسمى دراسة خيارات الشحن | Text | نعم | "هذا الحقل مطلوب" (`:1599`) | إدخال |
| تاريخ جاهزية البضاعة (CRD) | Date | نعم | — | افتراضي: النهارده + 5 |
| ربط بملف استيراد / ربط بأمر الشراء / ربط بمشروع | `SearchableDropdownField` | لا | — | `/import-files`، و`/purchase-orders`، و`/projects` |
| عنوان الاستلام / المصنع | Text | لا | — | إدخال |
| أيام نموذج 4 المتوقعة / أيام التخليص الجمركي المتوقعة | Number (d) | لا | — | افتراضي 5 / 7 |

**لكل خيار شحن (كارت):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| وكيل الشحن / الناقل | `SearchableDropdownField` | لا | — | `/external-service-providers` |
| الخط الملاحي | `SearchableDropdownField` + زرار "تكويد خط ملاحي جديد بالذكاء الاصطناعي" | نعم | — | الشركاء (خطوط ملاحية) |
| اسم الباخرة / الرحلة | Text | نعم | `l.requiredField` (`:2072`) | إدخال |
| رقم الرحلة | Text | لا | — | إدخال |
| ميناء السفر (POL) / ميناء الوصول (POD) | `SearchableDropdownField` | لا | — | `/transport-locations` |
| المخلص الجمركي | `SearchableDropdownField` | لا | — | الشركاء |
| تاريخ الإبحار (ETD) / تاريخ الوصول المتوقع (ETA) | Date | نعم | — | إدخال |
| أيام التأخير المتوقعة | Number | لا | — | إدخال |
| مستوى المخاطر | `SearchableDropdownField` (Low / Medium / High) | — | — | ثابتة (`:2220-2227`) |
| محتسب ✅ | Checkbox | — | — | يدخل الخيار في الحساب |

**أداة AI:** مربع "لصق نص رسالة أو إيميل عرض السعر..." وأزرار: لصق نص العرض، وتفريغ، ونموذج تجريبي، ورفع مستند عرض السعر، واستخراج وتحليل عروض السعر.

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة عند هذه المرحلة | تحكم دورة الحياة (`VerticalStageScaffold`). لو مفيش ملف استيراد مختار، الزرارين بيفتحوا dialog تختار فيه الملف الأول (`_showSelectAndSkipDialog` / `_showSelectAndHoldDialog` في `core/widgets/shipment_stage_lifecycle_control.dart:209-247`) | `/import-files/{id}/...` | `import_files.edit` / `close` |
| بحث واستنساخ دراسة شحن | `_openSearchAndCloneStudyDialog` | `POST /api/v1/shipping-scenarios/{id}/clone` | مستخدم مسجل |
| 🚀 استخراج عروض أسعار النولون | `SmartUploadButton` (freightQuotation) | `POST /api/v1/smart-upload/upload` | مستخدم مسجل |
| 🔄 إعادة تحميل حية | `_refreshData(force: true)` | كل الـ GETs | — |
| العودة للداش بورد | رجوع | — | — |
| استخراج وتحليل عروض السعر ⚡ / رفع مستند عرض السعر 📄 | استخراج AI | `/smart-upload/parse-text/freight-quotation`، و`/smart-upload/upload` | مستخدم مسجل |
| إضافة خيار شحن جديد | يضيف كارت خيار inline | — | — |
| استنساخ خيار الناقل (Ctrl + D) / حذف | تكرار / حذف كارت | — | — |
| إعادة تحميل حية 🔄 / تفريغ وبدء تسجيل جديد 🔄 | تحديث / تفريغ الفورم | — | — |
| حفظ مؤقت ومتابعة لاحقة 💾 | **نفس دالة الحفظ النهائي** `_saveEvaluationSession` | `POST /api/v1/shipping-scenarios` | مستخدم مسجل |
| حفظ الدراسة والنتائج ✅ | حفظ + `_showSaveSuccessReportDialog` | `POST` / `PUT /{session_id}` | مستخدم مسجل |
| **تاب السجل:** تحديث السجل، وإعادة تحميل حية، وتصدير Excel، وتصدير PDF، واستيراد Excel (`MasterDataToolbarWidget`)، وبحث واستنساخ، وإخفاء الملغية | إدارة السجل | `moduleEndpoint: 'shipping-evaluations'` ← `/api/v1/shipping-evaluations/export-excel` ... | — |

### الجداول

- **مؤشرات فوق:** متوسط موعد التوصيل للمخزن، وأسرع خط ملاحي وصولاً، وأبطأ خط ملاحي وصولاً، والخط الموصى به رسمياً.
- **السجل:** مؤشرات (إجمالي الدراسات، ونشطة، ومتوسط الترانزيت، ومع توصية) وقائمة الدراسات المحفوظة. كانت فاضية في الـ scratch DB.

### التابات

1. **Scenarios Evaluator (دراسة وسيناريوهات الشحن):** `13-shipping-scenarios-tab-1-scenarios-evaluator.png`. فيه المؤشرات، وأداة AI، والإعدادات، وكروت الخيارات، وشريط الحفظ تحت.
2. **Saved Evaluations Log (سجل الدراسات المحفوظة):** `13-shipping-scenarios-tab-2-saved-evaluations-log.png`. فيه مؤشرات، و"عمليات البيانات والتصدير/الاستيراد"، وبحث "ابحث بكود الدراسة، العنوان، أو الملاحظات..."، واستنساخ.

> أسماء التابات والعنوان في الهيدر ظاهرين بالإنجليزي ("Freight Shipping Scenarios & Carrier Evaluation"، و"Operations & Stages") رغم إن الوضع عربي. ده من الـ bug المعروف بتاع الـ locale: `MaterialApp` بيعمل `Directionality` من `en_US`، و`VerticalStageScaffold` بيقرر اللغة بـ `Directionality.of(context)` (`core/widgets/vertical_stage_scaffold.dart:76`، و`:279`، و`:342`).

### الـ Dialogs

- **"إضافة خيار شحن جديد" مش dialog.** بيضيف كارت inline (`capture-manifest.json`)، والصورة `13-shipping-scenarios-dialog-add.png`.
- **أخطاء الـ validation:** `13-shipping-scenarios-dialog-add-validation.png`. بعد الحفظ والفورم فاضي ظهر "هذا الحقل مطلوب" تحت "مسمى دراسة خيارات الشحن" بإطار أحمر، وده صح.
- من الكود: `UniversalEntityExtractorDialog` (تكويد خط ملاحي)، و`FreightQuotationsExtractorDialog`، و`CloneEntityReviewDialog`، وتقرير النجاح، ومقارنة الحاويات، ومخطط الرص.

### التصدير والطباعة

- تاب السجل: تصدير Excel / PDF واستيراد Excel عن طريق `MasterDataToolbarWidget` (`widgets/saved_scenarios_registry_tab.dart:133-134`)، بـ URL مبني من `moduleEndpoint` (`core/widgets/master_data_toolbar.dart:57`، و`:122`).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | تصدير Excel / PDF واستيراد Excel في تاب السجل بيستخدموا `moduleEndpoint: 'shipping-evaluations'`، لكن الـ router الحقيقي `prefix="/api/v1/shipping-scenarios"`، ومفيش فيه routes للتصدير أصلاً. فالأزرار دي هتفشل (404) | `features/shipping_scenarios/widgets/saved_scenarios_registry_tab.dart:134`؛ `modules/shipping_scenarios/router.py:15-19`، و`:22-88` | صحّح الـ endpoint وأضف routes التصدير، أو صدّر في الـ client |
| Medium | "حفظ مؤقت ومتابعة لاحقة" بينادي نفس `_saveEvaluationSession` بتاع الحفظ النهائي، فمفيش draft | `shipping_scenarios_screen.dart:2924-2925` و`:2946` | status=draft وvalidation أخف |
| Medium | زرار "🚀 استخراج عروض أسعار النولون" في الهيدر مقصوص من الشمال والنص مش باين كله، لأن الـ `headerActions` جوه `Flexible` والمساحة مش كفاية لـ 3 أزرار + Skip + Stop | `13-shipping-scenarios-main.png`؛ `shipping_scenarios_screen.dart:1307-1332`؛ `core/widgets/vertical_stage_scaffold.dart:215-223` | صغّر الأزرار أو حطها في ⋮ |
| Medium | Labels الأزرار فيها emoji مكررة مع الأيقونة ("حفظ مؤقت ومتابعة لاحقة 💾"، و"تفريغ وبدء تسجيل جديد 🔄"، و"حفظ الدراسة والنتائج ✅") | `13-shipping-scenarios-main.png`؛ `shipping_scenarios_screen.dart:2909`، و`:2924` | أيقونة واحدة من غير emoji |
| Low | عنوان الشاشة وأسماء التابات بالإنجليزي في الوضع العربي (الـ bug المعروف بتاع الـ locale) | `13-shipping-scenarios-main.png`؛ `core/widgets/vertical_stage_scaffold.dart:76` | صلّح `supportedLocales` |
| Low | خيارات مستوى المخاطر نص إنجليزي ثابت: `'Low Risk 🟢'` و`'Medium Risk 🟠'` و`'High Risk 🔴'` | `shipping_scenarios_screen.dart:2224-2226` | l10n |
| Low | Console: `Accept-Encoding` (11 مرة). **فرق Web بس** | `runtime-errors.json` | — |
| Low | 18 `ElevatedButton` و147 `Colors.` و14 `Color(0x` بدل `AppButton` / `AppTheme` | `shipping_scenarios_screen.dart` (عدّ grep) | توحيد |
