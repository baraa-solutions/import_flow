---
name: widget-unification
description: دليل ومعيار توحيد الأدوات والـ Widgets ومنع التكرار والعبء الزائد في ImportFlow ERP. يوجّه المطورين ووكلاء الذكاء الاصطناعي لاستخدام الأدوات المركزية المعتمدة وتجنب إعادة اختراع العجلة.
---

# 🛠️ Widget Unification & Tool Optimization Skill — ImportFlow ERP

> **الهدف:** توحيد الكود وطرق الاستخلاص، تنظيم الأدوات المعتمدة، ومنع تكرار أي أدوات لا تُستخدم وتشكل عبئاً على الشاشة والنظام.

---

## 🏛️ 1. المبدأ الذهبي: Single Source of Truth
يُحظر كتابة كود مخصص (ad-hoc) لأي نمط واجهة مستخدم يتوفر له مكون مركزي في `frontend/lib/core/widgets/` أو `frontend/lib/core/theme/`.

كل الأدوات المركزية مجمّعة في الملف الموحد:
```dart
import 'package:frontend/core/widgets/widgets.dart';
```

---

## 📋 2. الفهرس المرجعي للأدوات الموحدة (Canonical Tool Catalog)

| النمط المطلوب | المكون المعتمد (Canonical Component) | الاستخدام الممنوع ❌ |
|---|---|---|
| **رسائل التنبيه والنتائج** | `AppTheme.snackBar(context, msg, severity: ...)` | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` |
| **جداول البيانات المتقدمة** | `EnterpriseDataTable<T>(columns: ..., rows: ...)` | `DataTable(...)` أو Dual-DataTable Hack |
| **شارات وحالات السجلات** | `AppStatusBadge.fromStatus(status: ...)` أو `AppStatusBadge(...)` | `Container(decoration: BoxDecoration(...))` محلي |
| **نوافذ التأكيد والحذف** | `AppConfirmDialog.showDelete(context, entityName: ...)` <br> `AppConfirmDialog.showToggleActive(...)` | `showDialog<bool>(builder: (ctx) => AlertDialog(...))` |
| **اختيار التاريخ** | `AppDatePickerField(label: ..., value: ..., onChanged: ...)` | `showDatePicker(...)` + `InkWell` + `InputDecorator` محلي |
| **حقول البحث المستقلة** | `AppSearchField(controller: ..., onChanged: ...)` | `TextField(decoration: InputDecoration(prefixIcon: search))` محلي |
| **حالات التحميل (Loading)** | `const AppLoadingState()` <br> `const AppLoadingState.section()` | `Center(child: CircularProgressIndicator(...))` |
| **حالات القوائم الفارغة** | `AppEmptyState(message: ...)` <br> `AppEmptyState.noSearchResults(...)` | `Column(children: [Icon, Text])` محلي |
| **حالات الأخطاء (Error)** | `AppErrorState(error: e, onRetry: ...)` | `Column(children: [Icon(error), Text])` محلي |
| **ترويسة الصفحات الرئيسية** | `PageHeader(icon: ..., title: ...)` | `appBar: AppBar(...)` خام |
| **أشرطة أدوات البيانات** | `ActionToolbar(...)` أو `MasterDataToolbarWidget(...)` | `Row(...)` مكدس بأزرار وحقول يدوية |
| **أزرار الإجراءات** | `AppButton(label: ..., variant: ..., onPressed: ...)` | `ElevatedButton.styleFrom(...)` |
| **أزرار صفوف الجداول** | `RowActionsPill(onView: ..., onEdit: ..., onDelete: ...)` | تكرار `IconButton` مصفوفة يدوياً |
| **القوائم المنسدلة المرجعية** | `SearchableDropdownField<T>(...)` | `DropdownButtonFormField(...)` (ممنوع قطعي) |
| **حقول الإدخال النصية** | `CustomTextField(controller: ..., label: ...)` | `TextFormField(...)` مكرر بـ borders محلية |
| **بطاقات وحاويات الشاشة** | `AppTheme.cardDecorationOf(context)` | `BoxDecoration(color: Colors.white, ...)` |
| **تحديد النصوص بالماوس** | `SelectionArea(child: ...)` إلزامي للشاشات والنوافذ | ترك الشاشات أو الـ Dialogs دون إمكانية تحديد بالماوس ❌ |
| **نسخ النصوص والجداول** | `CopyHelper.copy(context, text)` <br> `TableCopyHelper.copyTable(context, ...)` | `Clipboard.setData(ClipboardData(...))` مباشر دون تنظيف Bidi ❌ |

---

## 🚫 3. قاعدة عدم إثقال الشاشات بالأدوات الزائدة (Zero-Weight Rule)

> **قاعدة صارمة:** أي أداة لا تُستخدم مباشرة في سياق الشاشة تمثل عبئاً على شجرة الـ Widgets (Widget Tree)، وتبطئ بناء الإطارات (Rebuilds)، وتشتت المستخدم.

### أ) التمييز الإلزامي بين أنواع الشاشات:
1. **شاشات القوائم (Type B - List/Master Screens):**
   - **Header:** بحد أقصى إجراءان (إضافة جديد + العودة للرئيسية). **❌ ممنوع وضع Stage Badges أو أزرار مراحل (Skip Step / Stop Shipment)**.
   - **Toolbar:** شريط أفقي مدمج واحد (Compact Toolbar Rule) بارتفاع أقصى 40px: 3 أزرار رئيسية فقط + `More actions ⋮` للباقي.
   - **الجدول:** يجب أن يبدأ في أول 90px من الشاشة لضمان ظهور 4-5 صفوف على الأقل في شاشات الحواسيب القياسية.

2. **شاشات المراحل التشغيلية (Type A - Stage/Review Screens):**
   - تحتوي فقط على أدوات المرحلة الحالية ومسار دورة الحياة (`VerticalStageScaffold`).
   - لا تكرر داخلها أدوات Master Data أو عمليات استيراد مجمعة لا تخص الشحنة.

3. **شاشات لوحات القيادة (Type C - Dashboards):**
   - مخصصة للتحليل البياني والبطاقات، ولا تحمّل جداول تعديل أو فورمات معقدة مالم تُطلب صراحة.

### ب) عزل النوافذ الثقيلة (Lazy Modals):
- **ممنوع** تضمين كود الحوارات الكبيرة (Dialogs) مثل الفورمات أو محاكيات الشحن كـ Inline Methods تزيد عن 50 سطراً داخل كود الشاشة الأساسي.
- يجب فصل أي Dialog معقد في ملف مستقل داخل مجلد `widgets/` الخاص بالـ Feature واستدعاؤه فقط عند نقر المستخدم.

### ج) حظر الـ Dual-DataTable Hack:
- يُمنع تماماً إنشاء جدولين منفصلين لمحاكاة الرأس الثابت (Sticky Header).
- استخدم `EnterpriseDataTable` مباشرة، فهو يوفر الرأس الثابت والتمرير الأفقي والعمودي وإخفاء الأعمدة والفرز والتصدير داخلياً بأعلى كفاءة.

---

## 💡 4. أمثلة التحويل والتوحيد السريع (Refactoring Recipes)

### النمط 1: رسائل الـ SnackBar
```dart
// ❌ قبل: 10 أسطر متكررة وتخالف أنظمة الألوان
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    backgroundColor: AppTheme.emerald,
    content: Text(msg),
    duration: const Duration(seconds: 4),
  ),
);

