import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';

/// ACID Expiry Tracker Strip & Lifecycle Monitoring Component
///
/// Features:
/// - Egyptian Customs BP-014 / Rule ACID-001 (14-day expiry warning threshold).
/// - Rule ACID-002 (automatic release suppression when `is_customs_released == true`).
/// - Rule ACID-004: All tables wrapped in [SelectionArea], sanitized copying via [CopyHelper.copy]
///   to strip Bidi Unicode isolates, and pure single-locale representation.
class AcidExpiryTrackerStrip extends ConsumerStatefulWidget {
  final void Function(AcidTrackerItemModel item)? onCloneTrackerItem;
  final VoidCallback? onRefresh;
  final bool isStripOnly;

  const AcidExpiryTrackerStrip({
    super.key,
    this.onCloneTrackerItem,
    this.onRefresh,
    this.isStripOnly = false,
  });

  @override
  ConsumerState<AcidExpiryTrackerStrip> createState() => _AcidExpiryTrackerStripState();
}

class _AcidExpiryTrackerStripState extends ConsumerState<AcidExpiryTrackerStrip> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final trackerSummary = ref.watch(acidTrackerProvider).valueOrNull;
    final trackerItems = trackerSummary?.items ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter items based on search query
    final filtered = trackerItems.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.acidNumber.toLowerCase().contains(q) ||
          (t.importFileCode != null && t.importFileCode!.toLowerCase().contains(q)) ||
          t.supplierName.toLowerCase().contains(q);
    }).toList();

    // Critical 14-day warning items (Suppressed if customs released per Rule ACID-002)
    final criticalAlertItems = trackerItems.where((t) {
      if (t.isCustomsReleased) return false;
      return t.status == 'Expired' || t.daysRemaining <= 14;
    }).toList();

    return SelectionArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 14-Day Expiry Warning Banner (Rule ACID-001 & ACID-002)
              if (criticalAlertItems.isNotEmpty)
                _build14DayWarningBanner(context, criticalAlertItems.length, isDark),

              // KPI Metric Cards Row/Grid
              _buildMetricCards(context, trackerSummary, trackerItems, isMobile, isDark),

              if (!widget.isStripOnly) ...[
                const SizedBox(height: 18),
                // Search Bar & Export Actions Toolbar
                _buildSearchAndActions(context, filtered, importFiles, isMobile, isDark),
                const SizedBox(height: 16),
                // Tracker Table / Empty State
                _buildTrackerTable(context, filtered, importFiles, constraints, isMobile, isDark),
              ],
            ],
          );
        },
      ),
    );
  }

  /// 14-day expiry critical warning banner
  Widget _build14DayWarningBanner(BuildContext context, int alertCount, bool isDark) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.orangeLight : AppTheme.warningBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.expiringSoonAcidsCard} ($alertCount)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isDark ? AppTheme.wcagOrange : AppTheme.warningForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.acidInfoBanner,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: isDark ? AppTheme.wcagOrange : AppTheme.charcoal,
              tooltip: l.refresh,
              onPressed: widget.onRefresh,
            ),
        ],
      ),
    );
  }

  /// Metric cards layout adapting to mobile and desktop
  Widget _buildMetricCards(
    BuildContext context,
    AcidTrackerSummaryModel? trackerSummary,
    List<AcidTrackerItemModel> trackerItems,
    bool isMobile,
    bool isDark,
  ) {
    final l = context.l10n;

    final totalCount = trackerSummary?.totalAcidsCount ?? trackerItems.length;
    final validCount = trackerSummary?.validCount ??
        trackerItems.where((t) => t.status != 'Expired' && t.daysRemaining > 14).length;
    final expiringCount = trackerSummary?.expiringSoonCount ??
        trackerItems.where((t) => t.status != 'Expired' && t.daysRemaining <= 14 && t.daysRemaining > 0).length;
    final expiredCount = trackerSummary?.expiredCount ??
        trackerItems.where((t) => t.status == 'Expired' || t.daysRemaining <= 0).length;

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              _buildTrackerCard(
                title: l.totalAcidsCard,
                count: totalCount,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                icon: Icons.qr_code,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildTrackerCard(
                title: l.validAcidsCard,
                count: validCount,
                color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald,
                icon: Icons.check_circle_outline,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTrackerCard(
                title: l.expiringSoonAcidsCard,
                count: expiringCount,
                color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
                icon: Icons.warning_amber,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildTrackerCard(
                title: l.expiredAcidsCard,
                count: expiredCount,
                color: isDark ? AppTheme.wcagCrimson : AppTheme.crimson,
                icon: Icons.cancel_outlined,
                isDark: isDark,
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        _buildTrackerCard(
          title: l.totalAcidsCard,
          count: totalCount,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          icon: Icons.qr_code,
          isDark: isDark,
        ),
        const SizedBox(width: 14),
        _buildTrackerCard(
          title: l.validAcidsCard,
          count: validCount,
          color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald,
          icon: Icons.check_circle_outline,
          isDark: isDark,
        ),
        const SizedBox(width: 14),
        _buildTrackerCard(
          title: l.expiringSoonAcidsCard,
          count: expiringCount,
          color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
          icon: Icons.warning_amber,
          isDark: isDark,
        ),
        const SizedBox(width: 14),
        _buildTrackerCard(
          title: l.expiredAcidsCard,
          count: expiredCount,
          color: isDark ? AppTheme.wcagCrimson : AppTheme.crimson,
          icon: Icons.cancel_outlined,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTrackerCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppTheme.darkBorder : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  CopyableText(
                    '$count',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? (color == AppTheme.charcoal ? AppTheme.darkTextPrimary : color) : color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search & Actions toolbar
  Widget _buildSearchAndActions(
    BuildContext context,
    List<AcidTrackerItemModel> filtered,
    List<dynamic> importFiles,
    bool isMobile,
    bool isDark,
  ) {
    final l = context.l10n;

    final searchField = TextField(
      key: const Key('acidExpiryTrackerSearchField'),
      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
      decoration: InputDecoration(
        hintText: l.searchExpiryTrackerHint,
        hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
        prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );

    final actionButtons = [
      AppButton(
        key: const Key('acidExpiryCopyBtn'),
        label: l.copyTable,
        onPressed: () => _copyAcidExpiryAsTsv(filtered, importFiles),
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        icon: Icons.copy,
      ),
      AppButton(
        key: const Key('acidExpiryExcelBtn'),
        label: l.exportExcel,
        onPressed: () => _exportAcidExpiryToExcel(filtered, importFiles),
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        icon: Icons.table_chart,
      ),
      AppButton(
        key: const Key('acidExpiryPdfBtn'),
        label: l.exportPdf,
        onPressed: () => _exportAcidExpiryToPdf(filtered, importFiles),
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        icon: Icons.picture_as_pdf,
      ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actionButtons,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 8),
        ...actionButtons.map((btn) => Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: btn,
            )),
      ],
    );
  }

  /// DataTable rendering
  Widget _buildTrackerTable(
    BuildContext context,
    List<AcidTrackerItemModel> filtered,
    List<dynamic> importFiles,
    BoxConstraints constraints,
    bool isMobile,
    bool isDark,
  ) {
    final l = context.l10n;

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.cardDecorationOf(context),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.borderStrong),
            const SizedBox(height: 12),
            Text(
              l.noAcidsFound,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: AppTheme.cardDecorationOf(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth < 750 ? 750 : constraints.maxWidth - (isMobile ? 28 : 40),
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
            columns: [
              DataColumn(label: Text(l.actionCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
              DataColumn(label: Text(l.acidNumberCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
              DataColumn(label: Text(l.importFile, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
              DataColumn(label: Text(l.foreignExporterCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
              DataColumn(label: Text(l.expiryDateCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
              DataColumn(label: Text(l.daysRemainingCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
              DataColumn(label: Text(l.validityStatusCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
            ],
            rows: filtered.map((t) {
              final days = t.daysRemaining;
              final isExp = t.status == 'Expired' || days <= 0;
              final isWarning = !isExp && days <= 14;
              final expDate = t.acidExpiryDate ?? '';
              final matchedFile = importFiles.where((f) => f.importFileId == t.importFileId).firstOrNull;
              final fileLabel = matchedFile?.displayName ?? t.importFileCode ?? '-';
              final poLabel = (matchedFile?.poNumber != null && matchedFile!.poNumber!.isNotEmpty)
                  ? matchedFile.poNumber!
                  : '';
              final statusLabel = isExp ? l.expiredStatusBadge : isWarning ? l.expiringSoonStatusBadge : l.validStatusBadge;
              final rowSummary = [
                t.acidNumber,
                fileLabel,
                poLabel,
                t.supplierName,
                expDate.length >= 10 ? expDate.substring(0, 10) : expDate,
                '$days',
                statusLabel,
              ].join('\t');

              return DataRow(
                cells: [
                  DataCell(
                    IconButton(
                      key: Key('cloneTrackerRowBtn_${t.acidNumber}'),
                      icon: Icon(Icons.copy_all, color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald, size: 20),
                      tooltip: l.cloneAcidRecordTooltip,
                      onPressed: () => widget.onCloneTrackerItem?.call(t),
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => CopyHelper.copy(context, t.acidNumber),
                      borderRadius: BorderRadius.circular(4),
                      child: CopyableTableCell(
                        value: t.acidNumber,
                        rowSummary: rowSummary,
                        child: Text(
                          t.acidNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: fileLabel,
                      rowSummary: rowSummary,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fileLabel, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                          if (poLabel.isNotEmpty)
                            Text('${l.poLabelPrefix}: $poLabel', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: t.supplierName,
                      rowSummary: rowSummary,
                      child: Text(t.supplierName, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: expDate.length >= 10 ? expDate.substring(0, 10) : expDate,
                      rowSummary: rowSummary,
                      child: Text(expDate.length >= 10 ? expDate.substring(0, 10) : expDate, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal)),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: '$days',
                      rowSummary: rowSummary,
                      child: Text(
                        '$days',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isExp
                              ? AppTheme.crimson
                              : isWarning
                                  ? (isDark ? AppTheme.wcagOrange : AppTheme.orange)
                                  : (isDark ? AppTheme.wcagEmerald : AppTheme.emerald),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: statusLabel,
                      rowSummary: rowSummary,
                      child: LivePulseBadge.acid(
                        daysRemaining: days,
                        isCustomsReleased: t.isCustomsReleased,
                        customLabel: statusLabel,
                        size: PulseBadgeSize.compact,
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
  }

  void _copyAcidExpiryAsTsv(List<AcidTrackerItemModel> list, List<dynamic> importFiles) {
    final l = context.l10n;
    final headers = [
      l.acidNumberCol,
      l.importFile,
      l.foreignExporterCol,
      l.expiryDateCol,
      l.daysRemainingCol,
      l.validityStatusCol,
    ];
    final rows = list.map((t) {
      final days = t.daysRemaining;
      final isExp = t.status == 'Expired' || days <= 0;
      final isWarning = !isExp && days <= 14;
      final matchedFile = importFiles.where((f) => f.importFileId == t.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? t.importFileCode ?? '-';
      final statusLabel = isExp ? l.expiredStatusBadge : isWarning ? l.expiringSoonStatusBadge : l.validStatusBadge;
      return [
        t.acidNumber,
        fileLabel,
        t.supplierName,
        t.acidExpiryDate ?? '-',
        days > 0 ? '$days' : '0',
        statusLabel,
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportAcidExpiryToExcel(List<AcidTrackerItemModel> list, List<dynamic> importFiles) async {
    final l = context.l10n;
    final headers = [
      l.acidNumberCol,
      l.importFile,
      l.foreignExporterCol,
      l.expiryDateCol,
      l.daysRemainingCol,
      l.validityStatusCol,
    ];
    final rows = list.map((t) {
      final days = t.daysRemaining;
      final isExp = t.status == 'Expired' || days <= 0;
      final isWarning = !isExp && days <= 14;
      final matchedFile = importFiles.where((f) => f.importFileId == t.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? t.importFileCode ?? '-';
      final statusLabel = isExp ? l.expiredStatusBadge : isWarning ? l.expiringSoonStatusBadge : l.validStatusBadge;
      return [
        t.acidNumber,
        fileLabel,
        t.supplierName,
        t.acidExpiryDate ?? '-',
        days > 0 ? '$days' : '0',
        statusLabel,
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocBAcidExpiryStage,
      importFileNameOrCode: 'ACID_Expiry_Tracker',
    );
  }

  Future<void> _exportAcidExpiryToPdf(List<AcidTrackerItemModel> list, List<dynamic> importFiles) async {
    final l = context.l10n;
    final headers = [
      l.acidNumberCol,
      l.importFile,
      l.foreignExporterCol,
      l.expiryDateCol,
      l.daysRemainingCol,
      l.validityStatusCol,
    ];
    final rows = list.map((t) {
      final days = t.daysRemaining;
      final isExp = t.status == 'Expired' || days <= 0;
      final isWarning = !isExp && days <= 14;
      final matchedFile = importFiles.where((f) => f.importFileId == t.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? t.importFileCode ?? '-';
      final statusLabel = isExp ? l.expiredStatusBadge : isWarning ? l.expiringSoonStatusBadge : l.validStatusBadge;
      return [
        t.acidNumber,
        fileLabel,
        t.supplierName,
        t.acidExpiryDate ?? '-',
        days > 0 ? '$days' : '0',
        statusLabel,
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocBAcidExpiryStage,
      importFileNameOrCode: 'ACID_Expiry_Tracker',
    );
  }
}
