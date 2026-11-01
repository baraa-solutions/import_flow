import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/financial_approval_model.dart';
import 'financial_ui.dart';
import 'payment_request_form/payment_linked_pos_section.dart';
import 'payment_request_form/payment_request_amounts_card.dart';
import 'payment_request_form/payment_request_header_banner.dart';
import 'payment_request_form/payment_request_party_row.dart';
import 'payment_request_form/payment_supplier_bank_card.dart';

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
                              PaymentRequestHeaderBanner(
                                editingPaymentId: editingPaymentId,
                                editingPaymentCode: editingPaymentCode,
                                onCancelEdit: onCancelEdit,
                                isLoadingPayPrefill: isLoadingPayPrefill,
                                onSearchAndClone: onSearchAndClone,
                                swiftExtractorWidget: swiftExtractorWidget,
                                constraints: constraints,
                              ),
                              PaymentRequestPartyRow(
                                selectedImportFileId: selectedImportFileId,
                                onImportFileChanged: onImportFileChanged,
                                payTitleController: payTitleController,
                                selectedSupplierId: selectedSupplierId,
                                onSupplierChanged: onSupplierChanged,
                                supplierNameController: supplierNameController,
                                paymentType: paymentType,
                                onPaymentTypeChanged: onPaymentTypeChanged,
                                openSameTypeRequest: openSameTypeRequest,
                                onViewOpenSameTypeRequest:
                                    onViewOpenSameTypeRequest,
                                constraints: constraints,
                              ),
                              PaymentRequestAmountsCard(
                                payPrefillData: payPrefillData,
                                selectedPercentage: selectedPercentage,
                                onSelectPercentage: onSelectPercentage,
                                currencyCode: currencyCode,
                                onCurrencyChanged: onCurrencyChanged,
                                amountController: amountController,
                                exchangeRateController: exchangeRateController,
                                requestDate: requestDate,
                                onRequestDateChanged: onRequestDateChanged,
                                dueDate: dueDate,
                                onDueDateChanged: onDueDateChanged,
                                maxWidth: constraints.maxWidth,
                              ),
                              const SizedBox(height: 16),
                              PaymentSupplierBankCard(
                                bankNameController: bankNameController,
                                swiftCodeController: swiftCodeController,
                                ibanController: ibanController,
                                isNarrow: isNarrow,
                              ),
                              const SizedBox(height: 16),
                              PaymentLinkedPosSection(
                                payPrefillData: payPrefillData,
                                onCloneLinkedPoItem: onCloneLinkedPoItem,
                                isMobile: constraints.maxWidth < 768,
                              ),
                              TextFormField(
                                controller: payNotesController,
                                decoration: InputDecoration(
                                  labelText: l.paymentNotesLabel,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 20),
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
}
