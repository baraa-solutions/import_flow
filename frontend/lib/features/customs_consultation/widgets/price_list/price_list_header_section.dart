import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import 'price_list_batch_upload_section.dart';

/// Header section for broker price list dialog.
/// Displays dialog title, batch upload button, error banner, broker picker,
/// title, target port, validity period (effective date), notes, and reference currency rate.
class PriceListHeaderSection extends StatelessWidget {
  final WidgetRef ref;
  final bool isEditing;
  final String existingPriceListTitle;
  final String? existingBrokerName;
  final int? selectedBroker;
  final List<dynamic> brokersList;
  final ValueChanged<int?> onBrokerChanged;
  final TextEditingController titleController;
  final TextEditingController portController;
  final DateTime? effectiveDate;
  final ValueChanged<DateTime?> onDateChanged;
  final TextEditingController notesController;
  final TextEditingController usdRateController;
  final String? errorMessage;
  final VoidCallback onClearError;
  final List<Map<String, dynamic>> itemsState;
  final void Function(Map<String, dynamic> extracted) onDataExtracted;
  final VoidCallback onClose;

  const PriceListHeaderSection({
    super.key,
    required this.ref,
    required this.isEditing,
    required this.existingPriceListTitle,
    this.existingBrokerName,
    required this.selectedBroker,
    required this.brokersList,
    required this.onBrokerChanged,
    required this.titleController,
    required this.portController,
    required this.effectiveDate,
    required this.onDateChanged,
    required this.notesController,
    required this.usdRateController,
    this.errorMessage,
    required this.onClearError,
    required this.itemsState,
    required this.onDataExtracted,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Header & AI Extract Button
        Row(
          children: [
            Icon(isEditing ? Icons.edit_note : Icons.add_circle, color: AppTheme.cobalt, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEditing ? l.editPriceListTitle(existingPriceListTitle) : l.createPriceListTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
              ),
            ),
            PriceListBatchUploadSection(
              ref: ref,
              currentItemsState: itemsState,
              onExtractionConfirmed: onDataExtracted,
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: AppTheme.textMuted),
            ),
          ],
        ),
        const Divider(height: 16),

        if (errorMessage != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.crimsonLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.crimson),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.crimson, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
                  onPressed: onClearError,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],

        // Header Form Inputs (Broker, Title, Port, Effective Date, Notes)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.charcoal.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cloudWhite),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (!isEditing)
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<int?>(
                        value: selectedBroker,
                        labelText: '${l.responsibleCustomsBroker} *',
                        searchHintText: l.searchBrokerHint,
                        items: brokersList
                            .map((b) => SearchableDropdownItem<int?>(value: b.providerId, label: b.partnerName))
                            .toList(),
                        onChanged: onBrokerChanged,
                      ),
                    )
                  else
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoalSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cloudWhite),
                        ),
                        child: Text(
                          '${l.responsibleCustomsBroker}: ${existingBrokerName ?? ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: l.priceListTitleField,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: portController,
                      decoration: InputDecoration(
                        labelText: l.targetPortField,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: AppDatePickerField(
                      label: l.effectiveDateField,
                      value: effectiveDate,
                      onChanged: onDateChanged,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: l.generalTermsAndNotesField,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: usdRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isAr ? 'سعر الصرف المرجعي بالدولار' : 'Ref USD Rate',
                        hintText: '48.50',
                        prefixIcon: const Icon(Icons.currency_exchange_rounded, size: 16, color: AppTheme.cobalt),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
