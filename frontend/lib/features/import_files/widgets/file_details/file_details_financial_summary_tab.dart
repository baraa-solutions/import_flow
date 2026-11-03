// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../models/import_file_model.dart';
import '../../../comprehensive_report/models/comprehensive_dossier_model.dart';
import '../logistics_shipment_expenses_summary_card.dart';
import 'file_details_action_handler.dart';
import 'financial_fx_reconciliation_card.dart';

/// 💰 Financial Summary tab for Import File Details
/// Displays executive landed cost breakdown, FX currency reconciliation,
/// logistics service invoices, customs duties, clearance fees, and simulation actions.
class FileDetailsFinancialSummaryTab extends ConsumerWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;

  const FileDetailsFinancialSummaryTab({
    super.key,
    required this.file,
    this.dossier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final actualLanded = dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp;
    final variancePct = dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct;
    final varianceEgp = dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp;
    final hasVariance = actualLanded > 0 && varianceEgp != 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Landed Cost Overview Card ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cloudWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? 'ملخص تكلفة الوصول والتسوية المحاسبية' : 'Landed Cost & Settlement Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                    if (actualLanded > 0)
                      AppStatusBadge(
                        label: isAr
                            ? (hasVariance
                                ? 'تمت التسوية مع فروق (${variancePct > 0 ? "+" : ""}${variancePct.toStringAsFixed(1)}%)'
                                : 'تمت التسوية المطابقة')
                            : (hasVariance
                                ? 'Settled with Variance (${variancePct > 0 ? "+" : ""}${variancePct.toStringAsFixed(1)}%)'
                                : 'Settled Matched'),
                        severity: hasVariance
                            ? (variancePct.abs() > 5 ? AppSeverity.danger : AppSeverity.warning)
                            : AppSeverity.success,
                      )
                    else
                      AppStatusBadge(
                        label: isAr ? 'بانتظار التسوية المحاسبية' : 'Pending Settlement',
                        severity: AppSeverity.info,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFinancialTile(
                        title: isAr ? 'التكلفة التقديرية' : 'Estimated Cost',
                        value: file.estimatedCost > 0 ? '${file.estimatedCost.toStringAsFixed(0)} \$' : '—',
                        subtitle: isAr ? 'التقدير الأولي للملف' : 'Initial file estimate',
                        color: AppTheme.cobalt,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFinancialTile(
                        title: isAr ? 'إجمالي تكلفة الوصول الفعلية' : 'Actual Landed Total',
                        value: actualLanded > 0 ? '${actualLanded.toStringAsFixed(0)} EGP' : '—',
                        subtitle: isAr ? 'شامل الجمارك والمصاريف' : 'Inclusive of duties & fees',
                        color: AppTheme.emerald,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFinancialTile(
                        title: isAr ? 'فروق التكلفة (EGP)' : 'Cost Variance (EGP)',
                        value: varianceEgp != 0 ? '${varianceEgp > 0 ? "+" : ""}${varianceEgp.toStringAsFixed(0)} EGP' : '—',
                        subtitle: variancePct != 0 ? '${variancePct > 0 ? "+" : ""}${variancePct.toStringAsFixed(1)}%' : (isAr ? 'لا يوجد انحراف' : 'No variance'),
                        color: hasVariance
                            ? (variancePct.abs() > 5 ? AppTheme.crimson : AppTheme.orange)
                            : AppTheme.emerald,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFinancialTile(
                        title: isAr ? 'إجمالي الرسوم الجمركية' : 'Customs Duties Total',
                        value: (file.customsDutyPaidAmount > 0)
                            ? '${file.customsDutyPaidAmount.toStringAsFixed(0)} EGP'
                            : '—',
                        subtitle: file.customsDutyPaymentStatus ?? (isAr ? 'لم تسدد بعد' : 'Unpaid'),
                        color: file.customsDutyPaymentStatus == 'PAID' ? AppTheme.emerald : AppTheme.orange,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── FX Currency Reconciliation Card ───────────────────────────────
          FinancialFxReconciliationCard(
            dossier: dossier,
            isDark: isDark,
            isAr: isAr,
          ),
          const SizedBox(height: 14),

          // ── Detailed Logistics Invoices & Expenses ────────────────────────
          LogisticsShipmentExpensesSummaryCard(file: file),
          const SizedBox(height: 14),

          // ── Financial Simulations & Settlement Operations ─────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElevatedSurface : Colors.blue.shade50.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: AppTheme.cobalt, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isAr ? 'محاكاة وإجراءات التسوية المالية الفورية:' : 'Quick Financial Simulation & Settlement Actions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    AppButton(
                      label: isAr ? 'طلب دفعة المورد' : 'Supplier Payment Request',
                      icon: Icons.payments_outlined,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.primary,
                      onPressed: () => FileDetailsActionHandler.handleSimulationAction(
                        context,
                        ref,
                        file,
                        'fn01_supplier_payment',
                      ),
                    ),
                    AppButton(
                      label: isAr ? 'تحويل مصاريف الشحن' : 'Freight Payment Transfer',
                      icon: Icons.local_shipping_outlined,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => FileDetailsActionHandler.handleSimulationAction(
                        context,
                        ref,
                        file,
                        'fn02_freight_payment',
                      ),
                    ),
                    AppButton(
                      label: isAr ? 'طلب نموذج 4' : 'Form 4 Bank Request',
                      icon: Icons.account_balance_outlined,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => FileDetailsActionHandler.handleSimulationAction(
                        context,
                        ref,
                        file,
                        'fn03_form4_request',
                      ),
                    ),
                    AppButton(
                      label: isAr ? 'استلام نموذج 4' : 'Form 4 Received',
                      icon: Icons.mark_email_read_outlined,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => FileDetailsActionHandler.handleSimulationAction(
                        context,
                        ref,
                        file,
                        'fn04_form4_received',
                      ),
                    ),
                    AppButton(
                      label: isAr ? 'سداد إذن التسليم' : 'Delivery Order Payment',
                      icon: Icons.directions_boat_filled_rounded,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => FileDetailsActionHandler.handleSimulationAction(
                        context,
                        ref,
                        file,
                        'cs02_delivery_order',
                      ),
                    ),
                    AppButton(
                      label: isAr ? 'سداد الرسوم الجمركية' : 'Customs Duty Payment',
                      icon: Icons.receipt_long_rounded,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.success,
                      onPressed: () => FileDetailsActionHandler.handleSimulationAction(
                        context,
                        ref,
                        file,
                        'cl03_duty_payment',
                      ),
                    ),
                    AppButton(
                      label: isAr ? 'التكلفة الفعلية الفردية' : 'Actual Landed Cost',
                      icon: Icons.fact_check_outlined,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => FileDetailsActionHandler.handleSimulationAction(
                        context,
                        ref,
                        file,
                        'clo02_actual_landed',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTile({
    required String title,
    required String value,
    required String subtitle,
    Color? color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppTheme.darkTextMuted : Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
