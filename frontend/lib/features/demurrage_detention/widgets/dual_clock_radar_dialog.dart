import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/demurrage_model.dart';
import 'radar/dual_clock_alerts.dart';
import 'radar/dual_clock_card.dart';
import 'radar/dual_clock_gate_out_section.dart';
import 'radar/dual_clock_header.dart';

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
                DualClockHeader(
                  billOfLadingNo: widget.billOfLadingNo,
                  carrierName: widget.carrierName,
                  onDark: onDark,
                  onCopyMetrics: _data == null ? null : () => _copyRadarMetrics(context),
                  onClose: () => Navigator.of(context).pop(),
                ),
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

  Widget _buildContent() {
    final l10n = context.l10n;
    final carrierClock = _data?.carrierClock ?? const CarrierClockModel();
    final portClock = _data?.portStorageClock ?? const PortStorageClockModel();

    final carrierSeverity = carrierClock.isOverdue
        ? AppSeverity.danger
        : (carrierClock.isWarning ? AppSeverity.warning : AppSeverity.success);
    final portSeverity = portClock.isOverdue
        ? AppSeverity.danger
        : (portClock.isCritical72hWarning ? AppSeverity.warning : AppSeverity.success);

    final carrierCard = DualClockCard(
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

    final portCard = DualClockCard(
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
          DualClockAlerts(
            carrierClock: carrierClock,
            portClock: portClock,
          ),
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
          DualClockGateOutSection(
            containerController: _containerController,
            eirController: _eirController,
            isSubmitting: _isSubmittingGateOut,
            onSubmit: _submitContainerGateOut,
          ),
        ],
      ),
    );
  }
}
