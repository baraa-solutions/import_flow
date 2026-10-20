---
name: ui-screen-standards
description: >
  معايير UI الكاملة لشاشات ImportFlow ERP. يُستخدم هذا الـ Skill عند تنفيذ
  أي مهمة تتعلق بـ Flutter Frontend أو UI أو إنشاء/تعديل شاشة أو Widget.
  لا تحتاج لقراءة هذا الملف في مهام Backend-only أو Database أو API فقط.

  **متى تُفعّله:** أي مهمة تذكر كلمة "شاشة"، "واجهة"، "UI"، "Flutter"،
  "Widget"، "Scaffold"، "Dialog"، "Form"، "Button"، "Layout"، "Screen".
---

# 🖥️ ImportFlow ERP — UI Screen Standards

> الـ Widgets الجاهزة موجودة في: `frontend/lib/core/widgets/`

---

## 0. 🏛️ Screen Types & Baseline Definitions (تصنيف الشاشات والمعايير المرجعية)

> **قاعدة حتمية:** يجب أولاً تحديد نوع الشاشة (**Type A** أو **Type B** أو **Type C**) قبل إجراء أي فحص اتساق أو مراجعة للتصميم. يُحظر تماماً تطبيق معيار شاشات المراحل (Stage Screen) على شاشات القوائم (List Screen) أو العكس.

### Type A — شاشات المراحل والمراجعة (Stage / Review Screens)
* **الشاشة المرجعية القياسية (Baseline Screen):** شاشة مراجعة مسودات المستندات (`ShipmentDraftDocumentsReviewScreen`).
* **الغرض:** إدارة مرحلة تشغيلية لشحنة استيرادية معينة (مثل الفحص، الإفراج، التخليص الجمركي، الفاتورة 4، نموذج 46).
* **هيكل الـ Header:**
  - أيقونة + عنوان الشاشة + **شارة المرحلة (Stage Badge مثل `PHASE-X` أو `STAGE_CODE`)**.
  - شريط الأزرار العلوي (Top-Right): أزرار دورة حياة الشحنة (`Skip Step` باللون البرتقالي، `Stop Shipment` باللون الأحمر، `Clone`، `AI Assistant`، `Refresh`، وزر العودة `Back to Dashboard` دائماً في النهاية).

### Type B — شاشات الجداول والقوائم الرئيسية (List / Index Screens)
* **الشاشة المرجعية القياسية (Baseline Screen):** شاشة إدارة ملفات الاستيراد والشحنات (`ImportFilesScreen`).
* **الغرض:** عرض وإدارة السجلات العامة والبيانات المرجعية (مثل ملفات الاستيراد، أوامر الشراء، الموردين، الشركات، الشركاء، المواقع، العملات).
* **هيكل الـ Header:**
  - أيقونة + عنوان الشاشة فقط (**❌ بدون شارة مرحلة Stage Badge**).
  - أعلى اليمين (Top-Right Actions): **بحد أقصى إجراءان اثنان فقط (Max 2 Actions)**:
    1. الإجراء الرئيسي للشاشة (مثل: `Add New`).
    2. زر العودة للرئيسية (`Back to Dashboard` / `BackToDashboardButton`).
* **هيكل جسم الشاشة — قاعدة شريط الأدوات المدمج (Compact Toolbar Rule):**
  1. **شريط الأدوات الموحد (Single Toolbar Row — Max 40px):**
     - بحد أقصى 3 أزرار رئيسية مرئية + قائمة `More actions ⋮` للأدوات الإضافية.
     - أيقونات مدمجة (32x32px): التحديث الفوري 🔄، تصدير إكسل 📗، تصدير بي دي إف 📕.
     - حقل بحث نصي (عرض 180-220px بارتفاع 32px) + قائمة تصفية حالة (عرض 100-130px).
     - أبعاد الأزرار: ارتفاع 32px، حشوة أفقية 10-12px، حجم خط 12.5-13px.
     - إجمالي ارتفاع منطقة الإجراءات: **80-90px** كحد أقصى.
  2. **جدول البيانات الرئيسي:** يبدأ مباشرة أسفل الشريط — **4-5 صفوف** مرئية عند فتح الشاشة على `1366x768`.

