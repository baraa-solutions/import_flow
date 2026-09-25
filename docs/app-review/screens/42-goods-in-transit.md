# رصيد ومطابقة البضاعة في الطريق (Goods In Transit (GIT) Ledger)
![](../screenshots/42-goods-in-transit-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب. الشاشة دي **تاب مدمج** جوه مركز الاستلام (شاشة 41)، والجدول فاضي ("لا توجد بضائع في الطريق مطابقة لمعايير البحث حالياً"). السبب إن الدفتر مالوش مصدر بيانات في الباك إند أصلاً (شوف الملاحظات).

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** دفتر بالبضاعة المشحونة اللي لسه مستلمتش في المخزن، على مستوى كل صنف في كل أمر شراء: الكمية بالفاتورة، وعدد الطرود، وعدد الحاويات، وتاريخ الاعتماد، والحالة (في الطريق / مستلمة بالمخزن). المفروض الرصيد ده بيقل تلقائياً أول ما الاستلام النهائي يتأكد.
- **المستخدمين:** مسؤول المخزن والتخطيط، والمالية (قيمة المخزون في الطريق)، ومسؤول النقل الداخلي.
- **المرحلة:** `PHASE-6: STEP_19`. بتخدم **BP-033** (تنسيق النقل الداخلي، من زرار TR-01) وبتمهّد لـ **BP-034** (`docs/phase_08_warehouse_receiving.md`).

## طريقة الوصول والصلاحية
- **الوصول:** مركز الاستلام (sidebar index 28) ← أول تاب "Goods In Transit (GIT) Ledger"، أو index 63 اللي بيفتح الـ Hub على التاب ده (`home/home_screen.dart:211`). لما الشاشة بتتفتح لوحدها بيبقى ليها `VerticalStageScaffold` بلون emerald (`goods_in_transit_screen.dart:579`)، بس في التطبيق الحالي بتتفتح مدمجة بس (`isEmbedded: true`).
- **الصلاحية:** الدفتر نفسه **مبينادي أي endpoint**. زرار TR-01 بيستخدم `/api/v1/inland-transport/...`، وده authenticated بس ومفيهوش RBAC.

## مكونات الشاشة

### الحقول

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث برقم الشحنة، أمر الشراء، كود أو اسم الصنف | `TextField` + زرار نسخ ومسح | لا | – | فلترة محلية على الـ state (`:258`–`290`) |
| فلتر الحالة: الكل / البضاعة في الطريق فقط (الرصيد الفعلي) / المستلمة فقط | `DropdownButton<String>` | لا | – | قايمة ثابتة، والافتراضي "In-Transit Only" (`:25`، `:293`) |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| نسخ ملف البيانات | بينسخ ملخص الدفتر للـ clipboard | – | – |
| طباعة تقرير | `printOrSaveGitPdf` (PDF) | – | – |
| تصدير مجدول | TSV: بينسخه للـ clipboard وبيحفظه بـ `FileSaveHelper.saveText` | – | – |
| تصدير إكسيل | CSV (مش xlsx) بيتنسخ وبيتحفظ بـ `FileSaveHelper.saveText` | – | – |
| حجز وتنسيق النقل (TR-01) | بيفتح `InlandTransportDialog` على **أول ملف مش "Arrived Warehouse"** في القايمة، أو أول ملف خالص (`:131`–`147`) | `/api/v1/inland-transport/bookings` | Authenticated |
| أيقونة التحديث (جنب الفلتر) | `initLedger()`: **بتصفّر الدفتر** (`:309`) | – | – |
| (صف) نسخ ملخص الصف، والضغط على كود الملف أو الـ PO أو الصنف | نسخ للـ clipboard | – | – |

### الجداول
- **بانر المعلومات** (أعلى الشاشة، خلفية teal، `:82`–`160`): عنوان "تقرير رصيد البضاعة في الطريق تفصيلي لكل أمر شراء"، ووصف إن الرصيد محسوب من الفواتير وقوائم التعبئة المعتمدة وبيتخصم تلقائياً بعد تأكيد الاستلام النهائي بالمخزن. أزرار التصدير و TR-01 جوه البانر ده.
- **KPIs (5 كروت):** الشحنات في الطريق (عدد الملفات)، وأوامر الشراء، وإجمالي العدد بالفاتورة، وإجمالي الكراتين والطرود، وعدد الحاويات النشطة. كلهم محسوبين على البنود اللي لسه مستلمتش بس (`:69`–`74`). وكلهم 0 في الصورة.
- **جدول "رصيد البضاعة في الطريق تفصيلي لكل أمر شراء"** (`DataTable`، `:349`): إجراءات | كود الملف (اسم الشحنة + badge بالكود) | رقم أمر الشراء | كود الصنف | اسم الصنف | الكمية بالفاتورة | عدد الطرود ونوعها | الحاويات (العدد × النوع) | تاريخ الاعتماد | حالة الدفتر (في الطريق / مستلمة). مفيش ترتيب ولا pagination.

### التابات
الشاشة المستقلة ليها تاب واحد "Goods In Transit (GIT) Ledger" (`:40`، والـ `titleAr` بتاعه "رصيد البضاعة بالطريق وتتبع الشحنات"، وده مختلف عن اسم نفس التاب في الـ Hub). الصورة: ![](../screenshots/42-goods-in-transit-tab-1-goods-in-transit-git-ledger.png) (هي هي نفس الصورة الرئيسية).

### الـ Dialogs
- **`InlandTransportDialog` (TR-01):** **مش متصوّر** لأن الـ harness مالقاش زرار إضافة ("no add/create button found"، `capture-manifest.json`). محتواه تبع شاشة النقل الداخلي.

### التصدير والطباعة
- PDF، و CSV (باسم "Excel")، و TSV، ونسخ الملف كله. الحفظ بيتم بـ `FileSaveHelper.saveText` مع Save dialog. على الويب بيبقى File System Access API أو `<a download>`، وده فرق خاص بالويب.
- اسم الملف `Goods_In_Transit_Ledger_<timestamp>.tsv/.csv` (`services/goods_in_transit_export_service.dart:119`، `:137`).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| Critical | **دفتر GIT مالوش أي مصدر في الباك إند.** الـ provider بيبدأ بقايمة فاضية، وبيتملي بس من `addReconciledShipment` في تاب مطابقة الـ Packing List، والبيانات دي في الذاكرة بس. يعني الرصيد بيضيع مع أي reload أو إعادة تشغيل، ومش مشترك بين المستخدمين، وقيمة البضاعة في الطريق مش موثوقة | `providers/goods_in_transit_provider.dart:12`–`20`؛ `import_documentation/widgets/po_reconciliation_tab.dart:1240`؛ `42-goods-in-transit-main.png` (فاضي) | اعمل endpoint للـ GIT ledger (مشتق من الـ PO والـ Packing List والـ GRN) واقرا منه |
| High | زرار التحديث بينادي `initLedger()` اللي بيعمل `state = []`، يعني "تحديث" بيمسح الداتا بدل ما يجيبها | `goods_in_transit_screen.dart:309`؛ `goods_in_transit_provider.dart:17`–`20` | خلّي التحديث يعمل fetch من الباك إند |
| High | "حجز وتنسيق النقل (TR-01)" **مبيسألش على أنهي شحنة**. بياخد أول ملف مش واصل للمخزن (أو أول ملف خالص) ويفتح عليه الحجز، فممكن يتحجز نقل لشحنة غلط | `goods_in_transit_screen.dart:132`–`138` | اطلب اختيار الملف بـ `SearchableDropdownField`، أو خلّي الزرار على مستوى الصف |
| Medium | مخالفة لـ UI standards: `ElevatedButton`/`OutlinedButton` بدل `AppButton`، وألوان مباشرة (`Colors.teal`، `Color(0xFF0D9488)`، `Colors.red`، `Colors.indigo`) | `goods_in_transit_screen.dart:117`–`127`، `:51`، `:156` | استخدم `AppButton` وألوان `AppTheme` |
| Medium | نصوص عربي مكتوبة في الكود مش في l10n: "حجز وتنسيق النقل (TR-01)"، و "لا توجد ملفات استيراد متاحة لحجز النقل" | `goods_in_transit_screen.dart:130`، `:142` | انقلها لملفات الـ localization التلاتة |
| Medium | "تصدير إكسيل" بيطلّع CSV مش xlsx، واسم الملف timestamp بدل النمط `[Stage Name] - [Import File Code].ext` المطلوب في CORE_RULES (Task I) | `services/goods_in_transit_export_service.dart:130`–`145` | استخدم `FileSaveHelper.exportAndSaveFile` مع xlsx حقيقي واسم قياسي |
| Low | فلتر الحالة `DropdownButton` عادي من غير label، وبيعرض الخيار الافتراضي بس | `goods_in_transit_screen.dart:293`، `42-goods-in-transit-main.png` | استخدم `SearchableDropdownField` بـ label زي باقي الشاشات |
| Low | أزرار التصدير شغالة حتى والجدول فاضي، فبتصدّر ملف فاضي | `goods_in_transit_screen.dart:97`–`121`، `42-goods-in-transit-main.png` | عطّلها لما مفيش بيانات |
| Low | (مشكلة الـ locale المعروفة) عنوان التاب "Goods In Transit (GIT) Ledger" ظاهر إنجليزي | `42-goods-in-transit-main.png` | ضيف `supportedLocales` |
| Low | Console: `Refused to set unsafe header "Accept-Encoding"`، وده **فرق خاص بالويب** | `runtime-errors.json` → `42-goods-in-transit` | – |
