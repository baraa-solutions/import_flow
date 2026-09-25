# ملفات الشحنات الاستيرادية (Import Files)
![](../screenshots/10-import-files-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)

- **الكود:** `BP-001` (نقطة بداية دورة الاستيراد، `docs/phase_01_import_planning.md`). ملف الاستيراد هو الكيان المركزي اللي كل المراحل بعد كده بتتربط بيه.
- **الغرض:** قائمة كل ملفات الشحنات الاستيرادية (Type B — List Screen، وهي نفسها الشاشة المرجعية لـ Type B في `.agents/skills/ui-screen-standards/SKILL.md`). منها بتفتح ملف جديد، وتعدّل، وتستنسخ، وتوقف أو تعيد فتح شحنة، وتتخطى مرحلة، وتطلب أسعار نولون، وتفتح قائمة التحقق الذكية وتفاصيل الملف.
- **المستخدمين:** مسؤول الاستيراد / مدير الشحنات. التفاصيل (`ImportFileDetailsDialog`) هي البوابة لشاشات المراحل (مصفوفة المستندات DC-04، رادار الغرامات TR-02، استلام المخزن TR-03).
- **المرحلة:** المرحلة 1 (التخطيط)، لكن الشاشة بتعرض الملفات في كل المراحل (عمود المرحلة الحالية والتقدم).

## طريقة الوصول والصلاحية

- **الوصول:** من الـ sidebar: "تخطيط الشحنة وأوامر الشراء" ← "ملفات الشحنات الاستيرادية" (navigation index 1).
- **الصلاحية (Backend RBAC)** في `modules/import_files/router.py`:
  - `import_files.view`: القائمة، و`/paginated`، و`/report/master`، و`/operational-dashboard`، و`/export-excel`، و`/export-pdf`، و`/{id}`، و`/{id}/freight-rfq`.
  - `import_files.create`: `POST ""` (سطر 34-43) و`POST /{id}/clone` (سطر 410-420).
  - `import_files.edit`: `PUT` و`DELETE /{id}` و`/hold` و`/resume`.
  - `import_files.close`: `/close-shipment` و`/reopen-shipment`.
- **تحميل البيانات:** الشاشة بتنادي `paginatedImportFilesProvider.fetchPage(1)` و`importFilesProvider.fetchImportFiles()` لما تفتح (`import_files_screen.dart:124-129`)، ومعاهم الشركات وأوامر الشراء والسيناريوهات (`:1098-1110`).

## مكونات الشاشة

### الحقول

**شريط الأدوات:**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث بكود الشحنة أو الشركة... | Text | لا | — | فلترة على صفحة الـ paginated (`import_files_screen.dart:2421`) |
| جميع الحالات | `SearchableDropdownField` (All / Open / In Progress / Closed) | لا | — | قيم ثابتة (`:2365-2368`) |

**Dialog إضافة ملف استيراد (`ImportFileFormDialog`، `widgets/import_file_form_dialog.dart`):**

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| رقم ملف الاستيراد | Text | نعم (`*`) | مش فاضي. **رسالة الخطأ هي اسم الحقل نفسه** (`:525` بيرجع `l.importFileIdLabel`) | إدخال يدوي → `custom_file_number` |
| الشركة المستوردة | `SearchableDropdownField` | نعم | مش في الـ Form validator. بيتفحص في `_submit` ويظهر SnackBar (`:279-281`) | `GET /api/v1/import-companies` |
| المورد الأجنبي | `SearchableDropdownField` | نعم | SnackBar من `_submit` (`:283-285`) | `GET /api/v1/suppliers` |
| المخلص الجمركي | `SearchableDropdownField` | لا | — | `GET /api/v1/external-service-providers` |
| أمر الشراء: | **TextFormField حر** | نعم (`*` في الـ label) | **مفيش validator** (`:617-620`) | إدخال نصي → `po_number` |
| أمر الشراء / الفاتورة | **TextFormField حر** | نعم (`*`) | **مفيش validator** (`:624-627`) | إدخال نصي → `pi_number` |
| بند التعريفة الجمركية | Text + زرار بحث | لا | — | جدول التعريفة `GET /api/v1/customs-tariff` |
| تصنيف الصنف | Text + زرار "فحص توجيهات الخبرة لهذا الصنف" | لا | — | `experience-guide` |
| عدد الفواتير وأرقامها / + أمر الشراء / الفاتورة / + قوائم تعبئة | Chips إضافة فواتير وقوائم تعبئة | لا | — | `invoices_data` |
| وسيلة النقل / الشروط | `SearchableDropdownField` (القيمة الافتراضية Sea FCL) | نعم | — | قيم ثابتة |
| الشروط التجارية الدولية | `SearchableDropdownField` (FOB) | نعم | — | `GET /api/v1/incoterms` |
| الأولوية | `SearchableDropdownField` (High) | نعم | — | قيم ثابتة |
| تصنيف الشحنة | `SearchableDropdownField` (New Purchase) | نعم | — | قيم ثابتة |
| الوصول المتوقع (ETA) / تاريخ فتح الملف | Date | نعم | — | افتراضي: النهارده + 30 / النهارده |
| المرحلة الحالية | `SearchableDropdownField` (Freight Studies) | نعم | — | قائمة المراحل |
| ميناء الشحن (POL) / ميناء الوصول (POD) | `SearchableDropdownField` | لا | — | `GET /api/v1/transport-locations` |
| تاريخ جاهزية البضاعة (CRD) | Date | لا | — | — |
| أيام السماح المطلوبة (FT)، تفضيل مسار الخدمة، عنوان الاستلام / المصنع، تعليمات واشتراطات الشحن | Text / Dropdown | لا | — | بيانات طلب النولون |
| إسناد الشحنة للمشاريع | `SearchableDropdownField` متعدد | لا | — | `GET /api/v1/projects` |

