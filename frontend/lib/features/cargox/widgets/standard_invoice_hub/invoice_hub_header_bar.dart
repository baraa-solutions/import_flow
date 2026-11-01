import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/cargox_model.dart';
import 'invoice_hub_formatters.dart';

/// Header bar and file selector for Standard Invoice Hub.
class InvoiceHubHeaderBar extends StatelessWidget {
  final ImportFileModel? selectedImportFile;
  final StandardInvoiceSessionModel? existingSession;
  final AsyncValue<List<ImportFileModel>> filesAsync;
  final ValueChanged<ImportFileModel> onSelectImportFile;
  final VoidCallback onRefresh;
  final VoidCallback? onViewExistingSession;

  const InvoiceHubHeaderBar({
    super.key,
    required this.selectedImportFile,
    required this.existingSession,
    required this.filesAsync,
    required this.onSelectImportFile,
    required this.onRefresh,
    this.onViewExistingSession,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderBanner(context),
        const SizedBox(height: 16),
        _buildFileSelector(context),
        if (selectedImportFile != null) ...[
          const SizedBox(height: 12),
          _buildShipmentMetadataStrip(context, selectedImportFile!),
        ],
        if (existingSession != null) ...[
          const SizedBox(height: 12),
          _buildPreExistingStudyAlertBanner(context, existingSession!),
        ],
      ],
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.table_chart, color: AppTheme.emerald, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.standardInvoiceHubTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.standardInvoiceHubDesc,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (existingSession != null)
            AppStatusBadge.fromStatus(
              status: existingSession!.status,
              label: resolveInvoiceHubStatusLabel(context, existingSession!.status),
            ),
        ],
      ),
    );
  }

  Widget _buildFileSelector(BuildContext context) {
    final l10n = context.l10n;

    return filesAsync.when(
      data: (files) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBDC3C7).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SearchableDropdownField<int>(
                  labelText: l10n.standardInvoiceFileSelectorLabel,
                  hintText: l10n.standardInvoiceFileSelectorHint,
                  value: selectedImportFile?.importFileId,
                  items: files
                      .map((f) => SearchableDropdownItem<int>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} — ${f.supplierName} [ACID: ${f.acidNumber ?? "N/A"}]',
                            searchValue: '${f.primaryNameWithCode} ${f.supplierName} ${f.companyName} ${f.acidNumber ?? ""}',
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
              AppButton(
                label: l10n.refresh,
                icon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                onPressed: onRefresh,
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (e, _) => Text('${l10n.standardInvoiceFetchError} $e', style: const TextStyle(color: AppTheme.crimson)),
    );
  }

  Widget _buildShipmentMetadataStrip(BuildContext context, ImportFileModel file) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.sorourSurfaceTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildMetaItem(
            label: isAr ? 'الملف' : 'File',
            value: file.primaryNameWithCode,
            icon: Icons.folder_open,
          ),
          _buildMetaItem(
            label: isAr ? 'المورد' : 'Supplier',
            value: file.supplierName,
            icon: Icons.business,
          ),
          _buildMetaItem(
            label: isAr ? 'الشركة المستوردة' : 'Importer',
            value: file.companyName,
            icon: Icons.domain,
          ),
          if (file.acidNumber != null)
            _buildMetaItem(
              label: 'ACID',
              value: file.acidNumber!,
              icon: Icons.verified_user_outlined,
              isLtr: true,
            ),
          if (file.vesselName != null && file.vesselName!.isNotEmpty)
            _buildMetaItem(
              label: isAr ? 'الناقل / السفينة' : 'Carrier / Vessel',
              value: file.vesselName!,
              icon: Icons.directions_boat_outlined,
            ),
          if (file.incotermCode.isNotEmpty)
            _buildMetaItem(
              label: isAr ? 'الشرط التجاري' : 'Incoterm',
              value: file.incotermCode,
              icon: Icons.handshake_outlined,
              isLtr: true,
            ),
        ],
      ),
    );
  }

  Widget _buildMetaItem({
    required String label,
    required String value,
    required IconData icon,
    bool isLtr = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.cobalt),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
        ),
        if (isLtr)
          LtrText(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          )
        else
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
      ],
    );
  }

  Widget _buildPreExistingStudyAlertBanner(BuildContext context, StandardInvoiceSessionModel s) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.orange),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.orange, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.standardInvoiceExistingSessionTitle(s.sessionCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7D6608)),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.standardInvoiceExistingSessionSubtitle(
                    formatInvoiceHubDateTime(s.updatedAt),
                    resolveInvoiceHubStatusLabel(context, s.status),
                    s.totalAmount.toStringAsFixed(2),
                    s.currencyCode,
                    s.lineItemsCount,
                  ),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7D6608)),
                ),
              ],
            ),
          ),
          AppButton(
            label: l10n.standardInvoiceViewSessionBtn,
            variant: AppButtonVariant.warning,
            size: AppButtonSize.small,
            onPressed: onViewExistingSession,
          ),
        ],
      ),
    );
  }
}
