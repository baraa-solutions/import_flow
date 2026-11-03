import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/cbm_calculator_model.dart';

/// Dedicated Search & Clone Dialog for CBM Calculations.
class CbmSearchCloneDialog extends StatefulWidget {
  final List<CBMCalculationModel> calculations;
  final ValueChanged<CBMCalculationModel> onSelectCalculation;

  const CbmSearchCloneDialog({
    super.key,
    required this.calculations,
    required this.onSelectCalculation,
  });

  static Future<CBMCalculationModel?> show(
    BuildContext context, {
    required List<CBMCalculationModel> calculations,
  }) async {
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl ||
        Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final locale = isArabic ? const Locale('ar') : const Locale('en');
    return showDialog<CBMCalculationModel>(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: textDir,
          child: CbmSearchCloneDialog(
            calculations: calculations,
            onSelectCalculation: (calc) {
              Navigator.of(ctx).pop(calc);
            },
          ),
        ),
      ),
    );
  }

  @override
  State<CbmSearchCloneDialog> createState() => _CbmSearchCloneDialogState();
}

class _CbmSearchCloneDialogState extends State<CbmSearchCloneDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<CBMCalculationModel> _filteredCalcs;

  @override
  void initState() {
    super.initState();
    _filteredCalcs = widget.calculations;
    _queryController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _queryController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCalcs = widget.calculations;
      } else {
        _filteredCalcs = widget.calculations.where((calc) {
          final code = calc.calcCode.toLowerCase();
          final title = (calc.title ?? '').toLowerCase();
          final notes = (calc.notes ?? '').toLowerCase();
          final mode =
              '${calc.recommendedShippingMethod ?? ''} ${calc.shippingMethodLabel(context.l10n)}'
                  .toLowerCase();
          return code.contains(query) ||
              title.contains(query) ||
              notes.contains(query) ||
              mode.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      child: SelectionArea(
        child: Container(
          width: math.min(720.0, screenWidth - 32),
          height: math.min(600.0, screenHeight - 64),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.control_point_duplicate_rounded,
                      color: AppTheme.cobalt,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.searchAndCloneCbmDialogTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.searchAndCloneCbmSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              AppSearchField(
                controller: _queryController,
                hint: l.searchByCalcCodeOrTitleHint,
              ),
              const SizedBox(height: 16),

              // Results List
              Expanded(
                child: _filteredCalcs.isEmpty
                    ? AppEmptyState(
                        icon: Icons.search_off_rounded,
                        message: l.noMatchingCalcsFound,
                      )
                    : ListView.separated(
                        itemCount: _filteredCalcs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final calc = _filteredCalcs[idx];
                          final isAir = calc.isAirRecommended;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkElevatedSurface
                                  : AppTheme.charcoalSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.darkBorder
                                    : AppTheme.cloudWhite,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            calc.calcCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.cobalt,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          AppStatusBadge(
                                            label: calc.shippingMethodLabel(l),
                                            severity: isAir
                                                ? AppSeverity.info
                                                : AppSeverity.success,
                                            size: AppStatusBadgeSize.small,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        calc.title ?? calc.calcCode,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 10,
                                        children: [
                                          Text(
                                            '${calc.totalCbm.toStringAsFixed(2)} m³',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.wcagOrange,
                                            ),
                                          ),
                                          Text(
                                            '${calc.totalGrossWeightKg.toStringAsFixed(0)} kg',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppTheme.darkTextSecondary
                                                  : AppTheme.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            '${calc.items.length} ${calc.items.length == 1 ? "item" : "items"}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppTheme.darkTextSecondary
                                                  : AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AppButton(
                                  label: l.cloneRowTooltip,
                                  icon: Icons.copy_rounded,
                                  variant: AppButtonVariant.primary,
                                  size: AppButtonSize.small,
                                  onPressed: () =>
                                      widget.onSelectCalculation(calc),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