### الأزرار والإجراءات

| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| رفع وثيقة ملف استيراد (PDF / Word / Excel) | `SmartUploadButton` لاستخراج بيانات من مستند، وبيظهر SnackBar بالنتيجة بس (`:1290-1305`) | `POST /api/v1/smart-upload/upload` | مستخدم مسجل |
| العودة للداش بورد | رجوع للوحة التحكم | — | — |
| 🔄 (في الهيدر) | إعادة تحميل | `GET /api/v1/import-files/paginated` | `import_files.view` |
| إضافة ملف استيراد شحنة جديد | يفتح `ImportFileFormDialog` | `POST /api/v1/import-files` | `import_files.create` |
| بحث واستنساخ شحنة | Dialog بحث عن ملف قديم واستنساخه | `POST /api/v1/import-files/{id}/clone` | `import_files.create` |
| إجراءات إضافية ⋮ | منيو فيها: التقرير الشامل (`_showMasterReportDialog`)، واستخراج الفاتورة/البوليصة الذكي، ومحاكي What-If وغيرهم (`:2470-2560`) | `/report/master` وغيره | `import_files.view` |
| 🔄 / 📗 / 📕 (شريط صغير) | تحديث، وتصدير Excel، وتصدير PDF للقائمة (`:2618-2640`) | في الـ client عبر `TableExportService` ← `FileSaveHelper.exportAndSaveFile` | — |
| **في كل صف:** إغلاق وإيقاف الشحنة (⊗) | `StopShipmentDialog` | `POST /{id}/close-shipment` | `import_files.close` |
| طلب أسعار نولون الشحن (✉) | `FreightRfqDialog` | `GET /{id}/freight-rfq` | `import_files.view` |
| تخطي المرحلة (⏩) | تخطي المرحلة الحالية | `PUT /{id}` | `import_files.edit` |
| استنساخ ملف شحنة استيراد (⊕) | `CloneEntityReviewDialog` | `POST /{id}/clone` | `import_files.create` |
| قائمة التحقق التشغيلية الذكية | `SmartChecklistDialog` | `GET /{id}/checklist` و`/auto-sync` و`/toggle` | مستخدم مسجل |
| عرض التفاصيل (👁) / تعديل السجل (✏) / استنساخ السطر (Ctrl+D) / طباعة وتصدير PDF / حذف - إيقاف التفعيل | تفاصيل، تعديل، نسخة، PDF، soft delete | `GET` / `PUT` / `POST clone` / — / `DELETE /{id}` | view / edit / create / — / edit |
| رابط كود الملف (FILE-2026-000x) | يفتح التفاصيل | — | — |
| ترقيم الصفحات (الأولى / السابقة / التالية / الأخيرة) | تنقل بين الصفحات | `/paginated?page=` | view |

**أزرار الـ Dialog:** إعادة تحميل حية، وتفريغ وبدء تسجيل جديد، وحفظ مؤقت، وإلغاء، وحفظ. وفي رأس الـ dialog زرار ✕ "إغلاق وتراجع" بيقفل من غير حفظ (`elements/10-import-files-dialog-add.json`).

### الجداول

