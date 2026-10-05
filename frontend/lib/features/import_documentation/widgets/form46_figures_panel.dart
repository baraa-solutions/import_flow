import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import 'idoc_ui_b.dart';

/// Itemised, right-aligned money table for the Form 46 duties and taxes.
///
/// Presentation only: it renders the four figure controllers owned by the
/// screen (customs value, import duty, VAT, total) and the missing-figures
/// banner. A figure that could not be computed stays empty and shows the
/// missing marker; nothing is estimated here.
class Form46FiguresPanel extends StatelessWidget {
  const Form46FiguresPanel({
    super.key,
    required this.cifCtrl,
    required this.dutyCtrl,
    required this.vatCtrl,
    required this.totalCtrl,
    required this.missing,
    required this.hasFile,
    required this.appliedDutyRate,
    required this.onComponentChanged,
  });

  final TextEditingController cifCtrl;
  final TextEditingController dutyCtrl;
  final TextEditingController vatCtrl;
  final TextEditingController totalCtrl;

  /// Missing inputs reported by the calculator (`tariff`, `fx_rate`, `fob`...).
  final List<String> missing;
  final bool hasFile;
  final double? appliedDutyRate;

  /// Called when the user edits the duty or VAT figure (total is recomputed).
  final VoidCallback onComponentChanged;

  /// Banner text listing the missing inputs.
  static String missingItemsText(AppLocalizations l, List<String> missing) {
    final labels = <String>[
      for (final m in missing)
        if (m == 'tariff')
          l.idocBMissingTariff
        else if (m == 'fx_rate')
          l.idocBMissingFxRate
        else if (m == 'fob_mixed_currency')
          l.idocBMissingFobMixedCurrency
        else
          l.idocBMissingFob,
    ];
    return l.idocBFigureMissingBanner(labels.join(', '));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final incomplete = missing.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasFile)
          IdocBNotice(
            key: const Key('decl46FiguresBanner'),
            severity: incomplete ? AppSeverity.danger : AppSeverity.warning,
            message: incomplete ? missingItemsText(l, missing) : l.idocBFreightInsuranceNote,
          ),
        IdocBMoneyTable(
          itemHeader: l.idocBFigureItemHeader,
          amountHeader: l.idocBFigureAmountHeader,
          lines: [
            IdocBMoneyLine(
              label: l.customsDeclCifValueLabel,
              field: _field(context, const Key('decl46CifField'), cifCtrl, prefix: Icons.monetization_on_outlined),
            ),
            IdocBMoneyLine(
              label: l.customsDeclImportDutyLabel,
              caption: appliedDutyRate == null ? null : l.idocBRateCaption(appliedDutyRate!.toStringAsFixed(1)),
              field: _field(context, const Key('decl46DutyField'), dutyCtrl, onChanged: (_) => onComponentChanged()),
            ),
            IdocBMoneyLine(
              label: l.customsDeclVatLabel,
              field: _field(context, const Key('decl46VatField'), vatCtrl, onChanged: (_) => onComponentChanged()),
            ),
            IdocBMoneyLine(
              label: l.customsDeclTotalDutiesLabel,
              kind: IdocBMoneyKind.total,
              field: _field(context, const Key('decl46TotalDutiesField'), totalCtrl, readOnly: true, emphasised: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    Key key,
    TextEditingController ctrl, {
    bool readOnly = false,
    bool emphasised = false,
    IconData? prefix,
    ValueChanged<String>? onChanged,
  }) {
    final l = context.l10n;
    return TextFormField(
      key: key,
      controller: ctrl,
      readOnly: readOnly,
      textAlign: TextAlign.end,
      textDirection: TextDirection.ltr,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: TextStyle(
        fontWeight: emphasised ? FontWeight.bold : FontWeight.w600,
        fontSize: emphasised ? 15 : 13.5,
        color: emphasised ? AppTheme.crimson : AppTheme.textPrimaryOf(context),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: l.idocBMissing,
        hintStyle: const TextStyle(color: AppTheme.crimson, fontStyle: FontStyle.italic, fontSize: 12.5),
        suffixText: l.egpCurrency,
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: l.customsDeclCopyValueTooltip,
          onPressed: () => CopyHelper.copy(context, ctrl.text),
        ),
        border: const OutlineInputBorder(),
        filled: readOnly,
        fillColor: readOnly ? AppTheme.surfaceAltOf(context) : null,
      ),
    );
  }
}
