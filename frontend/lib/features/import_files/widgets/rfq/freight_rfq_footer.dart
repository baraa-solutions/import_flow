import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/freight_rfq_generator_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/import_file_model.dart';

/// Footer bar with Print PDF, Copy Email, and Close buttons for FreightRfqDialog
class FreightRfqFooter extends StatelessWidget {
  final FreightRfqDataModel? rfq;
  final TextEditingController recipientController;
  final VoidCallback onClose;

  const FreightRfqFooter({
    super.key,
    required this.rfq,
    required this.recipientController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = rfq;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(12),
          bottomEnd: Radius.circular(12),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          if (data != null) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: Text(l.freightRfqPrintPdfBtn),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.crimson,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                final pdfBytes = await FreightRfqGeneratorService.generateFreightRfqPdf(
                  rfq: data,
                  recipientName: recipientController.text,
                );
                if (context.mounted) {
                  await FreightRfqGeneratorService.printOrSavePdf(
                    context,
                    pdfBytes,
                    data.customFileNumber ?? data.importFileCode,
                  );
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l.freightRfqCopyEmailBtn),
              onPressed: () => FreightRfqGeneratorService.copyToClipboard(
                context,
                data.emailBodyTemplate,
                'Email',
              ),
            ),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.crimson,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
            label: Text(l.freightRfqCloseDismissBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
