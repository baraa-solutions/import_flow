import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/api_constants.dart';
import '../../network/api_client.dart';
import '../../theme/app_theme.dart';
import '../extraction_progress_dialog.dart';
import 'extractor_controllers.dart';
import 'extractor_types.dart';

class ExtractorService {
  /// File types the backend smart-upload endpoint accepts (bmp / tiff were offered before and always got 415).
  static const List<String> kExtractorAllowedExtensions = [
    'pdf', 'png', 'jpg', 'jpeg', 'webp', 'xlsx', 'xls', 'docx', 'doc', 'txt',
  ];

  /// User-facing error text: the backend `detail` (e.g. "no OCR engine installed") instead of a raw exception dump.
  static String describeExtractionError(Object error, {required bool isArabic}) {
    if (error is DioException) {
      final data = error.response?.data;
      final detail = data is Map ? data['detail'] : null;
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
      if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) {
        return isArabic ? 'تعذر الاتصال بالخادم. تأكد من تشغيل النظام ثم أعد المحاولة.' : 'Cannot reach the server. Please retry.';
      }
    }
    return isArabic ? 'خطأ في معالجة واستخراج البيانات: $error' : 'Extraction error: $error';
  }

  /// Number of recognized fields reported by the backend (`fields_found`), or null when not reported.
  static int? countFoundFields(Map<String, dynamic> data) {
    final found = data['fields_found'];
    return found is List ? found.length : null;
  }

  /// Short result message: how many fields were recognized and whether OCR was used.
  static String buildExtractionResultMessage(Map<String, dynamic> data, {required bool isArabic}) {
    final count = countFoundFields(data);
    final info = data['document_text_info'];
    final method = info is Map ? info['method']?.toString() : null;
    final usedOcr = method == 'ocr' || method == 'mixed';
    if (count == 0) {
      return isArabic
          ? 'لم يتم التعرف على أي حقل في المستند. راجع جودة الملف أو الصق النص يدوياً.'
          : 'No fields were recognized in this document. Check the file quality or paste the text instead.';
    }
    final countText = count == null ? '' : (isArabic ? 'تم التعرف على $count حقل' : '$count fields recognized');
    final ocrText = usedOcr ? (isArabic ? ' (عبر التعرف الضوئي OCR)' : ' (via OCR)') : '';
    return '$countText$ocrText';
  }

  static void _applyExtractionResponse({
    required BuildContext context,
    required ExtractorControllers controllers,
    required Map<String, dynamic> data,
    required double defaultScore,
    required bool isArabic,
  }) {
    final extracted = data['extracted_fields'] as Map<String, dynamic>? ?? {};
    final score = (data['confidence_score'] as num?)?.toDouble() ?? defaultScore;
    controllers.populateFields(extracted, score);

    final count = countFoundFields(data);
    if (count == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(buildExtractionResultMessage(data, isArabic: isArabic)),
        backgroundColor: count == 0 ? AppTheme.orange : AppTheme.emerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<void> extractFromRawText({
    required BuildContext context,
    required WidgetRef ref,
    required ExtractorControllers controllers,
    required EntityTarget target,
    required void Function(bool) setExtracting,
    required VoidCallback onExtracted,
  }) async {
    final text = controllers.rawTextCtrl.text.trim();
    if (text.isEmpty) return;

    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final progressCtrl = ExtractionProgressController();
    progressCtrl.update(
      percent: 0.15,
      status: isArabic ? 'جاري فحص النص وتحليل الحقول التخصصية...' : 'Analyzing text and extracting specialized fields...',
      stepLabel: isArabic ? 'المرحلة 1 من 4: تحليل النص' : 'Step 1 of 4: Text Analysis',
      currentStep: 1,
    );

    setExtracting(true);

    if (context.mounted) {
      ExtractionProgressDialog.show(
        context: context,
        title: isArabic
            ? 'جاري استخراج بيانات ${getTargetName(context, target)}'
            : 'Extracting ${getTargetName(context, target)} Profile',
        fileName: isArabic ? 'النص المنسوخ (${text.length} حرف)' : 'Pasted Text (${text.length} characters)',
        controller: progressCtrl,
      );
    }

    try {
      final dio = ref.read(uploadDioProvider);
      final formData = FormData.fromMap({'raw_text': text});
      final moduleName = getModuleForTarget(target);
      final resp = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/parse-text/$moduleName',
        data: formData,
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (resp.statusCode == 200 && resp.data != null && context.mounted) {
        _applyExtractionResponse(
          context: context,
          controllers: controllers,
          data: resp.data as Map<String, dynamic>,
          defaultScore: 0.85,
          isArabic: isArabic,
        );
        onExtracted();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeExtractionError(e, isArabic: isArabic)),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      setExtracting(false);
    }
  }

  static Future<void> pickAndExtractFile({
    required BuildContext context,
    required WidgetRef ref,
    required ExtractorControllers controllers,
    required EntityTarget target,
    required void Function(bool) setExtracting,
    required VoidCallback onExtracted,
  }) async {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        // Must match the backend whitelist (modules/smart_document_upload/validators.py ALLOWED_EXTENSIONS).
        allowedExtensions: kExtractorAllowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      controllers.selectedFileName = file.name;

      final progressCtrl = ExtractionProgressController();
      progressCtrl.update(
        percent: 0.2,
        status: isArabic ? 'جاري قراءة الملف ومعالجة المستند...' : 'Reading file and processing document...',
        stepLabel: isArabic ? 'المرحلة 1 من 4: قراءة المستند' : 'Step 1 of 4: Document Reading',
        currentStep: 1,
      );

      if (context.mounted) {
        ExtractionProgressDialog.show(
          context: context,
          title: isArabic
              ? 'جاري استخراج بيانات ${getTargetName(context, target)}'
              : 'Extracting ${getTargetName(context, target)} Profile',
          fileName: file.name,
          controller: progressCtrl,
        );
      }

      setExtracting(true);

      final dio = ref.read(uploadDioProvider);
      final moduleName = getModuleForTarget(target);
      FormData formData;

      if (file.bytes != null) {
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        });
      } else if (file.path != null) {
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path!, filename: file.name),
        });
      } else {
        throw Exception('Unable to read file content');
      }

      final resp = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/upload/$moduleName',
        data: formData,
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (resp.statusCode == 200 && resp.data != null && context.mounted) {
        _applyExtractionResponse(
          context: context,
          controllers: controllers,
          data: resp.data as Map<String, dynamic>,
          defaultScore: 0.90,
          isArabic: isArabic,
        );
        onExtracted();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeExtractionError(e, isArabic: isArabic)),
            backgroundColor: AppTheme.crimson,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      setExtracting(false);
    }
  }

  static Future<void> saveEntity({
    required BuildContext context,
    required WidgetRef ref,
    required ExtractorControllers controllers,
    required EntityTarget target,
    required GlobalKey<FormState> formKey,
    required void Function(bool) setSaving,
    VoidCallback? onSaved,
  }) async {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final name = controllers.companyNameCtrl.text.trim();
    final arabicName = controllers.arabicNameCtrl.text.trim();
    final effectiveName = name.isNotEmpty ? name : arabicName;

    if (formKey.currentState != null && !formKey.currentState!.validate()) {
      return;
    }

    if (effectiveName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'اسم الكيان أو الشركة مطلوب لإتمام الحفظ والتسجيل' : 'Entity / Company name is required.'),
          backgroundColor: AppTheme.orange,
        ),
      );
      return;
    }

    setSaving(true);
    try {
      final dio = ref.read(dioProvider);
      final payloadData = controllers.buildSavePayload(target, effectiveName);

      await dio.post(payloadData.endpoint, data: payloadData.payload);

      if (context.mounted) {
        setSaving(false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تم تكويد وحفظ ${getTargetName(context, target)} "$effectiveName" بنجاح'
                  : 'Successfully registered ${getTargetName(context, target)} "$effectiveName"',
            ),
            backgroundColor: AppTheme.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
        onSaved?.call();
      }
    } catch (e) {
      if (context.mounted) {
        setSaving(false);
        String msg = e.toString();
        if (e is DioException && e.response?.data != null) {
          msg = e.response?.data['detail']?.toString() ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ أثناء الحفظ: $msg' : 'Error saving record: $msg'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }
}
