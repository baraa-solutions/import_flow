import '../../../core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/customs_abandonment_model.dart';
import '../services/customs_abandonment_service.dart';

class CustomsAbandonmentRadarDialog extends ConsumerStatefulWidget {
  const CustomsAbandonmentRadarDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const CustomsAbandonmentRadarDialog(),
    );
  }

  @override
  ConsumerState<CustomsAbandonmentRadarDialog> createState() => _CustomsAbandonmentRadarDialogState();
}

class _CustomsAbandonmentRadarDialogState extends ConsumerState<CustomsAbandonmentRadarDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<CustomsAbandonmentRadarModel> _records = [];
  CustomsAbandonmentSummaryModel? _summary;
  bool _isLoading = false;
  String _selectedRisk = 'All';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final service = ref.read(customsAbandonmentServiceProvider);
      final list = await service.listRadars(
        riskLevel: _selectedRisk,
        search: _searchController.text.trim(),
      );
      final sum = await service.getSummary();
      if (mounted) {
        setState(() {
          _records = list;
          _summary = sum;
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

  Future<void> _triggerRecalculate() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(customsAbandonmentServiceProvider);
      await service.recalculate();
      if (!mounted) return;
      AppTheme.snackBar(context, 'تمت إعادة تقييم مدد المهمل الجمركي بنجاح', severity: AppSeverity.success);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      AppTheme.snackBar(context, 'فشل في إعادة الاحتساب: $e', severity: AppSeverity.danger);
      setState(() => _isLoading = false);
    }
  }

  void _showExtensionRequestDialog(CustomsAbandonmentRadarModel item) {
    final reasonController = TextEditingController();
    final daysController = TextEditingController(text: '30');
    final refController = TextEditingController();
    final planController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.more_time_rounded, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Text('طلب مد مهلة قانونية — ${item.importFileCode}'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المادة 67 من قانون الجمارك 207/2020 تجيز مد المهلة بقرار من مدير عام الجمرك بناء على أسباب مبررة قبل نقل الشحنة للمهمل.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: reasonController,
                  label: 'سبب طلب التمديد (مثل: انتظار فحص سلامة الغذاء / تحاليل المعامل)',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: daysController,
                        label: 'عدد الأيام المطلوبة',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: refController,
                        label: 'رقم الإشارة أو الخطاب الداخلي',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: planController,
                  label: 'خطة إنهاء الإفراج السريع (Action Plan)',
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'إرسال طلب التمديد',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                AppTheme.snackBar(ctx, 'يرجى إدخال سبب طلب التمديد', severity: AppSeverity.warning);
                return;
              }
              final days = int.tryParse(daysController.text.trim()) ?? 30;
              Navigator.of(ctx).pop();
              try {
                final service = ref.read(customsAbandonmentServiceProvider);
                await service.requestExtension(
                  item.radarId,
                  reason: reasonController.text.trim(),
                  requestedDays: days,
                  extensionRequestRef: refController.text.trim().isNotEmpty ? refController.text.trim() : null,
                  actionPlan: planController.text.trim().isNotEmpty ? planController.text.trim() : null,
                );
                if (!mounted) return;
                AppTheme.snackBar(context, 'تم تسجيل طلب التمديد وتحديث حالة الرادار', severity: AppSeverity.success);
                _loadData();
              } catch (e) {
                if (!mounted) return;
                AppTheme.snackBar(context, 'خطأ أثناء تسجيل الطلب: $e', severity: AppSeverity.danger);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showOfficialLetterDraft(CustomsAbandonmentRadarModel item) async {
    try {
      final service = ref.read(customsAbandonmentServiceProvider);
      final draft = await service.getLetterDraft(item.radarId);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.article_outlined, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(child: Text('صيغة خطاب طلب مد المهلة الرسمي — ${item.importFileCode}')),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: SelectionArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('التاريخ: ${draft.letterDate}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('رقم المرجع: ${draft.letterRef}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('السيد الأستاذ / ${draft.recipientTitle}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('تحية طيبة وبعد ،،،', style: TextStyle(color: Colors.grey.shade800)),
                      const SizedBox(height: 12),
                      Text('الموضوع: ${draft.subject}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                      const SizedBox(height: 16),
                      Text(draft.formalBodyAr, style: const TextStyle(fontSize: 13.5, height: 1.6)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text('السند القانوني: ${draft.legalBasis}', style: TextStyle(fontSize: 12, color: Colors.blue.shade900)),
                      ),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text('وتفضلوا بقبول فائق الاحترام والتقدير،،،\n\nمقدمه لسيادتكم / الشركة المستوردة', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق'),
            ),
            AppButton(
              label: 'نسخ نص الخطاب',
              icon: Icons.copy_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                final fullText = '''
التاريخ: ${draft.letterDate}
مرجع: ${draft.letterRef}

السيد الأستاذ / ${draft.recipientTitle}
تحية طيبة وبعد ،،،

الموضوع: ${draft.subject}

${draft.formalBodyAr}

السند القانوني: ${draft.legalBasis}

وتفضلوا بقبول فائق الاحترام والتقدير،،،
${draft.importerName}
''';
                CopyHelper.copy(ctx, fullText, customMessage: 'تم نسخ مسودة الخطاب بالكامل إلى الحافظة');
              },
            ),
          ],
        ),
      );
    } catch (e) {
      AppTheme.snackBar(context, 'تعذر استخراج مسودة الخطاب: $e', severity: AppSeverity.danger);
    }
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'CRITICAL_7_DAYS':
        return AppTheme.crimson;
      case 'WARNING_15_DAYS':
        return AppTheme.orange;
      case 'UNDER_ABANDONMENT_INVENTORY':
        return Colors.purple.shade700;
      case 'NORMAL':
      default:
        return AppTheme.emerald;
    }
  }

  String _riskLabel(String risk) {
    switch (risk) {
      case 'CRITICAL_7_DAYS':
        return 'حرج (≤ 7 أيام)';
      case 'WARNING_15_DAYS':
        return 'إنذار (≤ 15 يوماً)';
      case 'UNDER_ABANDONMENT_INVENTORY':
        return 'تحت حصر المهمل ⛔';
      case 'NORMAL':
      default:
        return 'طبيعي (> 20 يوماً)';
    }
  }

  AppSeverity _riskSeverity(String risk) {
    switch (risk) {
      case 'CRITICAL_7_DAYS':
      case 'UNDER_ABANDONMENT_INVENTORY':
        return AppSeverity.danger;
      case 'WARNING_15_DAYS':
        return AppSeverity.warning;
      case 'NORMAL':
      default:
        return AppSeverity.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
        width: 1100,
        height: 750,
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
                  const Icon(Icons.radar_rounded, color: AppTheme.crimson, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رادار المهمل الجمركي والمخاطر القانونية (Customs Abandonment Radar)',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'المادة 67 من قانون الجمارك المصري 207/2020: الحد الأقصى لبقاء البضائع بالموانئ قبل تحويلها للمهمل والبيع بالمزاد',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: 'إعادة احتساب',
                    icon: Icons.refresh_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: _isLoading ? null : _triggerRecalculate,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Summary Metrics Bar
            if (_summary != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.grey.shade100,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMetricChip('إجمالي الشحنات', '${_summary!.totalRadars}', Colors.blueGrey),
                      const SizedBox(width: 8),
                      _buildMetricChip('طبيعي 🟢', '${_summary!.normalCount}', AppTheme.emerald),
                      const SizedBox(width: 8),
                      _buildMetricChip('إنذار (15 يوم) 🟡', '${_summary!.warning15DaysCount}', AppTheme.orange),
                      const SizedBox(width: 8),
                      _buildMetricChip('حرج (7 أيام) 🔴', '${_summary!.critical7DaysCount}', AppTheme.crimson),
                      const SizedBox(width: 8),
                      _buildMetricChip('تحت الحصر ⛔', '${_summary!.underInventoryCount}', Colors.purple.shade700),
                      const SizedBox(width: 24),
                      Text(
                        'موانئ بحرية: ${_summary!.seaportCount} | جافة/جوية: ${_summary!.dryPortCount + _summary!.airportCount}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Filter & Search Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: AppSearchField(
                      controller: _searchController,
                      hint: 'بحث برقم الملف، البوليصة، أو الجمرك...',
                      onChanged: (_) => _loadData(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('مستوى الخطورة: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  DropdownButton<String>(
                    value: _selectedRisk,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('كافة المستويات')),
                      DropdownMenuItem(value: 'CRITICAL_7_DAYS', child: Text('🔴 حرج (≤ 7 أيام)')),
                      DropdownMenuItem(value: 'WARNING_15_DAYS', child: Text('🟡 إنذار (≤ 15 يوماً)')),
                      DropdownMenuItem(value: 'NORMAL', child: Text('🟢 طبيعي')),
                      DropdownMenuItem(value: 'UNDER_ABANDONMENT_INVENTORY', child: Text('⛔ تحت حصر المهمل')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRisk = val);
                        _loadData();
                      }
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث القائمة',
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content Table
            Expanded(
              child: _isLoading
                  ? const AppLoadingState()
                  : _errorMessage != null
                      ? AppErrorState(message: _errorMessage!, onRetry: _loadData)
                      : _records.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_outlined, size: 54, color: AppTheme.emerald),
                                  SizedBox(height: 12),
                                  Text(
                                    'لا توجد شحنات تحت مخاطر المهمل حالياً. جميع البضائع في النطاق الآمن.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : SelectionArea(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _records.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = _records[idx];
                                  final rColor = _riskColor(item.riskLevel);

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: rColor.withValues(alpha: 0.4), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Risk Indicator Column
                                        Container(
                                          width: 80,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: rColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                '${item.daysRemaining}',
                                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: rColor),
                                              ),
                                              Text(
                                                'يوم متبقي',
                                                style: TextStyle(fontSize: 10, color: rColor, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Main File Details
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    item.importFileCode,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cobalt),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  AppStatusBadge(
                                                    label: _riskLabel(item.riskLevel),
                                                    severity: _riskSeverity(item.riskLevel),
                                                  ),
                                                  if (item.extensionRequested) ...[
                                                    const SizedBox(width: 6),
                                                    const AppStatusBadge(
                                                      label: 'طلب تمديد قيد الانتظار',
                                                      severity: AppSeverity.warning,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'الميناء: ${item.portName ?? item.portType} | تاريخ الوصول: ${item.arrivalDate} | بالدائرة الجمركية: ${item.daysInPort} يوم (حد أقصى ${item.maxLegalDays} يوم)',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              ),
                                              if (item.cargoDescription != null)
                                                Text(
                                                  'البضاعة: ${item.cargoDescription}',
                                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Actions Buttons
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AppButton(
                                              label: 'طلب مد مهلة',
                                              icon: Icons.more_time_rounded,
                                              variant: AppButtonVariant.secondary,
                                              size: AppButtonSize.small,
                                              onPressed: () => _showExtensionRequestDialog(item),
                                            ),
                                            const SizedBox(width: 8),
                                            AppButton(
                                              label: 'مسودة الخطاب',
                                              icon: Icons.article_outlined,
                                              variant: AppButtonVariant.secondary,
                                              size: AppButtonSize.small,
                                              onPressed: () => _showOfficialLetterDraft(item),
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
    ),
  );
}

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
