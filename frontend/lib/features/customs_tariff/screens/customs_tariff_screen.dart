import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';
import '../widgets/duty_calculator_dialog.dart';
import '../widgets/nafeza_details_dialog.dart';
import '../widgets/tariff_form_dialog.dart';
import 'hs_code_search_screen.dart';

class CustomsTariffScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const CustomsTariffScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<CustomsTariffScreen> createState() =>
      _CustomsTariffScreenState();
}

class _CustomsTariffScreenState extends ConsumerState<CustomsTariffScreen> {
  final TextEditingController _searchController = TextEditingController();
  late int _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTabIndex;
    if (!ref.read(customsTariffProvider).isLoading) {
      Future.microtask(() {
        ref.read(customsTariffProvider.notifier).fetchTariffs();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CustomsTariffScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      setState(() => _currentTab = widget.initialTabIndex);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tariffsAsync = ref.watch(customsTariffProvider);
    final showInactive = ref.watch(showInactiveCustomsTariffsProvider);

    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.cloudWhite,
      appBar: PageHeader(
        icon: Icons.receipt_long_outlined,
        title: l10n.customsTariffScreenTitle,
        subtitle: l10n.customsTariffScreenSubtitle,
        actions: [
          SegmentedButton<int>(
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.cobalt;
                }
                return Colors.white12;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.white70;
              }),
            ),
            segments: [
              ButtonSegment(
                value: 0,
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: Text(l10n.customsTariffScreenTitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              ButtonSegment(
                value: 1,
                icon: const Icon(Icons.saved_search, size: 16),
                label: Text(l10n.hsExplorerBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
            selected: {_currentTab},
            onSelectionChanged: (set) => setState(() => _currentTab = set.first),
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: _currentTab == 1
            ? HsCodeSearchScreen(
                key: const ValueKey('hs_explorer_tab_view'),
                initialQuery: _searchController.text,
                isEmbedded: true,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ActionToolbar(
                      primaryActions: [
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
                            l10n.addTariffManualBtn,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                          ),
                          onPressed: () => showTariffDialog(context, ref, initialModeIndex: 1),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.orange,
                            foregroundColor: Colors.white,
                            minimumSize: Size(0, density.buttonHeight),
                            padding: density.buttonPadding,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: Icon(Icons.auto_fix_high, size: density.buttonIconSize),
                          label: Text(
                            l10n.smartNafezaDiffEngineBtn,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                          ),
                          onPressed: () => showTariffDialog(context, ref, initialModeIndex: 0),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            minimumSize: Size(0, density.buttonHeight),
                            padding: density.buttonPadding,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: Icon(Icons.calculate, size: density.buttonIconSize),
                          label: Text(
                            l10n.dutyCalculatorBtn,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                          ),
                          onPressed: () => showDutyCalculatorDialog(context, ref),
                        ),
                      ],
                      moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
                        context: context,
                        includeTsv: (tariffsAsync.valueOrNull ?? []).isNotEmpty,
                      ),
                      onMoreActionSelected: (val) {
                        if (val == 'import_excel') {
                          _handleExcelImport(context, ref);
                        } else {
                          MasterDataActionHelper.handleStandardAction(
                            context: context,
                            ref: ref,
                            actionValue: val,
                            moduleEndpoint: 'customs-tariff',
                            entityNameAr: 'التعريفة الجمركية',
                            entityNameEn: 'Customs Tariff Schedule',
                            entityFilePrefix: 'Customs_Tariff_Schedule',
                            onCopyTsv: () => _copyTariffsTsv(context, tariffsAsync.valueOrNull ?? []),
                          );
                        }
                      },
                      searchController: _searchController,
                      searchHint: l10n.searchTariffsHint,
                      onSearchChanged: (val) {
                        ref.read(customsTariffSearchQueryProvider.notifier).state = val.trim();
                      },
                      filters: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.showInactiveTariffsLabel,
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
                                value: showInactive,
                                activeThumbColor: AppTheme.cobalt,
                                onChanged: (val) {
                                  ref.read(showInactiveCustomsTariffsProvider.notifier).state = val;
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
                          onPressed: () => ref.read(customsTariffProvider.notifier).fetchTariffs(),
                        ),
                        if ((tariffsAsync.valueOrNull ?? []).isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                            tooltip: l10n.customsTariffExportTsvBtn,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth: density.buttonHeight,
                              minHeight: density.buttonHeight,
                            ),
                            onPressed: () => _copyTariffsTsv(context, tariffsAsync.valueOrNull ?? []),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: tariffsAsync.when(
                        loading: () => const AppLoadingState(),
                        error: (e, _) => AppErrorState(
                          error: e,
                          onRetry: () => ref.read(customsTariffProvider.notifier).fetchTariffs(),
                        ),
                data: (tariffs) {
                  final query = _searchController.text.trim().toLowerCase().replaceAll('.', '');
                  final filteredTariffs = query.isEmpty
                      ? tariffs
                      : tariffs.where((t) {
                          final hsClean = t.hsCode.toLowerCase().replaceAll('.', '');
                          final desc = t.hsDescription.toLowerCase();
                          final cat = t.categorySearchText;
                          final auth = (t.regulatoryAuthority ?? '').toLowerCase();
                          final note = (t.priorApprovalNote ?? '').toLowerCase();
                          return hsClean.contains(query) ||
                              desc.contains(query) ||
                              cat.contains(query) ||
                              auth.contains(query) ||
                              note.contains(query);
                        }).toList();

                  if (filteredTariffs.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: _searchController.text.isNotEmpty
                          ? l10n.noTariffsMatchingQuery(_searchController.text)
                          : l10n.noTariffsFound,
                    );
                  }
                  return _buildTariffTable(context, ref, filteredTariffs);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Color _getCategoryColor(String? category) {
    // CUSTOMS_CATEGORY codes first, then the older free-text names.
    switch (category) {
      case 'ELECTRONICS':
        return AppTheme.cobalt;
      case 'AUTOMOTIVE':
      case 'AUTOMOTIVE_SPARE_PARTS':
        return AppTheme.orange;
      case 'PHARMACEUTICALS':
        return AppTheme.emerald;
      case 'FOOD_AGRICULTURAL':
        return const Color(0xFF27AE60);
      case 'Electronics':
        return AppTheme.cobalt;
      case 'Automotive':
      case 'Automotive Parts':
        return AppTheme.orange;
      case 'Pharmaceuticals':
        return AppTheme.emerald;
      case 'Agriculture & Food':
        return const Color(0xFF27AE60);
      case 'Luxury Goods':
        return AppTheme.crimson;
      case 'Home Appliances':
        return const Color(0xFF8E44AD);
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildTariffTable(
      BuildContext context, WidgetRef ref, List<CustomsTariffModel> tariffs) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 1180 ? 1180.0 : constraints.maxWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderOf(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FixedColumnWidth(210),
                      1: FixedColumnWidth(140),
                      2: FlexColumnWidth(3),
                      3: FixedColumnWidth(140),
                      4: FixedColumnWidth(180),
                      5: FixedColumnWidth(140),
                      6: FixedColumnWidth(90),
                    },
                    children: [
                  // Header Row
                  TableRow(
                    decoration: const BoxDecoration(color: AppTheme.charcoal),
                    children: [
                      l10n.tariffActionsCol,
                      l10n.tariffHsCodeCol,
                      l10n.tariffDescAndAuthorityCol,
                      l10n.tariffCategoryCol,
                      l10n.tariffTaxRatesBreakdownCol,
                      l10n.tariffRequirementsCol,
                      l10n.tariffStatusCol,
                    ]
                        .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ))
                        .toList(),
                  ),

                  // Data Rows
                  ...tariffs.asMap().entries.map((entry) {
                    final tariff = entry.value;
                    final isEven = entry.key % 2 == 0;
                    final catColor = _getCategoryColor(tariff.customsCategory);
                    final rowSummary = _buildTariffRowSummary(l10n, tariff);

                    final reqsList = <String>[];
                    if (tariff.requiresAcid) reqsList.add('ACID');
                    if (tariff.requiresCoo) reqsList.add('COO');
                    if (tariff.requiresInspection) reqsList.add('INSP');
                    final reqsStr = reqsList.join(', ');

                    final taxRatesStr = [
                      'Duty: ${tariff.customsDutyRate}%',
                      'VAT: ${tariff.vatRate}%',
                      if (tariff.scheduleTaxRate > 0) 'Sched: ${tariff.scheduleTaxRate}%',
                      if (tariff.developmentFeeRate > 0) 'Dev: ${tariff.developmentFeeRate}%',
                    ].join(', ');

                    return TableRow(
                      decoration: BoxDecoration(
                        color: isEven
                            ? AppTheme.surfaceOf(context)
                            : (isDark ? AppTheme.darkCardBackground : Colors.grey.shade50),
                      ),
                      children: [
                        // Actions: Quick Copy Summary, View, Edit, Print, Delete
                        _cell(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_all_rounded,
                                    size: 18, color: AppTheme.cobalt),
                                tooltip: l10n.tariffCopySummaryBtn,
                                onPressed: () =>
                                    _copySingleTariffSummary(context, tariff),
                                visualDensity: VisualDensity.compact,
                              ),
                              RowActionsPill(
                                onView: () => showNafezaDetailsDialog(context, ref, tariff),
                                onEdit: () => showTariffDialog(context, ref, tariff: tariff),
                                onPrint: () async {
                                  final agreements = await ref
                                      .read(customsTariffProvider.notifier)
                                      .fetchAgreements(tariff.hsCode);
                                  if (context.mounted) {
                                    await MasterDataExportService.printOrSaveTariffPdf(
                                        tariff, agreements);
                                  }
                                },
                                onDelete: () async {
                                  final isActive = tariff.isActive;
                                  final confirm = await AppConfirmDialog.showToggleActive(
                                    context,
                                    isCurrentlyActive: isActive,
                                    message: isActive
                                        ? l10n.confirmDeactivateTariff(tariff.hsCode)
                                        : l10n.confirmActivateTariff(tariff.hsCode),
                                    confirmLabel: isActive ? l10n.deactivateBtn : l10n.activateBtn,
                                    cancelLabel: l10n.cancel,
                                  );
                                  if (confirm == true) {
                                    await ref
                                        .read(customsTariffProvider.notifier)
                                        .toggleActive(tariff.tariffId, tariff.isActive);
                                  }
                                },
                                deleteTooltip: tariff.isActive ? l10n.deactivateTariffTooltip : l10n.activateTariffTooltip,
                              ),
                            ],
                          ),
                        ),
                        // HS Code Badge
                        _cell(
                          value: tariff.hsCode,
                          rowSummary: rowSummary,
                          child: InkWell(
                            onTap: () =>
                                showNafezaDetailsDialog(context, ref, tariff),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppTheme.cobalt.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tariff.hsCode,
                                    style: const TextStyle(
                                      color: AppTheme.cobalt,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => CopyHelper.copy(context, tariff.hsCode),
                                    child: const Icon(Icons.copy_rounded,
                                        size: 12, color: AppTheme.cobalt),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Description & Regulatory Authority
                        _cell(
                          value: '${tariff.hsDescription}${tariff.regulatoryAuthority != null ? " - ${tariff.regulatoryAuthority}" : ""}',
                          rowSummary: rowSummary,
                          child: InkWell(
                            onTap: () =>
                                showNafezaDetailsDialog(context, ref, tariff),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tariff.hsDescription,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.charcoal,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (tariff.regulatoryAuthority != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      l10n.govAuthorityPrefix(tariff.regulatoryAuthority!),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Category
                        _cell(
                          value: tariff.categoryLabel(l10n) ?? '—',
                          rowSummary: rowSummary,
                          child: tariff.customsCategory != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    tariff.categoryLabel(l10n) ?? tariff.customsCategory!,
                                    style: TextStyle(
                                      color: catColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
                              : const Text('—',
                                  style: TextStyle(color: Colors.grey)),
                        ),

                        // Tax Rates Breakdown
                        _cell(
                          value: taxRatesStr,
                          rowSummary: rowSummary,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              _rateBadge(l10n.rateDutyBadge('${tariff.customsDutyRate}%'),
                                  AppTheme.cobalt),
                              _rateBadge(l10n.rateVatBadge('${tariff.vatRate}%'),
                                  AppTheme.emerald),
                              if (tariff.scheduleTaxRate > 0)
                                _rateBadge(
                                    l10n.rateSchedBadge('${tariff.scheduleTaxRate}%'),
                                    AppTheme.crimson),
                              if (tariff.developmentFeeRate > 0)
                                _rateBadge(
                                    l10n.rateDevBadge('${tariff.developmentFeeRate}%'),
                                    AppTheme.orange),
                            ],
                          ),
                        ),

                        // Requirements (COO, Inspection, ACID)
                        _cell(
                          value: reqsStr.isNotEmpty ? reqsStr : '—',
                          rowSummary: rowSummary,
                          child: Row(
                            children: [
                              _reqIcon('ACID', tariff.requiresAcid),
                              const SizedBox(width: 4),
                              _reqIcon('COO', tariff.requiresCoo),
                              const SizedBox(width: 4),
                              _reqIcon('INSP', tariff.requiresInspection),
                            ],
                          ),
                        ),

                        // Status
                        _cell(
                          value: tariff.isActive ? l10n.statusActive : l10n.statusInactive,
                          rowSummary: rowSummary,
                          child: AppStatusBadge(
                            label: tariff.isActive ? l10n.statusActive : l10n.statusInactive,
                            severity: tariff.isActive ? AppSeverity.success : AppSeverity.danger,
                            size: AppStatusBadgeSize.small,
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
  },
);
}

  Widget _rateBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _reqIcon(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: active ? AppTheme.cobalt.withValues(alpha: 0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              active ? AppTheme.cobalt.withValues(alpha: 0.4) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: active ? AppTheme.cobalt : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _cell({
    required Widget child,
    String? value,
    String? rowSummary,
  }) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    );
    if (value != null) {
      content = CopyableTableCell(
        value: value,
        rowSummary: rowSummary,
        child: content,
      );
    }
    return TableRowInkWell(
      onTap: () {},
      child: content,
    );
  }

  void _copyTariffsTsv(BuildContext context, List<CustomsTariffModel> tariffs) {
    final l10n = context.l10n;
    final headers = [
      l10n.tariffTsvHeaderHsCode,
      l10n.tariffTsvHeaderDescription,
      l10n.tariffTsvHeaderCategory,
      l10n.tariffTsvHeaderDutyRate,
      l10n.tariffTsvHeaderVatRate,
      l10n.tariffTsvHeaderScheduleTax,
      l10n.tariffTsvHeaderDevFee,
      l10n.tariffTsvHeaderImportFee,
      l10n.tariffTsvHeaderAuthority,
      l10n.tariffTsvHeaderRequirements,
      l10n.tariffTsvHeaderStatus,
    ];
    final rows = tariffs.map((t) {
      final reqs = <String>[];
      if (t.requiresAcid) reqs.add('ACID');
      if (t.requiresCoo) reqs.add('COO');
      if (t.requiresInspection) reqs.add('INSP');
      return [
        t.hsCode,
        t.hsDescription,
        t.categoryLabel(l10n) ?? '',
        '${t.customsDutyRate}%',
        '${t.vatRate}%',
        '${t.scheduleTaxRate}%',
        '${t.developmentFeeRate}%',
        '${t.importFeeRate}%',
        t.regulatoryAuthority ?? '',
        reqs.join(', '),
        t.isActive ? l10n.statusActive : l10n.statusInactive,
      ];
    });
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.customsTariffExportTsvSuccess);
  }

  String _buildTariffRowSummary(AppLocalizations l10n, CustomsTariffModel t) {
    final b = StringBuffer();
    b.writeln('📋 ${l10n.customsTariffScreenTitle}');
    b.writeln('${l10n.tariffCodeBadgeLabel}${t.hsCode}');
    b.writeln('${l10n.tariffTsvHeaderDescription}: ${t.hsDescription}');
    if (t.customsCategory != null && t.customsCategory!.isNotEmpty) {
      b.writeln('${l10n.tariffTsvHeaderCategory}: ${t.categoryLabel(l10n)}');
    }
    b.writeln('${l10n.taxRatesBreakdownSection}:');
    b.writeln('  • ${l10n.tariffTsvHeaderDutyRate}: ${t.customsDutyRate}%');
    b.writeln('  • ${l10n.tariffTsvHeaderVatRate}: ${t.vatRate}%');
    if (t.scheduleTaxRate > 0) {
      b.writeln('  • ${l10n.tariffTsvHeaderScheduleTax}: ${t.scheduleTaxRate}%');
    }
    if (t.developmentFeeRate > 0) {
      b.writeln('  • ${l10n.tariffTsvHeaderDevFee}: ${t.developmentFeeRate}%');
    }
    if (t.regulatoryAuthority != null && t.regulatoryAuthority!.isNotEmpty) {
      b.writeln('${l10n.tariffTsvHeaderAuthority}: ${t.regulatoryAuthority}');
    }
    final reqs = <String>[];
    if (t.requiresAcid) reqs.add('ACID');
    if (t.requiresCoo) reqs.add('COO');
    if (t.requiresInspection) reqs.add('INSP');
    if (reqs.isNotEmpty) {
      b.writeln('${l10n.tariffTsvHeaderRequirements}: ${reqs.join(", ")}');
    }
    b.writeln('${l10n.tariffTsvHeaderStatus}: ${t.isActive ? l10n.statusActive : l10n.statusInactive}');
    return b.toString().trim();
  }

  void _copySingleTariffSummary(BuildContext context, CustomsTariffModel tariff) {
    final l10n = context.l10n;
    final summary = _buildTariffRowSummary(l10n, tariff);
    CopyHelper.copy(context, summary, customMessage: l10n.tariffCopySummarySuccess);
  }

  // ==================================================
  // Add / Edit Customs Tariff Dialog (MD-008) - Smart Text & Manual Modes
  // ==================================================


  // ==================================================
  // Excel / CSV Dataset Import Handler
  // ==================================================

  Future<void> _handleExcelImport(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLoadingState(),
                        const SizedBox(height: 16),
                        Text(l10n.importingTariffDataset),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final summary = await ref
              .read(customsTariffProvider.notifier)
              .uploadExcelTariffs(file.bytes!, file.name);

          if (context.mounted) {
            Navigator.pop(context); // Close loading dialog
            final imported = summary?['imported'] ?? 0;
            final updated = summary?['updated'] ?? 0;
            final total = summary?['total_processed'] ?? 0;

            await AppConfirmDialog.show(
              context,
              title: l10n.importCompletedTitle,
              message: l10n.importSummaryContent(total, imported, updated),
              confirmLabel: l10n.ok,
              confirmVariant: AppButtonVariant.primary,
              icon: Icons.check_circle,
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.importFailedSnack(e.toString()),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

}
