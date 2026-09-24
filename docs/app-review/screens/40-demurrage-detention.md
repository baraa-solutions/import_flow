# تتبع غرامات الأرضيات وحراسات الحاويات (Demurrage & Detention)
![](../screenshots/40-demurrage-detention-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب. قاعدة البيانات الـ scratch **مفيهاش جلسات تتبع**، فتاب التتبع ظاهر فاضي.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** حساب ومتابعة فترات السماح وغرامات الحاويات: **Demurrage** (غرامة الخط الملاحي على بقاء الحاوية في الميناء، USD)، و **Detention** (تأخير رد الحاوية الفاضية، USD)، و **Port Storage** (أرضيات ساحات الميناء، EGP). الحساب بالشرائح التصاعدية حسب سياسة كل خط ملاحي، وبعدها ترحيل الغرامات للتسوية المالية / Landed Cost.
- **المستخدمين:** مسؤول العمليات والشحن، والمستخلص، والمالية (الترحيل للتسوية).
- **المرحلة:** المرحلة 5 "الميناء والتخليص الجمركي" (بادج `STEP_18` "Demurrage & Guard"). مالهاش BP code في `doc.md`، والتطبيق بيسميها **TR-02** (رادار الغرامات)، ومرتبطة بـ **BK-02** (اتفاقية فترات السماح) و **TR-05** (إرجاع الحاويات الفاضية EIR). بتخدم متطلب "عداد أيام السماح والتنبيه المبكر لغرامات الأرضيات" في **BP-029** (`docs/phase_07_customs_clearance.md`)، والترحيل لـ Phase 9 (`docs/phase_09_financial_settlement.md`).

## طريقة الوصول والصلاحية
- **Sidebar:** "المرحلة 5: الميناء والتخليص الجمركي" ← "تتبع غرامات الأرضيات وحراسات الحاويات" (index 44). كمان بتتفتح من `ImportFileDetailsDialog` ("رادار الغرامات (TR-02)")، ومن `LifecycleBoardScreen`، ومن كارت الرادار في الداش بورد (ومعاها `initialImportFileId`).
- **Scaffold:** `Scaffold` + `AppBar` + `AdaptiveTabScaffold` بتابات أفقية (`demurrage_detention_screen.dart:256`، `:258`، `:340`)، مش `VerticalStageScaffold`.
- **الصلاحية:** أي مستخدم عامل login (`modules/demurrage_detention/router.py:45`). مفيش RBAC code.

## مكونات الشاشة

### الحقول
**التاب 1 (فلاتر):** بحث برقم البوليصة أو كود التتبع + "تصفية الحالة" (`SearchableDropdownField<String>`، `:460`).

**التاب 2 (المحاكي):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| الخط الملاحي | `SearchableDropdownField<String>` | أيوه | – | **قايمة ثابتة في الكود** (MSC, Maersk, CMA CGM, …) (`:48`) |
| نوع الحاوية | `SearchableDropdownField<String>` | أيوه | – | قايمة ثابتة (`:59`) |
| عدد الحاويات | TextFormField رقمي | أيوه | > 0 (`:897`) | افتراضي 1 |
| سعر الصرف مقابل الجنيه | TextFormField رقمي | أيوه | > 0 (`:918`) | **افتراضي 50.0 ثابت** (`:42`) |
| سماح الأرضيات بالميناء (يوم) | رقمي | – | – | افتراضي 14 |
| سماح إعادة الفارغ (يوم) | رقمي | – | – | افتراضي 7 |
| تاريخ تفريغ الحاويات من السفينة / خروج البوابة / إعادة الفارغ | Date pickers (ListTile) | التفريغ أيوه | – | افتراضي: التفريغ من 16 يوم، والباقي فاضي = "لم تخرج بعد" |

**Dialog بدء تتبع شحنة:** الخط الملاحي، وميناء الوصول (`SearchableDropdownField`، والقايمتين ثابتين في الكود)، ورقم بوليصة الشحن (إلزامي)، ورقم الحاوية (إلزامي)، ونوع الحاوية، وتاريخ التفريغ.

**Dialog إضافة سياسة خط ملاحي:** الخط، ونوع الحاوية، وسماح Demurrage، وسماح Detention، وسماح الأرضيات، والسعر اليومي للأرضيات EGP (افتراضي 250).

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| توثيق فترات السماح (BK-02) (الهيدر) | `FreeDaysAgreementDialog` | `POST /api/v1/demurrage-detention/free-days-agreement`، `GET .../free-days-agreement/{importFileId}` | Authenticated |
| أيقونة موصل بيانات الشحن (الهيدر) | `showFreightDataMonitorDialog`: مؤشر النولون، وقواعد الخطوط، وتعريفات أرضيات الموانئ | `/api/v1/freight-data/...` | Authenticated |
| تحديث (الهيدر) | `ref.invalidate(demurrageProvider)` + `loadInitialData()` | `GET .../trackings`، `GET .../policies` | Authenticated |
| العودة للداش بورد | رجوع | – | – |
| بدء تتبع شحنة جديدة | `_showAddTrackingDialog` | `POST .../trackings` | Authenticated |
| إرجاع الحاويات (TR-05) | `EmptyContainerReturnDialog` | `POST .../empty-container-return` | Authenticated |
| طباعة كشف المتابعة / تصدير إكسيل / تصدير جدول نصوص | تصدير الجلسات (متعطلين لما القايمة فاضية) | – | – |
| (كارت الجلسة) رادار العداد المزدوج | `DualClockRadarDialog` | `GET .../trackings/{id}/dual-clock` | Authenticated |
| (كارت) تحديث تواريخ الخروج والإعادة | `_showUpdateDatesDialog` | `PUT .../trackings/{trackingId}` | Authenticated |
| (كارت) ترحيل للتسوية المالية | `_handlePushToSettlement` | `POST .../trackings/push-to-settlement` | Authenticated |
| (المحاكي) إعادة احتساب الغرامات الآن | `_runQuickSimulation` | `POST .../simulate` | Authenticated |
| (المحاكي) نسخ تفاصيل الحساب | TSV للـ clipboard | – | – |
| (السياسات) إضافة سياسة خط ملاحي جديدة / تصدير Excel / TSV / نسخ ملخص | `_showAddPolicyDialog` … | `POST .../policies`، `GET .../policies` | Authenticated |

### الجداول
- **التاب 1، جلسات التتبع:** 3 KPIs (إجمالي الجلسات النشطة، شحنات بها غرامات سارية، إجمالي الغرامات المحسوبة بالجنيه)، وقايمة كروت (`_buildTrackingCard`، `:615`) فيها: البوليصة، وعدد الحاويات، وتاريخ التفريغ، وخروج البوابة، والإعادة، والحالة، والتكلفة التقديرية. الحالة الحالية فاضية: "لا توجد جلسات تتبع مطابقة للبحث".
- **التاب 2، تفاصيل الشرائح التصاعدية المطبقة:** الأعمدة: البند | الأيام المستهلكة | أيام السماح | أيام الغرامة | قيمة الغرامة. والصفوف: Demurrage، و Detention، و Port Storage. وفوقيهم 3 كروت (غرامة أرضيات USD، غرامة تأخير فارغ USD، أرضيات الميناء EGP) وإجمالي التكلفة الشاملة بالجنيه.
- **التاب 3، سياسات الخطوط:** قايمة سياسات (الخط، نوع الحاوية، سماح Demurrage و Detention والأرضيات، السعر اليومي، العملة) (`:1340`).

### التابات
1. **جلسات تتبع الحاويات الحية (Active Container Trackings)**: ![](../screenshots/40-demurrage-detention-tab-1-active-container-trackings.png)
2. **محاكي وحاسبة الشرائح التصاعدية (Tiered Simulator & Calculator)**: ![](../screenshots/40-demurrage-detention-tab-2-tiered-simulator-calculator.png). بالقيم الافتراضية (MSC، 40ft HC، تفريغ 2026-09-08) النتيجة 80 USD Demurrage + 2750 EGP أرضيات = **6750 جنيه** (بسعر صرف 50).
3. **سياسات تعريفة الخطوط الملاحية (Carrier Tariff Policies)**: **مفيش صورة صحيحة للتاب ده.** الملف `40-demurrage-detention-tab-3-carrier-tariff-policies.png` فيه في الحقيقة dialog "موصل بيانات الشحن البحري والغرامات الخارجي المجاني" (`FreightDataMonitorDialog`) مفتوح فوق تاب المحاكي، لأن الـ harness داس على أيقونة الهيدر بدل التاب (`elements/40-...-tab-3-...json` بيبيّن تابات الـ dialog: "نظرة عامة ومراقبة الحصة" …). محتوى التاب متوثّق من الكود (`_buildPoliciesTab`، `:1340`).

### الـ Dialogs
- **بدء تتبع شحنة وحاويات جديدة:** ![](../screenshots/40-demurrage-detention-dialog-add.png). أخطاء الـ validation: رسالة "حقل مطلوب" حمرا تحت رقم البوليصة ورقم الحاوية: ![](../screenshots/40-demurrage-detention-dialog-add-validation.png). أزرار الـ dialog: "إلغاء" و "حفظ وبدء التتبع"، والحفظ عليه spinner (`:1615`).
- **موصل بيانات الشحن البحري (FreightDataMonitorDialog):** ظاهر في `40-demurrage-detention-tab-3-carrier-tariff-policies.png`. فيه 3 تابات (نظرة عامة ومراقبة الحصة، محاكي الغرامات والأرضيات المزدوج، تعريفات أرضيات الموانئ المصرية) + "تحديث مؤشر النولون الآن" و "تحديث حالة الموصل" و "نسخ ملخص الحالة كاملاً". تاب النظرة العامة فيه 3 أقسام: "مؤشر شحن الحاويات الأسبوعي المجاني" (نشط ومتصل، الخطوط الملاحية المتابعة، تاريخ آخر تحديث)، و "موصل قواعد غرامات التوكيلات الملاحية" (الحصة الشهرية للطلبات 25، الطلبات المستخدمة، الطلبات المتبقية، الخطوط المسجلة) مع تنبيه حماية الحصة، و "سجل قرارات وتعريفات أرضيات هيئات الموانئ المصرية". كل قيمة جنبها أيقونة نسخ، وزرار X للقفل.
- **إضافة سياسة خط ملاحي** (`_showAddPolicyDialog`، `:1737`)، و **تحديث تواريخ الخروج والإعادة** (`:1625`)، و `DualClockRadarDialog`، و `FreeDaysAgreementDialog`، و `EmptyContainerReturnDialog`: مش متصوّرين.

### التصدير والطباعة
- طباعة كشف المتابعة (PDF)، وتصدير Excel، وتصدير جدول نصوص (TSV) للجلسات، وتصدير Excel و TSV للسياسات، ونسخ تفاصيل المحاكي. الأزرار كانت متعطلة في الصورة لأن مفيش بيانات (`40-demurrage-detention-main.png`).
- على الويب الحفظ بيتم بـ File System Access API أو `<a download>` (فرق خاص بالويب).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| Critical | "ترحيل للتسوية المالية" بيبعت `importFileId: item.importFileId ?? 1`. ولأن dialog بدء التتبع **مبيبعتش `import_file_id` أصلاً**، أي جلسة اتعملت من الشاشة دي هتترحّل غراماتها على **ملف الاستيراد رقم 1**، وده بيبوّظ Landed Cost لملف تاني | `demurrage_detention_screen.dart:1720`، payload `:1594`–`:1603` (مفيهوش import_file_id)، `modules/demurrage_detention/schemas.py:60` (الحقل Optional) | اطلب اختيار ملف الاستيراد في الـ dialog (أو خده من `initialImportFileId`)، وامنع الترحيل لو مفيش ملف |
| High | سعر الصرف ثابت `50.0` في إنشاء الجلسة، وافتراضي المحاكي 50. ده مخالف لقاعدة عدم الـ hard-code، والإجمالي بالجنيه هيبقى غلط | `:1602`، `:42`، `:920` | هات السعر من master العملات أو خليه إلزامي في الـ dialog |
| High | الخطوط الملاحية والموانئ وأنواع الحاويات **قوايم نصوص ثابتة** في الكود، وبتتبعت كنص حر (`carrier_name` و `port_name`) بدل FK. ده مخالف لقاعدة "ممنوع تخزين Master Data كنص حر"، مع إن فيه master للموانئ (شاشة 05) وللشركاء | `:48`، `:59`، `:68`، `:1594` | اربطها بـ `/ports-locations` و `/external-service-providers` وخزّن IDs |
| Medium | dialog بدء التتبع ودialog إضافة سياسة بيتقفلوا حتى لو الحفظ فشل (`Navigator.pop(ctx)` قبل ما يتشيك على النتيجة)، فالمستخدم بيخسر اللي كتبه | `:1606`، `:1842` | اقفل بس لو النتيجة نجحت |
| Medium | زرار "حفظ السياسة" ملوش loading state ولا منع للضغط المزدوج | `:1828`–`:1851` | ضيف `isSaving` زي dialog التتبع، أو `AppButton(isLoading:)` |
| Medium | رسالة العدّاد في المحاكي إنجليزي hard-coded: "Demurrage charges incurred: 2 days overdue." | `40-demurrage-detention-tab-2-tiered-simulator-calculator.png`، `:1101`، `:1103`، `:1105` | انقلها لـ l10n |
| Medium | الشاشة مش مستخدمة `VerticalStageScaffold` مع إنها شاشة مرحلة (Type A): AppBar عادي وتابات أفقية وعنوان مقطوع "…حاسبة ومتابعة فترات السماح وغرامات الحاويات والأ"، ومفيش أزرار تخطي/إيقاف المرحلة زي شاشات 38 و 39 | `:256`، `:258`، `:340`؛ `40-demurrage-detention-main.png` | انقلها لـ `VerticalStageScaffold` |
| Low | عناوين صفوف جدول الشرائح بتخلط المصطلحات: "Demurrage (أرضيات الميناء)" و "Port Storage (تخزين ساحات الميناء)"، فالاتنين بيتقروا "أرضيات"، مع إن Demurrage غرامة خط ملاحي | `40-demurrage-detention-tab-2-tiered-simulator-calculator.png` | Demurrage = "غرامة تأخير الحاوية بالميناء (الخط الملاحي)" |
| Low | زرار "توثيق فترات السماح (BK-02)" و "إرجاع الحاويات (TR-05)" نصوص عربي hard-coded، وألوان `Color(0xFF8E44AD)`، و `ElevatedButton` بدل `AppButton` | `:299`–`:313`، `:534`، `:280` | l10n + `AppButton` + `AppTheme` |
| Low (ويب) | `Refused to set unsafe header "Accept-Encoding"` ×4: سلوك خاص بالمتصفح، مش bug على الديسك توب | `runtime-errors.json` ← `40-demurrage-detention` | متبعتش الهيدر لما يكون `kIsWeb` |
