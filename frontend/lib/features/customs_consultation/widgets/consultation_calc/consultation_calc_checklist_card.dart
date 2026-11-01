import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_consultation_model.dart';
import 'consultation_calc_logic_helper.dart';

/// Card managing regulatory documents and customs clearance checklist items.
class ConsultationCalcChecklistCard extends StatelessWidget {
  final List<CustomsChecklistItemModel> checklist;
  final VoidCallback onAddChecklistItem;
  final void Function(int index, CustomsChecklistItemModel item) onUpdateItem;
  final void Function(int index) onCloneItem;
  final void Function(int index) onDeleteItem;

  const ConsultationCalcChecklistCard({
    super.key,
    required this.checklist,
    required this.onAddChecklistItem,
    required this.onUpdateItem,
    required this.onCloneItem,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  final titleWidget = Text(
                    l.customsChecklistTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  );
                  final btnWidget = AppButton(
                    label: l.addNewChecklistItem,
                    icon: Icons.add,
                    variant: AppButtonVariant.primary,
                    onPressed: onAddChecklistItem,
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleWidget,
                        const SizedBox(height: 10),
                        btnWidget,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: titleWidget),
                      btnWidget,
                    ],
                  );
                },
              ),
              const Divider(height: 20),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: checklist.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = checklist[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 850;

                        final infoContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (item.hsCode != null && item.hsCode!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: CopyableText(
                                      item.hsCode!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.cobalt,
                                      ),
                                    ),
                                  ),
                                CopyableText(
                                  ConsultationCalcLogicHelper.getLocalizedDocType(
                                      item.documentType, l),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            if (item.regulatoryAgency != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: CopyableText(
                                  '${l.responsiblePartyLabel}: ${item.regulatoryAgency == "GOEIC" ? l.goeicAgencyName : item.regulatoryAgency}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.cobalt,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (item.remarks != null && item.remarks!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: CopyableText(
                                  ConsultationCalcLogicHelper.getLocalizedRemarks(
                                      item.remarks, l),
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textStrong),
                                ),
                              ),
                          ],
                        );

                        final responsibleDropdown = SearchableDropdownField<String>(
                          value: item.responsibleParty,
                          labelText: l.responsiblePartyLabel,
                          items: [
                            SearchableDropdownItem(
                                value: 'Customs Broker',
                                label: l.partyCustomsBroker),
                            SearchableDropdownItem(
                                value: 'Supplier / Exporter',
                                label: l.partySupplierExporter),
                            SearchableDropdownItem(
                                value: 'Importer Team',
                                label: l.partyImporterTeam),
                            SearchableDropdownItem(
                                value: 'Freight Forwarder',
                                label: l.partyFreightForwarder),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              onUpdateItem(
                                  index, item.copyWith(responsibleParty: val));
                            }
                          },
                        );

                        final statusDropdown = SearchableDropdownField<String>(
                          value: item.status,
                          labelText: l.statusCol,
                          items: [
                            SearchableDropdownItem(
                                value: 'Pending', label: l.statusPending),
                            SearchableDropdownItem(
                                value: 'Received', label: l.statusReceived),
                            SearchableDropdownItem(
                                value: 'Verified', label: l.statusVerified),
                            SearchableDropdownItem(
                                value: 'Approved', label: l.statusApproved),
                            SearchableDropdownItem(
                                value: 'Rejected', label: l.statusRejected),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              onUpdateItem(index, item.copyWith(status: val));
                            }
                          },
                        );

                        final actionIcons = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                item.isBlockingShipment
                                    ? Icons.block
                                    : Icons.check_circle_outline,
                                color: item.isBlockingShipment
                                    ? AppTheme.crimson
                                    : AppTheme.textMuted,
                                size: 20,
                              ),
                              tooltip: item.isBlockingShipment
                                  ? l.blockingConditionTooltip
                                  : l.nonBlockingConditionTooltip,
                              onPressed: () {
                                onUpdateItem(
                                  index,
                                  item.copyWith(
                                      isBlockingShipment: !item.isBlockingShipment),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded,
                                  color: AppTheme.cobalt, size: 20),
                              tooltip: l.cloneChecklistItemTooltip,
                              onPressed: () => onCloneItem(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.textMuted, size: 20),
                              onPressed: () => onDeleteItem(index),
                            ),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              infoContent,
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: responsibleDropdown),
                                  const SizedBox(width: 8),
                                  Expanded(child: statusDropdown),
                                  const SizedBox(width: 8),
                                  actionIcons,
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: infoContent),
                            const SizedBox(width: 12),
                            SizedBox(width: 190, child: responsibleDropdown),
                            const SizedBox(width: 8),
                            SizedBox(width: 160, child: statusDropdown),
                            const SizedBox(width: 8),
                            actionIcons,
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
