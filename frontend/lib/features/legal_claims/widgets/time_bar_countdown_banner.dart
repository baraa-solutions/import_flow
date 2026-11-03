import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../legal_claims_provider.dart';

class TimeBarCountdownBanner extends StatelessWidget {
  final LegalClaimItem claim;

  const TimeBarCountdownBanner({super.key, required this.claim});

  @override
  Widget build(BuildContext context) {
    Color bannerColor;
    String statusTitle;
    IconData statusIcon;

    switch (claim.urgencyLevel) {
      case 'EXPIRED':
        bannerColor = AppTheme.crimson;
        statusTitle = 'سقط حق الدعوى بالتقادم القانوني التام';
        statusIcon = Icons.error_outline;
        break;
      case 'CRITICAL_7_DAYS':
        bannerColor = AppTheme.crimson;
        statusTitle = 'خطر داهم: متبقي أقل من 7 أيام على سقوط الحق بالتقادم';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'WARNING_30_DAYS':
        bannerColor = AppTheme.orange;
        statusTitle = 'تنبيه قانوني: متبقي أقل من شهر على انقضاء مهلة الدعوى';
        statusIcon = Icons.alarm;
        break;
      default:
        bannerColor = AppTheme.cobalt;
        statusTitle = 'مواعيد الدعوى والمطالبة القانونية سارية ومحمية';
        statusIcon = Icons.shield_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: bannerColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    color: bannerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${claim.daysUntilTimeBar} يوم متبقي',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTimeMetric(
                  'إخطار التلف المستتر (مهلة 3 أيام)',
                  claim.latentNoticeDeadline != null
                      ? claim.latentNoticeDeadline!.toIso8601String().substring(0, 10)
                      : 'فوري (تلف ظاهر)',
                  claim.isLatentNoticeExpired ? AppTheme.crimson : AppTheme.charcoal,
                ),
              ),
              Expanded(
                child: _buildTimeMetric(
                  'تاريخ سقوط حق الدعوى (سنة بحري)',
                  claim.timeBarStatuteOfLimitationsDate.toIso8601String().substring(0, 10),
                  bannerColor,
                ),
              ),
              Expanded(
                child: _buildTimeMetric(
                  'تاريخ استلام الشحنة الفعلي',
                  claim.deliveryDate?.toIso8601String().substring(0, 10) ?? 'غير مسجل',
                  AppTheme.charcoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeMetric(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
