import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';
import '../widgets/add_agreement_dialog.dart';
import '../widgets/tariff_form_dialog.dart';
import '../widgets/verify_tariff_dialog.dart';
import 'anti_dumping_hazard_card.dart';

  void showNafezaDetailsDialog(
      BuildContext context, WidgetRef ref, CustomsTariffModel tariff) {
    final l10n = context.l10n;
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SelectionArea(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ref
                  .read(customsTariffProvider.notifier)
                  .fetchAgreements(tariff.hsCode),
              builder: (context, snapshot) {
                final agreements = snapshot.data ?? [];
                final isLoadingAgreements =
                    snapshot.connectionState == ConnectionState.waiting;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Modal Header matching Screenshot
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.article_outlined,
                                color: AppTheme.charcoal, size: 26),
                            const SizedBox(width: 8),
                            Text(
                              l10n.nafezaDetailsModalTitle,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print_outlined,
                                  color: AppTheme.cobalt, size: 20),
                              tooltip: l10n.exportTariffPdfBtn,
                              onPressed: () => MasterDataExportService.printOrSaveTariffPdf(
                                  tariff, agreements),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded,
                                  color: AppTheme.cobalt, size: 20),
                              tooltip: l10n.nafezaDetailsCopyTooltip,
                              onPressed: () => _copyTariffSummary(
                                  context, tariff, agreements, isArabic),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 1),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item Code & Description Section
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  color: AppTheme.charcoal, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: l10n.itemNumberLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                TextSpan(
                                  text: tariff.hsCode,
                                  style: const TextStyle(
                                    color: AppTheme.cobalt,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  color: AppTheme.charcoal, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: l10n.itemDescriptionLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                TextSpan(
                                  text: tariff.hsDescription,
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          if (tariff.hasAntiDumpingRisk)
                            AntiDumpingHazardCard(tariff: tariff),
                          const SizedBox(height: 16),
                          const Divider(height: 20, thickness: 1),

                          // Taxes Breakdown Section matching Screenshot
                          Text(
                            l10n.taxesSectionHeader,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.charcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _taxDetailRow(l10n.importDutyLabel,
                                    '${tariff.customsDutyRate.toStringAsFixed(3)} %'),
                                _taxDetailRow(l10n.scheduleTaxLabel,
                                    '${tariff.scheduleTaxRate.toStringAsFixed(3)} %'),
                                _taxDetailRow(l10n.vatLabel,
                                    '${tariff.vatRate.toStringAsFixed(3)} %'),
                                if (tariff.developmentFeeRate > 0)
                                  _taxDetailRow(l10n.developmentFeeLabel,
                                      '${tariff.developmentFeeRate.toStringAsFixed(3)} %'),
                                if (tariff.importFeeRate > 0)
                                  _taxDetailRow(l10n.importFeeLabel,
                                      '${tariff.importFeeRate.toStringAsFixed(3)} %'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 20, thickness: 1),

                          // Rules, Trade Agreements & Regulatory Notes matching Screenshot
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.documentsAndProceduresHeader,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoal,
                                ),
                              ),
                              if (isLoadingAgreements)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppTheme.cobalt),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Items List with Blue Left/Right Vertical Border matching Nafeza UI in screenshot
                          _buildNafezaRulesList(tariff, agreements),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Modal Footer Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.emerald,
                            side: const BorderSide(color: AppTheme.emerald),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.verified, size: 18),
                          label: Text(l10n.verifyTariffBtn),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showVerifyTariffDialog(context, ref, tariff);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cobalt,
                            side: const BorderSide(color: AppTheme.cobalt),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.handshake_outlined, size: 18),
                          label: Text(l10n.addPreferentialAgreementBtn),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showAddAgreementDialog(
                                context, ref, tariff.hsCode);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(l10n.editTariffBtn),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showTariffDialog(context, ref, tariff: tariff);
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

  void _copyTariffSummary(BuildContext context, CustomsTariffModel tariff,
      List<Map<String, dynamic>> agreements, bool isArabic) {
    final buffer = StringBuffer();
    if (isArabic) {
      buffer.writeln('بيانات التعريفة الجمركية - منصة نافذة');
      buffer.writeln('بند التعريفة الجمركية: ${tariff.hsCode}');
      buffer.writeln('الوصف: ${tariff.hsDescription}');
      buffer.writeln('ضريبة الوارد: ${tariff.customsDutyRate.toStringAsFixed(3)}%');
      buffer.writeln('ضريبة الجدول: ${tariff.scheduleTaxRate.toStringAsFixed(3)}%');
      buffer.writeln('ضريبة القيمة المضافة: ${tariff.vatRate.toStringAsFixed(3)}%');
      if (tariff.developmentFeeRate > 0) {
        buffer.writeln('رسم التنمية: ${tariff.developmentFeeRate.toStringAsFixed(3)}%');
      }
      if (tariff.importFeeRate > 0) {
        buffer.writeln('رسم الوارد: ${tariff.importFeeRate.toStringAsFixed(3)}%');
      }
      if (agreements.isNotEmpty) {
        buffer.writeln('الاتفاقيات التفضيلية:');
        for (final ag in agreements) {
          final name = ag['agreement_name'] ?? 'اتفاقية';
          final red = _numToDouble(ag['reduction_percentage'], 1.0);
          buffer.writeln('- $name: تخفيض ${(red * 100).toStringAsFixed(0)}%');
        }
      }
      if (tariff.priorApprovalNote != null && tariff.priorApprovalNote!.isNotEmpty) {
        buffer.writeln('الموافقات المسبقة: ${tariff.priorApprovalNote}');
      }
    } else {
      buffer.writeln('Customs Tariff Details - Nafeza Portal');
      buffer.writeln('HS Code: ${tariff.hsCode}');
      buffer.writeln('Description: ${tariff.hsDescription}');
      buffer.writeln('Import Duty: ${tariff.customsDutyRate.toStringAsFixed(3)}%');
      buffer.writeln('Schedule Tax: ${tariff.scheduleTaxRate.toStringAsFixed(3)}%');
      buffer.writeln('VAT: ${tariff.vatRate.toStringAsFixed(3)}%');
      if (tariff.developmentFeeRate > 0) {
        buffer.writeln('Development Fee: ${tariff.developmentFeeRate.toStringAsFixed(3)}%');
      }
      if (tariff.importFeeRate > 0) {
        buffer.writeln('Import Fee: ${tariff.importFeeRate.toStringAsFixed(3)}%');
      }
      if (agreements.isNotEmpty) {
        buffer.writeln('Preferential Agreements:');
        for (final ag in agreements) {
          final name = ag['agreement_name'] ?? 'Agreement';
          final red = _numToDouble(ag['reduction_percentage'], 1.0);
          buffer.writeln('- $name: Reduction ${(red * 100).toStringAsFixed(0)}%');
        }
      }
      if (tariff.priorApprovalNote != null && tariff.priorApprovalNote!.isNotEmpty) {
        buffer.writeln('Prior Approval: ${tariff.priorApprovalNote}');
      }
    }
    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: isArabic
          ? context.l10n.nafezaDetailsCopySuccess
          : 'Tariff details copied to clipboard',
    );
  }

