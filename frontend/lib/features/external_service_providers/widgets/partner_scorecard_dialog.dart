import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/localization/app_localizations.dart';

void showPartnerScorecardDialog(BuildContext context, WidgetRef ref, {
  required int providerId,
  required String providerName,
  required String providerType,
}) {
  showDialog(
    context: context,
    builder: (ctx) => PartnerScorecardDialog(
      providerId: providerId,
      providerName: providerName,
      providerType: providerType,
    ),
  );
}

class PartnerScorecardDialog extends ConsumerStatefulWidget {
  final int providerId;
  final String providerName;
  final String providerType;

  const PartnerScorecardDialog({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.providerType,
  });

  @override
  ConsumerState<PartnerScorecardDialog> createState() => _PartnerScorecardDialogState();
}

class _PartnerScorecardDialogState extends ConsumerState<PartnerScorecardDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _scorecard;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _fetchScorecard();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _fetchScorecard() async {
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/external-service-providers/${widget.providerId}/scorecard',
        cancelToken: cancelToken,
      );
      if (mounted) {
        setState(() {
          _scorecard = res.data is Map<String, dynamic> ? res.data : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (cancelToken.isCancelled) return;
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 800,
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()))
              : _error != null
                  ? SizedBox(
                      height: 250,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.crimson, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: AppTheme.crimson)),
                            const SizedBox(height: 12),
                            AppButton(label: l10n.retryConnectionBtn, variant: AppButtonVariant.primary, onPressed: _fetchScorecard),
                          ],
                        ),
                      ),
                    )
                  : _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compositeScore = (_scorecard?['composite_score'] as num?)?.toDouble() ?? 0.0;
    final tier = _scorecard?['performance_tier'] ?? 'Gold A';
    final stars = (_scorecard?['star_rating'] as num?)?.toDouble() ?? 4.0;
    final totalJobs = _scorecard?['total_jobs_evaluated'] ?? 0;
    final summary = _scorecard?['evaluation_summary_ar'] ?? '';
    final metrics = (_scorecard?['metrics'] as Map<String, dynamic>?) ?? {};
    final strengths = (_scorecard?['strengths'] as List<dynamic>?) ?? [];
    final improvements = (_scorecard?['improvement_areas'] as List<dynamic>?) ?? [];

    final criteria = (_scorecard?['criteria_breakdown'] as List<dynamic>?) ?? [];

    Color tierColor;
    if (tier.toString().contains('Platinum')) {
      tierColor = AppTheme.emerald;
    } else if (tier.toString().contains('Gold')) {
      tierColor = AppTheme.cobalt;
    } else if (tier.toString().contains('Silver')) {
      tierColor = AppTheme.orange;
    } else {
      tierColor = AppTheme.crimson;
    }

    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.workspace_premium_outlined, color: tierColor, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scorecardDialogTitle,
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n.scorecardPartnerSubtitle(widget.providerName, widget.providerType),
                      style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Score and Tier Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: isDark ? 0.15 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tierColor.withValues(alpha: isDark ? 0.6 : 0.4), width: 1.5),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${compositeScore.toStringAsFixed(1)} / 100',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: tierColor),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < stars.floor()
                              ? Icons.star
                              : (index < stars ? Icons.star_half : Icons.star_border),
                          color: Colors.amber.shade700,
                          size: 18,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: tierColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l10n.scorecardTierLabel(tier.toString()),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.scorecardTotalJobs(totalJobs is int ? totalJobs : int.tryParse(totalJobs.toString()) ?? 0),
                        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700, fontSize: 12.5),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade900, fontSize: 12.5, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Criteria Breakdown (LOG-KPIS-005)
          if (criteria.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? '📊 تفصيل معايير التقييم والأوزان المعتمدة' : '📊 Evaluation Criteria & Weights Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(4.5),
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardBackground : const Color(0xFFF1F5F9),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Text(
                            isArabic ? 'المعيار' : 'Criterion',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Text(
                            isArabic ? 'الوزن' : 'Weight',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Text(
                            isArabic ? 'الدرجة المحققة' : 'Score',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Text(
                            isArabic ? 'مصدر البيانات الفعلي' : 'Data Source',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                        ),
                      ],
                    ),
                    ...criteria.map((c) {
                      final cMap = c is Map<String, dynamic> ? c : {};
                      final name = isArabic
                          ? (cMap['criterion_name_ar'] ?? cMap['criterion_name_en'] ?? '')
                          : (cMap['criterion_name_en'] ?? cMap['criterion_name_ar'] ?? '');
                      final weight = cMap['weight_pct'] ?? 0;
                      final score = (cMap['score_achieved'] as num?)?.toDouble() ?? 0.0;
                      final source = cMap['data_source_ar'] ?? '-';
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(name.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            child: Text('$weight%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            child: Text(
                              '${score.toStringAsFixed(1)} / 100',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: score >= 85 ? AppTheme.emerald : (score >= 70 ? AppTheme.orange : AppTheme.crimson),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(source.toString(), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.black87)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Detailed KPI Metrics Tiles
          if (metrics.isNotEmpty) ...[
            Text('📈 ${l10n.scorecardKpiHeader}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics.entries.map((entry) {
                final key = entry.key;
                final val = entry.value;
                String label = key;
                if (key == 'avg_clearance_turnaround_days') label = l10n.scorecardAvgClearanceDays;
                if (key == 'green_channel_rate_pct') label = l10n.scorecardGreenChannelRate;
                if (key == 'sla_adherence_rate_pct') label = l10n.scorecardSlaAdherenceRate;
                if (key == 'avg_arrival_delay_days') label = l10n.scorecardAvgArrivalDelayDays;
                if (key == 'schedule_reliability_pct') label = l10n.scorecardScheduleReliability;

                return Container(
                  width: 230,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(
                        val is num ? val.toStringAsFixed(1) : val.toString(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],

          // Strengths & Improvement
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (strengths.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('💪 ${l10n.scorecardStrengthsHeader}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.emerald)),
                      const SizedBox(height: 6),
                      ...strengths.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 15, color: AppTheme.emerald),
                            const SizedBox(width: 6),
                            Expanded(child: Text(s.toString(), style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              if (improvements.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⚠️ ${l10n.scorecardImprovementsHeader}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.orange)),
                      const SizedBox(height: 6),
                      ...improvements.map((im) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 15, color: AppTheme.orange),
                            const SizedBox(width: 6),
                            Expanded(child: Text(im.toString(), style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Expandable Methodology Guide (6 Partner Types)
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            collapsedBackgroundColor: isDark ? AppTheme.darkCardBackground : const Color(0xFFF8FAFC),
            backgroundColor: isDark ? AppTheme.darkCardBackground : const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
            leading: const Icon(Icons.info_outline_rounded, color: AppTheme.cobalt, size: 20),
            title: Text(
              isArabic ? 'ℹ️ كيف يُحسب التقييم؟ (دليل معايير وأوزان التقييم المعتمدة لكافة الشركاء)' : 'ℹ️ How is the Scorecard Calculated? (Official Criteria & Weights Guide)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMethodologyRow(
                      context,
                      title: isArabic ? '1. المخلص الجمركي (Customs Broker):' : '1. Customs Broker:',
                      desc: isArabic
                          ? '• سرعة الإفراج (35%): من سجلات الإفراج الجمركي الفعلي.\n• المسار الأخضر (25%): من منظومة نافذة MTS.\n• دقة الفواتير والرسوم (25%): مطابقة الفواتير والمصاريف.\n• تجنب الأرضيات والغرامات (15%): رادار تتبع فترات السماح.'
                          : '• Turnaround Speed (35%): Actual clearance turnaround.\n• Green Channel Rate (25%): Nafeza MTS green routing.\n• Billing Precision (25%): Matching clearance invoices.\n• Demurrage Avoidance (15%): Free time radar compliance.',
                    ),
                    const Divider(height: 14),
                    _buildMethodologyRow(
                      context,
                      title: isArabic ? '2. الخط الملاحي (Shipping Line):' : '2. Shipping Line:',
                      desc: isArabic
                          ? '• الالتزام بمواعيد الإبحار والوصول (40%): تتبع حجوزات الشحن وتأخيرات الترانزيت.\n• أيام السماح المجانية للحاويات (25%): ميزة فترات السماح المسجلة.\n• سلامة الحاويات وتفادي التلف (20%): محاضر الفحص واستلام البضائع.\n• سرعة إصدار إذن التسليم (15%): سجلات سداد واستلام D/O.'
                          : '• Transit Schedule SLA (40%): Tracking departure delays.\n• Free Days Allowance (25%): Standard demurrage free days.\n• Equipment Integrity (20%): Container condition at discharge.\n• D/O Processing Speed (15%): Delivery order receipt speed.',
                    ),
                    const Divider(height: 14),
                    _buildMethodologyRow(
                      context,
                      title: isArabic ? '3. وكيل الشحن (Freight Forwarder):' : '3. Freight Forwarder:',
                      desc: isArabic
                          ? '• الالتزام بمواعيد الشحن والتتبع (35%): حجوزات الشحن والربط مع التتبع.\n• شفافية الأسعار وثبات العروض (30%): مطابقة فواتير المصاريف مع عروض الأسعار.\n• فترة السماح التنافسية (20%): رصيد أيام السماح المسجلة.\n• سرعة إصدار بوالص الشحن (15%): مراجعة مسودة Draft B/L.'
                          : '• Shipping SLA & Tracking (35%): Booking schedule compliance.\n• Quote Transparency (30%): Final invoices vs quotation.\n• Free Days Allowance (20%): Demurrage buffer days.\n• B/L Issuance Speed (15%): Draft bill of lading approval.',
                    ),
                    const Divider(height: 14),
                    _buildMethodologyRow(
                      context,
                      title: isArabic ? '4. شركة النقل الداخلي (Inland Transport):' : '4. Inland Transport:',
                      desc: isArabic
                          ? '• الالتزام بمواعيد التحميل والتسليم (40%): أوامر النقل الداخلي ومطابقة المواعيد.\n• سلامة الحاويات والبضائع (30%): محاضر الفحص والاستلام بالمستودعات GRN.\n• توفر الأسطول وتغطية الموانئ (20%): أنواع الأسطول وتغطية الموانئ.\n• التقييم العام وجودة التنسيق (10%): تقييم مشرفي الحركة.'
                          : '• Delivery SLA (40%): Fleet arrival vs scheduled gate-in.\n• Cargo Integrity (30%): Zero-damage reports at warehouse.\n• Fleet Availability (20%): Equipment types & port coverage.\n• Coordination (10%): Transport supervisors assessment.',
                    ),
                    const Divider(height: 14),
                    _buildMethodologyRow(
                      context,
                      title: isArabic ? '5. شركة الفحص والرقابة (Inspection Agency):' : '5. Inspection Agency:',
                      desc: isArabic
                          ? '• سرعة سحب العينات وصدور شهادة المطابقة (45%): سجلات سحب العينات وصدور النتائج.\n• دقة نتائج الفحص والمواصفات (35%): تفادي قرارات الرفض الرقابي.\n• نطاق الاعتماد والاعتراف الرقابي (20%): رقم الاعتماد والاعتراف لدى GOEIC.'
                          : '• Sampling & CoC Speed (45%): Laboratory testing turnaround.\n• Conformity Accuracy (35%): Avoiding regulatory rejection.\n• Accreditation Scope (20%): ISO 17020/17025 accredited labs.',
                    ),
                    const Divider(height: 14),
                    _buildMethodologyRow(
                      context,
                      title: isArabic ? '6. شركة التأمين البحري (Insurance Company):' : '6. Insurance Company:',
                      desc: isArabic
                          ? '• شمولية وسرعة إصدار وثيقة التأمين (40%): شروط تغطية أخطار المعهد.\n• سرعة تسوية المطالبات والتعويضات (40%): سجلات تعويضات مطالبات الشحن.\n• التنافسية السعرية لنسبة القسط (20%): عروض أسعار وثائق التأمين البحري.'
                          : '• Policy Issuance & Terms (40%): Marine cargo cover clauses.\n• Claims Settlement (40%): Claim reimbursement turnaround.\n• Premium Competitiveness (20%): Rate benchmark competitiveness.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodologyRow(BuildContext context, {required String title, required String desc}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt)),
        const SizedBox(height: 3),
        Text(desc, style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black87, height: 1.35)),
      ],
    );
  }
}
