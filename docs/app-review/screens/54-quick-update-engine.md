# محرك تحديث الشحنات التشغيلي واليومي (Quick Update Engine)
![](../screenshots/54-quick-update-engine-main.png)

> التصوير اتعمل على **Flutter Web (release)**. الشاشة بتختار أول ملف تلقائياً (هنا FILE-2026-0006)، والصورة اتاخدت وجدول التحديثات لسه بيحمّل (spinner). جرد العناصر اتاخد بعدها بشوية، وفيه "لا توجد تحديثات تشغيلية مسجلة لهذه الشحنة حتى الآن".

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** نقطة واحدة تسجّل منها **تحديث يومي** لشحنة (ملاحظة، ومرحلة مستهدفة، وتعديل تكلفة، ومستخدم مسؤول)، وتشوف:
  - شريط **فحص المراحل** (10 مراحل من Phase 1 لـ Phase 10)، ولكل مرحلة حالتها (منتهية / جارية / مستقبلية) وعدد التحديثات بتاعتها.
  - **سجل ونتائج دراسة الاستشارة الجمركية والفحص المستندي** للملف، ومنه تعرض قائمة الفحص، أو تعدّل حالة المستندات، أو تطبع.
  - **جدول التحديثات** للملف، مع العمليات والتصدير.
- **المستخدمين:** مسؤولي التشغيل والمتابعة اليومية.
- **المرحلة:** متابعة عابرة للمراحل. مالهاش BP/MD code في `inventory.json`.

## طريقة الوصول والصلاحية
- **Sidebar:** "لوحة القيادة والتقارير والرقابة" ← "محرك التحديث السريع" (index 42).
- **Scaffold:** `Scaffold` بهيدر مخصص: العنوان، و"العودة للداش بورد"، وتحديث.
- **الصلاحية:** أي مستخدم مسجّل (`modules/shipment_updates/router.py:19` بـ `Depends(get_current_user)`).
- **تحميل البيانات:** `initState` بيجيب الملفات، ويختار أول ملف، ويجيب تحديثاته (`shipment_update_engine_screen.dart:146-160`).

