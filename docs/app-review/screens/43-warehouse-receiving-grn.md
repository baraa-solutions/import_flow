# استلام المخازن وأذون الإضافة (Warehouse Receiving & GRN)
![](../screenshots/43-warehouse-receiving-grn-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب. الشاشة دي **تاب مدمج** جوه مركز الاستلام (41)، وهي التاب الافتراضي لما تفتحه من الـ sidebar. قاعدة البيانات الـ scratch **مفيهاش أذون إضافة**، فالقايمة فاضية ("لا توجد سجلات استلام بمخازن الشركة حالياً"). التابين الداخليين بتوع الشاشة المستقلة ("سجل أذون الإضافة المخزنية" و "إنشاء إذن استلام وفحص مخزني") **متصوّروش**، لأنهم مش موجودين في الوضع المدمج (`capture-manifest.json`: "tab label not found").

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** تسجيل وصول الشاحنة للمخزن (السائق، واللوحة، ورقم السيل وسلامته)، وإصدار إذن الإضافة **GRN**، ومطابقة كميات كل صنف (بالفاتورة، والمقبول، والعجز، والتالف، والعينات)، وإثبات الفروقات، وحجر البضاعة (Quarantine)، ومحضر الفحص الفني TR-04. الاستلام النهائي بيقفل رصيد GIT وبينقل الملف لمرحلة الاستلام.
- **المستخدمين:** أمين المخزن، ولجنة الفحص والاستلام، ومراقب الجودة.
- **المرحلة:** `PHASE-6: STEP_19`. **BP-033** و **BP-034** و **BP-035** (`docs/phase_08_warehouse_receiving.md`). الباك إند بيسميها "Phase 8 - Warehouse Receiving" (`modules/warehouse_receiving/router.py:30`).

## طريقة الوصول والصلاحية
- **الوصول:** sidebar ← "مركز الاستلام والمخازن والبضاعة بالطريق" (index 28، `home/home_screen.dart:138` بـ `initialSubTab: 1`). وكمان بتتفتح كشاشة مستقلة (`WarehouseReceivingScreen()`) من `ImportFileDetailsDialog` ("استلام المخزن (TR-03)"، `import_files/widgets/import_file_details_dialog.dart:958`)، وساعتها بتبقى بـ `VerticalStageScaffold` (`warehouse_receiving_screen.dart:891`).
- **الصلاحية:** أي مستخدم عامل login (`Depends(get_current_user)` على الـ router كله، `router.py:30`). مفيش RBAC code، يعني أي حد يقدر يعتمد استلام نهائي أو يحذف إذن.

## مكونات الشاشة

### الحقول
**شريط الأدوات:** بحث برقم الإذن / الشاحنة / السائق (`TextField`، وبيعمل fetch للـ API مع كل حرف، `:542`)، و فلتر الحالة (`SearchableDropdownField<String>`: جميع الحالات / مسودة بانتظار العد / تم الاستلام / فروقات مسجلة، `:549`).

**Dialog "تسجيل محضر استلام شحنة جديدة بالمخزن"** (`_WarehouseReceivingFormDialog`):

- فوق الحقول **بانر "تنبيه إداري عاجل"** (خلفية amber، `:1212`–`1256`): بيقول إن لازم أوراق الشحنة المعتمدة (قائمة التعبئة والفاتورة) توصل لمسؤول المخزن قبل وصول الشاحنة، وجنبه زرار "إرسال إشعار للمخزن وتوليد مهمة".
- تحت الحقول عنوان "بيانات جرد واختبار كميات الأصناف تفصيلياً بكل أمر شراء:" وزرار "إضافة صنف". كل بند بيبدأ بسطر فيه badge "أمر الشراء: <رقم>" و "<كود الصنف> - <اسم الصنف>" (`:1415`–`1416`).

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة الاستيرادية * | `SearchableDropdownField<int?>` | أيوه | `v == null` ← "يرجى اختيار ملف الشحنة" (`:1277`) | `importFilesProvider` (`GET /import-files`). الـ label: الاسم والكود + PO |
| اسم المخزن والفرع * | `TextFormField` | أيوه | مش فاضي (`:1294`) | **نص حر**، والافتراضي "Main Warehouse - Cairo" (`:1001`) |
| رقم الشاحنة واللوحة | `TextFormField` | لا | – | إدخال يدوي |
| اسم السائق | `TextFormField` | لا | – | إدخال يدوي |
| رقم السيل والرصاص الأمني | `TextFormField` | لا (الباك إند بيطلبه لو السيل مكسور) | مفيش تحقق في الواجهة | إدخال يدوي |
| سلامة السيل | `SwitchListTile` | – | – | افتراضي: سليم |
| بنود الأصناف (لكل بند): اسم وبيان الصنف، العدد بالفاتورة، المستلم الفعلي، العجز، التالف، عينات مسحوبة | `TextFormField` رقمية | لا | **مفيش أي validator** | بتتملى تلقائياً من أوامر الشراء المرتبطة بالملف (`:1063`–`1095`)، والافتراضي **بيانات وهمية** (`:1025`–`1046`) |

**Dialog إثبات فروقات (`_DiscrepancyReportDialog`):** نوع الفروقات (`SearchableDropdownField`: عجز وتلف / عجز فقط / تلف فقط / كسر السيل)، وملاحظات إلزامية (`:1588`)، وحجر البضاعة، وفتح مطالبة ومرجعها.

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| استيراد Excel / تصدير PDF / تصدير Excel / إعادة تحميل حية (`MasterDataToolbarWidget`) | استيراد وتصدير عام للموديول | `POST /warehouse-receiving/import-excel`، `GET /warehouse-receiving/export-excel`، `GET .../export-pdf` (**مش موجودين في الباك إند**، شوف الملاحظات) | Authenticated |
| تسجيل وصول شاحنة واستلام محضر جديد | بيفتح dialog الإضافة | – | – |
| بحث واستنساخ إذن إضافة سابق | `SearchAndCloneWarehouseReceivingDialog` ثم `CloneEntityReviewDialog` | – | – |
| تصدير جدول أذون الاستلام كجدول بيانات | TSV للـ clipboard (`:565`) | – | – |
| أيقونة Excel / أيقونة PDF | `TableExportService.exportTableToExcel/Pdf` (`:294`، `:340`) | – | – |
| (Dialog) إرسال إشعار للمخزن وتوليد مهمة | **مبيبعتش حاجة**: بيعمل `setState` ويطلّع SnackBar "نجاح" بس (`:1247`–`1255`) | – | – |
| (Dialog) إضافة صنف | بيضيف بند فاضي بقيم افتراضية ("PO-NEW" و "ITM-NEW" و "New Item") | – | – |
| (Dialog) إلغاء | قفل الـ dialog من غير حفظ (متعطل أثناء التحميل، `:1493`) | – | – |
| (Dialog) حفظ مؤقت (مسودة بانتظار العد) | status = Draft | `POST /warehouse-receiving` أو `PUT /{id}` | Authenticated |
| (Dialog) تأكيد الاستلام النهائي للمخزن | status = Goods Received + تحديث GIT محلياً | `POST` أو `PUT /warehouse-receiving` | Authenticated |
| (كارت) عرض / تعديل | نفس dialog الإضافة | `PUT /warehouse-receiving/{id}` | Authenticated |
| (كارت) طباعة | **بينسخ نص للـ clipboard** بدل الطباعة (`:676`–`694`) | – | – |
| (كارت) حذف | Soft delete بعد تأكيد | `DELETE /warehouse-receiving/{id}` | Authenticated |
| (كارت) تأكيد الاستلام النهائي | confirm ثم update | `PUT /warehouse-receiving/{id}` | Authenticated |
| (كارت) إثبات عجز أو تلف | `_DiscrepancyReportDialog` | `POST /{id}/report-discrepancy` | Authenticated |
| (كارت) محضر الفحص (TR-04) | `WarehouseInspectionDialog` | `POST /{id}/inspection-protocol` | Authenticated |
| (كارت) فحص / حظر الحجر | **SnackBar بس** حسب الـ flag المحلي (`:832`–`847`) | – (الـ endpoint `POST /{id}/validate-dispatch` موجود ومش مستخدم) | – |
| (كارت) نسخ الصف / استنساخ | TSV / clone draft | – | – |

### الجداول
- **قايمة كروت** (`SliverList`، `:626`)، والكارت فيه: كود GRN، والمخزن، وbadge السيل، وbadge الحالة، وbadge الحجر، وسطر الشاحنة والسائق، وتاريخ الوصول، والفاحص، وحالة الفروقات، وشبكة كميات (بالفاتورة / المقبول / العجز / التالف). الفلترة بالبحث والحالة بتحصل في الباك إند (`search`، `status`). مفيش ترتيب ولا pagination.

### التابات
- في الوضع المدمج **مفيش تابات**. الشاشة المستقلة ليها تابين: "سجل أذون الإضافة المخزنية" (القايمة)، و "إنشاء إذن استلام وفحص مخزني"، والتاني ده **مش تاب**: بيفتح dialog الإضافة بس (`:899`–`903`). ومفيش صور ليهم لأنهم مش موجودين في الوضع المدمج اللي اتصوّر.

### الـ Dialogs
- **تسجيل محضر استلام شحنة جديدة:** ![](../screenshots/43-warehouse-receiving-grn-dialog-add.png). الـ dialog **بيفتح وفيه صنفين وهميين** (ITM-SR-101 Enterprise Servers 250/247، و ITM-SR-102 Smart Network Switches 500/498، وأمر شراء PO-2026-IT-001).
- **أخطاء الـ validation:** ![](../screenshots/43-warehouse-receiving-grn-dialog-add-validation.png). بيظهر خطأ واحد بس "يرجى اختيار ملف الشحنة"، وده لأن اسم المخزن متملي افتراضياً، وحقول الكميات مالهاش validators.
- **إثبات الفروقات** و **محضر الفحص TR-04** و **الاستنساخ**: مش متصوّرين (مفيش سجلات).

### التصدير والطباعة
- Excel و PDF للقايمة عن طريق `TableExportService` (الـ stage name "Warehouse Receiving"، والاسم "GRN_Registry")، و TSV للـ clipboard، وتصدير الـ toolbar العام (متعطل، شوف الملاحظات). "طباعة" الكارت بتنسخ نص بس. الحفظ على الويب بيبقى File System Access API / `<a download>`، وده فرق خاص بالويب.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| Critical | الـ dialog بيفتح **وفيه أصناف وكميات وهمية** (أمر شراء PO-2026-IT-001، 250/247 سيرفر…). ولو الملف المختار مالوش PO مربوط، بيتحط بند مخترع "ITM-GEN-01" بكمية 100. يعني ممكن يتعمل GRN بكميات محدش عدّها | `warehouse_receiving_screen.dart:1025`–`1046`، `:1084`–`1094`؛ `43-warehouse-receiving-grn-dialog-add.png` | ابدأ من غير بنود، واطلب إدخال العدد الفعلي. وممنوع بند افتراضي |
| High | لو في فروقات جمركية مسجلة للملف، الواجهة **بتحط عجز = 2 وتالف = 1 من عندها**، وعينات = 1 دايماً، والمقبول = كمية الـ PO، من غير أي عدّ فعلي | `warehouse_receiving_screen.dart:1076`–`1080` | الكميات الفعلية لازم تتدخل يدوي، والواجهة متخمّنش |
| High | مفيش أي تحقق على الكميات: مفيش تحقق إنها أرقام، ولا إن المقبول + العجز + التالف = الكمية بالفاتورة، وأي قيمة مش رقم بتتحول لـ 0 (`int.tryParse ?? 0`) | `warehouse_receiving_screen.dart:1130`–`1133`، `:1440`–`1476` | ضيف validators رقمية ومعادلة توازن الكميات، وكمان في `modules/warehouse_receiving/validators.py` |
| High | حقل "عينات مسحوبة" بيظهر في الفورم **بس مبيتبعتش للباك إند** (مش موجود في `grnItemsPayload`)، فأي قيمة بيدخلها المستخدم بتضيع | `warehouse_receiving_screen.dart:1126`–`1135`، `:1473` | ضيفه للـ payload وللـ schema |
| High | زرار "إرسال إشعار للمخزن وتوليد مهمة" **شكلي بس**: بيقلب لونه ويطلّع SnackBar نجاح، ومفيش إشعار ولا مهمة بتتعمل | `warehouse_receiving_screen.dart:1247`–`1255` | اربطه بـ smart-tasks / notifications، أو شيله |
| High | زرار "فحص / حظر الحجر" بيطلّع SnackBar من flag محلي بس، ومبينادي `POST /{id}/validate-dispatch` الموجود في الباك إند | `warehouse_receiving_screen.dart:832`–`847`؛ `modules/warehouse_receiving/router.py:95` | نادِ الـ endpoint واعرض نتيجته |
| High | أزرار `MasterDataToolbarWidget` (استيراد Excel / تصدير Excel / PDF) بتنادي `/warehouse-receiving/import-excel` و `/export-excel` و `/export-pdf`، **والـ routes دي مش معرّفة**. الـ GET هيقع على `/{record_id}` ويرجع 422 | `core/widgets/master_data_toolbar.dart:57`، `:122`؛ `modules/warehouse_receiving/router.py` (مفيهوش export/import) | اعمل الـ endpoints أو شيل الـ toolbar من الشاشة |
| Medium | اسم المخزن **نص حر** وافتراضيه "Main Warehouse - Cairo"، بدل FK على master للمخازن. ده مخالف لقاعدة "ممنوع تخزين Master Data كنص حر" | `warehouse_receiving_screen.dart:1001`، `:1283` | master مخازن + `SearchableDropdownField` |
| Medium | في التعديل، رقم أمر الشراء بيتبدّل بـ `PO-MAIN-<importFileId>` المخترع بدل الـ PO الحقيقي | `warehouse_receiving_screen.dart:1010` | خزّن `po_number` في `grn_items` ورجّعه |
| Medium | الحذف مفيهوش try/catch ولا SnackBar نجاح أو فشل، ولا `ref.invalidate` للـ providers المرتبطة (importFiles و GIT) | `warehouse_receiving_screen.dart:707`–`709`؛ `providers/warehouse_receiving_provider.dart:135`–`142` | اعرض خطأ الباك إند، واعمل invalidate |
| Medium | زرار "حفظ مؤقت" مالوش loading indicator (بس بيتعطل)، و "تأكيد الاستلام" هو اللي عليه spinner. ومفيش تحقق في الواجهة إن رقم السيل مطلوب لو السيل مكسور، مع إن الباك إند بيرفض | `warehouse_receiving_screen.dart:1494`–`1504`؛ `modules/warehouse_receiving/validators.py:3`–`9` | spinner للزرارين، و validator شرطي للسيل |
| Medium | البحث بيعمل request للـ API مع كل حرف من غير debounce | `warehouse_receiving_screen.dart:542`–`544` | debounce حوالي 300ms |
| Medium | مخالفة لـ UI standards: `ElevatedButton` في كل الأزرار الأساسية بدل `AppButton`، و `Colors.blue/amber/orange` مباشر | `:485`، `:790`–`826`، `:1212`–`1218`، `:1415` | `AppButton` + `AppTheme` |
| Medium | نصوص مكتوبة في الكود: "محضر الفحص (TR-04)"، وهيدرز Excel/PDF بالعربي، والعنوان الإنجليزي للـ PDF | `warehouse_receiving_screen.dart:813`، `:296`–`309`، `:377`–`378` | l10n |
| Medium | الباك إند بيسجّل الـ audit log بـ `performed_by="Warehouse Manager"` ثابت، مش المستخدم الحالي | `modules/warehouse_receiving/service.py:55`، `:229` | استخدم `current_user` |
| Low | (مشكلة الـ locale المعروفة) عناوين الهيدر والتابات الرأسية إنجليزي | `43-warehouse-receiving-grn-main.png` | `supportedLocales` |
| Low | Console: `Refused to set unsafe header "Accept-Encoding"`، وده **فرق خاص بالويب** | `runtime-errors.json` → `43-warehouse-receiving-grn` | – |
