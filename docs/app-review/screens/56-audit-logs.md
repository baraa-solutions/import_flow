# سجل التدقيق والتتبع التاريخي للنظام (System Audit Logs)
![](../screenshots/56-audit-logs-main.png)

> التصوير اتعمل على **Flutter Web (release)**. السجلات اللي ظاهرة اتولّدت من الـ seed على القاعدة الـ scratch (إضافة مقدمي خدمة ESP-0000xx).

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** عرض زمني لعمليات الإضافة والتعديل والحذف والاسترجاع (CREATE / UPDATE / DELETE / RESTORE) على كيانات النظام: مين عمل إيه وإمتى، وملخص التغيير. ومنها تفتح تاريخ الكيان كله (`RowHistoryDialog`).
- **المستخدمين:** الإدارة، والمراجعة الداخلية، ومسؤول النظام.
- **المرحلة:** رقابة عابرة للمراحل (Audit Trail). مالهاش BP/MD code.

## طريقة الوصول والصلاحية
- **Sidebar:** "لوحة القيادة والتقارير والرقابة" ← "سجل التدقيق والرقابة" (index 39).
- **Scaffold:** `Scaffold` + `PageHeader` (عنوان وعنوان فرعي و"العودة للداش بورد").
- **الصلاحية:** أي مستخدم مسجّل. الـ router كله `Depends(get_current_user)` من غير أي دور (`modules/audit_logs/router.py:9`).
- **البيانات:** `GET /api/v1/audit-logs?limit=200` (`audit_logs_provider.dart:26`). الباك إند بيسمح لحد 500 (`router.py:13`).

## مكونات الشاشة

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث في السجلات بكود الكيان، المستخدم، أو تفاصيل التغيير | TextField | لا | — | فلترة محلية (`_getFilteredLogs`، `audit_logs_screen.dart:60`) |
| الكيان | `DropdownButton<String>`: الكل، ImportCompany، Supplier، ExternalServiceProvider، User | لا | — | قايمة ثابتة (`audit_logs_screen.dart:29-34` و `:205-230`) |
| نوع العملية | `DropdownButton<String>`: الكل، CREATE، UPDATE، DELETE، RESTORE | لا | — | ثابت (`:37-42` و `:243-260`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| ⋮ إجراءات إضافية | تصدير Excel، وتصدير PDF، ونسخ TSV (`audit_logs_screen.dart:142-182`) | — | الكل |
| تحديث حي (🔄) | إعادة تحميل | `GET /api/v1/audit-logs?limit=200` | الكل |
| تصدير السجلات (جدول نصوص) | TSV للحافظة (`:292`) | — | الكل |
| شارة الكيان (مثلاً "مقدم الخدمة والبنك #ESP-000042") | نسخ الكود | — | الكل |
| نسخ تفاصيل السجل | نسخ للحافظة | — | الكل |
| تصدير سجل المراجعة (بي دي إف) | `printOrSaveAuditLogPdf` لسجل واحد (`:459`) | — | الكل |
| عرض سجل الكيان الكامل | `RowHistoryDialog` | `GET /api/v1/audit-logs/{entity_type}/{entity_id}` | الكل |
| تم بواسطة: System Admin | نسخ اسم المستخدم | — | الكل |

### الجداول
مفيش DataTable. السجلات **كروت في قائمة** (Timeline). كل كارت فيه: أيقونة العملية، و Badge العملية (إضافة/تعديل/حذف/استرجاع)، والكيان وكوده، والملخص، و"تم بواسطة"، والتاريخ والوقت، وأزرار النسخ والـ PDF والتاريخ الكامل.
- **الفلاتر:** الكيان، ونوع العملية، والبحث. كلها محلية على آخر 200 سجل.
- **الترتيب:** الأحدث الأول (حسب الباك إند). مفيش pagination ولا فلتر بالتاريخ.

### التابات
مفيش تابات.

### الـ Dialogs
`RowHistoryDialog` (`frontend/lib/features/audit_logs/widgets/row_history_dialog.dart`) بيعرض كل تاريخ الكيان. **ما اتصورش**: الشاشة مالهاش زرار إضافة.

### التصدير والطباعة
Excel و PDF للقائمة المفلترة (`exportAuditLogsToExcel`، و `printOrSaveAuditLogsListPdf` في `:177-180`)، و PDF لكل سجل، ونسخ TSV. الحفظ عن طريق `FileSaveHelper`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | سجل التدقيق كله (ومعاه تعديلات المستخدمين والصلاحيات) مفتوح لأي مستخدم مسجّل، ومفيش RBAC | `modules/audit_logs/router.py:9` و `:13` و `:19` | اقصره على ADMIN/MANAGER أو صلاحية `audit.view` |
| Medium | الشاشة بتجيب آخر 200 سجل بس والفلترة كلها محلية، ومفيش pagination ولا فلتر تاريخ. أي عملية أقدم مش هتلاقيها بالبحث | `audit_logs_provider.dart:26`؛ `audit_logs_screen.dart:60` | فلترة و pagination على السيرفر (entity_type، action، from/to، user) |
| Medium | فلتر الكيان فيه 4 أنواع بس مكتوبين في الكود، والباك إند بيسجّل حوالي 23 نوع كيان (منهم `ImportFile` في 20 مكان، و `ShipmentBooking`، و `PaymentRequest`، و `UserPermissions`، و `LandedCostSettlementRecord`...)، فمش هتقدر تفلتر عليهم | `audit_logs_screen.dart:29-34`؛ `grep entity_type= modules/*/service.py` | هات قائمة الأنواع المتاحة من الباك إند (distinct entity_type) |
| Low | الـ label بيظهر "الكيان:: الكل" و "نوع العملية:: الكل" بنقطتين مكررتين، لأن الترجمة نفسها `'الكيان:'` والكود بيزود `': '` | `elements/56-audit-logs-main.json`؛ `audit_logs_screen.dart:217`؛ `core/localization/app_localizations_ar.dart:4987` | شيل `:` من واحد منهم |
| Low | ملخص التغيير بالإنجليزي "Created new ExternalServiceProvider record" وسط واجهة عربية، والنص ده بيتولّد في الباك إند | `56-audit-logs-main.png`؛ `modules/audit_logs/service.py:29` | خزّن كود العملية وترجمه في الواجهة |
| Low | الفلاتر `DropdownButton` عادي | `audit_logs_screen.dart:205` و `:243` | `SearchableDropdownField` |
| Low | عنوان الهيدر لازق في الحافة العليا ومقصوص شوية (نفس مشكلة المهام الذكية) | `56-audit-logs-main.png` | راجع ارتفاع `PageHeader` مع العنوان الفرعي |
