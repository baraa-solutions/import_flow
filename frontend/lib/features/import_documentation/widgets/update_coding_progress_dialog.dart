import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import 'idoc_ui_b.dart';

/// Lazy Modal dialog for verifying item coding progress and detected regulatory bodies on Nafeza.
/// Disposes text editing controllers cleanly on unmount.
class UpdateCodingProgressDialog extends ConsumerStatefulWidget {
  final BankingDocumentModel doc;
  final VoidCallback onSubmitted;

  const UpdateCodingProgressDialog({
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
      builder: (ctx) => UpdateCodingProgressDialog(
        doc: doc,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  ConsumerState<UpdateCodingProgressDialog> createState() => _UpdateCodingProgressDialogState();
}

class _UpdateCodingProgressDialogState extends ConsumerState<UpdateCodingProgressDialog> {
  late final TextEditingController _totalCtrl;
  late final TextEditingController _codedCtrl;
  late final TextEditingController _notesCtrl;
  late final Set<String> _selectedBodies;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    _totalCtrl = TextEditingController(
      text: doc.itemsCountTotal > 0 ? '${doc.itemsCountTotal}' : '1',
    );
    _codedCtrl = TextEditingController(
      text: doc.itemsCountCoded > 0 ? '${doc.itemsCountCoded}' : _totalCtrl.text,
    );
    _selectedBodies = Set<String>.from(doc.regulatoryBodiesDetected);
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _codedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onSelected) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, color: isSelected ? AppTheme.white : AppTheme.charcoal)),
      selected: isSelected,
      selectedColor: AppTheme.wcagCobalt,
      checkmarkColor: AppTheme.white,
      onSelected: (_) => onSelected(),
    );
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final total = int.tryParse(_totalCtrl.text) ?? 1;
    final coded = int.tryParse(_codedCtrl.text) ?? total;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(bankingDocumentsProvider.notifier).verifyItems(
        widget.doc.bankDocId,
        {
          'items_pulled_verified': true,
          'items_count_total': total,
          'items_count_coded': coded,
          'regulatory_bodies': _selectedBodies.toList(),
          'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmitted();
        messenger.showSnackBar(
          AppTheme.snackBar(context, 'تم تأكيد سحب وفحص الأصناف والتكويد 100% بنجاح'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showErrorDetailsDialog(context, title: 'خطأ في تأكيد فحص الأصناف', error: e);
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
            Icon(Icons.fact_check_outlined, color: AppTheme.wcagEmerald),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تأكيد سحب الأصناف والتحقق من التكويد 100% (المستخلص)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'يقوم المستخلص بسحب الأصناف على نافذة للتأكد من نجاح التكويد 100% واكتشاف أي جهات عرض رقابية.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _totalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'إجمالي عدد الأصناف',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _codedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'عدد الأصناف المكودة بنجاح',
                          prefixIcon: Icon(Icons.check_circle_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'جهات العرض الرقابية المكتشفة على نافذة:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('GOEIC (صادرات وواردات)', _selectedBodies.contains('GOEIC'), () {
                      setState(() {
                        if (_selectedBodies.contains('GOEIC')) {
                          _selectedBodies.remove('GOEIC');
                        } else {
                          _selectedBodies.add('GOEIC');
                        }
                      });
                    }),
                    _buildChip('NFSA (سلامة الغذاء)', _selectedBodies.contains('NFSA'), () {
                      setState(() {
                        if (_selectedBodies.contains('NFSA')) {
                          _selectedBodies.remove('NFSA');
                        } else {
                          _selectedBodies.add('NFSA');
                        }
                      });
                    }),
                    _buildChip('Radiation (هيئة الطاقة الذرية)', _selectedBodies.contains('Radiation'), () {
                      setState(() {
                        if (_selectedBodies.contains('Radiation')) {
                          _selectedBodies.remove('Radiation');
                        } else {
                          _selectedBodies.add('Radiation');
                        }
                      });
                    }),
                    _buildChip('Phytosanitary (حجر زراعي/بيطري)', _selectedBodies.contains('Phytosanitary'), () {
                      setState(() {
                        if (_selectedBodies.contains('Phytosanitary')) {
                          _selectedBodies.remove('Phytosanitary');
                        } else {
                          _selectedBodies.add('Phytosanitary');
                        }
                      });
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات فحص الأصناف',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IdocBUi.fit(AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          )),
          IdocBUi.fit(AppButton(
            label: 'تأكيد السحب والفحص',
            icon: Icons.check,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          )),
        ],
      ),
    );
  }
}
