import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/enterprise_data_table/enterprise_data_table.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../models/master_item_model.dart';
import '../providers/master_items_provider.dart';
import '../widgets/item_supplier_mapping_dialog.dart';
import '../widgets/master_item_form_dialog.dart';
import '../widgets/master_items_filter_bar.dart';

/// 2️⃣ Master Items Catalog Screen (Type B List / Master Screen - MD-ITEM-001)
/// Standard Master Screen compliant with ui-screen-standards and widget-unification:
/// - Type B: STRICTLY NO Stage Badges, NO Skip Step, NO Stop Shipment buttons.
/// - Header: PageHeader (54-58px height) with exactly 2 top-right actions:
///   1. Add New Item (AppButtonVariant.primary)
///   2. Back to Dashboard (BackToDashboardButton)
/// - Toolbar: Single ActionToolbar row (max 40px height) with text search (200px),
///   category filter, Live Refresh (🔄), and Export to Excel (📗).
/// - Main Content: Unified EnterpriseDataTable<MasterItemModel> exclusively (NO Dual-DataTable hack).
/// - Modals: Isolated Lazy Modals using SearchableDropdownField.
class MasterItemsScreen extends ConsumerStatefulWidget {
  const MasterItemsScreen({super.key});

  @override
  ConsumerState<MasterItemsScreen> createState() => _MasterItemsScreenState();
}

class _MasterItemsScreenState extends ConsumerState<MasterItemsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteItem(MasterItemModel item) async {
    final confirmed = await AppConfirmDialog.showDelete(
      context,
      entityName: '${item.itemCode} - ${item.descriptionAr}',
    );

