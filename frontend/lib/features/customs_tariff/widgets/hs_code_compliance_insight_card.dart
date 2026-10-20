import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/customs_tariff_model.dart';
import '../models/preferential_agreement_model.dart';
import '../providers/customs_tariff_provider.dart';

/// بطاقة تنبيهية / ملاحظات ذكية للبند الجمركي
/// تعرض شروط الاستيراد الرقابية، جهات العرض، والفحص المعملي،
/// بالإضافة إلى الإعفاءات والاتفاقيات التجارية المتاحة وشروط استيفائها.
class HsCodeComplianceInsightCard extends ConsumerStatefulWidget {
  final String hsCode;
  final CustomsTariffModel? tariff;
  final String? countryOfOrigin;
  final bool isDark;
  final bool isArabic;
  final bool initiallyExpanded;

  const HsCodeComplianceInsightCard({
    super.key,
    required this.hsCode,
    this.tariff,
    this.countryOfOrigin,
    this.isDark = false,
    this.isArabic = true,
    this.initiallyExpanded = true,
  });

  @override
  ConsumerState<HsCodeComplianceInsightCard> createState() =>
      _HsCodeComplianceInsightCardState();
}

class _HsCodeComplianceInsightCardState
    extends ConsumerState<HsCodeComplianceInsightCard> {
  List<PreferentialAgreementModel>? _agreements;
  bool _isLoadingAgreements = false;
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _fetchAgreements();
  }

  @override
  void didUpdateWidget(covariant HsCodeComplianceInsightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hsCode != widget.hsCode) {
      _fetchAgreements();
    }
  }

  Future<void> _fetchAgreements() async {
    final cleanHs = widget.hsCode.trim();
    if (cleanHs.isEmpty || cleanHs == '-' || cleanHs == 'UNSPECIFIED') return;

    setState(() => _isLoadingAgreements = true);
    try {
      final rawAgreements = await ref
          .read(customsTariffProvider.notifier)
          .fetchAgreements(cleanHs);
      if (mounted) {
        setState(() {
          _agreements = rawAgreements
              .map((json) => PreferentialAgreementModel.fromJson(json))
              .toList();
          _isLoadingAgreements = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _agreements = [];
          _isLoadingAgreements = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isAr = widget.isArabic;
    final cleanHs = widget.hsCode.trim();
    final registeredTariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];
    final tariff = widget.tariff ??
        registeredTariffs
            .cast<CustomsTariffModel?>()
            .firstWhere(
              (t) =>
                  t != null &&
                  (t.hsCode == cleanHs ||
                      t.hsCode.replaceAll('.', '') == cleanHs.replaceAll('.', '')),
              orElse: () => null,
            );

    final hasPriorApproval =
        tariff != null && (tariff.priorApprovalNote?.isNotEmpty ?? false);
    final hasAuthority =
        tariff != null && (tariff.regulatoryAuthority?.isNotEmpty ?? false);
    final hasAgreements = _agreements != null && _agreements!.isNotEmpty;

    final badgeBg = hasPriorApproval
        ? AppTheme.crimson.withValues(alpha: isDark ? 0.2 : 0.08)
        : AppTheme.cobalt.withValues(alpha: isDark ? 0.2 : 0.08);
    final borderColor = hasPriorApproval
        ? AppTheme.crimson.withValues(alpha: 0.4)
        : AppTheme.cobalt.withValues(alpha: 0.3);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Toggle Bar
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(7),
                  bottom: Radius.circular(_isExpanded ? 0 : 7),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasPriorApproval
                        ? Icons.warning_amber_rounded
                        : Icons.shield_outlined,
                    color: hasPriorApproval
                        ? AppTheme.crimson
                        : AppTheme.cobalt,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'بطاقة الامتثال الذكي للبند الجمركي [$cleanHs]: شروط الاستيراد والاتفاقيات والإعفاءات'
                          : 'Smart Compliance Insight for HS [$cleanHs]: Regulatory Conditions & Agreements',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: hasPriorApproval
                            ? (isDark ? Colors.red.shade300 : AppTheme.crimson)
                            : (isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                      ),
                    ),
                  ),
                  if (hasAgreements) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppTheme.emerald.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        isAr
                            ? 'إعفاءات متاحة (${_agreements!.length})'
                            : 'Exemptions Available (${_agreements!.length})',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.green.shade300
                              : AppTheme.emerald,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Regulatory Import Conditions (شروط الاستيراد الرقابية)
                  _buildSectionContainer(
                    title: isAr
                        ? '🛡️ شروط الاستيراد الرقابية وجهات العرض والفحص'
                        : '🛡️ Regulatory Import Conditions & Inspection Authorities',
                    accentColor: hasPriorApproval
                        ? AppTheme.crimson
                        : AppTheme.orange,
                    isDark: isDark,
                    children: [
                      // Authorities
                      _buildInfoRow(
                        label: isAr ? 'جهات العرض والرقابة:' : 'Regulatory Authorities:',
                        value: hasAuthority
                            ? tariff.regulatoryAuthority!
                            : (isAr
                                ? 'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)'
                                : 'General Organization for Export & Import Control (GOEIC)'),
                        isDark: isDark,
                        isHighlight: hasAuthority,
                      ),
                      // Inspections & Certificates
                      _buildInfoRow(
                        label: isAr ? 'الفحص والمطابقة:' : 'Inspection & Compliance:',
                        value: (tariff?.requiresInspection ?? true)
                            ? (isAr
                                ? 'فحص ظاهري ومعملي إلزامي بالدائرة الجمركية طبقاً للمواصفة القياسية المصرية'
                                : 'Mandatory Physical & Lab Inspection at Port per Egyptian Standard')
                            : (isAr
                                ? 'إفراج مباشر دون فحص معملي مسبق'
                                : 'Standard Clearance without prior lab inspection'),
                        isDark: isDark,
                      ),
                      // COO & ACID
                      _buildInfoRow(
                        label: isAr ? 'شهادة المنشأ و ACID:' : 'Origin & ACID:',
                        value: isAr
                            ? 'شهادة منشأ أصلية معتمدة من الغرفة التجارية + رقم ACID إلزامي مسجل عبر CargoX'
                            : 'Original authenticated Certificate of Origin + Mandatory ACID via CargoX',
                        isDark: isDark,
                      ),
                      // Prior Approval Notes if present
                      if (hasPriorApproval) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.crimson.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppTheme.crimson.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.crimson, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  tariff.priorApprovalNote!,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.red.shade300
                                        : AppTheme.crimson,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Row 2: Available Agreements & Exemptions (الاتفاقيات والإعفاءات المتاحة)
                  _buildSectionContainer(
                    title: isAr
                        ? '📜 الإعفاءات والاتفاقيات الجمركية المتاحة وقواعد المنشأ'
                        : '📜 Available Trade Agreements, Exemptions & Origin Rules',
                    accentColor: AppTheme.emerald,
                    isDark: isDark,
                    children: [
                      if (_isLoadingAgreements)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAr
                                    ? 'جاري فحص الاتفاقيات التفضيلية المعتمدة للبند...'
                                    : 'Checking preferential trade agreements for HS code...',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      else if (_agreements != null && _agreements!.isNotEmpty) ...[
                        ..._agreements!.map((agreement) {
                          final originMatched = widget.countryOfOrigin != null &&
                              agreement.originCountries
                                  .split(',')
                                  .map((c) => c.trim().toUpperCase())
                                  .contains(widget.countryOfOrigin!.trim().toUpperCase());

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: originMatched
                                  ? AppTheme.emerald.withValues(alpha: 0.12)
                                  : (isDark
                                      ? AppTheme.darkSurface
                                      : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: originMatched
                                    ? AppTheme.emerald
                                    : (isDark
                                        ? AppTheme.darkBorder
                                        : Colors.grey.shade300),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      originMatched
                                          ? Icons.verified
                                          : Icons.handshake_outlined,
                                      color: originMatched
                                          ? AppTheme.emerald
                                          : AppTheme.cobalt,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        agreement.agreementName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: originMatched
                                              ? (isDark
                                                  ? Colors.green.shade300
                                                  : AppTheme.emerald)
                                              : (isDark
                                                  ? AppTheme.darkTextPrimary
                                                  : AppTheme.charcoal),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        agreement.reductionType == 'full_duty_exemption'
                                            ? (isAr ? 'إعفاء 100%' : '100% Exemption')
                                            : '${(agreement.reductionPercentage * 100).toInt()}% تخفيض',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.green.shade300
                                              : AppTheme.emerald,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isAr
                                      ? '• الدول المشمولة: ${agreement.originCountries} | المستند الإلزامي: ${agreement.requiredDocument ?? "شهادة EUR.1 / شهادة منشأ أصلية مستوفاة"}'
                                      : '• Eligible Countries: ${agreement.originCountries} | Required Document: ${agreement.requiredDocument ?? "Original EUR.1 / COO"}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                if (agreement.conditionsNote != null &&
                                    agreement.conditionsNote!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '• ${agreement.conditionsNote!}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontStyle: FontStyle.italic,
                                        color: isDark
                                            ? AppTheme.darkTextMuted
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        // Default general agreements applicable in Egypt
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            isAr
                                ? '• الاتفاقيات العامة السارية: اتفاقية الشراكة المصرية الأوروبية، اتفاقية التجارة الحرة العربية (GAFTA)، اتفاقية أغادير، اتفاقية الميركوسور، اتفاقية التجارة مع تركيا.'
                                : '• Applicable Trade Treaties: EU-Egypt Partnership, GAFTA, Agadir, Mercosur, Turkey FTA.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            isAr
                                ? '• شرط تطبيق الإعفاء: توفير شهادة منشأ مطابقة للاتفاقية (EUR.1 لأوروبا / شهادة منشأ عربية لـ GAFTA) + الشحن المباشر من بلد المنشأ.'
                                : '• Exemption Condition: Compliant Certificate of Origin (EUR.1 for EU / Arab COO for GAFTA) + Direct consignment.',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.green.shade300
                                  : AppTheme.emerald,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required Color accentColor,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurface.withValues(alpha: 0.6)
            : const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const Divider(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required bool isDark,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: isHighlight
                    ? (isDark ? Colors.amber.shade300 : AppTheme.orange)
                    : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