- **الجدول الرئيسي** (`:1407-1419`): Checkbox، والإجراءات، ورقم ملف الاستيراد (رابط + الكود الداخلي)، والشركة المستوردة، وأمر الشراء / الفاتورة (رقم أمر الشراء + الفاتورة المبدئية)، والمورد الأجنبي، ووسيلة النقل / الشروط (مثلاً `Sea FCL (CFR)`)، والأولوية، والوصول المتوقع، والمرحلة الحالية، ونسبة التقدم، والإجراء التالي، والمسؤول، والحالة.
- على 1600px بيبان أول 7 أعمدة بس، والباقي محتاج scroll أفقي (عمود "الأولوية" مقصوص في `10-import-files-main.png`).
- **فلاتر:** بحث نصي + فلتر حالة. **الترتيب:** حسب الباك إند (الأحدث الأول).
- **ترقيم صفحات** تحت الجدول (`1 - 6 / 6`).
- **جدول التقرير الشامل** (جوه `_showMasterReportDialog`، `:648-668`): 21 عمود (المسؤول، والملف، والمورد، والمشاريع، والفاتورة، والنقل، والـ Incoterm، والتكلفة، والـ ETA، والميناء، والمخزن، وغيرهم).

### التابات

مفيش تابات في الشاشة.

### الـ Dialogs

- **إضافة ملف استيراد شحنة جديد:** `10-import-files-dialog-add.png`. فيه الحقول اللي فوق. شريط الأزرار تحت: إعادة تحميل حية، وتفريغ وبدء تسجيل جديد، وحفظ مؤقت، وإلغاء، وحفظ.
- **أخطاء الـ validation:** `10-import-files-dialog-add-validation.png`. بعد الحفظ والفورم فاضي بيظهر خطأ واحد بس تحت "رقم ملف الاستيراد"، ونصه هو اسم الحقل ("رقم ملف الاستيراد") مش رسالة مفهومة. الشركة والمورد وأمر الشراء متعلّمين `*` ومفيش عليهم خطأ inline.
- Dialogs تانية من الكود (متصورتش): `ImportFileDetailsDialog`، و`FreightRfqDialog`، و`SmartChecklistDialog`، و`StopShipmentDialog` / `ReopenShipmentDialog`، و`CloneEntityReviewDialog`، و`VisualContainerLoadPlannerDialog`، والتقرير الشامل.

### التصدير والطباعة

- 📗 Excel و📕 PDF للقائمة: `TableExportService.exportTableToExcel/Pdf` ← `FileSaveHelper.exportAndSaveFile` (`import_files_screen.dart:502, 551`).
- التقرير الشامل: نسخ للحافظة (`:359`)، وتنزيل CSV عبر `FileSaveHelper.saveText` باسم `Reports_Import_Files_Master_Summary_<timestamp>.csv` (`:1013-1021`).
- طباعة PDF لكل صف من منيو الصف.
- في الباك إند فيه كمان `GET /export-excel` و`GET /export-pdf` (`router.py:185, 230`).

## ملاحظات المراجعة

| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | التقرير الشامل بيعرض ويصدّر **بيانات وهمية ثابتة** بدل الفاضي: تواريخ `'31-8-2026'` و`'10-8-2026'` و`'X'` ثابتة لكل الصفوف، وقيم fallback زي `'Main Site Building'` و`'MSC / COCOS'` و`'Vertex'` و`'ACID-19876543210987'` و`'FORM4-2026-001'` و`'DEC46-2026-001'`. والـ CSV بيحط قيمة فاتورة `24500.0` لو مفيش فواتير | `frontend/lib/features/import_files/screens/import_files_screen.dart:705-733`، و`:302`، و`:308`، و`:1011` | اعرض `—` للقيم الناقصة وشيل كل الثوابت التجريبية. رقم ACID ممنوع يتولّد |
| High | "أمر الشراء" و"أمر الشراء / الفاتورة" نص حر متعلّم إلزامي (`*`) ومن غير validator. ده غير إنه مش مربوط بجدول أوامر الشراء، والنتيجة إن عمود "ملف الاستيراد" في شاشة أوامر الشراء بيطلع `-` لكل الأوامر مع إن الملفات بتذكر أرقامها | `widgets/import_file_form_dialog.dart:617-627`؛ `10-import-files-main.png` مقابل `11-purchase-orders-main.png` | استخدم `SearchableDropdownField` على `/api/v1/purchase-orders` واحفظ `po_id` كـ FK |
| Medium | رسالة الـ validation هي اسم الحقل ("رقم ملف الاستيراد")، ونفس الحكاية في حقل التكلفة | `import_file_form_dialog.dart:525`، و`:1197`؛ `10-import-files-dialog-add-validation.png` | استخدم رسالة "هذا الحقل مطلوب" (`l.requiredField`) |
| Medium | الشركة والمورد بيتفحصوا بـ SnackBar بعد الـ validate، وواحد واحد، مش inline تحت الحقل. في الصورة ظهر خطأ حقل واحد بس رغم إن حقول إلزامية كتير فاضية | `import_file_form_dialog.dart:279-285`؛ `10-import-files-dialog-add-validation.png` | خلّي كل الحقول الإلزامية جوه `Form` بـ validator |
| Medium | زرار "حفظ مؤقت" بينادي نفس `_submit` بتاع "حفظ"، فمفيش حفظ draft حقيقي | `import_file_form_dialog.dart:1306` و`:1322` | اعمل مسار draft بـ validation أخف (أو شيل الزرار) |
| Medium | "تفريغ وبدء تسجيل جديد" بيفضّي الشركة والمورد والمخلص والأرقام والملاحظات بس. الموانئ والتواريخ والمشاريع والفواتير بيفضلوا زي ما هم | `import_file_form_dialog.dart:1283-1293` | امسح الفورم كله، أو اعمل إعادة إنشاء للـ state |
| Medium | الهيدر فيه 3 إجراءات (رفع وثيقة + العودة + 🔄)، والـ 🔄 جه **بعد** "العودة للداش بورد" (Type B: بحد أقصى 2، والعودة لازم تبقى الأخيرة) | `import_files_screen.dart:1290-1308`؛ `10-import-files-main.png` | انقل رفع الوثيقة لـ ⋮ و🔄 لشريط الأدوات |
| Medium | 10 أيقونات إجراء في كل صف، وفيهم زرارين استنساخ مختلفين ("استنساخ ملف شحنة استيراد" و"استنساخ السطر Ctrl+D") | `elements/10-import-files-main.json`؛ `10-import-files-main.png` | ادمج الاستنساخ وحط الباقي في منيو ⋮ للصف |
| Medium | الجدول أعرض من الشاشة: 7 أعمدة بس ظاهرة على 1600px و"الأولوية" مقصوص. ده بيخالف قاعدة الـ Sticky Actions + Responsive | `10-import-files-main.png` | ثبّت عمود الإجراءات وقلّل الأعمدة الافتراضية |
| Low | tooltip زرار التخطي بيخلط لغات أسماء المراحل: "Phase 3: Import Documentation & ACI" و"Phase 2 - Shipment Initiation" جنب "تأكيد الحجز الملاحي" | `elements/10-import-files-main.json` (أزرار "تخطي المرحلة: ...") | ترجم أسماء المراحل من `DisplayNameResolver` |
| Low | tooltips ثابتة بالعربي `'تصدير إكسل (Excel)'` و`'تصدير بي دي إف (PDF)'`، ونص بيتحدد بـ `Localizations.localeOf` (الـ bug المعروف بتاع الـ locale) | `import_files_screen.dart:2626`، و`:2634`، و`:458` | استخدم `context.l10n` |
| Low | تصدير التقرير الشامل CSV بيسمح بامتداد `xlsx` مع إن المحتوى CSV، واسم الملف مش على المعيار `[Stage] - [File]` | `import_files_screen.dart:1013-1021` | `allowedExtensions: ['csv']` واسم قياسي |
| Low | ternary ملوش لازمة: `widget.fileToEdit != null ? l.save : l.save` | `import_file_form_dialog.dart:1324` | زرار "حفظ التعديلات" في وضع التعديل |
| Low | Console: `Refused to set unsafe header "Accept-Encoding"` (4 مرات). ده **فرق Web بس**: dio بيبعت `Accept-Encoding: gzip` والمتصفح بيرفضه | `runtime-errors.json` (10-import-files)؛ `frontend/lib/core/network/api_client.dart:27` | متبعتش الـ header لما `kIsWeb` |
| Low | أزرار كتير `ElevatedButton`/`OutlinedButton` وألوان `Colors.*` / `Color(0x..)` بدل `AppButton` / `AppTheme` (87 `Colors.` و15 `Color(0x` في الشاشة) | `import_files_screen.dart` (مثلاً `:2611`، و`:2629`)؛ `import_file_form_dialog.dart:1295-1325` | انقلها لـ `AppButton` |