    if (!mounted) return;
    if (confirmed == true) {
      try {
        await ref.read(masterItemsProvider.notifier).deleteItem(item.itemId);
        if (!mounted) return;
        AppTheme.snackBar(
          context,
          'تم تعطيل الصنف "${item.itemCode}" بنجاح',
          severity: AppSeverity.success,
        );
      } catch (e) {
        if (!mounted) return;
        AppTheme.snackBar(
          context,
          'تعذر تعطيل الصنف: ${e.toString()}',
          severity: AppSeverity.danger,
        );
      }
    }
  }

  Future<void> _exportToExcel(List<MasterItemModel> items) async {
    if (items.isEmpty) {
      AppTheme.snackBar(
        context,
        'لا توجد أصناف مطابقة للتصدير حالياً',
        severity: AppSeverity.warning,
      );
      return;
    }

    final headers = [
      'كود الصنف',
      'الوصف العربي',
      'الوصف الإنجليزي',
      'الفئة',
      'بند التعريفة الجمركية',
      'نسبة الجمارك %',
      'ضريبة القيمة المضافة %',
      'وحدة القياس',
      'نوع التعبئة',
      'الحجم (CBM)',
      'الوزن القائم (كجم)',
      'الوزن الصافي (كجم)',
      'الحالة',
    ];

    final rows = items.map((i) {
      return [
        i.itemCode,
        i.descriptionAr,
        i.descriptionEn ?? '',
        i.productCategory ?? '',
        i.hsCode ?? '',
        i.lastCustomsDutyPct?.toString() ?? '',
        i.lastVatPct?.toString() ?? '',
        i.defaultUom,
        i.defaultPkgType,
        i.cbmPerUnit.toString(),
        i.grossWeightKg.toString(),
        i.netWeightKg.toString(),
        i.isActive ? 'نشط' : 'معطل',
      ];
    }).toList();

    try {
      await TableExportService.exportTableToCsv(
        context: context,
        headers: headers,
        rows: rows,
        stageName: 'Master_Data_Items_Catalog',
        importFileNameOrCode: 'Master_Catalog_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      if (!mounted) return;
      AppTheme.snackBar(
        context,
        'فشل تصدير ملف الإكسل: $e',
        severity: AppSeverity.danger,
      );
    }
  }

  List<EnterpriseColumn<MasterItemModel>> _buildColumns(BuildContext context) {
    return [
      EnterpriseColumn<MasterItemModel>(
        id: 'item_code',
        title: 'كود الصنف',
        width: 160,
        isNumeric: true,
        searchValue: (item) => item.itemCode,
        exportValue: (item) => item.itemCode,
        sortComparator: (a, b) => a.itemCode.compareTo(b.itemCode),
        cellBuilder: (context, item, index) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: AppTheme.cobalt,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.itemCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    color: AppTheme.cobalt,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<MasterItemModel>(
        id: 'description',
        title: 'توصيف الصنف المعتمد',
        flex: 3,
        searchValue: (item) => '${item.descriptionAr} ${item.descriptionEn ?? ''}',
        exportValue: (item) => item.descriptionAr,
        sortComparator: (a, b) => a.descriptionAr.compareTo(b.descriptionAr),
        cellBuilder: (context, item, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.descriptionAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (item.descriptionEn != null && item.descriptionEn!.isNotEmpty)
                Text(
                  item.descriptionEn!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          );
        },
      ),
      EnterpriseColumn<MasterItemModel>(
        id: 'category',
        title: 'الفئة',
        width: 130,
        searchValue: (item) => item.productCategory ?? '',
        exportValue: (item) => item.productCategory ?? '',
        sortComparator: (a, b) => (a.productCategory ?? '').compareTo(b.productCategory ?? ''),
        cellBuilder: (context, item, index) {
          if (item.productCategory == null || item.productCategory!.isEmpty) {
            return const Text('—', style: TextStyle(color: Colors.grey));
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              getCategoryLabelAr(item.productCategory!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
      EnterpriseColumn<MasterItemModel>(
        id: 'tariff',
        title: 'التعريفة والجمارك',
        width: 180,
        searchValue: (item) => item.hsCode ?? '',
        exportValue: (item) => item.hsCode != null ? '${item.hsCode} (Duty: ${item.lastCustomsDutyPct}%)' : '',
        cellBuilder: (context, item, index) {
          if (item.hsCode == null || item.hsCode!.isEmpty) {
            return const Text('غير محدد', style: TextStyle(color: Colors.grey, fontSize: 12));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.hsCode!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
              ),
              if (item.lastCustomsDutyPct != null || item.lastVatPct != null)
                Text(
                  'جمارك: ${item.lastCustomsDutyPct ?? 0}% | ق.م: ${item.lastVatPct ?? 0}%',
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                ),
            ],
          );
        },
      ),
      EnterpriseColumn<MasterItemModel>(
        id: 'uom_pkg',
        title: 'الوحدة والتعبئة',
        width: 130,
        exportValue: (item) => '${item.defaultUom} / ${item.defaultPkgType}',
        cellBuilder: (context, item, index) {
          return Text(
            '${item.defaultUom} / ${item.defaultPkgType}',
            style: const TextStyle(fontSize: 12),
          );
        },
      ),
      EnterpriseColumn<MasterItemModel>(
        id: 'specs',
        title: 'الحجم والأوزان',
        width: 140,
        isNumeric: true,
        exportValue: (item) => '${item.cbmPerUnit} CBM, ${item.grossWeightKg} KG',
        cellBuilder: (context, item, index) {
          return Text(
            '${item.cbmPerUnit} CBM | ${item.grossWeightKg} كجم',
            style: const TextStyle(fontSize: 11.5),
          );
        },
      ),
      EnterpriseColumn<MasterItemModel>(
        id: 'suppliers',
        title: 'الموردون',
        width: 130,
        cellBuilder: (context, item, index) {
          return OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              side: const BorderSide(color: AppTheme.cobaltBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.link_rounded, size: 14, color: AppTheme.cobalt),
            label: const Text(
              'الموردين',
              style: TextStyle(fontSize: 11.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
            ),
            onPressed: () => ItemSupplierMappingDialog.show(context, item: item),
          );
        },
      ),
      EnterpriseColumn<MasterItemModel>(
        id: 'status',
        title: 'الحالة',
        width: 100,
        exportValue: (item) => item.isActive ? 'نشط' : 'معطل',
        sortComparator: (a, b) => a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1),
        cellBuilder: (context, item, index) {
          return AppStatusBadge.fromStatus(
            status: item.isActive ? 'ACTIVE' : 'INACTIVE',
            label: item.isActive ? 'نشط' : 'معطل',
            size: AppStatusBadgeSize.small,
          );
        },
      ),
      EnterpriseColumn<MasterItemModel>(
        id: 'actions',
        title: 'الإجراءات',
        width: 100,
        isLocked: true,
        cellBuilder: (context, item, index) {
          return RowActionsPill(
            onEdit: () => MasterItemFormDialog.show(context, itemToEdit: item),
            onDelete: () => _confirmDeleteItem(item),
            editTooltip: 'تعديل بيانات الصنف',
            deleteTooltip: 'تعطيل الصنف من الكتالوج',
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final density = ref.watch(displayDensityProvider);
    final masterItemsAsync = ref.watch(masterItemsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // ── Header: PageHeader (Type B Standard: 54-58px height, 2 actions max) ──
      appBar: PageHeader(
        icon: Icons.inventory_2_outlined,
        title: 'دليل الأصناف والكتالوج المرجعي',
        subtitle: 'إدارة وتوحيد الأصناف المستوردة، التعريفات الجمركية، وربط الموردين',
        actions: [
          AppButton(
            label: 'إضافة صنف جديد',
            icon: Icons.add,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () => MasterItemFormDialog.show(context),
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
        ],
      ),

      // ── Body ───────────────────────────────────────────────
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── ActionToolbar: Single row, max 40px height ──────
              ActionToolbar(
                searchController: _searchController,
                searchHint: 'بحث بكود الصنف أو التوصيف...',
                onSearchChanged: (val) {
                  ref.read(masterItemsProvider.notifier).setSearchQuery(val);
                },
                filters: const [
                  MasterItemsCategoryFilter(width: 170),
                ],
                quickDataActions: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
                    tooltip: 'تحديث فوري',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () => ref.read(masterItemsProvider.notifier).refresh(),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.table_chart,
                      size: density.buttonIconSize + 2,
                      color: AppTheme.emerald,
                    ),
                    tooltip: 'تصدير إكسل 📗',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () {
                      final items = masterItemsAsync.value?.items ?? [];
                      _exportToExcel(items);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Main Data Table Area ─────────────────────────────
              Expanded(
                child: masterItemsAsync.when(
                  loading: () => const AppLoadingState(),
                  error: (err, _) => AppErrorState(
                    error: err,
                    onRetry: () => ref.read(masterItemsProvider.notifier).refresh(),
                  ),
                  data: (state) {
                    final items = state.items;
                    if (items.isEmpty) {
                      return AppEmptyState(
                        message: 'لا توجد أصناف في الكتالوج مطابقة لشروط البحث',
                        subtitle: state.searchQuery.isNotEmpty
                            ? 'نتيجة البحث عن: "${state.searchQuery}"'
                            : 'انقر على "إضافة صنف جديد" في الأعلى لإضافة أول صنف.',
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceOf(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderOf(context)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: EnterpriseDataTable<MasterItemModel>(
                          storageKey: 'master_items_enterprise_table',
                          data: items,
                          columns: _buildColumns(context),
                          isLoading: false,
                          emptyMessage: 'لا توجد أصناف معروضة',
                          emptyIcon: Icons.inventory_2_outlined,
                          enableExport: true,
                          exportFileName: 'Master_Items_Catalog_${DateTime.now().millisecondsSinceEpoch}.csv',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