### Type C — الشاشات الخدمية ولوحات القيادة (Utility / Dashboard Screens)
* **أمثلة:** `OperationalDashboardScreen`, `LifecycleBoardScreen`, `CbmCalculatorScreen`, `DynamicReportBuilderScreen`.
* **الهيكل:** مصممة لوظائف التفاعل والتحليل البياني، بدون جدول CRUD قياسي أو مسار مرحلة.

---

## 🎨 Button Color Palette Matrix (مصفوفة ألوان الأزرار الإلزامية)

> **قاعدة حتمية:** يُحظر تعيين ألوان الأزرار عشوائياً. يجب الالتزام بالمصفوفة التالية:

| الغرض (Purpose) | اللون (Color) | النمط (Style) |
|---|---|---|
| **Primary Action** | أزرق مصمت `AppTheme.cobalt` | `AppButtonVariant.primary` |
| **Secondary Action** | أزرق بإطار `Blue outline` | `AppButtonVariant.outline` |
| **Neutral Utility** | كحلي `AppTheme.charcoal` | رمادي داكن |
| **AI Feature** | زمردي `AppTheme.emerald` + `Icons.auto_awesome` | `AppTheme.emerald` |
| **Destructive / Stop** | أحمر `AppTheme.crimson` | `AppButtonVariant.danger` |
| **Warning / Skip** | برتقالي بإطار `AppTheme.orange` Outlined | Outlined |
| **Export Excel** | أخضر `AppTheme.emerald` | `Icons.table_chart` |
| **Export PDF** | أحمر `AppTheme.crimson` | `Icons.picture_as_pdf` |

---

## 📐 Density Control Placement Rule

* تحكم الكثافة (`Comfortable` / `Compact` / `Ultra-Compact`) = **إعداد عام مركزي واحد فقط**.
* ظهوره داخل شاشة معينة = **خطأ تكرار (Duplication Bug)** يجب إصلاحه.
* عزل التراكب: أي قائمة منبثقة يجب أن تكون بخلفية مصمتة (`solid background`) ومستوى طبقي صحيح.

---

## 🪟 General Overlay & Popover Rules (قواعد النوافذ المنبثقة)

1. **التموضع أسفل الزرار حصراً:** `position: PopupMenuPosition.under`.
2. **منع حجب أزرار التنقل:** محاذاة يمين امتداد يسار عند الحاجة.
3. **حظر حجب عنوان الشاشة أو أزرار التنقل الرئيسية.**
4. **تقييد الارتفاع الرأسي:** لا تغطي القائمة أكثر من سطر أدوات واحد، مع سكرول داخلي.
5. **خلفية مصمتة `elevation: 6`** + حواف دائرية `BorderRadius.circular(8)`.
6. **AI Assistant Docking (Desktop ≥ 1200px):** `AiAssistantDockedPanel` بعرض 410-560px داخل الـ `Row` الرئيسي.
7. **Greeting Bubble:** تنهار تلقائياً بعد 7 ثوانٍ أو عند أي تمرير.
8. **اختبار إلزامي على 1366x768** قبل تسليم أي شاشة.

---

## 🧱 Component Consolidation (المكونات الموحدة المشتركة)

> **قاعدة حتمية:** يُحظر كتابة كود محلي (Ad-hoc) للترويسة أو شريط الأدوات. يجب استخدام المكونات الموحدة من `frontend/lib/core/widgets/`:

