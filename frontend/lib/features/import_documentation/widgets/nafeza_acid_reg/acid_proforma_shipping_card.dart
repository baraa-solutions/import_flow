import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

class AcidProformaShippingCard extends StatelessWidget {
  final TextEditingController proformaNoCtrl;
  final TextEditingController proformaDateCtrl;
  final String invoiceType;
  final ValueChanged<String?> onInvoiceTypeChanged;
  final TextEditingController polCtrl;
  final TextEditingController podCtrl;
  final List<dynamic> brokers;
  final int? selectedBrokerId;
  final ValueChanged<int?> onBrokerChanged;
  final TextEditingController brokerPhoneCtrl;
  final TextEditingController requestedDateCtrl;
  final bool isSaving;
  final int? editingAcidSessionId;
  final VoidCallback onSave;
  final VoidCallback? onGoToSmartParser;
  final VoidCallback? onOpenSearchAndClone;
  final bool isMobile;

  const AcidProformaShippingCard({
    super.key,
    required this.proformaNoCtrl,
    required this.proformaDateCtrl,
    required this.invoiceType,
    required this.onInvoiceTypeChanged,
    required this.polCtrl,
    required this.podCtrl,
    required this.brokers,
    required this.selectedBrokerId,
    required this.onBrokerChanged,
    required this.brokerPhoneCtrl,
    required this.requestedDateCtrl,
    required this.isSaving,
    required this.editingAcidSessionId,
    required this.onSave,
    this.onGoToSmartParser,
    this.onOpenSearchAndClone,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.proformaPortsBrokerSection,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          const Divider(height: 24),
          if (isMobile) ...[
            TextFormField(
              controller: proformaNoCtrl,
              decoration: InputDecoration(
                labelText: '${l.proformaInvoiceNoLabel} *',
                prefixIcon: const Icon(Icons.receipt_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? l.proformaInvoiceNoLabel : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: proformaDateCtrl,
              decoration: InputDecoration(
                labelText: '${l.proformaInvoiceDateLabel} *',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SearchableDropdownField<String>(
              value: invoiceType,
              labelText: l.invoiceTypeLabel,
              items: [
                SearchableDropdownItem(value: 'Proforma Invoice', label: l.proformaInvoiceLabel),
                SearchableDropdownItem(value: 'Commercial Invoice', label: l.commercialInvoiceLabel),
              ],
              onChanged: onInvoiceTypeChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: polCtrl,
              decoration: InputDecoration(
                labelText: '${l.portOfLoadingLabel} *',
                prefixIcon: const Icon(Icons.directions_boat_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? l.portOfLoadingLabel : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: podCtrl,
              decoration: InputDecoration(
                labelText: '${l.portOfDischargeLabel} *',
                prefixIcon: const Icon(Icons.anchor),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? l.portOfDischargeLabel : null,
            ),
            const SizedBox(height: 12),
            SearchableDropdownField<int>(
              labelText: l.customsBrokerResponsibleLabel,
              hintText: l.searchFileOrSupplierHint,
              value: selectedBrokerId,
              items: brokers.map((b) => SearchableDropdownItem<int>(
                value: b.providerId ?? 0,
                label: '${b.partnerName} (${b.partnerCode})',
              )).toList(),
              onChanged: onBrokerChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: brokerPhoneCtrl,
              decoration: InputDecoration(
                labelText: l.brokerPhoneLabel,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: requestedDateCtrl,
              decoration: InputDecoration(
                labelText: '${l.acidRequestDateLabel} *',
                prefixIcon: const Icon(Icons.event_available),
                border: const OutlineInputBorder(),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: proformaNoCtrl,
                    decoration: InputDecoration(
                      labelText: '${l.proformaInvoiceNoLabel} *',
                      prefixIcon: const Icon(Icons.receipt_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? l.proformaInvoiceNoLabel : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: proformaDateCtrl,
                    decoration: InputDecoration(
                      labelText: '${l.proformaInvoiceDateLabel} *',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SearchableDropdownField<String>(
                    value: invoiceType,
                    labelText: l.invoiceTypeLabel,
                    items: [
                      SearchableDropdownItem(value: 'Proforma Invoice', label: l.proformaInvoiceLabel),
                      SearchableDropdownItem(value: 'Commercial Invoice', label: l.commercialInvoiceLabel),
                    ],
                    onChanged: onInvoiceTypeChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: polCtrl,
                    decoration: InputDecoration(
                      labelText: '${l.portOfLoadingLabel} *',
                      prefixIcon: const Icon(Icons.directions_boat_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? l.portOfLoadingLabel : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: podCtrl,
                    decoration: InputDecoration(
                      labelText: '${l.portOfDischargeLabel} *',
                      prefixIcon: const Icon(Icons.anchor),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? l.portOfDischargeLabel : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SearchableDropdownField<int>(
                    labelText: l.customsBrokerResponsibleLabel,
                    hintText: l.searchFileOrSupplierHint,
                    value: selectedBrokerId,
                    items: brokers.map((b) => SearchableDropdownItem<int>(
                      value: b.providerId ?? 0,
                      label: '${b.partnerName} (${b.partnerCode})',
                    )).toList(),
                    onChanged: onBrokerChanged,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: brokerPhoneCtrl,
                    decoration: InputDecoration(
                      labelText: l.brokerPhoneLabel,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: requestedDateCtrl,
                    decoration: InputDecoration(
                      labelText: '${l.acidRequestDateLabel} *',
                      prefixIcon: const Icon(Icons.event_available),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Submit & Action Buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AppButton(
                key: const Key('saveAcidRequestSubmitBtn'),
                label: isSaving
                    ? l.loading
                    : (editingAcidSessionId != null ? l.updateAcidRequestButton : l.saveAcidRequestButton),
                onPressed: isSaving ? null : onSave,
                icon: Icons.save,
                isLoading: isSaving,
              ),
              AppButton(
                label: l.goToSmartParserButton,
                onPressed: onGoToSmartParser,
                variant: AppButtonVariant.secondary,
                icon: Icons.smart_toy_outlined,
              ),
              AppButton(
                key: const Key('subtab0SearchAndCloneBtn'),
                label: l.searchAndCloneAcidBtn,
                onPressed: onOpenSearchAndClone,
                variant: AppButtonVariant.secondary,
                icon: Icons.copy_all,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
