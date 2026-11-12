import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/localization/app_localizations.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import 'idoc_ui_b.dart';

/// Lazy Modal dialog for recording the customs broker's pulling of the tax coding sheet from Nafeza.
/// Disposes all controllers properly on dialog unmount.
class PullTaxCodingSheetDialog extends ConsumerStatefulWidget {
  final BankingDocumentModel doc;
  final VoidCallback onSubmitted;

  const PullTaxCodingSheetDialog({
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
      builder: (ctx) => PullTaxCodingSheetDialog(
        doc: doc,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  ConsumerState<PullTaxCodingSheetDialog> createState() => _PullTaxCodingSheetDialogState();
}

class _PullTaxCodingSheetDialogState extends ConsumerState<PullTaxCodingSheetDialog> {
  int? _selectedBrokerId;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _fileUrlCtrl;
  late final TextEditingController _notesCtrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    // Starts empty for a new pull: the user picks the broker (never an arbitrary first broker).
    _selectedBrokerId = doc.taxCodingBrokerId;
    _dateCtrl = TextEditingController(
      text: doc.taxCodingPulledDate ?? DateTime.now().toIso8601String().substring(0, 10),
    );
    _fileUrlCtrl = TextEditingController(text: doc.taxCodingSheetFileUrl ?? '');
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _fileUrlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);
    try {
      await ref.read(bankingDocumentsProvider.notifier).pullTaxCodingSheet(
        widget.doc.bankDocId,
        {
          'broker_id': _selectedBrokerId,
          'pulled_date': _dateCtrl.text.trim(),
          'file_url': _fileUrlCtrl.text.trim().isNotEmpty ? _fileUrlCtrl.text.trim() : null,
          'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmitted();
        messenger.showSnackBar(
          AppTheme.snackBar(context, 'تم تسجيل سحب شيت التكويد الضريبي بنجاح ومطالبة المحاسب بالرفع والتكويد'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showErrorDetailsDialog(context, title: 'خطأ في تسجيل سحب الشيت', error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partners = ref.watch(partnersProvider).valueOrNull ?? [];
    final brokers = partners.where((p) =>
      p.partnerType.contains('Customs') ||
      p.partnerType.contains('مستخلص') ||
      p.partnerType.contains('Broker')
    ).toList();

    return SelectionArea(
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: AppTheme.wcagCobalt),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تسجيل سحب شيت التكويد الضريبي (المستخلص)',
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
                'يقوم المستخلص الجمركي بسحب شيت الأصناف الضريبي من منصة نافذة لتسليمه لمحاسب الشركة لتكويده.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              SearchableDropdownField<int>(
                labelText: 'المستخلص الجمركي المسئول',
                hintText: 'اختر المستخلص الجمركي',
                value: _selectedBrokerId,
                isRequired: true,
                items: brokers.map((b) => SearchableDropdownItem<int>(
                  value: b.providerId ?? 0,
                  label: '${b.partnerName} (${b.partnerCode})',
                )).toList(),
                onChanged: (val) => setState(() => _selectedBrokerId = val),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'تاريخ سحب الشيت من نافذة',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fileUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'رابط / مسار ملف الشيت (اختياري)',
                  prefixIcon: Icon(Icons.attachment_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات المستخلص',
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
            label: 'تأكيد السحب',
            icon: Icons.check,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting || _selectedBrokerId == null ? null : _submit,
          )),
        ],
      ),
    );
  }
}
