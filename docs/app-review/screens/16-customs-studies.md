# الدراسات الجمركية وعروض التخليص ومراجعة الضرائب (Customs Studies & Clearance RFQ)
![](../screenshots/16-customs-studies-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الأكواد:** `BP-009` الاستشارة الجمركية الأولية، و`BP-010` تقدير الرسوم والضرائب الجمركية، و`MD-008` (جدول التعريفة / HS Code) (`docs/phase_01_import_planning.md` سطر 63-67).
- **الغرض:** مساحة عمل لدراسة جمركية مبدئية للشحنة: تختار المخلص وملف الاستيراد، وتحسب الرسوم والضرائب لكل بند من بنود أوامر الشراء المربوطة (FOB، والنولون، والتأمين، وCIF، والجمارك، وضريبة القيمة المضافة، ورسم التنمية)، وتطبق قائمة أسعار المخلص، وتسجل الدراسات، وتدير قوائم أسعار المخلصين وعروض التخليص.
- **المستخدمين:** مسؤول الجمارك / المخلص الداخلي / الإدارة المالية.
- **نوع الشاشة:** Type A (Stage Screen) عن طريق `VerticalStageScaffold` (Stage badge "Customs Studies")، ومعاها Skip / Stop.

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar: "المرحلة 1: التخطيط والدراسات المسبقة" ← "الدراسات الجمركية وعروض التخليص ومراجعة الضرائب" (index 6). فيه كمان indices 7 و55 و56 من غير عناصر في الـ sidebar: index 55 = تاب العروض، وindex 56 = وضع **مراجعة الضرائب** (`isTaxReviewMode`) بتابين مختلفين.
- **الصلاحية:** أي مستخدم مسجل. `dependencies=[Depends(get_current_user)]` ومن غير RBAC (`modules/customs_consultation/router.py:33-37`).
- **تحميل البيانات:** `initState` بيجيب الاستشارات، وملفات الاستيراد، وأوامر الشراء، والتعريفة، والعملات، والسيناريوهات، والشركاء، والمشاريع، وأنواع المصروفات، وقوائم الأسعار (`customs_consultation_screen.dart:123-151`).

## مكونات الشاشة

### الحقول

**تاب Customs Workspace (مركز الاستشارة والفحص الجمركي):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| العنوان | Text | نعم | required. **قيمته الافتراضية "دراسة المراجعة الجمركية الأولية لخط إنتاج ومعدات الشحنة"** (`l10n.defaultCustomsConsultationTitle`، `:162`) | إدخال |
| المخلص الجمركي | `SearchableDropdownField` | نعم | — | `/api/v1/external-service-providers` |
| ربط بملف استيراد | `SearchableDropdownField` (الخيار الفاضي "-- جميع الملفات --"، `:2216`) | لا | — | `/api/v1/import-files` |
| إجمالي الضرائب والرسوم (EGP) | Number (محسوب) | — | — | ناتج المحرك |
| عملة البضاعة أو الفاتورة / عملة النولون | `SearchableDropdownField` | — | — | `/api/v1/currencies` |
| سعر الصرف الجمركي للبضاعة / سعر صرف عملة النولون | Number | — | — | **افتراضي 50.0** (`:66`، و`:69`) |
| تاريخ الدراسة الجمركية | Date | — | — | النهارده |
| قيمة النولون بالعملة الأجنبية / النولون البحري أو الجوي (EGP) | Number | — | — | إدخال / محسوب |
| (تحت) التأمين 0.5% / 1% / يدوي، وبنود التعريفة لكل بند | Options / جدول | — | — | `/api/v1/customs-tariff` |

**تاب Consultations Log:** بحث "بحث بالكود أو العنوان أو المستخلص..."، وفلتر "تصفية الحالة"، وCheckbox "إظهار المؤرشفة".
**تاب Broker Price Lists & Catalog:** فلتر "تصفية حسب المخلص الجمركي".

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة عند هذه المرحلة | تحكم دورة الحياة. لو مفيش ملف استيراد مختار، الزرارين بيفتحوا dialog تختار فيه الملف الأول (`_showSelectAndSkipDialog` / `_showSelectAndHoldDialog` في `core/widgets/shipment_stage_lifecycle_control.dart:209-247`) | `/api/v1/import-files/{id}/...` | `import_files.edit` / `close` |
| 🔄 إعادة تحميل حية | تحديث كل الـ providers (`:1727-1760`) | GETs | — |
| العودة للداش بورد | رجوع | — | — |
| بحث واستنساخ استشارة | `SearchAndCloneConsultationDialog` | `POST /api/v1/customs-consultations/{id}/clone` | مستخدم مسجل |
| تفريغ وبدء تسجيل جديد | تفريغ الفورم | — | — |
| تصدير جدول الحساب مفصول بمسافات جدولية / تصدير جدول الحساب إكسيل / طباعة أو حفظ تقرير الحساب الجمركي / نسخ ملف الحساب الجمركي للحافظة | تصدير الحساب (`:1298-1350`) | في الـ client | — |
| استخراج ذكي لمقايسة تخليص | استخراج AI لعرض مخلص | `/api/v1/smart-upload/...` | — |
| حفظ مؤقت ومتابعة لاحقة | **نفس `_saveConsultation`** | `POST` / `PUT /api/v1/customs-consultations` | مستخدم مسجل |
| حفظ دراسة الاستشارة الجمركية | `_saveConsultation` (`:1387`) | `POST` / `PUT` | مستخدم مسجل |
| مزامنة اشتراطات بنود التعريفة الجمركية مع قائمة المستندات | مزامنة الـ checklist | `/customs-consultations/...` | — |
| عوائق التخليص (كارت قابل للضغط) | عرض العوائق | — | — |
| **Broker Price Lists:** إنشاء قائمة أسعار جديدة لمخلص / إضافة قائمة أسعار الآن / استخراج ذكي 🤖 | `price_list_form_dialog` | `POST /customs-consultations/price-lists` (+ `/clone`، و`/active/{brokerId}`) | مستخدم مسجل |
| **Clearance Quotes:** كل أزرار شاشة 17 (متركّبة جوه التاب) | — | `/api/v1/customs-clearance-quotations/...` | — |

### الجداول

- **مؤشرات أعلى التاب 1:** جاهزية الفحص الجمركي (40%)، وعدد البنود والمستندات (5)، وعوائق التخليص (2).
- **محرك حساب الرسوم والضرائب:** جدول لكل بند (FOB، ونصيب النولون والتأمين، وCIF، ونسبة الجمارك وقيمتها، والضريبة، ورسم الخدمات).
- **Consultations Log:** مؤشرات (0 / 0%) وقائمة الدراسات، وكانت فاضية في الـ scratch DB.
- **Broker Price Lists:** كروت قوائم الأسعار، وفاضية ("لا توجد قوائم أسعار مسجلة للمخلصين المحددين").

### التابات

1. **Customs Workspace (مركز الاستشارة والفحص الجمركي):** `16-customs-studies-tab-1-customs-workspace.png`.
2. **Consultations Log (سجل الدراسات المحفوظة):** `16-customs-studies-tab-2-consultations-log.png`.
3. **Broker Price Lists & Catalog (قوائم الأسعار وتكويد المصروفات):** `16-customs-studies-tab-3-broker-price-lists-catalog.png`. فوقه صف chips (قوائم الأسعار / عروض التخليص / استخراج ذكي) بيكرر التنقل اللي في الـ sidebar.
4. **Clearance Quotes & AI Extractor (عروض التخليص والاستخراج الذكي):** `16-customs-studies-tab-4-clearance-quotes-ai-extractor.png`. ده هو شاشة 17 متركّبة جوه التاب (راجع `17-clearance-quotations.md`).
5. **مركز احتساب ومراجعة الضرائب** و6. **سجل مراجعات الضرائب المحفوظة:** بيظهروا في وضع `isTaxReviewMode` بس (index 56). **متصوروش**: الـ harness ملقاش الـ labels في الـ semantics tree لأن الوضع العادي (index 6) مش بيعرضهم (`capture-manifest.json` issues).

> أسماء التابات والعنوان "Customs Broker Consultation & Inspection Workspace" و"Operations & Stages" ظاهرين بالإنجليزي في الوضع العربي، وده من الـ bug المعروف بتاع الـ locale (`core/widgets/vertical_stage_scaffold.dart:76`، و`:279`، و`:342`).

### الـ Dialogs

- **إنشاء طلب عرض أسعار جديد** (من تاب 4، بيفتح `_showCreateRFQDialog` بتاع شاشة 17): `16-customs-studies-dialog-add.png`. الحقول: عنوان الطلب (**متعبّي بعنوان الـ dialog نفسه**)، وربط بملف استيراد (اختياري)، وميناء التخليص (Alexandria Port)، ونوع الشحنة (Ocean FCL 40HQ)، وعدد الحاويات (1)، والوزن القائم (10000)، والحجم (30). الأزرار: "إلغاء" و"إنشاء الطلب" (`POST /api/v1/customs-clearance-quotations/rfqs`).
- **"الـ validation":** `16-customs-studies-dialog-add-validation.png`. الحفظ والفورم "فاضي" **أنشأ فعلاً طلب جديد `CRFQ-000002`** بعنوان "إنشاء طلب عرض أسعار تخليص جمركي" وبالقيم الافتراضية (Alexandria Port، و10000 كجم، و30 م³)، ومفيش أي رسالة validation ظهرت.
- من الكود: `consultation_details_dialog`، و`AddChecklistItemDialog`، و`AddCustomExpenseDialog`، و`CloneEntityReviewDialog`، و`SearchAndCloneConsultationDialog`، و`price_list_form_dialog`.

### التصدير والطباعة

- Excel: `CustomsExportService.exportCustomsStudyToExcel` (`:1311`) ← `FileSaveHelper.saveText` (CSV بيسمح بـ `xlsx`، `services/customs_export_service.dart:360-371`).
- PDF: `CustomsConsultationPdfService.printOrPreviewCalculationReportPdf` ← `Printing.layoutPdf` (`:1344`).
- TSV ونسخ للحافظة.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Critical | **نسب جمركية وضريبية hard-coded** في الـ Flutter (ممنوع صراحةً في CORE_RULES §6): جمارك 5% وضريبة قيمة مضافة 14% ورسم خدمات 1% ثابتين في حالة الفواتير من غير بنود، وfallback `?? 5.0` و`?? 14.0` لو البند مش لاقي تعريفة، ورسوم نافذة 390 / 392 / 394 (14%) ثابتة في التصدير. كمان الحساب الجمركي في الـ client مش في Service في الباك إند | `customs_consultation_screen.dart:809-814`، و`:904`، و`:945`؛ `services/customs_export_service.dart:92-94` | انقل المحرك لـ Backend Service (skill `customs-landed-cost-engine`) واقرأ النسب من `customs_tariff` / الإعدادات. لو التعريفة ناقصة اعرض خطأ مش نسبة افتراضية |
| High | سعر الصرف الجمركي وسعر صرف النولون بيبدأوا بـ 50.0 ثابتة، مش من جدول العملات، والحساب بيتعمل بيهم على طول | `customs_consultation_screen.dart:66`، و`:69`؛ `16-customs-studies-main.png` (50.0) | اسحب السعر من `/api/v1/currencies` حسب تاريخ الدراسة |
| High | Dialog "إنشاء طلب عرض أسعار" بيحفظ طلب حقيقي بقيم افتراضية (العنوان = عنوان الـ dialog، وميناء، ووزن، وحجم ثابتين) من غير ما المستخدم يدخل حاجة، وزرار الإنشاء من غير loading ولا معالجة أخطاء | `16-customs-studies-dialog-add.png`، و`16-customs-studies-dialog-add-validation.png` (`CRFQ-000002`)؛ `customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart:838-845`، و`:1000-1024` | حقول فاضية + required، و`isLoading`، و`try/catch` مع SnackBar |
| Medium | "حفظ مؤقت ومتابعة لاحقة" و"حفظ دراسة الاستشارة الجمركية" بينادوا نفس `_saveConsultation` | `customs_consultation_screen.dart:1959` و`:1970` | draft حقيقي |
| Medium | العنوان متعبّي افتراضياً بنص ثابت، فكل الدراسات هتتحفظ بنفس الاسم والـ required validator مش هيشتغل | `customs_consultation_screen.dart:162`؛ `app_localizations_ar.dart:1016`؛ `16-customs-studies-main.png` | اقترح `[Code] Company` أو سيبه فاضي |
| Medium | "ربط بملف استيراد" الخيار الفاضي بتاعه "-- جميع الملفات --"، ودي صياغة فلتر مش صياغة اختيار | `customs_consultation_screen.dart:2216`؛ `16-customs-studies-main.png` | "-- غير مرتبط --" |
| Medium | تاب Broker Price Lists فيه صف chips بيكرر نفس التابات اللي في الـ sidebar (قوائم الأسعار / عروض التخليص / استخراج ذكي) | `16-customs-studies-tab-3-broker-price-lists-catalog.png` | شيل التكرار |
| Medium | تابات وضع مراجعة الضرائب (5 و6) مش ليها عنصر في الـ sidebar، ومش بتتفتح غير بـ index 56 | `capture-manifest.json` (16 issues)؛ `inventory.json` notes | أضف عنصر sidebar أو شاشة مستقلة |
| Low | العنوان وأسماء التابات بالإنجليزي في الوضع العربي (الـ bug المعروف بتاع الـ locale) | `16-customs-studies-main.png` | صلّح `supportedLocales` |
| Low | Labels أزرار فيها emoji ("استخراج ذكي لمقايسة تخليص 🤖") | `16-customs-studies-tab-3-broker-price-lists-catalog.png` | أيقونة بس |
| Low | Console: `Accept-Encoding` (23 مرة). **فرق Web بس** | `runtime-errors.json` | — |
| Low | 18 `ElevatedButton` و104 `Colors.` بدل `AppButton` / `AppTheme` | `customs_consultation_screen.dart` (عدّ grep) | توحيد |
