# تقرير ومطابقة الشحنات المستلمة (Received Shipments Audit Report)
![](../screenshots/44-warehouse-received-report-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب. الشاشة دي **تاب مدمج** (التالت) جوه مركز الاستلام (41). قاعدة البيانات الـ scratch مفيهاش أذون إضافة، فالتقرير فاضي ("لا توجد شحنات مستلمة مطابقة لمعايير البحث حالياً"). تاب الشاشة المستقلة "تقرير الشحنات المستلمة بالمخزن تفصيلي" **متصوّرش** لأنه مش موجود في الوضع المدمج (`capture-manifest.json`: "tab label not found").

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** تقرير تدقيق للقراءة بس، بيطابق الكمية بالفاتورة مع المستلم فعلياً لكل صنف في كل أمر شراء، وبيبيّن العجز والتالف والعينات وصافي الفروق. المصدر هو أذون الإضافة (GRN) نفسها.
- **المستخدمين:** المراجع الداخلي، والمالية (قبل التسوية)، ومدير المخازن.
- **المرحلة:** `PHASE-6: STEP_19`. **BP-035** (فحص الجودة والمطالبات)، وبيدعم **BP-034** (`docs/phase_08_warehouse_receiving.md`).

## طريقة الوصول والصلاحية
- **الوصول:** مركز الاستلام ← التاب التالت "Received Shipments Audit Report"، أو index 64 (`home/home_screen.dart:214`، `initialSubTab: 2`). كشاشة مستقلة بتبقى بـ `VerticalStageScaffold`، بس في التطبيق الحالي بتتفتح مدمجة بس.
- **الصلاحية:** بتقرا `GET /api/v1/warehouse-receiving` (authenticated بس، `modules/warehouse_receiving/router.py:30`). مفيش RBAC.

## مكونات الشاشة

### الحقول

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث برقم الشحنة، أمر الشراء، كود أو اسم الصنف | `TextField` + نسخ ومسح | لا | – | فلترة محلية على البنود (`warehouse_received_report_screen.dart:67`–`75`)، بتشمل كمان اسم المخزن |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تصدير جدول مفصول بمسافات | TSV بـ `FileSaveHelper.saveText` (`:106`) | – | – |
| تصدير إكسيل | CSV بـ `FileSaveHelper.saveText` (`:118`) | – | – |
| طباعة تقرير بي دي إف | `printOrSaveReportPdf` (`:130`) | – | – |
| نسخ الملف الشامل | ملخص التقرير للـ clipboard (`:142`) | – | – |
| (صف) نسخ | ملخص الصف (`:718`) | – | – |
| تحديث (في الوضع المستقل) | `fetchRecords()` (`:757`) | `GET /warehouse-receiving` | Authenticated |

### الجداول
- **بانر التقرير** (أعلى الشاشة): عنوان "تقرير الشحنات المستلمة بالمخازن ومطابقة الفروق"، ووصف إنه حصر شامل لكل الشحنات اللي اتأكد استلامها مفصّلة بأوامر الشراء، مع مطابقة الكميات بالفاتورة بالمستلم فعلياً والفاقد والتالف والعينات. أزرار التصدير الأربعة جوه البانر ده.
- **KPIs (6 كروت):** إجمالي العدد بالفاتورة، والمستلم الفعلي بالمخزن، وإجمالي التالف، وإجمالي العجز، والعينات المسحوبة، وصافي الفروق (بالأحمر لو ≠ 0) (`:237`–`292`). كلهم "0 وحدة" في الصورة.
- **جدول "الشحنات المستلمة تفصيلي لكل أمر شراء"** (`DataTable`، `:375`): ملف الاستيراد | رقم أمر الشراء | الحاوية والشاحنة | الصنف والبيان | الكمية بالفاتورة | العجز | التالف | العينات | المستلم | الفرق (المستلم − الفاتورة) | حالة الاستلام | إجراءات. مفيش ترتيب ولا pagination.

### التابات
الشاشة المستقلة ليها تاب واحد (`l.whReportTabTitle`، `:51`)، ومفيش صورة ليه (السبب فوق).

### الـ Dialogs
مفيش dialogs. الشاشة للقراءة بس ("no add/create button found" في `capture-manifest.json`).

### التصدير والطباعة
TSV، و CSV باسم "إكسيل"، و PDF، ونسخ شامل. الحفظ بـ Save dialog (`FileSaveHelper.saveText`). على الويب بيبقى File System Access API / `<a download>`، وده فرق خاص بالويب.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| High | عمود "حالة الاستلام" **دايماً** "معتمد ومستلم" باللون الأخضر، حتى لو الإذن لسه مسودة أو عليه فروقات. والتقرير بيجمع **كل** الأذون، مش المستلمة بس، فالمسودات بتدخل في الإجماليات | `warehouse_received_report_screen.dart:693`–`712`؛ `services/warehouse_received_report_export_service.dart:50`–`71` (مفيش فلتر على `status`) | اعرض `r.status` الحقيقي، وفلتر على "Goods Received" أو ضيف فلتر حالة |
| High | بيانات مخترعة في التقرير: كود الملف `IMP-<id>`، ورقم أمر الشراء `PO-MAIN-<id>`، والحاوية ثابتة **"1 × 40ft HQ"**، والعينات دايماً 0. يعني تقرير التدقيق مش بيعكس الـ PO ولا الحاويات الحقيقية | `services/warehouse_received_report_export_service.dart:56`–`58`، `:64` | هات كود الملف والـ PO والحاويات والعينات من الباك إند (ضيفها لـ `WarehouseReceivingResponse`) |
| Medium | الفرق بيتحسب `accepted − invoiced` بس، فالعينات المسحوبة (مشروعة) بتظهر كعجز | `services/warehouse_received_report_export_service.dart:66` | الفرق = المقبول + العينات − الفاتورة، أو اعرض الاتنين |
| Medium | مخالفة لـ UI standards: `ElevatedButton`/`OutlinedButton` بألوان `Colors.indigo`/`Colors.blue`/`Colors.purple`/`Colors.green`/`Colors.red` مباشر | `warehouse_received_report_screen.dart:62`، `:99`–`142`، `:244`، `:280`، `:700`–`709` | `AppButton` + `AppTheme` |
| Medium | "تصدير إكسيل" بيطلّع CSV، واسم الملف مش على النمط القياسي `[Stage Name] - [Import File Code].ext` | `services/warehouse_received_report_export_service.dart:206`–`235` | `FileSaveHelper.exportAndSaveFile` + xlsx |
| Low | الـ label بتاع KPI "المستلم الفعلي بال…" مقطوع (ellipsis) في عرض 1600px | `44-warehouse-received-report-main.png` | قلّل النص أو خلّي الكارت يلف لسطرين |
| Low | أزرار التصدير شغالة والتقرير فاضي | `44-warehouse-received-report-main.png` | عطّلها لما مفيش بيانات |
| Low | (مشكلة الـ locale المعروفة) الهيدر والتابات الرأسية إنجليزي | `44-warehouse-received-report-main.png` | `supportedLocales` |
| Low | Console: `Refused to set unsafe header "Accept-Encoding"`، وده **فرق خاص بالويب** | `runtime-errors.json` → `44-warehouse-received-report` | – |
