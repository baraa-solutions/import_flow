import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/widgets/extraction_progress_dialog.dart';
import 'extracted_quotation_option_model.dart';

/// Data class holding the results of a quotation extraction operation.
class QuotationsExtractionResult {
  final List<ExtractedQuotationOption> options;
  final Map<String, dynamic>? primaryMetadata;
  final Map<String, String> customFields;
  final double confidenceScore;
  final String? error;

  const QuotationsExtractionResult({
    this.options = const [],
    this.primaryMetadata,
    this.customFields = const {},
    this.confidenceScore = 1.0,
    this.error,
  });
}

/// Service handling API calls, OCR upload, and response processing for freight quotations extraction.
class QuotationsExtractionService {
  /// Extracts quotation options from raw pasted text.
  static Future<QuotationsExtractionResult> extractFromText({
    required BuildContext context,
    required Dio dio,
    required String text,
    required bool isArabic,
  }) async {
    final progressCtrl = ExtractionProgressController();
    progressCtrl.update(
      percent: 0.20,
      status: isArabic
          ? 'جاري فحص وتحليل نصوص عروض الشحن والنولون...'
          : 'Analyzing freight quotation text...',
      stepLabel: isArabic
          ? 'المرحلة 1 من 4: تحليل النص الذكي'
          : 'Phase 1 of 4: Smart Text Analysis',
      currentStep: 1,
    );

    ExtractionProgressDialog.show(
      context: context,
      title: isArabic
          ? 'استخراج وتدقيق عروض أسعار الشحن من النص'
          : 'Extract & Verify Freight Quotations from Text',
      fileName: isArabic ? 'النص المنسوخ (${text.length} حرف)' : 'Copied Text (${text.length} chars)',
      controller: progressCtrl,
    );

    progressCtrl.startAutoAdvance(targetPercent: 0.90, duration: const Duration(seconds: 2));

    try {
      final response = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/parse-text/freight-quotation',
        data: FormData.fromMap({
          'raw_text': text,
          'save_session': false,
        }),
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      return processResponse(response.data, isArabic: isArabic);
    } on DioException catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return QuotationsExtractionResult(
        error: isArabic ? 'خطأ في الاتصال بالخادم: ${e.message}' : 'Connection error: ${e.message}',
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return QuotationsExtractionResult(
        error: isArabic ? 'حدث خطأ أثناء الاستخراج: $e' : 'Extraction error: $e',
      );
    }
  }

  /// Extracts quotation options from uploaded document or image using OCR.
  static Future<QuotationsExtractionResult> extractFromFileOcr({
    required BuildContext context,
    required Dio dio,
    required PlatformFile file,
    required bool isArabic,
  }) async {
    final fileSizeFormatted = file.size > 1024 * 1024
        ? '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB'
        : '${(file.size / 1024).toStringAsFixed(1)} KB';

    final progressCtrl = ExtractionProgressController();
    progressCtrl.update(
      percent: 0.15,
      status: isArabic
          ? 'جاري رفع الملف وتهيئة الماسح الضوئي...'
          : 'Uploading file and preparing OCR scanner...',
      stepLabel: isArabic ? 'المرحلة 1 من 4: رفع الملف' : 'Phase 1 of 4: File Upload',
      currentStep: 1,
    );

    ExtractionProgressDialog.show(
      context: context,
      title: isArabic
          ? 'استخراج عروض أسعار الشحن بالماسح الضوئي'
          : 'Scan & Extract Freight Quotations (OCR)',
      fileName: file.name,
      fileSize: fileSizeFormatted,
      controller: progressCtrl,
    );

    try {
      final multipartFile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
      final formData = FormData.fromMap({
        'file': multipartFile,
        'module_name': 'freight-quotation',
        'save_session': false,
      });

      final response = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/upload',
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final uploadRatio = sent / total;
            final p = 0.15 + (uploadRatio * 0.35);
            progressCtrl.update(
              percent: p,
              status: isArabic
                  ? 'جاري رفع الملف (${(uploadRatio * 100).round()}%)...'
                  : 'Uploading file (${(uploadRatio * 100).round()}%)...',
              stepLabel: isArabic ? 'المرحلة 2 من 4: رفع الملف' : 'Phase 2 of 4: File Upload',
              currentStep: 2,
            );
            if (uploadRatio >= 0.99) {
              progressCtrl.startAutoAdvance(targetPercent: 0.92, duration: const Duration(seconds: 5));
            }
          }
        },
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      return processResponse(response.data, isArabic: isArabic);
    } on DioException catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return QuotationsExtractionResult(
        error: isArabic
            ? 'خطأ في معالجة الملف بالماسح الضوئي: ${e.message}'
            : 'OCR document processing error: ${e.message}',
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return QuotationsExtractionResult(
        error: isArabic ? 'حدث خطأ أثناء معالجة المستند: $e' : 'Document processing error: $e',
      );
    }
  }

  /// Processes raw response payload from smart upload service.
  static QuotationsExtractionResult processResponse(dynamic data, {required bool isArabic}) {
    if (data == null) {
      return const QuotationsExtractionResult();
    }
    final extracted = (data['extracted_fields'] as Map<String, dynamic>?) ?? {};
    final rawRateOptions = (extracted['rate_options'] as List<dynamic>?) ?? [];
    final score = (data['confidence_score'] as num?)?.toDouble() ?? 1.0;

    final List<ExtractedQuotationOption> parsedList = [];

    if (rawRateOptions.isNotEmpty) {
      for (int i = 0; i < rawRateOptions.length; i++) {
        final optMap = rawRateOptions[i] as Map<String, dynamic>;
        parsedList.add(ExtractedQuotationOption.fromMap(optMap, i + 1));
      }
    } else if (extracted['freight_rate'] != null || extracted['ocean_freight'] != null) {
      parsedList.add(ExtractedQuotationOption.fromMap(extracted, 1));
    }

    final Map<String, String> cFields = {};
    final additionalExpenses = (extracted['additional_expenses'] as List<dynamic>?) ?? [];
    for (final item in additionalExpenses) {
      if (item is Map<String, dynamic>) {
        final lbl = (item['label'] ?? item['raw_label'] ?? (isArabic ? 'مصروف إضافي' : 'Additional Expense')).toString();
        final val = (item['formatted_value'] ?? 'USD ${item['amount']}').toString();
        cFields[lbl] = val;
      }
    }

    if (extracted['cancel_fee'] != null) {
      final cancelLabel = isArabic ? 'رسوم الإلغاء' : 'Cancellation Fee';
      cFields[cancelLabel] = 'USD ${extracted['cancel_fee']}';
    }

    String? error;
    if (parsedList.isEmpty) {
      error = isArabic
          ? 'لم يتم العثور على أية عروض أسعار صالحة في النص أو المستند المدخل. يرجى التحقق من الصيغة.'
          : 'No valid quotation options found in input text or document. Please check the format.';
    }

    return QuotationsExtractionResult(
      options: parsedList,
      primaryMetadata: extracted,
      customFields: cFields,
      confidenceScore: score,
      error: error,
    );
  }
}
