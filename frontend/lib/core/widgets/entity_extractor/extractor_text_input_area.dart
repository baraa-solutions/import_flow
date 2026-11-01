import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buttons/app_button.dart';
import 'extractor_types.dart';

class ExtractorRawTextInput extends StatelessWidget {
  final TextEditingController controller;
  final EntityTarget target;

  const ExtractorRawTextInput({
    super.key,
    required this.controller,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Column(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: getPlaceholderForTarget(target, isArabic),
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }
}

class ExtractorFileUploadArea extends StatelessWidget {
  final String? selectedFileName;
  final bool isExtracting;
  final VoidCallback onPickFile;

  const ExtractorFileUploadArea({
    super.key,
    required this.selectedFileName,
    required this.isExtracting,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return InkWell(
      onTap: isExtracting ? null : onPickFile,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.4), style: BorderStyle.solid),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.cobalt),
            const SizedBox(height: 12),
            Text(
              selectedFileName ?? (isArabic ? 'اضغط لاختيار ملف أو سحب مستند الفاتورة أو الكارت' : 'Click to select file or drag document / business card'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selectedFileName != null ? AppTheme.charcoal : Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isArabic ? 'يدعم ملفات: المستندات والصور والجداول الإلكترونية' : 'Supported formats: PDF, Images (PNG/JPG), Excel, Word',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class ExtractorSmartExtractButton extends StatelessWidget {
  final bool isExtracting;
  final VoidCallback? onExtract;

  const ExtractorSmartExtractButton({
    super.key,
    required this.isExtracting,
    required this.onExtract,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final label = isExtracting
        ? (isArabic ? 'جاري التحليل والاستخراج...' : 'Analyzing & Extracting Data...')
        : (isArabic ? 'استخراج وتحليل البيانات تلقائياً ✨' : 'Smart Extract & Auto-Analyze ✨');

    return SizedBox(
      width: double.infinity,
      height: 42,
      child: AppButton(
        label: label,
        icon: Icons.auto_awesome,
        variant: AppButtonVariant.primary,
        isLoading: isExtracting,
        onPressed: isExtracting ? null : onExtract,
      ),
    );
  }
}

class ExtractorSaveButton extends StatelessWidget {
  final EntityTarget target;
  final bool isSaving;
  final bool isExtracting;
  final VoidCallback? onSave;

  const ExtractorSaveButton({
    super.key,
    required this.target,
    required this.isSaving,
    required this.isExtracting,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final label = isArabic
        ? 'حفظ وتكويد ${getTargetName(context, target)} في قاعدة البيانات 💾'
        : 'Save & Register ${getTargetName(context, target)} in Database 💾';

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: AppButton(
        label: label,
        icon: Icons.check_circle_rounded,
        variant: AppButtonVariant.success,
        isLoading: isSaving,
        onPressed: (isSaving || isExtracting) ? null : onSave,
      ),
    );
  }
}
