import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/import_file_po_linker.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/import_file_model.dart';

/// Mobile stacked cards list widget for viewport < 768px in ImportFilesScreen.
class ImportFilesMobileCardList extends StatelessWidget {
  final List<ImportFileModel> items;
  final int? highlightedFileId;
  final Map<int, List<PurchaseOrderModel>> linkedPOsCache;
  final List<PurchaseOrderModel> allPOs;
  final ValueChanged<ImportFileModel> onViewDetails;
  final ValueChanged<ImportFileModel> onEdit;
  final ValueChanged<ImportFileModel> onClone;
  final ValueChanged<ImportFileModel> onSmartReference;
  final ValueChanged<ImportFileModel> onSmartChecklist;
  final ValueChanged<ImportFileModel> onStopShipment;
  final ValueChanged<ImportFileModel> onReopenShipment;
  final ValueChanged<int> onOpenComprehensiveReport;

  const ImportFilesMobileCardList({
    super.key,
    required this.items,
    this.highlightedFileId,
    required this.linkedPOsCache,
    required this.allPOs,
    required this.onViewDetails,
    required this.onEdit,
    required this.onClone,
    required this.onSmartReference,
    required this.onSmartChecklist,
    required this.onStopShipment,
    required this.onReopenShipment,
    required this.onOpenComprehensiveReport,
  });

  String _getPriorityLabel(String priority, AppLocalizations l) {
    switch (priority.toLowerCase()) {
      case 'high':
        return l.priorityHigh;
      case 'medium':
        return l.priorityMedium;
      case 'low':
        return l.priorityLow;
      case 'critical':
        return l.priorityCritical;
      default:
        return priority;
    }
  }

  String _getStatusLabel(String status, AppLocalizations l) {
    switch (status.toLowerCase()) {
      case 'open':
        return l.statusOpen;
      case 'in progress':
      case 'in_progress':
        return l.statusInProgress;
      case 'closed':
        return l.statusClosed;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return SelectionArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final file = items[index];
          final priorityText = _getPriorityLabel(file.priority, l);
          final statusText = _getStatusLabel(file.status, l);
          final resolvedStage = DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr);
          final shipDisplayName = DisplayNameResolver.resolveShipmentName(file, isArabic: isAr);

          String poDisplay;
          if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
            poDisplay = file.poNumber!.trim();
          } else {
            final linkedPOs = linkedPOsCache.putIfAbsent(
              file.importFileId,
              () => ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs),
            );
            if (linkedPOs.isNotEmpty) {
              poDisplay = linkedPOs
                  .map((p) => (p.poReference != null &&
                          p.poReference!.trim().isNotEmpty &&
                          p.poReference != file.customFileNumber &&
                          p.poReference != file.importFileCode)
                      ? p.poReference!
                      : p.poNumber)
                  .join(', ');
            } else {
              poDisplay = '-';
            }
          }
          final piDisplay = file.piNumber != null && file.piNumber!.trim().isNotEmpty ? file.piNumber!.trim() : '-';

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: highlightedFileId == file.importFileId
                    ? AppTheme.cobalt
                    : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                width: highlightedFileId == file.importFileId ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Shipment Name & Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => onViewDetails(file),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shipDisplayName,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(height: 2),
                            LtrText(
                              file.importFileCode,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Chip(
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          label: Text(
                            priorityText,
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: file.priority == 'High' || file.priority == 'Critical'
                              ? AppTheme.wcagCrimson
                              : AppTheme.wcagOrange,
                        ),
                        Chip(
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          label: Text(
                            statusText,
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: file.status == 'Open'
                              ? AppTheme.wcagEmerald
                              : (isDark ? const Color(0xFF475569) : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16),
                // Importer & Supplier
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.importingCompany,
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                          ),
                          Text(file.companyName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.foreignSupplier,
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                          ),
                          Text(file.supplierName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // PO & Mode
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.poInvoiceLabel,
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                          ),
                          Text(
                            '${l.poNumberShortPrefix}$poDisplay │ ${l.piNumberShortPrefix}$piDisplay',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.transportModeIncoterm,
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                          ),
                          Text('${file.shipmentMode} (${file.incotermCode})', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Stage & Progress
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.currentPhaseStage,
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                          ),
                          Text(resolvedStage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${file.progressPercent.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          LinearProgressIndicator(
                            value: file.progressPercent / 100,
                            color: AppTheme.wcagEmerald,
                            backgroundColor: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Actions row: wraps on narrow cards instead of overflowing
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    IconButton(
                      key: Key('openComprehensiveReportCardBtn_${file.importFileId}'),
                      icon: const Icon(Icons.summarize_outlined, color: AppTheme.cobalt, size: 18),
                      tooltip: isAr ? 'تقرير الشحنة الشامل المدمج' : 'Shipment Comprehensive Report',
                      onPressed: () => onOpenComprehensiveReport(file.importFileId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 18),
                      tooltip: l.viewDetails,
                      onPressed: () => onViewDetails(file),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: l.edit,
                      onPressed: () => onEdit(file),
                    ),
                    IconButton(
                      icon: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 18),
                      tooltip: l.cloneImportFileDialogTitle,
                      onPressed: () => onClone(file),
                    ),
                    IconButton(
                      icon: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 18),
                      tooltip: isAr ? 'المرجع الذكي للشحنة' : 'Shipment Smart Reference',
                      onPressed: () => onSmartReference(file),
                    ),
                    IconButton(
                      icon: const Icon(Icons.playlist_add_check_circle, color: AppTheme.cobalt, size: 18),
                      tooltip: l.smartChecklistTooltip,
                      onPressed: () => onSmartChecklist(file),
                    ),
                    if (file.status != 'Closed')
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: AppTheme.wcagCrimson, size: 18),
                        tooltip: l.stopShipmentTooltip,
                        onPressed: () => onStopShipment(file),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: AppTheme.wcagEmerald, size: 18),
                        tooltip: l.reopenShipmentTooltip,
                        onPressed: () => onReopenShipment(file),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
