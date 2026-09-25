# مصفوفة مستندات الشحنة (المسودات والاعتماد) (Shipment Draft Documents Matrix (DC-04))
> **مفيش screenshot للشاشة دي.** التصوير فشل (`capture-manifest.json`، شاشة 31، `status: "failed"`). زرار الوصول "مصفوفة المستندات (DC-04)" موجود في الـ semantics tree بتاع `ImportFileDetailsDialog`، لكن مكانه عند الإحداثي (4290,141)، يعني برا الـ viewport اللي عرضه 1600×1000، والـ scroll مش بيوصّله. معنى ده إن الـ layout مقصوص، ومستخدم حقيقي مش هيقدر يوصل للزرار ده على الشاشة دي. الشرح اللي تحت كله مبني على الكود.

## الغرض والمستخدمين والمرحلة (BP/MD)
الشاشة دي هي الـ "hub" المجمّع لكل مسودات المرحلة 3 في شاشة واحدة بتابات رأسية. كل تاب فيها هو نفس الـ widget اللي بتستخدمه الشاشات المنفصلة من 24 لـ 29، ومعاهم تاب التأمين. ودي كمان **الشاشة المرجعية (Baseline)** لمعيار Type A في `.agents/skills/ui-screen-standards/SKILL.md` §0.

- **المستخدمين:** موظف التوثيق، ومسؤول الاستيراد، والمخلص.
- **المرحلة:** المرحلة 3 (`stageCode: 'PHASE-3'`، `shipment_draft_docs_screen.dart:252`). العنوان: "مراجعة وتدقيق مسودات مستندات الشحن — المرحلة 3" / "Shipment Draft Documents Review".
- **الكود:** `BP-016` و `BP-022` و `BP-026`.

## طريقة الوصول والصلاحية
- **الوصول:** ملفات الشحنات الاستيرادية ← "عرض التفاصيل" (`ImportFileDetailsDialog`) ← زرار "مصفوفة المستندات (DC-04)" (`frontend/lib/features/import_files/widgets/import_file_details_dialog.dart:658`)، وبعدها Navigator push ومعاه الملف المختار. ومن `ImportDocumentationScreen` (case 2)، ودي wrapper مش مستخدمة.
- **الصلاحية:** أي مستخدم عامل login (routers `import_documentation` و `docs_customs_approval`: `Depends(get_current_user)` بس).

## مكونات الشاشة
`VerticalStageScaffold` بلون `AppTheme.emerald`، وفيه 7 تابات رأسية، وبانر "دليل الخبرات" (`ExperienceGuideAlertBanner`) بيظهر فوق لو فيه تطابقات مع شحنات سابقة (`:262-269`).

### الحقول
مفيش حقول على مستوى الشاشة نفسها. الملف بييجي من `initialImportFileId`، أو أول ملف في القايمة (`:92-96`). الحقول جوه كل تاب متشرحة في الشاشة المنفصلة بتاعته (24 لـ 29).

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| استنساخ (أيقونة، Ctrl+D) | بيفتح dialog الاستنساخ المناسب للتاب المفتوح: اعتماد المستندات، أو PO Recon، أو COO، أو Draft B/L (`_openSearchAndCloneDialog`، `:125-202`) | GET للـ sessions الخاصة بالتاب | — |
| توليد وميكنة المخاطبات والخطابات الرسمية | `FormalLetterGeneratorDialog` (`ElevatedButton` أبيض، `:285-294`) | `POST /formal-letters/generate` | — |
| تحديث | `_refreshData` بيحمّل الملفات ومستندات الشحنة ودليل الخبرات | `GET /import-files`، `GET /import-documentation/shipment-documents`، `POST /experience-guide/match` | — |
| تخطي المرحلة / إيقاف الشحنة / العودة للداش بورد | من `VerticalStageScaffold` | `/import-files/{id}/hold` وغيره | أي مستخدم |

### الجداول
الجداول جوه التابات (شوف 24 لـ 29)، وفي تاب 7 جداول شاشة التأمين.

