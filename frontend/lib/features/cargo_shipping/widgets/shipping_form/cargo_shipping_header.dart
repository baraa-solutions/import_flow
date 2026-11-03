import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../cargo_shipping_ui.dart';

/// Top header banner and 2-step navigation bar for the cargo shipping form tab.
class CargoShippingHeader extends StatelessWidget {
  final dynamic curFile;
  final int? selectedImportFileId;
  final String? editingRecordCode;
  final int? editingRecordId;
  final int activeStepIndex;
  final ValueChanged<int> onStepChanged;
  final VoidCallback? onCancelEdit;

  const CargoShippingHeader({
    super.key,
    required this.curFile,
    required this.selectedImportFileId,
    this.editingRecordCode,
    this.editingRecordId,
    required this.activeStepIndex,
    required this.onStepChanged,
    this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedImportFileId != null && curFile != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 12),
            child: ShippingLinkedFileBanner(
              fileLabel: curFile.primaryNameWithCode,
              companyName: curFile.companyName,
              supplierName: curFile.supplierName,
              acidNumber: curFile.acidNumber,
              recordCode: editingRecordCode,
              onCancelEdit: editingRecordId != null ? onCancelEdit : null,
            ),
          ),
        ShippingStepSwitcher(
          selectedIndex: activeStepIndex,
          titles: [
            context.l10n.cargoShippingStep1Title,
            context.l10n.cargoShippingStep2Title,
          ],
          icons: const [
            Icons.inventory_2_outlined,
            Icons.timelapse_outlined,
          ],
          onSelected: onStepChanged,
        ),
      ],
    );
  }
}
