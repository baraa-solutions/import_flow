import 'package:flutter/material.dart';

import '../../../shipping_scenarios/models/shipping_scenario_model.dart';
import 'booking_form_containers_tab.dart';
import 'booking_form_controller.dart';
import 'booking_form_general_tab.dart';
import 'booking_form_routing_tab.dart';

/// Details tab assembling general info, carrier routing, and container equipment.
class BookingFormDetailsTab extends StatelessWidget {
  final BookingFormController ctrl;
  final List<dynamic> importFiles;
  final List<dynamic> shippingLines;
  final List<dynamic> freightForwarders;
  final List<dynamic> ports;
  final List<ShippingEvaluationModel> matchingSessions;
  final String? quoteMismatchError;
  final bool cargoMetricsMissing;
  final ValueChanged<int?> onImportFileChanged;
  final void Function(ShippingEvaluationModel session, ShippingScenarioItemModel item) onApplyScenarioQuote;
  final void Function(String name, int? id) onShippingLineChanged;
  final void Function(String name, int? id) onFreightForwarderChanged;
  final void Function(String name, int? id) onPolChanged;
  final void Function(String name, int? id) onPodChanged;
  final ValueChanged<DateTime> onEtdChanged;
  final ValueChanged<DateTime> onEtaChanged;
  final ValueChanged<DateTime> onAtdChanged;
  final VoidCallback onClearAtd;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String>? onExpectedWhDaysChanged;
  final ValueChanged<String> onContainerTypeChanged;
  final ValueChanged<int> onContainerQtyChanged;

  const BookingFormDetailsTab({
    super.key,
    required this.ctrl,
    required this.importFiles,
    required this.shippingLines,
    required this.freightForwarders,
    required this.ports,
    required this.matchingSessions,
    required this.quoteMismatchError,
    required this.cargoMetricsMissing,
    required this.onImportFileChanged,
    required this.onApplyScenarioQuote,
    required this.onShippingLineChanged,
    required this.onFreightForwarderChanged,
    required this.onPolChanged,
    required this.onPodChanged,
    required this.onEtdChanged,
    required this.onEtaChanged,
    required this.onAtdChanged,
    required this.onClearAtd,
    required this.onStatusChanged,
    required this.onExpectedWhDaysChanged,
    required this.onContainerTypeChanged,
    required this.onContainerQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingFormGeneralTab(
          selectedImportFileId: ctrl.selectedImportFileId,
          bookingConfirmNoController: ctrl.bookingConfirmNo,
          importFiles: importFiles,
          matchingSessions: matchingSessions,
          selectedScenarioItemId: ctrl.selectedScenarioItemId,
          selectedScenarioProviderName: ctrl.selectedScenarioProviderName,
          vesselName: ctrl.vesselName.text,
          onImportFileChanged: onImportFileChanged,
          onApplyScenarioQuote: onApplyScenarioQuote,
        ),
        const SizedBox(height: 12),
        BookingFormRoutingTab(
          shippingLineName: ctrl.shippingLineName,
          shippingLines: shippingLines,
          onShippingLineChanged: onShippingLineChanged,
          freightForwarderName: ctrl.freightForwarderName,
          freightForwarders: freightForwarders,
          onFreightForwarderChanged: onFreightForwarderChanged,
          polController: ctrl.pol,
          podController: ctrl.pod,
          ports: ports,
          onPolChanged: onPolChanged,
          onPodChanged: onPodChanged,
          etd: ctrl.etd,
          eta: ctrl.eta,
          atd: ctrl.atd,
          onEtdChanged: onEtdChanged,
          onEtaChanged: onEtaChanged,
          onAtdChanged: onAtdChanged,
          onClearAtd: onClearAtd,
          freeDemurrageController: ctrl.freeDemurrage,
          expectedWhDaysController: ctrl.expectedWhDays,
          onExpectedWhDaysChanged: onExpectedWhDaysChanged,
          status: ctrl.status,
          onStatusChanged: onStatusChanged,
          vesselNameController: ctrl.vesselName,
          voyageNoController: ctrl.voyageNo,
          releaseOrderNoController: ctrl.releaseOrderNo,
        ),
        const SizedBox(height: 12),
        BookingFormContainersTab(
          containers: ctrl.containers,
          quoteRevision: ctrl.quoteRevision,
          hasQuoteMismatch: ctrl.hasQuoteMismatch,
          quoteMismatchError: quoteMismatchError,
          cargoMetricsMissing: cargoMetricsMissing,
          onContainerTypeChanged: onContainerTypeChanged,
          onContainerQtyChanged: onContainerQtyChanged,
        ),
      ],
    );
  }
}
