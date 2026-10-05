import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/financial_settlement_model.dart';
import '../providers/financial_settlement_provider.dart';
import 'settlement_ui.dart';

/// Parses a user-entered decimal (accepts a comma separator). Null when empty or invalid.
double? parseSettlementNumber(String? raw) {
  final text = (raw ?? '').trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

/// Builds the create payload from user-entered values only.
///
/// No money math happens here: `amount_egp`, totals and allocations are computed
/// by the backend. Optional weight / CBM stay 0 when left empty, and the exchange
/// rate is sent only when the user typed one.
Map<String, dynamic> buildSettlementCreatePayload({
  required int importFileId,
  required ExpenseInvoiceModel invoice,
  required ItemLandedCostModel item,
}) {
  return {
    'import_file_id': importFileId,
    'expense_invoices': [invoice.toCreateJson()],
    'item_landed_costs': [item.toCreateJson()],
  };
}

/// Add / clone dialog for a landed-cost settlement. A clone copies the source
/// lines but must target a different import file (one active settlement per file).
class SettlementFormDialog extends ConsumerStatefulWidget {
  final LandedCostSettlementModel? initialRecord;
  final bool isCloneDraft;

  const SettlementFormDialog({
    super.key,
    this.initialRecord,
    this.isCloneDraft = false,
  });

  @override
  ConsumerState<SettlementFormDialog> createState() => _SettlementFormDialogState();
}

class _SettlementFormDialogState extends ConsumerState<SettlementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedImportFileId;
  int? _sourceImportFileId;

  late final TextEditingController _invNoCtrl;
  late String _category;
  late final TextEditingController _providerCtrl;
  late String? _currency;
  late final TextEditingController _amountFxCtrl;
  late final TextEditingController _rateCtrl;
  late String _allocationRule;

  late final TextEditingController _itemCodeCtrl;
  late final TextEditingController _itemNameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _cbmCtrl;
  late final TextEditingController _fobUnitCtrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final rec = widget.initialRecord;
    _sourceImportFileId = widget.isCloneDraft ? rec?.importFileId : null;
    _selectedImportFileId = widget.isCloneDraft ? null : rec?.importFileId;

    final exp = (rec != null && rec.expenseInvoices.isNotEmpty) ? rec.expenseInvoices.first : null;
    _invNoCtrl = TextEditingController(text: exp?.invoiceNo ?? '');
    _category = exp?.category ?? 'Freight';
    _providerCtrl = TextEditingController(text: exp?.providerName ?? '');
    _currency = (exp != null && exp.currency.isNotEmpty) ? exp.currency : null;
    _amountFxCtrl = TextEditingController(text: exp == null ? '' : exp.amountFx.toString());
    _rateCtrl = TextEditingController(text: (exp != null && exp.exchangeRate > 0) ? exp.exchangeRate.toString() : '');
    _allocationRule = exp?.allocationRule ?? 'Volume-Based';

    final itm = (rec != null && rec.itemLandedCosts.isNotEmpty) ? rec.itemLandedCosts.first : null;
    _itemCodeCtrl = TextEditingController(text: itm?.itemCode ?? '');
    _itemNameCtrl = TextEditingController(text: itm?.itemName ?? '');
    _qtyCtrl = TextEditingController(text: itm?.qtyLabel ?? '');
    _weightCtrl = TextEditingController(text: (itm != null && itm.grossWeightKg > 0) ? itm.grossWeightKg.toString() : '');
    _cbmCtrl = TextEditingController(text: (itm != null && itm.cbm > 0) ? itm.cbm.toString() : '');
    _fobUnitCtrl = TextEditingController(text: itm == null ? '' : itm.fobUnitEgp.toString());

    // Live load on mount: no stale lookups.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(currenciesProvider.notifier).fetchCurrencies(includeInactive: false);
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _invNoCtrl, _providerCtrl, _amountFxCtrl, _rateCtrl, _itemCodeCtrl,
      _itemNameCtrl, _qtyCtrl, _weightCtrl, _cbmCtrl, _fobUnitCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String label, TextEditingController controller) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
        tooltip: context.l10n.financialSettlementCopyFieldTooltip,
        onPressed: () => CopyHelper.copy(
          context,
          controller.text,
          customMessage: context.l10n.financialSettlementCopyFieldTooltip,
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.settlementFieldRequired : null;

  String? _positive(String? v) {
    final n = parseSettlementNumber(v);
    return (n == null || n <= 0) ? context.l10n.settlementPositiveNumberRequired : null;
  }

  String? _optionalNonNegative(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = parseSettlementNumber(v);
    return (n == null || n < 0) ? context.l10n.settlementNonNegativeNumberRequired : null;
  }

  bool get _isBaseCurrency => (_currency ?? '').toUpperCase() == 'EGP';

  String? _rateValidator(String? v) {
    if (_isBaseCurrency || _currency == null) {
      return _optionalNonNegative(v);
    }
    final n = parseSettlementNumber(v);
    return (n == null || n <= 0) ? context.l10n.settlementExchangeRateRequired : null;
  }

  Widget _row(bool compact, List<Widget> children, {List<int>? flex}) {
    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(flex: flex != null ? flex[i] : 1, child: children[i]),
        ],
      ],
    );
  }

  Widget _text(String label, TextEditingController c,
      {String? Function(String?)? validator, bool numeric = false, Key? key}) {
    return TextFormField(
      key: key,
      controller: c,
      validator: validator,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: _decoration(label, c),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Future<void> _save() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final payload = buildSettlementCreatePayload(
        importFileId: _selectedImportFileId!,
        invoice: ExpenseInvoiceModel(
          invoiceNo: _invNoCtrl.text.trim(),
          category: _category,
          providerName: _providerCtrl.text.trim(),
          currency: _currency!,
          amountFx: parseSettlementNumber(_amountFxCtrl.text)!,
          exchangeRate: parseSettlementNumber(_rateCtrl.text) ?? 0.0,
          allocationRule: _allocationRule,
        ),
        item: ItemLandedCostModel(
          itemCode: _itemCodeCtrl.text.trim(),
          itemName: _itemNameCtrl.text.trim(),
          qty: parseSettlementNumber(_qtyCtrl.text)!,
          grossWeightKg: parseSettlementNumber(_weightCtrl.text) ?? 0.0,
          cbm: parseSettlementNumber(_cbmCtrl.text) ?? 0.0,
          fobUnitEgp: parseSettlementNumber(_fobUnitCtrl.text)!,
        ),
      );
      await ref.read(financialSettlementProvider.notifier).createSettlement(payload);
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.financialSettlementSaveError(ApiErrorText.of(l10n, e))),
        backgroundColor: AppTheme.crimson,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final importFiles = (ref.watch(importFilesProvider).valueOrNull ?? [])
        .where((f) => f.importFileId != _sourceImportFileId)
        .toList();
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final dialogWidth = (MediaQuery.of(context).size.width - 32).clamp(320.0, 750.0);
    final compact = dialogWidth < 500;
    final ruleItems = [
      SearchableDropdownItem(value: 'Volume-Based', label: l10n.financialSettlementRuleVolumeBased),
      SearchableDropdownItem(value: 'Value-Based', label: l10n.financialSettlementRuleValueBased),
      SearchableDropdownItem(value: 'Weight-Based', label: l10n.financialSettlementRuleWeightBased),
      SearchableDropdownItem(value: 'Equal', label: l10n.financialSettlementRuleEqual),
    ];

    Widget header(String text, Color color) =>
        SettlementSectionHeader(title: text, color: color);

    return AlertDialog(
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.down,
      title: Text(widget.isCloneDraft
          ? '${l10n.financialSettlementDialogTitle} — ${l10n.cloneFinancialSettlementDialogTitle}'
          : l10n.financialSettlementDialogTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SelectionArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isCloneDraft) ...[
                    Text(l10n.settlementCloneHint, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 10),
                  ],
                  SearchableDropdownField<int?>(
                    key: const Key('settlementImportFileField'),
                    value: _selectedImportFileId,
                    labelText: widget.isCloneDraft
                        ? l10n.settlementCloneTargetFileLabel
                        : l10n.financialSettlementImportFileLabel,
                    searchHintText: l10n.financialSettlementImportFileSearchHint,
                    items: importFiles
                        .map((f) => SearchableDropdownItem<int?>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.companyName}',
                              subtitle: f.companyName,
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedImportFileId = val),
                    validator: (v) {
                      if (v == null) return l10n.financialSettlementImportFileValidator;
                      if (v == _sourceImportFileId) return l10n.settlementCloneTargetFileMustDiffer;
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  header(l10n.financialSettlementExpenseSectionHeader, AppTheme.cobalt),
                  const SizedBox(height: 8),
                  _row(compact, [
                    _text(l10n.financialSettlementInvoiceNoLabel, _invNoCtrl, validator: _required),
                    SearchableDropdownField<String>(
                      value: _category,
                      labelText: l10n.financialSettlementCategoryLabel,
                      searchHintText: l10n.financialSettlementCategorySearchHint,
                      items: [
                        SearchableDropdownItem(value: 'Freight', label: l10n.financialSettlementCategoryFreight),
                        SearchableDropdownItem(value: 'Customs Duty', label: l10n.financialSettlementCategoryCustomsDuty),
                        SearchableDropdownItem(value: 'Brokerage', label: l10n.financialSettlementCategoryBrokerage),
                        SearchableDropdownItem(value: 'Local Transport', label: l10n.financialSettlementCategoryLocalTransport),
                        SearchableDropdownItem(value: 'Storage', label: l10n.financialSettlementCategoryStorage),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _row(compact, [
                    _text(l10n.financialSettlementProviderNameLabel, _providerCtrl, validator: _required),
                    SearchableDropdownField<String?>(
                      key: const Key('settlementCurrencyField'),
                      value: _currency,
                      labelText: l10n.settlementCurrencyLabel,
                      searchHintText: l10n.settlementCurrencySearchHint,
                      items: currencies
                          .map((c) => SearchableDropdownItem<String?>(
                                value: c.currencyCode,
                                label: '${c.currencyCode} - ${c.currencyName}',
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v),
                      validator: (v) => (v == null || v.isEmpty) ? l10n.settlementCurrencyRequired : null,
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _row(compact, [
                    _text(l10n.financialSettlementAmountFxLabel, _amountFxCtrl,
                        validator: _positive, numeric: true, key: const Key('settlementAmountFxField')),
                    _text(l10n.financialSettlementExchangeRateLabel, _rateCtrl,
                        validator: _rateValidator, numeric: true, key: const Key('settlementRateField')),
                  ]),
                  const SizedBox(height: 8),
                  SearchableDropdownField<String>(
                    value: _allocationRule,
                    labelText: l10n.financialSettlementAllocationRuleLabel,
                    searchHintText: l10n.financialSettlementAllocationRuleSearchHint,
                    items: ruleItems,
                    onChanged: (v) {
                      if (v != null) setState(() => _allocationRule = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  header(l10n.financialSettlementItemSectionHeader, AppTheme.emerald),
                  const SizedBox(height: 8),
                  _row(compact, [
                    _text(l10n.financialSettlementItemCodeLabel, _itemCodeCtrl, validator: _required),
                    _text(l10n.financialSettlementItemNameLabel, _itemNameCtrl, validator: _required),
                  ], flex: const [1, 2]),
                  const SizedBox(height: 8),
                  _row(compact, [
                    _text(l10n.financialSettlementQtyReceivedLabel, _qtyCtrl,
                        validator: _positive, numeric: true, key: const Key('settlementQtyField')),
                    _text(l10n.financialSettlementFobUnitPriceLabel, _fobUnitCtrl,
                        validator: _positive, numeric: true, key: const Key('settlementFobUnitField')),
                  ]),
                  const SizedBox(height: 8),
                  _row(compact, [
                    _text(l10n.settlementGrossWeightLabel, _weightCtrl,
                        validator: _optionalNonNegative, numeric: true, key: const Key('settlementWeightField')),
                    _text(l10n.settlementCbmLabel, _cbmCtrl,
                        validator: _optionalNonNegative, numeric: true, key: const Key('settlementCbmField')),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l10n.financialSettlementLiveReloadBtn,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          icon: Icons.refresh,
          onPressed: _isLoading
              ? null
              : () {
                  ref.read(financialSettlementProvider.notifier).fetchSettlements();
                  ref.read(importFilesProvider.notifier).fetchImportFiles();
                  ref.read(currenciesProvider.notifier).fetchCurrencies(includeInactive: false);
                },
        ),
        AppButton(
          label: l10n.financialSettlementResetFormBtn,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          icon: Icons.cleaning_services_outlined,
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _invNoCtrl.clear();
                    _providerCtrl.clear();
                    _amountFxCtrl.clear();
                    _rateCtrl.clear();
                    _currency = null;
                  });
                },
        ),
        AppButton(
          label: l10n.cancel,
          variant: AppButtonVariant.secondary,
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        AppButton(
          key: const Key('settlementSaveButton'),
          label: l10n.financialSettlementSaveAndAllocateBtn,
          variant: AppButtonVariant.success,
          icon: Icons.check_circle_outline,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _save,
        ),
      ],
    );
  }
}
