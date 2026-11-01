import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'duty_calculator/duty_calc_actions_bar.dart';
import 'duty_calculator/duty_calc_freight_insurance_card.dart';
import 'duty_calculator/duty_calc_header.dart';
import 'duty_calculator/duty_calc_invoice_lines_card.dart';
import 'duty_calculator/duty_calc_results_breakdown.dart';
import 'duty_calculator/duty_calculator_state.dart';

export 'duty_calculator/duty_calculator_state.dart' show DutyCalculatorState, numToDouble;
export 'duty_calculator/duty_calc_actions_bar.dart' show copyDutyCalculatorStatement;

/// Opens the Egyptian Customs Duty Calculator dialog (Nafeza platform model).
void showDutyCalculatorDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialHsCode,
  int? initialImportFileId,
  String? initialCurrency,
  double? initialFreightAmount,
  double? initialInsuranceAmount,
  List<Map<String, dynamic>>? initialExtractedLines,
}) {
  showDialog(
    context: context,
    builder: (ctx) => DutyCalculatorDialog(
      initialHsCode: initialHsCode,
      initialImportFileId: initialImportFileId,
      initialCurrency: initialCurrency,
      initialFreightAmount: initialFreightAmount,
      initialInsuranceAmount: initialInsuranceAmount,
      initialExtractedLines: initialExtractedLines,
    ),
  );
}

/// Modular coordinator widget for Egyptian Customs Duty Calculator.
class DutyCalculatorDialog extends ConsumerStatefulWidget {
  final String? initialHsCode;
  final int? initialImportFileId;
  final String? initialCurrency;
  final double? initialFreightAmount;
  final double? initialInsuranceAmount;
  final List<Map<String, dynamic>>? initialExtractedLines;

  const DutyCalculatorDialog({
    super.key,
    this.initialHsCode,
    this.initialImportFileId,
    this.initialCurrency,
    this.initialFreightAmount,
    this.initialInsuranceAmount,
    this.initialExtractedLines,
  });

  @override
  ConsumerState<DutyCalculatorDialog> createState() =>
      _DutyCalculatorDialogState();
}

class _DutyCalculatorDialogState extends ConsumerState<DutyCalculatorDialog> {
  late final DutyCalculatorState _calcState;

  @override
  void initState() {
    super.initState();
    _calcState = DutyCalculatorState(
      initialHsCode: widget.initialHsCode,
      initialCurrency: widget.initialCurrency,
      initialFreightAmount: widget.initialFreightAmount,
      initialInsuranceAmount: widget.initialInsuranceAmount,
      initialExtractedLines: widget.initialExtractedLines,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialImportFileId != null && !_calcState.didAutoSimulate) {
        _calcState.didAutoSimulate = true;
        _calcState.runImportFileSimulation(widget.initialImportFileId!, ref);
      } else if (widget.initialImportFileId == null &&
          !_calcState.didInitialRateLoad) {
        _calcState.didInitialRateLoad = true;
        _calcState.loadInitialRate(ref);
      }
    });
  }

  @override
  void dispose() {
    _calcState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: ListenableBuilder(
        listenable: _calcState,
        builder: (context, _) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.calculate, color: AppTheme.emerald),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'حاسبة الجمارك المصرية — منصة نافذة'
                        : 'Egyptian Customs Duty Calculator — Nafeza Platform',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 860,
              height: 620,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DutyCalcHeader(
                      state: _calcState,
                      initialImportFileId: widget.initialImportFileId,
                      isArabic: isArabic,
                      ref: ref,
                    ),
                    const SizedBox(height: 8),
                    DutyCalcFreightInsuranceCard(
                      state: _calcState,
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 16),
                    DutyCalcInvoiceLinesCard(
                      state: _calcState,
                      isArabic: isArabic,
                      isDark: isDark,
                      ref: ref,
                      initialImportFileId: widget.initialImportFileId,
                    ),
                    const SizedBox(height: 16),
                    DutyCalcPrimaryActionBar(
                      state: _calcState,
                      isArabic: isArabic,
                      ref: ref,
                    ),
                    if (_calcState.multiResult != null) ...[
                      DutyCalcResultsBreakdown(
                        multiResult: _calcState.multiResult!,
                        isArabic: isArabic,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      DutyCalcExportActionBar(
                        state: _calcState,
                        isArabic: isArabic,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isArabic ? 'إغلاق' : 'Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}