// ✅ بعد: سطر واحد موحد ومطابق للـ Theme
AppTheme.snackBar(context, msg, severity: AppSeverity.success);
```

### النمط 2: تأكيد الحذف أو إيقاف التفعيل
```dart
// ❌ قبل: 25 سطراً من الـ boilerplate
final confirm = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(l10n.confirmActionTitle),
    content: Text(isActive ? l10n.confirmDeactivate(...) : l10n.confirmActivate(...)),
    actions: [ ... ],
  ),
);

// ✅ بعد: استدعاء نظيف وموحد
final confirm = await AppConfirmDialog.showToggleActive(
  context,
  isCurrentlyActive: isActive,
  entityName: entity.name,
);
```

### النمط 3: حالات Riverpod AsyncValue
```dart
// ❌ قبل: تكرار غير منسق
asyncState.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  data: (items) => items.isEmpty 
      ? Center(child: Text('لا توجد بيانات')) 
      : MyListView(items),
  error: (err, _) => Center(child: Text('خطأ: $err')),
);

// ✅ بعد: مكونات موحدة جاهزة للـ Dark Mode والـ Localization
asyncState.when(
  loading: () => const AppLoadingState(),
  data: (items) => items.isEmpty
      ? AppEmptyState(message: context.l10n.noResultsFound)
      : MyListView(items),
  error: (err, _) => AppErrorState(
    error: err,
    onRetry: () => ref.invalidate(myProvider),
  ),
);
```

### النمط 4: شارة الحالة (Status Badge)
```dart
// ❌ قبل: Container مخصص مع switch case متكرر في عشرات الملفات
Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
  child: Text(status, style: TextStyle(color: fg)),
)

// ✅ بعد: شارة ذكية وموحدة تحدد اللون والتنسيق تلقائياً
AppStatusBadge.fromStatus(status: item.status, label: item.statusLabel);
```

---

## 🛡️ 5. قائمة فحص الاستلام (Pre-Delivery Checklist)
قبل تسليم أي شاشة أو مراجعة كود واجهة:
1. [ ] لا يوجد أي `ScaffoldMessenger.of(context).showSnackBar` يدوي (استخدم `AppTheme.snackBar`).
2. [ ] لا يوجد أي `AlertDialog` محلي لإجراءات الحذف والتفعيل (استخدم `AppConfirmDialog`).
3. [ ] لا يوجد `CircularProgressIndicator` ملقى بالوسط يدوياً (استخدم `AppLoadingState`).
4. [ ] لا يوجد `DataTable` خام برأسين (استخدم `EnterpriseDataTable`).
5. [ ] شاشات Type B لا تحتوي أزرار مراحل تشغيلية ولا تزيد أزرار الترويسة عن 2.
6. [ ] شريط الأدوات مدمج (أقل من 40px) والجداول تبدأ مباشرة أسفله.
7. [ ] تم استيراد المكونات عبر `import 'package:frontend/core/widgets/widgets.dart';`.
8. [ ] تم تغليف جذر الشاشة أو الـ Dialog بـ `SelectionArea` لتمكين المستخدم من تحديد ونسخ النصوص بالماوس بحرية.
9. [ ] لا يوجد أي استدعاء مباشر لـ `Clipboard.setData` (استخدم `CopyHelper.copy` أو `TableCopyHelper.copyTable` لنزع Bidi Unicode Isolates).
10. [ ] لا يوجد تكديس ثنائي اللغة بين أقواس مثل `(PO)` أو `(Terminal / Depot)` (فصل لغوي نقي 100% مع تخزين Tier 2 English بالـ Backend).

