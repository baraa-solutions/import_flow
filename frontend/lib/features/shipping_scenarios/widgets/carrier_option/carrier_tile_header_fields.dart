import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../external_service_providers/models/partner_model.dart';
import '../../models/shipping_scenario_model.dart';

class CarrierTileHeaderFields extends StatelessWidget {
  final int index;
  final ShippingScenarioItemModel item;
  final ValueChanged<ShippingScenarioItemModel> onUpdateItem;
  final VoidCallback onClone;
  final VoidCallback onDelete;
  final List<PartnerModel> freightForwarders;
  final List<PartnerModel> shippingLines;
  final List<PartnerModel> customsBrokers;
  final List<dynamic> portsList;
  final int? editingSessionId;
  final int editFormVersion;
  final VoidCallback? onRefreshData;
  final bool isNarrowCard;

  const CarrierTileHeaderFields({
    super.key,
    required this.index,
    required this.item,
    required this.onUpdateItem,
    required this.onClone,
    required this.onDelete,
    required this.freightForwarders,
    required this.shippingLines,
    required this.customsBrokers,
    required this.portsList,
    required this.editingSessionId,
    required this.editFormVersion,
    required this.isNarrowCard,
    this.onRefreshData,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatarWidget = CircleAvatar(
      radius: 14,
      backgroundColor: item.isRecommended ? AppTheme.emerald : AppTheme.cobalt,
      child: Text(
        '${index + 1}',
        style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );

    final forwarderDropdown = SearchableDropdownField<int?>(
      value: item.providerId,
      labelText: l.freightForwarderCol,
      searchHintText: l.forwarderSearchHint,
      items: [
        SearchableDropdownItem<int?>(value: null, label: l.unassigned),
        ...freightForwarders.map((p) => SearchableDropdownItem<int?>(
              value: p.providerId,
              label: '${p.partnerName}${p.partnerCode.isNotEmpty ? " (${p.partnerCode})" : ""}',
              searchValue: '${p.partnerName} ${p.partnerCode} ${p.partnerType}',
            )),
      ],
      onChanged: (val) {
        final partner = freightForwarders.where((p) => p.providerId == val).firstOrNull;
        onUpdateItem(item.copyWith(
          providerId: val,
          providerName: partner != null ? partner.partnerName : item.providerName,
        ));
      },
    );

    final shippingLineDropdown = SearchableDropdownField<String>(
      value: shippingLines.any((p) => p.partnerName == item.providerName)
          ? item.providerName
          : (item.providerName.isNotEmpty ? item.providerName : ''),
      labelText: '${l.shippingLineCol} *',
      searchHintText: l.shippingLineSearchHint,
      items: [
        SearchableDropdownItem<String>(value: '', label: l.unassigned),
        if (item.providerName.isNotEmpty && !shippingLines.any((p) => p.partnerName == item.providerName))
          SearchableDropdownItem<String>(
            value: item.providerName,
            label: '★ ${item.providerName} (${l.suggestedSuffix})',
            searchValue: item.providerName,
          ),
        ...shippingLines.map((p) => SearchableDropdownItem<String>(
              value: p.partnerName,
              label: '${p.partnerName}${p.scacCode != null && p.scacCode!.isNotEmpty ? " (${p.scacCode})" : ""}',
              searchValue: '${p.partnerName} ${p.partnerCode} ${p.scacCode ?? ""} ${p.partnerType}',
              subtitle: p.scacCode != null && p.scacCode!.isNotEmpty ? 'SCAC: ${p.scacCode}' : p.partnerCode,
            )),
      ],
      onChanged: (val) {
        if (val != null && val.isNotEmpty) {
          onUpdateItem(item.copyWith(providerName: val));
        }
      },
    );

    final addShippingLineBtn = IconButton(
      icon: const Icon(Icons.add_business_outlined, color: AppTheme.emerald, size: 20),
      tooltip: l.addNewLineTooltip,
      onPressed: () => UniversalEntityExtractorDialog.showShippingLineExtractor(
        context,
        onSaved: () => onRefreshData?.call(),
      ),
    );

    final vesselField = TextFormField(
      key: ValueKey('vessel_${editingSessionId ?? "new"}_${index}_$editFormVersion'),
      initialValue: item.vesselName,
      decoration: InputDecoration(labelText: '${l.vesselNameCol} *', isDense: true),
      validator: (v) => v == null || v.trim().isEmpty ? l.requiredField : null,
      onChanged: (v) => onUpdateItem(item.copyWith(vesselName: v.trim())),
    );

    final voyageField = TextFormField(
      key: ValueKey('voyage_${editingSessionId ?? "new"}_${index}_$editFormVersion'),
      initialValue: item.voyageNumber ?? '',
      decoration: InputDecoration(labelText: l.voyageCol, isDense: true),
      onChanged: (v) => onUpdateItem(item.copyWith(voyageNumber: v.trim())),
    );

    final cloneCarrierBtn = IconButton(
      icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
      tooltip: l.cloneCarrierOptionTooltip,
      onPressed: onClone,
    );

    final deleteCarrierBtn = IconButton(
      icon: const Icon(Icons.delete_outline, color: AppTheme.crimson),
      onPressed: onDelete,
    );

    final polDropdown = SearchableDropdownField<int?>(
      value: item.portOfLoadingId,
      labelText: l.portOfLoadingCol,
      items: [
        SearchableDropdownItem<int?>(value: null, label: l.unassigned),
        ...portsList.map((p) => SearchableDropdownItem<int?>(
              value: p.locationId,
              label: '${p.unLocode} - ${p.locationName} (${p.country})',
            )),
      ],
      onChanged: (val) {
        final selectedPort = portsList.where((p) => p.locationId == val).firstOrNull;
        onUpdateItem(item.copyWith(
          portOfLoadingId: val,
          polName: selectedPort != null ? selectedPort.locationName : item.polName,
        ));
      },
    );

    final podDropdown = SearchableDropdownField<int?>(
      value: item.portOfDischargeId,
      labelText: l.portOfDischargeCol,
      items: [
        SearchableDropdownItem<int?>(value: null, label: l.unassigned),
        ...portsList.map((p) => SearchableDropdownItem<int?>(
              value: p.locationId,
              label: '${p.unLocode} - ${p.locationName} (${p.country})',
            )),
      ],
      onChanged: (val) {
        final selectedPort = portsList.where((p) => p.locationId == val).firstOrNull;
        onUpdateItem(item.copyWith(
          portOfDischargeId: val,
          podName: selectedPort != null ? selectedPort.locationName : item.podName,
        ));
      },
    );

    final brokerDropdown = SearchableDropdownField<int?>(
      value: item.customsBrokerId,
      labelText: l.customsBrokerLabel,
      items: [
        SearchableDropdownItem<int?>(value: null, label: l.unassigned),
        ...customsBrokers.map((p) => SearchableDropdownItem<int?>(
              value: p.providerId,
              label: p.partnerName,
            )),
      ],
      onChanged: (val) {
        final partner = customsBrokers.where((p) => p.providerId == val).firstOrNull;
        final hasClearance = item.clearanceFeePrice > 0;
        onUpdateItem(item.copyWith(
          customsBrokerId: val,
          customsBrokerName: partner?.partnerName,
          clearanceFeeApplicable: val != null ? true : item.clearanceFeeApplicable,
          clearanceFeePrice: (!hasClearance && val != null) ? 2500.0 : item.clearanceFeePrice,
          clearanceFeeCurrency: "EGP",
          inspectionFeeApplicable: val != null ? true : item.inspectionFeeApplicable,
          inspectionFeePrice: (!hasClearance && val != null) ? 3500.0 : item.inspectionFeePrice,
          inspectionFeeCurrency: "EGP",
          inlandTransportFeeApplicable: val != null ? true : item.inlandTransportFeeApplicable,
          inlandTransportFeePrice: (!hasClearance && val != null) ? 14800.0 : item.inlandTransportFeePrice,
          inlandTransportFeeCurrency: "EGP",
          portExpensesApplicable: val != null ? true : item.portExpensesApplicable,
          portExpensesPrice: (!hasClearance && val != null) ? 4750.0 : item.portExpensesPrice,
          portExpensesCurrency: "EGP",
        ));
      },
    );

    final sailingDatePicker = InkWell(
      onTap: () async {
        final sDate = DateTime.tryParse(item.sailingDate) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: sDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          onUpdateItem(item.copyWith(sailingDate: picked.toString().substring(0, 10)));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: '${l.sailingDateCol} *', isDense: true),
        child: Text(
          item.sailingDate.isNotEmpty ? item.sailingDate : l.unassigned,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: item.sailingDate.isNotEmpty
                ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)
                : (isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
          ),
        ),
      ),
    );

    final etaDatePicker = InkWell(
      onTap: () async {
        final etaDate = DateTime.tryParse(item.estimatedArrivalDate) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: etaDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          onUpdateItem(item.copyWith(estimatedArrivalDate: picked.toString().substring(0, 10)));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: '${l.estimatedArrivalDateCol} *', isDense: true),
        child: Text(
          item.estimatedArrivalDate.isNotEmpty ? item.estimatedArrivalDate : l.unassigned,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: item.estimatedArrivalDate.isNotEmpty
                ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)
                : (isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
          ),
        ),
      ),
    );

    final delayField = TextFormField(
      key: ValueKey('delay_${editingSessionId ?? "new"}_${index}_$editFormVersion'),
      initialValue: item.expectedLineDelayDays.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: l.expectedDelayCol, isDense: true),
      onChanged: (v) {
        final delay = int.tryParse(v) ?? 0;
        onUpdateItem(item.copyWith(expectedLineDelayDays: delay));
      },
    );

    final riskDropdown = SearchableDropdownField<String>(
      value: item.riskLevel,
      labelText: l.riskLevelCol,
      items: const [
        SearchableDropdownItem(value: 'Low', label: 'Low Risk 🟢'),
        SearchableDropdownItem(value: 'Medium', label: 'Medium Risk 🟠'),
        SearchableDropdownItem(value: 'High', label: 'High Risk 🔴'),
      ],
      onChanged: (v) {
        if (v != null) {
          onUpdateItem(item.copyWith(riskLevel: v));
        }
      },
    );

    final excludedChip = FilterChip(
      label: Text(
        item.isExcludedFromAverage ? l.excludedFromAvg : l.includedInAvg,
        style: TextStyle(
          fontSize: 11,
          color: item.isExcludedFromAverage ? AppTheme.crimson : AppTheme.cobalt,
        ),
      ),
      selected: item.isExcludedFromAverage,
      onSelected: (val) {
        onUpdateItem(item.copyWith(isExcludedFromAverage: val));
      },
    );

    if (isNarrowCard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              avatarWidget,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.providerName.isNotEmpty ? item.providerName : '${l.carrierOptionHeader} #${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              cloneCarrierBtn,
              deleteCarrierBtn,
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: forwarderDropdown),
              const SizedBox(width: 8),
              Expanded(child: shippingLineDropdown),
              addShippingLineBtn,
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(flex: 2, child: vesselField),
              const SizedBox(width: 8),
              Expanded(child: voyageField),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: polDropdown),
              const SizedBox(width: 8),
              Expanded(child: podDropdown),
            ],
          ),
          const SizedBox(height: 10),
          brokerDropdown,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: sailingDatePicker),
              const SizedBox(width: 8),
              Expanded(child: etaDatePicker),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: delayField),
              const SizedBox(width: 8),
              Expanded(child: riskDropdown),
              const SizedBox(width: 8),
              excludedChip,
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            avatarWidget,
            const SizedBox(width: 10),
            Expanded(flex: 2, child: forwarderDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: shippingLineDropdown),
            const SizedBox(width: 4),
            addShippingLineBtn,
            const SizedBox(width: 6),
            Expanded(flex: 2, child: vesselField),
            const SizedBox(width: 10),
            Expanded(child: voyageField),
            const SizedBox(width: 4),
            cloneCarrierBtn,
            const SizedBox(width: 4),
            deleteCarrierBtn,
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: polDropdown),
            const SizedBox(width: 12),
            Expanded(child: podDropdown),
            const SizedBox(width: 12),
            Expanded(child: brokerDropdown),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: sailingDatePicker),
            const SizedBox(width: 10),
            Expanded(child: etaDatePicker),
            const SizedBox(width: 10),
            Expanded(child: delayField),
            const SizedBox(width: 10),
            Expanded(child: riskDropdown),
            const SizedBox(width: 10),
            excludedChip,
          ],
        ),
      ],
    );
  }
}
