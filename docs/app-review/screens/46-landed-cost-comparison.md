# مقارنة التكلفة التقديرية والفعلية (Estimated vs Actual Landed Cost)
![](../screenshots/46-landed-cost-comparison-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب. الشاشة دي **تاب مدمج** (التاني) جوه شاشة التسوية المالية (45). مفيش ملف متختار، فالشاشة بتعرض بس "الرجاء اختيار ملف استيراد لعرض ومقارنة عروض الأسعار". الـ harness **مختارش ملف**، فمحتوى المقارنة (الكروت والجداول) متوثّق من الكود بس.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** مقارنة التكلفة التقديرية لملف الاستيراد (`estimated_cost` من ملف الاستيراد) بالتكلفة الفعلية المسجلة في التسوية المالية، وحساب نسبة الانحراف، وعرض تفصيل المصاريف الفعلية وتكلفة الوحدة لكل صنف مع معامل الزيادة.
- **المستخدمين:** مدير المالية، ومسؤول التكاليف، والإدارة.
- **المرحلة:** `PHASE-6: STEP_20`. **BP-039** (شيت تكلفة البند النهائي ومعامل الزيادة، `docs/phase_09_financial_settlement.md`).

## طريقة الوصول والصلاحية
- **الوصول:** شاشة التسوية المالية (sidebar index 29) ← التاب التاني، أو index 50 مباشرة (`home/home_screen.dart:172`). الـ widget بيتبني lazy جوه `IndexedStack` (`financial_settlement_screen.dart:713`–`715`)، وبيقبل `importFileId` كمان (`landed_cost_comparison_screen.dart:20`–`25`).
- **الصلاحية:** `GET /api/v1/import-files/{id}` و GET للتسويات، والاتنين authenticated بس، مفيش RBAC.

## مكونات الشاشة

### الحقول

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختر ملف الاستيراد (label: "اختر ملف الاستيراد لمقارنة عروض الأسعار") | `SearchableDropdownField<int>` | لا | – | `importFilesProvider` (`landed_cost_comparison_screen.dart:250`) |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| اختيار ملف | `_fetchData(fileId)`: بيجيب التكلفة التقديرية والـ Incoterm، وبعدين التسوية | `GET /api/v1/import-files/{id}`، و `GET /api/v1/financial-settlements?import_file_id=` (**URL غلط**) | Authenticated |
| Chip كود الملف | نسخ الكود (`:272`) | – | – |
| تصدير TSV / تصدير Excel / طباعة PDF / نسخ الملف | `LandedCostComparisonExportService` (بتظهر بعد تحميل مقارنة) (`:397`–`430`) | – | – |
| نسخ (في الهيدر) و BackToDashboardButton | في الوضع المستقل بس (`:207`، `:218`) | – | – |

### الجداول
المحتوى ده بيظهر بس لو في تسوية للملف (متوثّق من الكود، **مفيش صورة**):
- **كروت المقارنة:** التكلفة التقديرية، والفعلية، والانحراف % (`:695`)، و Incoterm.
- **جدول تفصيل المصاريف** (`:713`–`718`): فئة المصروف | مقدم الخدمة | العملة | المبلغ بالعملة | سعر الصرف | المبلغ بالجنيه.
- **جدول تكلفة الأصناف** (`:782`–`787`): كود الصنف | الاسم | الكمية | سعر FOB للوحدة | تكلفة الوحدة النهائية | معامل الزيادة.
- لو مفيش تسوية: "لا توجد بيانات تكلفة وصول مسجلة" (`noLandedCostDataRegistered`).

### التابات
مفيش تابات داخلية.

### الـ Dialogs
مفيش dialogs ("no add/create button found" في `capture-manifest.json`).

### التصدير والطباعة
TSV و Excel بـ `FileSaveHelper.saveText` (`services/landed_cost_comparison_export_service.dart:216`، `:334`)، و PDF، ونسخ للـ clipboard (`:96`). وكلهم بيظهروا بعد اختيار ملف فيه تسوية بس. الحفظ على الويب بيبقى File System Access API / `<a download>`، وده فرق خاص بالويب.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| Critical | الشاشة بتنادي **`/api/v1/financial-settlements`** (جمع)، والـ router الحقيقي على `/api/v1/financial-settlement` (مفرد). النتيجة 404، والـ `catch` بيبلعه ويحط `_settlementRecord = null`، فالمقارنة **مش هتشتغل أبداً**، وهتقول دايماً "لا توجد بيانات تكلفة وصول مسجلة" حتى لو في تسوية | `landed_cost_comparison_screen.dart:106`–`108`، `:124`–`128`؛ `modules/financial_settlement/router.py:43` | صحّح الـ URL واستخدم `ApiConstants`، واعرض الخطأ بدل ما تبلعه |
| High | كل الأخطاء بتتبلع بصمت: فشل تحميل ملف الاستيراد بيخلّي التكلفة التقديرية = 0 والـ Incoterm = FOB، ومفيش أي رسالة للمستخدم. المتغير `_error` بيتعرض في الـ build (`:171`–`172`) بس عمره ما بيتحط له قيمة غير `null` (`:76`)، فحالة الخطأ دي مش بتظهر أبداً | `landed_cost_comparison_screen.dart:33`، `:76`، `:98`–`102`، `:126`–`134`، `:171`–`172` | اعرض SnackBar أو حالة خطأ |
| Medium | النص غلط: الـ label والرسالة الفاضية بيقولوا "لمقارنة **عروض الأسعار**". مفاتيح الـ l10n دي متشاركة مع شاشة مقارنة عروض النولون، ومالهاش علاقة بتكلفة الوصول | `46-landed-cost-comparison-main.png`؛ `landed_cost_comparison_screen.dart:251`، `:308`؛ `app_localizations_ar.dart:5355`، `:5363` | اعمل مفاتيح خاصة بالشاشة دي ("اختر ملف الاستيراد لمقارنة التكلفة التقديرية بالفعلية") |
| Medium | الـ label والـ hint بيترسموا فوق بعض جوه الـ dropdown ومش بيتقروا ("ابحث برقم الملف…" فوق "اختر ملف الاستيراد…") | `46-landed-cost-comparison-main.png`، `45-financial-settlement-tab-2-estimated-vs-actual-comparison.png`؛ `landed_cost_comparison_screen.dart:251`–`252` | استخدم `labelText` بس، أو خلّي الـ hint يظهر لما الحقل يتفتح |
| Medium | الـ endpoint مكتوب كنص في الشاشة (`dio.get` مباشر)، مش من `ApiConstants` ولا من provider. ده مخالف للـ architecture (Flutter ← provider ← API) | `landed_cost_comparison_screen.dart:82`–`110` | انقله لـ `financialSettlementProvider` |
| Low | ألوان مباشرة (`Colors.blue`، `Colors.green.shade*`) ونص "نسخ" وSnackBar مكتوبين في الكود | `landed_cost_comparison_screen.dart:146`، `:207`، `:272`، `:411`، `:551` | `AppTheme` + l10n |
| Low | (مشكلة الـ locale المعروفة) الهيدر والتابات الرأسية إنجليزي | `46-landed-cost-comparison-main.png` | `supportedLocales` |
| Low | Console: `Refused to set unsafe header "Accept-Encoding"`، وده **فرق خاص بالويب** | `runtime-errors.json` → `46-landed-cost-comparison` | – |
