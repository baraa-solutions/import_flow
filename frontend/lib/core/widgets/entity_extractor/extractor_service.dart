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

      if (resp.statusCode == 200 && resp.data != null) {
        final extracted = resp.data['extracted_fields'] as Map<String, dynamic>? ?? {};
        final score = (resp.data['confidence_score'] as num?)?.toDouble() ?? 0.85;
        controllers.populateFields(extracted, score);
        onExtracted();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ في استخراج البيانات: $e' : 'Extraction Error: $e'),
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
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'bmp', 'tiff', 'xlsx', 'xls', 'docx', 'doc', 'txt'],
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

      if (resp.statusCode == 200 && resp.data != null) {
        final extracted = resp.data['extracted_fields'] as Map<String, dynamic>? ?? {};
        final score = (resp.data['confidence_score'] as num?)?.toDouble() ?? 0.90;
        controllers.populateFields(extracted, score);
        onExtracted();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ في معالجة واستخراج الملف: $e' : 'File Processing Error: $e'),
            backgroundColor: AppTheme.crimson,
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
