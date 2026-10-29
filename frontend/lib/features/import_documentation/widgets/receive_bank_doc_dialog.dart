import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import 'idoc_ui_b.dart';

/// Lazy Modal dialog for receiving and endorsing a bank Form 4 document.
/// Encapsulates text editing controllers with strict disposal lifecycle
/// to prevent memory leaks.
class ReceiveBankDocDialog extends ConsumerStatefulWidget {
  final BankingDocumentModel doc;
  final VoidCallback onSubmitted;

  const ReceiveBankDocDialog({
    super.key,
    required this.doc,
    required this.onSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required BankingDocumentModel doc,
    required VoidCallback onSubmitted,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ReceiveBankDocDialog(
        doc: doc,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  ConsumerState<ReceiveBankDocDialog> createState() => _ReceiveBankDocDialogState();
}

class _ReceiveBankDocDialogState extends ConsumerState<ReceiveBankDocDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _notesCtrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    _numCtrl = TextEditingController(
      text: doc.docReferenceNumber != 'PENDING' ? doc.docReferenceNumber : '',
    );
    _dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    _notesCtrl = TextEditingController(text: doc.notes ?? '');
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(bankingDocumentsProvider.notifier).receiveBankingDocument(
        widget.doc.bankDocId,
        {
          'form4_number': _numCtrl.text.trim(),
          'received_date': _dateCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.idocBBankEndorsedSuccess),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showErrorDetailsDialog(
          context,
          title: context.l10n.idocBBankEndorseError,
          error: e,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified, color: AppTheme.wcagEmerald),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.idocBBankReceiptTitle(doc.docType),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.idocBBankReceiptIntro(doc.bankName),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _numCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.idocBBankReceiptNumLabel(doc.docType),
                    hintText: context.l10n.idocBBankReceiptNumHint,
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? (context.l10n.idocBBankReceiptNumRequired)
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.idocBBankReceiptDateLabel,
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? (context.l10n.idocBBankReceiptDateRequired)
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.l10n.idocBBankReceiptNotesLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IdocBUi.fit(AppButton(
            label: context.l10n.cancel,
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            variant: AppButtonVariant.secondary,
          )),
          IdocBUi.fit(AppButton(
            label: _isSubmitting
                ? context.l10n.idocBBankEndorsing
                : context.l10n.idocBBankEndorseAndLink,
            onPressed: _isSubmitting ? null : _submit,
            icon: Icons.check,
            isLoading: _isSubmitting,
          )),
        ],
      ),
    );
  }
}
