import '../../../core/utils/container_requirement_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../models/shipping_scenario_model.dart';
import '../providers/shipping_scenarios_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import 'search_and_clone_study_dialog.dart';
import '../../../core/localization/api_error_text.dart';

class SavedScenariosRegistryTab extends ConsumerStatefulWidget {
  final void Function(ShippingEvaluationModel session) onEditSession;
  final VoidCallback onSwitchToEvaluator;

  const SavedScenariosRegistryTab({
    super.key,
    required this.onEditSession,
    required this.onSwitchToEvaluator,
  });

  @override
  ConsumerState<SavedScenariosRegistryTab> createState() => _SavedScenariosRegistryTabState();
}

class _SavedScenariosRegistryTabState extends ConsumerState<SavedScenariosRegistryTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shippingScenariosProvider);
    final poList = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final projectsList = ref.watch(projectsProvider).valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return _buildHistoryRegistryTab(state, poList, projectsList, importFiles);
  }

  Widget _buildHistoryRegistryTab(
    ShippingScenariosState state,
    List poList,
    List projectsList,
    List<ImportFileModel> importFiles,
  ) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSessions = state.sessions.length;
    final activeSessions = state.sessions.where((s) => s.isActive).length;
    final avgTransitAll = totalSessions > 0
        ? state.sessions.fold<double>(0, (sum, s) => sum + s.avgExpectedTransitDays) / totalSessions
        : 0.0;
    final withRecommendation = state.sessions.where((s) => s.recommendedScenarioProvider != null && s.recommendedScenarioProvider!.isNotEmpty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Top Summary Cards ───────────────────────────────────────────────
        Container(
          color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _histStatCard(
                    icon: Icons.folder_copy_rounded,
                    label: l.totalStudiesMetric,
                    value: '$totalSessions',
                    color: AppTheme.cobalt,
                  ),
                  _histStatCard(
                    icon: Icons.check_circle_rounded,
                    label: l.activeStatus,
                    value: '$activeSessions',
                    color: AppTheme.emerald,
                  ),
                  _histStatCard(
                    icon: Icons.schedule_rounded,
                    label: l.avgTransitMetric,
                    value: avgTransitAll > 0 ? '${avgTransitAll.toStringAsFixed(1)} d' : '-',
                    color: AppTheme.cobaltBorder,
                  ),
                  _histStatCard(
                    icon: Icons.recommend_rounded,
                    label: l.withRecommendationMetric,
                    value: '$withRecommendation',
                    color: AppTheme.orange,
                  ),
                ],
              ),
              // Force Refresh button
              AppButton(
                label: l.refreshRegistry,
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => ref.read(shippingScenariosProvider.notifier).fetchSessions(),
              ),
            ],
          ),
        ),

        // Data Actions Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: MasterDataToolbarWidget(
            moduleEndpoint: 'shipping-evaluations',
            title: 'Shipping_Evaluations',
            onRefreshNeeded: () => ref.read(shippingScenariosProvider.notifier).fetchSessions(),
          ),
        ),

        // ─── Search & Filter Bar ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
            boxShadow: [BoxShadow(color: isDark ? Colors.black26 : AppTheme.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 750;
              final searchField = AppSearchField(
                controller: _searchController,
                hint: l.searchStudiesHint,
                onChanged: (v) {
                  ref.read(shippingScenariosProvider.notifier).setSearchQuery(v.trim());
                },
              );

              final actionWidgets = <Widget>[
                FilterChip(
                  avatar: Icon(
                    state.showInactive ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: state.showInactive ? AppTheme.crimson : AppTheme.textMuted,
                  ),
                  label: Text(
                    state.showInactive ? l.showDeleted : l.hideDeleted,
                    style: TextStyle(
                      fontSize: 12,
                      color: state.showInactive ? AppTheme.crimson : (isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong),
                      fontWeight: state.showInactive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: state.showInactive,
                  selectedColor: AppTheme.crimson.withValues(alpha: 0.12),
                  checkmarkColor: AppTheme.crimson,
                  onSelected: (val) => ref.read(shippingScenariosProvider.notifier).toggleShowInactive(val),
                ),
                AppButton(
                  key: const ValueKey('registrySearchAndCloneStudyBtn'),
                  label: l.searchAndCloneStudyBtn,
                  icon: Icons.control_point_duplicate_rounded,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: () => _openSearchAndCloneStudyDialog(context, state.sessions),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.sessions.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  ),
                ),
              ];

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actionWidgets,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  ...actionWidgets.map((w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: w)),
                ],
              );
            },
          ),
        ),
        // ─── Data Table ──────────────────────────────────────────────────────
        Expanded(
          child: state.isLoading
              ? const AppLoadingState()
              : state.sessions.isEmpty
                  ? AppEmptyState(
                      icon: Icons.folder_open_rounded,
                      message: _searchController.text.isNotEmpty
                          ? l.noResultsFound
                          : l.noDataFound,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 768) {
                          return _buildMobileStudiesCardList(context, state.sessions, importFiles);
                        }
                        return SingleChildScrollView(
                          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
                          child: Card(
                            elevation: 2,
                            color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 48,
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 60,
                                horizontalMargin: 16,
                                columnSpacing: 20,
                                dividerThickness: 0.5,
                                headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkScaffoldBackground : AppTheme.charcoal),
                            headingTextStyle: const TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                            columns: [
                              DataColumn(label: SizedBox(
                                width: 168,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.orange),
                                    const SizedBox(width: 4),
                                    Text(l.actionsCol, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              )),
                              DataColumn(label: Text('📋 ${l.studyCodeCol}')),
                              DataColumn(label: Text('📁 ${l.linkImportFile}')),
                              DataColumn(label: Text('📝 ${l.titleField}')),
                              DataColumn(label: Text('⏱️ ${l.avgTransitMetric}')),
                              DataColumn(label: Text('🏭 ${l.avgWarehouseArrivalMetric}')),
                              DataColumn(label: Text('⭐ ${l.recommendedLineMetric}')),
                              DataColumn(label: Text('🔢 ${l.optionsCountCol}')),
                              DataColumn(label: Text('🔗 ${l.linkPurchaseOrder}')),
                              DataColumn(label: Text('📅 ${l.crdLabel}')),
                              DataColumn(label: Text('📍 ${l.pickupAddressLabel}')),
                            ],
                            rows: state.sessions.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final sess = entry.value;
                              final isEven = idx.isEven;
                              final rowColor = !sess.isActive
                                  ? (AppTheme.crimsonLight)
                                  : isEven
                                      ? (isDark ? AppTheme.darkCardBackground : AppTheme.white)
                                      : (isDark ? AppTheme.darkInputBackground : AppTheme.charcoalSurface);

                              final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                              final rawFileCode = sess.importFileCode ?? (sess.importFileId != null ? 'IMP-${sess.importFileId}' : '—');
                              final shipmentTitle = (rawFileCode != '—')
                                  ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
                                  : '—';

                              final rowSummary = '${sess.sessionCode} | ${sess.title ?? ""} | $shipmentTitle | ${sess.avgExpectedTransitDays.toStringAsFixed(1)}d | WH: ${sess.avgExpectedWarehouseArrivalDate ?? "-"} | ${sess.recommendedScenarioProvider ?? "-"}';

                              return DataRow(
                                color: WidgetStateProperty.all(rowColor),
                                onSelectChanged: (_) => _showSessionDetailsDialog(context, sess, importFiles),
                                cells: [
                                  // ⚡ 1. ACTIONS — أول عمود دائماً مرئي
                                  DataCell(
                                    RowActionsPill(
                                      onView: () => _showSessionDetailsDialog(context, sess, importFiles),
                                      onEdit: () => widget.onEditSession(sess),
                                      onClone: () => _openCloneStudyReviewDialog(context, sess),
                                      onPrint: () => _showPrintReportDialog(context, sess, importFiles),
                                      onDelete: () => _handleDeleteOrRestore(context, sess, l),
                                    ),
                                  ),

                                  // 2. Study Code
                                  DataCell(
                                    CopyableTableCell(
                                      value: sess.sessionCode,
                                      rowSummary: rowSummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (sess.isActive ? AppTheme.cobalt : AppTheme.crimson).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: (sess.isActive ? AppTheme.cobalt : AppTheme.crimson).withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              sess.isActive ? Icons.analytics_outlined : Icons.delete_outline,
                                              size: 13,
                                              color: sess.isActive ? AppTheme.cobalt : AppTheme.crimson,
                                            ),
                                            const SizedBox(width: 5),
                                            CopyableText(
                                              sess.sessionCode,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: sess.isActive ? AppTheme.cobalt : AppTheme.crimson,
                                                fontSize: 12,
                                                decoration: sess.isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 3. Import File
                                  DataCell(
                                    CopyableTableCell(
                                      value: rawFileCode != '—' ? '$shipmentTitle ($rawFileCode)' : '—',
                                      rowSummary: rowSummary,
                                      child: rawFileCode == '—'
                                          ? const Text('—', style: TextStyle(color: AppTheme.textMuted))
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  shipmentTitle,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                    color: AppTheme.charcoal,
                                                 ),
                                                 maxLines: 1,
                                                 overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.cobalt.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2), width: 0.8),
                                                  ),
                                                  child: Text(
                                                    rawFileCode,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.cobalt,
                                                      fontSize: 10,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),

                                  // 4. Title
                                  DataCell(
                                    CopyableTableCell(
                                      value: sess.title ?? l.freightStudiesTitle,
                                      rowSummary: rowSummary,
                                      child: SizedBox(
                                        width: 180,
                                        child: Text(
                                          sess.title ?? l.freightStudiesTitle,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 5. Avg Transit
                                  DataCell(
                                    CopyableTableCell(
                                      value: l.avgTransitDays(sess.avgExpectedTransitDays.toStringAsFixed(1)),
                                      rowSummary: rowSummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cobaltLight,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          l.avgTransitDays(sess.avgExpectedTransitDays.toStringAsFixed(1)),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.wcagCobalt,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 6. Avg WH Arrival
                                  DataCell(
                                    CopyableTableCell(
                                      value: sess.avgExpectedWarehouseArrivalDate ?? '—',
                                      rowSummary: rowSummary,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warehouse_rounded, size: 14, color: AppTheme.emerald.withValues(alpha: 0.7)),
                                          const SizedBox(width: 4),
                                          Text(
                                            sess.avgExpectedWarehouseArrivalDate ?? '—',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.emerald,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 7. Recommended Carrier
                                  DataCell(
                                    CopyableTableCell(
                                      value: sess.recommendedScenarioProvider ?? '—',
                                      rowSummary: rowSummary,
                                      child: sess.recommendedScenarioProvider != null && sess.recommendedScenarioProvider!.isNotEmpty
                                          ? Container(
                                              constraints: const BoxConstraints(maxWidth: 150),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [AppTheme.cobalt, AppTheme.cobalt],
                                                ),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.star_rounded, size: 12, color: AppTheme.orange),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      sess.recommendedScenarioProvider!,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : const Text('—', style: TextStyle(color: AppTheme.textMuted)),
                                    ),
                                  ),

                                  // 8. Options Count
                                  DataCell(
                                    CopyableTableCell(
                                      value: l.optionsCount(sess.items.length),
                                      rowSummary: rowSummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.charcoal,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          l.optionsCount(sess.items.length),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.charcoal,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 9. Linked PO / Project
                                  DataCell(
                                    CopyableTableCell(
                                      value: sess.poNumber != null
                                          ? 'PO: ${sess.poNumber}'
                                          : (sess.projectName != null ? 'PRJ: ${sess.projectName}' : l.independentStudy),
                                      rowSummary: rowSummary,
                                      child: sess.poNumber != null
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.receipt_long_rounded, size: 13, color: AppTheme.emerald),
                                                const SizedBox(width: 4),
                                                Text('PO: ${sess.poNumber}', style: const TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.w600)),
                                              ],
                                            )
                                          : sess.projectName != null
                                              ? Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.folder_special_rounded, size: 13, color: AppTheme.orange),
                                                    const SizedBox(width: 4),
                                                    Text('PRJ: ${sess.projectName}', style: const TextStyle(color: AppTheme.wcagOrange, fontSize: 11, fontWeight: FontWeight.w600)),
                                                  ],
                                                )
                                              : Text(l.independentStudy, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    ),
                                  ),

                                  // 10. CRD Date
                                  DataCell(
                                    CopyableTableCell(
                                      value: sess.cargoReadyDate,
                                      rowSummary: rowSummary,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.event_rounded, size: 13, color: AppTheme.textMuted),
                                          const SizedBox(width: 4),
                                          Text(sess.cargoReadyDate, style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 11. Pick-up Address
                                  DataCell(
                                    CopyableTableCell(
                                      value: sess.pickUpAddress ?? '—',
                                      rowSummary: rowSummary,
                                      child: SizedBox(
                                        width: 140,
                                        child: Text(
                                          sess.pickUpAddress ?? '—',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// بطاقة إحصائية صغيرة في شريط الـ History
  Widget _histStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CopyableText(value, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  void _showSessionDetailsDialog(BuildContext context, ShippingEvaluationModel sess, [List<ImportFileModel>? importFiles]) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final rawFileCode = sess.importFileCode ?? (sess.importFileId != null ? 'IMP-${sess.importFileId}' : null);
    final shipmentTitle = (rawFileCode != null && rawFileCode != '—')
        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
        : null;

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AlertDialog(
        title: Text('${l.freightStudiesTitle} (${sess.sessionCode})'),
        content: SizedBox(
          width: 950,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sess.title ?? l.freightStudiesTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (shipmentTitle != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_outlined, size: 14, color: AppTheme.cobalt),
                        const SizedBox(width: 4),
                        Text('$shipmentTitle ($rawFileCode)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text('${l.crdLabel}: ${sess.cargoReadyDate} | ${l.pickupAddressLabel}: ${sess.pickUpAddress ?? "—"} | ${l.avgForm4DaysLabel}: ${sess.avgForm4Days}d | ${l.avgClearanceDaysLabel}: ${sess.avgClearanceDays}d', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const Divider(height: 20),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('#')),
                      DataColumn(label: Text(l.shippingLineCol)),
                      DataColumn(label: Text(l.totalQuoteValue)),
                      DataColumn(label: Text(l.avgTransitMetric)),
                      DataColumn(label: Text(l.customsBrokerLabel)),
                      DataColumn(label: Text(l.vesselNameCol)),
                      DataColumn(label: Text('${l.portOfLoadingCol} ➔ ${l.portOfDischargeCol}')),
                      DataColumn(label: Text(l.sailingDateCol)),
                      DataColumn(label: Text(l.estimatedArrivalDateCol)),
                      DataColumn(label: Text(l.freeTimeDaysCol)),
                      DataColumn(label: Text(l.statusCol)),
                    ],
                    rows: sess.items.asMap().entries.map((e) {
                      final item = e.value;
                      final totalText = item.totalQuotationAmount != null
                          ? '${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? ""}'
                          : '—';
                      final rowSummary = '${item.providerName} | $totalText | ${item.expectedTotalDaysToWarehouse}d | ${item.polName ?? "-"} ➔ ${item.podName ?? "-"} | ${item.vesselName}';
                      return DataRow(
                        cells: [
                          DataCell(CopyableTableCell(value: '${e.key + 1}', rowSummary: rowSummary, child: Text('${e.key + 1}'))),
                          DataCell(CopyableTableCell(value: item.providerName, rowSummary: rowSummary, child: Text(item.providerName, style: const TextStyle(fontWeight: FontWeight.bold)))),
                          DataCell(CopyableTableCell(value: totalText, rowSummary: rowSummary, child: Text(totalText, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson)))),
                          DataCell(CopyableTableCell(value: '${item.expectedTotalDaysToWarehouse} d', rowSummary: rowSummary, child: Text('${item.expectedTotalDaysToWarehouse} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                          DataCell(CopyableTableCell(value: item.customsBrokerName ?? '-', rowSummary: rowSummary, child: Text(item.customsBrokerName ?? '-'))),
                          DataCell(CopyableTableCell(value: '${item.vesselName} (${item.voyageNumber ?? "-"})', rowSummary: rowSummary, child: Text('${item.vesselName} (${item.voyageNumber ?? "-"})'))),
                          DataCell(CopyableTableCell(value: '${item.polName ?? "-"} ➔ ${item.podName ?? "-"}', rowSummary: rowSummary, child: Text('${item.polName ?? "-"} ➔ ${item.podName ?? "-"}', style: const TextStyle(fontSize: 11)))),
                          DataCell(CopyableTableCell(value: item.sailingDate, rowSummary: rowSummary, child: Text(item.sailingDate))),
                          DataCell(CopyableTableCell(value: item.estimatedArrivalDate, rowSummary: rowSummary, child: Text(item.estimatedArrivalDate))),
                          DataCell(CopyableTableCell(value: '${item.freeTimeDays} d', rowSummary: rowSummary, child: Text('${item.freeTimeDays} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                          DataCell(CopyableTableCell(value: item.isRecommended ? l.recommendedLineMetric : item.isExcludedFromAverage ? l.excludedBadge : l.normalBadge, rowSummary: rowSummary, child: Text(item.isRecommended ? '⭐ ${l.recommendedLineMetric}' : item.isExcludedFromAverage ? l.excludedBadge : l.normalBadge))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l.exportExcel,
            icon: Icons.file_download_outlined,
            variant: AppButtonVariant.success,
            onPressed: () => _exportScenarioCsv(context, sess, importFiles),
          ),
          AppButton(
            label: l.close,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ],
      ),
    ),
    );
  }

  void _showPrintReportDialog(BuildContext context, ShippingEvaluationModel sess, [List<ImportFileModel>? importFiles]) {
    _exportScenarioCsv(context, sess, importFiles);
  }

  // ignore: unused_element
  void _showContainerComparisonDialog(
    BuildContext context,
    ContainerDualRecommendationResult dualRec,
    double cbm,
    double weightKg,
  ) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AlertDialog(
        title: Text('🚚 ${l.compareContainersMatrix}'),
        content: SizedBox(
          width: 650,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CBM: ${cbm.toStringAsFixed(3)} m³ | ${l.weightUtilizationCol}: ${weightKg.toStringAsFixed(0)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              Table(
                border: TableBorder.all(color: AppTheme.cloudWhite),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.statusCol, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(8), child: Text('📦 ${l.stackableOption}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald))),
                      Padding(padding: const EdgeInsets.all(8), child: Text('🚫 ${l.nonStackableOption}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange))),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.recommendedContainerCol)),
                      Padding(padding: const EdgeInsets.all(8), child: Text(dualRec.stackableResult.recommendedContainerCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(dualRec.nonStackableResult.recommendedContainerCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.requiredCountCol)),
                      Padding(padding: const EdgeInsets.all(8), child: Text('${dualRec.stackableResult.requiredContainersCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                      Padding(padding: const EdgeInsets.all(8), child: Text('${dualRec.nonStackableResult.requiredContainersCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.spaceUtilizationCol)),
                      Padding(padding: const EdgeInsets.all(8), child: Text('${dualRec.stackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%')),
                      Padding(padding: const EdgeInsets.all(8), child: Text('${dualRec.nonStackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: l.close,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ],
      ),
    ),
    );
  }


  Future<void> _exportScenarioCsv(BuildContext context, ShippingEvaluationModel sess, [List<ImportFileModel>? importFiles]) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final rawFileCode = sess.importFileCode ?? (sess.importFileId != null ? 'IMP-${sess.importFileId}' : '-');
    final shipmentTitle = rawFileCode != '-' ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic) : '-';

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('Sorour Logistics ERP — تقرير دراسة وتقييم سيناريوهات الشحن');
    buffer.writeln('كود الدراسة,${sess.sessionCode}');
    buffer.writeln('عنوان الدراسة,"${(sess.title ?? '').replaceAll('"', '""')}"');
    buffer.writeln('كود ملف الاستيراد,$rawFileCode');
    if (shipmentTitle != '-') {
      buffer.writeln('اسم الشحنة التجاري,"${shipmentTitle.replaceAll('"', '""')}"');
    }
    buffer.writeln('أمر الشراء,${sess.poNumber ?? "-"}');
    buffer.writeln('المشروع,${sess.projectName ?? "-"}');
    buffer.writeln('تاريخ الجاهزية CRD,${sess.cargoReadyDate}');
    buffer.writeln('عنوان الاستلام,"${(sess.pickUpAddress ?? "-").replaceAll('"', '""')}"');
    buffer.writeln('الخط الموصى به,"${(sess.recommendedScenarioProvider ?? "-").replaceAll('"', '""')}"');
    buffer.writeln('');
    buffer.writeln('--- سيناريوهات الشحن المقارنة ---');
    buffer.writeln('الخط الملاحي / الناقل,الباخرة,ميناء الشحن,ميناء الوصول,مدة الإبحار (أيام),تاريخ الإبحار,تاريخ الوصول التقديري ETA,تاريخ وصول المخزن المتوقع,التكلفة التقديرية,العملة,مستوى المخاطر,موصى به');
    for (final it in sess.items) {
      buffer.writeln('"${it.providerName.replaceAll('"', '""')}","${it.vesselName.replaceAll('"', '""')}","${it.polName ?? '-'}","${it.podName ?? '-'}","${it.vesselLeadTimeDays}","${it.sailingDate}","${it.estimatedArrivalDate}","${it.expectedWarehouseArrivalDate}","${it.totalQuotationAmount ?? '-'}","${it.quotationCurrency ?? '-'}","${it.riskLevel}","${it.isRecommended ? "نعم" : "لا"}"');
    }

    final filename = 'Phase1_Shipping_Evaluation_${sess.sessionCode}_${DateTime.now().millisecondsSinceEpoch}.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'حفظ دراسة سيناريوهات الشحن بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  Future<void> _handleDeleteOrRestore(BuildContext context, ShippingEvaluationModel sess, AppLocalizations l) async {
    if (sess.isActive) {
      final confirm = await AppConfirmDialog.show(
        context,
        title: l.confirmDelete,
        message: '${l.confirmDeleteStudyMessage} (${sess.sessionCode})',
        confirmLabel: l.delete,
        cancelLabel: l.cancel,
        confirmVariant: AppButtonVariant.danger,
        icon: Icons.warning_rounded,
      );
      if (confirm == true) {
        await ref.read(shippingScenariosProvider.notifier).deleteSession(sess.sessionId!);
      }
    } else {
      await ref.read(shippingScenariosProvider.notifier).restoreSession(sess.sessionId!);
    }
  }

  void _openCloneStudyReviewDialog(BuildContext context, ShippingEvaluationModel source) {
    final l = context.l10n;
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final initialName = '${source.title ?? source.sessionCode}${TableRowCloneHelper.copySuffix}';

    final copiedMap = <String, String>{
      l.shippingCarrierOptions: '${source.items.length}',
      l.crdLabel: source.cargoReadyDate,
    };
    if (source.recommendedScenarioProvider != null) {
      copiedMap[l.recommendedLineMetric] = source.recommendedScenarioProvider!;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SelectionArea(
            child: CloneEntityReviewDialog(
            entityType: l.cloneStudyDialogTitle,
            sourceCode: source.sessionCode,
            suggestedNewCode: '${source.sessionCode}-CLONE',
            sourceTitle: initialName,
            copiedFieldsSummary: copiedMap,
            mandatorilyResetFields: [
              l.cloneFieldStudyCodeGenerated,
              l.cloneFieldImportFileReset,
              l.cloneFieldPoReset,
              l.cloneFieldSelectionReset,
            ],
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final sId = source.sessionId;
              if (sId == null) return;
              final messenger = ScaffoldMessenger.of(context);
              final cloned = await ref.read(shippingScenariosProvider.notifier).cloneSession(
                sId,
                newTitle: newTitle,
                remarks: notes,
                unlinkImportFile: true,
                unlinkPo: true,
                copyCarrierOptions: copyLineItems,
              );
              if (!context.mounted) return;
              if (cloned != null) {
                widget.onEditSession(cloned);
                widget.onSwitchToEvaluator();
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  AppTheme.snackBar(
                    context,
                    l.cloneStudySuccess(cloned.sessionCode),
                    severity: AppSeverity.success,
                  ),
                );
              } else {
                // The clone failed: show the (localized) reason instead of staying silent.
                messenger.showSnackBar(
                  AppTheme.snackBar(
                    context,
                    ApiErrorText.of(l, ref.read(shippingScenariosProvider).error, fallback: l.operationFailed),
                    severity: AppSeverity.danger,
                  ),
                );
              }
            },
          ),
        ),
        ),
      ),
    );
  }

  void _openSearchAndCloneStudyDialog(BuildContext context, List<ShippingEvaluationModel> sessions) {
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SelectionArea(
            child: SearchAndCloneStudyDialog(
            sessions: sessions,
            onSelectStudy: (session) {
              Navigator.of(dialogCtx).pop();
              _openCloneStudyReviewDialog(context, session);
            },
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildMobileStudiesCardList(
    BuildContext context,
    List<ShippingEvaluationModel> sessions,
    List<ImportFileModel> importFiles,
  ) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 24),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final sess = sessions[index];
        final rawFileCode = sess.importFileCode ?? (sess.importFileId != null ? 'IMP-${sess.importFileId}' : null);
        final shipmentTitle = (rawFileCode != null && rawFileCode != '—')
            ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
            : null;

        return Card(
          elevation: 2,
          color: !sess.isActive
              ? (AppTheme.crimsonLight)
              : (isDark ? AppTheme.darkCardBackground : AppTheme.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: !sess.isActive
                  ? AppTheme.crimson.withValues(alpha: 0.4)
                  : (isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Icon + Code + Active Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.cobalt.withValues(alpha: 0.15),
                      child: const Icon(Icons.alt_route, color: AppTheme.cobalt, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CopyableText(
                        sess.sessionCode,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppStatusBadge(
                      label: sess.isActive ? l.activeStatus : context.l10n.ssInactive,
                      severity: sess.isActive ? AppSeverity.success : AppSeverity.danger,
                      size: AppStatusBadgeSize.small,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                if (sess.title != null && sess.title!.isNotEmpty) ...[
                  Text(
                    sess.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Linked Import File / PO
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (rawFileCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '📁 $rawFileCode${shipmentTitle != null ? " ($shipmentTitle)" : ""}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (sess.poNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'PO: ${sess.poNumber}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Metrics wrap: Options count, Transit, WH Date, Recommended Carrier
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkInputBackground : AppTheme.charcoal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l.optionsCount(sess.items.length),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                        ),
                      ),
                    ),
                    if (sess.avgExpectedTransitDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⏱️ ${sess.avgExpectedTransitDays.toStringAsFixed(1)} d',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                        ),
                      ),
                    if (sess.recommendedScenarioProvider != null && sess.recommendedScenarioProvider!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '⭐ ${sess.recommendedScenarioProvider}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                        ),
                      ),
                    if (sess.cargoReadyDate.isNotEmpty)
                      Text(
                        '📅 CRD: ${sess.cargoReadyDate}',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Actions Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    RowActionsPill(
                      onView: () => _showSessionDetailsDialog(context, sess, importFiles),
                      onEdit: () => widget.onEditSession(sess),
                      onClone: () => _openCloneStudyReviewDialog(context, sess),
                      onPrint: () => _showPrintReportDialog(context, sess, importFiles),
                      onDelete: () => _handleDeleteOrRestore(context, sess, l),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}
