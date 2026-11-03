import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/financial_approval_model.dart';
import '../financial_ui.dart';

class SwiftMatchingMatrixBox extends ConsumerWidget {
  final List<PaymentRequestModel> paymentsList;
  final int? selectedPaymentIdForReconcile;
  final Map<String, dynamic>? extractedSwift;
  final Map<String, dynamic>? matchedPayment;
  final bool isSmartReconciling;
  final ValueChanged<int> onPaymentSelected;
  final ValueChanged<PaymentRequestModel> onExecuteReconcile;

  const SwiftMatchingMatrixBox({
    super.key,
    required this.paymentsList,
    required this.selectedPaymentIdForReconcile,
    required this.extractedSwift,
    required this.matchedPayment,
    required this.isSmartReconciling,
    required this.onPaymentSelected,
    required this.onExecuteReconcile,
  });

  Widget _buildCompareRow(
    BuildContext context,
    String label,
    String sysVal,
    String swiftVal,
    bool isMatch,
    String badgeText, {
    Color? customBadgeBg,
    Color? customBadgeBorder,
    Color? customBadgeText,
    Widget? trailingAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => CopyHelper.copy(context, sysVal),
                child: Text(
                  sysVal,
                  style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Icon(Icons.arrow_right_alt, color: AppTheme.textMuted, size: 16),
            Expanded(
              child: InkWell(
                onTap: () => CopyHelper.copy(context, swiftVal),
                child: Text(
                  swiftVal,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMatch ? AppTheme.emerald : (customBadgeText ?? AppTheme.crimson),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: customBadgeBg ?? (isMatch ? AppTheme.emeraldLight : AppTheme.crimsonLight),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: customBadgeBorder ?? (isMatch ? AppTheme.emeraldBorder : AppTheme.crimsonBorder),
                ),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: customBadgeText ?? (isMatch ? AppTheme.wcagEmerald : AppTheme.crimson),
                ),
              ),
            ),
          ],
        ),
        if (trailingAction != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 130),
            child: trailingAction,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    PaymentRequestModel? matchedPay;
    if (selectedPaymentIdForReconcile != null) {
      matchedPay = paymentsList.firstWhere(
        (p) => p.paymentId == selectedPaymentIdForReconcile,
        orElse: () => paymentsList.first,
      );
    } else if (matchedPayment != null && matchedPayment!['payment_id'] != null) {
      matchedPay = paymentsList.firstWhere(
        (p) => p.paymentId == matchedPayment!['payment_id'],
        orElse: () => paymentsList.first,
      );
    }

    if (matchedPay == null) {
      return Center(child: Text(l10n.swiftNoMatchingRecords));
    }

    final score = matchedPayment?['confidence_score'] ?? 100;
    final amtInfo = matchedPayment?['amount_matching'] as Map<String, dynamic>?;
    final isAmtMatched = amtInfo?['is_matched'] ?? false;
    final variance = (amtInfo?['variance'] as num?)?.toDouble() ??
        ((extractedSwift?['amount'] is num)
            ? ((extractedSwift!['amount'] as num).toDouble() - matchedPay.requestedAmount)
            : 0.0);

    final benInfo = matchedPayment?['beneficiary_matching'] as Map<String, dynamic>?;
    final isBenMatched = benInfo?['is_matched'] ?? true;

    final bankInfo = matchedPayment?['bank_swift_matching'] as Map<String, dynamic>?;
    final isSwiftMatched = bankInfo?['is_matched'] ??
        (matchedPay.swiftCode == null ||
            matchedPay.swiftCode == extractedSwift?['beneficiary_bank_swift']);
    final matchedBankType = bankInfo?['matched_bank_type'] as String?;

    final accInfo = matchedPayment?['account_iban_matching'] as Map<String, dynamic>?;
    final isAccMatched = accInfo?['is_matched'] ?? true;

