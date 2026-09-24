# الإغلاق المالي والإداري لملف الاستيراد (Import File Final Closure)
![](../screenshots/47-file-closure-main.png)

> التصوير اتعمل على **Flutter Web (Chromium)** مش Windows desktop، لأن Visual Studio مش متسطّب. قاعدة البيانات الـ scratch **مفيهاش ملفات مغلقة**، فالسجل فاضي ("لا توجد شحنات مغلقة ومؤرشفة نهائياً حالياً").

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** الإقفال النهائي لملف الاستيراد بعد ما كل حاجة تخلص: المستندات الأصلية، والإفراج الجمركي، والاستلام المخزني، وتسوية تكلفة الوصول، وإغلاق المهام. الشاشة بتصدر "شهادة إغلاق وأرشفة"، وبتحفظ مكان الأرشيف الرقمي، وبتسمح بإعادة فتح شحنة مقفولة.
- **المستخدمين:** المراجع المالي والإداري، ومدير العمليات، والإدارة العليا.
- **المرحلة:** `PHASE-6: STEP_21` (`file_closure_screen.dart:416`). **BP-040** "بوابة تدقيق الإقفال والأرشفة" (`docs/phase_10_file_closure.md`)، وفي `doc.md` اسمها BP-040 Close Import File.

## طريقة الوصول والصلاحية
- **Sidebar:** "المرحلة 6: الاستلام المخزني والتسوية المالية" ← "الإغلاق المالي والإداري لملف الاستيراد" (index 30، `home/home_screen.dart:140`).
- **Scaffold:** `VerticalStageScaffold` (Type A) بلون emerald (`:415`–`434`).
- **الصلاحية:** أي مستخدم عامل login (`modules/file_closure/router.py:30`). مفيش RBAC، يعني أي مستخدم يقدر يقفل ملف نهائياً أو يحذف شهادة.

## مكونات الشاشة

### الحقول
**السجل:** بحث بكود الشهادة والمراجع (`TextField`، `:518`، والفلترة في الباك إند).

