import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/smart_upload_button.dart';
import '../../po_form_dialog.dart';

/// Smart upload banner for automatic extraction of packing lists.
class PackingUploadBanner extends StatelessWidget {
  final POFormDialogState dialog;
  final bool isArabic;

  const PackingUploadBanner({
    super.key,
    required this.dialog,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.emeraldLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.emeraldBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppTheme.emerald, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'أداة قراءة واستخراج بيان التعبئة والوزن' : 'Packing List Reader',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                ),
                Text(
                  isArabic
                      ? 'قم برفع ملف بيان التعبئة لاستخراج أعداد الطرود والأوزان والأحجام تلقائياً'
                      : 'Upload packing list to extract packages count, weights and CBM volumes automatically',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SmartUploadButton(
            module: SmartUploadModule.packingList,
            compact: MediaQuery.sizeOf(context).width < 700,
            label: isArabic ? 'قراءة بيان التعبئة' : 'Read Packing List',
            onDataExtracted: (result) {
              dialog.applyExtractedFields(result.extractedFields, targetTab: 'packing');
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(
                  context,
                  isArabic ? 'تمت قراءة بيان التعبئة بنجاح' : 'Packing list extracted successfully',
                  severity: AppSeverity.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
