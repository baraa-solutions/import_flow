import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/cargox_model.dart';
import '../../services/cargox_export_service.dart';
import 'invoice_hub_formatters.dart';

/// Sessions Registry tab:
/// Displays previously saved invoice verification sessions, filters by status,
/// provides search capabilities, and offers 4 export channels (TSV, CSV/Excel, PDF, Dossier).
class InvoiceHubRegistryView extends ConsumerWidget {
  final AsyncValue<List<StandardInvoiceSessionModel>> sessionsAsync;
  final TextEditingController searchController;
  final String filterStatus;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  const InvoiceHubRegistryView({
    super.key,
    required this.sessionsAsync,
    required this.searchController,
    required this.filterStatus,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? <ImportFileModel>[];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(context, importFiles),
          const SizedBox(height: 16),
          sessionsAsync.when(
            data: (sessions) {
              if (sessions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text(l10n.standardInvoiceNoSessionsFound),
                  ),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  columns: [
                    DataColumn(label: Text(l10n.standardInvoiceColSessionCode)),
                    DataColumn(label: Text(l10n.standardInvoiceColFileCode)),
                    DataColumn(label: Text(l10n.standardInvoiceColAcid)),
                    DataColumn(label: Text(l10n.standardInvoiceColInvoiceNum)),
                    DataColumn(label: Text(l10n.standardInvoiceColSupplier)),
                    DataColumn(label: Text(l10n.standardInvoiceColTotal)),
                    DataColumn(label: Text(l10n.standardInvoiceColItemsCount)),
                    DataColumn(label: Text(l10n.standardInvoiceColStatus)),
                    DataColumn(label: Text(l10n.standardInvoiceColUpdatedAt)),
                  ],
                  rows: sessions.map((s) {
                    final resolvedTitle = DisplayNameResolver.resolveShipmentTitleByCode(
                      s.importFileCode,
                      shipments: importFiles,
                      isArabic: isAr,
                    );
                    final rowSummary =
                        '${s.sessionCode} | File: $resolvedTitle (${s.importFileCode}) | ACID: ${s.acidNumber ?? "—"} | Inv: ${s.invoiceNumber ?? "—"} | Supp: ${s.exporterName ?? "—"} | Total: ${s.totalAmount.toStringAsFixed(2)} ${s.currencyCode} | Items: ${s.lineItemsCount} | Status: ${s.status} | Updated: ${formatInvoiceHubDateTime(s.updatedAt)}';
                    return DataRow(
                      cells: [
                        DataCell(CopyableTableCell(
                          value: s.sessionCode,
                          rowSummary: rowSummary,
                          child: Text(s.sessionCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                        )),
                        DataCell(
                          CopyableTableCell(
                            value: resolvedTitle.isNotEmpty ? '$resolvedTitle (${s.importFileCode})' : s.importFileCode,
                            rowSummary: rowSummary,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (resolvedTitle.isNotEmpty && resolvedTitle != s.importFileCode)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      resolvedTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                        color: AppTheme.charcoal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: LtrText(
                                        s.importFileCode,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => CopyHelper.copy(
                                        context,
                                        s.importFileCode,
                                        customMessage: '${l10n.standardInvoiceColFileCode}: ${s.importFileCode}',
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2.0),
                                        child: Icon(Icons.copy_rounded, size: 10, color: AppTheme.cobalt),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(CopyableTableCell(value: s.acidNumber ?? '—', rowSummary: rowSummary, child: Text(s.acidNumber ?? '—'))),
                        DataCell(CopyableTableCell(value: s.invoiceNumber ?? '—', rowSummary: rowSummary, child: Text(s.invoiceNumber ?? '—'))),
                        DataCell(CopyableTableCell(value: s.exporterName ?? '—', rowSummary: rowSummary, child: Text(s.exporterName ?? '—'))),
                        DataCell(CopyableTableCell(
                          value: '${s.totalAmount.toStringAsFixed(2)} ${s.currencyCode}',
                          rowSummary: rowSummary,
                          child: Text(
                            '${s.totalAmount.toStringAsFixed(2)} ${s.currencyCode}',
                            style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold),
                          ),
                        )),
                        DataCell(CopyableTableCell(value: '${s.lineItemsCount}', rowSummary: rowSummary, child: Text('${s.lineItemsCount}'))),
                        DataCell(AppStatusBadge.fromStatus(
                          status: s.status,
                          label: resolveInvoiceHubStatusLabel(context, s.status),
                          size: AppStatusBadgeSize.small,
                        )),
                        DataCell(CopyableTableCell(
                          value: formatInvoiceHubDateTime(s.updatedAt),
                          rowSummary: rowSummary,
                          child: Text(formatInvoiceHubDateTime(s.updatedAt)),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Text('${l10n.errorPrefix}: $e', style: const TextStyle(color: AppTheme.crimson)),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, List<ImportFileModel> importFiles) {
    final l10n = context.l10n;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: l10n.standardInvoiceRegistrySearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: filterStatus,
              isDense: true,
              items: [
                DropdownMenuItem(value: 'All', child: Text(l10n.standardInvoiceFilterAll, style: const TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'APPROVED', child: Text(l10n.standardInvoiceStatusApproved, style: const TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'UNDER_REVIEW', child: Text(l10n.standardInvoiceStatusUnderReview, style: const TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'REJECTED_NEEDS_MODIFICATION', child: Text(l10n.standardInvoiceStatusRejected, style: const TextStyle(fontSize: 12))),
              ],
              onChanged: (v) {
                if (v != null) onFilterChanged(v);
              },
            ),
          ),
        ),
        AppButton(
          label: l10n.standardInvoiceSessionsExportTsvBtn,
          icon: Icons.table_view_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () async {
            final sessions = sessionsAsync.valueOrNull ?? [];
            if (sessions.isEmpty) return;
            await CargoXExportService.saveSessionsTsvToFile(context: context, sessions: sessions, shipments: importFiles);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(context, l10n.cargoxCopiedTsvSuccess),
            );
          },
        ),
        AppButton(
          label: l10n.standardInvoiceSessionsExportExcelBtn,
          icon: Icons.file_present_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () async {
            final sessions = sessionsAsync.valueOrNull ?? [];
            if (sessions.isEmpty) return;
            await CargoXExportService.saveSessionsCsvToFile(context: context, sessions: sessions, shipments: importFiles);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(context, l10n.cargoxCopiedExcelSuccess),
            );
          },
        ),
        AppButton(
          label: l10n.standardInvoiceSessionsPrintPdfBtn,
          icon: Icons.picture_as_pdf_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () async {
            final sessions = sessionsAsync.valueOrNull ?? [];
            if (sessions.isEmpty) return;
            await CargoXExportService.printOrSaveSessionsPdf(context: context, sessions: sessions, shipments: importFiles);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(context, l10n.cargoxExportPdfDialogTitle),
            );
          },
        ),
        AppButton(
          label: l10n.standardInvoiceSessionsCopyDossierBtn,
          icon: Icons.copy_all_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () {
            final sessions = sessionsAsync.valueOrNull ?? [];
            if (sessions.isEmpty) return;
            CargoXExportService.copySessionsDossier(context: context, sessions: sessions, shipments: importFiles);
          },
        ),
      ],
    );
  }
}
