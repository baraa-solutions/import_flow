import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';

class DualClockGateOutSection extends StatelessWidget {
  final TextEditingController containerController;
  final TextEditingController eirController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const DualClockGateOutSection({
    super.key,
    required this.containerController,
    required this.eirController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return CcFormSection(
      title: l10n.dualClockGateOutSectionTitle,
      icon: Icons.local_shipping_outlined,
      child: LayoutBuilder(
        builder: (context, c) {
          final container = TextFormField(
            controller: containerController,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.dualClockContainerNoLabel,
              hintText: l10n.dualClockContainerNoHint,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                tooltip: l10n.demurrageCopyFieldTooltip,
                onPressed: () => CopyHelper.copy(context, containerController.text, customMessage: l10n.demurrageCopyFieldTooltip),
              ),
            ),
          );
          final eir = TextFormField(
            controller: eirController,
            decoration: InputDecoration(
              labelText: l10n.dualClockEirReceiptLabel,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                tooltip: l10n.demurrageCopyFieldTooltip,
                onPressed: () => CopyHelper.copy(context, eirController.text, customMessage: l10n.demurrageCopyFieldTooltip),
              ),
            ),
          );
          final submit = AppButton(
            onPressed: isSubmitting ? null : onSubmit,
            isLoading: isSubmitting,
            icon: Icons.check_circle_outline,
            label: l10n.dualClockRecordGateOutBtn,
            variant: AppButtonVariant.success,
          );
          if (c.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                container,
                const SizedBox(height: 10),
                eir,
                const SizedBox(height: 10),
                Align(alignment: AlignmentDirectional.centerEnd, child: submit),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: container),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: eir),
              const SizedBox(width: 10),
              submit,
            ],
          );
        },
      ),
    );
  }
}
