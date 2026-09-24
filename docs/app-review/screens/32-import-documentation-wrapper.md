# غلاف مستندات الاستيراد، غير مستخدم (Import Documentation Wrapper (orphan))
> **مفيش screenshot للشاشة دي.** اتعلّم عليها skipped في `capture-manifest.json` (شاشة 32)، والسبب "unreachable in the running app". الكلاس `ImportDocumentationScreen` مش بيتعمله instance في أي مكان في التطبيق، فمفيش أي طريقة تفتحها من الواجهة. الشرح اللي تحت مبني على الكود بس.

## الغرض والمستخدمين والمرحلة (BP/MD)
دي "Legacy facade wrapper for backward compatibility" حسب التعليق في `frontend/lib/features/import_documentation/screens/import_documentation_screen.dart:14-15`. مفيش فيها أي UI خاص بيها. هي بس بتوجّه لشاشة مرحلة حسب `initialIndex`:

| `initialIndex` | الشاشة اللي بترجعها |
|---|---|
| 0 (والـ default) | `NafezaAcidScreen` (شاشة 22) |
| 1 | `BankForm4Screen` (شاشة 23) |
| 2 | `ShipmentDraftDocsScreen` (شاشة 31) |
| 3 | `CustomsDeclaration46Screen` (مجموعة الجمارك) |

وكمان بتعمل re-export لنفس الشاشات الأربعة (`:9-12`).

- **الكود:** `BP-016` (حسب `inventory.json`).

## طريقة الوصول والصلاحية
- **الوصول:** مفيش. الـ inventory بيقول "not instantiated anywhere".
- **الصلاحية:** تابعة للشاشة اللي بيتوجّه ليها، وكلها `get_current_user` بس.

## مكونات الشاشة
### الحقول
مفيش. البارامترات بس: `initialIndex` و `initialImportFileId`.

### الأزرار والإجراءات
مفيش.

### الجداول
مفيش.

### التابات
مفيش. `initialSubTab` بيتبعت ثابت بـ 0 للشاشة الهدف (`:30-54`).

### الـ Dialogs
مفيش.

### التصدير والطباعة
مفيش.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Low | كود ميت: الـ wrapper مش مستخدم في أي مكان، وبيعمل re-export لأربع شاشات، وده بيوسّع الـ import graph ويلخبط اللي بيقرا الكود (مين المدخل الحقيقي؟) | `import_documentation_screen.dart:1-56`، `inventory.json` (شاشة 32: "not instantiated anywhere") | يتشال، أو يتعلّم عليه `@Deprecated` |
| Low | الـ wrapper بيتجاهل `initialSubTab`، ودايماً بيبعت 0، فلو اتستخدم تاني مش هيقدر يفتح تاب بعينه | `import_documentation_screen.dart:30-54` | تمرير `initialSubTab` أو الحذف |
