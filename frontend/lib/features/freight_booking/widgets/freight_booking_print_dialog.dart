import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/freight_booking_model.dart';
import '../services/freight_booking_pdf_service.dart';
import 'freight_booking_ui.dart';

/// Booking manifest preview ("paper" sheet) with copy, save PDF, and print actions.
class FreightBookingPrintDialog extends StatefulWidget {
  final ShipmentBookingModel booking;
  final String? fileCode;

  const FreightBookingPrintDialog({
    super.key,
    required this.booking,
    this.fileCode,
  });

  @override
  State<FreightBookingPrintDialog> createState() => _FreightBookingPrintDialogState();
}

class _FreightBookingPrintDialogState extends State<FreightBookingPrintDialog> {
  bool _isExporting = false;

  List<String> _copyLines(AppLocalizations l) {
    final b = widget.booking;
    return <String>[
      l.freightBookingPrintSystemHeader,
      '${l.freightBookingColBookingCode}: ${b.bookingCode}',
      '${l.freightBookingViewShippingLine} ${b.shippingLineName ?? "-"}',
      '${l.freightBookingViewConfirmNo} ${b.bookingConfirmationNo ?? "-"}',
      '${l.freightBookingColRoute}: ${b.polName ?? "-"} → ${b.podName ?? "-"}',
      '${l.freightBookingColVesselVoyage}: ${b.vesselName ?? "-"} / ${b.voyageNumber ?? "-"}',
      l.freightBookingViewEtd(b.etd != null ? b.etd!.substring(0, 10) : '-'),
      l.freightBookingViewEta(b.eta != null ? b.eta!.substring(0, 10) : '-'),
      ...b.containersData.expand((c) => c.individualContainers.map((i) => '${c.containerType} | ${i.containerNumber} | ${i.sealNumber}')),
      ...b.costChargesData.map((ch) => '${ch.chargeType}: ${ch.total.toStringAsFixed(2)} ${ch.currency}'),
      '${l.freightBookingViewTotalFreight}: ${b.totalFreightCostUsd == null ? CcFormat.unknown : '\$${b.totalFreightCostUsd!.toStringAsFixed(2)}'}',
    ];
  }

