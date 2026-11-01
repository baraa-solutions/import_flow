import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../currencies/models/currency_model.dart';
import '../../../external_service_providers/models/partner_model.dart';
import '../../models/import_documentation_model.dart';
import 'bank_form4_localizer.dart';

/// Form 4 Details input card with currency, bank selector, amounts, and checklist.
class BankForm4DetailsCard extends StatelessWidget {
  final bool isMobile;
  final bool isDark;
  final String bankDocType;
  final ValueChanged<String?> onDocTypeChanged;
  final TextEditingController docReferenceNumberCtrl;
  final int? selectedBankId;
  final List<PartnerModel> banksList;
  final void Function(int? bankId, String bankName) onBankChanged;
  final BankingDocumentModel? activeDoc;
  final TextEditingController bankAmountController;
  final String form4Currency;
  final ValueChanged<String?> onCurrencyChanged;
  final List<CurrencyModel> currencies;
  final TextEditingController form4RequestDateCtrl;
  final TextEditingController form4NotesCtrl;
  final Map<String, bool> checklist;
  final ValueChanged<String> onToggleChecklistItem;

  const BankForm4DetailsCard({
    super.key,
    required this.isMobile,
    required this.isDark,
    required this.bankDocType,
    required this.onDocTypeChanged,
    required this.docReferenceNumberCtrl,
    required this.selectedBankId,
    required this.banksList,
    required this.onBankChanged,
    required this.activeDoc,
    required this.bankAmountController,
    required this.form4Currency,
    required this.onCurrencyChanged,
    required this.currencies,
    required this.form4RequestDateCtrl,
    required this.form4NotesCtrl,
    required this.checklist,
    required this.onToggleChecklistItem,
  });

