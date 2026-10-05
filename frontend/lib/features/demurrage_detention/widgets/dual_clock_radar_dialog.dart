import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/demurrage_model.dart';
import 'demurrage_status.dart';

void showDualClockRadarDialog(BuildContext context, WidgetRef ref, {
  required int trackingId,
  required String billOfLadingNo,
  required String carrierName,
}) {
  showDialog(
    context: context,
    builder: (ctx) => DualClockRadarDialog(
      trackingId: trackingId,
      billOfLadingNo: billOfLadingNo,
      carrierName: carrierName,
    ),
  );
}

class DualClockRadarDialog extends ConsumerStatefulWidget {
  final int trackingId;
  final String billOfLadingNo;
  final String carrierName;

  const DualClockRadarDialog({
    super.key,
    required this.trackingId,
    required this.billOfLadingNo,
    required this.carrierName,
  });

  @override
  ConsumerState<DualClockRadarDialog> createState() => _DualClockRadarDialogState();
}

class _DualClockRadarDialogState extends ConsumerState<DualClockRadarDialog> {
  bool _isLoading = true;
  String? _error;
  DualClockModel? _data;

  // Gate-out controllers
  final _containerController = TextEditingController();
  final _eirController = TextEditingController();
  DateTime? _gateOutDate;
  DateTime? _emptyReturnDate;
  bool _isSubmittingGateOut = false;

  @override
  void initState() {
    super.initState();
    _fetchDualClockData();
  }

  @override
  void dispose() {
    _containerController.dispose();
    _eirController.dispose();
    super.dispose();
  }