### 1. `PageHeader` (ترويسة الصفحة الموحدة)
* شاشات Type B و C فقط عبر `appBar: PageHeader(...)`.
* ارتفاع ثابت: `54px` بدون عنوان فرعي، `58px` مع عنوان فرعي.
* خلفية `AppTheme.charcoal` مصمتة — لا gradients ضخمة.

### 2. `ActionToolbar` (شريط الأدوات الموحد)
* صف أفقي مدمج واحد مباشرة فوق الجداول — ارتفاع أقصى `30-40px`.
* يدمج: 3 أزرار رئيسية + `More actions ⋮` + حقل بحث (180-210px) + فلاتر (100-125px) + أيقونات (🔄 📗 📕).
* `SingleChildScrollView` أفقي داخلي بدون أشرطة ظاهرة + `MainAxisAlignment.spaceBetween`.

### 3. `MetricCard` / `MetricCardStrip` (شريط المؤشرات)
* **سطر واحد فقط** — لا شبكة 2×2 من البطاقات المنفصلة.
* التخطيط: `[icon] Title: Value` في سطر واحد مع `VerticalDivider` بين المؤشرات.
* الارتفاع يتكيف مع الكثافة: 42px → 34px → 28px.
* التسميات المختصرة إلزامية (`POs`, `PI/PO Amt`, `CBM`) — **القيم الرقمية لا تُقتطع أبداً**.
* الترتيب: `PageHeader` ← `MetricCardStrip` ← `ActionToolbar` ← `DataTable`.
* التفاف تلقائي لصفين عند ضيق المساحة (<660px).

### 4. الربط الشامل للكثافة (Global Density Wiring)
* كل العناصر تستمع لـ `ref.watch(displayDensityProvider)` وتستجيب فورياً.

### 5. مصفوفة أحجام الخطوط (Typography Scale)

| العنصر | Comfortable | Compact | Ultra-Compact |
|---|---|---|---|
| Page title | 20px | 17px | 15px |
| Page subtitle | 13px | 12px | 11px |
| Metric strip | 14px | 13px | 12px |
| Button text | 13px | 12px | 12px |
| Table header | 13px | 12px | 12px |
| Table cell primary | 14px | 13px | 12px |
| Table cell secondary | 12px | 11px | 11px |
| Search & Filter inputs | 13px | 12px | 12px |

> **قاعدة 11px Floor:** يُحظر أي نص أقل من 11px — يُطبّق `DisplayDensityMode.clampFontSize(size)`.

### 6. المكونات الموحدة الإلزامية (Canonical Core Widgets)
> استورد جميع المكونات عبر: `import 'package:frontend/core/widgets/widgets.dart';`
* **شارات الحالة:** `AppStatusBadge.fromStatus(status: ...)` — تمنع إنشاء Containers محلية.
* **تأكيد الحذف/التفعيل:** `AppConfirmDialog.showDelete(...)` و `showToggleActive(...)` — بديل لـ AlertDialog اليدوي.
* **حقول التواريخ:** `AppDatePickerField(...)` — تلغي تكرار showDatePicker و InputDecorator.
* **البحث المستقل:** `AppSearchField(...)` — للنوافذ المنبثقة والفلاتر المنفصلة.
* **حالات البيانات:** `AppLoadingState` و `AppEmptyState` و `AppErrorState` — بديل CircularProgressIndicator و Column المكرر.
* **رسائل التنبيه:** `AppTheme.snackBar(context, msg, severity: ...)` — بديل ScaffoldMessenger المكرر.
* **الجداول المتقدمة:** `EnterpriseDataTable<T>` — يمنع تماماً الـ Dual-DataTable Hack.
* **حقول الإدخال:** `CustomTextField` — حقل الإدخال القياسي بدلاً من TextFormField الخام.

---

## 1. 📐 Screen Anatomy — هيكل كل شاشة