  Widget _buildChecklistItem(BuildContext context, String key, String title, bool isRequired) {
    final isChecked = checklist[key] ?? false;
    return InkWell(
      onTap: () => onToggleChecklistItem(key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isChecked
              ? (isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.2) : AppTheme.infoBackground)
              : (isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isChecked ? AppTheme.wcagCobalt : (isDark ? AppTheme.darkBorder : AppTheme.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isChecked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: isChecked ? AppTheme.wcagCobalt : (isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docTypeField = SearchableDropdownField<String>(
      labelText: context.l10n.idocBBankDocTypeLabel,
      hintText: context.l10n.idocBBankDocTypeHint,
      value: bankDocType,
      isRequired: true,
      items: [
        SearchableDropdownItem<String>(
          value: 'Form 4',
          label: context.l10n.idocBBankTypeForm4,
        ),
        SearchableDropdownItem<String>(
          value: 'Letter of Credit (L/C)',
          label: context.l10n.idocBBankTypeLc,
        ),
        SearchableDropdownItem<String>(
          value: 'Form 9',
          label: context.l10n.idocBBankTypeForm9,
        ),
      ],
      onChanged: onDocTypeChanged,
    );

    final refNoField = TextFormField(
      controller: docReferenceNumberCtrl,
      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: context.l10n.idocBBankRefLabel,
        hintText: context.l10n.idocBBankRefHint,
        prefixIcon: const Icon(Icons.pin_outlined),
        border: const OutlineInputBorder(),
      ),
    );

    final bankDropdown = SearchableDropdownField<int>(
      labelText: context.l10n.issuingBankLabel,
      hintText: context.l10n.selectBankHint,
      value: selectedBankId,
      isRequired: true,
      items: banksList
          .map((b) => SearchableDropdownItem<int>(
                value: b.providerId ?? 0,
                label: '${b.partnerName} (${b.partnerCode})',
              ))
          .toList(),
      onChanged: (val) {
        final b = banksList.where((p) => p.providerId == val).firstOrNull;
        onBankChanged(val, b?.partnerName ?? '');
      },
    );

    final swiftBankMatchWidget = (activeDoc != null && activeDoc?.swiftExecutingBankId != null)
        ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  selectedBankId == activeDoc?.swiftExecutingBankId
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  size: 14,
                  color: selectedBankId == activeDoc?.swiftExecutingBankId
                      ? AppTheme.wcagEmerald
                      : AppTheme.crimson,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    selectedBankId == activeDoc?.swiftExecutingBankId
                        ? BankForm4Localizer.swiftMatchSuccess(context, activeDoc?.swiftExecutingBankName ?? '')
                        : BankForm4Localizer.swiftMatchWarning(context, activeDoc?.swiftExecutingBankName ?? ''),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selectedBankId == activeDoc?.swiftExecutingBankId
                          ? AppTheme.wcagEmerald
                          : AppTheme.crimson,
                    ),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    final bankAmountField = TextFormField(
      controller: bankAmountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: context.l10n.bankAmountLabel,
        prefixIcon: const Icon(Icons.attach_money),
        suffixText: form4Currency,
        border: const OutlineInputBorder(),
      ),
      validator: (val) => val == null || val.trim().isEmpty ? context.l10n.requiredField : null,
    );

    final currencyField = SearchableDropdownField<String>(
      labelText: context.l10n.transferCurrencyLabel,
      hintText: context.l10n.selectCurrencyHint,
      value: form4Currency,
      isRequired: true,
      items: (currencies.isNotEmpty
              ? currencies.map((c) => c.currencyCode).toSet()
              : ['USD', 'EUR', 'GBP', 'CNY', 'SAR', 'AED', 'EGP'])
          .map((code) => SearchableDropdownItem<String>(
                value: code,
                label: code,
              ))
          .toList(),
      onChanged: onCurrencyChanged,
    );

    final requestDateField = TextFormField(
      controller: form4RequestDateCtrl,
      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: context.l10n.bankRequestDateLabel,
        prefixIcon: const Icon(Icons.calendar_today),
        border: const OutlineInputBorder(),
      ),
    );

    final notesField = TextFormField(
      controller: form4NotesCtrl,
      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: context.l10n.bankNotesLabel,
        border: const OutlineInputBorder(),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.bankApplicationDetailsSection,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          Divider(height: 24, color: isDark ? AppTheme.darkBorder : AppTheme.border),

          if (isMobile) ...[
            docTypeField,
            const SizedBox(height: 14),
            refNoField,
            const SizedBox(height: 14),
            bankDropdown,
            swiftBankMatchWidget,
            const SizedBox(height: 14),
            bankAmountField,
            const SizedBox(height: 14),
            currencyField,
            const SizedBox(height: 14),
            requestDateField,
            const SizedBox(height: 14),
            notesField,
          ] else ...[
            Row(
              children: [
                Expanded(child: docTypeField),
                const SizedBox(width: 14),
                Expanded(child: refNoField),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bankDropdown,
                      swiftBankMatchWidget,
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: bankAmountField),
                const SizedBox(width: 14),
                Expanded(child: currencyField),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: requestDateField),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: notesField),
              ],
            ),
          ],
          const SizedBox(height: 24),

          Text(
            context.l10n.form4ChecklistSectionTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildChecklistItem(context, 'proforma_invoice', context.l10n.form4ItemProformaInvoice, true),
              _buildChecklistItem(context, 'packing_list', context.l10n.form4ItemPackingList, true),
              _buildChecklistItem(context, 'certificate_of_origin', context.l10n.form4ItemCertificateOfOrigin, true),
              _buildChecklistItem(context, 'bill_of_lading', context.l10n.form4ItemBillOfLading, true),
              _buildChecklistItem(context, 'acid_notice', context.l10n.form4ItemAcidNotice, true),
              _buildChecklistItem(context, 'marine_insurance', context.l10n.form4ItemMarineInsurance, false),
              _buildChecklistItem(context, 'bank_application', context.l10n.form4ItemBankApplication, true),
              _buildChecklistItem(context, 'admin_fee_receipt', context.l10n.form4ItemAdminFeeReceipt, false),
            ],
          ),
        ],
      ),
    );
  }
}
