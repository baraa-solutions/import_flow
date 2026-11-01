import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/cargox_model.dart';
import '../../services/cargox_export_service.dart';

/// Actions bar with search, status filter, export shortcuts, and new envelope trigger.
class CargoXHubActionsBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String statusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final List<CargoXEnvelopeModel> filteredEnvelopes;
  final List<ImportFileModel> importFiles;
  final VoidCallback onPrepareNewEnvelope;

  const CargoXHubActionsBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.filteredEnvelopes,
    required this.importFiles,
    required this.onPrepareNewEnvelope,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasItems = filteredEnvelopes.isNotEmpty;

    return Card(
      elevation: 1,
      color: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.l10n.cargoxSearchEnvelopesHint,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: statusFilter,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: 'All', child: Text(context.l10n.cargoxFilterAllStatuses)),
                  DropdownMenuItem(value: 'DRAFT', child: Text(context.l10n.cargoxFilterDraft)),
                  DropdownMenuItem(value: 'UPLOADED_BY_SUPPLIER', child: Text(context.l10n.cargoxFilterUploaded)),
                  DropdownMenuItem(value: 'ACCEPTED_BY_CUSTOMS', child: Text(context.l10n.cargoxFilterAccepted)),
                ],
                onChanged: (val) => onStatusFilterChanged(val ?? 'All'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.table_view_outlined, size: 16, color: AppTheme.cobalt),
                label: Text(
                  context.l10n.cargoxExportTsvBtn,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.cobalt),
                ),
                onPressed: !hasItems
                    ? null
                    : () async {
                        await CargoXExportService.saveEnvelopesTsvToFile(
                          context: context,
                          envelopes: filteredEnvelopes,
                          shipments: importFiles,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          AppTheme.snackBar(
                            context,
                            context.l10n.cargoxCopiedTsvSuccess,
                            severity: AppSeverity.success,
                          ),
                        );
                      },
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.file_present_outlined, size: 16, color: AppTheme.emerald),
                label: Text(
                  context.l10n.cargoxExportExcelBtn,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.emerald),
                ),
                onPressed: !hasItems
                    ? null
                    : () async {
                        await CargoXExportService.saveEnvelopesCsvToFile(
                          context: context,
                          envelopes: filteredEnvelopes,
                          shipments: importFiles,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          AppTheme.snackBar(
                            context,
                            context.l10n.cargoxCopiedExcelSuccess,
                            severity: AppSeverity.success,
                          ),
                        );
                      },
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.purple),
                label: Text(
                  context.l10n.cargoxPrintPdfBtn,
                  style: const TextStyle(fontSize: 11.5, color: Colors.purple),
                ),
                onPressed: !hasItems
                    ? null
                    : () async {
                        await CargoXExportService.printOrSaveEnvelopesPdf(
                          context: context,
                          envelopes: filteredEnvelopes,
                          shipments: importFiles,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          AppTheme.snackBar(
                            context,
                            context.l10n.cargoxExportPdfDialogTitle,
                            severity: AppSeverity.info,
                          ),
                        );
                      },
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.copy_all_outlined, size: 16, color: AppTheme.charcoal),
                label: Text(
                  context.l10n.cargoxCopyDossierBtn,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal),
                ),
                onPressed: !hasItems
                    ? null
                    : () {
                        CargoXExportService.copyEnvelopesDossier(
                          context: context,
                          envelopes: filteredEnvelopes,
                          shipments: importFiles,
                        );
                      },
              ),
              const SizedBox(width: 8),
              AppButton(
                label: context.l10n.cargoxPrepareNewEnvelopeBtn,
                icon: Icons.add,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: onPrepareNewEnvelope,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
