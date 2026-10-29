import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/currency_model.dart';
import '../providers/currencies_provider.dart';

/// 🏛️ Reusable Lazy Modal Dialog for Creating / Editing Currencies.
/// Extracted from currencies_screen.dart to follow the Zero-Weight / Lazy Modals rule.
class CurrencyFormDialog extends ConsumerStatefulWidget {
  final CurrencyModel? currency;

  const CurrencyFormDialog({super.key, this.currency});

  static Future<bool?> show(BuildContext context, {CurrencyModel? currency}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CurrencyFormDialog(currency: currency),
    );
  }

  @override
  ConsumerState<CurrencyFormDialog> createState() => _CurrencyFormDialogState();
}

class _CurrencyFormDialogState extends ConsumerState<CurrencyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _symbolCtrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.currency?.currencyCode ?? '');
    _nameCtrl = TextEditingController(text: widget.currency?.currencyName ?? '');
    _symbolCtrl = TextEditingController(text: widget.currency?.currencySymbol ?? '');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _symbolCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      if (widget.currency == null) {
        final newModel = CurrencyModel(
          currencyCode: _codeCtrl.text.trim().toUpperCase(),
          currencyName: _nameCtrl.text.trim(),
          currencySymbol: _symbolCtrl.text.trim(),
        );
        final ok = await ref.read(currenciesProvider.notifier).createCurrency(newModel);
        if (ok && mounted) Navigator.pop(context, true);
      } else {
        final updateData = {
          'currency_name': _nameCtrl.text.trim(),
          'currency_symbol': _symbolCtrl.text.trim(),
        };
        final ok = await ref
            .read(currenciesProvider.notifier)
            .updateCurrency(widget.currency!.currencyId!, updateData);
        if (ok && mounted) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isNew = widget.currency == null;

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            const Icon(Icons.currency_exchange, color: AppTheme.cobalt, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isNew
                    ? l10n.addCurrencyDialogTitle
                    : l10n.editCurrencyDialogTitle(widget.currency!.currencyCode),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeCtrl,
                  enabled: isNew,
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.isoCodeLabel,
                    hintText: l10n.isoCodeHint,
                    prefixIcon: const Icon(Icons.code_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.currencyCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _codeCtrl.text),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().length != 3
                      ? l10n.isoCodeLengthError
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.currencyNameLabel,
                    hintText: l10n.currencyNameHint,
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.currencyCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _nameCtrl.text),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l10n.requiredField : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _symbolCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.currencySymbolLabel,
                    hintText: l10n.currencySymbolHint,
                    prefixIcon: const Icon(Icons.euro_symbol, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.currencyCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _symbolCtrl.text),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l10n.requiredField : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (widget.currency != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: AppTheme.crimson),
              tooltip: l10n.exportCurrencyPdfBtn,
              onPressed: () =>
                  MasterDataExportService.printOrSaveCurrencyPdf(widget.currency!),
            ),
          AppButton(
            label: l10n.cancel,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          ),
          AppButton(
            label: isNew
                ? l10n.createCurrencySubmitBtn
                : l10n.saveChangesSubmitBtn,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
