import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/cargo_insurance_model.dart';

/// 🛡️ Reusable Compact Cargo Insurance Policy Card
class InsurancePolicyCard extends StatelessWidget {
  final CargoInsuranceModel? policy;
  final String? policyNumber, certificateCode, insuranceCompanyName, currency, coverageClause, status;
  final double? insuredValue, cifValue;
  final VoidCallback? onViewDetails, onFileClaim, onPrint;

  const InsurancePolicyCard({
    super.key,
    this.policy,
    this.policyNumber,
    this.certificateCode,
    this.insuranceCompanyName,
    this.insuredValue,
    this.cifValue,
    this.currency,
    this.coverageClause,
    this.status,
    this.onViewDetails,
    this.onFileClaim,
    this.onPrint,
  });

  String get _policyNumber => policyNumber ?? policy?.policyNumber ?? policy?.certificateCode ?? '—';
  String get _certificateCode => certificateCode ?? policy?.certificateCode ?? '';
  String get _companyName => insuranceCompanyName ?? policy?.insuranceCompanyName ?? '—';
  double get _insuredVal => insuredValue ?? policy?.insuredValue ?? 0.0;
  String get _curr => currency ?? policy?.currency ?? 'USD';
  String get _clause => coverageClause ?? policy?.coverageClause ?? 'ICC_A';
  String get _status => status ?? policy?.status ?? 'ISSUED';

  static String _formatNumber(double val) {
    final p = val.toStringAsFixed(2).split('.'), d = p[0], b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) b.write(',');
      b.write(d[i]);
    }
    return '$b.${p[1]}';
  }

  String _formatCoverage(String clause, bool isAr) => switch (clause.toUpperCase()) {
        'ICC_A' => isAr ? 'شروط معهد المكتتبين أ — أخطار شاملة' : 'ICC A — All Risks',
        'ICC_B' => isAr ? 'شروط معهد المكتتبين ب — أخطار محددة' : 'ICC B — Named Perils',
        'ICC_C' => isAr ? 'شروط معهد المكتتبين ج — حوادث كبرى' : 'ICC C — Major Casualties',
        'AIR_ALL_RISKS' => isAr ? 'شروط النقل الجوي — أخطار شاملة' : 'Air All Risks',
        _ => clause,
      };

  String _formatStatus(String st, bool isAr) => switch (st.toUpperCase()) {
        'ISSUED' => isAr ? 'سارية ومعتمدة' : 'Issued & Valid',
        'CLAIMED' => isAr ? 'قيد المطالبة' : 'Claimed',
        'CANCELLED' => isAr ? 'ملغاة' : 'Cancelled',
        _ => isAr ? 'مسودة' : 'Draft',
      };

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final hasActions = onViewDetails != null || onFileClaim != null || onPrint != null;

    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderOf(context)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.charcoal.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.shield_rounded, color: AppTheme.cobalt, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _policyNumber,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            splashRadius: 16,
                            tooltip: isAr ? 'نسخ رقم الوثيقة' : 'Copy Policy Number',
                            onPressed: () => CopyHelper.copy(context, _policyNumber),
                          ),
                        ],
                      ),
                      if (_certificateCode.isNotEmpty && _certificateCode != _policyNumber)
                        Text(
                          _certificateCode,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondaryOf(context),
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                AppStatusBadge.fromStatus(
                  status: _status,
                  label: _formatStatus(_status, isAr),
                  size: AppStatusBadgeSize.small,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppTheme.borderOf(context)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInfo(
                    context,
                    label: isAr ? 'شركة التأمين' : 'Insurance Company',
                    value: _companyName,
                    icon: Icons.business_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfo(
                    context,
                    label: isAr ? 'القيمة المؤمنة 110% سيف' : 'Insured Value 110% CIF',
                    value: '${_formatNumber(_insuredVal)} $_curr',
                    icon: Icons.monetization_on_outlined,
                    highlight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildInfo(
              context,
              label: isAr ? 'شروط التغطية التأمينية' : 'Coverage Terms',
              value: _formatCoverage(_clause, isAr),
              icon: Icons.verified_user_outlined,
            ),
            if (hasActions) ...[
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppTheme.borderOf(context)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onFileClaim != null) ...[
                    AppButton(
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.danger,
                      icon: Icons.assignment_late_outlined,
                      label: isAr ? 'تسجيل مطالبة هوالك' : 'File Damage Claim',
                      onPressed: onFileClaim,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onPrint != null) ...[
                    AppButton(
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.ghost,
                      icon: Icons.print_rounded,
                      label: isAr ? 'طباعة' : 'Print',
                      onPressed: onPrint,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onViewDetails != null)
                    AppButton(
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.visibility_outlined,
                      label: isAr ? 'عرض الوثيقة' : 'View Policy',
                      onPressed: onViewDetails,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, {required String label, required String value, required IconData icon, bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context), fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: highlight ? AppTheme.cobalt : AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}
