import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Modal dialog for manually attaching a document to a CargoX envelope.
class CargoXAddDocumentDialog extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onAdd;

  const CargoXAddDocumentDialog({
    super.key,
    required this.onAdd,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<Map<String, dynamic>> onAdd,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CargoXAddDocumentDialog(onAdd: onAdd),
    );
  }

  @override
  State<CargoXAddDocumentDialog> createState() => _CargoXAddDocumentDialogState();
}

class _CargoXAddDocumentDialogState extends State<CargoXAddDocumentDialog> {
  final _typeCtrl = TextEditingController(text: 'Certificate of Analysis (COA)');
  final _numCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(text: 'Analysis_Report.pdf');

  @override
  void dispose() {
    _typeCtrl.dispose();
    _numCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return SelectionArea(
      child: Dialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.cargoxAddDocDialogTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _typeCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.cargoxDocTypeField,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _numCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.cargoxDocNumberField,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.cargoxDocFileNameField,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: context.l10n.cargoxAddDocSubmitBtn,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: () {
                        if (_typeCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) return;
                        widget.onAdd({
                          'doc_type': _typeCtrl.text.trim(),
                          'doc_number': _numCtrl.text.trim(),
                          'file_name': _nameCtrl.text.trim(),
                          'file_size_kb': 250.0,
                          'is_mandatory': false,
                          'verified_against_acid': true,
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
