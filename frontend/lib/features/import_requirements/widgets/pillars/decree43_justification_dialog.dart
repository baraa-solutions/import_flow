import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// ⚖️ Decree 43 Justification Dialog — ImportFlow ERP
///
/// Isolated modal dialog to review exemptions and enter justification for
/// non-registered factories under Egyptian Decree 43 / 2016.
class Decree43JustificationDialog extends StatefulWidget {
  final String? initialJustification;

  const Decree43JustificationDialog({
    super.key,
    this.initialJustification,
  });

  static Future<String?> show(
    BuildContext context, {
    String? initialJustification,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Decree43JustificationDialog(
        initialJustification: initialJustification,
      ),
    );
  }

  @override
  State<Decree43JustificationDialog> createState() => _Decree43JustificationDialogState();
}

class _Decree43JustificationDialogState extends State<Decree43JustificationDialog> {
  late final TextEditingController _justCtrl;

  @override
  void initState() {
    super.initState();
    _justCtrl = TextEditingController(text: widget.initialJustification ?? '');
  }

  @override
  void dispose() {
    _justCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final sampleReasons = [
      l10n.decree43JustificationReasonProductionInput,
      l10n.decree43JustificationReasonPrivateUse,
      l10n.decree43JustificationReasonSpareParts,
      l10n.decree43JustificationReasonMinisterialExemption,
      l10n.decree43SampleReasonGoeicReview,
    ];

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.gavel_rounded, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Text(
              l10n.decree43JustificationDialogTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cobaltLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cobaltBorder),
                ),
                child: Text(
                  l10n.decree43JustificationDialogDesc,
                  style: const TextStyle(fontSize: 12, color: AppTheme.wcagCobalt),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.decree43CommonExemptionsTitle,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: sampleReasons.map((r) => ActionChip(
                  label: Text(r, style: const TextStyle(fontSize: 10)),
                  backgroundColor: AppTheme.charcoalSurface,
                  onPressed: () {
                    _justCtrl.text = r;
                    setState(() {});
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _justCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.decree43OptionRequestJustification,
                  hintText: l10n.decree43JustificationHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l10n.requirementCopyFieldTooltip,
                    onPressed: () => CopyHelper.copy(
                      context,
                      _justCtrl.text,
                      customMessage: l10n.requirementCopySummarySuccess,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: l10n.cancel,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: l10n.save,
            icon: Icons.check,
            variant: AppButtonVariant.success,
            onPressed: () {
              final txt = _justCtrl.text.trim();
              if (txt.isEmpty) return;
              Navigator.pop(context, txt);
            },
          ),
        ],
      ),
    );
  }
}
