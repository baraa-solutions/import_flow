# تكلفة الوصول والتسوية المالية ومقارنة الفروق (Landed Cost & Settlement Hub)
![](../screenshots/45-financial-settlement-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب. قاعدة البيانات الـ scratch **مفيهاش تسويات**، فالسجل فاضي ("لا توجد تسويات مالية لتكلفة الوصول مسجلة حالياً").

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** محرك تكلفة الوصول الشاملة (Landed Cost). بيسجّل فواتير المصاريف (نولون، وجمارك، وتخليص، ونقل، وأرضيات)، ويوزّعها على الأصناف بمعيار (الحجم / القيمة / الوزن / بالتساوي)، ويحسب تكلفة الوحدة النهائية بالجنيه ومعامل زيادة التكلفة (Markup Factor)، وبيولّد قيد يومية لـ Odoo. وكمان فيه تجميع فواتير الملف (CLO-01)، والتكلفة الفعلية (CLO-02)، ومقارنة التقديري بالفعلي.
- **المستخدمين:** المحاسب ومدير المالية، ومسؤول التكاليف.
- **المرحلة:** `PHASE-6: STEP_20` (`financial_settlement_screen.dart:629`). **BP-036 / BP-037** (تجميع المصروفات)، و **BP-038** (محرك التوزيع)، و **BP-039** (شيت تكلفة البند) من `docs/phase_09_financial_settlement.md`. مرتبطة بـ MD-006A (Cost Item Master) و MD-005 (العملات) في `doc.md`.

## طريقة الوصول والصلاحية
- **Sidebar:** "المرحلة 6: الاستلام المخزني والتسوية المالية" ← "تكلفة الوصول والتسوية المالية ومقارنة الفروق" (index 29، `home/home_screen.dart:139`، `initialSubTab: 0`)، و index 50 بيفتحها على تاب المقارنة (`home_screen.dart:172`).
- **Scaffold:** `VerticalStageScaffold` (Type A) بلون cobalt (`:628`). الهيدر فيه العنوان "Comprehensive Landed Cost Engine" وبادج المرحلة "Landed Cost Settlement" (مشتق من `STEP_20`)، وفوق التابات "Operations & Stages". الشريط اللي تحت الهيدر "عمليات البيانات والتصدير/الاستيراد" هو `MasterDataToolbarWidget`.
- **الصلاحية:** أي مستخدم عامل login (`modules/financial_settlement/router.py:43`، `Depends(get_current_user)`). مفيش RBAC، يعني أي مستخدم يقدر يعتمد تكلفة فعلية أو يصدّر قيد محاسبي.

## مكونات الشاشة

### الحقول
**السجل (تاب 1):** بحث برقم التسوية واسم المحاسب (`TextField`).

**Dialog "تسجيل مصاريف وبنود شحنة لاحتساب تكلفة الوصول"** (`_FinancialSettlementFormDialog`، `:1319`):

الحقول متقسمة تحت عنوانين: "بيانات فاتورة المصروف والخدمات اللوجستية:" (`:1356`) و "بيانات صنف الشحنة والاستيراد:". وفي العرض الضيق (`isCompact`) الحقول بتترص تحت بعض (`:1361`).

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة الاستيرادية * | `SearchableDropdownField<int?>` | أيوه | `v == null` (`:1348`) | `importFilesProvider` |
| رقم الفاتورة * | `TextFormField` | الـ label بيقول أيوه | **مفيش validator** (`:1386`) | افتراضي وهمي "INV-LOG-01" (`:1257`) |
| فئة المصروف * | `SearchableDropdownField<String>` | أيوه | – | قايمة ثابتة: نولون شحن / رسوم جمركية / تخليص / نقل محلي / أرضيات (`:1397`–`1403`) |
| اسم مورد الخدمة * | `TextFormField` | الـ label بيقول أيوه | **مفيش validator** | **نص حر**، افتراضي "Maersk Shipping Line" (`:1259`) |
| المبلغ بالعملة الأجنبية | `TextFormField` رقمي | – | مفيش | افتراضي 1000 |
| سعر الصرف | `TextFormField` رقمي | – | مفيش | **افتراضي 50.0 ثابت** (`:1261`) |
| قاعدة توزيع المصروف على الأصناف * | `SearchableDropdownField<String>` | أيوه | – | حسب الحجم / القيمة / الوزن / بالتساوي |
| كود الصنف، اسم الصنف | `TextFormField` | – | مفيش | افتراضي "ITM-001" / "Imported Cargo Valves" (`:1272`–`1273`) |
| الكمية المستلمة، سعر الفاتورة للوحدة بالجنيه | `TextFormField` رقمي | – | مفيش | افتراضي 100 / 500 |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تسوية الفواتير (CLO-01) (الهيدر) | `FinalSettlementInvoicesDialog` على **أول ملف في القايمة** (`:657`–`664`) | `GET /financial-settlement/invoices-aggregation/{id}`، `POST .../confirm-invoices-settlement` | Authenticated |
| التكلفة الفعلية (CLO-02) (الهيدر) | `ActualLandedCostDialog` على **أول ملف** (`:683`–`690`) | `POST .../calculate-actual-landed-cost/{id}`، `POST .../approve-actual-landed-cost` | Authenticated |
| تخطي المرحلة / إيقاف الشحنة عند هذه المرحلة | تحكم دورة حياة الشحنة (`VerticalStageScaffold`) | import-files hold/skip | Authenticated |
| تحديث (الهيدر) | `fetchSettlements()` | `GET /financial-settlement` | Authenticated |
| استيراد Excel / تصدير PDF / تصدير Excel / إعادة تحميل حية (toolbar) | `MasterDataToolbarWidget` بـ `moduleEndpoint: 'financial-settlement'` | `/financial-settlement/import-excel` و `/export-excel` و `/export-pdf` (**مش معرّفين في الـ router**) | Authenticated |
| تسجيل فواتير مصاريف واحتساب تكلفة الوصول | dialog الإضافة | – | – |
| بحث واستنساخ تسوية تكلفة سابقة | `SearchAndCloneFinancialSettlementDialog` ثم `CloneEntityReviewDialog` | – | – |
| تصدير كشف التسويات (جدول بيانات) + أيقونتين Excel / PDF | TSV للـ clipboard، و `TableExportService` | – | – |
| (Dialog) حفظ وتوزيع بنود المصروف | إنشاء تسوية بمصروف واحد وصنف واحد | `POST /financial-settlement` | Authenticated |
| (Dialog) تفريغ وبدء تسجيل جديد | بيفضّي الفاتورة والمورد والمبلغ، وبيرجّع سعر الصرف 50.0 | – | – |
| (Dialog) إعادة تحميل حية | `fetchSettlements()` | `GET /financial-settlement` | Authenticated |
| (Dialog) إلغاء | قفل الـ dialog (`:1568`) | – | – |
| (كارت) عرض | `OdooJournalEntryDialog` | `GET /{id}/odoo-journal-entry` | Authenticated |
| (كارت) تعديل وإعادة احتساب | **مبيفتحش تعديل**، بيعمل recalculate ويطلّع SnackBar نجاح من غير ما يستنى النتيجة (`:1023`–`1028`) | `POST /{id}/recalculate` | Authenticated |
| (كارت) طباعة | نسخ breakdown كـ TSV | – | – |
| (كارت) حذف | Soft delete | `DELETE /financial-settlement/{id}` | Authenticated |
| (كارت) RecalculateButton، تسوية الفواتير، التكلفة الفعلية، نسخ، استنساخ | – | `recalculate` / CLO-01 / CLO-02 | Authenticated |
| (كارت) 📒 تصدير قيد اليومية للنظام المالي | `OdooJournalEntryDialog` (CSV/Excel) | `GET /{id}/export-odoo-csv`، `/export-odoo-excel` | Authenticated |

### الجداول
- **كروت التسويات:** 4 مؤشرات (إجمالي قيمة فاتورة الشراء، وإجمالي المصاريف والنولون، وتكلفة الوصول الشاملة، ومعامل زيادة التكلفة)، وبعدين:
  - **جدول المصاريف:** رقم الفاتورة | الفئة | مورد الخدمة | المبلغ بالعملة | سعر الصرف | المبلغ بالجنيه | قاعدة التوزيع.
  - **جدول تكلفة الأصناف:** كود الصنف | الاسم | الكمية | سعر FOB للوحدة | نصيب النولون | نصيب الجمارك | نصيب التخليص | نصيب النقل | تكلفة الوحدة النهائية | معامل الزيادة (`:1001`–`1008`).
- الفلترة بالبحث. مفيش ترتيب ولا pagination.

### التابات
1. **سجل تسويات تكلفة الوصول وتوليد القيود (Landed Cost Registry):** ![](../screenshots/45-financial-settlement-tab-1-landed-cost-registry.png)
2. **مقارنة التكلفة التقديرية والفعلية (Estimated vs Actual Comparison):** ![](../screenshots/45-financial-settlement-tab-2-estimated-vs-actual-comparison.png). ده `LandedCostComparisonScreen` مدمج، وشرحه في `46-landed-cost-comparison.md`.
3. **احتساب وتسوية تكلفة شحنة جديدة (New Cost Settlement):** ![](../screenshots/45-financial-settlement-tab-3-new-cost-settlement.png). **مش تاب**: الضغط عليه بيفتح dialog الإضافة فوق التاب اللي قبله (`:636`–`639`).

### الـ Dialogs
- **تسجيل مصاريف وبنود شحنة:** ![](../screenshots/45-financial-settlement-dialog-add.png). بيفتح **متملي بيانات وهمية** (INV-LOG-01، و Maersk Shipping Line، و 1000، و 50.0، و ITM-001 Imported Cargo Valves، و 100، و 500).
- **أخطاء الـ validation:** ![](../screenshots/45-financial-settlement-dialog-add-validation.png). الـ harness فضّى الفورم بزرار "تفريغ" وضغط حفظ، فظهر خطأ واحد بس "يرجى اختيار ملف الشحنة". "رقم الفاتورة *" و "اسم مورد الخدمة *" فاضيين ومظهرش تحتهم أي خطأ.
- `FinalSettlementInvoicesDialog` (CLO-01)، و `ActualLandedCostDialog` (CLO-02)، و `OdooJournalEntryDialog`، والاستنساخ: **مش متصوّرين**.

### التصدير والطباعة
- كشف التسويات: TSV للـ clipboard، و Excel و PDF بـ `TableExportService`، وتصدير الـ toolbar العام (مش شغال)، وقيد Odoo CSV/Excel بـ `FileSaveHelper.saveText/saveBytes` (`screens/odoo_journal_entry_dialog.dart:72`، `:98`). الحفظ على الويب بيبقى File System Access API / `<a download>`، وده فرق خاص بالويب.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| High | أزرار الهيدر "تسوية الفواتير (CLO-01)" و "التكلفة الفعلية (CLO-02)" **مبتسألش على الشحنة**. بتفتح على `files.first` (أول ملف في القايمة)، فممكن يتعمل تجميع فواتير أو اعتماد تكلفة فعلية لملف غلط. كود الملف بيظهر في هيدر الـ dialog بس، ومفيش طريقة تغيّره منه. ورسالة "يرجى اختيار شحنة أولاً" بتظهر بس لو مفيش ملفات خالص | `financial_settlement_screen.dart:658`–`669`، `:684`–`694`؛ `widgets/final_settlement_invoices_dialog.dart:246` | اطلب اختيار الملف بـ `SearchableDropdownField` قبل ما تفتح الـ dialog |
| Medium | الـ payload بيبعت `gross_weight_kg: 1000.0` و `cbm: 10.0` **ثابتين**، و `currency: 'USD'` ثابت. المبلغ بالجنيه نفسه بيتحسب صح من سعر الصرف اللي المستخدم دخّله (`fx * rate`)، وبما إن الفورم فيه صنف واحد بس فالتوزيع بيروح كله عليه. بس العملة المسجلة غلط لأي فاتورة مش بالدولار، والوزن والحجم المتخزنين وهميين، فأي إعادة حساب أو تقرير بيعتمد عليهم هيطلع غلط | `financial_settlement_screen.dart:1588`، `:1591`، `:1599`–`1600` | هات الوزن والحجم من الـ PO / Packing List، وضيف اختيار عملة من master العملات |
| High | سعر الصرف الافتراضي **50.0 ثابت** في الواجهة (حتى بعد "تفريغ")، ولو القيمة مش رقم بيبقى 1.0. وفي الباك إند `base_exchange_rate = 48.5` ثابت في تجميع الفواتير، ونسب النولون الحكمي 2% والتأمين 2.5% ثابتة في الكود. ده مخالف لقاعدة "ممنوع Hard-Code أي نسبة أو رسم" | `financial_settlement_screen.dart:1261`، `:1561`، `:1583`؛ `modules/financial_settlement/service.py:860`، `:542`، `:566` | هات السعر من master العملات بتاريخ الفاتورة، وخلّي النسب إعدادات |
| High | الـ dialog بيفتح **متملي بيانات وهمية** (INV-LOG-01، Maersk، 1000 USD، ITM-001 Valves 100×500)، فأي ضغطة "حفظ" بعد اختيار الملف بتسجّل تسوية مخترعة | `financial_settlement_screen.dart:1256`–`1276`؛ `45-financial-settlement-dialog-add.png` | ابدأ بحقول فاضية |
| High | "رقم الفاتورة *" و "اسم مورد الخدمة *" عليهم نجمة الإلزامي **ومفيش validator**. والمبلغ والكمية والسعر مفيش عليهم تحقق رقمي | `financial_settlement_screen.dart:1386`–`1389`، `:1442`–`1461`؛ `45-financial-settlement-dialog-add-validation.png` (مفيش خطأ تحتهم) | ضيف validators |
| High | الفورم بيسمح بفاتورة مصروف **واحدة** وصنف **واحد** بس لكل تسوية، مع إن BP-036/038 محتاجة تجميع كل المصروفات وتوزيعها على كل الأصناف | `financial_settlement_screen.dart:1604`–`1608` | Repeaters للمصروفات والأصناف، أو اعتمد على CLO-01/CLO-02 وشيل الفورم اليدوي |
| High | زرار "تعديل" (القلم) مبيفتحش تعديل. بيعمل recalculate من غير `await` ويطلّع SnackBar نجاح فوراً حتى لو الطلب فشل | `financial_settlement_screen.dart:1023`–`1028` | افتح dialog تعديل، أو اعمل await للنتيجة واعرضها |
| High | أزرار `MasterDataToolbarWidget` بتنادي `/financial-settlement/import-excel` و `/export-excel` و `/export-pdf`، **ومش معرّفين في الـ router**. الـ GET هيقع على `/{settlement_id}` ويرجع 422 | `core/widgets/master_data_toolbar.dart:57`، `:122`؛ `modules/financial_settlement/router.py:45`–`198` | اعمل الـ endpoints أو شيل الـ toolbar |
| Medium | تاب "احتساب وتسوية تكلفة شحنة جديدة" مش تاب، بيفتح dialog. ده بيكسر نموذج التابات في Type A | `financial_settlement_screen.dart:636`–`639`؛ `45-financial-settlement-tab-3-new-cost-settlement.png` | حوّله لزرار في الـ toolbar، أو خلّيه فورم جوه تاب |
| Medium | اسم مورد الخدمة **نص حر** بدل FK على MD-003 External Service Providers / MD-004 Shipping Lines | `financial_settlement_screen.dart:1443` | `SearchableDropdownField` من `/external-service-providers` |
| Medium | مخالفة لـ UI standards: `ElevatedButton` في كل مكان، وألوان `Color(0xFF1E3A8A)` و `Color(0xFF0D9488)`، وإيموجي "📒" في label زرار ومعاه أيقونة | `financial_settlement_screen.dart:647`–`682`، `:1083`–`1112`؛ `app_localizations_ar.dart:3350` | `AppButton` + `AppTheme`، وشيل الإيموجي |
| Medium | نصوص مكتوبة في الكود: "تسوية الفواتير (CLO-01)"، و "التكلفة الفعلية (CLO-02)"، ورسايل الـ SnackBar | `financial_settlement_screen.dart:656`، `:667`، `:682`، `:693` | l10n |
| Low | الحذف مفيهوش try/catch ولا رسالة نتيجة | `financial_settlement_screen.dart:1043`–`1045` | اعرض نجاح أو فشل |
| Low | (مشكلة الـ locale المعروفة) "Comprehensive Landed Cost Engine" والتابات الرأسية ظاهرين إنجليزي | `45-financial-settlement-main.png` | `supportedLocales` |
| Low | Console: `Refused to set unsafe header "Accept-Encoding"` (3 مرات)، وده **فرق خاص بالويب** | `runtime-errors.json` → `45-financial-settlement` | – |
