import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/freight_rfq_generator_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/import_file_model.dart';

/// WhatsApp template tab for FreightRfqDialog
class FreightRfqWhatsAppTab extends StatelessWidget {
  final FreightRfqDataModel rfq;

  const FreightRfqWhatsAppTab({
    super.key,
    required this.rfq,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF0FDF4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WhatsApp Bubble Preview
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  rfq.whatsappTextTemplate,
                  style: const TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xFF0F172A)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info & Quick Action Panel
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l.freightRfqWhatsappFeatures,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('• ${l.freightRfqWhatsappFeature1}', style: const TextStyle(fontSize: 12)),
                      Text('• ${l.freightRfqWhatsappFeature2}', style: const TextStyle(fontSize: 12)),
                      Text('• ${l.freightRfqWhatsappFeature3}', style: const TextStyle(fontSize: 12)),
                      Text('• ${l.freightRfqWhatsappFeature4}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(l.freightRfqCopyWhatsappBtn),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cobalt,
                            side: const BorderSide(color: AppTheme.cobalt),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => FreightRfqGeneratorService.copyToClipboard(
                            context,
                            rfq.whatsappTextTemplate,
                            'WhatsApp',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
