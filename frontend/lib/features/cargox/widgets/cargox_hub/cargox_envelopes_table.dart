import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/cargox_model.dart';
import 'cargox_hub_helpers.dart';

/// Envelopes tracking table and card list component.
class CargoXEnvelopesTable extends StatelessWidget {
  final List<CargoXEnvelopeModel> envelopes;
  final List<ImportFileModel> importFiles;
  final ValueChanged<int> onVerifyAcid;
  final ValueChanged<CargoXEnvelopeModel> onViewManifest;
  final ValueChanged<CargoXEnvelopeModel> onSealAndTransfer;

  const CargoXEnvelopesTable({
    super.key,
    required this.envelopes,
    required this.importFiles,
    required this.onVerifyAcid,
    required this.onViewManifest,
    required this.onSealAndTransfer,
  });

  @override
  Widget build(BuildContext context) {
    if (envelopes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            context.l10n.cargoxNoEnvelopesFound,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: envelopes.map((env) => _buildEnvelopeCard(context, env)).toList(),
    );
  }

  Widget _buildEnvelopeCard(BuildContext context, CargoXEnvelopeModel env) {
    final isAccepted = env.status == 'ACCEPTED_BY_CUSTOMS';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
      env.importFileCode,
      shipments: importFiles,
      isArabic: isAr,
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.markunread_mailbox, color: AppTheme.cobalt, size: 22),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => CopyHelper.copy(
                          context,
                          env.envelopeCode,
                          customMessage: context.l10n.cargoxCopiedEnvelopeSuccess(env.envelopeCode),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              env.envelopeCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.charcoal,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                          ],
                        ),
                      ),
                      if (env.importFileCode != null) ...[
                        const SizedBox(width: 10),
                        if (shipmentName != env.importFileCode) ...[
                          Flexible(
                            child: Text(
                              shipmentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.charcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        InkWell(
                          onTap: () => CopyHelper.copy(
                            context,
                            env.importFileCode!,
                            customMessage: context.l10n.cargoxCopiedToClipboard,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  env.importFileCode!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.copy, size: 12, color: AppTheme.cobalt),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_all, size: 16, color: AppTheme.cobalt),
                      tooltip: context.l10n.cargoxCopyDossierBtn,
                      onPressed: () => _copyEnvelopeDossier(context, env, isAr),
                    ),
                    const SizedBox(width: 4),
                    AppStatusBadge(
                      label: switch (env.status) {
                        'ACCEPTED_BY_CUSTOMS' => context.l10n.cargoxFilterAccepted,
                        'UPLOADED_BY_SUPPLIER' => context.l10n.cargoxFilterUploaded,
                        'SEALED_AND_TRANSFERRED' => context.l10n.cargoxFilterAccepted,
                        'DRAFT' => context.l10n.cargoxFilterDraft,
                        _ => env.status,
                      },
                      severity: switch (env.status) {
                        'ACCEPTED_BY_CUSTOMS' => AppSeverity.success,
                        'UPLOADED_BY_SUPPLIER' => AppSeverity.info,
                        'SEALED_AND_TRANSFERRED' => AppSeverity.info,
                        'DRAFT' => AppSeverity.warning,
                        _ => AppSeverity.info,
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18),

            // Metadata Grid
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _buildMetaItem(
                  context,
                  context.l10n.cargoxMetaAcidNumber,
                  env.acidNumber,
                  isCopyable: true,
                ),
                _buildMetaItem(context, context.l10n.cargoxMetaSupplier, env.supplierName),
                _buildMetaItem(context, context.l10n.cargoxMetaSupplierCargoxId, env.supplierCargoxId),
                _buildMetaItem(
                  context,
                  context.l10n.cargoxMetaBlNumber,
                  env.blNumber ?? context.l10n.cargoxMetaPendingIssuance,
                ),
                if (env.blockchainTxHash != null)
                  _buildMetaItem(
                    context,
                    context.l10n.cargoxMetaBlockchainTxHash,
                    '${env.blockchainTxHash!.substring(0, 16)}...',
                    isCopyable: true,
                    fullValue: env.blockchainTxHash,
                  ),
                if (env.customsConfirmationReceipt != null)
                  _buildMetaItem(
                    context,
                    context.l10n.cargoxMetaCustomsReceipt,
                    env.customsConfirmationReceipt!,
                    isCopyable: true,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Documents Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: env.documents.map((d) {
                final docSummary = '${d.docType}: ${d.fileName} (${d.fileSizeKb} KB)';
                return ActionChip(
                  avatar: const Icon(Icons.attach_file, size: 14, color: AppTheme.cobalt),
                  label: Text(
                    '${localizeCargoXDocType(context, d.docType)} (${d.fileName})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.grey.shade100,
                  padding: const EdgeInsets.all(4),
                  tooltip: context.l10n.copyTooltip,
                  onPressed: () {
                    CopyHelper.copy(
                      context,
                      docSummary,
                      customMessage: context.l10n.cargoxCopiedAttachedDocSuccess(d.fileName),
                    );
                  },
                );
              }).toList(),
            ),
            const Divider(height: 18),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.verified_outlined, size: 15, color: Colors.purple),
                  label: Text(
                    context.l10n.cargoxCheckAcidBtn,
                    style: const TextStyle(fontSize: 11, color: Colors.purple),
                  ),
                  onPressed: () => onVerifyAcid(env.envelopeId),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.receipt_long, size: 15, color: AppTheme.cobalt),
                  label: Text(
                    context.l10n.cargoxDigitalManifestBtn,
                    style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                  ),
                  onPressed: () => onViewManifest(env),
                ),
                const SizedBox(width: 8),
                if (!isAccepted)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.send_to_mobile, size: 15, color: Colors.white),
                    label: Text(
                      context.l10n.cargoxSealAndTransferBtn,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => onSealAndTransfer(env),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      context.l10n.cargoxDeliveredAndAcceptedBadge,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(
    BuildContext context,
    String label,
    String value, {
    bool isCopyable = false,
    String? fullValue,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
        ),
        if (isCopyable) ...[
          const SizedBox(width: 2),
          InkWell(
            onTap: () {
              CopyHelper.copy(
                context,
                fullValue ?? value,
                customMessage: context.l10n.cargoxCopiedToClipboard,
              );
            },
            child: const Icon(Icons.copy, size: 13, color: AppTheme.cobalt),
          ),
        ],
      ],
    );
  }

  void _copyEnvelopeDossier(BuildContext context, CargoXEnvelopeModel env, bool isAr) {
    final summary = StringBuffer();
    final resolvedShipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
      env.importFileCode,
      shipments: importFiles,
      isArabic: isAr,
    );
    summary.writeln('${context.l10n.cargoxTsvHeaderEnvelopeCode}: ${env.envelopeCode}');
    summary.writeln('${context.l10n.cargoxTsvHeaderImportFile}: $resolvedShipmentTitle');
    summary.writeln('${context.l10n.cargoxTsvHeaderAcid}: ${env.acidNumber}');
    summary.writeln('${context.l10n.cargoxTsvHeaderSupplier}: ${env.supplierName}');
    summary.writeln('${context.l10n.cargoxTsvHeaderSupplierCargoxId}: ${env.supplierCargoxId}');
    summary.writeln('${context.l10n.cargoxTsvHeaderBlNumber}: ${env.blNumber ?? "—"}');
    summary.writeln('${context.l10n.cargoxTsvHeaderStatus}: ${env.status}');
    if (env.blockchainTxHash != null) {
      summary.writeln('${context.l10n.cargoxTsvHeaderTxHash}: ${env.blockchainTxHash}');
    }
    if (env.customsConfirmationReceipt != null) {
      summary.writeln('${context.l10n.cargoxTsvHeaderCustomsReceipt}: ${env.customsConfirmationReceipt}');
    }
    summary.writeln('${context.l10n.cargoxTsvHeaderDocsCount}: ${env.documents.length}');
    for (final d in env.documents) {
      summary.writeln('  - ${localizeCargoXDocType(context, d.docType)}: ${d.fileName} (${d.fileSizeKb} KB)');
    }
    CopyHelper.copy(
      context,
      summary.toString().trim(),
      customMessage: context.l10n.cargoxCopiedEnvelopeSuccess(env.envelopeCode),
    );
  }
}
