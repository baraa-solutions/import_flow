import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../l10n/valuation_uplift_l10n.dart';
import '../widgets/valuation_uplift_card.dart';

/// 🏛️ Customs Declaration 46 Screen — ImportFlow ERP (EPIC-CUST-VAL)
///
/// Features registration of Form 46 K.M, integration with Nafeza MTS,
/// and live Valuation Uplift comparison (Commercial CIF vs Accepted Customs CIF).
class CustomsDeclaration46Screen extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final int initialSubTab;

  const CustomsDeclaration46Screen({
    super.key,
    this.initialImportFileId,
    this.initialSubTab = 0,
  });

  @override
  ConsumerState<CustomsDeclaration46Screen> createState() =>
      _CustomsDeclaration46ScreenState();
}

class _CustomsDeclaration46ScreenState
    extends ConsumerState<CustomsDeclaration46Screen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _declaration46NoController;
  late TextEditingController _mtsCertController;
  late TextEditingController _customsOfficeController;
  late TextEditingController _commercialCifController;
  late TextEditingController _assessedCifController;
  late TextEditingController _upliftReasonController;
  late TextEditingController _exchangeRateController;

  bool _isValuationUplifted = false;
  double _commercialCifEgp = 0.0;
  double _assessedCifEgp = 0.0;
  double _customsExchangeRate = 50.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _declaration46NoController = TextEditingController();
    _mtsCertController = TextEditingController();
    _customsOfficeController = TextEditingController(text: 'Alexandria Port Customs');
    _commercialCifController = TextEditingController(text: '0.00');
    _assessedCifController = TextEditingController(text: '0.00');
    _upliftReasonController = TextEditingController();
    _exchangeRateController = TextEditingController(text: '50.00');

    Future.microtask(() {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _declaration46NoController.dispose();
    _mtsCertController.dispose();
    _customsOfficeController.dispose();
    _commercialCifController.dispose();
    _assessedCifController.dispose();
    _upliftReasonController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    ref.read(importFilesProvider.notifier).fetchImportFiles();
    ref.read(customsClearanceProvider.notifier).fetchRecords();
  }

  void _onValuesChanged() {
    final comm = double.tryParse(_commercialCifController.text.replaceAll(',', '')) ?? 0.0;
    final assess = double.tryParse(_assessedCifController.text.replaceAll(',', '')) ?? 0.0;
    final rate = double.tryParse(_exchangeRateController.text.replaceAll(',', '')) ?? 50.0;

    setState(() {
      _commercialCifEgp = comm;
      _assessedCifEgp = assess;
      _customsExchangeRate = rate > 0 ? rate : 50.0;
      if (_assessedCifEgp > _commercialCifEgp && _commercialCifEgp > 0) {
        _isValuationUplifted = true;
      }
    });
  }

  Future<void> _saveDeclaration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final l = context.l10n;
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.saveDeclarationBtn,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    final commUsd = _customsExchangeRate > 0 ? _commercialCifEgp / _customsExchangeRate : 0.0;
    final assessUsd = _customsExchangeRate > 0 ? _assessedCifEgp / _customsExchangeRate : 0.0;
    final upliftAmount = (_assessedCifEgp > _commercialCifEgp)
        ? (_assessedCifEgp - _commercialCifEgp)
        : 0.0;

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: AppBar(
          title: Text(
            l.customsDeclaration46Title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppTheme.sorourNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadInitialData,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Integrated Valuation Uplift Comparison Card
                ValuationUpliftCard(
                  commercialCifEgp: _commercialCifEgp,
                  customsAssessedCifEgp: _assessedCifEgp,
                  commercialCifUsd: commUsd,
                  customsAssessedCifUsd: assessUsd,
                  customsExchangeRate: _customsExchangeRate,
                  isValuationUplifted: _isValuationUplifted,
                  valuationUpliftAmountEgp: upliftAmount,
                  valuationUpliftReason: _upliftReasonController.text,
                  onRecompute: _onValuesChanged,
                ),
                const SizedBox(height: 24),

                // Form Details Card
                Container(
                  decoration: AppTheme.cardDecorationOf(context),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.customsDeclaration46Title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.sorourNavy,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Row 1: Declaration No & Date
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _declaration46NoController,
                              label: l.declarationNumberLabel,
                              isRequired: true,
                              icon: Icons.numbers,
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _mtsCertController,
                              label: l.mtsCertificateNumberLabel,
                              icon: Icons.assignment_turned_in_outlined,
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _customsOfficeController,
                              label: l.customsOfficeLabel,
                              isRequired: true,
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 2: Valuation CIF Inputs (Commercial vs Assessed) & Exchange Rate
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _commercialCifController,
                              label: l.commercialInvoiceCifLabel,
                              isRequired: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              icon: Icons.shopping_bag_outlined,
                              textDirection: TextDirection.ltr,
                              validator: (val) {
                                if (val == null || val.isEmpty) return context.l10n.requiredField;
                                final d = double.tryParse(val.replaceAll(',', ''));
                                if (d == null || d <= 0) return context.l10n.requiredField;
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _assessedCifController,
                              label: l.customsAssessedCifLabel,
                              isRequired: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              icon: Icons.account_balance_outlined,
                              textDirection: TextDirection.ltr,
                              validator: (val) {
                                if (val == null || val.isEmpty) return context.l10n.requiredField;
                                final d = double.tryParse(val.replaceAll(',', ''));
                                if (d == null || d <= 0) return context.l10n.requiredField;
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _exchangeRateController,
                              label: l.exchangeRateLabel,
                              isRequired: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              icon: Icons.currency_exchange,
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 3: Uplift Reason & Toggle
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: CustomTextField(
                              controller: _upliftReasonController,
                              label: l.valuationReasonLabel,
                              icon: Icons.edit_note,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  l.isValuationUpliftedSwitch,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                value: _isValuationUplifted,
                                activeThumbColor: AppTheme.orange,
                                onChanged: (val) {
                                  setState(() => _isValuationUplifted = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Action Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AppButton(
                            label: l.recalculateUpliftBtn,
                            variant: AppButtonVariant.secondary,
                            icon: Icons.refresh,
                            onPressed: _onValuesChanged,
                          ),
                          const SizedBox(width: 12),
                          AppButton(
                            label: l.saveDeclarationBtn,
                            variant: AppButtonVariant.success,
                            icon: Icons.save,
                            isLoading: _isSaving,
                            onPressed: _saveDeclaration,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
