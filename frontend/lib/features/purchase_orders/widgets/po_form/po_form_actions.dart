import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Action buttons for the PO Form dialog (Cancel, Preview Report, Save/Submit).
class POFormActions extends StatelessWidget {
  final bool isEdit;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onPreviewReport;
  final VoidCallback onSubmit;

  const POFormActions({
    super.key,
    required this.isEdit,
    required this.isSubmitting,
    required this.onCancel,
    required this.onPreviewReport,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    // Wrap (not Row): on a phone-width dialog the buttons drop to a second line instead of overflowing.
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        AppButton(
          label: l.cancel,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onCancel,
        ),
        AppButton(
          label: l.previewPoReportBtn,
          icon: Icons.preview_rounded,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onPreviewReport,
        ),
        AppButton(
          label: isEdit ? l.savePoEditsBtn : l.savePurchaseOrderBtn,
          icon: Icons.save_rounded,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          isLoading: isSubmitting,
          onPressed: isSubmitting ? null : onSubmit,
        ),
      ],
    );
  }
}
