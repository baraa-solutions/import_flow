import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'copyable_data_helper.dart';

/// Progress state notifier for AI / OCR extraction operations
class ExtractionProgressController extends ChangeNotifier {
  double _percent = 0.0;
  String _status = 'جاري تحضير الملف...';
  String _stepLabel = 'المرحلة 1 من 4: قراءة المستند';
  int _currentStep = 1;

  double get percent => _percent;
  int get percentInt => (_percent * 100).round().clamp(0, 100);
  String get status => _status;
  String get stepLabel => _stepLabel;
  int get currentStep => _currentStep;

  void update({
    required double percent,
    required String status,
    String? stepLabel,
    int? currentStep,
  }) {
    _percent = percent.clamp(0.0, 1.0);
    _status = status;
    if (stepLabel != null) _stepLabel = stepLabel;
    if (currentStep != null) _currentStep = currentStep;
    notifyListeners();
  }

  /// Automatically simulates smooth progress during backend processing
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
    _timer?.cancel();
    notifyListeners();
  }

  Timer? _timer;
  void startAutoAdvance({
    double targetPercent = 0.90,
    Duration duration = const Duration(seconds: 4),
    String? step4Status,
  }) {
    _timer?.cancel();
    const stepDuration = Duration(milliseconds: 150);
    final totalSteps = duration.inMilliseconds ~/ stepDuration.inMilliseconds;
    int stepCount = 0;

    _timer = Timer.periodic(stepDuration, (t) {
      stepCount++;
      if (_percent < targetPercent && stepCount <= totalSteps) {
        final stepIncrement = (targetPercent - _percent) / (totalSteps - stepCount + 1);
        _percent = (_percent + stepIncrement).clamp(0.0, targetPercent);
        
        if (_percent >= 0.20 && _percent < 0.50) {
          _currentStep = 2;
          _stepLabel = 'المرحلة 2 من 4: رفع الملف إلى محرك المعالجة';
          _status = 'جاري إرسال المستند ومعالجة الصفحات...';
        } else if (_percent >= 0.50 && _percent < 0.75) {
          _currentStep = 3;
          _stepLabel = 'المرحلة 3 من 4: التعرف الضوئي واستخراج الجداول';
          _status = 'جاري تحليل النصوص، أرقام البنود، والأسعار...';
        } else if (_percent >= 0.75) {
          _currentStep = 4;
          _stepLabel = 'المرحلة 4 من 4: استخراج الحقول والمطابقة الذكية';
          _status = step4Status ?? 'جاري استخراج بنود الفاتورة وكشف التعبئة وتنسيق البيانات...';
        }
        notifyListeners();
      } else if (_percent >= targetPercent) {
        t.cancel();
      }
    });
  }

  void complete() {
    _timer?.cancel();
    _percent = 1.0;
    _currentStep = 4;
    _stepLabel = 'اكتملت المعالجة بنجاح 100%';
    _status = 'تم استخراج كافة البيانات بنجاح وجاري عرض المعاينة!';
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Comprehensive 0% to 100% Extraction Progress Modal Dialog
class ExtractionProgressDialog extends StatelessWidget {
  final String title;
  final String? fileName;
  final String? fileSize;
  final ExtractionProgressController controller;
  final VoidCallback? onCancel;

  const ExtractionProgressDialog({
    super.key,
    required this.title,
    this.fileName,
    this.fileSize,
    required this.controller,
    this.onCancel,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? fileName,
    String? fileSize,
    required ExtractionProgressController controller,
    VoidCallback? onCancel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ExtractionProgressDialog(
        title: title,
        fileName: fileName,
        fileSize: fileSize,
        controller: controller,
        onCancel: onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pct = controller.percent;
        final pctInt = controller.percentInt;

        String activeStepLabel;
        String activeStatus;
        if (pctInt >= 100) {
          activeStepLabel = l.ocrCompleteSuccess;
          activeStatus = l.ocrCompleteSuccessDesc;
        } else if (controller.currentStep == 1) {
          activeStepLabel = l.ocrStepProgressLabel(1, 4, l.ocrStep1Reading);
          activeStatus = l.ocrAnalyzingText;
        } else if (controller.currentStep == 2) {
          activeStepLabel = l.ocrStepProgressLabel(2, 4, l.ocrStep2Upload);
          activeStatus = l.ocrSendingDoc;
        } else if (controller.currentStep == 3) {
          activeStepLabel = l.ocrStepProgressLabel(3, 4, l.ocrStep3Ocr);
          activeStatus = l.ocrAnalyzingText;
        } else {
          activeStepLabel = l.ocrStepProgressLabel(4, 4, l.ocrStep4Fields);
          activeStatus = l.ocrExtractingFields;
        }

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 12,
          child: SelectionArea(
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeStepLabel,
                              style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: pctInt == 100 ? AppTheme.emerald : AppTheme.cobalt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$pctInt%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                        tooltip: l.closeAndCancelExtractionTooltip,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          controller.cancel();
                          onCancel?.call();
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // File metadata badge
                  if (fileName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName!,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                            tooltip: l.copyTooltip,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => CopyHelper.copy(context, fileName!),
                          ),
                          if (fileSize != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              fileSize!,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),

                // Animated Progress Bar (0% -> 100%)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 12,
                    child: LinearProgressIndicator(
                      value: pct > 0 ? pct : null,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pctInt >= 100 ? AppTheme.emerald : AppTheme.cobalt,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Live status text
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: pctInt >= 100
                          ? const Icon(Icons.check_circle, color: AppTheme.emerald, size: 16)
                          : const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cobalt),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activeStatus,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: pctInt >= 100 ? AppTheme.emerald : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 4-Step Visual Progress Stepper
                Row(
                  children: [
                    _buildStepIndicator(stepNum: 1, label: l.ocrStep1Reading, active: controller.currentStep >= 1, done: controller.currentStep > 1 || pctInt == 100),
                    _buildStepLine(done: controller.currentStep > 1 || pctInt == 100),
                    _buildStepIndicator(stepNum: 2, label: l.ocrStep2Upload, active: controller.currentStep >= 2, done: controller.currentStep > 2 || pctInt == 100),
                    _buildStepLine(done: controller.currentStep > 2 || pctInt == 100),
                    _buildStepIndicator(stepNum: 3, label: l.ocrStep3Ocr, active: controller.currentStep >= 3, done: controller.currentStep > 3 || pctInt == 100),
                    _buildStepLine(done: controller.currentStep > 3 || pctInt == 100),
                    _buildStepIndicator(stepNum: 4, label: l.ocrStep4Fields, active: controller.currentStep >= 4, done: pctInt == 100),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.crimson),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: Text(l.cancelAndCloseExtractor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        controller.cancel();
                        onCancel?.call();
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildStepIndicator({required int stepNum, required String label, required bool active, required bool done}) {
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade600;
    if (done) {
      bg = AppTheme.emerald;
      fg = Colors.white;
    } else if (active) {
      bg = AppTheme.cobalt;
      fg = Colors.white;
    }

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: bg,
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('$stepNum', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? AppTheme.charcoal : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine({required bool done}) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: done ? AppTheme.emerald : Colors.grey.shade300,
    );
  }
}
