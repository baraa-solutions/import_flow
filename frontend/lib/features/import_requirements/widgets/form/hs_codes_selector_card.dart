import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_requirement_model.dart';

/// 🏷️ HS Codes & Commodities Selector Card — ImportFlow ERP
///
/// Displays multiple HS Code sequence chips with compliance status indicators,
/// and provides controllers for editing item tariff code, description, origin, and values.
class HsCodesSelectorCard extends StatelessWidget {
  final List<ImportRequirementHSCodeItemModel> hsCodeItems;
  final int selectedHsItemIndex;
  final ValueChanged<int> onHsItemSelected;
  final TextEditingController hsCodeCtrl;
  final TextEditingController descCtrl;
  final TextEditingController originCtrl;
  final TextEditingController currencyCtrl;
  final TextEditingController valueCtrl;

  // Active item compliance checks
  final bool isDecree43Applicable;
  final bool isWhiteListVerified;
  final String? decree43Action;
  final bool isCooRequired;
  final String cooStatus;
  final bool isInspectionRequired;
  final String inspectionStatus;
  final bool isImportPermitRequired;
  final String permitStatus;
  final bool isPostAcidConfirmed;

  const HsCodesSelectorCard({
    super.key,
    required this.hsCodeItems,
    required this.selectedHsItemIndex,
    required this.onHsItemSelected,
    required this.hsCodeCtrl,
    required this.descCtrl,
    required this.originCtrl,
    required this.currencyCtrl,
    required this.valueCtrl,
    required this.isDecree43Applicable,
    required this.isWhiteListVerified,
    this.decree43Action,
    required this.isCooRequired,
    required this.cooStatus,
    required this.isInspectionRequired,
    required this.inspectionStatus,
    required this.isImportPermitRequired,
    required this.permitStatus,
    required this.isPostAcidConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cloudWhite),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.hsCodesSelectorCardTitle(hsCodeItems.length),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.emerald),
                ),
                child: Text(
                  l10n.totalHsValueBadge(valueCtrl.text, currencyCtrl.text),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Multiple HS Items Chips
          if (hsCodeItems.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.charcoalSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cloudWhite),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.alt_route_rounded, color: AppTheme.cobalt, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        l10n.hsCodeSequenceNavTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                      ),
                      const Spacer(),
                      Text(
                        l10n.requirementSelectHsInstruction,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(hsCodeItems.length, (idx) {
                      final itm = hsCodeItems[idx];
                      final isSelected = selectedHsItemIndex == idx;

                      final fulfilledCount = isSelected
                          ? [
                              (!isDecree43Applicable || isWhiteListVerified || decree43Action == 'justified'),
                              (!isCooRequired || cooStatus == 'Obtained'),
                              (!isInspectionRequired || inspectionStatus == 'Completed'),
                              (!isImportPermitRequired || permitStatus == 'Approved'),
                              isPostAcidConfirmed,
                            ].where((b) => b).length
                          : itm.fulfilledPillarsCount;

                      final isFullyCompliant = isSelected ? (fulfilledCount == 5) : itm.isFullyCompliant;

                      final isDecree43Warning = isSelected
                          ? (isDecree43Applicable && !isWhiteListVerified && decree43Action != 'justified')
                          : (itm.decree43Applicable && !itm.whiteListVerified && itm.decree43Action != 'justified');

                      return InkWell(
                        onTap: () => onHsItemSelected(idx),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.cobaltLight : AppTheme.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.cobalt : AppTheme.cloudWhite,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected ? AppTheme.cobalt : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        l10n.hsItemCodeLabel(itm.hsCode, itm.itemCode ?? 'Item'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isFullyCompliant
                                              ? AppTheme.emerald.withValues(alpha: 0.12)
                                              : (isDecree43Warning ? AppTheme.crimsonLight : AppTheme.charcoalSurface),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isFullyCompliant
                                                ? AppTheme.emerald
                                                : (isDecree43Warning ? AppTheme.crimson : AppTheme.cloudWhite),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isFullyCompliant
                                                  ? Icons.check
                                                  : (isDecree43Warning ? Icons.warning_amber_rounded : Icons.pending_actions),
                                              size: 11,
                                              color: isFullyCompliant
                                                  ? AppTheme.emerald
                                                  : (isDecree43Warning ? AppTheme.crimson : AppTheme.textStrong),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              isFullyCompliant
                                                  ? l10n.hsCodeFullyCompliantChip
                                                  : (isDecree43Warning
                                                      ? l10n.decree43NotRegisteredBadge
                                                      : l10n.requirementPillarsProgressBadge(fulfilledCount)),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isFullyCompliant
                                                    ? AppTheme.emerald
                                                    : (isDecree43Warning ? AppTheme.crimson : AppTheme.textStrong),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.hsItemDescLabel(itm.commodityDescription ?? '', itm.itemValue.toStringAsFixed(2), itm.currency),
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textStrong),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

          // Primary HS Code Detail Fields
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: hsCodeCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.hsCodeFieldLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.qr_code_2, color: AppTheme.cobalt, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        hsCodeCtrl.text,
                        customMessage: l10n.requirementCopySummarySuccess,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.hsCodeRequiredError : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.commodityDescFieldLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.description, color: AppTheme.cobalt, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        descCtrl.text,
                        customMessage: l10n.requirementCopySummarySuccess,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commodityDescRequiredError : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: originCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.countryOfOriginFieldLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.public, color: AppTheme.cobalt, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        originCtrl.text,
                        customMessage: l10n.requirementCopySummarySuccess,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.countryOfOriginRequiredError : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: currencyCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.currencyFieldLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        currencyCtrl.text,
                        customMessage: l10n.requirementCopySummarySuccess,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: valueCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.valueInCurrencyFieldLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.monetization_on, color: AppTheme.emerald, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        valueCtrl.text,
                        customMessage: l10n.requirementCopySummarySuccess,
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
