import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/inspection_appeal_model.dart';
import '../services/inspection_appeal_service.dart';

class InspectionAppealsDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const InspectionAppealsDialog({super.key, this.initialImportFileId});

  static Future<void> show(BuildContext context, {int? initialImportFileId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => InspectionAppealsDialog(initialImportFileId: initialImportFileId),
    );
  }

  @override
  ConsumerState<InspectionAppealsDialog> createState() => _InspectionAppealsDialogState();
}

class _InspectionAppealsDialogState extends ConsumerState<InspectionAppealsDialog> {
  List<InspectionAppealModel> _appeals = [];
  bool _isLoading = false;
  String _selectedAuthority = 'All';
  String _selectedTier = 'All';
  String _selectedResult = 'All';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(inspectionAppealServiceProvider);
      final list = await service.listAppeals(
        importFileId: widget.initialImportFileId,
        regulatoryAuthority: _selectedAuthority,
        appealTier: _selectedTier,
        appealResult: _selectedResult,
      );

      if (mounted) {
        setState(() {
          _appeals = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  AppSeverity _tierSeverity(AppealTier tier) {
    switch (tier) {
      case AppealTier.firstAppeal:
        return AppSeverity.info;
      case AppealTier.secondAppeal:
        return AppSeverity.warning;
      case AppealTier.triplicateSample:
        return AppSeverity.danger;
    }
  }

  AppSeverity _resultSeverity(AppealResult res) {
    switch (res) {
      case AppealResult.overturnedConforming:
        return AppSeverity.success;
      case AppealResult.upheldRejected:
        return AppSeverity.danger;
      case AppealResult.pending:
        return AppSeverity.warning;
    }
  }

  void _showNewAppealDialog() {
    final fileIdController = TextEditingController(text: widget.initialImportFileId?.toString() ?? '');
    String authority = 'GOEIC';
    String initialResult = 'NON_CONFORMING_CHEMICAL';
    final sampleNoController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.biotech_outlined, color: AppTheme.cobalt),
              SizedBox(width: 8),
              Text('تقديم تظلم معملي جديد على نتيجة الفحص'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    label: 'معرف الملف الاستيرادي (Import File ID)',
                    controller: fileIdController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  const Text('الجهة الرقابية المختصة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: authority,
                    items: const [
                      DropdownMenuItem(value: 'GOEIC', child: Text('الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)')),
                      DropdownMenuItem(value: 'NFSA', child: Text('الهيئة القومية لسلامة الغذاء (NFSA)')),
                      DropdownMenuItem(value: 'EDA', child: Text('هيئة الدواء المصرية (EDA)')),
                      DropdownMenuItem(value: 'NTRA', child: Text('الجهاز القومي لتنظيم الاتصالات (NTRA)')),
                      DropdownMenuItem(value: 'ATOMIC_ENERGY', child: Text('هيئة الطاقة الذرية')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => authority = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'رقم العينة المعملية المسحوبة',
                          controller: sampleNoController,
                          hint: 'SMP-2026-9876',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('نوع عدم المطابقة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: initialResult,
                              items: const [
                                DropdownMenuItem(value: 'NON_CONFORMING_CHEMICAL', child: Text('غير مطابق كيميائياً')),
                                DropdownMenuItem(value: 'NON_CONFORMING_MICROBIAL', child: Text('غير مطابق ميكروبياً')),
                                DropdownMenuItem(value: 'NON_CONFORMING_VISUAL', child: Text('غير مطابق ظاهرياً')),
                              ],
                              onChanged: (v) {
                                if (v != null) setDlgState(() => initialResult = v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'أسباب ومبررات التظلم الفنية',
                    controller: reasonController,
                    maxLines: 2,
                    hint: 'طلب إعادة التحليل بمعمل مرجعي معتمد أو فحص العينة المحفوظة...',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'قيد التظلم رسمياً',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final fid = int.tryParse(fileIdController.text.trim());
                if (fid == null || reasonController.text.trim().isEmpty) {
                  AppTheme.snackBar(ctx, 'يرجى إدخال رقم الملف وأسباب التظلم', severity: AppSeverity.warning);
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  final service = ref.read(inspectionAppealServiceProvider);
                  await service.createAppeal(
                    importFileId: fid,
                    regulatoryAuthority: authority,
                    sampleNumber: sampleNoController.text.trim().isNotEmpty ? sampleNoController.text.trim() : null,
                    initialTestResult: initialResult,
                    rejectionReason: reasonController.text.trim(),
                    appealSubmissionDate: DateTime.now().toIso8601String(),
                  );
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'تم قيد التظلم المعملي رسمياً وإخطار اللجنة المختصة', severity: AppSeverity.success);
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'فشل في قيد التظلم: $e', severity: AppSeverity.danger);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDecisionDialog(InspectionAppealModel item) {
    String decision = 'OVERTURNED_CONFORMING';
    final letterController = TextEditingController(text: item.officialLetterRef ?? '');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Text('تسجيل قرار لجنة التظلمات — ${item.appealCode}'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('قرار اللجنة النهائي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: decision,
                  items: const [
                    DropdownMenuItem(
                      value: 'OVERTURNED_CONFORMING',
                      child: Text('قبول التظلم وإلغاء الرفض (مطابق للإفراج 🟢)'),
                    ),
                    DropdownMenuItem(
                      value: 'UPHELD_REJECTED',
                      child: Text('تأييد قرار الرفض (إحالة لإعادة التصدير 🔴)'),
                    ),
                    DropdownMenuItem(
                      value: 'PENDING',
                      child: Text('استمرار الفحص والمراجعة (معلق 🟡)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => decision = v);
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'رقم الخطاب / القرار الرسمي الصادر',
                  controller: letterController,
                  hint: 'قرار رقم 104 لسنة 2026',
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'حيثيات وملاحظات القرار',
                  controller: notesController,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'حفظ القرار',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  final service = ref.read(inspectionAppealServiceProvider);
                  await service.recordCommitteeDecision(
                    item.appealId,
                    appealResult: decision,
                    appealCommitteeDate: DateTime.now().toIso8601String(),
                    officialLetterRef: letterController.text.trim().isNotEmpty ? letterController.text.trim() : null,
                    notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                  );
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'تم اعتماد وتوثيق قرار لجنة التظلمات بنجاح', severity: AppSeverity.success);
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'فشل في حفظ القرار: $e', severity: AppSeverity.danger);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProgressTierDialog(InspectionAppealModel item) {
    String nextTier = item.appealTier == AppealTier.firstAppeal ? 'SECOND_APPEAL' : 'TRIPLICATE_SAMPLE';
    final labController = TextEditingController();
    final refController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Text('تصعيد التظلم إلى مرحلة أعلى — ${item.appealCode}'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المرحلة المستهدفة بالتصعيد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: nextTier,
                  items: const [
                    DropdownMenuItem(value: 'SECOND_APPEAL', child: Text('التظلم الثاني (لجنة الخبراء)')),
                    DropdownMenuItem(value: 'TRIPLICATE_SAMPLE', child: Text('التحكيم الثلاثي (العينة المرجعية المحفوظة)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => nextTier = v);
                  },
                ),
                if (nextTier == 'TRIPLICATE_SAMPLE') ...[
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'اسم المعمل المحايد المعتمد للتحكيم',
                    controller: labController,
                    hint: 'المعمل المركزي لجامعة القاهرة، معمل البتروكيماويات...',
                  ),
                ],
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'رقم خطاب طلب التصعيد',
                  controller: refController,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'مبررات التصعيد',
                  controller: notesController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'تأكيد التصعيد',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  final service = ref.read(inspectionAppealServiceProvider);
                  await service.progressTier(
                    item.appealId,
                    targetTier: nextTier,
                    triplicateLabAssigned: labController.text.trim().isNotEmpty ? labController.text.trim() : null,
                    officialLetterRef: refController.text.trim().isNotEmpty ? refController.text.trim() : null,
                    notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                  );
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'تم تصعيد التظلم إلى المرحلة التالية بنجاح', severity: AppSeverity.success);
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'فشل في تصعيد التظلم: $e', severity: AppSeverity.danger);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 1100,
        height: 740,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.biotech_rounded, color: AppTheme.cobalt, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تظلمات الفحص المعملي والتحكيم الثلاثي (Inspection & Lab Appeals)',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'إدارة دورة التظلم المعملي، لجان الخبراء، وتحكيم العينات الثلاثية لدى الهيئات الرقابية (GOEIC / NFSA / EDA)',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: 'تقديم تظلم معملي',
                    icon: Icons.add_circle_outline,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: _showNewAppealDialog,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('الجهة الرقابية: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    DropdownButton<String>(
                      value: _selectedAuthority,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('كافة الجهات')),
                        DropdownMenuItem(value: 'GOEIC', child: Text('صادرات وواردات (GOEIC)')),
                        DropdownMenuItem(value: 'NFSA', child: Text('سلامة الغذاء (NFSA)')),
                        DropdownMenuItem(value: 'EDA', child: Text('هيئة الدواء (EDA)')),
                        DropdownMenuItem(value: 'NTRA', child: Text('تنظيم الاتصالات (NTRA)')),
                        DropdownMenuItem(value: 'ATOMIC_ENERGY', child: Text('طاقة ذرية')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedAuthority = val);
                          _loadData();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    const Text('المرحلة: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    DropdownButton<String>(
                      value: _selectedTier,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('كافة المراحل')),
                        DropdownMenuItem(value: 'FIRST_APPEAL', child: Text('التظلم الأول')),
                        DropdownMenuItem(value: 'SECOND_APPEAL', child: Text('التظلم الثاني')),
                        DropdownMenuItem(value: 'TRIPLICATE_SAMPLE', child: Text('التحكيم الثلاثي')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedTier = val);
                          _loadData();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    const Text('النتيجة: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    DropdownButton<String>(
                      value: _selectedResult,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('كافة النتائج')),
                        DropdownMenuItem(value: 'PENDING', child: Text('🟡 قيد النظر')),
                        DropdownMenuItem(value: 'OVERTURNED_CONFORMING', child: Text('🟢 مطابق (تم القبول)')),
                        DropdownMenuItem(value: 'UPHELD_REJECTED', child: Text('🔴 مرفوض (تأييد الرفض)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedResult = val);
                          _loadData();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'تحديث القائمة',
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text('خطأ: $_errorMessage', style: const TextStyle(color: AppTheme.crimson)))
                      : _appeals.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 54, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  const Text('لا توجد تظلمات معملية مسجلة حالياً', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            )
                          : SelectionArea(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _appeals.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = _appeals[idx];

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Left Icon
                                        Container(
                                          width: 70,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.biotech_rounded, color: AppTheme.cobalt, size: 28),
                                        ),
                                        const SizedBox(width: 14),

                                        // Main Appeal Details
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    item.appealCode,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cobalt),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(4)),
                                                    child: Text(item.regulatoryAuthority, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  AppStatusBadge(
                                                    label: item.appealTier.labelAr,
                                                    severity: _tierSeverity(item.appealTier),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  AppStatusBadge(
                                                    label: item.appealResult.labelAr,
                                                    severity: _resultSeverity(item.appealResult),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'ملف استيرادي: IMP-${item.importFileId} | رقم العينة: ${item.sampleNumber ?? "غير محدد"} | نتيجة الفحص المبدئي: ${item.initialTestResult}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              ),
                                              if (item.rejectionReason != null)
                                                Text(
                                                  'أسباب التظلم: ${item.rejectionReason}',
                                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              if (item.triplicateLabAssigned != null)
                                                Text(
                                                  'المعمل المحايد المعتمد للتحكيم: ${item.triplicateLabAssigned}',
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Action Buttons
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AppButton(
                                              label: 'قرار اللجنة',
                                              icon: Icons.gavel_rounded,
                                              variant: AppButtonVariant.primary,
                                              size: AppButtonSize.small,
                                              onPressed: () => _showDecisionDialog(item),
                                            ),
                                            const SizedBox(width: 6),
                                            if (item.appealTier != AppealTier.triplicateSample)
                                              AppButton(
                                                label: 'تصعيد التظلم',
                                                icon: Icons.arrow_upward_rounded,
                                                variant: AppButtonVariant.secondary,
                                                size: AppButtonSize.small,
                                                onPressed: () => _showProgressTierDialog(item),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