    final mismatchLabel = context.l10n.faMismatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows, color: AppTheme.emerald, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.swiftMatchingMatrixTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.charcoal,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: score >= 80
                    ? AppTheme.emeraldLight
                    : (score >= 50 ? AppTheme.orangeLight : AppTheme.crimsonLight),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: score >= 80 ? AppTheme.emerald : AppTheme.orange,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(score >= 80 ? Icons.check_circle : Icons.warning_amber,
                      size: 13, color: score >= 80 ? AppTheme.emerald : AppTheme.orange),
                  const SizedBox(width: 4),
                  Text(
                    l10n.swiftConfidenceScoreTag(score),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: score >= 80 ? AppTheme.wcagEmerald : AppTheme.wcagOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SearchableDropdownField<int>(
          labelText: l10n.swiftTargetPaymentLabel,
          items: paymentsList.where((p) => p.isActive).map((p) {
            final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
            final isArLocale = Localizations.localeOf(context).languageCode == 'ar';
            final shipName = DisplayNameResolver.resolveShipmentNameByCode(
              p.importFileCode,
              shipments: allFiles,
              isArabic: isArLocale,
            );
            final shipBadge = (shipName.isNotEmpty && shipName != '-') ? ' [$shipName]' : '';
            return SearchableDropdownItem<int>(
              value: p.paymentId,
              label:
                  '${p.paymentCode}$shipBadge - ${p.supplierName} (${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}) [${p.status}]',
              icon: Icons.receipt_long,
            );
          }).toList(),
          value: matchedPay.paymentId,
          onChanged: (val) {
            if (val != null) onPaymentSelected(val);
          },
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.cloudWhite),
          ),
          child: Column(
            children: [
              _buildCompareRow(
                context,
                '${l10n.swiftRequestedAmountLabel}:',
                '${matchedPay.requestedAmount.toStringAsFixed(2)} ${matchedPay.currencyCode}',
                '${extractedSwift?['amount'] ?? '-'} ${extractedSwift?['currency'] ?? '-'}',
                isAmtMatched,
                isAmtMatched
                    ? (variance == 0.0
                        ? l10n.swiftBadgeMatchedFull
                        : l10n.swiftBadgeDeficit(variance.abs().toStringAsFixed(2), matchedPay.currencyCode))
                    : mismatchLabel,
              ),
              const Divider(height: 12),
              _buildCompareRow(
                context,
                l10n.swiftBeneficiaryLabel,
                matchedPay.beneficiaryName ?? matchedPay.supplierName,
                extractedSwift?['beneficiary_name'] ?? '-',
                isBenMatched,
                isBenMatched ? l10n.swiftBadgeMatchedFull : mismatchLabel,
              ),
              const Divider(height: 12),
              _buildCompareRow(
                context,
                context.l10n.faBeneficiarySwift57a,
                matchedPay.swiftCode ?? '-',
                extractedSwift?['beneficiary_bank_swift'] ?? '-',
                isSwiftMatched && matchedBankType != 'SENDER_BANK',
                (isSwiftMatched && matchedBankType != 'SENDER_BANK')
                    ? l10n.swiftBadgeMatchedFull
                    : (matchedBankType == 'SENDER_BANK'
                        ? (context.l10n.faMatchedSenderBank)
                        : mismatchLabel),
                customBadgeBg: matchedBankType == 'SENDER_BANK' ? AppTheme.orangeLight : null,
                customBadgeBorder: matchedBankType == 'SENDER_BANK' ? AppTheme.orange : null,
                customBadgeText: matchedBankType == 'SENDER_BANK' ? AppTheme.wcagOrange : null,
              ),
              if (extractedSwift?['sender_bank_swift'] != null &&
                  extractedSwift!['sender_bank_swift'].toString().isNotEmpty) ...[
                const Divider(height: 12),
                _buildCompareRow(
                  context,
                  context.l10n.faRemittingBankEg,
                  extractedSwift!['sender_bank_name'] ?? (context.l10n.faRemittingBankInEgypt),
                  extractedSwift!['sender_bank_swift'],
                  true,
                  context.l10n.faIssuingBank,
                  customBadgeBg: AppTheme.cobaltLight,
                  customBadgeBorder: AppTheme.cobaltBorder,
                  customBadgeText: AppTheme.wcagCobalt,
                ),
              ],
              const Divider(height: 12),
              _buildCompareRow(
                context,
                l10n.swiftAccountLabel,
                matchedPay.ibanAccountNo ?? '-',
                extractedSwift?['beneficiary_account_or_iban'] ?? '-',
                isAccMatched,
                isAccMatched ? l10n.swiftBadgeMatchedFull : mismatchLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FinancialUi.fit(AppButton(
            label: l10n.swiftExecuteReconcileBtn,
            variant: AppButtonVariant.success,
            icon: Icons.verified,
            isLoading: isSmartReconciling,
            onPressed: isSmartReconciling ? null : () => onExecuteReconcile(matchedPay!),
          )),
        ),
      ],
    );
  }
}
