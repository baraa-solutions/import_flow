import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_dialog_layout.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

enum ShortageClaimDecision { fileClaim, waive }

class ShortageClaimResult {
  final ShortageClaimDecision decision;
  final String? claimRef;
  final String reasonOrNotes;
  final double estimatedAmount;
  final String currency;
  const ShortageClaimResult({required this.decision, this.claimRef, required this.reasonOrNotes, required this.estimatedAmount, required this.currency});
}

/// Modal for settling warehouse receiving shortages (file claim or waive).
class ShortageClaimDialog extends StatefulWidget {
  final int importFileId;
  final String grnCode;
  final int totalShortageQty;
  final double estimatedAmount;
  final String currency;
  final Future<void> Function(ShortageClaimResult result)? onSubmit;

  const ShortageClaimDialog({
    super.key, required this.importFileId, required this.grnCode,
    required this.totalShortageQty, required this.estimatedAmount,
    required this.currency, this.onSubmit,
  });

  static Future<ShortageClaimResult?> show({
    required BuildContext context, required int importFileId,
    required String grnCode, required int totalShortageQty,
    required double estimatedAmount, required String currency,
    Future<void> Function(ShortageClaimResult result)? onSubmit,
  }) => showDialog<ShortageClaimResult>(
    context: context, barrierDismissible: false,
    builder: (_) => ShortageClaimDialog(
      importFileId: importFileId, grnCode: grnCode, totalShortageQty: totalShortageQty,
      estimatedAmount: estimatedAmount, currency: currency, onSubmit: onSubmit,
    ),
  );

  @override
  State<ShortageClaimDialog> createState() => _ShortageClaimDialogState();
}

class _ShortageClaimDialogState extends State<ShortageClaimDialog> {
  final _formKey = GlobalKey<FormState>();
  ShortageClaimDecision _decision = ShortageClaimDecision.fileClaim;
  late final TextEditingController _claimRefCtrl = TextEditingController(text: 'CLM-${widget.grnCode}');
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _waiveReasonCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _claimRefCtrl.dispose();
    _notesCtrl.dispose();
    _waiveReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final isClaim = _decision == ShortageClaimDecision.fileClaim;
    final res = ShortageClaimResult(
      decision: _decision,
      claimRef: isClaim ? _claimRefCtrl.text.trim() : null,
      reasonOrNotes: (isClaim ? _notesCtrl : _waiveReasonCtrl).text.trim(),
      estimatedAmount: widget.estimatedAmount, currency: widget.currency,
    );
    try {
      if (widget.onSubmit != null) await widget.onSubmit!(res);
      if (mounted) Navigator.of(context).pop(res);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);
    final isClaim = _decision == ShortageClaimDecision.fileClaim;

    return AppDialogLayout(
      title: isAr ? 'تسوية عجز استلام المستودع' : 'Warehouse Shortage Settlement',
      subtitle: isAr ? 'إذن الإضافة: ${widget.grnCode} • ملف الشحنة: #${widget.importFileId}' : 'GRN: ${widget.grnCode} • Import File: #${widget.importFileId}',
      icon: Icons.assignment_late_outlined,
      iconColor: AppTheme.orange,
      maxWidth: 580,
      actions: [
        AppButton(label: isAr ? 'إلغاء' : 'Cancel', variant: AppButtonVariant.secondary, onPressed: _isLoading ? null : () => Navigator.of(context).pop()),
        const SizedBox(width: 8),
        AppButton(
          label: isClaim ? (isAr ? 'إرسال المطالبة الرسمية' : 'Submit Official Claim') : (isAr ? 'تأكيد التنازل مع السبب' : 'Confirm Waiver'),
          variant: isClaim ? AppButtonVariant.primary : AppButtonVariant.warning,
          icon: isClaim ? Icons.send_rounded : Icons.check_circle_outline,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _submit,
        ),
      ],
      child: SelectionArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSummaryCard(isAr, isDark),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _tabButton(
                        label: isAr ? 'فتح مطالبة للمورد' : 'File Supplier Claim',
                        icon: Icons.send_rounded,
                        selected: isClaim,
                        color: AppTheme.cobalt,
                        isDark: isDark,
                        onTap: () => setState(() => _decision = ShortageClaimDecision.fileClaim),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _tabButton(
                        label: isAr ? 'تجاهل وتنازل مع سبب' : 'Waive with Reason',
                        icon: Icons.cancel_outlined,
                        selected: !isClaim,
                        color: AppTheme.orange,
                        isDark: isDark,
                        onTap: () => setState(() => _decision = ShortageClaimDecision.waive),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isClaim) ...[
                  CustomTextField(controller: _claimRefCtrl, label: isAr ? 'رقم مرجع مطالبة المورد' : 'Supplier Claim Reference', isRequired: true, textDirection: TextDirection.ltr, icon: Icons.tag),
                  const SizedBox(height: 10),
                  CustomTextField(controller: _notesCtrl, label: isAr ? 'تفاصيل وملاحظات المطالبة' : 'Claim Details & Notes', hint: isAr ? 'أدخل تفاصيل العجز الفنية للمورد' : 'Enter shortage details for supplier', maxLines: 2, icon: Icons.notes_rounded),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.orangeLight, borderRadius: BorderRadius.circular(AppTheme.radiusSm), border: Border.all(color: AppTheme.orange)),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(isAr ? 'سيتم تسجيل التنازل رسمياً مع إثبات السبب.' : 'Waiver will be recorded with stated reason.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: _waiveReasonCtrl,
                    label: isAr ? 'سبب التجاوز والتنازل *' : 'Waiver Justification *',
                    isRequired: true,
                    maxLines: 2,
                    hint: isAr ? 'اذكر مبرر التنازل (مثال: نسبة فاقد مسموحة)' : 'Specify reason (e.g. allowed loss margin)',
                    validator: (v) => (v == null || v.trim().isEmpty) ? (isAr ? 'سبب التنازل مطلوب' : 'Waiver reason is required') : null,
                    icon: Icons.edit_note_rounded,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isAr, bool isDark) {
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;
    final amount = '${widget.estimatedAmount.toStringAsFixed(2)} ${widget.currency}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: border)),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppTheme.crimson, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('${isAr ? 'كمية العجز' : 'Shortage'}: ${widget.totalShortageQty}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context)))),
          Container(width: 1, height: 24, color: border),
          const SizedBox(width: 10),
          const Icon(Icons.monetization_on_outlined, color: AppTheme.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('${isAr ? 'القيمة' : 'Value'}: $amount', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context)))),
        ],
      ),
    );
  }

  Widget _tabButton({required String label, required IconData icon, required bool selected, required Color color, required bool isDark, required VoidCallback onTap}) {
    final border = selected ? color : (isDark ? AppTheme.darkBorder : AppTheme.border);
    final bg = selected ? (color == AppTheme.cobalt ? AppTheme.cobaltLight : AppTheme.orangeLight) : (isDark ? AppTheme.darkSurface : AppTheme.surface);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppTheme.radiusSm), border: Border.all(color: border, width: selected ? 1.5 : 1.0)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : AppTheme.textSecondaryOf(context)),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? color : AppTheme.textSecondaryOf(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
