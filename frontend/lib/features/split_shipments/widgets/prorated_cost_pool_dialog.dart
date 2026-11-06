import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/buttons/app_button.dart';

/// Asks the user for the file's customs and freight cost pools before redistributing
/// them across split allocations. Returns `(customs, freight)` or null when cancelled.
Future<(double, double)?> showProratedCostPoolDialog(BuildContext context) {
  return showDialog<(double, double)>(
    context: context,
    builder: (_) => const _ProratedCostPoolDialog(),
  );
}

class _ProratedCostPoolDialog extends StatefulWidget {
  const _ProratedCostPoolDialog();

  @override
  State<_ProratedCostPoolDialog> createState() => _ProratedCostPoolDialogState();
}

class _ProratedCostPoolDialogState extends State<_ProratedCostPoolDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customsController = TextEditingController();
  final _freightController = TextEditingController();

  @override
  void dispose() {
    _customsController.dispose();
    _freightController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final l10n = context.l10n;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return l10n.requiredField;
    final parsed = double.tryParse(text);
    if (parsed == null || parsed < 0) return l10n.invalidNumberError;
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      double.parse(_customsController.text.trim()),
      double.parse(_freightController.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SelectionArea(
      child: AlertDialog(
        title: Text(l10n.splitPoolDialogTitle),
        content: SizedBox(
          width: 360,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('splitPoolCustomsField'),
                  controller: _customsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.splitPoolCustomsLabel),
                  validator: _validate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('splitPoolFreightField'),
                  controller: _freightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.splitPoolFreightLabel),
                  validator: _validate,
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppButton(
            label: l10n.confirm,
            variant: AppButtonVariant.primary,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
