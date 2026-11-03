import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import 'cargox_add_document_dialog.dart';
import 'cargox_hub_helpers.dart';

/// Card containing attached documents matrix for CargoX envelope creation.
class CargoXAttachedDocsTable extends StatelessWidget {
  final List<Map<String, dynamic>> attachedDocs;
  final VoidCallback onRestoreDefaults;
  final ValueChanged<int> onRemoveDoc;
  final ValueChanged<Map<String, dynamic>> onAddDoc;

  const CargoXAttachedDocsTable({
    super.key,
    required this.attachedDocs,
    required this.onRestoreDefaults,
    required this.onRemoveDoc,
    required this.onAddDoc,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rtl_outlined, color: AppTheme.emerald, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.cargoxSection2AttachedDocs,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: AppTheme.charcoal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    icon: const Icon(Icons.restore_page, size: 16),
                    label: Text(
                      context.l10n.cargoxRestoreDefaultDocsBtn,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: onRestoreDefaults,
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Documents Table
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(2.2),
                1: FlexColumnWidth(1.8),
                2: FlexColumnWidth(2.5),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1.0),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppTheme.charcoal),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        context.l10n.cargoxColDocType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        context.l10n.cargoxColDocNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        context.l10n.cargoxColFileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        context.l10n.cargoxColFileSize,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        context.l10n.cargoxColAcidMatch,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        context.l10n.cargoxColActions,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                ...attachedDocs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final doc = entry.value;
                  final locType = localizeCargoXDocType(context, doc['doc_type']?.toString());
                  final fullRow = '$locType\t${doc['doc_number'] ?? '-'}\t${doc['file_name'] ?? ''}\t${doc['file_size_kb']} KB';

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: CopyableTableCell(
                          value: locType,
                          rowSummary: fullRow,
                          child: Text(locType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: CopyableTableCell(
                          value: doc['doc_number']?.toString() ?? '-',
                          rowSummary: fullRow,
                          child: Text(doc['doc_number'] ?? '-', style: const TextStyle(fontSize: 11.5)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: CopyableTableCell(
                          value: doc['file_name']?.toString() ?? '',
                          rowSummary: fullRow,
                          child: Text(doc['file_name'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: CopyableTableCell(
                          value: '${doc['file_size_kb']} KB',
                          rowSummary: fullRow,
                          child: Text('${doc['file_size_kb']} KB', style: const TextStyle(fontSize: 11.5)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: CopyableTableCell(
                          value: context.l10n.cargoxDocMatchedBadge,
                          rowSummary: fullRow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              context.l10n.cargoxDocMatchedBadge,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 15, color: AppTheme.cobalt),
                            tooltip: context.l10n.copy,
                            onPressed: () {
                              CopyHelper.copy(
                                context,
                                fullRow,
                                customMessage: context.l10n.cargoxCopiedAttachedDocSuccess(
                                  doc['file_name'] ?? locType,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            onPressed: () => onRemoveDoc(idx),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: context.l10n.cargoxAddDocToEnvelopeBtn,
              icon: Icons.add,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => CargoXAddDocumentDialog.show(context, onAdd: onAddDoc),
            ),
          ],
        ),
      ),
    );
  }
}
