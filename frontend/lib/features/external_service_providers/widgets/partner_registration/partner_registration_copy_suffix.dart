import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class PartnerRegistrationCopySuffix extends StatelessWidget {
  final TextEditingController controller;

  const PartnerRegistrationCopySuffix({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (ctx, val, _) {
        if (val.text.trim().isEmpty) return const SizedBox.shrink();
        return Tooltip(
          message: l10n.partnersCopyFieldTooltip,
          child: InkWell(
            onTap: () => CopyHelper.copy(
              context,
              val.text.trim(),
              customMessage: l10n.copiedToClipboard(val.text.trim()),
            ),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.copy_rounded, size: 15, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}
