import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../models/original_documents_collection_model.dart';
import '../idoc_ui.dart';
import 'original_docs_localizer.dart';

/// Physical verification matrix table for Original Documents Collection.
/// Wrapped in [SelectionArea] with sanitized clipboard operations.
class OriginalDocsDossierTable extends StatelessWidget {
  final List<OriginalDocumentItemModel> documents;
  final List<CourierEntryModel> couriers;
  final String currentUserName;
  final VoidCallback onAddCustomDocument;
  final ValueChanged<int> onRemoveDocument;
  final VoidCallback onChanged;

  const OriginalDocsDossierTable({
    super.key,
    required this.documents,
    required this.couriers,
    required this.currentUserName,
    required this.onAddCustomDocument,
    required this.onRemoveDocument,
    required this.onChanged,
  });

  static const List<String> _categories = [
    'Commercial',
    'Certificate',
    'Shipping',
    'Egypt Import',
    'Banking',
    'Regulatory',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(18),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_view_outlined, color: AppTheme.emerald, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      l.physicalDocsVerificationMatrixHeader,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.charcoal,
                      ),
                    ),
                  ],
                ),
                IdocUi.fit(
                  AppButton(
                    label: l.addCustomDocBtn,
                    icon: Icons.add,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: onAddCustomDocument,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
                headingTextStyle: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columns: [
                  DataColumn(label: Text(l.colAction)),
                  DataColumn(label: Text(l.colCourierNo)),
                  DataColumn(label: Text(l.colDocCategory)),
                  DataColumn(label: Text(l.colDocName)),
                  DataColumn(label: Text(l.colRequirement)),
                  DataColumn(label: Text(l.colResponsibleParty)),
                  DataColumn(label: Text(l.colPhysicalReceived)),
                  DataColumn(label: Text(l.colReceivedDate)),
                  DataColumn(label: Text(l.colVerified)),
                  DataColumn(label: Text(l.colAuditor)),
                  DataColumn(label: Text(l.colDocStatus)),
                  DataColumn(label: Text(l.colRemarks)),
                ],
                rows: List.generate(documents.length, (index) {
                  final doc = documents[index];
                  final catLabel = OriginalDocsLocalizer.getDocCategoryLabel(context, doc.category);
                  final reqLabel = OriginalDocsLocalizer.getRequirementLabel(context, doc.isRequired);
                  final partyLabel = OriginalDocsLocalizer.getResponsiblePartyLabel(context, doc.responsibleParty);
                  final statusLabel = OriginalDocsLocalizer.getStatusLabel(context, doc.status);

                  final rowSummary = '${doc.documentName} | $catLabel | $reqLabel | $partyLabel | '
                      '${doc.courierNo ?? "—"} | $statusLabel | '
                      '${l.colPhysicalReceived}: ${doc.isReceived ? "Yes" : "No"} (${doc.receivedDate ?? "—"}) | '
                      '${l.colVerified}: ${doc.isVerified ? "Yes" : "No"} (${doc.verificationDate ?? "—"} - ${doc.verifiedBy ?? "—"})';

                  return DataRow(
                    cells: [
                      // Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18, color: AppTheme.cobalt),
                              tooltip: l.originalDocsCopyRowSuccess,
                              onPressed: () => CopyHelper.copy(
                                context,
                                rowSummary,
                                customMessage: l.originalDocsCopyRowSuccess,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                              tooltip: l.colAction,
                              onPressed: () => onRemoveDocument(index),
                            ),
                          ],
                        ),
                      ),
                      // Courier No
                      DataCell(
                        CopyableTableCell(
                          value: doc.courierNo ?? '',
                          rowSummary: rowSummary,
                          child: SizedBox(
                            width: 140,
                            child: SearchableDropdownField<String>(
                              value: couriers.any((c) => c.courierNo == doc.courierNo && c.courierNo.isNotEmpty)
                                  ? doc.courierNo
                                  : null,
                              labelText: l.selectCourierPlaceholder,
                              hintText: l.selectCourierPlaceholder,
                              decoration: const InputDecoration(border: InputBorder.none),
                              items: couriers
                                  .where((c) => c.courierNo.isNotEmpty)
                                  .map((c) => SearchableDropdownItem<String>(value: c.courierNo, label: c.courierNo))
                                  .toList(),
                              onChanged: (val) {
                                doc.courierNo = val;
                                onChanged();
                              },
                            ),
                          ),
                        ),
                      ),
                      // Category
                      DataCell(
                        CopyableTableCell(
                          value: catLabel,
                          rowSummary: rowSummary,
                          child: SizedBox(
                            width: 110,
                            child: SearchableDropdownField<String>(
                              value: doc.category,
                              labelText: l.colCategory,
                              decoration: const InputDecoration(border: InputBorder.none),
                              items: _categories
                                  .map((cat) => SearchableDropdownItem<String>(
                                        value: cat,
                                        label: OriginalDocsLocalizer.getDocCategoryLabel(context, cat),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  doc.category = val;
                                  onChanged();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      // Document Name
                      DataCell(
                        CopyableTableCell(
                          value: doc.documentName,
                          rowSummary: rowSummary,
                          child: SizedBox(
                            width: 170,
                            child: TextFormField(
                              initialValue: doc.documentName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                                  tooltip: l.originalDocsCopyRowSuccess,
                                  onPressed: doc.documentName.isNotEmpty
                                      ? () => CopyHelper.copy(
                                            context,
                                            doc.documentName,
                                            customMessage: l.originalDocsCopyRowSuccess,
                                          )
                                      : null,
                                ),
                              ),
                              onChanged: (val) {
                                doc.documentName = val.trim();
                                onChanged();
                              },
                            ),
                          ),
                        ),
                      ),
                      // Required
                      DataCell(
                        CopyableTableCell(
                          value: reqLabel,
                          rowSummary: rowSummary,
                          child: OriginalDocsLocalizer.buildRequiredBadge(context, doc.isRequired),
                        ),
                      ),
                      // Responsible Party
                      DataCell(
                        CopyableTableCell(
                          value: partyLabel,
                          rowSummary: rowSummary,
                          child: Text(partyLabel, style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                      // Received Checkbox
                      DataCell(
                        CopyableTableCell(
                          value: doc.isReceived ? 'Yes' : 'No',
                          rowSummary: rowSummary,
                          child: Checkbox(
                            value: doc.isReceived,
                            activeColor: AppTheme.cobalt,
                            onChanged: (val) {
                              doc.isReceived = val ?? false;
                              if (doc.isReceived && (doc.receivedDate == null || doc.receivedDate!.isEmpty)) {
                                doc.receivedDate = DateTime.now().toIso8601String().substring(0, 10);
                              }
                              if (doc.isReceived && doc.status == 'Pending') {
                                doc.status = 'Received';
                              }
                              onChanged();
                            },
                          ),
                        ),
                      ),
                      // Received Date
                      DataCell(
                        CopyableTableCell(
                          value: doc.receivedDate ?? '',
                          rowSummary: rowSummary,
                          child: SizedBox(
                            width: 100,
                            child: TextFormField(
                              initialValue: doc.receivedDate,
                              style: const TextStyle(fontSize: 11),
                              decoration: const InputDecoration(hintText: 'YYYY-MM-DD', border: InputBorder.none),
                              onChanged: (val) {
                                doc.receivedDate = val.trim();
                                onChanged();
                              },
                            ),
                          ),
                        ),
                      ),
                      // Verified Checkbox
                      DataCell(
                        CopyableTableCell(
                          value: doc.isVerified ? 'Yes' : 'No',
                          rowSummary: rowSummary,
                          child: Checkbox(
                            value: doc.isVerified,
                            activeColor: AppTheme.emerald,
                            onChanged: (val) {
                              doc.isVerified = val ?? false;
                              if (doc.isVerified) {
                                doc.isReceived = true;
                                doc.status = 'Verified';
                                if (doc.verificationDate == null || doc.verificationDate!.isEmpty) {
                                  doc.verificationDate = DateTime.now().toIso8601String().substring(0, 10);
                                }
                                if (doc.verifiedBy == null || doc.verifiedBy!.isEmpty) {
                                  doc.verifiedBy = currentUserName;
                                }
                              } else {
                                doc.status = doc.isReceived ? 'Received' : 'Pending';
                              }
                              onChanged();
                            },
                          ),
                        ),
                      ),
                      // Verified By
                      DataCell(
                        CopyableTableCell(
                          value: doc.verifiedBy ?? '',
                          rowSummary: rowSummary,
                          child: SizedBox(
                            width: 100,
                            child: TextFormField(
                              initialValue: doc.verifiedBy,
                              style: const TextStyle(fontSize: 11),
                              decoration: InputDecoration(hintText: l.hintAuditor, border: InputBorder.none),
                              onChanged: (val) {
                                doc.verifiedBy = val.trim();
                                onChanged();
                              },
                            ),
                          ),
                        ),
                      ),
                      // Status Badge
                      DataCell(
                        CopyableTableCell(
                          value: statusLabel,
                          rowSummary: rowSummary,
                          child: OriginalDocsLocalizer.buildStatusBadge(context, doc.status),
                        ),
                      ),
                      // Remarks
                      DataCell(
                        CopyableTableCell(
                          value: doc.remarks ?? '',
                          rowSummary: rowSummary,
                          child: SizedBox(
                            width: 140,
                            child: TextFormField(
                              initialValue: doc.remarks,
                              style: const TextStyle(fontSize: 11),
                              decoration: InputDecoration(hintText: l.hintRemarks, border: InputBorder.none),
                              onChanged: (val) {
                                doc.remarks = val.trim();
                                onChanged();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
