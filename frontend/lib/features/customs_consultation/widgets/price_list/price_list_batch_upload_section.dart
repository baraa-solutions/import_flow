import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../extraction_summary_dialog.dart';
import 'price_list_match_helper.dart';

/// Batch upload and AI document extraction section for broker price lists.
class PriceListBatchUploadSection extends StatelessWidget {
  final WidgetRef ref;
  final List<Map<String, dynamic>> currentItemsState;
  final void Function(Map<String, dynamic> extracted) onExtractionConfirmed;

  const PriceListBatchUploadSection({
    super.key,
    required this.ref,
    required this.currentItemsState,
    required this.onExtractionConfirmed,
  });

  Future<void> _extractFromDocument(BuildContext context) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'png', 'jpg', 'jpeg', 'webp', 'xlsx', 'xls', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
      final file = result.files.first;

      final fileSizeFormatted = file.size > 1024 * 1024
          ? '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB'
          : '${(file.size / 1024).toStringAsFixed(1)} KB';

      final progressCtrl = ExtractionProgressController();
      progressCtrl.update(
        percent: 0.20,
        status: isAr ? 'جاري قراءة وتصنيف مقايسة التخليص بالذكاء الاصطناعي...' : 'Reading quotation with AI...',
        stepLabel: isAr ? 'المرحلة 1 من 3: فحص المستند' : 'Step 1 of 3: Document check',
        currentStep: 1,
      );

      if (!context.mounted) return;
      ExtractionProgressDialog.show(
        context: context,
        title: isAr ? 'استخراج وتصنيف مقايسة التخليص الجمركي' : 'Extract customs quotation items',
        fileName: file.name,
        fileSize: fileSizeFormatted,
        controller: progressCtrl,
      );

      final dio = ref.read(uploadDioProvider);
      final multipartFile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
      final formData = FormData.fromMap({
        'file': multipartFile,
        'module_name': 'clearance-quotation',
        'save_session': false,
      });

      final response = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/upload',
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 120)),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final ratio = sent / total;
            progressCtrl.update(
              percent: 0.20 + (ratio * 0.40),
              status: isAr ? 'جاري رفع الملف: ${(ratio * 100).round()}%...' : 'Uploading file: ${(ratio * 100).round()}%...',
              stepLabel: isAr ? 'المرحلة 2 من 4: معالجة البيانات' : 'Step 2 of 4: Data processing',
              currentStep: 2,
            );
            if (ratio >= 0.99) {
              progressCtrl.startAutoAdvance(
                targetPercent: 0.92,
                duration: const Duration(seconds: 4),
                step4Status: isAr
                    ? 'جاري استخراج أتعاب ومصروفات مقايسة التخليص والنقل وتنسيق البيانات...'
                    : 'Extracting quotation fees and inland transport expenses...',
              );
            }
          }
        },
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.data != null) {
        final extracted = (response.data['extracted_fields'] as Map<String, dynamic>?) ?? {};
        final expensesCatalog = (extracted['expenses_catalog'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        final List<ExtractedSummaryItem> summaryItems = [];

        for (final extItem in expensesCatalog) {
          final rawName = ((extItem['item_name'] ?? extItem['expense_name']) as String? ?? '').trim();
          final price = ((extItem['price'] ?? extItem['amount']) as num?)?.toDouble() ?? 0.0;
          if (price <= 0 && rawName.isEmpty) continue;

          int bestScore = 0;
          String? matchedCanonical;
          String? matchedCode = extItem['code']?.toString();

          for (final itm in currentItemsState) {
            final name = (itm['expense_name'] as String? ?? '').trim();
            final score = calculateMatchScore(name, rawName);
            if (score > bestScore) {
              bestScore = score;
              matchedCanonical = name;
              if (itm['code'] != null && (matchedCode == null || matchedCode.isEmpty)) {
                matchedCode = itm['code']?.toString();
              }
            }
          }

          final double conf = (extItem['confidence'] as num?)?.toDouble() ??
              (bestScore > 0 ? bestScore.toDouble() : 50.0);
          final bool isUncoded = extItem['is_uncoded'] == true || (matchedCode == null && conf < 60);

          summaryItems.add(ExtractedSummaryItem(
            rawName: rawName,
            matchedCanonicalName: bestScore >= 80 ? matchedCanonical : null,
            code: matchedCode,
            category: (extItem['category']?.toString() ?? 'Other Fees').split('(').first.trim(),
            unitType: (((extItem['pricing_unit'] ?? extItem['unit_type'])?.toString()) ?? 'Per Shipment')
                .split('(')
                .first
                .trim(),
            price: price,
            currency: extItem['currency']?.toString() ?? 'EGP',
            confidence: conf,
            isUncoded: isUncoded,
            notes: extItem['notes']?.toString(),
          ));
        }

        final cFee = (extracted['clearance_fee'] as num?)?.toDouble();
        if (cFee != null && cFee > 0 && !summaryItems.any((s) => s.rawName.contains('تخليص'))) {
          summaryItems.add(const ExtractedSummaryItem(
            rawName: 'أتعاب تخليص جمركي',
            matchedCanonicalName: 'أتعاب تخليص حاوية 40 قدم',
            code: 'CLR-40FT-FEE',
            category: 'Clearance Fees',
            unitType: 'Per Shipment',
            price: 2500.0,
            currency: 'EGP',
            confidence: 90.0,
            isUncoded: false,
          ));
        }
        final inlandFee = (extracted['inland_transport_fee'] as num?)?.toDouble();
        if (inlandFee != null && inlandFee > 0 && !summaryItems.any((s) => s.rawName.contains('نقل') || s.rawName.contains('شاحنة'))) {
          summaryItems.add(ExtractedSummaryItem(
            rawName: 'نقل داخلي',
            matchedCanonicalName: 'حاوية 40 قدم إسكندرية - قاهرة',
            code: 'INL-40FT-CAI',
            category: 'Inland Transport',
            unitType: 'Per Truck',
            price: inlandFee,
            currency: 'EGP',
            confidence: 90.0,
            isUncoded: false,
          ));
        }

        if (!context.mounted) return;

        final bool? shouldApply = await ExtractionSummaryDialog.show(
          context: context,
          fileName: file.name,
          brokerName: extracted['broker_name']?.toString(),
          portName: extracted['port_name']?.toString(),
          title: extracted['title']?.toString(),
          items: summaryItems,
        );

        if (shouldApply == true) {
          onExtractionConfirmed(extracted);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(
                context,
                isAr
                    ? 'تم استخراج وتصنيف بنود المقايسة وتعبئة النموذج بنجاح'
                    : 'Quotation items extracted and form populated successfully',
                severity: AppSeverity.success,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            '${isAr ? "خطأ أثناء الاستخراج" : "Extraction error"}: ${ApiErrorText.of(l, e)}',
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppButton(
      label: l.smartFileExtractionBtn,
      icon: Icons.auto_awesome,
      variant: AppButtonVariant.primary,
      size: AppButtonSize.small,
      onPressed: () => _extractFromDocument(context),
    );
  }
}