```
┌────────────────────────────────────────────────────────────────────────┐
│  ZONE A — Header & Action Bar                                          │
│  [Icon + Title + Stage Badge]  [Skip] [Stop] [Clone] [AI] [🔄] [← Dash] │
├──────────────┬─────────────────────────────────────────────────────────┤
│  ZONE B      │  ZONE C — Main Content Area                             │
│  Sidebar Nav │  │ Toolbar: [🔄] [📥 Excel] [📄 PDF]                   │
│  (Stages /   │  ├─────────────────────────────────────────────────┤   │
│   Steps)     │  │ Cards / Body: [PDF] [Excel] [Print] [Save Draft]│   │
└──────────────┴─────────────────────────────────────────────────────────┘
```

---

## 2. 🏗️ Zone A — Page Header & Action Bar

> **الـ Widget الجاهز:** `VerticalStageScaffold`

### عناصر الـ Page Header الإلزامية:
- **Icon** + **Page Title** (Title Case) + **Stage Badge** (`PHASE-X` أو `STAGE_CODE`)
- **Header Color:** `AppTheme.charcoal` أو `AppTheme.cobalt`

### شريط الإجراءات — الترتيب الإلزامي الصارم:

| # | العنصر | متى يظهر |
|---|--------|-----------|
| 1 | ⏭ **Skip Step** (Outline Orange) | شاشات المراحل |
| 2 | 🛑 **Stop Shipment** (Filled Danger) | شاشات المراحل |
| 3 | 📋 **Clone** (`Icons.copy_rounded`) | عند انطباقه |
| 4 | 🤖 **AI Assistant** | عند انطباقه |
| 5 | 🔄 **Live Refresh** (`Icons.refresh`) | **إلزامي في كل الشاشات** |
| 6 | ← **Back to Dashboard** `BackToDashboardButton()` | **دايمًا الأخير** |

### مثال الكود:
```dart
VerticalStageScaffold(
  stageCode: 'PHASE-3: DRAFT_DOCUMENTS',
  titleAr: 'مراجعة مسودات المستندات',
  titleEn: 'Shipment Draft Documents Review',
  headerIcon: Icons.description_outlined,
  headerColor: AppTheme.cobalt,
  selectedImportFileId: importFileId,
  showStageLifecycleControls: true,  // ← Skip Step + Stop Shipment تلقائياً
  onShipmentStatusChanged: () => ref.invalidate(provider),
  headerActions: [
    IconButton(icon: const Icon(Icons.copy_rounded), tooltip: 'Duplicate', onPressed: _handleClone),
    IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: () => ref.invalidate(provider)),
    const BackToDashboardButton(),  // ← دايمًا الأخير
  ],
  tabs: [...],
  selectedIndex: _tab,
  onTabSelected: (i) => setState(() => _tab = i),
  body: _buildBody(),
)
```

---

## 3. 📑 Zone B — Sidebar Navigation

> **الـ Widget الجاهز:** `AdaptiveTabScaffold` أو `VerticalStageScaffold` (tabs)

```text
< 4 tabs  → Horizontal TabBar (افتراضي)
≥ 4 tabs  → Vertical Sidebar تلقائي (عبر AdaptiveTabScaffold)
```

---

## 4. 🔧 Zone C — Toolbar & Content Actions

### للشاشات القائمة على بيانات (Lists / Tables):
> **الـ Widget الجاهز:** `MasterDataToolbarWidget`

```dart
MasterDataToolbarWidget(
  moduleEndpoint: 'suppliers',
  title: context.l10n.screenTitle,
  onRefreshNeeded: () => ref.invalidate(yourProvider),
  onImportExcel: () => ...,  // اختياري
  extraTrailing: yourExtraButton,  // اختياري
)
```

### للشاشات القائمة على نماذج (Forms / Edit Dialogs):
> **الـ Widget الجاهز:** `StandardFormActionBar`

```dart
StandardFormActionBar(
  onRefresh: () => _reload(),
  onSaveDraft: () => _saveDraft(),  // إلزامي لأي Form
  onResetForm: () => _reset(),
  onSubmit: () => _submit(),
  onClose: () => Navigator.pop(ctx),
  isSaving: _isSaving,
  isEditing: isEditMode,
)
```

