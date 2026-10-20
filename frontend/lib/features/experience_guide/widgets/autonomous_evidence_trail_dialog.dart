import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/guide_entry_model.dart';
import '../providers/experience_guide_provider.dart';

class AutonomousEvidenceTrailDialog extends ConsumerStatefulWidget {
  final int entryId;
  final String? initialTitle;
  /// Evidence / reason already rendered in the user's language from the entry's message code;
  /// they win over the provenance texts, which are stored in English.
  final String? initialEvidence;
  final String? initialReason;
  final VoidCallback? onStateChanged;

  const AutonomousEvidenceTrailDialog({
    super.key,
    required this.entryId,
    this.initialTitle,
    this.initialEvidence,
    this.initialReason,
    this.onStateChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required int entryId,
    String? initialTitle,
    String? initialEvidence,
    String? initialReason,
    VoidCallback? onStateChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AutonomousEvidenceTrailDialog(
        entryId: entryId,
        initialTitle: initialTitle,
        initialEvidence: initialEvidence,
        initialReason: initialReason,
        onStateChanged: onStateChanged,
      ),
    );
  }

  @override
  ConsumerState<AutonomousEvidenceTrailDialog> createState() =>
      _AutonomousEvidenceTrailDialogState();
}

class _AutonomousEvidenceTrailDialogState
    extends ConsumerState<AutonomousEvidenceTrailDialog> {
  ProvenanceModel? _provenance;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _loadProvenance();
  }

  Future<void> _loadProvenance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(experienceGuideProvider.notifier);
      final data = await notifier.fetchEntryProvenance(widget.entryId);
      if (mounted) {
        setState(() {
          _provenance = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل في تحميل مسار الأدلة: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePromote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: AppTheme.emerald),
            SizedBox(width: 8),
            Text('اعتماد الاستنتاج كقاعدة مؤسسية', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'سيتم قفل هذا النمط وتحويله إلى مرجعية مؤسسية معتمدة ومؤكدة (Confirmed Standard)، '
          'بحيث تظل نشطة ولا يتم أرشفتها تلقائياً عند تغير العينات. هل تريد المتابعة؟',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'تأكيد الاعتماد',
            icon: Icons.check_circle_rounded,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final notifier = ref.read(experienceGuideProvider.notifier);
      final res = await notifier.promoteInferredEntry(
        widget.entryId,
        promotedBy: 'Authorized Staff',
      );
      if (mounted) {
        setState(() => _isProcessingAction = false);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم اعتماد النمط بنجاح كمرجعية مؤسسية ثابتة'),
              backgroundColor: AppTheme.emerald,
            ),
          );
          widget.onStateChanged?.call();
          _loadProvenance();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ حدث خطأ أثناء الاعتماد: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  Future<void> _handleReject() async {
    final reasonController = TextEditingController();
    final rejected = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppTheme.crimson),
            SizedBox(width: 8),
            Text('استبعاد هذا الاستنتاج الذاتي', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'يرجى توضيح سبب استبعاد هذا الاستنتاج حتى يتعلم النظام ولا يعيد اقتراحه مستقبلاً:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'مثال: تم الاتفاق على ملحق تعاقدي جديد يلغي هذا التأخير...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'استبعاد الاستنتاج',
            icon: Icons.block_rounded,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () {
              if (reasonController.text.trim().length >= 3) {
                Navigator.pop(ctx, true);
              }
            },
          ),
        ],
      ),
    );

    if (rejected != true || reasonController.text.trim().length < 3) return;

    setState(() => _isProcessingAction = true);
    try {
      final notifier = ref.read(experienceGuideProvider.notifier);
      final res = await notifier.rejectInferredEntry(
        widget.entryId,
        rejectionReason: reasonController.text.trim(),
      );
      if (mounted) {
        setState(() => _isProcessingAction = false);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم استبعاد الاستنتاج وحجبه من الظهور التشغيلي'),
              backgroundColor: AppTheme.charcoal,
            ),
          );
          widget.onStateChanged?.call();
          _loadProvenance();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ حدث خطأ أثناء الاستبعاد: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppTheme.emerald, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مسار الأدلة والتحليل الذاتي (Evidence Trail & Provenance)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.initialTitle ?? _provenance?.title ?? 'استنتاج آلي ذاتي',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.cobalt),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.crimson)),
                        )
                      : _buildEvidenceContent(),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  if (_provenance != null &&
                      _provenance!.sourceType == 'SYSTEM_INFERRED' &&
                      !_provenance!.isConfirmed &&
                      !_provenance!.isRejected) ...[
                    AppButton(
                      label: 'اعتماد كمرجعية مؤسسية مؤكدة',
                      icon: Icons.verified_rounded,
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.small,
                      isLoading: _isProcessingAction,
                      onPressed: _handlePromote,
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: 'استبعاد هذا النمط',
                      icon: Icons.cancel_outlined,
                      variant: AppButtonVariant.danger,
                      size: AppButtonSize.small,
                      isLoading: _isProcessingAction,
                      onPressed: _handleReject,
                    ),
                  ],
                  const Spacer(),
                  AppButton(
                    label: 'إغلاق',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceContent() {
    final p = _provenance!;
    final reasonText = widget.initialReason ?? p.reasonWhy;
    final evidenceText = widget.initialEvidence ?? p.evidenceSummary;
    final score = p.confidenceScore != null ? (p.confidenceScore! * 100).toInt() : 0;
    final files = p.contributingFiles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Status & Dimension Chips Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 14, color: AppTheme.cobalt),
                    SizedBox(width: 4),
                    Text(
                      'استنتاج آلي ذاتي (System-Inferred)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (p.isConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.emerald),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: AppTheme.emerald),
                      const SizedBox(width: 4),
                      Text(
                        'معتمد كقاعدة مؤسسية (${p.confirmedBy ?? 'إدارة'})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      ),
                    ],
                  ),
                )
              else if (p.isRejected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.crimson),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.block_rounded, size: 14, color: AppTheme.crimson),
                      const SizedBox(width: 4),
                      Text(
                        'مستبعد (${p.rejectedBy ?? 'مستخدم'})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.orange),
                  ),
                  child: const Text(
                    'قيد المراقبة وإعادة التقييم التلقائي',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange),
                  ),
                ),
              if (p.patternCategory != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    p.patternCategory!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // 2. Metrics 3-Card Dashboard
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'مستوى الثقة الإحصائية',
                  value: '$score%',
                  subtitle: p.confidenceLevel ?? 'MEDIUM',
                  icon: Icons.analytics_outlined,
                  color: score >= 80
                      ? AppTheme.emerald
                      : (score >= 65 ? AppTheme.cobalt : AppTheme.orange),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'حجم العينة المرصودة',
                  value: '${p.sampleSize ?? files.length}',
                  subtitle: 'شحنات استيرادية سابقة',
                  icon: Icons.inventory_2_outlined,
                  color: AppTheme.cobalt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'تاريخ الاكتشاف والرصد',
                  value: p.firstDetectedAt != null
                      ? p.firstDetectedAt!.split('T').first
                      : 'مستمر',
                  subtitle: p.lastRecalculatedAt != null
                      ? 'آخر تحديث: ${p.lastRecalculatedAt!.split('T').first}'
                      : 'تحديث تلقائي',
                  icon: Icons.update_rounded,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Why am I seeing this note? (Panel)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.help_outline_rounded, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'لماذا يظهر هذا الاستنتاج التشغيلي؟',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reasonText ?? 'تم رصد هذا النمط تلقائياً استناداً إلى نتائج وتكرار البيانات في الشحنات السابقة.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Evidence Summary Card
          if (evidenceText != null && evidenceText.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fact_check_outlined, size: 16, color: AppTheme.charcoal),
                      SizedBox(width: 6),
                      Text(
                        'ملخص الإثبات والقياس الإحصائي (Comparative Metrics):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    evidenceText,
                    style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.charcoal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 5. Contributing Files Table
          Row(
            children: [
              const Icon(Icons.table_rows_rounded, size: 16, color: AppTheme.cobalt),
              const SizedBox(width: 6),
              Text(
                'الشحنات السابقة المساهمة في هذا الاستنتاج (${files.length} شحنات):',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (files.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Text('لا توجد تفاصيل شحنات تفصيلية مسجلة في هذا الاستنتاج', style: TextStyle(fontSize: 12)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade200)),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text('كود الشحنة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text('المقياس المرصود', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text('حالة الشحنة / التفاصيل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...files.map((f) {
                      final code = f['import_file_code'] ?? f['booking_id']?.toString() ?? 'SHP';
                      final metric = f['metric_measured'] ?? f['variance_egp']?.toString() ?? '-';
                      final status = f['file_status'] ?? f['status'] ?? f['route'] ?? 'مسجلة';

                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              code.toString(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              metric.toString(),
                              style: const TextStyle(fontSize: 12, color: AppTheme.crimson, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              status.toString(),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
