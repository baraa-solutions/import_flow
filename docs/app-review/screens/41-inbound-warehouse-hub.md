# مركز الاستلام والمخازن والبضاعة بالطريق (Inbound & Warehouse Hub)
![](../screenshots/41-inbound-warehouse-hub-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب. قاعدة البيانات الـ scratch **مفيهاش أذون استلام ولا بضاعة في الطريق**، فكل التابات ظاهرة فاضية.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** شاشة "Hub" بتجمع 3 شاشات المرحلة 6 (الاستلام المخزني) في مكان واحد بتابات رأسية: رصيد البضاعة في الطريق (GIT)، واستلام المخازن وأذون الإضافة (GRN)، وتقرير مطابقة الشحنات المستلمة. الـ Hub نفسه مفيهوش محتوى غير الهيدر والتابات. كل تاب هو شاشة مستقلة ومتوثّقة لوحدها (42 و 43 و 44).
- **المستخدمين:** أمين المخزن، ومسؤول النقل الداخلي، ومراجع الجودة، ومدير العمليات.
- **المرحلة:** بادج `PHASE-6: STEP_19` (`inbound_warehouse_hub_screen.dart:94`). بتخدم **BP-033** (النقل الداخلي ووصول الشاحنات)، و **BP-034** (إذن الإضافة GRN ومطابقة البنود)، و **BP-035** (فحص الجودة والحجر والمطالبات) من `docs/phase_08_warehouse_receiving.md`.

## طريقة الوصول والصلاحية
- **Sidebar:** "المرحلة 6: الاستلام المخزني والتسوية المالية" ← "مركز الاستلام والمخازن والبضاعة بالطريق" (index 28). الـ index ده بيفتح الـ Hub على **التاب التاني (GRN)** (`home/home_screen.dart:138`، `initialSubTab: 1`)، وده اللي ظاهر في الصورة الرئيسية. في كمان index 63 بيفتح على تاب GIT (`home_screen.dart:211`) و index 64 بيفتح على التقرير (`home_screen.dart:214`).
- **Scaffold:** `VerticalStageScaffold` (Type A) بلون `AppTheme.cobalt` (`inbound_warehouse_hub_screen.dart:93`–`117`). التابات بـ `IndexedStack` وبتتبني lazy أول ما تتزار (`:120`–`144`).
- **الصلاحية:** أي مستخدم عامل login. الـ routers `warehouse-receiving` و `inland-transport` عليها `Depends(get_current_user)` بس (`modules/warehouse_receiving/router.py:30`)، ومفيش RBAC code.

## مكونات الشاشة

### الحقول
الـ Hub نفسه مفيهوش حقول إدخال. الحقول موجودة جوه التابات (شوف 42 و 43 و 44).

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة (الهيدر) | بيفتح `SkipStepDialogHelper` لتخطي STEP_19 للشحنة (`core/widgets/shipment_stage_lifecycle_control.dart:348`) | endpoint التخطي بتاع ملفات الاستيراد | Authenticated |
| إيقاف الشحنة عند هذه المرحلة | بيفتح `HoldShipmentAtStageDialog` (`shipment_stage_lifecycle_control.dart:374`) | `POST /api/v1/import-files/{id}/hold` | Authenticated |
| أيقونة تحديث (الهيدر) | `_refreshData()`: بتعيد تحميل أذون الاستلام وملفات الاستيراد، و **بتصفّر دفتر GIT** (`initLedger`) | `GET /api/v1/warehouse-receiving`، `GET /api/v1/import-files` | Authenticated |
| العودة للداش بورد | رجوع للوحة التحكم | – | – |
| التابات الرأسية (3) | تبديل بين GIT و GRN والتقرير | – | – |

### الجداول
مفيش جداول على مستوى الـ Hub. الجداول في التابات.

**عناصر الهيدر الظاهرة في الصورة:** أيقونة المخزن، والعنوان "Inbound Logistics & Warehouse Hub"، وبادج المرحلة "Warehouse GRN" (مشتق من `STEP_19`)، وفوق التابات الرأسية عنوان "Operations & Stages". كل اللي تحت الهيدر في الصورة الرئيسية (شريط "عمليات البيانات والتصدير/الاستيراد"، وأزرار التسجيل والاستنساخ، والبحث، وفلتر "جميع الحالات"، والرسالة "لا توجد سجلات استلام بمخازن الشركة حالياً") هو محتوى تاب GRN، ومشروح في `43-warehouse-receiving-grn.md`.

### التابات
1. **رصيد ومطابقة البضاعة في الطريق (Goods In Transit (GIT) Ledger):** ![](../screenshots/41-inbound-warehouse-hub-tab-1-goods-in-transit-git-ledger.png). شرحه في `42-goods-in-transit.md`.
2. **استلام المخازن وأذون الإضافة (Warehouse Receiving & GRN):** ![](../screenshots/41-inbound-warehouse-hub-tab-2-warehouse-receiving-grn.png). ده التاب الافتراضي من الـ sidebar. شرحه في `43-warehouse-receiving-grn.md`.
3. **تقرير ومطابقة الشحنات المستلمة (Received Shipments Audit Report):** ![](../screenshots/41-inbound-warehouse-hub-tab-3-received-shipments-audit-report.png). شرحه في `44-warehouse-received-report.md`.

### الـ Dialogs
- **تسجيل محضر استلام شحنة جديدة بالمخزن** (من تاب GRN، زرار "تسجيل وصول شاحنة واستلام محضر جديد"): ![](../screenshots/41-inbound-warehouse-hub-dialog-add.png)
- **أخطاء الـ validation** بعد "حفظ مؤقت" والفورم فاضي: رسالة حمرا "يرجى اختيار ملف الشحنة" تحت "ملف الشحنة الاستيرادية *" بس: ![](../screenshots/41-inbound-warehouse-hub-dialog-add-validation.png)
- شرح الحقول كامل في `43-warehouse-receiving-grn.md`.

### التصدير والطباعة
مفيش تصدير على مستوى الـ Hub. كل تاب ليه أزرار تصدير خاصة بيه (Excel و PDF و TSV).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| High | زرار التحديث في الهيدر بينادي `goodsInTransitProvider.notifier.initLedger()`، والدالة دي **بتمسح دفتر GIT وبترجّعه فاضي** (`state = AsyncValue.data([])`). يعني أي بيانات اتضافت من مطابقة الـ Packing List هتضيع مع أول refresh، أو حتى مع فتح الـ Hub نفسه (`initState` بينادي `_refreshData`) | `inbound_warehouse_hub_screen.dart:46`، `:64`؛ `providers/goods_in_transit_provider.dart:17`–`20` | اعمل GIT ledger من الباك إند، وخلّي التحديث يعمل fetch بدل ما يصفّر |
| Medium | الـ sidebar item اسمه "مركز الاستلام … والبضاعة بالطريق"، بس بيفتح على تاب GRN مش على أول تاب (GIT). ده بيلخبط المستخدم، ومش ماشي مع ترتيب التابات | `home/home_screen.dart:138` (`initialSubTab: 1`)، `41-inbound-warehouse-hub-main.png` | افتح على التاب الأول، أو رتّب التابات بحيث الافتراضي يبقى الأول |
| Low | بادج الهيدر بيفضل "Warehouse GRN" ثابت مهما كان التاب (باين في GIT والتقرير كمان). البادج جاي من `stageCode: 'PHASE-6: STEP_19'` الثابت عن طريق `DisplayNameResolver.resolveStageBadge`، فهو بيوصف المرحلة مش التاب، وده ممكن يلخبط المستخدم وهو في تاب GIT | `41-inbound-warehouse-hub-tab-1-goods-in-transit-git-ledger.png`، `41-inbound-warehouse-hub-tab-3-received-shipments-audit-report.png`؛ `core/widgets/vertical_stage_scaffold.dart:77`؛ `core/services/display_name_resolver.dart:35` | خلّي البادج يتغير مع التاب المختار، أو سمّيه باسم المرحلة كلها |
| Low | (مشكلة الـ locale المعروفة) عنوان الهيدر "Inbound Logistics & Warehouse Hub"، والبادج "Warehouse GRN"، وعناوين التابات الرأسية، و "Operations & Stages" ظاهرين إنجليزي مع إن الواجهة عربي. `VerticalStageScaffold` بيختار `titleAr`/`titleEn` حسب `Directionality.of(context) == rtl`، والـ Directionality بتيجي LTR لأن الـ locale بيتحل لـ `en_US` (الـ layout نفسه LTR: الـ sidebar على الشمال) | `41-inbound-warehouse-hub-main.png`؛ `core/widgets/vertical_stage_scaffold.dart:76`، `:99`، `:342` | ضيف `supportedLocales` في `main.dart` (مشكلة عامة في التطبيق) |
| Low | Console على الويب: `Refused to set unsafe header "Accept-Encoding"` (6 مرات). ده **فرق خاص بالويب**: المتصفح بيمنع الـ header ده، ومالوش تأثير على الديسكتوب | `runtime-errors.json` → `41-inbound-warehouse-hub` | متبعتش الـ header ده لما `kIsWeb` |
| Low | زرار التحديث `IconButton` بلون `Colors.white70` مباشر، مش من `AppTheme` | `inbound_warehouse_hub_screen.dart:109` | استخدم لون من `AppTheme` |
