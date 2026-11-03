import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_consultation_model.dart';
import '../tariff_missing_widgets.dart';

/// Builder for individual table rows in customs tariff details.
class ConsultationCalcItemRow {
  static DataRow buildRow({
    required BuildContext context,
    required CustomsItemCalcRow line,
    required String customsCurrency,
    required AppLocalizations l,
    required bool isArabic,
    required String egpLabel,
  }) {
    final rowSummary = isArabic
        ? '${line.hsCode} | ${line.description} | ${l.quantityAndUnitCol}: ${line.qty.toStringAsFixed(0)} ${line.unit} | ${l.fobEgpCol}: ${line.fobEgp.toStringAsFixed(2)} $egpLabel | ${l.cifEgpCol}: ${line.cifEgp.toStringAsFixed(2)} $egpLabel | ${l.customsDutyCol}: ${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)} $egpLabel) | ${l.vatCol}: ${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)} $egpLabel) | ${l.totalTaxesAndDutiesCol}: ${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel'
        : '${line.hsCode} | ${line.description} | Qty: ${line.qty.toStringAsFixed(0)} ${line.unit} | FOB: ${line.fobEgp.toStringAsFixed(2)} $egpLabel | CIF: ${line.cifEgp.toStringAsFixed(2)} $egpLabel | Duty: ${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)} $egpLabel) | VAT: ${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)} $egpLabel) | Total: ${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel';

    return DataRow(
      cells: [
        DataCell(
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
            tooltip: l.copyTooltip,
            onPressed: () => CopyHelper.copy(
              context,
              rowSummary,
              customMessage: l.customsTaxCopyRowSuccess,
            ),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: line.hsCode,
            rowSummary: rowSummary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    line.hsCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cobalt,
                    ),
                  ),
                ),
                if (line.isTariffMissing) ...[
                  const SizedBox(width: 4),
                  const TariffMissingBadge(),
                ],
              ],
            ),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value:
                '${line.description}${line.countryOfOrigin != null ? " - ${line.countryOfOrigin}" : ""}',
            rowSummary: rowSummary,
            child: SizedBox(
              width: 190,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    line.description,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (line.countryOfOrigin != null &&
                      line.countryOfOrigin!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.cobaltLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cobaltBorder),
                      ),
                      child: Text(
                        line.countryOfOrigin!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.wcagCobalt,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: '${line.qty.toStringAsFixed(0)} ${line.unit}',
            rowSummary: rowSummary,
            child: Text('${line.qty.toStringAsFixed(0)} ${line.unit}'),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: '${line.foreignPrice.toStringAsFixed(2)} $customsCurrency',
            rowSummary: rowSummary,
            child: Text(
              '${line.foreignPrice.toStringAsFixed(2)} $customsCurrency',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.cobalt,
              ),
            ),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: !line.isCalculated
                ? '—'
                : '${line.fobEgp.toStringAsFixed(2)} $egpLabel',
            rowSummary: rowSummary,
            child: Text(
                !line.isCalculated ? '—' : line.fobEgp.toStringAsFixed(2)),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: !line.isCalculated
                ? '—'
                : '${line.cifEgp.toStringAsFixed(2)} $egpLabel',
            rowSummary: rowSummary,
            child: Text(
              !line.isCalculated ? '—' : line.cifEgp.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: !line.isCalculated
                ? '—'
                : '${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)} $egpLabel)',
            rowSummary: rowSummary,
            child: !line.isCalculated
                ? const Text('—',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (line.hasExemption) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${line.baseDutyRate}%',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.emerald,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.emeraldBorder),
                          ),
                          child: Text(
                            line.appliedAgreementName ?? l.ccExemption,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppTheme.wcagEmerald,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                            '${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)})'),
                      ],
                    ],
                  ),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: !line.isCalculated
                ? '—'
                : '${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)} $egpLabel)',
            rowSummary: rowSummary,
            child: !line.isCalculated
                ? const Text('—',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ))
                : Text(
                    '${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)})'),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: !line.isCalculated
                ? '—'
                : '${(line.scheduleTaxAmountEgp + line.developmentFeeAmountEgp + line.customsServiceFeeAmountEgp).toStringAsFixed(2)} $egpLabel',
            rowSummary: rowSummary,
            child: !line.isCalculated
                ? const Text('—',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ))
                : Text(
                    '${(line.scheduleTaxAmountEgp + line.developmentFeeAmountEgp + line.customsServiceFeeAmountEgp).toStringAsFixed(2)} $egpLabel'),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: !line.isCalculated
                ? '—'
                : '${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel',
            rowSummary: rowSummary,
            child: !line.isCalculated
                ? const Text('—',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ))
                : Text(
                    '${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.crimson,
                    ),
                  ),
          ),
        ),
        DataCell(
          line.isTariffMissing
              ? const TariffMissingBadge()
              : !line.isCalculated
                  ? const Text('—',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                      ))
                  : Row(
                      children: [
                        if (line.requiresAcid)
                          Container(
                            margin: const EdgeInsetsDirectional.only(start: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cobaltBorder,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l.ccACID,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cobalt,
                              ),
                            ),
                          ),
                        if (line.requiresCoo)
                          Container(
                            margin: const EdgeInsetsDirectional.only(start: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldBorder,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l.ccCOO,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.emerald,
                              ),
                            ),
                          ),
                        if (line.requiresInspection)
                          Container(
                            margin: const EdgeInsetsDirectional.only(start: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.orangeLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l.ccGOEIC,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.orange,
                              ),
                            ),
                          ),
                        if (line.regulatoryAuthority != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cobaltLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              line.regulatoryAuthority!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cobalt,
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}
