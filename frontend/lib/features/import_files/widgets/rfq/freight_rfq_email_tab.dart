import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/freight_rfq_generator_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/import_file_model.dart';

/// Email draft tab for FreightRfqDialog
class FreightRfqEmailTab extends StatelessWidget {
  final FreightRfqDataModel rfq;

  const FreightRfqEmailTab({
    super.key,
    required this.rfq,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF9FAFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject Line Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Text('Subject: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                Expanded(
                  child: SelectableText(
                    rfq.emailSubject,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.cobalt),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: AppTheme.cobalt),
                  tooltip: l.freightRfqCopySubjectTooltip,
                  onPressed: () => FreightRfqGeneratorService.copyToClipboard(context, rfq.emailSubject, 'Subject'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Email Body Box
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  rfq.emailBodyTemplate,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
