import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/expense_catalog_model.dart';
import '../providers/expense_catalog_provider.dart';

class ExpenseCatalogScreen extends ConsumerStatefulWidget {
  const ExpenseCatalogScreen({super.key});

  @override
  ConsumerState<ExpenseCatalogScreen> createState() => _ExpenseCatalogScreenState();
}

class _ExpenseCatalogScreenState extends ConsumerState<ExpenseCatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'Clearance Fees',
    'Procedures & Approvals',
    'Inland Transport',
    'Port & Handling',
    'Other Fees',
  ];

  final List<String> _unitTypes = [
    'fixed',
    'per_ton',
    'per_container',
    'per_vehicle',
    'per_night',
    'per_invoice',
    'per_shipment',
    'range',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog({ExpenseCatalogModel? item}) {
    final isEdit = item != null;
    final codeController = TextEditingController(text: item?.code ?? '');
    final nameArController = TextEditingController(text: item?.canonicalNameAr ?? '');
    final nameEnController = TextEditingController(text: item?.canonicalNameEn ?? '');
    String selectedCategory = item?.category ?? _categories.first;
    String selectedUnit = item?.unitType ?? _unitTypes.first;
    bool allowComposite = item?.allowComposite ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isArabic = context.l10n.isArabic;
          final isDark = AppTheme.isDark(context);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_note_rounded : Icons.post_add_rounded,
                  color: AppTheme.cobalt,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isEdit
                      ? (isArabic ? 'تعديل بند المصروف' : 'Edit Expense Item')
                      : (isArabic ? 'إضافة كود مصروف قياسي جديد' : 'New Expense Code'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SelectionArea(
              child: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'كود البند القياسي (فريد بحروف كبيرة)' : 'Catalog Code (Uppercase)',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: codeController,
                          enabled: !isEdit,
                          decoration: InputDecoration(
                            hintText: 'e.g. CLR-LCL-INV',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            fillColor: isEdit ? (isDark ? Colors.grey.shade900 : Colors.grey.shade200) : null,
                            filled: isEdit,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (isArabic ? 'الكود إلزامي' : 'Code is required')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isArabic ? 'الاسم القياسي بالعربية' : 'Arabic Name',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: nameArController,
                          decoration: InputDecoration(
                            hintText: isArabic ? 'مثال: أتعاب تخليص جمركي' : 'e.g. أتعاب تخليص جمركي',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (isArabic ? 'الاسم العربي إلزامي' : 'Arabic name is required')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isArabic ? 'الاسم القياسي بالإنجليزية' : 'English Name',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: nameEnController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Customs Clearance Agency Fee',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'التصنيف' : 'Category',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    initialValue: selectedCategory,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: _categories
                                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                                        .toList(),
                                    onChanged: (v) => setDlgState(() => selectedCategory = v ?? selectedCategory),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'وحدة الحساب' : 'Unit Type',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    initialValue: selectedUnit,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: _unitTypes
                                        .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                                        .toList(),
                                    onChanged: (v) => setDlgState(() => selectedUnit = v ?? selectedUnit),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            isArabic ? 'يسمح بالقيمة المجمعة / المتعددة' : 'Allow Composite / Multi-item',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          value: allowComposite,
                          onChanged: (v) => setDlgState(() => allowComposite = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final payload = {
                    'code': codeController.text.trim().toUpperCase(),
                    'canonical_name_ar': nameArController.text.trim(),
                    'canonical_name_en': nameEnController.text.trim().isEmpty ? null : nameEnController.text.trim(),
                    'category': selectedCategory,
                    'unit_type': selectedUnit,
                    'allow_composite': allowComposite,
                  };

                  bool success;
                  if (isEdit) {
                    success = await ref.read(expenseCatalogProvider.notifier).updateItem(item.code, payload);
                  } else {
                    success = await ref.read(expenseCatalogProvider.notifier).createItem(payload);
                  }

                  if (context.mounted && success) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic ? 'تم حفظ بند المصروف بنجاح' : 'Expense item saved successfully',
                        ),
                        backgroundColor: AppTheme.emerald,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: Text(isArabic ? 'حفظ' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPatternDialog(ExpenseCatalogModel item) {
    final patternController = TextEditingController();
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppTheme.cobalt, size: 22),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'إضافة نمط / مرادف ذكي للتعرف' : 'Add Recognition Pattern',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isArabic ? 'كود البند:' : 'Item Code:'} ${item.code} (${item.canonicalNameAr})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: patternController,
                decoration: InputDecoration(
                  hintText: isArabic ? 'مثال: أتعاب المخلص، مصاريف إجراءات' : 'e.g. clearance fee, agent fees',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final pattern = patternController.text.trim();
              if (pattern.isEmpty) return;
              final success = await ref.read(expenseCatalogProvider.notifier).addPattern(item.code, pattern);
              if (ctx.mounted && success) {
                Navigator.of(ctx).pop();
              }
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic ? 'تم إضافة نمط التعرف بنجاح' : 'Pattern added successfully'),
                    backgroundColor: AppTheme.emerald,
                  ),
                );
              }
            },
            child: Text(isArabic ? 'إضافة النمط' : 'Add Pattern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expenseCatalogProvider);
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: PageHeader(
        title: isArabic ? 'دليل وكتالوج المصروفات الجمركية القياسي' : 'Coded Reference Expense Catalog',
        subtitle: isArabic
            ? 'الأكواد المرجعية الموحدة للمصروفات، أنماط التعرف الذكي، وذاكرة ربط بنود المخلصين'
            : 'Standard reference expense codes, recognition patterns, and broker mappings memory',
        icon: Icons.receipt_long_rounded,
        actions: const [
          BackToDashboardButton(),
        ],
      ),
      body: SelectionArea(
        child: Column(
          children: [
            // Tabs Bar
            Container(
              color: isDark ? const Color(0xFF1E2631) : Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.cobalt,
                indicatorColor: AppTheme.cobalt,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                    text: isArabic ? 'الأكواد القياسية للمصروفات' : 'Standard Catalog Items',
                  ),
                  Tab(
                    icon: const Icon(Icons.psychology_alt_rounded, size: 18),
                    text: isArabic ? 'ذاكرة ربط بنود المخلصين' : 'Broker Mappings Memory',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Catalog Items
                  _buildCatalogTab(state, isArabic, isDark),

                  // Tab 2: Broker Mappings
                  _buildBrokerMappingsTab(state, isArabic, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogTab(ExpenseCatalogState state, bool isArabic, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Toolbar Row
          Row(
            children: [
              // Search
              SizedBox(
                width: 240,
                height: 36,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: isArabic ? 'بحث بالكود أو الاسم...' : 'Search code or name...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(expenseCatalogProvider.notifier).setSearch('');
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (v) => ref.read(expenseCatalogProvider.notifier).setSearch(v.trim()),
                ),
              ),
              const SizedBox(width: 8),

              // Category Filter
              Container(
                width: 180,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: state.selectedCategory,
                    isDense: true,
                    isExpanded: true,
                    hint: Text(isArabic ? 'كل التصنيفات' : 'All Categories', style: const TextStyle(fontSize: 12)),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(isArabic ? 'كل التصنيفات' : 'All Categories', style: const TextStyle(fontSize: 12)),
                      ),
                      ..._categories.map((c) => DropdownMenuItem<String?>(
                            value: c,
                            child: Text(c, style: const TextStyle(fontSize: 12)),
                          )),
                    ],
                    onChanged: (v) => ref.read(expenseCatalogProvider.notifier).filterCategory(v),
                  ),
                ),
              ),
              const Spacer(),

              // Refresh
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: isArabic ? 'تحديث' : 'Refresh',
                onPressed: () => ref.read(expenseCatalogProvider.notifier).fetchItems(),
              ),
              const SizedBox(width: 8),

              // Add Button
              AppButton(
                label: isArabic ? 'إضافة كود مصروف' : 'Add Expense Code',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () => _showAddEditDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items Table
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                    ? Center(
                        child: Text(
                          isArabic ? 'لا توجد بنود مصروفات مطابقة' : 'No expense items found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return Card(
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: InkWell(
                                      onTap: () => CopyHelper.copy(context, item.code),
                                      child: Text(
                                        item.code,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: AppTheme.cobalt,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              item.canonicalNameAr,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (item.canonicalNameEn != null) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                '(${item.canonicalNameEn})',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Chip(
                                              label: Text(item.category, style: const TextStyle(fontSize: 10.5)),
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                              backgroundColor: isDark ? const Color(0xFF253140) : const Color(0xFFF1F5F9),
                                            ),
                                            Chip(
                                              label: Text(item.unitType, style: const TextStyle(fontSize: 10.5)),
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            if (item.allowComposite)
                                              Chip(
                                                label: Text(isArabic ? 'مجمع' : 'Composite', style: const TextStyle(fontSize: 10.5, color: Colors.orange)),
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                          ],
                                        ),
                                        if (item.recognitionPatterns.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: [
                                              ...item.recognitionPatterns.map(
                                                (pat) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.emerald.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    pat,
                                                    style: const TextStyle(fontSize: 10.5, color: AppTheme.emerald),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    tooltip: isArabic ? 'إضافة مرادف ذكي' : 'Add Recognition Pattern',
                                    color: AppTheme.emerald,
                                    onPressed: () => _showAddPatternDialog(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: isArabic ? 'تعديل البند' : 'Edit',
                                    color: AppTheme.cobalt,
                                    onPressed: () => _showAddEditDialog(item: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    tooltip: isArabic ? 'تعطيل البند' : 'Deactivate',
                                    color: AppTheme.crimson,
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: Text(isArabic ? 'تأكيد التعطيل' : 'Confirm Deactivation'),
                                          content: Text(
                                            isArabic
                                                ? 'هل أنت متأكد من تعطيل الكود ${item.code}؟'
                                                : 'Are you sure you want to deactivate ${item.code}?',
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
                                              onPressed: () => Navigator.of(c).pop(true),
                                              child: Text(isArabic ? 'تعطيل' : 'Deactivate'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ref.read(expenseCatalogProvider.notifier).deactivateItem(item.code);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokerMappingsTab(ExpenseCatalogState state, bool isArabic, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                isArabic
                    ? 'الذاكرة التراكمية لمطابقة بنود الفواتير مع المخلصين الجمركيين'
                    : 'Customs Broker Extracted Items Memory',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: isArabic ? 'تحديث' : 'Refresh',
                onPressed: () => ref.read(expenseCatalogProvider.notifier).fetchBrokerMappings(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: state.brokerMappings.isEmpty
                ? Center(
                    child: Text(
                      isArabic ? 'لا توجد ذاكرة ربط محفوظة حالياً' : 'No broker mappings stored yet',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: state.brokerMappings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final mapping = state.brokerMappings[index];
                      return Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                mapping.rawItemName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.cobalt),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mapping.catalogCode,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                    color: AppTheme.cobalt,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                mapping.canonicalNameAr,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${isArabic ? 'المخلص:' : 'Broker:'} ${mapping.brokerName.isEmpty ? (isArabic ? 'عام / شامل' : 'Global') : mapping.brokerName} | ${isArabic ? 'دقة المطابقة:' : 'Confidence:'} ${(mapping.confidenceScore * 100).toInt()}%',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: AppTheme.crimson,
                            tooltip: isArabic ? 'حذف الربط' : 'Delete mapping',
                            onPressed: () async {
                              await ref
                                  .read(expenseCatalogProvider.notifier)
                                  .deleteBrokerMapping(mapping.brokerName, mapping.rawItemName);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