  Future<void> _fetchDualClockData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/demurrage-detention/trackings/${widget.trackingId}/dual-clock');
      if (mounted) {
        setState(() {
          _data = res.data is Map ? DualClockModel.fromJson(Map<String, dynamic>.from(res.data as Map)) : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiErrorText.of(context.l10n, e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitContainerGateOut() async {
    final l10n = context.l10n;
    if (_containerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.dualClockEnterContainerValidation, severity: AppSeverity.warning),
      );
      return;
    }

    setState(() => _isSubmittingGateOut = true);
    try {
      final dio = ref.read(dioProvider);
      final containerNo = _containerController.text.trim();
      final payload = {
        'gate_out_date': _gateOutDate?.toIso8601String().split('T').first,
        'empty_return_date': _emptyReturnDate?.toIso8601String().split('T').first,
        'eir_number': _eirController.text.trim().isNotEmpty ? _eirController.text.trim() : null,
      };

      await dio.patch(
        '/demurrage-detention/trackings/${widget.trackingId}/containers/$containerNo',
        data: payload,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            '${l10n.dualClockGateOutSuccessSnack} ($containerNo)',
            severity: AppSeverity.success,
          ),
        );
        _containerController.clear();
        _eirController.clear();
        _gateOutDate = null;
        _emptyReturnDate = null;
        _fetchDualClockData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            '${l10n.dualClockGateOutErrorSnack}: ${ApiErrorText.of(l10n, e)}',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingGateOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screen = MediaQuery.of(context).size;
    final width = screen.width > 880 ? 820.0 : screen.width * 0.95;
    final onDark = AppTheme.white.withValues(alpha: 0.78);

    return SelectionArea(
      child: Dialog(
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: screen.height * 0.9),
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(l10n, onDark),
                Flexible(
                  child: _isLoading
                      ? const SizedBox(height: 300, child: CcStateView.loading())
                      : _error != null
                          ? SizedBox(
                              height: 260,
                              child: CcStateView.error(
                                message: _error!,
                                actionLabel: l10n.dualClockRetryBtn,
                                onAction: _fetchDualClockData,
                              ),
                            )
                          : _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n, Color onDark) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 16),
      color: AppTheme.charcoal,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(Icons.speed_rounded, color: AppTheme.cobalt, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dualClockRadarDialogTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.white),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _chip(Icons.description_outlined, l10n.billOfLadingLabel(widget.billOfLadingNo), onDark),
                    _chip(Icons.directions_boat_outlined, widget.carrierName, onDark),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded, color: onDark, size: 20),
            tooltip: l10n.dualClockCopyMetricsBtn,
            onPressed: _data == null ? null : () => _copyRadarMetrics(context),
          ),
          IconButton(
            icon: Icon(Icons.close, color: onDark),
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color onDark) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onDark),
          const SizedBox(width: 4),
          Flexible(
            child: LtrText(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: onDark)),
          ),
        ],
      ),
    );
  }

  void _copyRadarMetrics(BuildContext context) {
    final l10n = context.l10n;
    final data = _data;
    if (data == null) return;
    final carrier = data.carrierClock;
    final port = data.portStorageClock;
    final buffer = StringBuffer()
      ..writeln(l10n.dualClockRadarDialogTitle)
      ..writeln('${l10n.billOfLadingLabel(widget.billOfLadingNo)}\t${widget.carrierName}')
      ..writeln('')
      ..writeln(l10n.dualClockCarrierClockTitle)
      ..writeln('${l10n.dualClockTotalAccruedLabel}:\t${carrier.accruedDemurrageFx.toStringAsFixed(2)} ${carrier.currency}')
      ..writeln('${l10n.colFreeDays}:\t${l10n.daysCountFormatted(carrier.freeDaysAllowed)}')
      ..writeln('${l10n.colOverdueDays}:\t${l10n.daysCountFormatted(carrier.overdueDays)}')
      ..writeln('')
      ..writeln(l10n.dualClockPortClockTitle)
      ..writeln('${l10n.dualClockTotalAccruedLabel}:\t${port.accruedStorageEgp.toStringAsFixed(2)} ${l10n.egpCurrency}')
      ..writeln('${l10n.colFreeDays}:\t${l10n.daysCountFormatted(port.storageFreeDays)}')
      ..writeln('${l10n.colOverdueDays}:\t${l10n.daysCountFormatted(port.overdueDays)}')
      ..writeln('${l10n.dailyStorageRateLabel}:\t${port.dailyRateEgp.toStringAsFixed(2)} ${l10n.egpCurrency}');

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.dualClockCopyMetricsSuccess,
    );
  }

  String _carrierStatusNote(AppLocalizations l10n, CarrierClockModel c) {
    if (c.isOverdue) {
      return '${l10n.dualClockOverdueDaysNote} (${l10n.daysCountFormatted(c.overdueDays)})';
    }
    if (c.isWarning) {
      return '${l10n.dualClockStatusLast3Days} (${l10n.daysCountFormatted(c.daysRemaining)})';
    }
    return '${l10n.dualClockFreeDaysRemaining} (${l10n.daysCountFormatted(c.daysRemaining)})';
  }

  String _portStatusNote(AppLocalizations l10n, PortStorageClockModel p) {
    if (p.isOverdue) {
      return '${l10n.dualClockOverdueDaysNote} (${l10n.daysCountFormatted(p.overdueDays)})';
    }
    if (p.isCritical72hWarning) return l10n.dualClockStatusCritical72h;
    return '${l10n.dualClockFreeDaysRemaining} (${l10n.daysCountFormatted(p.daysRemaining)})';
  }

  Widget _buildContent() {
    final l10n = context.l10n;
    final carrierClock = _data?.carrierClock ?? const CarrierClockModel();
    final portClock = _data?.portStorageClock ?? const PortStorageClockModel();
    final bool warning72h = portClock.isCritical72hWarning && !portClock.isOverdue;
    final String portAdvice = l10n.dualClockHoursUntilPenalties(portClock.hoursUntilPenalties);

    final carrierSeverity = carrierClock.isOverdue
        ? AppSeverity.danger
        : (carrierClock.isWarning ? AppSeverity.warning : AppSeverity.success);
    final portSeverity = portClock.isOverdue
        ? AppSeverity.danger
        : (portClock.isCritical72hWarning ? AppSeverity.warning : AppSeverity.success);

    final carrierCard = _ClockCard(
      title: l10n.dualClockCarrierClockTitle,
      icon: Icons.directions_boat_outlined,
      accentColor: AppTheme.cobalt,
      severity: carrierSeverity,
      statusNote: _carrierStatusNote(l10n, carrierClock),
      totalAmount: carrierClock.accruedDemurrageFx,
      currency: carrierClock.currency,
      consumedDays: carrierClock.daysConsumed,
      freeDays: carrierClock.freeDaysAllowed,
      overdueDays: carrierClock.overdueDays,
      extraLabel: carrierClock.expiryDate != null ? l10n.dualClockExpiryLabel : null,
      extraValue: carrierClock.expiryDate,
    );
    final portCard = _ClockCard(
      title: l10n.dualClockPortClockTitle,
      icon: Icons.warehouse_outlined,
      accentColor: AppTheme.orange,
      severity: portSeverity,
      statusNote: _portStatusNote(l10n, portClock),
      totalAmount: portClock.accruedStorageEgp,
      currency: l10n.egpCurrency,
      consumedDays: portClock.daysConsumed,
      freeDays: portClock.storageFreeDays,
      overdueDays: portClock.overdueDays,
      extraLabel: l10n.dailyStorageRateLabel,
      extraValue: '${portClock.dailyRateEgp.toStringAsFixed(2)} ${l10n.egpCurrency}',
    );

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 72-Hour Warning Alert
          if (warning72h)
            Container(
              margin: const EdgeInsetsDirectional.only(bottom: 16),
              padding: const EdgeInsetsDirectional.all(14),
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.severityForegroundOf(context, AppSeverity.warning), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.severityForegroundOf(context, AppSeverity.warning), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dualClockWarning72hTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                            fontSize: 13.5,
                          ),
                        ),
                        if (portAdvice.isNotEmpty)
                          Text(portAdvice, style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Dual Clocks (side by side, stacked when narrow)
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 640) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [carrierCard, const SizedBox(height: 12), portCard],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: carrierCard),
                  const SizedBox(width: 16),
                  Expanded(child: portCard),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Partial Gate-Out Section (LOG-CONT-002)
          CcFormSection(
            title: l10n.dualClockGateOutSectionTitle,
            icon: Icons.local_shipping_outlined,
            child: LayoutBuilder(
              builder: (context, c) {
                final container = TextFormField(
                  controller: _containerController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.dualClockContainerNoLabel,
                    hintText: l10n.dualClockContainerNoHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                      tooltip: l10n.demurrageCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _containerController.text, customMessage: l10n.demurrageCopyFieldTooltip),
                    ),
                  ),
                );
                final eir = TextFormField(
                  controller: _eirController,
                  decoration: InputDecoration(
                    labelText: l10n.dualClockEirReceiptLabel,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                      tooltip: l10n.demurrageCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _eirController.text, customMessage: l10n.demurrageCopyFieldTooltip),
                    ),
                  ),
                );
                final submit = AppButton(
                  onPressed: _isSubmittingGateOut ? null : _submitContainerGateOut,
                  isLoading: _isSubmittingGateOut,
                  icon: Icons.check_circle_outline,
                  label: l10n.dualClockRecordGateOutBtn,
                  variant: AppButtonVariant.success,
                );
                if (c.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      container,
                      const SizedBox(height: 10),
                      eir,
                      const SizedBox(height: 10),
                      Align(alignment: AlignmentDirectional.centerEnd, child: submit),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: container),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: eir),
                    const SizedBox(width: 10),
                    submit,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two penalty clocks: accrued amount (severity coloured), a free-
