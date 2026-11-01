import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/cargox_model.dart';
import '../../services/cargox_pdf_service.dart';

/// PDF Preview and print modal for Customs Track Commercial Invoice & Packing List.
class CustomsTrackPdfPreviewDialog extends StatefulWidget {
  final CustomsInvoiceTrackModel track;

  const CustomsTrackPdfPreviewDialog({super.key, required this.track});

  static void show(BuildContext context, CustomsInvoiceTrackModel track) {
    showDialog(
      context: context,
      builder: (ctx) => CustomsTrackPdfPreviewDialog(track: track),
    );
  }

  @override
  State<CustomsTrackPdfPreviewDialog> createState() => _CustomsTrackPdfPreviewDialogState();
}

class _CustomsTrackPdfPreviewDialogState extends State<CustomsTrackPdfPreviewDialog> {
  bool _isInvoiceMode = true;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    Map<String, dynamic> invData = {};
    if (track.customsInvoiceData is Map) {
      invData = Map<String, dynamic>.from(track.customsInvoiceData as Map);
    } else if (track.customsInvoiceData is List && (track.customsInvoiceData as List).isNotEmpty) {
      invData = Map<String, dynamic>.from((track.customsInvoiceData as List).first as Map);
    }

    final payload = invData.isNotEmpty ? StandardInvoicePayloadModel.fromJson(invData) : StandardInvoicePayloadModel();
    final packData = (track.customsPackingListData is Map) ? Map<String, dynamic>.from(track.customsPackingListData as Map) : <String, dynamic>{};

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 900,
          height: 750,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: AppTheme.emerald, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '${isAr ? "معاينة وطباعة مستندات المسار الجمركي:" : "Customs Track Documents:"} ${track.trackCode}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                      ),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ChoiceChip(
                    label: Text(context.l10n.standardInvoiceTabTitle),
                    selected: _isInvoiceMode,
                    selectedColor: AppTheme.emerald.withValues(alpha: 0.2),
                    onSelected: (val) => setState(() => _isInvoiceMode = true),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: Text(context.l10n.standardInvoicePackingListTitle),
                    selected: !_isInvoiceMode,
                    selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                    onSelected: (val) => setState(() => _isInvoiceMode = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: PdfPreview(
                  build: (format) => _isInvoiceMode
                      ? CargoXPdfService.generateCustomsInvoicePdf(track: track, payload: payload)
                      : CargoXPdfService.generateCustomsPackingListPdf(track: track, packingListData: packData),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  pdfFileName: _isInvoiceMode ? 'Customs_Invoice_${track.trackCode}.pdf' : 'Customs_Packing_List_${track.trackCode}.pdf',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
