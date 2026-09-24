# مركز اعتماد المستندات وتعديلات المورد (Docs Customs Approval Hub)
![](../screenshots/29-docs-customs-approval-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
دي البوابة النهائية للمرحلة 3. الشاشة بتولّد قايمة قياسية بالمستندات المطلوبة للملف، وتعمل فحص متقاطع ذكي بين المستندات، وبعدين كل مستند بياخد اعتماد ثنائي: اعتماد تجاري من إدارة الاستيراد، واعتماد جمركي من المخلص. أي فرق بيتحول لـ "تذكرة استدراك" بتروح للمورد وبتتقفل لما التعديل يوصل. ومعاها عرض للأرشيف المركزي وملخص إخطارات التعديل.

- **المستخدمين:** مسؤول الاستيراد (المراجع التجاري)، والمخلص الجمركي، ومتابعة الموردين.
- **المرحلة:** المرحلة 3، الخطوة 6 (`stageCode: 'STEP_09'`، `docs_customs_approval_screen.dart:92`). الـ badge الظاهر: "Final Approval".
- **الكود:** `BP-026` (Review Final Shipment Documents). اسم الـ router في الكود "DCA-001" (`modules/docs_customs_approval/router.py:28`).

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 3" ← "6. مركز اعتماد المستندات وتعديلات المورد" (index 20). وكمان تاب رقم 1 في مصفوفة DC-04 (شاشة 31).
- **الصلاحية:** أي مستخدم عامل login (`router.py:28`، `dependencies=[Depends(get_current_user)]`). المراجعة التجارية والجمركية بتاخد اسم المراجع (`reviewer_name`) كنص من الـ dialog، مش من المستخدم اللي عامل login (`customs_document_approval_tab.dart:1436`، `:1596`).

## مكونات الشاشة
الغلاف `DedicatedStageScaffold` بلون `AppTheme.cobalt`. المحتوى `CustomsDocumentApprovalTab` (1908 سطر)، وفيه شريط أدوات، وزرين تبديل للعرض، ولوحتين جنب بعض.

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| ملف الشحنة المستوردة | `SearchableDropdownField<int>` (`customs_document_approval_tab.dart:601`) | عملياً نعم | لو فاضي، أي إجراء بيطلع SnackBar تحذير (`:115-120`، `:233-237`) | `GET /import-files`. في الصورة **فاضي** رغم إن الشاشة الأم بتختار أول ملف |
| فلتر "الكل" | قايمة فلترة للحالة | لا | — | ثابتة |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تخطي المرحلة / إيقاف الشحنة | دورة حياة الملف | `/import-files/{id}/hold` وغيره | أي مستخدم |
| بحث واستنساخ اعتماد مستندات سابق (Ctrl+D) | `SearchAndCloneCustomsApprovalDialog` | `GET /docs-customs-approval` | — |
| توليد وميكنة المخاطبات والخطابات الرسمية | `FormalLetterGeneratorDialog` | `POST /formal-letters/generate` | — |
| تحديث / العودة للداش بورد | — | `GET /import-files` | — |
| فحص متقاطع ذكي | `_handleRunMatrixCheck` (`:81`)، فيه `_isRunningMatrixCheck` | `POST /api/v1/docs-customs-approval/matrix-check/{fileId}` | — |
| توليد القائمة القياسية | `_handleAutoGenerate` (`:114`)، **من غير loading state** (`:638`) | `POST /api/v1/docs-customs-approval/auto-generate/{fileId}` | — |
| تذكرة استدراك للمورد، و "+ تذكرة جديدة" | `_showRaiseTicketDialog` (`:232`) | `POST /api/v1/docs-customs-approval/tickets` | — |
| مصفوفة الاعتماد الثنائي والفحص المتقاطع / الأرشيف المركزي وملخص إخطارات التعديل | تبديل العرض. التاني بيضمّن `CentralDocsArchiveScreen` (`:832`) | `GET /import-documentation/central-archive/{fileId}` | — |
| نسخ / Excel / PDF (أيقونات للمصفوفة وللتذاكر، الـ tooltips: "نسخ الجدول كـ TSV" و "نسخ التذاكر كـ TSV" وأزرار Excel و PDF) | بتبقى disabled لو القايمة فاضية | Client، ومنه لـ `TableExportService` ثم `FileSaveHelper` | — |
| تحديث (أيقونة في لوحة المصفوفة) | `_refresh` | `GET /docs-customs-approval`، `/tickets/list` | — |
| مراجعة تجارية (لكل مستند) | `_CommercialReviewDialog` | `POST /api/v1/docs-customs-approval/{id}/commercial-review` | أي مستخدم |
| مراجعة المخلص (لكل مستند) | `_CustomsBrokerReviewDialog` | `POST /api/v1/docs-customs-approval/{id}/customs-review` | أي مستخدم |
| حل التذكرة | `_ResolveTicketDialog` | `POST /api/v1/docs-customs-approval/tickets/{id}/resolve` | أي مستخدم |

### الجداول
- **مصفوفة اعتماد المستندات الجمركية:** الأعمدة، حسب التصدير (`:283-300`): كود الاعتماد، نوع المستند، الرقم المرجعي، الاعتماد التجاري، المراجع التجاري، اعتماد المخلص، المخلص الجمركي، الحالة العامة. في الصورة فاضية: "لا توجد مستندات مسجلة. اضغط 'توليد القائمة القياسية' للبدء."
- **سجل تذاكر الاستدراك والاستفسارات:** كود التذكرة، تصنيف المشكلة، درجة الخطورة، الحالة، الوصف، القيمة المتوقعة، القيمة الفعلية (`:379-395`). في الصورة فاضي: "لا توجد تذاكر استدراك مفتوحة. كافة المستندات متطابقة."

### التابات
مفيش تابات بمعنى التابات. فيه زرين تبديل للعرض: "مصفوفة الاعتماد الثنائي والفحص المتقاطع" (العرض الافتراضي في الصورة)، و "الأرشيف المركزي وملخص إخطارات التعديل" (بيعرض محتوى شاشة 30، ومتصورش).

### الـ Dialogs
- **dialog-add** (`29-docs-customs-approval-dialog-add.png`): الـ harness داس "تذكرة جديدة"، ومفيش dialog اتفتح. الصورة طالعة زي الشاشة الرئيسية بالظبط. السبب إن ملف الشحنة مش متختار، فالكود بيطلع SnackBar تحذير ويرجع (`customs_document_approval_tab.dart:233-237`)، والـ SnackBar متصورش. ولذلك مفيش صورة لأخطاء الـ validation (`capture-manifest.json`: "no save/submit button found").
- **تذكرة استدراك جديدة** (`_RaiseTicketDialog`، `:1630`، من الكود): تصنيف المشكلة (`SearchableDropdownField`: HS Code Mismatch، Weight Discrepancy، CBM Discrepancy، Value Mismatch، Missing ACID، Incoterm Conflict، Other)، ودرجة الخطورة (Critical / Major / Minor)، والوصف * (أقل حاجة 5 حروف)، والقيمة المتوقعة، والقيمة الفعلية، والإجراء المطلوب من المورد.
- **المراجعة التجارية** (`:1321`): اسم المراجع * (validator)، والقرار (`SearchableDropdownField`: Approved / Under Review / Rejected)، والملاحظات. **مراجعة المخلص** (`:1470`) نفس الحقول. **حل التذكرة** (`:1794`). كل الـ dialogs دي فيها `_isSubmitting`.

### التصدير والطباعة
Excel و PDF و TSV للمصفوفة (`:283`، `:316`) وللتذاكر (`:379`، `:410`)، عن طريق `TableExportService` وبعده `FileSaveHelper`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | الاعتماد الثنائي (التجاري والجمركي) بياخد اسم المراجع كنص حر من المستخدم، ومش من الـ token، ومن غير فحص role. أي مستخدم يقدر يعتمد باسم المخلص | `customs_document_approval_tab.dart:1412`، `:1436`، `:1571`، `:1596`، `modules/docs_customs_approval/router.py:28` | `reviewer = current_user`، وصلاحيات منفصلة لكل دور |
| Medium | ملف الشحنة فاضي، مع إن `DocsCustomsApprovalScreen` بيختار أول ملف ويبعته كـ `initialImportFileId`. وبسبب كده "تذكرة جديدة" و "فحص متقاطع" و "توليد القائمة" كلهم بيطلعوا SnackBar من غير ما يعملوا حاجة، والـ dialog مبيفتحش | `29-docs-customs-approval-main.png`، `29-docs-customs-approval-dialog-add.png`، `docs_customs_approval_screen.dart:53-58`، `customs_document_approval_tab.dart:233-237` | التأكد إن الملف المختار بيوصل للتاب، أو تعطيل الأزرار مع tooltip "اختر ملف الشحنة" |
| Medium | "توليد القائمة القياسية" مفيهوش loading state، فممكن يتضغط كذا مرة ويولّد قوايم مكررة | `customs_document_approval_tab.dart:638`، `:114-125` | `isLoading` زي زرار الفحص المتقاطع |
| Medium | عناوين أعمدة التصدير hard-coded بـ `isAr ? '…' : '…'` بدل مفاتيح `l10n` | `customs_document_approval_tab.dart:285-293`، `:381-388` | مفاتيح `l10n` |
| Low | زرار الخطابات في الـ header `OutlinedButton` بدل `AppButton`، وفي التاب 12 `ElevatedButton` | `docs_customs_approval_screen.dart:106`، `customs_document_approval_tab.dart` | `AppButton` |
| Low | رسالة "كافة المستندات متطابقة" بتظهر لما مفيش تذاكر، حتى لو مفيش مستندات مسجلة أصلاً، وده مضلل | `29-docs-customs-approval-main.png` | الرسالة تتغير لو المصفوفة فاضية |
| Low | الـ breadcrumb بيقول "مراجعة مسودات بوالص الشحن"، والعنوان "Docs Customs Approval …" مقطوع بالإنجليزي. ده من مشكلة الـ locale المعروفة | `29-docs-customs-approval-main.png` | `supportedLocales` |
| Low | console (ويب بس): `Refused to set unsafe header "Accept-Encoding"` | `runtime-errors.json` ← `29-docs-customs-approval` | — |
