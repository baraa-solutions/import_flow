import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/clearance_expense_invoice_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'customs_ui.dart';
import 'expenses/clearance_add_invoice_form.dart';
import 'expenses/clearance_expenses_kpis.dart';
import 'expenses/clearance_invoices_list.dart';

/// CL-05 Modal Dialog: Clearance Fees & Port Invoices
/// (broker invoices, handling and port freight expenses).
class ClearanceExpensesDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const ClearanceExpensesDialog({
    super.key,
    required this.file,
    this.clearanceRecord,
  });

  static Future<bool?> show(
    BuildContext context,
    ImportFileModel file, {
    CustomsClearanceModel? clearanceRecord,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClearanceExpensesDialog(
        file: file,
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<ClearanceExpensesDialog> createState() =>
      _ClearanceExpensesDialogState();
}

class _ClearanceExpensesDialogState
    extends ConsumerState<ClearanceExpensesDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showAddForm = false;
  ClearanceInvoicesSummaryModel? _summary;

  // Form Controllers
  late TextEditingController _providerNameController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _amountEgpController;
  late TextEditingController _vatAmountController;
  late TextEditingController _whtAmountController;
  late TextEditingController _notesController;

  String _expenseCategory = 'BROKER_FEES';
  DateTime _invoiceDate = DateTime.now();
  bool _vatIncluded = false;
  bool _whtDeducted = false;
  String _allocationRule = 'Equal';
  final String _currency = 'EGP';

  final List<String> _expenseCategories = DomainEnums.codesOf(DomainEnumType.clearanceExpenseCategory);

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadInvoices();
  }

  void _initControllers() {
    _providerNameController = TextEditingController();
    _invoiceNumberController = TextEditingController();
    _amountEgpController = TextEditingController();
    _vatAmountController = TextEditingController(text: '0.00');
    _whtAmountController = TextEditingController(text: '0.00');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _providerNameController.dispose();
    _invoiceNumberController.dispose();
    _amountEgpController.dispose();
    _vatAmountController.dispose();
    _whtAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final summary = await ref
          .read(customsClearanceProvider.notifier)
          .fetchClearanceInvoices(widget.file.importFileId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final l = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccLoadInvoicesError(ApiErrorText.of(l, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _providerNameController.clear();
    _invoiceNumberController.clear();
    _amountEgpController.clear();
    _vatAmountController.text = '0.00';
    _whtAmountController.text = '0.00';
    _notesController.clear();
    setState(() {
      _expenseCategory = 'BROKER_FEES';
      _invoiceDate = DateTime.now();
      _vatIncluded = false;
      _whtDeducted = false;
      _allocationRule = 'Equal';
      _showAddForm = false;
    });
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final amountEgp = double.tryParse(_amountEgpController.text.trim()) ?? 0.0;
    final vatAmount = _vatIncluded
        ? (double.tryParse(_vatAmountController.text.trim()) ?? 0.0)
        : 0.0;
    final whtAmount = _whtDeducted
        ? (double.tryParse(_whtAmountController.text.trim()) ?? 0.0)
        : 0.0;
    final netPayable = amountEgp + vatAmount - whtAmount;

    final payload = {
      'import_file_id': widget.file.importFileId,
      if (widget.clearanceRecord?.customsClearanceId != null)
        'customs_clearance_id': widget.clearanceRecord!.customsClearanceId,
      'invoice_number': _invoiceNumberController.text.trim(),
      'invoice_date': CcFormat.date(_invoiceDate),
      'provider_name': _providerNameController.text.trim(),
      'expense_category': _expenseCategory,
      'currency': _currency,
      'amount_fx': amountEgp,
      'exchange_rate': 1.0,
      'amount_egp': amountEgp,
      'vat_included': _vatIncluded,
      'vat_amount': vatAmount,
      'wht_deducted': _whtDeducted,
      'wht_amount': whtAmount,
      'net_payable_egp': netPayable,
      'allocation_rule': _allocationRule,
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    };
    final categoryLabel = DomainEnums.label(l, DomainEnumType.clearanceExpenseCategory, _expenseCategory);

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(customsClearanceProvider.notifier)
          .createClearanceInvoice(payload);

      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(context, l.ccExpSaved(categoryLabel), severity: AppSeverity.success),
        );
        _resetForm();
        await _loadInvoices();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccExpSaveFail(ApiErrorText.of(l, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteInvoice(ClearanceExpenseInvoiceModel invoice) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
            const SizedBox(width: 8),
            Expanded(child: Text(l.ccExpDeleteTitle)),
          ],
        ),
        content: Text(l.ccExpDeleteContent(invoice.invoiceNumber, invoice.providerName)),
        actions: [
          AppButton(
            label: l.cancel,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: l.ccExpDeleteConfirm,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(customsClearanceProvider.notifier)
          .deleteClearanceInvoice(invoice.invoiceId, widget.file.importFileId);

      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(context, l.ccExpDeleted, severity: AppSeverity.success),
        );
        await _loadInvoices();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccExpDeleteFail(ApiErrorText.of(l, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final file = widget.file;
    final declaration = (file.form46No != null && file.form46No!.isNotEmpty) ? file.form46No! : l.ccExpDeclPending;

    return CcStageDialogShell(
      title: l.ccExpTitle,
      icon: Icons.receipt_long,
      accent: AppTheme.cobalt,
      maxWidth: 920,
      chips: [
        CcHeaderChip(
          Icons.folder_outlined,
          l.ccExpChipFile(
            file.importFileCode,
            file.supplierName.isNotEmpty ? file.supplierName : l.ccExpSupplierFallback,
            declaration,
          ),
        ),
      ],
      showCancel: false,
      confirmLabel: l.close,
      confirmIcon: Icons.close,
      confirmVariant: AppButtonVariant.secondary,
      isSubmitting: false,
      onConfirm: () => Navigator.of(context).pop(true),
      onCancel: () => Navigator.of(context).pop(true),
      footerLeading: Row(
        children: [
          const Icon(Icons.sync_alt, size: 16, color: AppTheme.emerald),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.ccExpFooterNote,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const SizedBox(height: 240, child: CcStateView.loading())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClearanceExpensesKpis(summary: _summary),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.receipt, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.ccExpListTitle(_summary?.invoicesCount ?? 0),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      key: const Key('addClearanceInvoiceBtn'),
                      label: _showAddForm ? l.ccExpCancelAdd : l.ccExpAddBtn,
                      icon: _showAddForm ? Icons.close : Icons.add,
                      variant: _showAddForm ? AppButtonVariant.secondary : AppButtonVariant.primary,
                      onPressed: () => setState(() => _showAddForm = !_showAddForm),
                    ),
                  ],
                ),
                if (_showAddForm) ...[
                  const SizedBox(height: 16),
                  ClearanceAddInvoiceForm(
                    formKey: _formKey,
                    providerNameController: _providerNameController,
                    invoiceNumberController: _invoiceNumberController,
                    amountEgpController: _amountEgpController,
                    vatAmountController: _vatAmountController,
                    whtAmountController: _whtAmountController,
                    notesController: _notesController,
                    expenseCategory: _expenseCategory,
                    onExpenseCategoryChanged: (cat) => setState(() => _expenseCategory = cat),
                    expenseCategories: _expenseCategories,
                    invoiceDate: _invoiceDate,
                    onInvoiceDateChanged: (dt) => setState(() => _invoiceDate = dt),
                    allocationRule: _allocationRule,
                    onAllocationRuleChanged: (r) => setState(() => _allocationRule = r),
                    vatIncluded: _vatIncluded,
                    onVatIncludedChanged: (v) => setState(() => _vatIncluded = v),
                    whtDeducted: _whtDeducted,
                    onWhtDeductedChanged: (w) => setState(() => _whtDeducted = w),
                    isSubmitting: _isSubmitting,
                    onCancel: _resetForm,
                    onSubmit: _submitInvoice,
                  ),
                ],
                const SizedBox(height: 20),
                ClearanceInvoicesList(
                  invoices: _summary?.invoices ?? [],
                  onDeleteInvoice: _deleteInvoice,
                ),
              ],
            ),
    );
  }
}
