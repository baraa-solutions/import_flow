import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../models/incoterm_model.dart';
import '../providers/incoterms_provider.dart';

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
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, density.buttonHeight),
                        padding: density.buttonPadding,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: Icon(Icons.add, size: density.buttonIconSize),
                      label: Text(
                        l10n.addIncotermBtn,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                      ),
                      onPressed: () => _IncotermsTab.showIncotermDialog(context, ref),
                    )
                  else if (_tabController.index == 1)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, density.buttonHeight),
                        padding: density.buttonPadding,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: Icon(Icons.add, size: density.buttonIconSize),
                      label: Text(
                        l10n.addCostItemBtn,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                      ),
                      onPressed: () => _CostItemsTab.showCostItemDialog(context, ref),
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
                      _IncotermsTab.copyIncotermsTsv(context, incotermsAsync.value ?? []);
                    } else if (_tabController.index == 1) {
                      _CostItemsTab.copyCostItemsTsv(context, costItemsAsync.value ?? []);
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
                        _IncotermsTab.copyIncotermsTsv(context, incotermsAsync.value ?? []);
                      } else if (_tabController.index == 1) {
                        _CostItemsTab.copyCostItemsTsv(context, costItemsAsync.value ?? []);
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
                      content: _IncotermsTab(searchQuery: _searchQuery),
                    ),
                    AdaptiveTabItem(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.incotermsTabCostItems,
                      content: _CostItemsTab(searchQuery: _searchQuery),
                    ),
                    AdaptiveTabItem(
                      icon: Icons.table_chart_outlined,
                      label: l10n.incotermsTabMatrix,
                      content: const _ResponsibilityMatrixTab(),
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

// ==================================================
// Tab 1: Incoterms List
// ==================================================

class _IncotermsTab extends ConsumerWidget {
  final String searchQuery;
  const _IncotermsTab({required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final incotermsAsync = ref.watch(incotermsProvider);

    return incotermsAsync.when(
      loading: () => const AppLoadingState(),
      error: (e, _) => AppErrorState(
        error: e,
        onRetry: () => ref.read(incotermsProvider.notifier).fetchIncoterms(),
      ),
      data: (incoterms) {
        final filtered = searchQuery.isEmpty
            ? incoterms
            : incoterms
                .where((i) =>
                    i.incotermCode.toLowerCase().contains(searchQuery) ||
                    i.incotermName.toLowerCase().contains(searchQuery))
                .toList();
        if (filtered.isEmpty) {
          return AppEmptyState(
            icon: Icons.handshake_outlined,
            message: l10n.noIncotermsFound,
          );
        }
        return _buildIncotermTable(context, ref, filtered);
      },
    );
  }

  static void copyIncotermsTsv(BuildContext context, List<IncotermModel> incoterms) {
    final l10n = context.l10n;
    final headers = [
      l10n.incotermsTsvHeaderCode,
      l10n.incotermsTsvHeaderName,
      l10n.incotermsTsvHeaderVersion,
      l10n.incotermsTsvHeaderDescription,
      l10n.incotermsTsvHeaderStatus,
    ];
    final rows = incoterms.map((i) => [
      i.incotermCode,
      i.incotermName,
      i.version,
      i.description ?? '',
      i.isActive ? l10n.statusActive : l10n.statusInactive,
    ]);
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.incotermsExportTsvSuccess);
  }

  String _buildIncotermSummary(BuildContext context, WidgetRef ref, IncotermModel i) {
    final l10n = context.l10n;
    final matrix = ref.read(responsibilityMatrixProvider).value ?? [];
    final responsibilities = matrix.where((r) => r.incotermId == i.incotermId || r.incotermCode == i.incotermCode).toList();

    final b = StringBuffer();
    b.writeln('📋 ${l10n.incotermsScreenTitle}');
    b.writeln('${l10n.incotermCodeBadgeLabel}${i.incotermCode}');
    b.writeln('${l10n.incotermNameCol}: ${i.incotermName}');
    b.writeln('${l10n.incotermVersionCol}: ${i.version}');
    b.writeln('${l10n.incotermStatusCol}: ${i.isActive ? l10n.statusActive : l10n.statusInactive}');
    if (i.description != null && i.description!.isNotEmpty) {
      b.writeln('${l10n.incotermDescriptionLabel}: ${i.description}');
    }
    if (responsibilities.isNotEmpty) {
      b.writeln('\n${l10n.incotermResponsibilitiesSectionTitle}');
      for (final r in responsibilities) {
        final party = r.responsibleParty == 'Importer'
            ? l10n.partyBuyerImporter
            : (r.responsibleParty == 'Exporter' ? l10n.partySellerExporter : l10n.partyShared);
        final inc = r.includedInIncoterm ? l10n.includedInPriceYes : l10n.includedInPriceNo;
        b.writeln('• ${r.costItemName}: $party ($inc)');
      }
    }
    return b.toString().trim();
  }

  String _buildIncotermRowSummary(AppLocalizations l10n, IncotermModel i) {
    return '${i.incotermCode}\t${i.incotermName}\t${i.version}\t${i.description ?? ""}\t${i.isActive ? l10n.statusActive : l10n.statusInactive}';
  }

  Widget _buildIncotermTable(
      BuildContext context, WidgetRef ref, List<IncotermModel> incoterms) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width > 1100
                    ? MediaQuery.of(context).size.width - 300
                    : 980,
              ),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(190),
                  1: FixedColumnWidth(110),
                  2: FlexColumnWidth(2),
                  3: FixedColumnWidth(120),
                  4: FixedColumnWidth(85),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppTheme.charcoal),
                    children: [
                      l10n.incotermActionsCol,
                      l10n.incotermCodeCol,
                      l10n.incotermNameCol,
                      l10n.incotermVersionCol,
                      l10n.incotermStatusCol,
                    ]
                        .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Text(h,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ))
                        .toList(),
                  ),
                  ...incoterms.asMap().entries.map((entry) {
                    final i = entry.value;
                    final isEven = entry.key % 2 == 0;
                    return TableRow(
                      decoration: BoxDecoration(
                        color: isEven
                            ? AppTheme.surfaceOf(context)
                            : (AppTheme.isDark(context)
                                ? AppTheme.darkSurface
                                : Colors.grey.shade50),
                      ),
                      children: [
                        _cell(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: l10n.incotermCopySummaryBtn,
                                child: InkWell(
                                  onTap: () => CopyHelper.copy(
                                    context,
                                    _buildIncotermSummary(context, ref, i),
                                    customMessage: l10n.incotermCopySummarySuccess,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 5),
                                    margin: const EdgeInsetsDirectional.only(end: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppTheme.emerald.withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(
                                      Icons.copy_all_rounded,
                                      size: 15,
                                      color: AppTheme.emerald,
                                    ),
                                  ),
                                ),
                              ),
                              RowActionsPill(
                                onView: () => showIncotermDialog(context, ref, incoterm: i),
                                onEdit: () => showIncotermDialog(context, ref, incoterm: i),
                                onPrint: () {
                                  final matrix = ref.read(responsibilityMatrixProvider).value ?? [];
                                  MasterDataExportService.printOrSaveIncotermPdf(i, matrix);
                                },
                                printTooltip: l10n.exportIncotermsPdfBtn,
                                onDelete: () async {
                                  final confirm = await AppConfirmDialog.showToggleActive(
                                    context,
                                    isCurrentlyActive: i.isActive,
                                    message: i.isActive
                                        ? l10n.confirmDeactivateIncoterm(i.incotermCode)
                                        : l10n.confirmActivateIncoterm(i.incotermCode),
                                  );
                                  if (confirm == true) {
                                    await ref
                                        .read(incotermsProvider.notifier)
                                        .toggleActive(i.incotermId, i.isActive);
                                  }
                                },
                                deleteTooltip: i.isActive
                                    ? l10n.deactivateIncotermTooltip
                                    : l10n.activateIncotermTooltip,
                              ),
                            ],
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: i.incotermCode,
                            rowSummary: _buildIncotermRowSummary(l10n, i),
                            child: Tooltip(
                              message: l10n.incotermsCopyFieldTooltip,
                              child: InkWell(
                                onTap: () => CopyHelper.copy(context, i.incotermCode),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        i.incotermCode,
                                        style: const TextStyle(
                                            color: AppTheme.cobalt,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy_rounded,
                                          size: 12, color: AppTheme.cobalt),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: '${i.incotermName}${i.description != null ? " - ${i.description}" : ""}',
                            rowSummary: _buildIncotermRowSummary(l10n, i),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.incotermName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.charcoal)),
                                if (i.description != null)
                                  Text(i.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: i.version,
                            rowSummary: _buildIncotermRowSummary(l10n, i),
                            child: Text(i.version,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: i.isActive ? l10n.statusActive : l10n.statusInactive,
                            rowSummary: _buildIncotermRowSummary(l10n, i),
                            child: AppStatusBadge(
                              label: i.isActive ? l10n.statusActive : l10n.statusInactive,
                              severity: i.isActive ? AppSeverity.success : AppSeverity.danger,
                              size: AppStatusBadgeSize.small,
                            ),
                          ),
                        ),

                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void showIncotermDialog(BuildContext context, WidgetRef ref,
      {IncotermModel? incoterm}) {
    final l10n = context.l10n;
    final codeCtrl =
        TextEditingController(text: incoterm?.incotermCode ?? '');
    final nameCtrl =
        TextEditingController(text: incoterm?.incotermName ?? '');
    final versionCtrl =
        TextEditingController(text: incoterm?.version ?? 'Incoterms 2020');
    final descCtrl =
        TextEditingController(text: incoterm?.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(incoterm == null
              ? l10n.addIncotermDialogTitle
              : l10n.editIncotermDialogTitle),
          content: SelectionArea(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.incotermCodeLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () =>
                              CopyHelper.copy(context, codeCtrl.text),
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.requiredField
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.incotermFullNameLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () =>
                              CopyHelper.copy(context, nameCtrl.text),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.requiredField
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: versionCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.incotermVersionLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () =>
                              CopyHelper.copy(context, versionCtrl.text),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.incotermDescriptionLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () =>
                              CopyHelper.copy(context, descCtrl.text),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    if (incoterm != null) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 15),
                            label: Text(l10n.exportIncotermsPdfBtn,
                                style: const TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            onPressed: () {
                              final matrix =
                                  ref.read(responsibilityMatrixProvider).value ??
                                      [];
                              MasterDataExportService.printOrSaveIncotermPdf(
                                  incoterm, matrix);
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.description, size: 15),
                            label: Text(l10n.exportIncotermsExcelBtn,
                                style: const TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            onPressed: () {
                              final matrix =
                                  ref.read(responsibilityMatrixProvider).value ??
                                      [];
                              MasterDataExportService.exportIncotermToExcel(
                                  context, incoterm, matrix);
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      final data = {
                        'incoterm_code': codeCtrl.text.trim().toUpperCase(),
                        'incoterm_name': nameCtrl.text.trim(),
                        'version': versionCtrl.text.trim(),
                        'description': descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                      };
                      String? error;
                      if (incoterm == null) {
                        error = await ref
                            .read(incotermsProvider.notifier)
                            .createIncoterm(data);
                      } else {
                        error = await ref
                            .read(incotermsProvider.notifier)
                            .updateIncoterm(incoterm.incotermId, data);
                      }
                      setDialogState(() => isLoading = false);
                      if (ctx.mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(context, error, severity: AppSeverity.danger),
                          );
                        } else {
                          Navigator.pop(ctx);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(incoterm == null ? l10n.addIncotermBtn : l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell({required Widget child}) => TableRowInkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(alignment: AlignmentDirectional.centerStart, child: child),
        ),
      );
}

// ==================================================
// Tab 2: Cost Items
// ==================================================

class _CostItemsTab extends ConsumerWidget {
  final String searchQuery;
  const _CostItemsTab({required this.searchQuery});

  static const List<String> _categories = [
    'Freight', 'Customs', 'Port', 'Bank', 'Other'
  ];

  static String _getCategoryLabel(AppLocalizations l10n, String category) {
    switch (category) {
      case 'Freight':
        return l10n.costCategoryFreight;
      case 'Customs':
        return l10n.costCategoryCustoms;
      case 'Port':
        return l10n.costCategoryPort;
      case 'Bank':
        return l10n.costCategoryBank;
      default:
        return l10n.costCategoryOther;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final costItemsAsync = ref.watch(costItemsProvider);

    return costItemsAsync.when(
      loading: () => const AppLoadingState(),
      error: (e, _) => AppErrorState(
        error: e,
        onRetry: () => ref.read(costItemsProvider.notifier).fetchCostItems(),
      ),
      data: (items) {
        final filtered = searchQuery.isEmpty
            ? items
            : items
                .where((i) =>
                    i.costItemCode.toLowerCase().contains(searchQuery) ||
                    i.costItemName.toLowerCase().contains(searchQuery) ||
                    i.costCategory.toLowerCase().contains(searchQuery))
                .toList();
        if (filtered.isEmpty) {
          return AppEmptyState(
            icon: Icons.payments_outlined,
            message: l10n.noCostItemsFound,
          );
        }
        return _buildCostItemTable(context, ref, filtered);
      },
    );
  }

  static void copyCostItemsTsv(BuildContext context, List<CostItemModel> items) {
    final l10n = context.l10n;
    final headers = [
      l10n.costItemsTsvHeaderCode,
      l10n.costItemsTsvHeaderName,
      l10n.costItemsTsvHeaderCategory,
      l10n.costItemsTsvHeaderDescription,
      l10n.costItemsTsvHeaderStatus,
    ];
    final rows = items.map((i) => [
      i.costItemCode,
      i.costItemName,
      _getCategoryLabel(l10n, i.costCategory),
      i.description ?? '',
      i.isActive ? l10n.statusActive : l10n.statusInactive,
    ]);
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.costItemsExportTsvSuccess);
  }

  String _buildCostItemSummary(AppLocalizations l10n, CostItemModel item) {
    final b = StringBuffer();
    b.writeln('📋 ${l10n.incotermsTabCostItems}');
    b.writeln('${l10n.costItemCodeBadgeLabel}${item.costItemCode}');
    b.writeln('${l10n.costItemNameCol}: ${item.costItemName}');
    b.writeln('${l10n.costItemCategoryCol}: ${_getCategoryLabel(l10n, item.costCategory)}');
    b.writeln('${l10n.costItemStatusCol}: ${item.isActive ? l10n.statusActive : l10n.statusInactive}');
    if (item.description != null && item.description!.isNotEmpty) {
      b.writeln('${l10n.costItemDescriptionLabel}: ${item.description}');
    }
    return b.toString().trim();
  }

  String _buildCostItemRowSummary(AppLocalizations l10n, CostItemModel item) {
    return '${item.costItemCode}\t${item.costItemName}\t${_getCategoryLabel(l10n, item.costCategory)}\t${item.description ?? ""}\t${item.isActive ? l10n.statusActive : l10n.statusInactive}';
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Freight':
        return AppTheme.cobalt;
      case 'Customs':
        return AppTheme.orange;
      case 'Port':
        return const Color(0xFF8E44AD);
      case 'Bank':
        return AppTheme.emerald;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCostItemTable(
      BuildContext context, WidgetRef ref, List<CostItemModel> items) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width > 1100
                    ? MediaQuery.of(context).size.width - 300
                    : 950,
              ),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(190),
                  1: FixedColumnWidth(110),
                  2: FlexColumnWidth(2),
                  3: FixedColumnWidth(130),
                  4: FixedColumnWidth(85),
                },
                children: [
              TableRow(
                decoration: const BoxDecoration(color: AppTheme.charcoal),
                children: [
                  l10n.costItemActionsCol,
                  l10n.costItemCodeCol,
                  l10n.costItemNameCol,
                  l10n.costItemCategoryCol,
                  l10n.costItemStatusCol,
                ]
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Text(h,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ))
                    .toList(),
              ),
              ...items.asMap().entries.map((entry) {
                final item = entry.value;
                final isEven = entry.key % 2 == 0;
                final catColor = _categoryColor(item.costCategory);
                return TableRow(
                  decoration: BoxDecoration(
                      color: isEven
                          ? AppTheme.surfaceOf(context)
                          : (AppTheme.isDark(context)
                              ? AppTheme.darkSurface
                              : Colors.grey.shade50)),
                  children: [
                    _cell(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: l10n.costItemCopySummaryBtn,
                            child: InkWell(
                              onTap: () => CopyHelper.copy(
                                context,
                                _buildCostItemSummary(l10n, item),
                                customMessage: l10n.costItemCopySummarySuccess,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 5),
                                margin: const EdgeInsetsDirectional.only(end: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppTheme.emerald.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(
                                  Icons.copy_all_rounded,
                                  size: 15,
                                  color: AppTheme.emerald,
                                ),
                              ),
                            ),
                          ),
                          RowActionsPill(
                            onView: () => showCostItemDialog(context, ref, item: item),
                            onEdit: () => showCostItemDialog(context, ref, item: item),
                            onPrint: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                AppTheme.snackBar(
                                  context,
                                  l10n.printCostItemSnack(item.costItemCode, item.costItemName),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            onDelete: () async {
                              final confirm = await AppConfirmDialog.showToggleActive(
                                context,
                                isCurrentlyActive: item.isActive,
                                message: item.isActive
                                    ? l10n.confirmDeactivateCostItem(item.costItemCode)
                                    : l10n.confirmActivateCostItem(item.costItemCode),
                              );
                              if (confirm == true) {
                                await ref.read(costItemsProvider.notifier).toggleActive(item.costItemId, item.isActive);
                              }
                            },
                            deleteTooltip: item.isActive ? l10n.deactivateCostItemTooltip : l10n.activateCostItemTooltip,
                          ),
                        ],
                      ),
                    ),
                    _cell(
                      child: CopyableTableCell(
                        value: item.costItemCode,
                        rowSummary: _buildCostItemRowSummary(l10n, item),
                        child: Tooltip(
                          message: l10n.incotermsCopyFieldTooltip,
                          child: InkWell(
                            onTap: () => CopyHelper.copy(context, item.costItemCode),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(item.costItemCode,
                                      style: TextStyle(
                                          color: catColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.copy_rounded,
                                      size: 11, color: catColor),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _cell(
                      child: CopyableTableCell(
                        value: '${item.costItemName}${item.description != null ? " - ${item.description}" : ""}',
                        rowSummary: _buildCostItemRowSummary(l10n, item),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.costItemName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.charcoal)),
                            if (item.description != null)
                              Text(item.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                    _cell(
                      child: CopyableTableCell(
                        value: _getCategoryLabel(l10n, item.costCategory),
                        rowSummary: _buildCostItemRowSummary(l10n, item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_getCategoryLabel(l10n, item.costCategory),
                              style: TextStyle(
                                  color: catColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                      ),
                    ),
                    _cell(
                      child: CopyableTableCell(
                        value: item.isActive ? l10n.statusActive : l10n.statusInactive,
                        rowSummary: _buildCostItemRowSummary(l10n, item),
                        child: AppStatusBadge(
                          label: item.isActive ? l10n.statusActive : l10n.statusInactive,
                          severity: item.isActive ? AppSeverity.success : AppSeverity.danger,
                          size: AppStatusBadgeSize.small,
                        ),
                      ),
                    ),

                  ],
                );
              }),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  static void showCostItemDialog(BuildContext context, WidgetRef ref,
      {CostItemModel? item}) {
    final l10n = context.l10n;
    final codeCtrl = TextEditingController(text: item?.costItemCode ?? '');
    final nameCtrl = TextEditingController(text: item?.costItemName ?? '');
    String selectedCategory = item?.costCategory ?? 'Freight';
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(item == null ? l10n.addCostItemDialogTitle : l10n.editCostItemDialogTitle),
          content: SelectionArea(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.costItemCodeLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, codeCtrl.text),
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.costItemNameLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, nameCtrl.text),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: selectedCategory,
                      labelText: l10n.costCategoryLabel,
                      items: _categories
                          .map((c) => SearchableDropdownItem<String>(value: c, label: _getCategoryLabel(l10n, c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.costItemDescriptionLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, descCtrl.text),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      final data = {
                        'cost_item_code': codeCtrl.text.trim().toUpperCase(),
                        'cost_item_name': nameCtrl.text.trim(),
                        'cost_category': selectedCategory,
                        'description': descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                      };
                      String? error;
                      if (item == null) {
                        error = await ref
                            .read(costItemsProvider.notifier)
                            .createCostItem(data);
                      } else {
                        error = await ref
                            .read(costItemsProvider.notifier)
                            .updateCostItem(item.costItemId, data);
                      }
                      setDialogState(() => isLoading = false);
                      if (ctx.mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(context, error, severity: AppSeverity.danger),
                          );
                        } else {
                          Navigator.pop(ctx);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(item == null ? l10n.addCostItemBtn : l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell({required Widget child}) => TableRowInkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(alignment: AlignmentDirectional.centerStart, child: child),
        ),
      );
}

// ==================================================
// Tab 3: Responsibility Matrix
// ==================================================

class _ResponsibilityMatrixTab extends ConsumerStatefulWidget {
  const _ResponsibilityMatrixTab();

  @override
  ConsumerState<_ResponsibilityMatrixTab> createState() =>
      _ResponsibilityMatrixTabState();
}

class _ResponsibilityMatrixTabState
    extends ConsumerState<_ResponsibilityMatrixTab> {
  int? _selectedIncotermId;

  static String _getCategoryLabel(AppLocalizations l10n, String category) {
    switch (category) {
      case 'Freight':
        return l10n.costCategoryFreight;
      case 'Customs':
        return l10n.costCategoryCustoms;
      case 'Port':
        return l10n.costCategoryPort;
      case 'Bank':
        return l10n.costCategoryBank;
      default:
        return l10n.costCategoryOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final incotermsAsync = ref.watch(incotermsProvider);
    final matrixAsync = ref.watch(responsibilityMatrixProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Incoterm selector dropdown & header actions
        incotermsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (incoterms) {
            final active = incoterms.where((i) => i.isActive).toList();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(l10n.filterByIncotermLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: SearchableDropdownField<int?>(
                        value: _selectedIncotermId,
                        hintText: l10n.allIncotermsOption,
                        items: [
                          SearchableDropdownItem<int?>(
                              value: null, label: l10n.allIncotermsOption),
                          ...active.map((i) => SearchableDropdownItem<int?>(
                                value: i.incotermId,
                                label: '${i.incotermCode} - ${i.incotermName}',
                              )),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedIncotermId = val),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: Text(l10n.matrixExportTsvBtn),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.cobalt,
                        side: const BorderSide(color: AppTheme.cobalt),
                      ),
                      onPressed: () {
                        final matrix = ref.read(responsibilityMatrixProvider).value ?? [];
                        final filtered = _selectedIncotermId == null
                            ? matrix
                            : matrix.where((r) => r.incotermId == _selectedIncotermId).toList();
                        _copyMatrixTsv(context, filtered);
                      },
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedIncotermId == null
                          ? l10n.showingAllMatrixResponsibilities
                          : l10n.filteringResponsibilitiesForSelectedTerm,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // Matrix table
        Expanded(
          child: matrixAsync.when(
            loading: () => const AppLoadingState(),
            error: (e, _) => AppErrorState(
              error: e,
              onRetry: () => ref.read(responsibilityMatrixProvider.notifier).fetchAll(),
            ),
            data: (matrix) {
              final filtered = _selectedIncotermId == null
                  ? matrix
                  : matrix
                      .where((r) => r.incotermId == _selectedIncotermId)
                      .toList();
              if (filtered.isEmpty) {
                return AppEmptyState(
                  icon: Icons.table_chart_outlined,
                  message: l10n.noMatrixDataFound,
                );
              }
              return _buildMatrixTable(filtered);
            },
          ),
        ),
      ],
    );
  }

  void _copyMatrixTsv(BuildContext context, List<IncotermResponsibilityModel> matrix) {
    final l10n = context.l10n;
    final headers = [
      l10n.matrixTsvHeaderIncoterm,
      l10n.matrixTsvHeaderCostItem,
      l10n.matrixTsvHeaderCategory,
      l10n.matrixTsvHeaderResponsible,
      l10n.matrixTsvHeaderIncluded,
      l10n.matrixTsvHeaderNotes,
    ];
    final rows = matrix.map((r) {
      final party = r.responsibleParty == 'Importer'
          ? l10n.partyBuyerImporter
          : (r.responsibleParty == 'Exporter' ? l10n.partySellerExporter : l10n.partyShared);
      return [
        r.incotermCode ?? '',
        r.costItemName ?? '',
        _getCategoryLabel(l10n, r.costCategory ?? ''),
        party,
        r.includedInIncoterm ? l10n.includedInPriceYes : l10n.includedInPriceNo,
        r.notes ?? '',
      ];
    });
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.matrixExportTsvSuccess);
  }

  String _buildMatrixRowSummary(AppLocalizations l10n, IncotermResponsibilityModel r) {
    final party = r.responsibleParty == 'Importer'
        ? l10n.partyBuyerImporter
        : (r.responsibleParty == 'Exporter' ? l10n.partySellerExporter : l10n.partyShared);
    final inc = r.includedInIncoterm ? l10n.includedInPriceYes : l10n.includedInPriceNo;
    return '${r.incotermCode ?? ""}\t${r.costItemName ?? ""}\t${_getCategoryLabel(l10n, r.costCategory ?? "")}\t$party\t$inc\t${r.notes ?? ""}';
  }

  Widget _buildMatrixTable(List<IncotermResponsibilityModel> matrix) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width > 1100
                    ? MediaQuery.of(context).size.width - 300
                    : 1000,
              ),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(110),
                  1: FixedColumnWidth(100),
                  2: FlexColumnWidth(2),
                  3: FixedColumnWidth(120),
                  4: FixedColumnWidth(160),
                  5: FixedColumnWidth(100),
                  6: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppTheme.charcoal),
                    children: [
                      l10n.matrixActionsCol,
                      l10n.matrixIncotermCol,
                      l10n.matrixCostItemCol,
                      l10n.matrixCategoryCol,
                      l10n.matrixResponsibleCol,
                      l10n.matrixIncludedCol,
                      l10n.matrixNotesCol,
                    ]
                        .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Text(h,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ))
                        .toList(),
                  ),
                  ...matrix.asMap().entries.map((entry) {
                    final r = entry.value;
                    final isEven = entry.key % 2 == 0;
                    final partySeverity = switch (r.responsibleParty) {
                      'Importer' => AppSeverity.info,
                      'Exporter' => AppSeverity.warning,
                      _ => AppSeverity.success,
                    };
                    final partyText = switch (r.responsibleParty) {
                      'Importer' => l10n.partyBuyerImporter,
                      'Exporter' => l10n.partySellerExporter,
                      _ => l10n.partyShared,
                    };
                    return TableRow(
                      decoration: BoxDecoration(
                          color: isEven
                              ? AppTheme.surfaceOf(context)
                              : (AppTheme.isDark(context)
                                  ? AppTheme.darkSurface
                                  : Colors.grey.shade50)),
                      children: [
                        _cell(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: l10n.matrixCopySummaryBtn,
                                child: InkWell(
                                  onTap: () => CopyHelper.copy(
                                    context,
                                    _buildMatrixRowSummary(l10n, r),
                                    customMessage: l10n.matrixCopySummarySuccess,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 5),
                                    margin: const EdgeInsetsDirectional.only(end: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppTheme.emerald.withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(
                                      Icons.copy_all_rounded,
                                      size: 15,
                                      color: AppTheme.emerald,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: AppTheme.cobalt, size: 20),
                                tooltip: l10n.editResponsibilityTooltip,
                                onPressed: () =>
                                    _showEditResponsibilityDialog(context, ref, r),
                              ),
                            ],
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: r.incotermCode ?? '',
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(r.incotermCode ?? '—',
                                  style: const TextStyle(
                                      color: AppTheme.cobalt,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: r.costItemName ?? '',
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Text(r.costItemName ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.charcoal)),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: _getCategoryLabel(l10n, r.costCategory ?? ''),
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Text(_getCategoryLabel(l10n, r.costCategory ?? ''),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade700)),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: partyText,
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: AppStatusBadge(
                              label: partyText,
                              severity: partySeverity,
                              size: AppStatusBadgeSize.small,
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: r.includedInIncoterm ? l10n.includedInPriceYes : l10n.includedInPriceNo,
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Icon(
                              r.includedInIncoterm
                                  ? Icons.check_circle
                                  : Icons.remove_circle_outline,
                              color: r.includedInIncoterm
                                  ? AppTheme.emerald
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: r.notes ?? '',
                            rowSummary: _buildMatrixRowSummary(l10n, r),
                            child: Text(
                              r.notes ?? '—',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        ),

                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditResponsibilityDialog(
      BuildContext context, WidgetRef ref, IncotermResponsibilityModel r) {
    final l10n = context.l10n;
    String selectedParty = r.responsibleParty;
    bool isIncluded = r.includedInIncoterm;
    final notesCtrl = TextEditingController(text: r.notes ?? '');
    bool isLoading = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Text(l10n.editResponsibilityDialogTitle(r.incotermCode ?? '')),
            ],
          ),
          content: SelectionArea(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.incotermPrefix(r.incotermCode ?? '—'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded,
                                    size: 14, color: AppTheme.cobalt),
                                tooltip: l10n.incotermsCopyFieldTooltip,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    CopyHelper.copy(context, r.incotermCode ?? ''),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                    l10n.costItemPrefix(r.costItemName ?? '—',
                                        _getCategoryLabel(l10n, r.costCategory ?? '—')),
                                    style: TextStyle(
                                        color: Colors.grey.shade700, fontSize: 12)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded,
                                    size: 14, color: AppTheme.cobalt),
                                tooltip: l10n.incotermsCopyFieldTooltip,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    CopyHelper.copy(context, r.costItemName ?? ''),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: selectedParty,
                      labelText: l10n.matrixResponsiblePartyFieldLabel,
                      items: [
                        SearchableDropdownItem<String>(
                            value: 'Importer',
                            label: l10n.partyBuyerImporter),
                        SearchableDropdownItem<String>(
                            value: 'Exporter',
                            label: l10n.partySellerExporter),
                        SearchableDropdownItem<String>(
                            value: 'Shared', label: l10n.partyShared),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedParty = val;
                            if (val == 'Exporter') {
                              isIncluded = true;
                            } else if (val == 'Importer') {
                              isIncluded = false;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l10n.includedInSellerPriceTitle,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                          l10n.includedInSellerPriceSubtitle,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      value: isIncluded,
                      activeThumbColor: AppTheme.emerald,
                      onChanged: (val) => setDialogState(() => isIncluded = val),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.commentNotesLabel,
                        hintText: l10n.commentNotesHint,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () =>
                              CopyHelper.copy(context, notesCtrl.text),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      final data = {
                        'responsible_party': selectedParty,
                        'included_in_incoterm': isIncluded,
                        'notes': notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      };

                      final error = await ref
                          .read(responsibilityMatrixProvider.notifier)
                          .updateResponsibility(r.responsibilityId, data);
                      ref.read(responsibilityMatrixProvider.notifier).fetchAll();

                      setDialogState(() => isLoading = false);
                      if (ctx.mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(context, error, severity: AppSeverity.danger),
                          );
                        } else {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(context, l10n.updatedSuccessfully, severity: AppSeverity.success),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(l10n.saveChanges),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell({required Widget child}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Align(alignment: AlignmentDirectional.centerStart, child: child),
      );
}
