import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import 'drilldown/drilldown_models.dart';
import 'drilldown/drilldown_record_card.dart';

export 'drilldown/drilldown_models.dart';
export 'drilldown/dashboard_drilldown_helper.dart';

class DashboardCardDrillDownDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color themeColor;
  final List<DrillDownItem> records;
  final bool isArabic;

  const DashboardCardDrillDownDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.records,
    required this.isArabic,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color themeColor,
    required List<DrillDownItem> records,
    required bool isArabic,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DashboardCardDrillDownDialog(
        title: title,
        icon: icon,
        themeColor: themeColor,
        records: records,
        isArabic: isArabic,
      ),
    );
  }

  /// Formats the shipment display for badges and copy outputs, ensuring zero duplication.
  static String formatBadgeShipment(DrillDownItem item) {
    final code = item.shipmentCode;
    final title = item.shipmentTitle;
    if (code == null || code.trim().isEmpty) return title ?? '-';
    final trimmedCode = code.trim();
    if (title == null || title.trim().isEmpty || title.trim() == trimmedCode) {
      return trimmedCode;
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.contains(trimmedCode)) {
      return trimmedTitle;
    }
    return '$trimmedTitle ($trimmedCode)';
  }

  @override
  State<DashboardCardDrillDownDialog> createState() =>
      _DashboardCardDrillDownDialogState();
}

class _DashboardCardDrillDownDialogState
    extends State<DashboardCardDrillDownDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DrillDownItem> get _filteredRecords {
    if (_searchQuery.trim().isEmpty) return widget.records;
    final q = _searchQuery.trim().toLowerCase();
    return widget.records.where((item) {
      final t = item.title.toLowerCase();
      final sub = item.subtitle?.toLowerCase() ?? '';
      final code = item.shipmentCode?.toLowerCase() ?? '';
      final sTitle = item.shipmentTitle?.toLowerCase() ?? '';
      final who = item.who.toLowerCase();
      final status = item.status.toLowerCase();
      final when = item.byWhen.toLowerCase();
      return t.contains(q) ||
          sub.contains(q) ||
          code.contains(q) ||
          sTitle.contains(q) ||
          who.contains(q) ||
          status.contains(q) ||
          when.contains(q);
    }).toList();
  }

  void _copyAllRecords(BuildContext context, AppLocalizations l) {
    final buffer = StringBuffer();
    buffer.writeln(
        '=== ${widget.title} (${widget.records.length} ${l.drillDownItemsCountSuffix}) ===\n');

    for (int i = 0; i < widget.records.length; i++) {
      final r = widget.records[i];
      buffer.writeln('${i + 1}. ${r.title}');
      if (r.shipmentCode != null) {
        buffer.writeln(
            '   - ${widget.isArabic ? "الشحنة" : "Shipment"}: ${DashboardCardDrillDownDialog.formatBadgeShipment(r)}');
      }
      buffer.writeln(
          '   - ${l.drillDownLabelWhat}: ${r.nextAction ?? r.subtitle ?? r.title}');
      buffer.writeln('   - ${l.drillDownLabelWho}: ${r.who}');
      buffer.writeln('   - ${l.drillDownLabelWhen}: ${r.byWhen}');
      buffer.writeln('   - ${l.drillDownLabelStatus}: ${r.status}');
      if (r.dataGaps.isNotEmpty) {
        buffer.writeln(
            '   - [${l.drillDownDataGapBadge}]: ${r.dataGaps.join(" | ")}');
      }
      buffer.writeln();
    }

    CopyHelper.copy(context, buffer.toString(),
        customMessage: l.drillDownCopiedAllToast);
  }

  void _copySingleRecord(
      BuildContext context, DrillDownItem r, AppLocalizations l) {
    final buffer = StringBuffer();
    buffer.writeln(r.title);
    if (r.shipmentCode != null) {
      buffer.writeln(
          '${widget.isArabic ? "الشحنة" : "Shipment"}: ${DashboardCardDrillDownDialog.formatBadgeShipment(r)}');
    }
    buffer.writeln(
        '${l.drillDownLabelWhat}: ${r.nextAction ?? r.subtitle ?? r.title}');
    buffer.writeln('${l.drillDownLabelWho}: ${r.who}');
    buffer.writeln('${l.drillDownLabelWhen}: ${r.byWhen}');
    buffer.writeln('${l.drillDownLabelStatus}: ${r.status}');
    if (r.dataGaps.isNotEmpty) {
      buffer
          .writeln('[${l.drillDownDataGapBadge}]: ${r.dataGaps.join(" | ")}');
    }

    CopyHelper.copy(context, buffer.toString(),
        customMessage: l.drillDownCopiedItemToast);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final totalCount = widget.records.length;
    final displayedList = _filteredRecords;
    final isDark = AppTheme.isDark(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side:
            BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
      ),
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: SelectionArea(
        child: Container(
          width: 880,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Dialog Header ──────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color:
                      widget.themeColor.withValues(alpha: isDark ? 0.15 : 0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(
                      bottom: BorderSide(
                          color: isDark
                              ? AppTheme.darkBorder
                              : Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.themeColor
                            .withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon,
                          color: widget.themeColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.charcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.themeColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalCount ${l.drillDownItemsCountSuffix}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (totalCount > 0) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.white : widget.themeColor,
                          side: BorderSide(
                              color: widget.themeColor
                                  .withValues(alpha: isDark ? 0.7 : 0.5)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: Text(
                          l.drillDownCopyAllBtn,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _copyAllRecords(context, l),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 20,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade600),
                      tooltip: l.drillDownCloseBtn,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Search & Filter Bar ────────────────────────────────────────
              if (totalCount > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 4),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.charcoal),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: l.drillDownSearchHint,
                      hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkTextMuted
                              : Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search,
                          size: 20,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  size: 18,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? AppTheme.darkCardBackground
                          : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.darkBorder
                                : Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.darkBorder
                                : Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),

              // ── Records List or Empty State ────────────────────────────────
              Expanded(
                child: totalCount == 0
                    ? _buildEmptyState(context, l, isDark: isDark)
                    : displayedList.isEmpty
                        ? Center(
                            child: Text(
                              widget.isArabic
                                  ? 'لا توجد نتائج مطابقة لبحثك'
                                  : 'No items match your search query',
                              style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : Colors.grey.shade600,
                                  fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: displayedList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final item = displayedList[index];
                              return DrilldownRecordCard(
                                item: item,
                                themeColor: widget.themeColor,
                                isArabic: widget.isArabic,
                                isDark: isDark,
                                onCopySingleRecord: (it) =>
                                    _copySingleRecord(context, it, l),
                                formatBadgeShipment:
                                    DashboardCardDrillDownDialog
                                        .formatBadgeShipment,
                              );
                            },
                          ),
              ),

              // ── Dialog Footer ──────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppTheme.darkCardBackground : Colors.grey.shade50,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(14)),
                  border: Border(
                      top: BorderSide(
                          color: isDark
                              ? AppTheme.darkBorder
                              : Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l.drillDownItemsCountSuffix}: ${displayedList.length} / $totalCount',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade600),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.darkElevatedSurface
                            : AppTheme.charcoal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l.drillDownCloseBtn,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildEmptyState(BuildContext context, AppLocalizations l,
      {bool isDark = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:
                    widget.themeColor.withValues(alpha: isDark ? 0.18 : 0.08),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.task_alt_rounded, size: 48, color: widget.themeColor),
            ),
            const SizedBox(height: 16),
            Text(
              l.drillDownEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                l.drillDownEmptyDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
