import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import 'idoc_ui_b.dart';

/// Lazy Modal dialog for confirming the company accountant's upload and coding of items on Nafeza.
/// Disposes all text editing controllers on unmount.
class UploadTaxCodingDialog extends ConsumerStatefulWidget {
  final BankingDocumentModel doc;
  final VoidCallback onSubmitted;

  const UploadTaxCodingDialog({
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
      builder: (ctx) => UploadTaxCodingDialog(
        doc: doc,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  ConsumerState<UploadTaxCodingDialog> createState() => _UploadTaxCodingDialogState();
}

class _UploadTaxCodingDialogState extends ConsumerState<UploadTaxCodingDialog> {
  late final TextEditingController _accountantCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _notesCtrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    _accountantCtrl = TextEditingController(
      text: doc.taxCodingAccountantName ?? 'محاسب الشركة المعتمد',
    );
    _dateCtrl = TextEditingController(
      text: doc.taxCodingUploadedDate ?? DateTime.now().toIso8601String().substring(0, 10),
    );
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _accountantCtrl.dispose();
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);
    try {
      await ref.read(bankingDocumentsProvider.notifier).uploadTaxCodingSheet(
        widget.doc.bankDocId,
        {
          'accountant_name': _accountantCtrl.text.trim(),
          'uploaded_date': _dateCtrl.text.trim(),
          'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmitted();
        messenger.showSnackBar(
          AppTheme.snackBar(context, 'تم تأكيد رفع وتكويد الأصناف ضريبياً على نافذة بنجاح'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showErrorDetailsDialog(context, title: 'خطأ في تأكيد التكويد', error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload_file_outlined, color: AppTheme.wcagEmerald),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تأكيد رفع وتكويد الشيت على نافذة (المحاسب)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'يقوم محاسب الشركة برفع وتكويد الأصناف على منصة نافذة باستخدام التوكن الضريبي الخاص بالشركة (EGS/GS1).',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountantCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المحاسب المسئول عن التكويد',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'تاريخ نجاح الرفع والتكويد',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات التكويد ورقم الإقرار الضريبي إن وجد',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IdocBUi.fit(AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          )),
          IdocBUi.fit(AppButton(
            label: 'تأكيد التكويد والرفع',
            icon: Icons.check,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          )),
        ],
      ),
    );
  }
}
