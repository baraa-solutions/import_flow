import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/original_documents_collection_model.dart';
import '../../services/original_docs_export_service.dart';
import '../idoc_ui.dart';
import 'original_docs_localizer.dart';

/// Couriers management card for registered packages and dispatch details.
/// Wrapped in [SelectionArea] with sanitized clipboard operations.
class OriginalDocsCourierTrackingCard extends StatelessWidget {
  final List<CourierEntryModel> couriers;
  final ImportFileModel? selectedImportFile;
  final VoidCallback onAddCourier;
  final ValueChanged<int> onRemoveCourier;
  final VoidCallback onChanged;
  final void Function({
    required int importFileId,
    required String courierNo,
    required String courierCompany,
    String? trackingNo,
    required String importFileCode,
  }) onShowDeliveryProof;

  const OriginalDocsCourierTrackingCard({
    super.key,
    required this.couriers,
    required this.selectedImportFile,
    required this.onAddCourier,
    required this.onRemoveCourier,
    required this.onChanged,
    required this.onShowDeliveryProof,
  });

  static const List<String> _carrierCompanies = [
    'DHL',
    'FedEx',
    'Aramex',
    'UPS',
    'Naqel',
    'SMSA',
    'Hand Delivery',
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
                    const Icon(Icons.local_shipping_outlined, color: AppTheme.cobalt, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      l.courierDispatchPackagesHeader,
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
                    label: l.addCourierAwbBtn,
                    icon: Icons.add,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: onAddCourier,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (couriers.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: Text(
                  l.noCouriersRegisteredMsg,
                  style: TextStyle(
                    color: AppTheme.textSecondaryOf(context),
                    fontSize: 13,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: couriers.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, idx) {
                  final c = couriers[idx];
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.cobalt.withValues(alpha: 0.15),
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cobalt,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Courier No
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: c.courierNo,
                          decoration: InputDecoration(
                            labelText: l.courierTrackingNoField,
                            isDense: true,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                              tooltip: l.originalDocsCopyRowSuccess,
                              onPressed: c.courierNo.isNotEmpty
                                  ? () => CopyHelper.copy(
                                        context,
                                        c.courierNo,
                                        customMessage: l.originalDocsCopyRowSuccess,
                                      )
                                  : null,
                            ),
                          ),
                          onChanged: (val) {
                            c.courierNo = val.trim();
                            onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Courier Company
                      Expanded(
                        flex: 2,
                        child: SearchableDropdownField<String>(
                          value: _carrierCompanies.contains(c.courierCompany)
                              ? c.courierCompany
                              : null,
                          labelText: l.courierCompanyField,
                          decoration: InputDecoration(
                            labelText: l.courierCompanyField,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          items: _carrierCompanies
                              .map((company) => SearchableDropdownItem<String>(
                                    value: company,
                                    label: OriginalDocsLocalizer.getCourierCompanyLabel(context, company),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              c.courierCompany = val;
                              onChanged();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dispatch Date
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: c.dispatchDate,
                          decoration: InputDecoration(
                            labelText: l.dispatchDateField,
                            isDense: true,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                              tooltip: l.originalDocsCopyRowSuccess,
                              onPressed: (c.dispatchDate != null && c.dispatchDate!.isNotEmpty)
                                  ? () => CopyHelper.copy(
                                        context,
                                        c.dispatchDate!,
                                        customMessage: l.originalDocsCopyRowSuccess,
                                      )
                                  : null,
                            ),
                          ),
                          onChanged: (val) {
                            c.dispatchDate = val.trim();
                            onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Received Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: c.isReceived,
                            activeColor: AppTheme.emerald,
                            onChanged: (val) {
                              c.isReceived = val ?? false;
                              if (c.isReceived && (c.receivedDate == null || c.receivedDate!.isEmpty)) {
                                c.receivedDate = DateTime.now().toIso8601String().substring(0, 10);
                              }
                              onChanged();
                            },
                          ),
                          Text(l.isReceivedCheckbox, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Received By
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: c.receivedBy,
                          decoration: InputDecoration(
                            labelText: l.receivedByNameField,
                            isDense: true,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                              tooltip: l.originalDocsCopyRowSuccess,
                              onPressed: (c.receivedBy != null && c.receivedBy!.isNotEmpty)
                                  ? () => CopyHelper.copy(
                                        context,
                                        c.receivedBy!,
                                        customMessage: l.originalDocsCopyRowSuccess,
                                      )
                                  : null,
                            ),
                          ),
                          onChanged: (val) {
                            c.receivedBy = val.trim();
                            onChanged();
                          },
                        ),
                      ),
                      if (c.courierNo.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18, color: AppTheme.cobalt),
                          tooltip: l.idocATrackTheCourierDirectlyOnThe,
                          onPressed: () => OriginalDocsExportService.launchCarrierTracking(
                            c.courierCompany,
                            c.courierNo,
                          ),
                        ),
                        if (selectedImportFile != null)
                          IconButton(
                            icon: Icon(
                              c.isReceived ? Icons.verified : Icons.verified_outlined,
                              size: 18,
                              color: AppTheme.emerald,
                            ),
                            tooltip: l.confirmCourierDeliveryBtn,
                            onPressed: () => onShowDeliveryProof(
                              importFileId: selectedImportFile!.importFileId,
                              courierNo: c.courierNo,
                              courierCompany: c.courierCompany,
                              trackingNo: c.courierNo,
                              importFileCode: selectedImportFile!.importFileCode,
                            ),
                          ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                        tooltip: l.deleteCourierTooltip,
                        onPressed: () => onRemoveCourier(idx),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
