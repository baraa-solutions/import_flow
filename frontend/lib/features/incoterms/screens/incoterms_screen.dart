import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/incoterms_provider.dart';
import '../widgets/cost_items_tab.dart';
import '../widgets/incoterm_edit_dialog.dart';
import '../widgets/incoterms_data_table.dart';
import '../widgets/incoterms_tab.dart';
import '../widgets/responsibility_matrix_tab.dart';

/// الشاشة الرئيسية المنسقة للشروط الدولية (Incoterms) وبنود التكلفة ومصفوفة المسؤوليات
class IncotermsScreen extends ConsumerStatefulWidget {
  const IncotermsScreen({super.key});

  @override
  ConsumerState<IncotermsScreen> createState() => _IncotermsScreenState();
}

class _IncotermsScreenState extends ConsumerState<IncotermsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    // Live reload on mount — guard against duplicate fetches
    if (!ref.read(incotermsProvider).isLoading) {
      Future.microtask(
          () => ref.read(incotermsProvider.notifier).fetchIncoterms());
    }
    if (!ref.read(costItemsProvider).isLoading) {
      Future.microtask(
          () => ref.read(costItemsProvider.notifier).fetchCostItems());
    }
    if (!ref.read(responsibilityMatrixProvider).isLoading) {
      Future.microtask(
          () => ref.read(responsibilityMatrixProvider.notifier).fetchAll());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showInactiveIncoterms = ref.watch(showInactiveIncotermsProvider);
    final showInactiveCostItems = ref.watch(showInactiveCostItemsProvider);
    final incotermsAsync = ref.watch(incotermsProvider);
    final costItemsAsync = ref.watch(costItemsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffoldBackground : AppTheme.cloudWhite,
      appBar: PageHeader(
        icon: Icons.handshake_outlined,
        title: l10n.incotermsScreenTitle,
        subtitle: l10n.incotermsScreenSubtitle,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActionToolbar(
                primaryActions: [
                  if (_tabController.index == 0)
                    AppButton(
                      label: l10n.addIncotermBtn,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      icon: Icons.add,
                      onPressed: () => IncotermEditDialog.show(context),
                    )
                  else if (_tabController.index == 1)
                    AppButton(
                      label: l10n.addCostItemBtn,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      icon: Icons.add,
                      onPressed: () => CostItemsTab.showCostItemDialog(context, ref),
                    ),
                ],
                moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
                  context: context,
                  includeTsv: true,
                ),
                onMoreActionSelected: (val) => MasterDataActionHelper.handleStandardAction(
                  context: context,
                  ref: ref,
                  actionValue: val,
                  moduleEndpoint: 'incoterms',
                  entityNameAr: 'شروط الشحن الدولية',
                  entityNameEn: 'Incoterms Rules',
                  entityFilePrefix: 'Incoterms_Rules',
                  onImportSuccess: () {
                    ref.read(incotermsProvider.notifier).fetchIncoterms();
                    ref.read(costItemsProvider.notifier).fetchCostItems();
                    ref.read(responsibilityMatrixProvider.notifier).fetchAll();
                  },
                  onCopyTsv: () {
                    if (_tabController.index == 0) {
                      IncotermsDataTable.copyIncotermsTsv(context, incotermsAsync.value ?? []);
                    } else if (_tabController.index == 1) {
                      CostItemsTab.copyCostItemsTsv(context, costItemsAsync.value ?? []);
                    }
                  },
                ),
                searchController: _searchController,
                searchHint: l10n.searchIncotermsHint,
                onSearchChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                filters: [
                  if (_tabController.index == 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.showInactiveIncotermsLabel,
                          style: TextStyle(
                            fontSize: density.buttonFontSize - 1,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: showInactiveIncoterms,
                            activeThumbColor: AppTheme.cobalt,
                            onChanged: (val) {
                              ref.read(showInactiveIncotermsProvider.notifier).state = val;
                            },
                          ),
                        ),
                      ],
                    )
                  else if (_tabController.index == 1)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.showInactiveCostItemsLabel,
                          style: TextStyle(
                            fontSize: density.buttonFontSize - 1,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: showInactiveCostItems,
                            activeThumbColor: AppTheme.cobalt,
                            onChanged: (val) {
                              ref.read(showInactiveCostItemsProvider.notifier).state = val;
                            },
                          ),
                        ),
                      ],
                    ),
                ],
                quickDataActions: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
                    tooltip: l10n.liveRefresh,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () {
                      ref.read(incotermsProvider.notifier).fetchIncoterms();
                      ref.read(costItemsProvider.notifier).fetchCostItems();
                      ref.read(responsibilityMatrixProvider.notifier).fetchAll();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                    tooltip: l10n.incotermsExportTsvBtn,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () {
                      if (_tabController.index == 0) {
                        IncotermsDataTable.copyIncotermsTsv(context, incotermsAsync.value ?? []);
                      } else if (_tabController.index == 1) {
                        CostItemsTab.copyCostItemsTsv(context, costItemsAsync.value ?? []);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Adaptive Tab Navigation
              Expanded(
                child: AdaptiveTabScaffold(
                  controller: _tabController,
                  tabs: [
                    AdaptiveTabItem(
                      icon: Icons.handshake_outlined,
                      label: l10n.incotermsTabRules,
                      content: IncotermsTab(searchQuery: _searchQuery),
                    ),
                    AdaptiveTabItem(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.incotermsTabCostItems,
                      content: CostItemsTab(searchQuery: _searchQuery),
                    ),
                    AdaptiveTabItem(
                      icon: Icons.table_chart_outlined,
                      label: l10n.incotermsTabMatrix,
                      content: const ResponsibilityMatrixTab(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