/// days progress bar and the key counters.
class _ClockCard extends StatelessWidget {
  const _ClockCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.severity,
    required this.statusNote,
    required this.totalAmount,
    required this.currency,
    required this.consumedDays,
    required this.freeDays,
    required this.overdueDays,
    this.extraLabel,
    this.extraValue,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final AppSeverity severity;
  final String statusNote;
  final double totalAmount;
  final String currency;
  final int consumedDays;
  final int freeDays;
  final int overdueDays;
  final String? extraLabel;
  final String? extraValue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDanger = severity == AppSeverity.danger;
    final fg = AppTheme.severityForegroundOf(context, severity);
    final progress = freeDays <= 0 ? (consumedDays > 0 ? 1.0 : 0.0) : (consumedDays / freeDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsetsDirectional.all(18),
      decoration: AppTheme.cardDecorationOf(context).copyWith(
        border: Border.all(
          color: isDanger ? fg.withValues(alpha: 0.6) : AppTheme.borderOf(context),
          width: isDanger ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => CopyHelper.copy(
              context,
              totalAmount.toStringAsFixed(2),
              customMessage: l10n.demurrageCopyFieldTooltip,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: CcMoneyText(totalAmount, currency: currency, fontSize: 24, color: isDanger ? fg : null)),
                const SizedBox(width: 6),
                Icon(Icons.copy_rounded, size: 15, color: AppTheme.textMutedOf(context)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: fg,
              backgroundColor: AppTheme.surfaceAltOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.freeDaysConsumed(consumedDays, freeDays),
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
          ),
          Divider(height: 22, color: AppTheme.borderOf(context)),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.colFreeDays}: ${l10n.daysCountFormatted(freeDays)}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${l10n.colOverdueDays}: ${l10n.daysCountFormatted(overdueDays)}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDanger ? fg : AppTheme.textSecondaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (extraLabel != null && extraValue != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    extraLabel!,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
                  ),
                ),
                LtrText(extraValue!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          CcStatusChip(label: statusNote, severity: severity, icon: DemurrageStatusStyle.iconOf(severity)),
        ],
      ),
    );
  }
}