### إجراءات التصدير (Task I — File Save):
> كافة أزرار التحميل تستخدم حصرياً `FileSaveHelper.exportAndSaveFile(bytes: ..., fileName: ..., mimeType: ...)`.
> تسمية الملفات: `[Stage Name] - [Import File Name or Code].[ext]`

---

## 5. 🌐 Language, Anti-Stacking & Text Selection Rules

### أ. قواعد اللغة والفصل اللغوي الصارم (Language & Anti-Stacking):
- ✅ **Title Case** لكل أزرار وعناوين الواجهة بالإنجليزية: `Skip Step`, `Save Draft`, `Back to Dashboard`.
- ✅ جميع الـ Labels في كود الواجهة تُستدعى حصرياً عبر `context.l10n`.
- ❌ **حظر التكديس اللغوي (Strict Anti-Stacking):** يُمنع منعاً باتاً وضع الترجمة الإنجليزية بين أقواس بجوار العربي أو العكس (مثل `"Save حفظ"`, `"New PO (أمر شراء جديد)"`, `'📦 قابل للرص (Stackable)'`).
- ✅ **لغة أحادية نقية (Single-Locale Pure View):**
  - في الوضع العربي: نصوص عربية نقية 100% (صفر حروف لاتينية أو شروحات إنجليزية إلا للرموز الدولية مثل `CBM`, `FOB`, `USD`, `EGP`).
  - في الوضع الإنجليزي: نصوص إنجليزية نقية 100% (صفر حروف عربية).
- ❌ نصوص عربية أو إنجليزية Hard-coded داخل UI = مخالفة صريحة و Bug يجب إصلاحه.
- ✅ RTL يُعيَّن مركزياً عبر AppTheme و Directionality — لا تتدخل يدوياً واستخدم `EdgeInsetsDirectional` و `AlignmentDirectional`.
- ✅ **التخزين أحادي اللغة (Single-Language Storage):**
  - رسائل النظام: كود رسالة + باراميترات (`msg_code` + `msg_params`).
  - النصوص الافتراضية واللواحق (Clone): ثوابت إنجليزية ثابتة (مثل ` (Copy)`).
  - الـ Enums: أكواد `UPPER_SNAKE_CASE` (مثل `APPROVED`).

### ب. قواعد تحديد ونسخ النصوص بالماوس (SelectionArea & Clipboard Standards):
- ✅ **تغليف جذري إلزامي بـ `SelectionArea` (Root Wrapper Rule):**
  - كل شاشة (`Scaffold.body`) وكل نافذة حوارية (`Dialog.content` أو `Dialog.child`) **يجب أن تُغلَّف بـ `SelectionArea`**.
  - هذا يضمن تمكين تحديد النصوص بالماوس وسحبها ونسخها بـ `Ctrl + C` على بيئة الديسكتوب (Windows Desktop).
- ✅ **خلايا الجداول والبيانات:** استخدام `CopyableTableCell` لتمكين قائمة كليك يمين لنسخ القيمة أو نسخ الصف بالكامل كـ TSV.
- ✅ **أكواد الأعمال الحساسة:** (ACID, Import File Code, PO Number, BL) تُعرض بـ `CopyableText` أو مع أيقونة نسخ مدمجة وتستخدم `CopyHelper.copy(context, text)` الذي يزيل محارف الـ Bidi isolates تلقائياً.

---

## 6. 🎨 Color & Styling Rules

