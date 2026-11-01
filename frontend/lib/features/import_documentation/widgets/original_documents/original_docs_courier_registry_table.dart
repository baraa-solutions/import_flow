import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../providers/original_documents_collection_provider.dart';
import '../../services/original_docs_export_service.dart';
import '../idoc_ui.dart';
import 'original_docs_localizer.dart';

/// Courier tracking registry table displaying all active and delivered couriers.
/// Wrapped in [SelectionArea] with sanitized clipboard operations.
class OriginalDocsCourierRegistryTable extends ConsumerStatefulWidget {
  final ValueChanged<int> onLoadFile;
  final void Function({
    required int importFileId,
    required String courierNo,
    required String courierCompany,
    String? trackingNo,
    required String importFileCode,
  }) onShowDeliveryProof;

  const OriginalDocsCourierRegistryTable({
    super.key,
    required this.onLoadFile,
    required this.onShowDeliveryProof,
  });

  @override
  ConsumerState<OriginalDocsCourierRegistryTable> createState() =>
      _OriginalDocsCourierRegistryTableState();
}

class _OriginalDocsCourierRegistryTableState
    extends ConsumerState<OriginalDocsCourierRegistryTable> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final allCouriersAsync = ref.watch(allCouriersProvider);
    final allImportFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l.idocASearchByWaybillCourierOrShipment,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.trim().isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 15),
                              onPressed: () {
                                setState(() => _searchController.clear());
                              },
                            )
                          : null,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 170,
                  child: SearchableDropdownField<String>(
                    value: _statusFilter,
                    labelText: l.colDocStatus,
                    items: [
                      SearchableDropdownItem<String>(value: 'All', label: l.filterStatusAll),
                      SearchableDropdownItem<String>(value: 'IN_TRANSIT', label: l.filterStatusInTransit),
                      SearchableDropdownItem<String>(value: 'DELIVERED', label: l.filterStatusDelivered),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IdocUi.fit(
                  AppButton(
                    label: l.refreshDataTooltip,
                    icon: Icons.refresh,
                    variant: AppButtonVariant.primary,
                    onPressed: () => ref.invalidate(allCouriersProvider),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          allCouriersAsync.when(
            data: (couriersList) {
              final query = _searchController.text.trim().toLowerCase();
              final filtered = couriersList.where((c) {
                if (_statusFilter == 'IN_TRANSIT' && c.isReceived) return false;
                if (_statusFilter == 'DELIVERED' && !c.isReceived) return false;
                if (query.isNotEmpty) {
                  final matchNo = c.courierNo.toLowerCase().contains(query);
                  final matchCompany = c.courierCompany.toLowerCase().contains(query);
                  final matchFile = c.importFileCode.toLowerCase().contains(query);
                  final matchReceiver = (c.receivedBy ?? '').toLowerCase().contains(query);
                  final matchPod = (c.podReference ?? '').toLowerCase().contains(query);
                  if (!matchNo && !matchCompany && !matchFile && !matchReceiver && !matchPod) {
                    return false;
                  }
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    l.idocANoCourierPackagesMatchTheSearch,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAlt),
                  headingTextStyle: const TextStyle(
                    color: AppTheme.charcoal,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  columns: [
                    DataColumn(label: Text(l.idocAOperations)),
                    DataColumn(label: Text(l.idocAShippingCompany)),
                    DataColumn(label: Text(l.idocAWaybillNumberAWB)),
                    DataColumn(label: Text(l.idocAImportFile)),
                    DataColumn(label: Text(l.idocALinkedDocuments)),
                    DataColumn(label: Text(l.idocADispatchDate)),
                    DataColumn(label: Text(l.idocATransitTime)),
                    DataColumn(label: Text(l.idocAReceiptStatus)),
                    DataColumn(label: Text(l.idocAReceiptDateAndTime)),
                    DataColumn(label: Text(l.idocAReceivedBy)),
                    DataColumn(label: Text(l.idocAPODNumber)),
                    DataColumn(label: Text(l.notes)),
                  ],
                  rows: filtered.map((c) {
                    final isAr = Localizations.localeOf(context).languageCode == 'ar';
                    final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
                      c.importFileCode,
                      shipments: allImportFiles,
                      isArabic: isAr,
                    );
                    final companyLabel = OriginalDocsLocalizer.getCourierCompanyLabel(context, c.courierCompany);
                    final rowSummary =
                        '$companyLabel | ${c.courierNo} | ${c.importFileCode} | ${c.isReceived ? l.idocAReceived : l.idocAInTransitAlt} | ${c.receivedDate ?? "-"}';

                    return DataRow(
                      cells: [
                        // Operations cell
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 16, color: AppTheme.cobalt),
                                tooltip: l.idocATrackTheCourierDirectlyOnThe,
                                onPressed: () => OriginalDocsExportService.launchCarrierTracking(
                                  c.courierCompany,
                                  c.courierNo,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  c.isReceived ? Icons.verified : Icons.verified_outlined,
                                  size: 16,
                                  color: AppTheme.emerald,
                                ),
                                tooltip: l.confirmCourierDeliveryBtn,
                                onPressed: () => widget.onShowDeliveryProof(
                                  importFileId: c.importFileId,
                                  courierNo: c.courierNo,
                                  courierCompany: c.courierCompany,
                                  trackingNo: c.courierNo,
                                  importFileCode: c.importFileCode,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 15, color: AppTheme.textSecondary),
                                tooltip: l.copyRow,
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  rowSummary,
                                  customMessage: l.originalDocsCopyRowSuccess,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.folder_open_outlined, size: 16, color: AppTheme.charcoal),
                                tooltip: l.originalDocsLoadSessionTooltip,
                                onPressed: () => widget.onLoadFile(c.importFileId),
                              ),
                            ],
                          ),
                        ),
                        // Courier Company
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_shipping, size: 15, color: AppTheme.cobalt),
                              const SizedBox(width: 6),
                              Text(
                                companyLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // AWB No
                        DataCell(
                          CopyableTableCell(
                            value: c.courierNo,
                            rowSummary: rowSummary,
                            child: InkWell(
                              onTap: () => CopyHelper.copy(
                                context,
                                c.courierNo,
                                customMessage: l.copiedToClipboard(c.courierNo),
                              ),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      c.courierNo,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppTheme.charcoal,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.copy, size: 12, color: AppTheme.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Shipment Code & Name
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (shipmentName != c.importFileCode) ...[
                                Text(
                                  shipmentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              InkWell(
                                onTap: () => widget.onLoadFile(c.importFileId),
                                child: Text(
                                  c.importFileCode,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.cobalt,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Associated Docs Count
                        DataCell(
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                l.idocADocumentsCount(c.associatedDocsCount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.cobalt,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Dispatch Date
                        DataCell(Text(c.dispatchDate ?? '—', style: const TextStyle(fontSize: 12))),
                        // Days in transit
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.daysInTransit >= 5
                                  ? AppTheme.crimson.withValues(alpha: 0.12)
                                  : (c.daysInTransit >= 3
                                      ? AppTheme.orange.withValues(alpha: 0.12)
                                      : AppTheme.severityBackgroundOf(context, AppSeverity.info)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l.daysInTransitLabel(c.daysInTransit),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: c.daysInTransit >= 5
                                    ? AppTheme.crimson
                                    : (c.daysInTransit >= 3 ? AppTheme.orange : AppTheme.cobalt),
                              ),
                            ),
                          ),
                        ),
                        // Status
                        DataCell(
                          c.isReceived
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle, size: 12, color: AppTheme.emerald),
                                      const SizedBox(width: 4),
                                      Text(
                                        l.idocAReceived,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.emerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.local_shipping, size: 12, color: AppTheme.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        l.idocAInTransitAlt,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        // Received Date & Time
                        DataCell(
                          Text(
                            c.receivedDate != null
                                ? '${c.receivedDate} ${c.receivedTime ?? ""}'.trim()
                                : '—',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Received By
                        DataCell(Text(c.receivedBy ?? '—', style: const TextStyle(fontSize: 12))),
                        // POD Ref
                        DataCell(
                          Text(
                            c.podReference ?? '—',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Notes
                        DataCell(Text(c.notes ?? '—', style: const TextStyle(fontSize: 11))),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              '${l.errorPrefix}: ${ApiErrorText.of(l, e)}',
              style: const TextStyle(color: AppTheme.crimson),
            ),
          ),
        ],
      ),
    );
  }
}
