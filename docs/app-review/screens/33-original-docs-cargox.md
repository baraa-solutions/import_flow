# أصول المستندات ومنظومة CargoX الرقمية (Original Docs & CargoX Hub)
![](../screenshots/33-original-docs-cargox-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
شاشة مستقلة للمرحلة 4 بتجمع وظيفتين:
1. **تحصيل أصول المستندات وتتبع الكورير:** بتستدعي المستندات المطلوبة من الأرشيف المركزي للشحنة تلقائي، وبتتابع طرود البريد السريع (لو فيه أكتر من طرد)، وبتدقق استلام الأصول الورقية مستند مستند (استلام، ثم تحقق).
2. **منظومة CargoX والمانيفست الرقمي:** دي شاشة `CargoXHubScreen` متضمّنة جوه الشاشة دي، وشرحها التفصيلي في `34-cargox-hub.md`.

- **المستخدمين:** موظف التوثيق، وقسم البنوك (استلام الأصول)، والمخلص.
- **المرحلة:** المرحلة 4 (`stageCode: 'PHASE-4'`، `original_docs_and_cargox_screen.dart:108`). العنوان: "Original Docs Collection & CargoX Hub — Phase 4"، والـ badge "CargoX & Banking".
- **الكود:** `BP-023` (Collect Original Shipping Documents) و `BP-024` (CargoX Integration).

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 4: التوثيق الرقمي والاعتماد البنكي" ← "أصول المستندات ومنظومة CargoX الرقمية" (index 54). بتفتح على تاب CargoX (subTab 1)، ولازم تدوس التاب الرأسي الأول عشان تروح لتحصيل الأصول. الـ indices 57 و 58 ملهمش عنصر في الـ sidebar.
- **الصلاحية:** أي مستخدم عامل login (`modules/original_documents_collection/router.py:20-23`، `Depends(get_current_user)`)، ومفيش RBAC على تأكيد الاستلام.

## مكونات الشاشة
`VerticalStageScaffold` بلون `AppTheme.crimson`، ومغلفة بـ `SelectionArea`. فيها تابين رأسيين، والتاني جنبه badge بعدد مستندات الشحنة.

### الحقول
تاب "تحصيل أصول المستندات وتتبع الكورير" (`33-original-docs-cargox-tab-1-original-docs-collection-courier.png`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختيار ملف الشحنة | `SearchableDropdownField` | نعم للتحصيل | — | `GET /import-files`. في الصورة **فاضي** (ملف الشاشة الأم مش بيوصل للتاب) |
| بحث برقم الكود أو الشحنة... | `TextField` بحث في السجل | لا | — | — |
| فلتر الحالة (جميع الحالات) | dropdown | لا | — | ثابت |
| شركة الكورير (لكل طرد) | `DropdownButtonFormField<String>`، والقايمة مكتوبة ثابتة: DHL، FedEx، Aramex، UPS، Naqel، SMSA، Hand Delivery، Other (`original_documents_collection_tab.dart:675-677`) | — | — | قايمة في الكود |
| رقم البوليصة / التتبع، تاريخ الإرسال، تاريخ الاستلام (لكل طرد) | `TextFormField` | — | — | يدوي |
| حالة كل مستند (مطلوب، مستلم، متحقق منه، ملاحظات) | checkboxes، ومعاهم `DropdownButtonFormField` (`:884`، `:909`) | — | — | تلقائي من الأرشيف (`auto-populate`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة عند هذه المرحلة | دورة حياة الملف | `/import-files/{id}/hold` وغيره | أي مستخدم |
| تحديث (أيقونة في الـ header) | `_refreshData` | `GET /import-files`، `GET /import-documentation/shipment-documents` | — |
| العودة للداش بورد | رجوع | — | — |
| تحديث البيانات (في التاب) | إعادة تحميل الـ sessions والتنبيهات | `GET /api/v1/original-documents-collection/sessions`، `/couriers/alerts`، `/couriers/all` | — |
| اختيار ملف | `_onSelectImportFile` (`:93`)، بيعمل auto-populate للمستندات | `GET /original-documents-collection/auto-populate/{fileId}`، `/sessions/by-file/{fileId}` | — |
| إضافة / حذف طرد كورير، إضافة / حذف مستند | `_addCourier`، `_removeCourier`، `_addCustomDocument`، `_removeDocument` (`:135-169`) | — | — |
| حفظ الجلسة / تأكيد الاكتمال | `_handleSaveSession` (`:175`)، فيه `_isSaving` | `POST /api/v1/original-documents-collection/sessions` | أي مستخدم |
| تأكيد استلام الطرد (إثبات ميعاد الاستلام) | `_showCourierDeliveryProofDialog` (`:1523`) | `POST /original-documents-collection/couriers/confirm-receipt` | أي مستخدم |
| تصدير جدول مجدول / تصدير إكسيل / طباعة تقرير مصدق / نسخ ملف البيانات | بيبقوا disabled لو مفيش بيانات. `OriginalDocsExportService` (`:1258`، `:1919`) | Client، ومنه لـ `FileSaveHelper`، و `GET /original-documents-collection/export/excel/{id}` | — |
| سجل جلسات تحصيل المستندات / سجل تتبع الكورير وإثبات ميعاد الاستلام | تبديل بين السجلين | — | — |

ملحوظة: التاب الرأسي التاني "CargoX Blockchain & ACI Hub" فيه شريط أفقي "منظومة كارجو إكس والبلوك تشين" بأربع مراحل (الفاتورة المعيارية، تجهيز المظروف، تتبع البلوك تشين، المانيفست الرقمي)، وجوه مرحلة الفاتورة كروت "تحميل نموذج إكسيل الموحد" و "رفع وقراءة فاتورة المورد" وقايمة رأسية (بيانات الفاتورة المستخرجة، مصفوفة المطابقة والفروق، الاعتماد والتحكم الجمركي، سجل الفواتير المعيارية، المسارات الجمركية). ده كله متشرح في `34-cargox-hub.md`.

### الجداول
- **سجل جلسات تحصيل أصول المستندات:** كان فاضي، وظاهر "لا توجد جلسات تحصيل مسجلة بعد."
- **سجل تتبع الكورير:** طرود كل الجلسات مع التنبيهات (`couriers/all`، `couriers/alerts`). متصورش.
- **جدول المستندات في الجلسة:** التصنيف، اسم المستند، إلزامي، الطرف المسؤول، رقم الكورير، مستلم، تاريخ الاستلام، متحقق منه، المتحقق، الحالة، ملاحظات (حسب بنية `original_documents_collection/model.py:44`).

### التابات
1. **Original Docs Collection & Courier:** `33-original-docs-cargox-tab-1-original-docs-collection-courier.png`.
2. **CargoX Blockchain & ACI Hub:** `33-original-docs-cargox-tab-2-cargox-blockchain-aci-hub.png`، وهي نفسها `33-original-docs-cargox-main.png`. الشرح في `34-cargox-hub.md`.

### الـ Dialogs
مفيش dialog إضافة (`capture-manifest.json`: "no add/create button found")، فمفيش صورة validation. الـ dialogs اللي في الكود: `_showCourierDeliveryProofDialog` (`:1523`)، و `OriginalDocumentsCollectionDialog` (`widgets/original_documents_collection_dialog.dart`). ولا واحد فيهم اتصور.

### التصدير والطباعة
Excel للمستندات وللسجل (`OriginalDocsExportService.exportDocumentsExcel` / `exportRegistryExcel`)، و "طباعة تقرير مصدق" (PDF)، ونسخ TSV. كله عن طريق `FileSaveHelper` (`services/original_docs_export_service.dart`).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | لما مستند يتعلّم عليه "متحقق منه" من غير اسم متحقق، الاسم بيتحط تلقائي `'Kamal'` مكتوب ثابت في الكود. سجل التحقق (Audit) بيبقى مزيف ومش مربوط بالمستخدم الحالي | `original_documents_collection_tab.dart:1022-1024` | `verifiedBy = currentUser.username`، والـ backend يسجل `updated_by` من الـ token |
| Medium | ملف الشحنة مش بيوصل للتاب. `OriginalDocumentsCollectionTab` بيقرا `initialImportFileId` في `initState` بس، ومعندوش `didUpdateWidget`، والشاشة الأم بتحدد الملف بعد ما الـ fetch يخلص. النتيجة إن الـ dropdown فاضي | `33-original-docs-cargox-tab-1-original-docs-collection-courier.png`، `original_documents_collection_tab.dart:68-70`، `original_docs_and_cargox_screen.dart:59-67` | إضافة `didUpdateWidget` |
| Medium | 3 استخدامات لـ `DropdownButtonFormField`، وشركات الكورير قايمة ثابتة في الكود بدل Master Data | `original_documents_collection_tab.dart:675`، `:884`، `:909` | `SearchableDropdownField`، وجدول مزودي خدمة من نوع Courier |
| Medium | شريط أزرار التصدير مقصوص من الناحية اليمين: زرار "طباعة تقرير مصدق" حافته مقطوعة عند حد الكارت (overflow أفقي) | `33-original-docs-cargox-tab-1-original-docs-collection-courier.png` (أقصى يمين الشريط) | `Wrap` بدل `Row` |
| Medium | مخالفات UI: 45 `Color(0x…)`، و 79 `Colors.xxx`، و 16 `ElevatedButton` في التاب. ولون الـ header `AppTheme.crimson`، وده لون الخطر، والمعيار charcoal أو cobalt | `original_documents_collection_tab.dart:1264-1265` (`Color(0xFF27AE60)`)، `original_docs_and_cargox_screen.dart:112` | `AppTheme.emerald`، ولون header قياسي |
| Low | عنوان الـ header طويل وبيلف لسطرين ("… — Phase" وتحتها "4")، ومكتوب بالإنجليزي. والتابات الرأسية وعنوان "Operations & Stages" بالإنجليزي. ده من مشكلة الـ locale المعروفة | `33-original-docs-cargox-tab-1-original-docs-collection-courier.png` | عنوان أقصر، و `supportedLocales` |
