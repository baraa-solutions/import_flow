import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../cbm_calculator/widgets/air_freight_calculator_widget.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../l10n/air_lcl_l10n.dart';
import '../models/freight_booking_model.dart';
import '../providers/freight_booking_provider.dart';
import 'freight_booking_ui.dart';

/// Modal dialog for recording Air Freight flight & waybill details,
/// or Ocean LCL CFS consolidation terminal and stripping fees.
///
/// Fully adheres to:
/// - Root wrapped in SelectionArea
/// - Strictly CopyHelper.copy for clipboard
/// - Unified widgets: AppButton, CustomTextField, AppTheme.cardDecorationOf, AppStatusBadge
/// - 100% Pure language separation via air_lcl_l10n.dart
class AirLclDetailsDialog extends ConsumerStatefulWidget {
  final ShipmentBookingModel booking;

  const AirLclDetailsDialog({super.key, required this.booking});

  @override
  ConsumerState<AirLclDetailsDialog> createState() => _AirLclDetailsDialogState();
}

class _AirLclDetailsDialogState extends ConsumerState<AirLclDetailsDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedTransportMode;
  late final TextEditingController _flightNumberController;
  late final TextEditingController _airlineCodeController;
  late final TextEditingController _mawbController;
  late final TextEditingController _hawbController;
  late final TextEditingController _airportTerminalController;
  late final TextEditingController _chargeableWeightController;
  late final TextEditingController _cfsTerminalController;
  late final TextEditingController _strippingFeesController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;

    // Detect transport mode
    if (b.transportMode.isNotEmpty) {
      _selectedTransportMode = b.transportMode;
    } else if (b.isAirFreight) {
      _selectedTransportMode = 'AIR_FREIGHT';
    } else if (b.isSeaLcl) {
      _selectedTransportMode = 'SEA_LCL';
    } else {
      _selectedTransportMode = 'SEA_FCL';
    }

    _flightNumberController = TextEditingController(text: b.flightNumber ?? '');
    _airlineCodeController = TextEditingController(text: b.airlineCode ?? '');
    _mawbController = TextEditingController(text: b.masterAirWaybill ?? '');
    _hawbController = TextEditingController(text: b.houseAirWaybill ?? '');
    _airportTerminalController = TextEditingController(text: b.airportTerminalName ?? '');
    _chargeableWeightController = TextEditingController(
      text: (b.chargeableWeightKg != null && b.chargeableWeightKg! > 0)
          ? b.chargeableWeightKg!.toStringAsFixed(2)
          : '',
    );

    _cfsTerminalController = TextEditingController(text: b.cfsTerminalName ?? '');
    _strippingFeesController = TextEditingController(
      text: (b.strippingFeesEgp != null && b.strippingFeesEgp! > 0)
          ? b.strippingFeesEgp!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    _airlineCodeController.dispose();
    _mawbController.dispose();
    _hawbController.dispose();
    _airportTerminalController.dispose();
    _chargeableWeightController.dispose();
    _cfsTerminalController.dispose();
    _strippingFeesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;

    setState(() => _isSubmitting = true);

    try {
      final payload = <String, dynamic>{
        'transport_mode': _selectedTransportMode,
        'flight_number': _flightNumberController.text.trim().isNotEmpty
            ? _flightNumberController.text.trim()
            : null,
        'airline_code': _airlineCodeController.text.trim().isNotEmpty
            ? _airlineCodeController.text.trim()
            : null,
        'master_air_waybill': _mawbController.text.trim().isNotEmpty
            ? _mawbController.text.trim()
            : null,
        'house_air_waybill': _hawbController.text.trim().isNotEmpty
            ? _hawbController.text.trim()
            : null,
        'airport_terminal_name': _airportTerminalController.text.trim().isNotEmpty
            ? _airportTerminalController.text.trim()
            : null,
        'cfs_terminal_name': _cfsTerminalController.text.trim().isNotEmpty
            ? _cfsTerminalController.text.trim()
            : null,
        'stripping_fees_egp': double.tryParse(_strippingFeesController.text.trim()) ?? 0.0,
        'chargeable_weight_kg': double.tryParse(_chargeableWeightController.text.trim()) ?? 0.0,
      };

      await ref.read(freightBookingProvider.notifier).updateBooking(widget.booking.bookingId, payload);

      if (mounted) {
        Navigator.pop(context, true);
        FbkUi.snack(context, l.saveSuccessSnack, severity: AppSeverity.success);
      }
    } catch (e) {
      if (mounted) {
        FbkUi.snack(context, '${l.saveErrorSnack}: ${ApiErrorText.of(l, e)}', severity: AppSeverity.danger);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = widget.booking;

    return SelectionArea(
      child: CcStageDialogShell(
        title: l.airLclDialogTitle,
        icon: _selectedTransportMode == 'AIR_FREIGHT'
            ? Icons.flight_takeoff
            : (_selectedTransportMode == 'SEA_LCL' ? Icons.conveyor_belt : Icons.directions_boat),
        accent: _selectedTransportMode == 'AIR_FREIGHT' ? AppTheme.cobalt : AppTheme.flatEmerald,
        maxWidth: 860,
        chips: [
          CcHeaderChip(Icons.tag, b.bookingCode, ltr: true),
          if (b.bookingConfirmationNo != null)
            CcHeaderChip(Icons.confirmation_number, b.bookingConfirmationNo!, ltr: true),
        ],
        confirmLabel: l.saveDetailsBtn,
        confirmIcon: Icons.save_rounded,
        confirmVariant: AppButtonVariant.primary,
        isSubmitting: _isSubmitting,
        onConfirm: _submit,
        body: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Mode Selection Segment ──
              _buildTransportModeSelector(l),
              const SizedBox(height: 16),

              // ── Mode-Specific Forms ──
              if (_selectedTransportMode == 'AIR_FREIGHT') ...[
                _buildAirFreightFields(l),
                const SizedBox(height: 16),
                AirFreightCalculatorWidget(
                  initialGrossWeightKg: double.tryParse(_chargeableWeightController.text.trim()),
                  onWeightApplied: (weight) {
                    setState(() {
                      _chargeableWeightController.text = weight.toStringAsFixed(2);
                    });
                  },
                ),
              ] else if (_selectedTransportMode == 'SEA_LCL') ...[
                _buildSeaLclFields(l),
              ] else ...[
                _buildSeaFclNotice(l),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransportModeSelector(AppLocalizations l) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, size: 18, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Text(
                l.transportModeLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _modeButton(
                code: 'SEA_FCL',
                label: l.transportModeSeaFcl,
                icon: Icons.directions_boat,
              ),
              _modeButton(
                code: 'SEA_LCL',
                label: l.transportModeSeaLcl,
                icon: Icons.conveyor_belt,
              ),
              _modeButton(
                code: 'AIR_FREIGHT',
                label: l.transportModeAirFreight,
                icon: Icons.flight_takeoff,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeButton({required String code, required String label, required IconData icon}) {
    final isSelected = _selectedTransportMode == code;
    return InkWell(
      onTap: () => setState(() => _selectedTransportMode = code),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cobalt.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.cobalt : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.cobalt : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.cobalt : AppTheme.flatCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirFreightFields(AppLocalizations l) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flight, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.airFreightSectionTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _flightNumberController,
                  label: l.flightNumberLabel,
                  hint: l.flightNumberHint,
                  icon: Icons.flight_land,
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _airlineCodeController,
                  label: l.airlineCodeLabel,
                  hint: l.airlineCodeHint,
                  icon: Icons.airplanemode_active,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _mawbController,
                  label: l.masterAirWaybillLabel,
                  hint: l.masterAirWaybillHint,
                  icon: Icons.receipt_long,
                  textDirection: TextDirection.ltr,
                  suffixIcon: _mawbController.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => CopyHelper.copy(context, _mawbController.text.trim()),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _hawbController,
                  label: l.houseAirWaybillLabel,
                  hint: l.houseAirWaybillHint,
                  icon: Icons.receipt,
                  textDirection: TextDirection.ltr,
                  suffixIcon: _hawbController.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => CopyHelper.copy(context, _hawbController.text.trim()),
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: _airportTerminalController,
                  label: l.airportTerminalNameLabel,
                  hint: l.airportTerminalNameHint,
                  icon: Icons.warehouse,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: CustomTextField(
                  controller: _chargeableWeightController,
                  label: l.chargeableWeightResult,
                  hint: '0.00',
                  icon: Icons.scale,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeaLclFields(AppLocalizations l) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.conveyor_belt, color: AppTheme.flatEmerald, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.seaLclSectionTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: _cfsTerminalController,
                  label: l.cfsTerminalNameLabel,
                  hint: l.cfsTerminalNameHint,
                  icon: Icons.domain,
                  suffixIcon: _cfsTerminalController.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => CopyHelper.copy(context, _cfsTerminalController.text.trim()),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: CustomTextField(
                  controller: _strippingFeesController,
                  label: l.strippingFeesEgpLabel,
                  hint: l.strippingFeesHint,
                  icon: Icons.monetization_on_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.flatEmerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.flatEmerald.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.flatEmerald, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.cfsStrippingNotice,
                    style: const TextStyle(fontSize: 12, color: AppTheme.flatEmerald, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeaFclNotice(AppLocalizations l) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.cobalt, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.transportModeSeaFcl,
              style: const TextStyle(fontSize: 13, color: AppTheme.flatCharcoal),
            ),
          ),
        ],
      ),
    );
  }
}
