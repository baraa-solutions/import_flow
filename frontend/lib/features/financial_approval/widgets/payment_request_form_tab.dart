import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/financial_approval_model.dart';
import 'financial_ui.dart';

/// Payment Request Form Tab Component (BP-012)
///
/// Encapsulates the entire Payment Request creation and edit form,
/// including supplier master data links, amount and bank accounts,
/// dynamic currency converters, linked PO allocations, and validation.
class PaymentRequestFormTab extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final int? editingPaymentId;
  final String? editingPaymentCode;
  final VoidCallback onCancelEdit;

  // Controllers
  final TextEditingController payTitleController;
  final TextEditingController supplierNameController;
  final TextEditingController amountController;
  final TextEditingController exchangeRateController;
  final TextEditingController bankNameController;
  final TextEditingController swiftCodeController;
  final TextEditingController ibanController;
  final TextEditingController payNotesController;

  // Dropdowns & Dates
  final String currencyCode;
  final ValueChanged<String> onCurrencyChanged;
  final DateTime requestDate;
  final ValueChanged<DateTime> onRequestDateChanged;
  final DateTime dueDate;
  final ValueChanged<DateTime> onDueDateChanged;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final String paymentType;
  final ValueChanged<String> onPaymentTypeChanged;
  final int? selectedSupplierId;
  final ValueChanged<int?> onSupplierChanged;

  // Prefill, Warnings & State
  final BudgetPrefillModel? payPrefillData;
  final bool isLoadingPayPrefill;
  final bool isSavingPayment;
  final VoidCallback onSavePaymentRequest;
  final VoidCallback onSearchAndClone;
  final void Function(LinkedPOItemModel po)? onCloneLinkedPoItem;
  final PaymentRequestModel? openSameTypeRequest;
  final void Function(PaymentRequestModel pay)? onViewOpenSameTypeRequest;
  final double? selectedPercentage;
  final void Function(double pct)? onSelectPercentage;
  final Widget? swiftExtractorWidget;

  const PaymentRequestFormTab({
    super.key,
    required this.formKey,
    this.editingPaymentId,
    this.editingPaymentCode,
    required this.onCancelEdit,
    required this.payTitleController,
    required this.supplierNameController,
    required this.amountController,
    required this.exchangeRateController,
    required this.bankNameController,
    required this.swiftCodeController,
    required this.ibanController,
    required this.payNotesController,
    required this.currencyCode,
    required this.onCurrencyChanged,
    required this.requestDate,
    required this.onRequestDateChanged,
    required this.dueDate,
    required this.onDueDateChanged,
    this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.paymentType,
    required this.onPaymentTypeChanged,
    this.selectedSupplierId,
    required this.onSupplierChanged,
    this.payPrefillData,
    this.isLoadingPayPrefill = false,
    this.isSavingPayment = false,
    required this.onSavePaymentRequest,
    required this.onSearchAndClone,
    this.onCloneLinkedPoItem,
    this.openSameTypeRequest,
    this.onViewOpenSameTypeRequest,
    this.selectedPercentage,
    this.onSelectPercentage,
    this.swiftExtractorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suppliersState = ref.watch(suppliersProvider);
    final suppliersList = suppliersState.valueOrNull ?? [];

    return SelectionArea(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
            onSearchAndClone();
          },
        },
        child: Focus(
          autofocus: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 700;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Edit Mode Active Banner
                              if (editingPaymentId != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.darkCardBackground
                                        : AppTheme.orangeLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? AppTheme.wcagOrange
                                          : AppTheme.orange,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_note,
                                          color: AppTheme.orange),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${l.activeEditModeBanner}: $editingPaymentCode',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppTheme.orange
                                                : AppTheme.wcagOrange,
                                          ),
                                        ),
                                      ),
                                      FinancialUi.fit(AppButton(
                                        label: l.cancelEdit,
                                        variant: AppButtonVariant.secondary,
                                        icon: Icons.close,
                                        onPressed: onCancelEdit,
                                      )),
                                    ],
                                  ),
                                ),

                              // Header with Title & Search/Clone Action
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runSpacing: 8,
                                spacing: 12,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth > 400
                                          ? constraints.maxWidth - 200
                                          : constraints.maxWidth,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            editingPaymentId != null
                                                ? '${l.editPaymentRequestTitle} ($editingPaymentCode)'
                                                : l.createPaymentRequestTitle,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? AppTheme.darkTextPrimary
                                                  : AppTheme.charcoal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isLoadingPayPrefill) ...[
                                          const SizedBox(width: 10),
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  FinancialUi.fit(AppButton(
                                    key: const ValueKey(
                                        'searchAndClonePaymentRequestBtn'),
                                    label: l.searchAndClonePaymentRequestBtn,
                                    variant: AppButtonVariant.secondary,
                                    size: AppButtonSize.small,
                                    icon: Icons.copy_all,
                                    onPressed: onSearchAndClone,
                                  )),
                                ],
                              ),
                              const Divider(),
                              const SizedBox(height: 6),

                              // Smart AI SWIFT MT103 Interactive Extractor
                              if (swiftExtractorWidget != null) ...[
                                swiftExtractorWidget!,
                                const SizedBox(height: 12),
                              ],

                              // Row 1: Import File & Payment Title
                              if (isNarrow)
                                Column(
                                  children: [
                                    _buildImportFileDropdown(context, ref, l),
                                    const SizedBox(height: 12),
                                    _buildTitleField(l),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildImportFileDropdown(
                                          context, ref, l),
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
                                      child: _buildSupplierDropdown(
                                          l, suppliersList),
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
                                          l.faOpenPaymentSameType(
                                              openSameTypeRequest!.paymentCode),
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
                                              onViewOpenSameTypeRequest!(
                                                  openSameTypeRequest!),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              // Percentage chips from PO invoice
                              if (payPrefillData != null &&
                                  payPrefillData!.totalInvoiceAmount > 0 &&
                                  onSelectPercentage != null) ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      l.faPercentFromPo(
                                        payPrefillData!.totalInvoiceAmount
                                            .toStringAsFixed(2),
                                        currencyCode,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.textStrong,
                                      ),
                                    ),
                                    ...[10.0, 20.0, 30.0, 50.0, 100.0]
                                        .map((pct) {
                                      final isSel = selectedPercentage == pct;
                                      return ChoiceChip(
                                        label:
                                            Text('${pct.toStringAsFixed(0)}%'),
                                        selected: isSel,
                                        selectedColor: AppTheme.wcagOrange,
                                        labelStyle: TextStyle(
                                          fontSize: 11,
                                          color: isSel
                                              ? AppTheme.white
                                              : (isDark
                                                  ? AppTheme.darkTextPrimary
                                                  : AppTheme.charcoal),
                                          fontWeight: isSel
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onSelected: (_) =>
                                            onSelectPercentage!(pct),
                                      );
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Row 3: Amount, Currency, Rate, Request Date, Due Date (Responsive)
                              if (constraints.maxWidth >= 1100)
                                Row(
                                  children: [
                                    Expanded(child: _buildAmountField(l)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child:
                                            _buildCurrencyDropdown(ref, l)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildExchangeRateField(l)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child:
                                            _buildRequestDateField(context, l)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: _buildDueDateField(context, l)),
                                  ],
                                )
                              else if (constraints.maxWidth >= 700)
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _buildAmountField(l)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child:
                                                _buildCurrencyDropdown(ref, l)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: _buildExchangeRateField(l)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                            child: _buildRequestDateField(
                                                context, l)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child:
                                                _buildDueDateField(context, l)),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _buildAmountField(l)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child:
                                                _buildCurrencyDropdown(ref, l)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildExchangeRateField(l),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                            child: _buildRequestDateField(
                                                context, l)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child:
                                                _buildDueDateField(context, l)),
                                      ],
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),

                              // Supplier Banking Details Card (WCAG AA)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkElevatedSurface
                                      : AppTheme.cobaltLight
                                          .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? AppTheme.darkBorder
                                        : AppTheme.cobaltBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${l.beneficiaryBankDetails}:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.cobalt,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (isNarrow)
                                      Column(
                                        children: [
                                          TextFormField(
                                            controller: bankNameController,
                                            decoration: InputDecoration(
                                              labelText: l.bankNameLabel,
                                              border:
                                                  const OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            controller: swiftCodeController,
                                            textDirection: TextDirection.ltr,
                                            decoration: InputDecoration(
                                              labelText: l.swiftCodeLabel,
                                              border:
                                                  const OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            controller: ibanController,
                                            textDirection: TextDirection.ltr,
                                            decoration: InputDecoration(
                                              labelText: l.ibanAccountLabel,
                                              border:
                                                  const OutlineInputBorder(),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: bankNameController,
                                              decoration: InputDecoration(
                                                labelText: l.bankNameLabel,
                                                border:
                                                    const OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: swiftCodeController,
                                              textDirection: TextDirection.ltr,
                                              decoration: InputDecoration(
                                                labelText: l.swiftCodeLabel,
                                                border:
                                                    const OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: ibanController,
                                              textDirection: TextDirection.ltr,
                                              decoration: InputDecoration(
                                                labelText: l.ibanAccountLabel,
                                                border:
                                                    const OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Linked Purchase Orders Section
                              if (payPrefillData != null &&
                                  payPrefillData!.linkedPos.isNotEmpty) ...[
                                Text(
                                  '${l.linkedPurchaseOrdersTitle}:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (constraints.maxWidth < 768)
                                  _buildMobileLinkedPOCardsList(l, isDark)
                                else
                                  _buildLinkedPOsTable(l, isDark),
                                const SizedBox(height: 16),
                              ],

                              // Payment Notes Field
                              TextFormField(
                                controller: payNotesController,
                                decoration: InputDecoration(
                                  labelText: l.paymentNotesLabel,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Form Actions (Cancel Edit / Submit)
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  if (editingPaymentId != null)
                                    FinancialUi.fit(AppButton(
                                      label: l.cancelEdit,
                                      variant: AppButtonVariant.secondary,
                                      icon: Icons.close,
                                      onPressed: onCancelEdit,
                                    ))
                                  else
                                    const SizedBox.shrink(),
                                  FinancialUi.fit(AppButton(
                                    label: editingPaymentId != null
                                        ? l.savePaymentChangesButton
                                        : l.issuePaymentRequestButton,
                                    variant: AppButtonVariant.primary,
                                    icon: editingPaymentId != null
                                        ? Icons.save
                                        : Icons.send,
                                    isLoading: isSavingPayment,
                                    onPressed: isSavingPayment
                                        ? null
                                        : onSavePaymentRequest,
                                  )),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportFileDropdown(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
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

  Widget _buildAmountField(AppLocalizations l) {
    return TextFormField(
      controller: amountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '${l.requestedAmountLabel} *',
        border: const OutlineInputBorder(),
      ),
      validator: (v) =>
          (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
              ? l.requiredField
              : null,
    );
  }

  Widget _buildCurrencyDropdown(WidgetRef ref, AppLocalizations l) {
    return SearchableDropdownField<String>(
      value: currencyCode,
      labelText: '${l.currencyCol} *',
      searchHintText: l.search,
      items: () {
        final curList = ref.watch(currenciesProvider).valueOrNull ?? [];
        final list = curList.isNotEmpty
            ? curList
                .map((c) => SearchableDropdownItem<String>(
                      value: c.currencyCode,
                      label: '${c.currencyCode} - ${c.currencyName}',
                    ))
                .toList()
            : [
                const SearchableDropdownItem(value: 'USD', label: 'USD'),
                const SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                const SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                const SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                const SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                const SearchableDropdownItem(value: 'SAR', label: 'SAR'),
                const SearchableDropdownItem(value: 'AED', label: 'AED'),
              ];
        if (!list.any((i) => i.value == currencyCode)) {
          list.add(SearchableDropdownItem(
              value: currencyCode, label: currencyCode));
        }
        return list;
      }(),
      onChanged: (val) {
        if (val != null) onCurrencyChanged(val);
      },
    );
  }

  Widget _buildExchangeRateField(AppLocalizations l) {
    return TextFormField(
      controller: exchangeRateController,
      keyboardType: TextInputType.number,
      validator: (v) {
        final r = double.tryParse((v ?? '').trim());
        if (r == null || r <= 0) return l.faExchangeRateInvalid;
        return null;
      },
      decoration: InputDecoration(
        labelText: '${l.exchangeRateCol} (EGP) *',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildRequestDateField(BuildContext context, AppLocalizations l) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: requestDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onRequestDateChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '${l.requestDateLabel} *',
          border: const OutlineInputBorder(),
        ),
        child: Text(requestDate.toString().substring(0, 10)),
      ),
    );
  }

  Widget _buildDueDateField(BuildContext context, AppLocalizations l) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: dueDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onDueDateChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '${l.dueDateLabel} *',
          border: const OutlineInputBorder(),
        ),
        child: Text(dueDate.toString().substring(0, 10)),
      ),
    );
  }

  Widget _buildMobileLinkedPOCardsList(AppLocalizations l, bool isDark) {
    if (payPrefillData == null || payPrefillData!.linkedPos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: payPrefillData!.linkedPos.map((po) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CopyableText(
                          po.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cobalt,
                            fontSize: 13,
                          ),
                        ),
                        if (po.displayName != po.poNumber)
                          CopyableText(
                            po.poNumber,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkCardBackground
                              : AppTheme.orangeLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.wcagOrange
                                : AppTheme.orange,
                          ),
                        ),
                        child: Text(
                          po.paymentTerms,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? AppTheme.orange : AppTheme.wcagOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (onCloneLinkedPoItem != null) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l.clonePoAllocationTooltip,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () => onCloneLinkedPoItem!(po),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l.invoiceAmount}:',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textStrong,
                    ),
                  ),
                  Text(
                    '${po.totalAmount.toStringAsFixed(2)} ${po.currency}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.emerald,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLinkedPOsTable(AppLocalizations l, bool isDark) {
    return Table(
      border: TableBorder.all(
        color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.8),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1.4),
        5: FlexColumnWidth(1.2),
        6: FlexColumnWidth(0.8),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.poNumberCol,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.projectNameCol,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.paymentTypeLabel,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.currencyCol,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.invoiceAmount,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.statusCol,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.actionsCol,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        ...payPrefillData!.linkedPos.map((po) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CopyableText(
                      po.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cobalt,
                      ),
                    ),
                    if (po.displayName != po.poNumber)
                      CopyableText(
                        po.poNumber,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CopyableText(po.projectName ?? '-'),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkCardBackground
                        : AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
                    ),
                  ),
                  child: CopyableText(
                    po.paymentTerms,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.orange : AppTheme.wcagOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CopyableText(
                  po.currency,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CopyableText(
                  '${po.totalAmount.toStringAsFixed(2)} ${po.currency}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emerald,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CopyableText(
                  po.status,
                  style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: onCloneLinkedPoItem != null
                    ? IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            size: 16, color: AppTheme.cobalt),
                        tooltip: l.clonePoAllocationTooltip,
                        onPressed: () => onCloneLinkedPoItem!(po),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }),
      ],
    );
  }
}
