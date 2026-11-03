import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/partner_model.dart';

class PartnerShareModals {
  PartnerShareModals._();

  static void showWhatsAppPreview(BuildContext context, PartnerModel partner) {
    final l10n = context.l10n;
    bool isArabic = l10n.isArabic;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final text = MasterDataExportService.generatePartnerWhatsAppText(
              partner,
              isArabic: isArabic);
          return SelectionArea(
            child: AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF25D366)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.whatsappPreviewTitle,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                          value: true,
                          label:
                              Text('عربي', style: TextStyle(fontSize: 11))),
                      ButtonSegment<bool>(
                          value: false,
                          label: Text('EN', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {isArabic},
                    onSelectionChanged: (newSelection) {
                      setModalState(() => isArabic = newSelection.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: SelectableText(
                        text,
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.closeBtn)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366)),
                  icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                  label: Text(l10n.copyWhatsappTextBtn,
                      style: const TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    CopyHelper.copy(context, text,
                        customMessage: l10n.whatsappCopiedSuccess);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void showEmailPreview(BuildContext context, PartnerModel partner) {
    final l10n = context.l10n;
    bool isArabic = l10n.isArabic;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final subject = MasterDataExportService.generatePartnerEmailSubject(
              partner,
              isArabic: isArabic);
          final body = MasterDataExportService.generatePartnerEmailBody(
              partner,
              isArabic: isArabic);

          return SelectionArea(
            child: AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded,
                      color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.emailPreviewTitle,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                          value: true,
                          label:
                              Text('عربي', style: TextStyle(fontSize: 11))),
                      ButtonSegment<bool>(
                          value: false,
                          label: Text('EN', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {isArabic},
                    onSelectionChanged: (newSelection) {
                      setModalState(() => isArabic = newSelection.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.emailSubjectPrefix(subject),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.charcoal)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        body,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.closeBtn)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt),
                  icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                  label: Text(l10n.copyEmailTextBtn,
                      style: const TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    CopyHelper.copy(
                      context,
                      '${l10n.emailSubjectPrefix(subject)}\n\n$body',
                      customMessage: l10n.emailCopiedSuccess,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
