import '../../../core/utils/container_requirement_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../models/shipping_scenario_model.dart';
import '../providers/shipping_scenarios_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../screens/shipping_scenarios_screen.dart';
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
      builder: (dialogCtx) => AlertDialog(
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
      builder: (dialogCtx) => AlertDialog(
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
    );
  }


  // ignore: unused_element
  void _showVisualLoadPlanDialog(BuildContext context, List<PurchaseOrderModel> pos, double totalCbm, double totalWeight) {
    final List<CargoItem> baseCargoItems = [];
    int itemCounter = 1;

    for (final po in pos) {
      final hasPalletPlan = po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0);
      final hasSinglePallet = po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0;

      if (hasPalletPlan) {
        final double totalGross = po.packingListItems.fold<double>(
          0.0,
          (sum, p) => sum + (p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.qtyPkg * p.grossWeightUnitKg)),
        );
        final int totalPallets = po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount);
        final double defaultPalletWeight = totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

        for (final pLine in po.palletPlanItems) {
          final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
          final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
          final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
          final pWt = pLine.grossWeightPerPalletKg > 0 ? pLine.grossWeightPerPalletKg : defaultPalletWeight;

          for (int i = 0; i < pLine.palletCount; i++) {
            baseCargoItems.add(CargoItem(
              itemId: 'PLT-$itemCounter',
              length: pL,
              width: pW,
              height: pH,
              weight: pWt,
              isStackable: pLine.isStackable,
              rotate: true,
              packageType: pLine.palletType,
              description: 'بالتة #$itemCounter (${pLine.palletType})${pLine.isStackable ? "" : " [Floor Only]"}',
            ));
            itemCounter++;
          }
        }
      } else if (hasSinglePallet) {
        final double pWt = po.totalGrossWeightKg > 0 ? (po.totalGrossWeightKg / po.palletCount) : 137.5;
        for (int i = 0; i < po.palletCount; i++) {
          baseCargoItems.add(CargoItem(
            itemId: 'PLT-$itemCounter',
            length: po.palletLengthCm,
            width: po.palletWidthCm,
            height: po.palletHeightCm,
            weight: pWt,
            isStackable: po.isPalletStackable,
            rotate: true,
            packageType: po.palletType,
            description: 'بالتة #$itemCounter (${po.palletType})${po.isPalletStackable ? "" : " [Floor Only]"}',
          ));
          itemCounter++;
        }
      } else if (po.packingListItems.isNotEmpty) {
        for (final pl in po.packingListItems) {
          for (int q = 0; q < pl.qtyPkg.toInt(); q++) {
            double lCm = pl.lengthCm;
            double wCm = pl.widthCm;
            double hCm = pl.heightCm;
            if (pl.unit == 'mm') {
              lCm /= 10;
              wCm /= 10;
              hCm /= 10;
            } else if (pl.unit == 'm') {
              lCm *= 100;
              wCm *= 100;
              hCm *= 100;
            }

            baseCargoItems.add(CargoItem(
              itemId: '$itemCounter',
              length: lCm > 0 ? lCm : 100.0,
              width: wCm > 0 ? wCm : 80.0,
              height: hCm > 0 ? hCm : 60.0,
              weight: pl.grossWeightUnitKg > 0 ? pl.grossWeightUnitKg : (pl.totalGrossWeightKg / (pl.qtyPkg > 0 ? pl.qtyPkg : 1)),
              rotate: true,
              isStackable: pl.isStackable,
              packageType: pl.packageType,
            ));
            itemCounter++;
          }
        }
      }
    }

    if (baseCargoItems.isEmpty && totalCbm > 0) {
      final double targetCbm = totalCbm;
      final double targetWeight = totalWeight > 0 ? totalWeight : 1000.0;
      final int numPallets = (targetCbm / 2.0).ceil().clamp(1, 50);
      final double perPalletCbm = targetCbm / numPallets;
      final double perPalletWeight = targetWeight / numPallets;

      double palletHeightCm = (perPalletCbm * 1000000.0) / 12000.0;
      if (palletHeightCm > 260) palletHeightCm = 260;

      for (int i = 0; i < numPallets; i++) {
        baseCargoItems.add(CargoItem(
          itemId: 'PLT-$itemCounter',
          length: 120,
          width: 100,
          height: palletHeightCm.clamp(30.0, 260.0),
          weight: perPalletWeight,
          rotate: true,
          isStackable: true,
          packageType: 'Pallet',
        ));
        itemCounter++;
      }
    }

    if (baseCargoItems.isEmpty) {
      baseCargoItems.add(CargoItem(
        itemId: '1',
        length: 120,
        width: 80,
        height: 100,
        weight: totalWeight > 0 ? totalWeight : 500.0,
        rotate: true,
        isStackable: true,
      ));
    }

    // Default active view mode: null = Actual/Mixed, true = All Stackable, false = All Non-Stackable
    bool? activeStackingMode = baseCargoItems.any((i) => !i.isStackable) ? null : true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final l = dialogCtx.l10n;
            // Compute plan dynamically based on the selected mode
            final plan = ContainerRequirementEngine.planShipment(
              baseCargoItems,
              forceStackable: activeStackingMode,
            );

            // Compute summary metrics for active plan
            final totalPkgs = baseCargoItems.length;
            final stackableInActive = activeStackingMode == true
                ? totalPkgs
                : (activeStackingMode == false ? 0 : baseCargoItems.where((c) => c.isStackable).length);
            final nonStackableInActive = totalPkgs - stackableInActive;

            final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
            final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

            // Determine container fleet text (e.g. 2 x 40HC or 2 x 40HC + 1 x 20GP)
            final Map<String, int> containerCounts = {};
            for (final p in plan) {
              if (p.containerCode != 'FAILED') {
                containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
              }
            }
            final fleetSummaryText = containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.view_in_ar, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.visualLoadPlanSimulator,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cobalt),
                    ),
                    child: Text(
                      l.requiredFleetLabel(fleetSummaryText, plan.length),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 980,
                height: 640,
                child: Column(
                  children: [
                    // 1. Scenario / Stacking Mode Switcher (All 3 required states)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoalSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cloudWhite),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.selectStackingScenarioLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                          ),
                          Row(
                            children: [
                              ChoiceChip(
                                label: Text(l.allStackableOption),
                                selected: activeStackingMode == true,
                                selectedColor: AppTheme.emerald,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == true ? AppTheme.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => activeStackingMode = true);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text(l.allNonStackableOption),
                                selected: activeStackingMode == false,
                                selectedColor: AppTheme.wcagOrange,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == false ? AppTheme.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => activeStackingMode = false);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text(l.mixedStackingOption),
                                selected: activeStackingMode == null,
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == null ? AppTheme.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => activeStackingMode = null);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2. Metrics Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoal.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cloudWhite),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildLoadMetricPill(l.totalPackagesMetricLabel, '$totalPkgs', AppTheme.cobalt),
                              const SizedBox(width: 8),
                              _buildLoadMetricPill(l.totalWeightMetricLabel, '${totalPlanWeight.toStringAsFixed(0)} kg', AppTheme.charcoal),
                              const SizedBox(width: 8),
                              _buildLoadMetricPill(l.totalVolumeMetricLabel, '${totalPlanVolume.toStringAsFixed(3)} m³', AppTheme.wcagOrange),
                            ],
                          ),
                          Row(
                            children: [
                              _buildLoadMetricPill(l.stackableMetricLabel, '$stackableInActive', AppTheme.wcagEmerald),
                              const SizedBox(width: 8),
                              _buildLoadMetricPill(l.nonStackableMetricLabel, '$nonStackableInActive', AppTheme.crimson),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 3. Table summary of container loads
                    Table(
                      border: TableBorder.all(color: AppTheme.cloudWhite),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.8),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(2.4),
                      },
                      children: [
                          TableRow(
                            decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                            children: [
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.containerCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.itemsAndPackagesCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.loadedWeightCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.spaceUtilizationCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.safetyDistributionCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                        ...plan.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final res = entry.value;
                          final placedIds = res.placedItems.map((p) => p.item.itemId).join(', ');

                          String statusText = '';
                          if (res.containerCode == 'FAILED') {
                            statusText = l.loadingFailedStatus(res.unplacedItems.map((u) => u.itemId).join(", "));
                          } else {
                            final nonStackInThis = res.placedItems.where((p) => !p.item.isStackable).length;
                            if (nonStackInThis > 0) {
                              statusText = l.nonStackableFloorCount(nonStackInThis);
                            } else {
                              statusText = l.multiLayerCompliant((res.totalVolume / res.spec.internalVolumeCbm * 100).toStringAsFixed(1));
                            }
                          }

                          final double spaceUtil = res.spec.internalVolumeCbm > 0 ? (res.totalVolume / res.spec.internalVolumeCbm) * 100 : 0.0;

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText(
                                  res.containerCode == 'FAILED' ? l.failedStackLabel : '$idx: ${res.spec.code}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText(placedIds.isEmpty ? '-' : placedIds, style: const TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText(res.containerCode == 'FAILED' ? '-' : '${res.totalWeight.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText('${spaceUtil.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: res.containerCode == 'FAILED'
                                        ? AppTheme.crimson
                                        : (res.placedItems.any((p) => !p.item.isStackable) ? AppTheme.wcagOrange : AppTheme.wcagEmerald),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 4. Tab view or list for visual container layout drawings
                    Expanded(
                      child: ListView.builder(
                        itemCount: plan.length,
                        itemBuilder: (ctx, pIdx) {
                          final res = plan[pIdx];
                          if (res.containerCode == 'FAILED') {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppTheme.crimsonLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.crimsonBorder)),
                              child: CopyableText(
                                l.itemsExceedCapacity(res.unplacedItems.map((u) => u.itemId).join(", ")),
                                style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold),
                              ),
                            );
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      CopyableText(
                                        l.containerLayoutTitle(pIdx + 1, res.spec.name, res.spec.code),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                      ),
                                      Row(
                                        children: [
                                          Text(l.woodenFloorPalletsLabel, style: const TextStyle(fontSize: 10, color: AppTheme.wcagOrange, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: AppTheme.cobaltLight, borderRadius: BorderRadius.circular(4)),
                                            child: CopyableText(
                                              l.internalDimsLabel(res.spec.internalLength.toStringAsFixed(0), res.spec.internalWidth.toStringAsFixed(0), res.spec.internalHeight.toStringAsFixed(0)),
                                              style: const TextStyle(fontSize: 10, color: AppTheme.cobalt),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Side View (Left Wall Removed) - High Fidelity Realistic Container
                                  Container(
                                    height: 190,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoal,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: CustomPaint(
                                      painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                      child: Container(),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Top View (Roof Removed)
                                  Container(
                                    height: 140,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoal,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: CustomPaint(
                                      painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                      child: Container(),
                                    ),
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
              ),
              actions: [
                AppButton(
                  label: l.closePlanBtn,
                  icon: Icons.close,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
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

  static Widget _buildLoadMetricPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          CopyableText(value, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
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
              if (cloned != null) {
                widget.onEditSession(cloned);
                widget.onSwitchToEvaluator();
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l.cloneStudySuccess(cloned.sessionCode)),
                    backgroundColor: AppTheme.wcagEmerald,
                  ),
                );
              } else {
                // The clone failed: show the (localized) reason instead of staying silent.
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ApiErrorText.of(l, ref.read(shippingScenariosProvider).error, fallback: l.operationFailed)),
                    backgroundColor: AppTheme.crimson,
                  ),
                );
              }
            },
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
          child: SearchAndCloneStudyDialog(
            sessions: sessions,
            onSelectStudy: (session) {
              Navigator.of(dialogCtx).pop();
              _openCloneStudyReviewDialog(context, session);
            },
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