## مكونات الشاشة

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختر الشحنة لتشغيل محرك التحديث والفحص المرحلي | `SearchableDropdownField<int>` | لا | — | `GET /api/v1/import-files`. الـ label: كود الملف (IMP)، والمورد، و`current_module` (`:231`) |
| حالة المستند (جوه قائمة فحص الاستشارة) | `DropdownButton<String>`: Approved / Pending / Received / Verified / Rejected | لا | — | ثابت (`:1200-1209`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| العودة للداش بورد / تحديث | رجوع، أو إعادة تحميل | `GET /api/v1/shipment-updates?import_file_id=`، و `GET /api/v1/shipment-updates/inspect/{id}` | الكل |
| تحديث يومي شامل عن الشحنة | `ShipmentUpdateDialog` للملف المختار. بيتقفل لو مفيش ملف (`:249-261`) | `POST /api/v1/shipment-updates` | الكل |
| تصدير جدول نصوص / تصدير إكسيل / طباعة بي دي إف (فوق) | TSV للحافظة، و `exportShipmentUpdatesToExcel`، و `printOrSaveShipmentUpdatesListPdf`. **مقفولين** طول ما مفيش تحديثات (`:266-296`) | — | الكل |
| كروت المراحل (Phase 1…Phase 9/10) | عرض الحالة وعدد التحديثات (tooltip) | `GET /shipment-updates/inspect/{id}` | الكل |
| استعراض قائمة الفحص / تعديل المستندات / طباعة | `_showConsultationDetailsDialog` للعرض أو التعديل، وطباعة slip الاستشارة (`:900-930`) | `/api/v1/customs-consultations/*` | الكل |
| تسجيل تحديث يومي (من كارت الاستشارة) | `ShipmentUpdateDialog` بمرحلة Phase 6 (`:942`) | `POST /api/v1/shipment-updates` | الكل |
| شريط "عمليات البيانات والتصدير/الاستيراد": إعادة تحميل حية، تصدير Excel، تصدير PDF، استيراد Excel | `MasterDataToolbarWidget` (`:454`) | endpoints الـ toolbar المشتركة | الكل |
| إجراءات الصف: عرض / تعديل / طباعة slip / حذف | الحذف فيه تأكيد (`:542-561`) وهو soft delete | `PUT/DELETE /api/v1/shipment-updates/{updateId}` | الكل |

### مكونات العرض (من الصورة)
- **رأس شريط الفحص:** كود الملف (FILE-2026-0006) وشارة بنفس الكود، وعلى الطرف التاني الـ `current_module` بالأخضر ("BP-019 Prepare Customs Declaration 46").
- **كروت المراحل:** كل كارت فيه أيقونة وحالة ("مستقبلية" / "جارية" / "منتهية") واسم المرحلة وسطر "التحديثات: N سجلات". الكروت أعرض من الكارت الأب فبتتقص (Phase 9 مقصوص وPhase 10 مش باين)، والصف بيتعمله scroll أفقي.
- **كارت الاستشارة الجمركية:** لو مفيش دراسة، بيظهر chip "لا توجد دراسة مسجلة" وصندوق معلومات أزرق: "لم يتم حفظ دراسة استشارة جمركية بعد لملف هذه الشحنة. يمكنك فتح مركز الاستشارة الجمركية…" (الحالة اللي في الصورة).
- **حالة الجدول الفاضي:** "لا توجد تحديثات تشغيلية مسجلة لهذه الشحنة حتى الآن." (في جرد العناصر؛ الصورة لسه فيها spinner).

### الجداول
**جدول التحديثات** (`:487-494`):
| العمود | المعنى |
|---|---|
| الإجراءات | عرض / تعديل / طباعة / حذف |
| الكود | كود التحديث |
| التاريخ | تاريخ التسجيل |
| النوع | نوع التحديث |
| المرحلة المستهدفة | Phase X |
| الملاحظات | نص التحديث |
| تعديل التكلفة | البند والقيمة القديمة والجديدة |
| المستخدم المسؤول | assigned user |

- **الفلاتر:** الملف المختار بس.
- **الترتيب:** حسب الباك إند.

### التابات
مفيش تابات.

### الـ Dialogs
`ShipmentUpdateDialog`، و dialog الاستشارة (inline)، وتأكيد الحذف. **ما اتصورتش**: الـ harness ما لقاش زرار إضافة بالاسم المتوقع.

### التصدير والطباعة
TSV و Excel و PDF للقائمة، و PDF slip لكل تحديث (`:538`)، و PDF لقائمة فحص الاستشارة (`Printing.layoutPdf` في `:903`). وكمان تصدير/استيراد من `MasterDataToolbarWidget`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | **مرحلة نفس الملف مختلفة بين الشاشات.** FILE-2026-0006 في لوحة المراحل "File Archive & Close" (الخطوة الأخيرة)، وهنا في قائمة الاختيار "BP-019 Prepare Customs Declaration 46"، وشريط الفحص بيعلّم Phase 1 إنها "جارية". الـ `current_module` بيتحسب بمعادلة منفصلة في `import_files/service.py` بدل ما يتقرا من محرك دورة الحياة | `51-lifecycle-board-main.png` (الصف FILE-2026-0006)؛ `elements/54-quick-update-engine-main.json` (`buttons[55]`: label "جارية" و tooltip "Phase 1: Planning & Studies"؛ الصورة نفسها اتاخدت قبل ما الفحص يخلص فكل الكروت فيها "مستقبلية")؛ `modules/import_files/service.py:200-205` | مصدر واحد للحقيقة: خلّي `current_module/current_stage` يتقروا من `lifecycle_board` |
| Medium | كود BP غلط: الملف اللي فيه رقم 46 بيتوصف "BP-019 Prepare Customs Declaration 46"، مع إن BP-019 هو Confirm Shipment Booking و BP-028 هو Submit Customs Declaration. والـ stage اللي معاه "Phase 3" مش متسق مع Phase 6 (إقرار 46) في نفس الموديول | `modules/import_files/service.py:202-203`؛ `doc.md:1739` و `:1756`؛ `modules/shipment_updates/service.py` (`ALL_PHASES_DEFS`: Phase 6 = إقرار 46) | صحّح الكود لـ BP-028 والمرحلة، وحدّث `tests/unit/test_import_files.py:115` |
| Medium | الشاشة دي شغالة بنموذج **10 مراحل**، ولوحة المراحل بـ **6 مراحل / 25 خطوة**. المستخدم بيشوف ترقيمين مختلفين لنفس الدورة | `54-quick-update-engine-main.png`؛ `shipment_update_engine_screen.dart:37-46`؛ `51-lifecycle-board-main.png` | وحّد نموذج المراحل، أو اعرض mapping واضح بينهم |
| Low | أسماء المراحل بالإنجليزي ("Phase 1: Planning & Studies"…) لأن `_getPhaseName` بياخد اللغة من `Localizations.localeOf(context)`، وده متأثر بمشكلة الـ locale المعروفة | `54-quick-update-engine-main.png`؛ `shipment_update_engine_screen.dart:49-53` | خد اللغة من `localeProvider` |
| Low | صفين تصدير متكررين: أزرار فوق (TSV/Excel/PDF، مقفولة) و `MasterDataToolbarWidget` تحت (Excel/PDF، مفتوحة) لنفس البيانات | `54-quick-update-engine-main.png`؛ `shipment_update_engine_screen.dart:266-296` و `:454` | سيب شريط واحد |
| Low | الحذف soft delete، بس الـ endpoint مش بياخد `current_user`، فمفيش `deleted_by` | `modules/shipment_updates/router.py:91` | سجّل المستخدم اللي حذف |
| Low | حالة المستند في قائمة الفحص `DropdownButton` بقيم ثابتة | `shipment_update_engine_screen.dart:1200` | مقبول كـ enum، بس الأحسن يبقى موحّد مع `SearchableDropdownField` |
