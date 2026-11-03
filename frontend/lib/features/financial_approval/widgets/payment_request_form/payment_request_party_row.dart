import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../financial_ui.dart';
import '../../models/financial_approval_model.dart';

class PaymentRequestPartyRow extends ConsumerWidget {
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final TextEditingController payTitleController;
  final int? selectedSupplierId;
  final ValueChanged<int?> onSupplierChanged;
  final TextEditingController supplierNameController;
  final String paymentType;
  final ValueChanged<String> onPaymentTypeChanged;
  final PaymentRequestModel? openSameTypeRequest;
  final void Function(PaymentRequestModel pay)? onViewOpenSameTypeRequest;
  final BoxConstraints constraints;

  const PaymentRequestPartyRow({
    super.key,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.payTitleController,
    required this.selectedSupplierId,
    required this.onSupplierChanged,
    required this.supplierNameController,
    required this.paymentType,
    required this.onPaymentTypeChanged,
    this.openSameTypeRequest,
    this.onViewOpenSameTypeRequest,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow = constraints.maxWidth < 700;
    final suppliersState = ref.watch(suppliersProvider);
    final suppliersList = suppliersState.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Import File & Payment Title
        if (isNarrow)
          Column(
            children: [
              _buildImportFileDropdown(ref, l),
              const SizedBox(height: 12),
              _buildTitleField(l),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildImportFileDropdown(ref, l),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildTitleField(l),
              ),
            ],
          ),
        const SizedBox(height: 12),

        // Row 2: Supplier Master Data, Beneficiary, Payment Type
        if (constraints.maxWidth < 750)
          Column(
            children: [
              _buildSupplierDropdown(l, suppliersList),
              const SizedBox(height: 12),
              _buildSupplierNameField(l),
              const SizedBox(height: 12),
              _buildPaymentTypeDropdown(l),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildSupplierDropdown(l, suppliersList),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildSupplierNameField(l),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildPaymentTypeDropdown(l),
              ),
            ],
          ),
        const SizedBox(height: 12),

        // Warning banner: open request of same type
        if (openSameTypeRequest != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkCardBackground
                  : AppTheme.orangeLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.wcagOrange,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.wcagOrange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.faOpenPaymentSameType(openSameTypeRequest!.paymentCode),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.charcoal,
                    ),
                  ),
                ),
                if (onViewOpenSameTypeRequest != null) ...[
                  const SizedBox(width: 8),
                  AppButton(
                    label: l.viewDetails,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () =>
                        onViewOpenSameTypeRequest!(openSameTypeRequest!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImportFileDropdown(WidgetRef ref, AppLocalizations l) {
    return SearchableDropdownField<int?>(
      value: selectedImportFileId,
      labelText: '${l.importFile} *',
      searchHintText: l.search,
      items: [
        SearchableDropdownItem<int?>(
          value: null,
          label: '-- ${l.notLinked} --',
        ),
        ...(ref.watch(importFilesProvider).valueOrNull ?? []).map(
          (f) => SearchableDropdownItem<int?>(
            value: f.importFileId,
            label: '${f.primaryNameWithCode} - ${f.companyName}',
            subtitle: f.companyName,
          ),
        ),
      ],
      onChanged: onImportFileChanged,
    );
  }

  Widget _buildTitleField(AppLocalizations l) {
    return TextFormField(
      controller: payTitleController,
      decoration: InputDecoration(
        labelText: '${l.paymentTitleLabel} *',
        border: const OutlineInputBorder(),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? l.requiredField : null,
    );
  }

  Widget _buildSupplierDropdown(
      AppLocalizations l, List<dynamic> suppliersList) {
    return SearchableDropdownField<int?>(
      value: selectedSupplierId,
      labelText: l.selectSupplierFromMasterData,
      searchHintText: l.search,
      items: suppliersList
          .map((s) => SearchableDropdownItem<int?>(
                value: s.supplierId,
                label: s.companyName,
                subtitle: s.foreignExporterCountry,
              ))
          .toList(),
      onChanged: onSupplierChanged,
    );
  }

  Widget _buildSupplierNameField(AppLocalizations l) {
    return TextFormField(
      controller: supplierNameController,
      decoration: InputDecoration(
        labelText: '${l.beneficiarySupplierLabel} *',
        border: const OutlineInputBorder(),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? l.requiredField : null,
    );
  }

  Widget _buildPaymentTypeDropdown(AppLocalizations l) {
    return SearchableDropdownField<String>(
      key: const ValueKey('payment_type_dropdown'),
      value: paymentType,
      labelText: '${l.paymentTypeLabel} *',
      searchHintText: l.search,
      items: FinancialUi.paymentTypeItems(l),
      onChanged: (v) {
        if (v != null) onPaymentTypeChanged(v);
      },
    );
  }
}
