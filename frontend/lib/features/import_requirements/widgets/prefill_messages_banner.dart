import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/system_messages/system_message_renderer.dart';
import '../../../core/theme/app_theme.dart';
import '../models/import_requirement_model.dart';

/// Localized text of a prefill system message (`{code, params}`) from the shared
/// system-message catalog; an unknown code is skipped (null) rather than shown raw.
String? prefillMessageText(AppLocalizations l10n, PrefillMessage m) => SystemMessageRenderer.tryRender(
      code: m.code,
      params: m.params,
      part: SystemMessagePart.note,
      l10n: l10n,
    );

/// Warning card listing the prefill messages (no HS code found, PO line without a tariff).
class PrefillMessagesBanner extends StatelessWidget {
  const PrefillMessagesBanner({super.key, required this.messages});

  final List<PrefillMessage> messages;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lines = [
      for (final m in messages) prefillMessageText(l10n, m),
    ].whereType<String>().toList();
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.orangeLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.orange),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(line, style: const TextStyle(fontSize: 12.5)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