```dart
// ✅ دايمًا من AppTheme
AppTheme.cobalt      // #3498DB → Primary / Download PDF
AppTheme.emerald     // #27AE60 → Success / Export Excel
AppTheme.crimson     // #C0392B → Danger / Stop / Delete
AppTheme.orange      // #E67E22 → Warning / Skip Step
AppTheme.charcoal    // #2C3E50 → Header Bar Background
AppTheme.cloudWhite  // #ECF0F1 → Page Background

// ✅ الأزرار دايمًا بـ AppButton
AppButton(
  label: context.l10n.exportExcel,
  variant: AppButtonVariant.success,
  size: AppButtonSize.small,
  icon: Icons.description,
  isLoading: _isLoading,
  onPressed: _onExport,
)

// ❌ ممنوع
Color(0xFF3498DB)              // Hard-coded hex
Colors.blue / Colors.red       // Material colors
ElevatedButton.styleFrom(...)  // Manual styling
```

---

## 7. 📋 SearchableDropdownField — Reusable Component Spec

> **الـ Widget الموحد:** `SearchableDropdownField<T>` (`frontend/lib/core/widgets/searchable_dropdown_field.dart`)
> يُستخدم حصرياً لأي حقل اختيار يسحب خياراته من جدول DB أو API.
> ❌ يُمنع تماماً `DropdownButtonFormField` أو `TextField` لهذه الحقول.

### متى ينطبق:
- أي قائمة منسدلة تأتي خياراتها من DB/API (وليس enum ثابت صغير مثل Yes/No).
- أي قائمة يمكن أن تتجاوز 8-10 عناصر.

### السلوك والمواصفات:
1. **فتح مودال (Modal)** يحتوي على: ترويسة + شريط بحث + قائمة قابلة للتمرير.
2. **شريط بحث فوري (Filter-as-you-type)** يبحث في جميع الحقول (كود، اسم، سياق).
3. **خيار `-- None / لا يوجد --`** في بداية القائمة للحقول الاختيارية.
4. **تمييز العنصر المختار** بـ `AppTheme.cobalt.withOpacity(0.08)` + Checkmark.
5. **حالات فراغ/تحميل** واضحة (`Icons.search_off` عند عدم المطابقة).

```dart
SearchableDropdownField<int?>(
  value: _selectedSupplierId,
  items: suppliers.map((s) => SearchableDropdownItem<int?>(
    value: s.supplierId,
    label: '${s.companyName} (${s.supplierCode})',
    searchValue: '${s.companyName} ${s.supplierCode} ${s.countryName ?? ''}',
    subtitle: s.countryName,
  )).toList(),
  labelText: 'Foreign Supplier (المورد الأجنبي)',
  hintText: context.l10n.selectSupplierHint,
  onChanged: (val) => setState(() => _selectedSupplierId = val),
)
```

---

## 8. ♻️ Auto-Refresh — التحديث التلقائي

```dart
// بعد كل Add / Edit / Delete / Status Change:
ref.invalidate(yourProvider);  // ← إلزامي دايمًا

// في initState:
@override
void initState() {
  super.initState();
  Future.microtask(() => ref.invalidate(yourProvider));
}

// مؤشر تحميل إلزامي أثناء Async:
AppButton(
  isLoading: _isSaving,  // ← يمنع الضغط المتكرر
  onPressed: _isSaving ? null : _save,
)
```

---

## 9. 🚫 Anti-Patterns — ممنوع في أي شاشة

```text
❌ AppBar عادي بدلاً من VerticalStageScaffold Header
❌ TabBar أفقي عند عدد tabs ≥ 4
❌ Text عربي/إنجليزي Hard-coded بدلاً من l10n
❌ ElevatedButton / OutlinedButton بدلاً من AppButton
❌ Colors.xxx أو Color(0xFF...) بدلاً من AppTheme
❌ DropdownButtonFormField بدلاً من SearchableDropdownField
❌ شاشة Stage بدون Back to Dashboard button
❌ شاشة Stage بدون showStageLifecycleControls: true
❌ بيانات Stale Cache عند فتح الشاشة (لا initState refresh)
❌ زرار بدون isLoading أثناء عملية Async
❌ حفظ ملف صامت — لازم FileSaveHelper.exportAndSaveFile
```

