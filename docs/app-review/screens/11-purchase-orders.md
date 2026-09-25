# أوامر الشراء وإثبات المنشأ (Purchase Orders & Origin)
![](../screenshots/11-purchase-orders-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الأكواد:** `BP-001` استلام أمر الشراء، و`BP-002` مراجعة الفاتورة المبدئية PI، و`BP-003` مراجعة قائمة التعبئة، و`BP-005` تخطيط تحميل الحاويات (`docs/phase_01_import_planning.md`). بتستخدم `MD-001` (الشركة المستوردة)، و`MD-002` (المورد)، و`MD-007` (المشروع)، والـ Incoterms، والعملات، والتعريفة `MD-008`.
- **الغرض:** تسجيل أوامر الشراء والفواتير المبدئية ببنودها (كود البند، والوصف، وبند التعريفة، وبلد المنشأ، والكمية، والسعر)، وقائمة التعبئة والوزن، مع حساب إجمالي القيمة والـ CBM والوزن القائم. ومنها بتتابع ميزان أمر الشراء والشحنات الجزئية.
- **المستخدمين:** مسؤول المشتريات / الاستيراد.
- **نوع الشاشة:** Type B (List Screen).

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar: "تخطيط الشحنة وأوامر الشراء" ← "أوامر الشراء وإثبات المنشأ" (index 2).
- **الصلاحية (RBAC)** في `modules/purchase_orders/router.py`: `purchase_orders.view` (القائمة، و`/{po_id}`، و`/packing-list-report`، و`/balance`)، و`purchase_orders.create` (`POST ""` و`/clone`)، و`purchase_orders.edit` (`PUT`، و`DELETE`، و`/restore`، و`/allocations`).
- **تحميل البيانات:** `initState` بيجيب أوامر الشراء والمشاريع وملفات الاستيراد (`purchase_orders_screen.dart:64-72`).

## مكونات الشاشة

### الحقول

**شريط الأدوات:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث برقم أمر الشراء أو الفاتورة أو الملاحظات... | Text | لا | — | فلترة محلية |
| جميع المشاريع | `SearchableDropdownField` | لا | — | `GET /api/v1/projects` |
| جميع الحالات | `SearchableDropdownField` (Draft / Approved / In Transit / Closed) | لا | — | قيم ثابتة (`:523-526`) |

**Dialog "أمر شراء جديد" (`POFormDialog`، `widgets/po_form_dialog.dart`)، تاب بنود الفاتورة المبدئية:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| Import File (ملف الشحنة الاستيرادية) | `SearchableDropdownField` | لا | — | `GET /api/v1/import-files` |
| PO Reference / Name (اسم / مرجع أمر الشراء) | Text | لا | — | `po_reference` |
| Proforma Invoice # | Text | لا | — | `pi_number` |
| Invoice Date (تاريخ الفاتورة) | Date | نعم | — | النهارده افتراضياً |
| Project | `SearchableDropdownField` | نعم | SnackBar في `_submitForm` (`po_form_dialog.dart:3338-3345`) | `/api/v1/projects` |
| Importing Company / Supplier | `SearchableDropdownField` + لينك "استدعاء AI Extractor & Coding" لتكويد شركة أو مورد جديد | نعم | نفس الـ SnackBar | `/import-companies`، `/suppliers` |
| Incoterm / Currency | `SearchableDropdownField` | نعم | نفس الـ SnackBar | `/incoterms`، `/currencies` |
| Country of Origin (بلد المنشأ العام) | `SearchableDropdownField` | لا | — | قائمة الدول |
| Status | `SearchableDropdownField` (Draft) | لا | — | ثابتة |
| Exchange Rate (سعر الصرف) | Number | لا | "⚡ يستدعى آلياً حسب تاريخ الفاتورة والعملة" | `/currencies` |
| Payment Terms (شروط الدفع) | `SearchableDropdownField` | نعم | — | ثابتة |
| **بنود أمر الشراء:** Item Code، وMain Description، وArabic Description، وCustoms Tariff / HS Code (بحث 🔍)، وبلد المنشأ للبند، وQty، وUnit / الوحدة، وUnit Price | Text / Dropdown | Item Code و Main و Arabic Description متعلّمين `*` | Arabic Description: `'Required'` (`:2129-2130`) | إدخال + `/customs-tariff` |

**تاب بيان التعبئة والوزن:** بيانات الطرود والأبعاد والأوزان لكل بند، بنفس منطق حاسبة الـ CBM (`BP-003`).

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| 🚀 استخراج الفاتورة والتعبئة الذكي (هيدر) | `SmartUploadButton` لاستخراج PI / PL | `POST /api/v1/smart-upload/upload` | مستخدم مسجل |
| العودة للداش بورد / 🔄 | رجوع / إعادة تحميل | `GET /api/v1/purchase-orders` | `purchase_orders.view` |
| أمر شراء جديد | يفتح `POFormDialog` | `POST /api/v1/purchase-orders` | `purchase_orders.create` |
| بحث واستنساخ أمر شراء | بحث واستنساخ | `POST /{po_id}/clone` | `purchase_orders.create` |
| إجراءات إضافية ⋮ | تصدير Excel، وتصدير PDF، ونسخ TSV، وتنزيل نموذج، واستيراد Excel (`:392-460`) | `GET /purchase-orders/export-excel`، و`/export-pdf`، و`POST /import-excel` (**مش موجودين في الباك إند**، شوف الملاحظات) | — |
| إعادة تحميل حية | إعادة تحميل | `GET /purchase-orders` | view |
| **في كل صف:** ميزان أمر الشراء والشحنات الجزئية | `POBalanceLedgerDialog` | `GET /{id}/balance` | view |
| عرض التفاصيل | `_showPODetailsDialog` (3 تابات جوه: بنود الفاتورة المبدئية، وبيان التعبئة والوزن، ومخطط ومحاكاة رص الحاويات 3D) | `GET /{po_id}` | view |
| تعديل السجل | `_showPODialog` | `PUT /{po_id}` | edit |
| استنساخ السطر (Ctrl+D) | `CloneEntityReviewDialog` | `POST /{po_id}/clone` | create |
| طباعة وتصدير PDF | PDF لأمر الشراء | — | — |
| إيقاف تفعيل أمر الشراء | soft delete | `DELETE /{po_id}` | edit |
| **Dialog:** 🚀 استخلاص ذكي (PI / PL)، و🚀 قراءة الفاتورة المبدئية | استخراج من ملف | `/smart-upload/upload` | — |
| **Dialog:** Add Item / Clone Line Item (Ctrl + D) | إضافة / تكرار بند | — | — |
| **Dialog:** معاينة تقرير أمر الشراء | معاينة قبل الحفظ (BP-001) | — | — |
| **Dialog:** حفظ أمر الشراء (فيه spinner `_isSubmitting`) / إلغاء | حفظ | `POST` / `PUT` | create / edit |
| **Dialog:** ✕ "إغلاق وتراجع" (رأس الـ dialog) | قفل من غير حفظ | — | — |

### الجداول

- **شريط مؤشرات:** إجمالي أوامر الشراء، وإجمالي قيمة البضاعة (`$`)، وإجمالي الحجم CBM، وإجمالي الوزن القائم (`:220-241`).
- **الجدول الرئيسي** (`:649-659`): الإجراءات، ورقم أمر الشراء (المرجع + الكود `PO-2026-00x`)، وتاريخ الفاتورة، وملف الاستيراد، ورقم الفاتورة المبدئية، والمشاريع ومراكز التكلفة، والشركة المستوردة، والمورد الأجنبي، وإجمالي FOB، والـ CBM والوزن، والـ Lifecycle.
- على 1600px آخر عمود ظاهر هو "الشركة المستوردة" (مقصوص)، والباقي محتاج scroll أفقي.
- **الفلاتر:** بحث، ومشروع، وحالة.

### التابات

مفيش تابات في الشاشة نفسها. التابات جوه الـ dialogs:
- Dialog الإضافة: "بنود الفاتورة المبدئية (1)" و"بيان التعبئة والوزن (1)" (`11-purchase-orders-dialog-add.png`).
- Dialog التفاصيل: 3 تابات (من الكود، متصورتش).

### الـ Dialogs

- **أمر شراء جديد:** `11-purchase-orders-dialog-add.png`. الفورم بيفتح بقيم افتراضية متعبّية (المشروع PRJ-2026-005، والشركة، والمورد، وFOB، وUSD، وسعر صرف 48.95، وCash in Advance)، ومعاه أداة قراءة الفاتورة المبدئية فوق.
- **أخطاء الـ validation:** `11-purchase-orders-dialog-add-validation.png`. الحفظ **عدّى الـ validation في الـ client** ووصل للباك إند، ورجع `422` (`runtime-errors.json`: `POST /api/v1/purchase-orders` 422). اللي ظهر للمستخدم SnackBar أحمر فيه رسالة Pydantic خام بالإنجليزي: "String should have at least 2 characters"، ومن غير اسم الحقل.
- Dialogs تانية (من الكود): `POBalanceLedgerDialog`، و`POReconciliationWarningDialog`، و`CloneEntityReviewDialog`، ومحاكي رص الحاويات.

### التصدير والطباعة

- ⋮ ← تصدير Excel / PDF: `_downloadPOFile` بيعمل `GET` بعدين `FileSaveHelper.saveBytes` بأسماء ثابتة `Purchase_Orders.xlsx` / `Purchase_Orders.pdf` (`purchase_orders_screen.dart:248-265`، و`:447`، و`:450`).
- نسخ TSV، وتنزيل نموذج إكسل، واستيراد Excel (`:278-297`).
- طباعة PDF لكل أمر شراء من الصف، ومعاينة تقرير أمر الشراء من الـ dialog.

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | تصدير Excel/PDF واستيراد Excel بينادوا `/purchase-orders/export-excel` و`/export-pdf` و`/import-excel`، والـ routes دي **مش موجودة** في الباك إند (الـ router فيه `""` و`/{po_id}` و`/packing-list-report` و`/allocations` و`/balance` و`/clone` و`/restore` بس). فالـ `GET` هيتطابق مع `/{po_id}` ويفشل | `purchase_orders_screen.dart:293`، و`:447`، و`:450`؛ `modules/purchase_orders/router.py:29-133` | أضف الـ endpoints في Router ← Service، أو شيل الإجراءات من المنيو |
| High | الحفظ بيعدّي الـ validation في الـ client ويتصد من الباك إند بـ 422، والمستخدم بيشوف رسالة Pydantic إنجليزي خام من غير اسم الحقل | `11-purchase-orders-dialog-add-validation.png`؛ `runtime-errors.json` (11-purchase-orders: POST 422)؛ `modules/purchase_orders/schemas.py:10` و`:44` (`min_length=2`) | طابق قواعد الـ client مع الـ schema (الوصف العربي، والـ HS Code اللي "None / General")، وترجم أخطاء 422 لاسم الحقل |
| Medium | عمود "ملف الاستيراد" بيطلع `-` لكل أوامر الشراء مع إن ملفات الاستيراد بتذكر أرقامها (FILE-2026-0006 ← PO-2026-006). ده لأن الربط من ناحية ملف الاستيراد نص حر | `11-purchase-orders-main.png`، `10-import-files-main.png`؛ `import_file_form_dialog.dart:617-627` | اربط بـ FK واحد (`import_file_id` / `po_id`) |
| Medium | مؤشر "إجمالي قيمة البضاعة" بيجمع كل أوامر الشراء بعملاتها المختلفة ويحط عليها `$` | `purchase_orders_screen.dart:227`؛ `11-purchase-orders-main.png` (`$333400.00`) | حوّل بسعر الصرف، أو اعرض إجمالي لكل عملة |
| Medium | Labels الـ dialog مخلوطة إنجليزي + عربي في نفس النص ("Invoice Date (تاريخ الفاتورة)"، و"Supplier (المورد الأجنبي)"، و"Unit Price (سعر الوحده)")، وده ممنوع في §5 من الـ Skill. وفيه كمان نصوص ثابتة: `'Arabic Description *'` و`'Required'` | `11-purchase-orders-dialog-add.png`؛ `po_form_dialog.dart:2129-2130` | `context.l10n` بلغة واحدة |
| Medium | رسائل الـ SnackBar في `_submitForm` عربي ثابت | `po_form_dialog.dart:3331` و`:3344` | l10n |
| Medium | التصدير بيعمل `await dio.get` قبل `FileSaveHelper.saveBytes`. على الويب ده بيضيّع الـ user gesture، فبيحصل تنزيل تلقائي (fallback) من غير نافذة "حفظ باسم". وأسماء الملفات عامة (`Purchase_Orders.xlsx`) ومخالفة لـ Task I | `purchase_orders_screen.dart:248-265`؛ `core/services/file_save_helper.dart:73-83` و`:273-275` | `FileSaveHelper.exportWithPickerAndFetch` واسم `[Stage] - [Code]` |
| Medium | الهيدر فيه 3 إجراءات (استخراج + العودة + 🔄)، والـ 🔄 بعد العودة | `purchase_orders_screen.dart:109-139`؛ `11-purchase-orders-main.png` | Type B: إجراء رئيسي + العودة بس |
| Low | فيه زرارين تحديث (🔄 في الهيدر و🔄 في الشريط) | `purchase_orders_screen.dart:140`، و`:538`، و`:556` | واحد في الـ Toolbar |
| Low | الجدول أعرض من الشاشة، وعمود الشركة مقصوص | `11-purchase-orders-main.png` | ثبّت عمود الإجراءات وقلّل الأعمدة |
| Low | Console: `Accept-Encoding` (14 مرة). **فرق Web بس** | `runtime-errors.json`؛ `core/network/api_client.dart:27` | — |
| Low | 23 `ElevatedButton` و167 `Colors.` في الشاشة بدل `AppButton` / `AppTheme` | `purchase_orders_screen.dart` (عدّ grep) | توحيد |