### التابات
| # | التاب | الـ widget | الشاشة المنفصلة المقابلة |
|---|---|---|---|
| 1 | مركز اعتماد المستندات وتعديلات المورد | `CustomsDocumentApprovalTab` | 29 |
| 2 | مطابقة الفاتورة وقائمة التعبئة | `POReconciliationTab` | 24 |
| 3 | مسودة بوليصة الشحن والاعتماد | `DraftBLReviewTab` | 25 |
| 4 | استخراج ومطابقة الفاتورة والبوليصة | `InvoiceBLMatcherTab` | 26 |
| 5 | مسودة شهادة المنشأ و EUR.1 | `COOReviewTab` | 27 |
| 6 | شهادات الفحص والمطابقة | `InspectionReviewTab` | 28 |
| 7 | وثيقة وشهادة التأمين على البضائع | `CargoInsuranceScreen(isEmbedded: true)` | شاشة التأمين (مجموعة الشحن) |

مفيش صور للتابات، والسبب مذكور فوق.

### الـ Dialogs
`SearchAndCloneCustomsApprovalDialog`، و `SearchAndClonePoReconciliationDialog`، و `SearchAndCloneDraftBlDialog`، و `SearchAndCloneCooDialog`، و `FormalLetterGeneratorDialog`. ولا واحد فيهم اتصور.

### التصدير والطباعة
نفس تصدير كل تاب (شوف 24 لـ 29)، وكله عن طريق `TableExportService` / `FileSaveHelper`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | الشاشة المرجعية للمعايير مش reachable فعلياً. زرار "مصفوفة المستندات (DC-04)" جوه `ImportFileDetailsDialog` بيترسم برا الشاشة عند x≈4290 في viewport عرضه 1600، والـ scroll مش بيوصله | `capture-manifest.json` (شاشة 31: `OffscreenError`)، `import_files/widgets/import_file_details_dialog.dart:497` (الأزرار كلها جوه `Row` في `title` بتاع `AlertDialog` من غير `Wrap` ولا scroll: KB، والمحاكاة الجمركية، و DC-01، و DC-04…)، `:658` | إصلاح layout شريط الأزرار في الـ dialog (Wrap أو overflow menu)، وإضافة عنصر للشاشة في الـ sidebar |
| Medium | وقت التنقل للشاشة `GET /api/v1/experience-guide` رجع 500، والسبب `ValidationError` لـ `GuideEntryResponse` (قيم `upvotes` و `source_type` و `status` بـ None). وجنبه ظهر `Bad state: Cannot use "ref" after the widget was disposed`. ممكن سبب الـ 500 يكون بيانات الـ seed في قاعدة المراجعة، بس الـ schema مش متحملة null | `runtime-errors.json` ← `31-shipment-draft-docs-matrix`، `scratchpad/appreview/backend.log:1119` | defaults في الـ schema، والتأكد من `mounted` قبل استخدام `ref` بعد أي await |
| Medium | `_loadGuideForFile` بيبلع أي خطأ بـ `catch (_) {}`، فأي فشل في دليل الخبرات مش بيوصل للمستخدم ولا بيتسجل | `shipment_draft_docs_screen.dart:122` | log و SnackBar غير مزعج |
| Low | الاستنساخ من تاب Draft B/L بينقل للتاب 3 من غير ما يغير `_selectedImportFileId` للملف بتاع المسودة المختارة، بعكس التابات التانية | `shipment_draft_docs_screen.dart:190-200` | `_selectedImportFileId = r.importFileId` |
| Low | زرار الخطابات `ElevatedButton` بخلفية `Colors.white`، وده مخالف لـ `AppButton` في الشاشة اللي المفروض هي الـ baseline | `shipment_draft_docs_screen.dart:285-294` | `AppButton` |
| Low | تكرار: كل تاب موجود كمان كشاشة منفصلة في الـ sidebar (24 لـ 29)، فيه طريقين لنفس الوظيفة بعناوين مختلفة (مثلاً "مطابقة الفاتورة وقائمة التعبئة" مقابل "مطابقة الفاتورة والباكينج مع أمر الشراء") | `shipment_draft_docs_screen.dart:208-242`، `inventory.json` | توحيد التسميات، أو اختيار مدخل واحد |