Widget _taxDetailRow(String label, String rateStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label :',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
            ),
          ),
          Text(
            rateStr,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.cobalt,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildNafezaRulesList(
      CustomsTariffModel tariff, List<Map<String, dynamic>> agreements) {
    final List<String> rules = [];

    // Preferential Agreements from Database
    for (final ag in agreements) {
      final name = ag['agreement_name'] ?? 'اتفاقية تجارية';
      final red = _numToDouble(ag['reduction_percentage'], 1.0);
      final pctStr = (red * 100).toStringAsFixed(0);
      final cond = ag['conditions_note'] != null &&
              ag['conditions_note'].toString().isNotEmpty
          ? ' - ${ag['conditions_note']}'
          : '';
      rules.add('ر ${ag['agreement_id'] ?? 6722} - $name تخفيض $pctStr%$cond');
    }

    // Prior Approval Note & Regulatory Conditions matching screenshot
    if (tariff.priorApprovalNote != null &&
        tariff.priorApprovalNote!.isNotEmpty) {
      rules.add('ق 4518 - ${tariff.priorApprovalNote}');
    } else if (tariff.regulatoryAuthority != null &&
        tariff.regulatoryAuthority!.isNotEmpty) {
      rules.add(
          'ق 4518 - لا يصرح باستيراد صنف إلا بموافقة مختومة بخاتم شعار الجمهورية من ${tariff.regulatoryAuthority}');
    }

    // Standard Nafeza Inspection Rule if required
    if (tariff.requiresInspection) {
      rules.add(
          'ق 4547 - يشترط للإفراج عن الصنف وارد تجار أن يكون إنتاج مصانع مسجلة من شركات مالكة للعلامة أو مطبقاً للائحة الفحص المعتمدة');
    }

    // Anti-Dumping Rules from Nafeza
    if (tariff.antiDumpingNotes != null && tariff.antiDumpingNotes!.isNotEmpty) {
      for (final noteLine in tariff.antiDumpingNotes!.split('\n')) {
        final trimmed = noteLine.trim();
        if (trimmed.isNotEmpty && !rules.contains(trimmed)) {
          rules.add(trimmed);
        }
      }
    }

    // General VAT Rule matching screenshot (ر 7042 - يحصل ضريبة قيمة مضافة بمقدار14% [عام])
    rules.add(
        'ر 7042 - يحصل ضريبة قيمة مضافة بمقدار ${tariff.vatRate.toStringAsFixed(0)}% [عام]');

    // Additional Notes
    if (tariff.notes != null && tariff.notes!.isNotEmpty) {
      rules.add('ق 9994 - ${tariff.notes}');
    }

    return Column(
      children: rules.map((ruleText) {
        final isAntiDumping = ruleText.trim().startsWith('غ') || ruleText.contains('إغراق') || ruleText.contains('اغراق');
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isAntiDumping ? AppTheme.flatCrimson.withValues(alpha: 0.06) : const Color(0xFFF8F9FA),
            border: BorderDirectional(
              start: BorderSide(
                color: isAntiDumping ? AppTheme.flatCrimson : const Color(0xFF1B65A8),
                width: 3.5,
              ),
            ),
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              ruleText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isAntiDumping ? FontWeight.w600 : FontWeight.normal,
                color: isAntiDumping ? AppTheme.flatCrimson : AppTheme.charcoal,
                height: 1.4,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }).toList(),
    );
  }
double _numToDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}