---

## 10. 📊 Data Table UX Standards

### أ. Sticky Header:
- ترويسة الجدول ثابتة أثناء التمرير الرأسي.
- خلفية مصمتة: `AppTheme.charcoal.withOpacity(0.06)` في الوضع الفاتح.
- حد سفلي رفيع أو ظل خفيف لتوضيح الفصل البصري.

### ب. Sticky Actions Column:
- في الجداول التي تدعم التمرير الأفقي: تثبيت عمود Checkbox وعمود Actions على الطرف.

### ج. استقلالية حاويات التمرير:
- كل جدول يحصل على حاوية تمرير مستقلة (رأسية + أفقية) مع `Scrollbar` تفاعلي.

---

## 11. 🖥️ Responsive Breakpoints & Display Density

### نقاط التوقف المعتمدة:
- **الحد الأدنى (Laptop):** 1366×768px
- **Tablet Landscape:** 1366×1024px
- **Large Desktop:** ≥ 1440px
- **Mobile/Narrow:** <768px → كروت متراصة `Card List`

### مستويات كثافة العرض:
| الوضع | ارتفاع السطر | الحشوات |
|---|---|---|
| Comfortable (افتراضي) | 52px | 16px |
| Compact | 44px | 10px |
| Ultra-Compact | 36px | 6px |

---

## 12. 📋 Row Clone / Duplicate — Spec

> يُستخدم لأي قسم يحتوي على بنود متكررة (PO Line Items, Packing List, Invoice Lines, etc.)

### السلوك الإلزامي:
1. أيقونة `Icons.copy_rounded` بجوار أيقونة الحذف في كل صف.
2. الصف المكرر يُدرج **عند `index + 1` مباشرة** — لا في نهاية القائمة.
3. يُنسخ كل المحتوى ما عدا الـ `item_id` الفريد (يتم إنشاؤه عند الحفظ).
4. إعادة ترقيم تسلسلي تلقائي للقائمة.
5. Focus تلقائي لأول حقل قابل للتعديل في الصف الجديد.
6. إعادة حساب الإجماليات فورياً.

---

## 13. 📋 Complete Screen Template (للنسخ المباشر)

```dart
class YourStageScreen extends ConsumerStatefulWidget {
  final int importFileId;
  const YourStageScreen({super.key, required this.importFileId});

  @override
  ConsumerState<YourStageScreen> createState() => _YourStageScreenState();
}

class _YourStageScreenState extends ConsumerState<YourStageScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(yourDataProvider)); // ← Auto-refresh on mount
  }

  @override
  Widget build(BuildContext context) {
    return VerticalStageScaffold(
      stageCode: 'STAGE_CODE',
      titleAr: 'اسم المرحلة',
      titleEn: 'Stage Name',
      headerIcon: Icons.your_icon,
      headerColor: AppTheme.cobalt,
      selectedImportFileId: widget.importFileId,
      showStageLifecycleControls: true,
      onShipmentStatusChanged: () => ref.invalidate(yourDataProvider),
      tabs: [
        VerticalNavTabItem(icon: Icons.list_alt, titleAr: 'القائمة', titleEn: 'List'),
      ],
      selectedIndex: _selectedTab,
      onTabSelected: (i) => setState(() => _selectedTab = i),
      headerActions: [
        const BackToDashboardButton(),  // ← دايمًا الأخير
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        MasterDataToolbarWidget(
          moduleEndpoint: 'your-endpoint',
          title: context.l10n.screenTitle,
          onRefreshNeeded: () => ref.invalidate(yourDataProvider),
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }
}
```

---

## 14. 🔍 Screen Consistency Audit Checklist

