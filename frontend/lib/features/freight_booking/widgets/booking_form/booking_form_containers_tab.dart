import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../models/freight_booking_model.dart';
import '../freight_booking_ui.dart';

/// Equipment and container allocation section with mismatch validation.
class BookingFormContainersTab extends StatelessWidget {
  final List<ContainerAllocationModel> containers;
  final int quoteRevision;
  final bool hasQuoteMismatch;
  final String? quoteMismatchError;
  final bool cargoMetricsMissing;
  final ValueChanged<String> onContainerTypeChanged;
  final ValueChanged<int> onContainerQtyChanged;

  const BookingFormContainersTab({
    super.key,
    required this.containers,
    required this.quoteRevision,
    required this.hasQuoteMismatch,
    required this.quoteMismatchError,
    required this.cargoMetricsMissing,
    required this.onContainerTypeChanged,
    required this.onContainerQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return CcFormSection(
      title: l.fbkSectionEquipment,
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CcFieldRow(
            children: [
              CcField(
                label: l.freightBookingContainerTypeInput,
                child: SearchableDropdownField<String>(
                  value: containers.isNotEmpty ? containers.first.containerType : null,
                  labelText: l.freightBookingContainerTypeInput,
                  searchHintText: '20GP, 40HC...',
                  hintText: l.fbkSelectHint,
                  decoration: ccInputDecoration(hint: l.fbkSelectHint),
                  items: const [
                    SearchableDropdownItem(value: '20GP', label: '20GP Standard'),
                    SearchableDropdownItem(value: '40GP', label: '40GP Standard'),
                    SearchableDropdownItem(value: '40HC', label: '40HC High Cube'),
                    SearchableDropdownItem(value: '45HC', label: '45HC High Cube'),
                    SearchableDropdownItem(value: '20RF', label: '20RF Reefer'),
                    SearchableDropdownItem(value: '40RF', label: '40RF Reefer'),
                  ],
                  onChanged: (val) {
                    if (val != null) onContainerTypeChanged(val);
                  },
                ),
              ),
              CcField(
                label: l.freightBookingContainersQtyInput,
                child: TextFormField(
                  key: ValueKey('fbkQty_$quoteRevision'),
                  initialValue: containers.isNotEmpty ? containers.first.quantity.toString() : '',
                  keyboardType: TextInputType.number,
                  decoration: ccInputDecoration(prefix: Icons.numbers),
                  onChanged: (val) {
                    final q = int.tryParse(val) ?? 1;
                    onContainerQtyChanged(q);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasQuoteMismatch && quoteMismatchError != null) ...[
            FbkNotice(
              key: const Key('fbkQuoteEquipmentMismatchNotice'),
              message: quoteMismatchError!,
              severity: AppSeverity.danger,
              icon: Icons.error_outline,
            ),
            const SizedBox(height: 8),
          ],
          FbkNotice(message: l.fbkEquipmentNote, severity: AppSeverity.info, icon: Icons.info_outline),
          if (cargoMetricsMissing) ...[
            const SizedBox(height: 8),
            FbkNotice(message: l.cshCargoMetricsMissing, severity: AppSeverity.warning, icon: Icons.warning_amber_rounded),
          ],
        ],
      ),
    );
  }
}
