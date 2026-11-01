import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/freight_booking_model.dart';
import '../freight_booking_registry_row.dart';
import 'freight_booking_dialog_helper.dart';
import 'freight_booking_export_helper.dart';

class FreightBookingRegistryList extends ConsumerWidget {
  final List<ShipmentBookingModel> bookings;
  final List<ImportFileModel> importFiles;
  final VoidCallback onRefresh;

  const FreightBookingRegistryList({
    super.key,
    required this.bookings,
    required this.importFiles,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final importFilesMap = {for (final f in importFiles) f.importFileId: f};
    final isAr = l.isArabic;

    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderOf(context)),
        itemBuilder: (context, i) {
          final bkg = bookings[i];
          final f = bkg.importFileId != null ? importFilesMap[bkg.importFileId] : null;
          final rawCode = bkg.importFileCode ?? (bkg.importFileId != null ? 'IMP-${bkg.importFileId}' : '');
          final shipName = f != null
              ? DisplayNameResolver.resolveShipmentName(f, isArabic: isAr)
              : DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: importFiles, isArabic: isAr);
          final shipTitle = f != null
              ? DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr)
              : DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
          return FbkRegistryRow(
            booking: bkg,
            fileName: shipName,
            fileCode: rawCode,
            fileTitle: shipTitle,
            actions: FbkRowActions(
              onView: () => FreightBookingDialogHelper.showViewBookingDialog(context, bkg),
              onEdit: () => FreightBookingDialogHelper.showAddEditBookingDialog(context, bkg),
              onClone: () => FreightBookingDialogHelper.onCloneBooking(context: context, booking: bkg),
              onPrint: () => FreightBookingDialogHelper.showPrintBookingDialog(context, bkg),
              onDelete: () => FreightBookingDialogHelper.confirmDelete(context: context, ref: ref, bkg: bkg),
              onCopyRow: () => FreightBookingExportHelper.copyBookingRowTsv(context: context, bkg: bkg, l: l),
              onConfirmBooking: () => FreightBookingDialogHelper.showConfirmBookingDialog(context, bkg),
              onDeparture: () => FreightBookingDialogHelper.showDepartureConfirmationDialog(context, bkg),
              onReviewDraftBl: () => FreightBookingDialogHelper.showDraftBlReviewDialog(context, ref, bkg),
              onCancelBooking: () => FreightBookingDialogHelper.confirmCancel(context: context, ref: ref, bkg: bkg),
              onEtaTracking: () => FreightBookingDialogHelper.showEtaTrackingDialog(context, bkg),
              onAirLclDetails: () => FreightBookingDialogHelper.showAirLclDetailsDialog(context, bkg),
            ),
          );
        },
      ),
    );
  }
}