| # | العنصر | المتوقع | الإجراء التصحيحي |
|---|--------|---------|-----------------|
| 1 | Page Header | Icon + Title (Title Case) + Stage Badge | استخدام `VerticalStageScaffold` |
| 2 | Action Bar Order | `[Skip][Stop][Clone][AI][Refresh][Dashboard]` | ترتيب Widgets وفق الجدول الصارم |
| 3 | Back to Dashboard | دايمًا آخر عنصر | `const BackToDashboardButton()` في نهاية `headerActions` |
| 4 | Live Refresh | `IconButton(Icons.refresh)` في الهيدر والـ Toolbar | `ref.invalidate()` |
| 5 | Save Draft | في كل شاشة Form أو Editable | `onSaveDraft` في `StandardFormActionBar` |
| 6 | Document Actions | PDF / Excel / Print في كروت المستندات | `AppTheme` + `AppButton` الموحد |
| 7 | Sidebar Navigation | Vertical Sidebar عند ≥4 tabs | `AdaptiveTabScaffold` |
| 8 | Language & Casing | English labels فقط + `context.l10n` + Title Case | استبدال النصوص بـ l10n |
| 9 | Dropdowns | `SearchableDropdownField` حصراً | استبدال `DropdownButtonFormField` |
| 10 | Loading State | `isLoading: _isSaving` في الأزرار | تمرير `isLoading` لـ `AppButton` |
| 11 | Table Sticky Header | ثابتة بخلفية مصمتة أثناء السكرول | `stickyHeader` + خلفية مصمتة |
| 12 | Sticky Actions Col | ثابت أثناء السكرول الأفقي | تثبيت عمود الإجراءات |
| 13 | Responsive Bounds | لا overflow عند 1366×768 | `Flexible/Expanded/Wrap` بدل أبعاد ثابتة |
| 14 | Universal Mouse Selection | `SelectionArea` إلزامي لكل شاشة وDialog وحاسبة | تغليف جذر الشاشة أو الـ Dialog بـ `SelectionArea` |
| 15 | Sanitized Clipboard Copy | تنظيف الـ Bidi Isolates (`\u2066`, `\u2067`, `\u2069`) | استخدام `CopyHelper.copy` و `TableCopyHelper.copyTable` حصراً |
| 16 | Anti-Stacking & Pure View | لغة نقية مفصولة 100% ومنع الأقواس الثنائية | إزالة التكديس مثل `(PO)` واستخدام `context.l10n` |

## File save and export (moved from CORE_RULES, 2026-10-05)

### 🔴 Mandatory Save File Location Dialog (Task I — حفظ وتنزيل الملفات الموحد)
```text
✅ فتح نافذة حوارية تفاعلية إلزامية (Native "Save As" Dialog) لتحديد مكان الحفظ واسم الملف:
   - ديسكتوب (Desktop): FilePicker.saveFile مع lockParentWindow: true
   - متصفح ويب (Web - Chromium): File System Access API (window.showSaveFilePicker)
✅ معالجة الإلغاء الآمن (AbortError): التقاط DOMException بهدوء دون حفظ ملف ودون خطأ
✅ متصفحات غير داعمة (Firefox/Safari/Mobile): تراجع لـ <a download> مع SnackBar توضيحي
✅ كافة عمليات التصدير والتحميل (PDF, Excel, PNG, CSV) تمر حصرياً عبر FileSaveHelper.exportAndSaveFile
✅ تمرير مصفوفة bytes لضمان التوافق التام عبر سطح المكتب (Windows Desktop) ومتصفح الويب (Web)
✅ الالتزام بنظام التسمية القياسي: [Stage Name] - [Import File Name/Code].[ext]
✅ إظهار إشعار عائم SnackBar مع زر "فتح المجلد" لفتح مسار الملف في Windows Explorer فور الحفظ
❌ حظر الحفظ الصامت التلقائي (Silent Download) في مسار ثابت أو مجلد افتراضي دون سؤال المستخدم
❌ حظر الأسماء العامة أو العشوائية (مثل export.pdf أو download.xlsx)
```
