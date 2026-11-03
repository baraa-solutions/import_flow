import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

/// Standard dialog footer: neutral cancel + one primary action with an in-button
/// spinner (repeat taps are blocked while [isLoading]).
List<Widget> ccDialogActions({
  required BuildContext context,
  required String confirmLabel,
  required VoidCallback? onConfirm,
  required bool isLoading,
  AppButtonVariant confirmVariant = AppButtonVariant.primary,
}) {
  return [
    AppButton(
      label: context.l10n.cancel,
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.small,
      onPressed: isLoading ? null : () => Navigator.pop(context),
    ),
    AppButton(
      label: confirmLabel,
      variant: confirmVariant,
      size: AppButtonSize.small,
      isLoading: isLoading,
      onPressed: onConfirm,
    ),
  ];
}

Widget ccCopyIcon(BuildContext context, TextEditingController c) => IconButton(
      icon: const Icon(Icons.copy, size: 16),
      tooltip: context.l10n.customsClearanceCopyFieldTooltip,
      onPressed: () => CopyHelper.copy(context, c.text),
    );
