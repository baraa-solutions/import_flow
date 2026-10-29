import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/expense_catalog_model.dart';
import '../providers/expense_catalog_provider.dart';
import '../widgets/expense_catalog_data_table.dart';
import '../widgets/expense_category_form_dialog.dart';

class ExpenseCatalogScreen extends ConsumerStatefulWidget {
  const ExpenseCatalogScreen({super.key});

  @override
  ConsumerState<ExpenseCatalogScreen> createState() => _ExpenseCatalogScreenState();
}

class _ExpenseCatalogScreenState extends ConsumerState<ExpenseCatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ExpenseCategoryFormDialog.defaultCategories;

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
    ExpenseCategoryFormDialog.showAddEdit(
      context,
      ref,
      item: item,
      categories: _categories,
    );
  }

  void _showAddPatternDialog(ExpenseCatalogModel item) {
    ExpenseCategoryFormDialog.showAddPattern(context, ref, item);
  }

  Future<void> _handleDeactivate(ExpenseCatalogModel item) async {
    final confirm = await AppConfirmDialog.showToggleActive(
      context,
      isCurrentlyActive: true,
      entityName: item.code,
    );
    if (confirm) {
      await ref.read(expenseCatalogProvider.notifier).deactivateItem(item.code);
    }
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
                  _buildCatalogTab(state, isArabic),

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

  Widget _buildCatalogTab(ExpenseCatalogState state, bool isArabic) {
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

          // Items Table via extracted ExpenseCatalogDataTable
          Expanded(
            child: ExpenseCatalogDataTable(
              items: state.items,
              isLoading: state.isLoading,
              onView: (item) => _showAddEditDialog(item: item),
              onEdit: (item) => _showAddEditDialog(item: item),
              onAddPattern: _showAddPatternDialog,
              onDeactivate: _handleDeactivate,
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
                          trailing: RowActionsPill(
                            onDelete: () async {
                              await ref
                                  .read(expenseCatalogProvider.notifier)
                                  .deleteBrokerMapping(mapping.brokerName, mapping.rawItemName);
                            },
                            deleteTooltip: isArabic ? 'حذف الربط' : 'Delete mapping',
                            confirmDelete: true,
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
