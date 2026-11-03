import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/original_documents_collection_model.dart';
import '../idoc_ui.dart';

/// Filter bar and metrics cards for Original Documents Collection.
/// Contains the shipment selector dropdown, refresh button, and readiness metrics.
class OriginalDocsFilterBar extends StatelessWidget {
  final ImportFileModel? selectedImportFile;
  final List<OriginalDocumentItemModel> documents;
  final AsyncValue<List<ImportFileModel>> filesAsync;
  final ValueChanged<ImportFileModel> onSelectImportFile;
  final VoidCallback onRefreshFiles;

  const OriginalDocsFilterBar({
    super.key,
    required this.selectedImportFile,
    required this.documents,
    required this.filesAsync,
    required this.onSelectImportFile,
    required this.onRefreshFiles,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFileSelector(context, l),
          if (selectedImportFile != null) ...[
            const SizedBox(height: 16),
            _buildStatisticsCards(l),
          ],
        ],
      ),
    );
  }

  Widget _buildFileSelector(BuildContext context, AppLocalizations l) {
    final acidLabel = l.idocAACID;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: filesAsync.when(
        data: (files) {
          return Row(
            children: [
              Expanded(
                child: SearchableDropdownField<int>(
                  labelText: l.selectImportFileLabel,
                  hintText: l.selectImportFileHint,
                  value: selectedImportFile?.importFileId,
                  items: files
                      .map((f) => SearchableDropdownItem<int>(
                            value: f.importFileId,
                            label:
                                '${f.primaryNameWithCode} — ${f.supplierName} (${f.companyName}) [$acidLabel: ${f.acidNumber ?? "—"}]',
                            searchValue:
                                '${f.primaryNameWithCode} ${f.supplierName} ${f.companyName} ${f.acidNumber ?? ""}',
                          ))
                      .toList(),
                  onChanged: (fileId) {
                    if (fileId != null) {
                      final match = files.where((f) => f.importFileId == fileId).firstOrNull;
                      if (match != null) onSelectImportFile(match);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              IdocUi.fit(
                AppButton(
                  label: l.refreshDataTooltip,
                  icon: Icons.refresh,
                  variant: AppButtonVariant.primary,
                  onPressed: onRefreshFiles,
                ),
              ),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(
          l.errorFetchingImportFiles(e),
          style: const TextStyle(color: AppTheme.crimson),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards(AppLocalizations l) {
    final totalDocs = documents.length;
    final receivedDocs = documents.where((d) => d.isReceived).length;
    final verifiedDocs = documents.where((d) => d.isVerified).length;
    final pendingDocs = totalDocs - receivedDocs;
    final completionPct = totalDocs > 0
        ? (verifiedDocs / totalDocs * 100).toStringAsFixed(1)
        : '0.0';

    MetricCardData metric(String label, String value, IconData icon, Color color) =>
        MetricCardData(
          title: label,
          shortTitle: label,
          value: value,
          icon: icon,
          color: color,
        );

    return IdocUi.metrics([
      metric(l.statTotalRequiredDocs, '$totalDocs', Icons.description_outlined, AppTheme.charcoal),
      metric(l.statReceivedOriginals, '$receivedDocs', Icons.inbox_outlined, AppTheme.cobalt),
      metric(l.statVerifiedDocs, '$verifiedDocs', Icons.verified_outlined, AppTheme.emerald),
      metric(l.statPendingDocs, '$pendingDocs', Icons.hourglass_empty_outlined, AppTheme.orange),
      metric(l.statReadinessRate, '$completionPct%', Icons.pie_chart_outline, AppTheme.wcagCobalt),
    ]);
  }
}
