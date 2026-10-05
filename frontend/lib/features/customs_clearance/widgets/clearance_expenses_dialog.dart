import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/clearance_expense_invoice_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'customs_ui.dart';

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

  Color _getCategoryColor(String category) {
    switch (DomainEnums.legacyToCode(DomainEnumType.clearanceExpenseCategory, category)) {
      case 'BROKER_FEES':
        return AppTheme.cobalt;
      case 'PORT_DUES_WHARFAGE':
        return AppTheme.orange;
      case 'STEVEDORING_HANDLING':
        return AppTheme.wcagCobalt;
      case 'LABORATORY_TESTING':
        return AppTheme.emerald;
      case 'STORAGE_DEMURRAGE':
        return AppTheme.crimson;
    }
    return AppTheme.charcoal;
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      );

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
                _buildSummaryKpiCards(l),
                const SizedBox(height: 16),
                _buildActionBar(l),
                if (_showAddForm) ...[
                  const SizedBox(height: 16),
                  _buildAddInvoiceForm(l),
                ],
                const SizedBox(height: 20),
                _buildInvoicesSection(l),
              ],
            ),
    );
  }

  Widget _buildSummaryKpiCards(AppLocalizations l) {
    final summary = _summary;
    final cur = l.ccCurrencyShort;
    final totalNet = summary?.netPayableEgp ?? 0.0;
    final brokerFees = summary?.totalClearanceFeesEgp ?? 0.0;
    final portDues = summary?.totalPortDuesEgp ?? 0.0;
    final handling = summary?.totalHandlingStevedoringEgp ?? 0.0;
    final count = summary?.invoicesCount ?? 0;

    return CcFieldRow(
      gap: 12,
      children: [
        _buildMetricCard(
          title: l.ccExpKpiNet,
          value: '${CcFormat.money(totalNet)} $cur',
          subtitle: l.ccExpInvoicesCount(count),
          icon: Icons.account_balance_wallet,
          color: AppTheme.emerald,
          highlight: true,
        ),
        _buildMetricCard(
          title: l.ccExpKpiBroker,
          value: '${CcFormat.money(brokerFees)} $cur',
          subtitle: l.ccExpKpiBrokerSub,
          icon: Icons.person_search,
          color: AppTheme.cobalt,
        ),
        _buildMetricCard(
          title: l.ccExpKpiPort,
          value: '${CcFormat.money(portDues)} $cur',
          subtitle: l.ccExpKpiPortSub,
          icon: Icons.anchor,
          color: AppTheme.orange,
        ),
        _buildMetricCard(
          title: l.ccExpKpiHandling,
          value: '${CcFormat.money(handling)} $cur',
          subtitle: l.ccExpKpiHandlingSub,
          icon: Icons.forklift,
          color: AppTheme.wcagCobalt,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.1) : AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: highlight ? color : AppTheme.borderOf(context),
          width: highlight ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LtrText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: highlight ? color : AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(AppLocalizations l) {
    return Row(
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
    );
  }

  Widget _buildAddInvoiceForm(AppLocalizations l) {
    final allocationRules = <String, String>{
      'Equal': l.ccExpAllocEqual,
      'Value-Based': l.ccExpAllocValue,
      'Weight-Based': l.ccExpAllocWeight,
      'Volume-Based': l.ccExpAllocVolume,
    };

    return Form(
      key: _formKey,
      child: CcFormSection(
        title: l.ccExpFormTitle,
        icon: Icons.note_add,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.ccExpFormNote,
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondaryOf(context),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),

            // Row 1: provider name, invoice number, date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('invoiceProviderNameField'),
                    controller: _providerNameController,
                    decoration: _dec(l.ccExpProviderLabel, hint: l.ccExpProviderHint, icon: Icons.business_outlined),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l.ccExpProviderRequired;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('invoiceNumberField'),
                    controller: _invoiceNumberController,
                    textDirection: TextDirection.ltr,
                    decoration: _dec(l.ccExpNumberLabel, hint: l.ccExpNumberHint, icon: Icons.tag),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l.ccExpNumberRequired;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _invoiceDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _dec(l.ccExpDateLabel, icon: Icons.calendar_today),
                      child: LtrText(CcFormat.date(_invoiceDate),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 2: category & allocation rule
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    key: const Key('invoiceCategoryDropdown'),
                    value: _expenseCategory,
                    isDense: false,
                    isRequired: true,
                    labelText: l.ccExpCategoryLabel,
                    decoration: _dec(l.ccExpCategoryLabel, icon: Icons.category_outlined),
                    items: _expenseCategories
                        .map((cat) => SearchableDropdownItem<String>(
                              value: cat,
                              label: DomainEnums.label(l, DomainEnumType.clearanceExpenseCategory, cat),
                            ))
                        .toList(),
                    validator: (v) => (v == null || v.isEmpty) ? l.requiredField : null,
                    onChanged: (val) {
                      if (val != null) setState(() => _expenseCategory = val);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    key: const Key('invoiceAllocationRuleDropdown'),
                    value: _allocationRule,
                    isDense: false,
                    isRequired: true,
                    labelText: l.ccExpAllocationLabel,
                    decoration: _dec(l.ccExpAllocationLabel, icon: Icons.pie_chart_outline),
                    items: allocationRules.entries
                        .map((rule) => SearchableDropdownItem<String>(value: rule.key, label: rule.value))
                        .toList(),
                    validator: (v) => (v == null || v.isEmpty) ? l.requiredField : null,
                    onChanged: (val) {
                      if (val != null) setState(() => _allocationRule = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 3: amount, VAT, WHT
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('invoiceAmountField'),
                    controller: _amountEgpController,
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec(l.ccExpAmountLabel, hint: '0.00', icon: Icons.attach_money),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l.ccExpAmountRequired;
                      final numVal = double.tryParse(val.trim());
                      if (numVal == null || numVal <= 0) return l.ccExpAmountPositive;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Material(
                        type: MaterialType.transparency,
                        child: CheckboxListTile(
                          title: Text(l.ccVatCheckboxLabel, overflow: TextOverflow.ellipsis),
                          value: _vatIncluded,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) => setState(() => _vatIncluded = val ?? false),
                        ),
                      ),
                      if (_vatIncluded)
                        TextFormField(
                          key: const Key('invoiceVatAmountField'),
                          controller: _vatAmountController,
                          textDirection: TextDirection.ltr,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec(l.ccVatAmountLabel, icon: Icons.percent),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Material(
                        type: MaterialType.transparency,
                        child: CheckboxListTile(
                          title: Text(l.ccExpWhtCheckbox, overflow: TextOverflow.ellipsis),
                          value: _whtDeducted,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) => setState(() => _whtDeducted = val ?? false),
                        ),
                      ),
                      if (_whtDeducted)
                        TextFormField(
                          key: const Key('invoiceWhtAmountField'),
                          controller: _whtAmountController,
                          textDirection: TextDirection.ltr,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec(l.ccWhtAmountLabel, icon: Icons.remove_circle_outline),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              key: const Key('invoiceNotesField'),
              controller: _notesController,
              decoration: _dec(l.ccExpNotesLabel, hint: l.ccExpNotesHint, icon: Icons.notes),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: l.cancel,
                  variant: AppButtonVariant.secondary,
                  onPressed: _isSubmitting ? null : _resetForm,
                ),
                const SizedBox(width: 12),
                AppButton(
                  key: const Key('saveClearanceInvoiceBtn'),
                  label: _isSubmitting ? l.ccExpSaving : l.ccExpSave,
                  icon: Icons.check,
                  variant: AppButtonVariant.success,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submitInvoice,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesSection(AppLocalizations l) {
    final invoices = _summary?.invoices ?? [];

    if (invoices.isEmpty) {
      return Container(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textMutedOf(context)),
            const SizedBox(height: 12),
            Text(
              l.ccExpEmptyTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              l.ccExpEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: invoices.map((inv) => _buildInvoiceCard(l, inv)).toList(),
    );
  }

  Widget _buildInvoiceCard(AppLocalizations l, ClearanceExpenseInvoiceModel invoice) {
    final catColor = _getCategoryColor(invoice.expenseCategory);
    final cur = l.ccCurrencyShort;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: catColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DomainEnums.label(l, DomainEnumType.clearanceExpenseCategory, invoice.expenseCategory),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: catColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l.ccExpInvoiceNo(invoice.invoiceNumber),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              LtrText(
                '(${invoice.invoiceCode})',
                style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CcMoneyText(
                    invoice.netPayableEgp,
                    currency: cur,
                    fontSize: 15,
                    color: AppTheme.successForeground,
                  ),
                  if (invoice.vatIncluded || invoice.whtDeducted)
                    LtrText(
                      l.ccExpBreakdown(
                        CcFormat.money(invoice.amountEgp),
                        CcFormat.money(invoice.vatAmount),
                        CcFormat.money(invoice.whtAmount),
                      ),
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryOf(context)),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                key: Key('deleteInvoiceBtn_${invoice.invoiceId}'),
                icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                tooltip: l.ccExpDeleteTooltip,
                onPressed: () => _deleteInvoice(invoice),
              ),
            ],
          ),
          Divider(height: 18, color: AppTheme.borderOf(context)),
          Wrap(
            spacing: 24,
            runSpacing: 6,
            children: [
              _buildCardInfo(Icons.business, l.ccExpInfoProvider, invoice.providerName),
              _buildCardInfo(Icons.calendar_today, l.ccExpInfoDate, invoice.invoiceDate, ltr: true),
              _buildCardInfo(
                Icons.pie_chart,
                l.ccExpInfoAllocation,
                invoice.allocationRule == 'Equal' ? l.ccExpAllocEqualShort : invoice.allocationRule,
              ),
              if (invoice.notes != null && invoice.notes!.isNotEmpty)
                _buildCardInfo(Icons.notes, l.ccExpInfoNotes, invoice.notes!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfo(IconData icon, String label, String value, {bool ltr = false}) {
    const valueStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMutedOf(context)),
        const SizedBox(width: 4),
        Text('$label: ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
        Flexible(
          child: ltr
              ? LtrText(value, style: valueStyle, overflow: TextOverflow.ellipsis)
              : Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
