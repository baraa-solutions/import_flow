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

/// Lazy Modal dialog for linking customs declaration to executing bank on Nafeza platform.
/// Disposes all text editing controllers on unmount to eliminate memory leaks.
class NafezaBankLinkDialog extends ConsumerStatefulWidget {
  final BankingDocumentModel doc;
  final VoidCallback onSubmitted;

  const NafezaBankLinkDialog({
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
      builder: (ctx) => NafezaBankLinkDialog(
        doc: doc,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  ConsumerState<NafezaBankLinkDialog> createState() => _NafezaBankLinkDialogState();
}

class _NafezaBankLinkDialogState extends ConsumerState<NafezaBankLinkDialog> {
  int? _selectedBankId;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _notesCtrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    final partners = ref.read(partnersProvider).valueOrNull ?? [];
    final banks = partners.where((p) => p.partnerType.contains('Bank') || p.partnerType.contains('بنك')).toList();

    _selectedBankId = doc.nafezaLinkedBankId ?? doc.swiftExecutingBankId ?? (banks.isNotEmpty ? banks.first.providerId : null);
    _dateCtrl = TextEditingController(
      text: doc.nafezaBankLinkDate ?? DateTime.now().toIso8601String().substring(0, 10),
    );
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedBankId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);
    try {
      await ref.read(bankingDocumentsProvider.notifier).linkNafezaBank(
        widget.doc.bankDocId,
        {
          'nafeza_linked_bank_id': _selectedBankId,
          'link_date': _dateCtrl.text.trim(),
          'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmitted();
        messenger.showSnackBar(
          AppTheme.snackBar(context, 'تم تسجيل الربط البنكي على نافذة بنجاح ومطابقة البنك'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showErrorDetailsDialog(context, title: 'خطأ في الربط البنكي', error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partners = ref.watch(partnersProvider).valueOrNull ?? [];
    final banks = partners.where((p) => p.partnerType.contains('Bank') || p.partnerType.contains('بنك')).toList();
    final isMatchingSwift = doc.swiftExecutingBankId != null && _selectedBankId == doc.swiftExecutingBankId;

    return SelectionArea(
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link, color: AppTheme.wcagCobalt),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ربط الشهادة بالبنك على منصة نافذة (المستخلص)',
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
                'يقوم المستخلص بربط الإقرار الجمركي على نافذة بالبنك المنفذ لسويفت التحويل حصراً حتى يتمكن البنك من إقرار نموذج 4.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              if (doc.swiftExecutingBankName != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.wcagCobalt.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 16, color: AppTheme.wcagCobalt),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'البنك المنفذ لسويفت التحويل: ${doc.swiftExecutingBankName}'
                          '${doc.swiftReferenceNo != null ? " (سويفت: ${doc.swiftReferenceNo})" : ""}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SearchableDropdownField<int>(
                labelText: 'البنك المربوط عليه الشهادة على نافذة',
                hintText: 'اختر البنك',
                value: _selectedBankId,
                isRequired: true,
                items: banks.map((b) => SearchableDropdownItem<int>(
                  value: b.providerId ?? 0,
                  label: '${b.partnerName} (${b.partnerCode})'
                      '${b.providerId == doc.swiftExecutingBankId ? " ⭐️ [بنك السويفت]" : ""}',
                )).toList(),
                onChanged: (val) => setState(() => _selectedBankId = val),
              ),
              const SizedBox(height: 8),

              if (!isMatchingSwift && doc.swiftExecutingBankId != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: AppTheme.crimson),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'تنبيه: البنك المختار لا يطابق بنك سويفت التحويل! يجب الربط بنفس بنك السويفت.',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.crimson, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              TextFormField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'تاريخ إتمام الربط البنكي',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات الربط البنكي ورقم التأكيد على نافذة',
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
            label: 'تأكيد الربط البنكي',
            icon: Icons.link,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting || _selectedBankId == null ? null : _submit,
          )),
        ],
      ),
    );
  }
}