**Dialog "إصدار شهادة إغلاق وأرشفة شحنة نهائياً"** (`_FileClosureFormDialog`، `file_closure_screen.dart:992`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختر ملف الشحنة للإغلاق النهائي * | `SearchableDropdownField<int?>` | أيوه | `v == null` ← "يرجى اختيار ملف الشحنة" (`:1204`) | `importFilesProvider`، **كل** الملفات (حتى المقفولة) (`:1196`) |
| قائمة التحقق الإلزامية (5 بنود): استلام المستندات الأصلية، والإفراج الجمركي وقرار 46، واستلام المخازن وإذن الإضافة، والتسوية المالية وتكلفة الوصول، وإغلاق المهام والتنبيهات | `CheckboxListTile` × 5 | الـ 5 لازم يتعلّموا في الاعتماد النهائي (فحص في الواجهة، `:1081`–`1088`) | **علامات يدوية**، مش محسوبة من النظام | افتراضياً **الـ 5 متعلّمين** (`:1037`–`1041`)، أو من سجل مسودة موجود (`:1060`–`1072`) |
| اسم المراجع المسؤول * | `TextFormField` | أيوه | مش فاضي ← "يلزم إدخال اسم المراجع" (`:1319`) | افتراضي وهمي "Adel Hassan (Senior Auditor)" (`:1042`) |
| مستودع الأرشيف الرقمي * | `TextFormField` | الـ label بيقول أيوه | **مفيش validator** (`:1322`–`1333`) | افتراضي "Digital Vault Archive 2026 - Main Server"، وبعد "تفريغ" بيبقى "Main Archive Vault #1" |
| ملاحظات الأرشفة والتدقيق | `TextFormField` (سطرين) | لا | – | افتراضي نص جاهز "تم استيفاء جميع المستندات…" (`:1044`) |
| مؤشر "نسبة اكتمال المهام والأوراق الكلية" | Progress + badge "x% (n/5)" + سطر تلميح 💡 إن زرار "حفظ كمسودة مؤقتة" بيحفظ التقدم لحد ما باقي الأوراق تكمل | – | – | محسوب من العلامات اليدوية (`:1157`–`1166`) |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة عند هذه المرحلة / تحديث (الهيدر) | تحكم دورة الحياة + `fetchClosures()` | import-files hold/skip، `GET /file-closure` | Authenticated |
| استيراد Excel / تصدير PDF / تصدير Excel / إعادة تحميل حية (toolbar) | `MasterDataToolbarWidget('file-closure')` | `/file-closure/import-excel`، `/export-excel`، `/export-pdf` (**مش معرّفين في الـ router**) | Authenticated |
| إصدار شهادة إغلاق وأرشفة شحنة نهائياً | dialog الإغلاق | – | – |
| بحث واستنساخ أرشفة سابقة | `SearchAndCloneFileClosureDialog` ثم `CloneEntityReviewDialog` | – | – |
| تصدير كشف الأرشيف (جدول بيانات) + أيقونتين Excel / PDF | TSV للـ clipboard، و `TableExportService` (`:257`، `:311`) | – | – |
| (بانر الملفات المغلقة) إعادة فتح | `ReopenShipmentDialog` (`:670`) | `POST /import-files/{id}/reopen-shipment` | Authenticated |
| (Dialog) إعادة تحميل حية 🔄 | `fetchClosures()` | `GET /file-closure` | Authenticated |
| (Dialog) تفريغ وبدء تسجيل جديد 🔄 | بيشيل كل العلامات ويفضّي المراجع والملاحظات، وبيحط "Main Archive Vault #1" | – | – |
| (Dialog) حفظ كمسودة مؤقتة 💾 | `is_draft: true` (عليه spinner) | `POST /file-closure` | Authenticated |
| (Dialog) إلغاء | قفل الـ dialog من غير حفظ | – | – |
| (Dialog) اعتماد الإغلاق والأرشفة النهائية ✅ | `is_draft: false` (عليه spinner) | `POST /file-closure` | Authenticated |
| (كارت) عرض الشهادة / تعديل / طباعة / حذف / نسخ / استنساخ | عرض شهادة، و**تعديل = SnackBar بس** (`:897`–`901`)، وطباعة = نسخ ملخص، وحذف = soft delete | `DELETE /file-closure/{id}` | Authenticated |

### الجداول
- **بانر الملفات المغلقة** (`:552`–`660`): بيظهر لو في ملفات حالتها Closed، وفيه chip لكل ملف وزرار إعادة فتح.
- **كروت الشهادات:** كود الشهادة، وbadge "مغلق"، والملف، والمراجع، ومكان الأرشيف، وتاريخ الإغلاق، والملاحظات، و5 chips لبنود التحقق (`_buildChecklistChip`، `:970`)، وأزرار الصف (`RowActionsPill`). مفيش ترتيب ولا pagination.

### التابات
1. **سجل الملفات المغلقة والمؤرشفة (Archived Files Registry):** ![](../screenshots/47-file-closure-tab-1-archived-files-registry.png)
2. **إغلاق وأرشفة ملف شحنة (Close Import File):** ![](../screenshots/47-file-closure-tab-2-close-import-file.png). **مش تاب**: بيفتح dialog الإغلاق (`:423`–`427`). الصورة بتبيّن الحالة الافتراضية: **الـ 5 بنود متعلّمين و 100% (5/5)** من غير ما يتختار ملف أصلاً، واسم المراجع "Adel Hassan (Senior Auditor)". والأزرار نازلة تحت بعض في عمود.

### الـ Dialogs
- **إصدار شهادة إغلاق وأرشفة:** ![](../screenshots/47-file-closure-dialog-add.png). الصورة دي بعد ما الـ harness داس "تفريغ وبدء تسجيل جديد"، فالعلامات 0% (0/5) والمستودع "Main Archive Vault #1".
- **أخطاء الـ validation:** ![](../screenshots/47-file-closure-dialog-add-validation.png). ظهر "يرجى اختيار ملف الشحنة" و "يلزم إدخال اسم المراجع" بالأحمر.
- `ReopenShipmentDialog`، وشهادة الإغلاق، والاستنساخ: **مش متصوّرين** (مفيش ملفات مغلقة).

### التصدير والطباعة
TSV للـ clipboard، و Excel و PDF لكشف الأرشيف (`TableExportService`)، ونسخ ملخص الشهادة بدل الطباعة، وتصدير الـ toolbar العام (مش شغال). الحفظ على الويب بيبقى File System Access API / `<a download>`، وده فرق خاص بالويب.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل | الاقتراح |
|---|---|---|---|
| High | قائمة التحقق **علامات يدوية متعلّمة افتراضياً (5/5 = 100%)** قبل اختيار أي ملف. الشاشة دي مبتسألش النظام، مع إن `GET /file-closure/closure-precheck/{id}` و `POST /file-closure/official-close` موجودين في الـ provider والباك إند، والـ widget الرسمي `OfficialFileClosureDialog` مستخدم بس من تفاصيل ملف الاستيراد، مش من الشاشة دي. الباك إند بيعمل فحص من الـ DB للإفراج الجمركي والـ GRN والتسوية عند الاعتماد النهائي، لكن بندين "المستندات الأصلية" و "إغلاق المهام" معتمدين على العلامة اليدوية بس | `file_closure_screen.dart:1037`–`1041`؛ `47-file-closure-tab-2-close-import-file.png`؛ `providers/file_closure_provider.dart:95`، `:108`؛ `import_files/widgets/import_file_details_dialog.dart:1086`؛ `modules/file_closure/service.py:43`–`92` | اعرض نتيجة الـ precheck للقراءة بس، واستخدم `official-close` |
| High | فحوصات الإغلاق في الباك إند (الإفراج، والـ GRN، والتسوية) ملفوفة في `try/except Exception: pass`، فأي خطأ في الاستعلام بيعدّي الفحص ويسمح بالإغلاق (fail-open) | `modules/file_closure/service.py:47`–`87` | خلّيها fail-closed: أي exception = رفض |
| High | الشاشة فيها 5 بنود بس، والـ spec بيطلب **بوابة سداسية**. ناقص "نموذج 4 البنكي وإيصال السويفت مطابق"، و "إرجاع الحاوية ولا توجد غرامات معلقة" | `file_closure_screen.dart:1271`–`1305`؛ `docs/phase_10_file_closure.md:10`–`18` | كمّل البوابة بالـ 6 بنود من الـ precheck |
| High | بيانات افتراضية وهمية: اسم مراجع "Adel Hassan (Senior Auditor)"، ومستودع، وملاحظة "تم استيفاء جميع المستندات…". وده بيتسجل في شهادة رسمية لو المستخدم معدّلش | `file_closure_screen.dart:1042`–`1044` | المراجع = المستخدم الحالي (`current_user`)، والباقي فاضي |
| Medium | "مستودع الأرشيف الرقمي *" عليه نجمة إلزامي **ومفيش validator**، ونص حر بدل master | `file_closure_screen.dart:1322`–`1333` (الـ `TextFormField` مالوش `validator`)؛ `app_localizations_ar.dart:3484` | validator، أو قايمة مستودعات |
| Medium | زرار "تعديل" في الكارت بيطلّع SnackBar بس ومبيفتحش حاجة | `file_closure_screen.dart:897`–`901` | افتح الـ dialog بالسجل (`initialRecord`) |
| Medium | Dropdown الملف بيعرض **كل** ملفات الاستيراد، حتى المقفولة والمؤرشفة | `file_closure_screen.dart:1196`–`1202` | فلتر على الملفات اللي مستوفية ومش مقفولة |
| Medium | كل بند في القايمة بيبان فيه **checkbox مرتين**: أيقونة `secondary` شكلها checkbox، و checkbox حقيقي على الناحية التانية، وده بيلخبط | `file_closure_screen.dart:1273`، `:1280`؛ `47-file-closure-dialog-add.png` | شيل أيقونة الـ secondary أو غيّرها لأيقونة المرحلة |
| Medium | الأزرار فيها إيموجي في نص الـ l10n (🔄 💾 ✅) **ومعاها** أيقونة Material، فالأيقونة بتتكرر. وفي تاب 2 الأزرار نازلة عمود تحت بعض (overflow direction) وبتاخد مساحة كبيرة | `app_localizations_ar.dart:3486`–`3488`، `:3501`؛ `47-file-closure-tab-2-close-import-file.png` | شيل الإيموجي، واستخدم `StandardFormActionBar` |
| Medium | تاب "إغلاق وأرشفة ملف شحنة" مش تاب، بيفتح dialog | `file_closure_screen.dart:423`–`427` | زرار في الـ toolbar |
| Medium | أزرار `MasterDataToolbarWidget` بتنادي `/file-closure/import-excel` و `/export-excel` و `/export-pdf`، ومش معرّفين في الـ router (GET هيقع على `/{closure_id}` ويرجع 422) | `core/widgets/master_data_toolbar.dart:57`؛ `modules/file_closure/router.py:32`–`131` | اعمل الـ endpoints أو شيل الـ toolbar |
| Medium | مخالفة لـ UI standards: `ElevatedButton` وألوان كتير مكتوبة مباشر (`Color(0xFFEFF6FF)`، و `Color(0xFF2E1A05)`، و `Color(0xFF7F1D1D)`…) | `file_closure_screen.dart:469`، `:558`–`658`، `:1384` | `AppButton` + ألوان dark/light في `AppTheme` |
| Low | (مشكلة الـ locale المعروفة) "Import File Final Closure & Archival" والتابات الرأسية إنجليزي | `47-file-closure-main.png` | `supportedLocales` |
| Low | Console: `Refused to set unsafe header "Accept-Encoding"` (مرتين)، وده **فرق خاص بالويب** | `runtime-errors.json` → `47-file-closure` | – |
