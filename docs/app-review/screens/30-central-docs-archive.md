# الأرشيف المركزي لمستندات وتعديلات الشحنة (Central Docs & Rectifications Hub)
![](../screenshots/30-central-docs-archive-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
عرض موحد (read-only) لكل مستندات ملف شحنة في مكان واحد: الفاتورة النهائية المعتمدة، وقائمة التعبئة، ومسودة البوليصة، ومسودة شهادة المنشأ / EUR.1، وشهادة الفحص. ومعاهم ملخص التعديلات والفروق المفتوحة، ومؤشر جاهزية الملف، وملخص الامتثال لمتطلبات الاستيراد، وإخطار جاهز يتبعت للمورد.

- **المستخدمين:** مسؤول الاستيراد، والإدارة، والمخلص. أي حد محتاج صورة كاملة عن مستندات الملف.
- **المرحلة:** المرحلة 3 (في آخرها، بعد اعتماد المسودات).
- **الكود:** `BP-016` و `BP-026`.

## طريقة الوصول والصلاحية
- **الوصول:** من الـ sidebar: "المرحلة 3" ← "الأرشيف المركزي لمستندات وتعديلات الشحنة" (index 51). وكمان بيتفتح بـ push من `LifecycleBoardScreen`، وبيتضمّن جوه `customs_document_approval_tab.dart:832` (شاشة 29).
- **الصلاحية:** أي مستخدم عامل login (`modules/import_documentation/router.py:14`، `GET /central-archive/{id}` في `router.py:880-881`).

## مكونات الشاشة
دي `Scaffold` فيها `AppBar` عادي بلون `AppTheme.charcoal`، وعنوانه "الأرشيف المركزي لمستندات وتعديلات الشحنة"، وفيه زرار إغلاق (X). يعني الشاشة **مش** مبنية على `VerticalStageScaffold` / `DedicatedStageScaffold`.

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختر ملف الشحنة للاستعراض المركزي | `SearchableDropdownField<int>` | نعم عشان يظهر أي محتوى | — | `GET /import-files`، ومش بيتختار تلقائي |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| إغلاق والعودة (X في الـ AppBar، وزرار تحت المحتوى) | `Navigator.of(context).maybePop()` (`central_docs_archive_screen.dart:109`) | — | — |
| نسخ TSV | `exportService.exportToTsv()` | Client | — |
| تصدير Excel | `exportService.exportToExcel()` (`:271`) | Client، ومنه لـ `CentralDocsArchiveExportService` ثم `FileSaveHelper` | — |
| طباعة / حفظ PDF | `exportService.printOrSavePdf()` | Client، ومنه لـ `FileSaveHelper` | — |
| نسخ الملف الكامل (Dossier) | `copyDossierToClipboard()` | Client | — |

الأزرار دي كلها بتظهر بس بعد ما تختار ملف (`_buildExportToolbar`، `:227-298`).

### الجداول
بعد اختيار الملف (متصورش، لأن الـ harness مختارش ملف):
- **كارت نظرة عامة:** المستورد، والمصدّر / المورد، ورقم ACID، ومسار الشحن (POL ثم POD)، وعدد الطرود والوزن، وقيمة الفاتورة الإجمالية، ودرجة الجاهزية، وعدد الفروق الحرجة والتحذيرات (`:652-833`).
- **كارت الامتثال لمتطلبات الاستيراد** (`:409`): chips الامتثال، والبيانات جاية من `GET /import-documentation/legal-compliance/{fileId}`.
- **كارت التعديلات الرئيسية** (`:874`): checklist الفروق والتعديلات المطلوبة من المورد.
- **كروت المستندات** (`:1031`): الفاتورة التجارية، وقائمة التعبئة، والبوليصة، وشهادة المنشأ، وشهادة الفحص.

### التابات
مفيش.

### الـ Dialogs
مفيش. الـ harness سجل "no add/create button found"، والشاشة read-only.

### التصدير والطباعة
TSV و Excel و PDF، ونسخ الملف الكامل. كله عن طريق `CentralDocsArchiveExportService`، والملف ده بيستخدم `FileSaveHelper` (`services/central_docs_archive_export_service.dart`).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | الشاشة `Scaffold` و `AppBar` عادي، مش `VerticalStageScaffold`. ده anti-pattern صريح في المعيار. ومفيش Stage Badge، ولا Refresh، ولا Back to Dashboard، ولا أدوات دورة حياة الشحنة، والوحيد الموجود زرار X | `30-central-docs-archive-main.png`، `central_docs_archive_screen.dart:86-114`، `.agents/skills/ui-screen-standards/SKILL.md` §9 | يتبني على `DedicatedStageScaffold` أو `PageHeader` حسب النوع |
| Low | لما الشاشة تتفتح من الـ sidebar (جوه الـ shell مش push)، زرار X "إغلاق والعودة" بينادي `maybePop()`، ومفيش route خاص بالشاشة يرجعله، فالمتوقع إن الزرار ميعملش حاجة. ده من قراية الكود، ومتجربش في الـ run | `central_docs_archive_screen.dart:109`، `30-central-docs-archive-main.png` | يستخبى في وضع الـ sidebar، أو يرجع للداش بورد |
| Medium | لو ميناء الوصول مش موجود بيظهر "Alexandria" كقيمة افتراضية. ده fallback ثابت بيدي معلومة غلط | `central_docs_archive_screen.dart:787`، `:817` | يظهر "—" أو "غير محدد" |
| Low | لون الخلفية مكتوب ثابت `Color(0xFFF4F6F9)`، وده بيكسر الـ dark mode. وفي الشاشة 12 `ElevatedButton` و 101 `Colors.xxx` | `central_docs_archive_screen.dart:87` | `AppTheme` |
| Low | ملف الشحنة مش بيتختار تلقائي. الشاشة بتفتح على placeholder "يرجى اختيار ملف شحنة من القائمة أعلاه". ده مقبول هنا، بس مش متسق مع شاشات المرحلة التانية | `30-central-docs-archive-main.png` | توحيد سلوك الاختيار |
| Low | console (ويب بس): `Refused to set unsafe header "Accept-Encoding"` | `runtime-errors.json` ← `30-central-docs-archive` | — |
