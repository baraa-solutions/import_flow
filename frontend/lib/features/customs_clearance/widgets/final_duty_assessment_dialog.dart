import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'customs_ui.dart';

/// Modal dialog for CL-02: Final Duty & Tax Assessment
/// احتساب الرسوم والضرائب الجمركية النهائية ومطابقة مطالبة نافذة MTS
class FinalDutyAssessmentDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const FinalDutyAssessmentDialog({
    super.key,
    required this.file,
    this.clearanceRecord,
  });

  static Future<bool?> show(
    BuildContext context,
    ImportFileModel file, {
    CustomsClearanceModel? clearanceRecord,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FinalDutyAssessmentDialog(
        file: file,
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<FinalDutyAssessmentDialog> createState() =>
      _FinalDutyAssessmentDialogState();
}

class _FinalDutyAssessmentDialogState
    extends ConsumerState<FinalDutyAssessmentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _claimNumberController;
  late TextEditingController _cifBaseController;
  late TextEditingController _exchangeRateController;
  late TextEditingController _importDutyController;
  late TextEditingController _vatController;
  late TextEditingController _scheduleTaxController;
  late TextEditingController _devFeeController;
  late TextEditingController _serviceFeesController;
  late TextEditingController _whtController;
  late TextEditingController _labFeesController;
  late TextEditingController _varianceReasonController;
  late TextEditingController _assessmentNotesController;

  DateTime _claimDate = DateTime.now();
  bool _isSubmitting = false;

  double get _cifBase => double.tryParse(_cifBaseController.text.trim()) ?? 0.0;
  double get _importDuty =>
      double.tryParse(_importDutyController.text.trim()) ?? 0.0;
  double get _vat => double.tryParse(_vatController.text.trim()) ?? 0.0;
  double get _scheduleTax =>
      double.tryParse(_scheduleTaxController.text.trim()) ?? 0.0;
  double get _devFee => double.tryParse(_devFeeController.text.trim()) ?? 0.0;
  double get _serviceFees =>
      double.tryParse(_serviceFeesController.text.trim()) ?? 0.0;
  double get _wht => double.tryParse(_whtController.text.trim()) ?? 0.0;
  double get _labFees => double.tryParse(_labFeesController.text.trim()) ?? 0.0;

  double get _calculatedTotal =>
      _importDuty +
      _vat +
      _scheduleTax +
      _devFee +
      _serviceFees +
      _wht +
      _labFees;

  double get _estimatedTotal {
    final est = widget.clearanceRecord?.estimatedDutyTotal;
    if (est != null && est > 0) {
      return est;
    }
    return 0.0;
  }

  double get _varianceAmount => _estimatedTotal > 0
      ? _calculatedTotal - _estimatedTotal
      : 0.0;

  double get _variancePercentage => _estimatedTotal > 0
      ? (_varianceAmount / _estimatedTotal) * 100
      : 0.0;

  @override
  void initState() {
    super.initState();
    final rec = widget.clearanceRecord;

    _claimNumberController = TextEditingController(
      text: rec?.nafezaClaimNumber ?? '',
    );
    _cifBaseController = TextEditingController(
      text: (rec != null && (rec.cifBaseAmount ?? 0) > 0)
          ? rec.cifBaseAmount!.toStringAsFixed(2)
          : '',
    );
    _exchangeRateController = TextEditingController(
      // No hard-coded rate (DOMAIN_RULES section 2): empty until the user enters the official customs rate.
      // Null (unknown) and the legacy 1.0 placeholder are never pre-filled.
      text: (rec != null &&
              (rec.cifBaseAmount ?? 0) > 0 &&
              (rec.customsExchangeRate ?? 0) > 0 &&
              rec.customsExchangeRate != 1.0)
          ? rec.customsExchangeRate!.toStringAsFixed(2)
          : '',
    );
    _importDutyController = TextEditingController(
      text: (rec != null && (rec.importDutyAmount ?? 0) > 0)
          ? rec.importDutyAmount!.toStringAsFixed(2)
          : '',
    );
    _vatController = TextEditingController(
      text: (rec != null && (rec.vatAmount ?? 0) > 0)
          ? rec.vatAmount!.toStringAsFixed(2)
          : '',
    );
    _scheduleTaxController = TextEditingController(
      text: (rec != null && (rec.scheduleTaxAmount ?? 0) > 0)
          ? rec.scheduleTaxAmount!.toStringAsFixed(2)
          : '0.00',
    );
    _devFeeController = TextEditingController(
      text: (rec != null && (rec.developmentFeeAmount ?? 0) > 0)
          ? rec.developmentFeeAmount!.toStringAsFixed(2)
          : '0.00',
    );
    _serviceFeesController = TextEditingController(
      text: (rec != null && (rec.customsServiceFees ?? 0) > 0)
          ? rec.customsServiceFees!.toStringAsFixed(2)
          : '0.00',
    );
    _whtController = TextEditingController(
      text: (rec != null && (rec.whtAmount ?? 0) > 0)
          ? rec.whtAmount!.toStringAsFixed(2)
          : '0.00',
    );
    _labFeesController = TextEditingController(
      text: (rec != null && (rec.labServiceFees ?? 0) > 0)
          ? rec.labServiceFees!.toStringAsFixed(2)
          : '0.00',
    );
    _varianceReasonController = TextEditingController(
      text: rec?.dutyVarianceReason ?? '',
    );
    _assessmentNotesController = TextEditingController();

    if (rec?.nafezaClaimDate != null) {
      final parsed = DateTime.tryParse(rec!.nafezaClaimDate!);
      if (parsed != null) _claimDate = parsed;
    }
  }

  @override
  void dispose() {
    _claimNumberController.dispose();
    _cifBaseController.dispose();
    _exchangeRateController.dispose();
    _importDutyController.dispose();
    _vatController.dispose();
    _scheduleTaxController.dispose();
    _devFeeController.dispose();
    _serviceFeesController.dispose();
    _whtController.dispose();
    _labFeesController.dispose();
    _varianceReasonController.dispose();
    _assessmentNotesController.dispose();
    super.dispose();
  }

  Future<void> _submitAssessment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'import_file_id': widget.file.importFileId,
        'nafeza_claim_number': _claimNumberController.text.trim(),
        'nafeza_claim_date': _claimDate.toIso8601String(),
        'cif_base_amount': _cifBase,
        'customs_exchange_rate':
            double.parse(_exchangeRateController.text.trim()),
        'import_duty_amount': _importDuty,
        'vat_amount': _vat,
        'schedule_tax_amount': _scheduleTax,
        'development_fee_amount': _devFee,
        'customs_service_fees': _serviceFees,
        'wht_amount': _wht,
        'lab_service_fees': _labFees,
        'actual_duty_total': _calculatedTotal,
        'duty_variance_reason': _varianceReasonController.text.trim().isNotEmpty
            ? _varianceReasonController.text.trim()
            : null,
        'assessment_notes': _assessmentNotesController.text.trim().isNotEmpty
            ? _assessmentNotesController.text.trim()
            : null,
      };
      final claim = _claimNumberController.text.trim();
      final total = CcFormat.money(_calculatedTotal);

      await ref
          .read(customsClearanceProvider.notifier)
          .assessFinalDuties(payload);

      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(context, l.ccAssessSuccess(claim, total), severity: AppSeverity.success),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccAssessError(ApiErrorText.of(l, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon, String? suffixText}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixText: suffixText,
        border: const OutlineInputBorder(),
      );

  Widget _moneyField(
    TextEditingController c,
    String label,
    IconData icon,
    String cur, {
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: c,
        textDirection: TextDirection.ltr,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _dec(label, hint: '0.00', icon: icon, suffixText: cur),
        onChanged: (_) => setState(() {}),
        validator: validator,
      );

  String? Function(String?) _nonNegative(String requiredMsg, String invalidMsg) => (val) {
        if (val == null || val.trim().isEmpty) return requiredMsg;
        final parsed = double.tryParse(val.trim());
        if (parsed == null || parsed < 0) return invalidMsg;
        return null;
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final file = widget.file;
    final cur = l.ccCurrencyShort;

    return CcStageDialogShell(
      title: l.ccAssessTitle,
      icon: Icons.calculate_rounded,
      accent: AppTheme.cobalt,
      maxWidth: 900,
      chips: [
        CcHeaderChip(Icons.folder_outlined, l.ccAssessFileChip(file.importFileCode)),
      ],
      confirmLabel: l.ccAssessConfirm,
      loadingLabel: l.ccDutyConfirming,
      confirmIcon: Icons.check_circle_outline_rounded,
      isSubmitting: _isSubmitting,
      onConfirm: _submitAssessment,
      footerLeading: Text(
        l.ccAssessTotalDue(CcFormat.money(_calculatedTotal)),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimaryOf(context),
        ),
        overflow: TextOverflow.ellipsis,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.ccAssessSubtitle,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
            const SizedBox(height: 14),
            CcFormSection(
              title: l.ccAssessClaimSection,
              icon: Icons.receipt_long_rounded,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _claimNumberController,
                          textDirection: TextDirection.ltr,
                          decoration: _dec(
                            l.ccAssessClaimNoLabel,
                            hint: l.ccAssessClaimNoHint,
                            icon: Icons.confirmation_number_outlined,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return l.ccAssessClaimNoRequired;
                            if (val.trim().length < 3) return l.ccAssessClaimNoTooShort;
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _claimDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _claimDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: _dec(l.ccAssessClaimDateLabel, icon: Icons.calendar_today_outlined),
                            child: Text(CcFormat.date(_claimDate),
                                textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _moneyField(
                          _cifBaseController,
                          l.ccAssessCifLabel,
                          Icons.account_balance_wallet_outlined,
                          cur,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return l.ccAssessCifRequired;
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return l.ccAssessPositiveValue;
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _exchangeRateController,
                          textDirection: TextDirection.ltr,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec(
                            l.ccAssessFxLabel,
                            hint: l.ccCustomsFxRateHint,
                            icon: Icons.currency_exchange_rounded,
                            suffixText: 'EGP/USD',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return l.ccAssessFxRequired;
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return l.ccAssessFxPositive;
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CcFormSection(
              title: l.ccAssessBreakdownSection,
              icon: Icons.pie_chart_outline_rounded,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _moneyField(
                          _importDutyController,
                          l.ccAssessImportDuty,
                          Icons.payments_outlined,
                          cur,
                          validator: _nonNegative(l.ccAssessImportDutyRequired, l.ccAssessInvalidValue),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _moneyField(
                          _vatController,
                          l.ccAssessVat,
                          Icons.price_change_outlined,
                          cur,
                          validator: _nonNegative(l.ccAssessVatRequired, l.ccAssessInvalidValue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _moneyField(
                            _scheduleTaxController, l.ccAssessScheduleTax, Icons.table_chart_outlined, cur),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _moneyField(
                            _devFeeController, l.ccAssessDevFee, Icons.trending_up_rounded, cur),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _moneyField(_serviceFeesController, l.ccAssessServiceFees,
                            Icons.miscellaneous_services_outlined, cur),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _moneyField(
                            _whtController, l.ccAssessWht, Icons.corporate_fare_outlined, cur),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _moneyField(
                            _labFeesController, l.ccAssessLabFees, Icons.biotech_outlined, cur),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildVarianceComparisonCard(l, cur),
            const SizedBox(height: 20),
            CcFormSection(
              title: l.ccAssessNotesSection,
              icon: Icons.note_alt_outlined,
              accent: AppTheme.charcoal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((widget.clearanceRecord?.notes ?? '').trim().isNotEmpty)
                    CcPreviousNotesBox(notes: widget.clearanceRecord!.notes!),
                  TextFormField(
                    key: const Key('assessmentNotesField'),
                    controller: _assessmentNotesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l.ccStepNotesLabel,
                      hintText: l.ccAssessNotesHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVarianceComparisonCard(AppLocalizations l, String cur) {
    final est = _estimatedTotal;
    final act = _calculatedTotal;
    final diff = _varianceAmount;
    final pct = _variancePercentage;

    AppSeverity severity;
    String badgeText;
    IconData badgeIcon;

    if (est == 0) {
      severity = AppSeverity.info;
      badgeText = l.ccAssessBadgeInitial;
      badgeIcon = Icons.info_outline;
    } else if (diff <= 0) {
      severity = AppSeverity.success;
      badgeText = l.ccAssessBadgeSaving((-pct).toStringAsFixed(1));
      badgeIcon = Icons.arrow_downward_rounded;
    } else if (pct <= 10) {
      severity = AppSeverity.warning;
      badgeText = l.ccAssessBadgeMinor(pct.toStringAsFixed(1));
      badgeIcon = Icons.arrow_upward_rounded;
    } else {
      severity = AppSeverity.danger;
      badgeText = l.ccAssessBadgeMajor(pct.toStringAsFixed(1));
      badgeIcon = Icons.warning_amber_rounded;
    }
    final badgeColor = AppTheme.severityForegroundOf(context, severity);

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, severity),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(badgeIcon, color: badgeColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.ccAssessVarianceTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              CcStatusChip(label: badgeText, severity: severity),
            ],
          ),
          const SizedBox(height: 14),
          CcFieldRow(
            gap: 12,
            children: [
              _buildMetricTile(
                l.ccAssessEstimatedTile,
                est > 0 ? '${CcFormat.money(est)} $cur' : l.ccAssessNotSet,
                Icons.receipt_outlined,
                AppTheme.textSecondaryOf(context),
              ),
              _buildMetricTile(
                l.ccAssessActualTile,
                '${CcFormat.money(act)} $cur',
                Icons.account_balance_outlined,
                AppTheme.cobalt,
              ),
              _buildMetricTile(
                l.ccAssessVarianceTile,
                est > 0 ? '${CcFormat.signedMoney(diff)} $cur' : '---',
                Icons.compare_arrows_rounded,
                badgeColor,
              ),
            ],
          ),
          if (est > 0 && pct.abs() > 5) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _varianceReasonController,
              decoration: _dec(
                l.ccAssessVarianceReason,
                hint: l.ccAssessVarianceReasonHint,
                icon: Icons.help_outline_rounded,
              ).copyWith(filled: true, fillColor: AppTheme.surfaceOf(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LtrText(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
