import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/shipment_update_model.dart';
import '../../providers/shipment_updates_provider.dart';
import '../shipment_update_dialog.dart';
import '../su_ui.dart';

class SuPipelineCard extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isAr;
  final ImportFileModel file;
  final String selectedFileCode;
  final ShipmentUpdatesState updatesState;
  final List<String> phaseCodes;
  final String Function(AppLocalizations, String) getPhaseName;
  final String Function(AppLocalizations, String) getStatusName;

  const SuPipelineCard({
    super.key,
    required this.l10n,
    required this.isAr,
    required this.file,
    required this.selectedFileCode,
    required this.updatesState,
    required this.phaseCodes,
    required this.getPhaseName,
    required this.getStatusName,
  });

  @override
  Widget build(BuildContext context) {
    return CcSectionCard(
      title: DisplayNameResolver.resolveShipmentName(file, isArabic: isAr),
      icon: Icons.hub,
      margin: EdgeInsets.zero,
      trailing: CcStatusChip(
        label: DisplayNameResolver.resolvePhaseName(file.currentModule, isArabic: isAr),
        severity: AppSeverity.success,
        icon: Icons.flag_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SuCodeBadge(code: selectedFileCode, copiedMessage: l10n.shipmentUpdateCodeBadgeLabel, fontSize: 11),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: phaseCodes.map((pCode) {
                final pName = getPhaseName(l10n, pCode);
                final insp = updatesState.inspectedPhases.firstWhere(
                  (ip) => ip.phaseCode == pCode,
                  orElse: () => PhaseInspectionModel(
                    phaseCode: pCode,
                    phaseName: pName,
                    phaseNumber: 1,
                    status: 'Future',
                    updateCount: 0,
                  ),
                );
                return SuPhaseTile(
                  name: pName,
                  status: insp.status,
                  statusLabel: getStatusName(l10n, insp.status),
                  countLabel: l10n.shipmentUpdateCountBadge(insp.updateCount),
                  onTap: () => ShipmentUpdateDialog.show(
                    context,
                    initialFileId: file.importFileId,
                    initialFileCode: selectedFileCode,
                    initialTargetPhase: pCode,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
