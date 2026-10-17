import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'freight_booking_ui.dart';

/// Action bar of the registry: create / clone / copy / export buttons.
class FbkActionBar extends StatelessWidget {
  const FbkActionBar({
    super.key,
    required this.onCreate,
    required this.onSearchClone,
    required this.onCopyTable,
    required this.onExportExcel,
    required this.onExportPdf,
  });

  final VoidCallback onCreate;
  final VoidCallback onSearchClone;
  final VoidCallback onCopyTable;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(12),
      decoration: AppTheme.toolbarDecorationOf(context),
      child: FbkButtonWrap(
        buttons: [
          AppButton(
            key: const Key('createBookingBtn'),
            label: l.freightBookingCreateButton,
            icon: Icons.add_task,
            size: AppButtonSize.small,
            onPressed: onCreate,
          ),
          AppButton(
            key: const Key('searchAndCloneBookingBtn'),
            label: l.searchAndCloneFreightBookingBtn,
            icon: Icons.copy_all_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onSearchClone,
          ),
          AppButton(
            key: const Key('copyBookingsTableTsvBtn'),
            label: l.customsDeclExportTsvButton,
            icon: Icons.copy,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: onCopyTable,
          ),
          AppButton(
            key: const Key('exportBookingsExcelBtn'),
            label: l.exportBookingsExcelTooltip,
            icon: Icons.table_view_outlined,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: onExportExcel,
          ),
          AppButton(
            key: const Key('exportBookingsPdfBtn'),
            label: l.exportBookingsPdfTooltip,
            icon: Icons.picture_as_pdf_outlined,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: onExportPdf,
          ),
        ],
      ),
    );
  }
}

/// Search box + status filter (+ the shipment filter chip when the screen was
/// opened for one import file).
class FbkFilterBar extends StatelessWidget {
  const FbkFilterBar({
    super.key,
    required this.searchController,
    required this.status,
    required this.onSearchChanged,
    required this.onStatusChanged,
    this.shipmentChipLabel,
    this.onClearShipment,
  });

  final TextEditingController searchController;
  final String status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final String? shipmentChipLabel;
  final VoidCallback? onClearShipment;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(12),
      decoration: AppTheme.cardDecorationOf(context),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final search = AppSearchField(
          key: const Key('bookingSearchField'),
          controller: searchController,
          hint: l.freightBookingSearchHint,
          onChanged: onSearchChanged,
        );
        final statusField = SearchableDropdownField<String>(
          value: status,
          labelText: l.freightBookingFilterStatusLabel,
          searchHintText: l.freightBookingFilterStatusHint,
          decoration: InputDecoration(
            labelText: l.freightBookingFilterStatusLabel,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
          items: [
            SearchableDropdownItem(value: 'All', label: l.freightBookingStatusAll),
            SearchableDropdownItem(value: 'Draft', label: l.freightBookingStatusDraft),
            SearchableDropdownItem(value: 'Booking Requested', label: l.freightBookingStatusRequested),
            SearchableDropdownItem(value: 'Confirmed', label: l.freightBookingStatusConfirmed),
            SearchableDropdownItem(value: 'Sailed', label: l.freightBookingStatusSailed),
          ],
          onChanged: (v) {
            if (v != null) onStatusChanged(v);
          },
        );
        final chip = shipmentChipLabel == null
            ? null
            : InputChip(
                avatar: const Icon(Icons.filter_alt, size: 16, color: AppTheme.cobalt),
                label: Text(shipmentChipLabel!),
                onDeleted: onClearShipment,
              );

        final fields = wide
            ? Row(
                children: [
                  Expanded(flex: 3, child: search),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: statusField),
                ],
              )
            : Column(children: [search, const SizedBox(height: 10), statusField]);
        if (chip == null) return fields;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [fields, const SizedBox(height: 8), chip],
        );
      }),
    );
  }
}