  Future<void> _onPrint(AppLocalizations l) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await FreightBookingPdfService.build(
        booking: widget.booking,
        l: l,
        fileCode: widget.fileCode,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${widget.booking.bookingCode}.pdf',
      );
    } catch (e) {
      if (mounted) {
        FbkUi.snack(context, e.toString(), severity: AppSeverity.danger);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _onSavePdf(AppLocalizations l) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await FreightBookingPdfService.build(
        booking: widget.booking,
        l: l,
        fileCode: widget.fileCode,
      );
      if (!mounted) return;
      final targetName = widget.fileCode ?? widget.booking.bookingCode;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: bytes,
        stageName: l.fbkStageName,
        importFileNameOrCode: targetName,
        extension: 'pdf',
      );
      if (mounted) {
        FbkUi.snack(context, l.freightBookingPrintSuccess, severity: AppSeverity.success);
      }
    } catch (e) {
      if (mounted) {
        FbkUi.snack(context, e.toString(), severity: AppSeverity.danger);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = widget.booking;

    return CcStageDialogShell(
      title: l.freightBookingPrintTitle(b.bookingCode),
      icon: Icons.print,
      maxWidth: 780,
      isSubmitting: _isExporting,
      confirmLabel: l.freightBookingPrintNowBtn,
      confirmIcon: Icons.print,
      confirmVariant: AppButtonVariant.primary,
      cancelKey: const Key('fbkPrintCloseBtn'),
      footerLeading: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FbkUi.fit(AppButton(
              label: l.copyTooltip,
              icon: Icons.copy_outlined,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              onPressed: () => CopyHelper.copy(context, _copyLines(l).join('\n')),
            )),
            FbkUi.fit(AppButton(
              key: const Key('fbkSavePdfBtn'),
              label: l.fbkSavePdfBtn,
              icon: Icons.download_outlined,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              isLoading: _isExporting,
              onPressed: _isExporting ? null : () => _onSavePdf(l),
            )),
          ],
        ),
      ),
      onConfirm: () => _onPrint(l),
      body: SelectionArea(child: _sheet(context, l)),
    );
  }

  /// The printable sheet always keeps a white paper look with dark ink.
  Widget _sheet(BuildContext context, AppLocalizations l) {
    final b = widget.booking;
    const ink = AppTheme.charcoal;
    const muted = AppTheme.textCaption;
    const bold = TextStyle(fontWeight: FontWeight.bold, color: ink, fontSize: 13);
    const plain = TextStyle(color: ink, fontSize: 12.5);

    Widget line(String text, {TextStyle? style}) =>
        Padding(padding: const EdgeInsetsDirectional.only(top: 4), child: Text(text, style: style ?? plain));

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: DefaultTextStyle(
        style: plain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(l.freightBookingPrintSystemHeader,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1, color: ink)),
                  Text(l.freightBookingPrintManifestHeader(b.bookingCode), style: bold),
                  Text(
                    l.freightBookingPrintDate(DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')),
                    style: const TextStyle(fontSize: 10.5, color: muted),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1.5),
            Wrap(
              spacing: 24,
              runSpacing: 4,
              children: [
                Text('${l.freightBookingViewShippingLine} ${b.shippingLineName ?? "-"}', style: bold),
                Text('${l.freightBookingViewConfirmNo} ${b.bookingConfirmationNo ?? "-"}', style: bold),
              ],
            ),
            line('${l.freightBookingColVesselVoyage}: ${b.vesselName ?? "-"} / ${b.voyageNumber ?? "-"}'),
            line('${l.freightBookingColRoute}: ${b.polName ?? "-"} → ${b.podName ?? "-"}'),
            line(l.freightBookingViewEtd(b.etd != null ? b.etd!.substring(0, 10) : '-')),
            line(l.freightBookingViewEta(b.eta != null ? b.eta!.substring(0, 10) : '-')),
            if (b.atd != null) line(l.freightBookingViewAtd(b.atd!.substring(0, 10), '+${b.departureDelayDays}d')),
            const SizedBox(height: 12),
            Text(l.freightBookingPrintContainersHeader,
                style: bold.copyWith(decoration: TextDecoration.underline)),
            for (final c in b.containersData)
              for (final indiv in c.individualContainers)
                line('• ${c.containerType} | ${indiv.containerNumber.isEmpty ? "N/A" : indiv.containerNumber} | ${indiv.sealNumber.isEmpty ? "N/A" : indiv.sealNumber}'),
            const SizedBox(height: 12),
            Text(l.freightBookingPrintChargesHeader, style: bold.copyWith(decoration: TextDecoration.underline)),
            for (final ch in b.costChargesData)
              line('• ${ch.chargeType}: ${ch.total.toStringAsFixed(2)} ${ch.currency}'),
            const Divider(),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l.freightBookingPrintGrandTotal(CcFormat.fixed(b.totalFreightCostUsd)),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.wcagEmerald),
              ),
            ),
            if (b.originalFreightCostUsd > 0 || b.costSavingsUsd > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsetsDirectional.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.wcagEmerald.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.savings_outlined, color: AppTheme.wcagEmerald, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l.freightBookingOriginalQuotedPrice}: \$${b.originalFreightCostUsd.toStringAsFixed(2)} | ${l.freightBookingExecutedPrice}: ${b.totalFreightCostUsd == null ? CcFormat.unknown : '\$${b.totalFreightCostUsd!.toStringAsFixed(2)}'} | ${l.freightBookingCostSavingsBadge}: \$${b.costSavingsUsd.toStringAsFixed(2)} (${b.savingsPercent.toStringAsFixed(1)}%)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: AppTheme.wcagEmerald),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
