import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_date_picker_field.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../incoterms/providers/incoterms_provider.dart';
import '../../../transport_locations/providers/transport_locations_provider.dart';
import '../import_file_form_dialog.dart';

/// 🚢 Tab 2: Shipping & Logistics for [ImportFileFormDialog].
///
/// Houses shipment mode, Incoterms, priority, shipment category, target ETA,
/// file opening date, lifecycle starting step, ports of loading/discharge,
/// cargo ready date, free detention days, and routing instructions.
class ImportFileFormShippingTab extends ConsumerStatefulWidget {
  final ImportFileFormDialogState dialog;

  const ImportFileFormShippingTab({super.key, required this.dialog});

  @override
  ConsumerState<ImportFileFormShippingTab> createState() => _ImportFileFormShippingTabState();
}

class _ImportFileFormShippingTabState extends ConsumerState<ImportFileFormShippingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dialog = widget.dialog;
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final incoterms = ref.watch(incotermsProvider).valueOrNull ?? [];
    final locations = ref.watch(transportLocationsProvider).asData?.value ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Shipment Mode, Incoterms, Priority ─────────────────
          Row(
            children: [
              Expanded(
                child: SearchableDropdownField<String>(
                  value: ['Sea FCL', 'Sea LCL', 'Air', 'Courier', 'Land', 'Multimodal'].contains(dialog.shipmentMode)
                      ? dialog.shipmentMode
                      : 'Sea FCL',
                  labelText: '${l.transportModeIncoterm} *',
                  items: const [
                    SearchableDropdownItem(value: 'Sea FCL', label: 'Sea FCL', searchValue: 'Sea FCL بحري حاوية كاملة'),
                    SearchableDropdownItem(value: 'Sea LCL', label: 'Sea LCL', searchValue: 'Sea LCL بحري جزئي طرد'),
                    SearchableDropdownItem(value: 'Air', label: 'Air', searchValue: 'Air جوي شحن جوي'),
                    SearchableDropdownItem(value: 'Courier', label: 'Courier', searchValue: 'Courier Express بريد سريع شحن سريع DHL FedEx Aramex UPS'),
                    SearchableDropdownItem(value: 'Land', label: 'Land', searchValue: 'Land بري شحن بري'),
                    SearchableDropdownItem(value: 'Multimodal', label: 'Multimodal', searchValue: 'Multimodal multi modes متعدد الوسائط مركب'),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      dialog.setState(() => dialog.shipmentMode = v);
                      dialog.markDirty();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SearchableDropdownField<String>(
                  value: incoterms.any((i) => i.incotermCode == dialog.incotermCode) ? dialog.incotermCode : 'FOB',
                  labelText: '${l.incotermsRules} *',
                  searchHintText: l.incotermsRules,
                  items: (incoterms.isNotEmpty
                          ? incoterms.map((i) => i.incotermCode).toList()
                          : ['FOB', 'CIF', 'CFR', 'EXW', 'FCA', 'CIP', 'DDP', 'DAP'])
                      .map((code) => SearchableDropdownItem<String>(value: code, label: code))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      dialog.setState(() => dialog.incotermCode = v);
                      dialog.markDirty();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SearchableDropdownField<String>(
                  value: dialog.priority,
                  labelText: '${l.priorityType} *',
                  searchHintText: l.priorityType,
                  items: const [
                    SearchableDropdownItem(value: 'Low', label: 'Low'),
                    SearchableDropdownItem(value: 'Medium', label: 'Medium'),
                    SearchableDropdownItem(value: 'High', label: 'High'),
                    SearchableDropdownItem(value: 'Critical', label: 'Critical'),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      dialog.setState(() => dialog.priority = v);
                      dialog.markDirty();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Row 2: Shipment Category, Target ETA, File Opening Date ────
          Row(
            children: [
              Expanded(
                child: SearchableDropdownField<String>(
                  value: dialog.shipmentCategory,
                  labelText: '${l.shipmentCategoryLabel} *',
                  searchHintText: l.shipmentCategoryLabel,
                  items: const [
                    SearchableDropdownItem(value: 'New Purchase', label: 'New Purchase'),
                    SearchableDropdownItem(value: 'Replacement', label: 'Replacement'),
                    SearchableDropdownItem(value: 'Repair', label: 'Repair'),
                    SearchableDropdownItem(value: 'Sample', label: 'Sample'),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      dialog.setState(() => dialog.shipmentCategory = v);
                      dialog.markDirty();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDatePickerField(
                  label: '${l.targetEta} *',
                  value: dialog.requiredEta,
                  onChanged: (d) {
                    if (d != null) {
                      dialog.setState(() => dialog.requiredEta = d);
                      dialog.markDirty();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDatePickerField(
                  label: '${l.fileOpeningDateLabel} *',
                  value: dialog.fileOpeningDate,
                  onChanged: (d) {
                    if (d != null) {
                      dialog.setState(() => dialog.fileOpeningDate = d);
                      dialog.markDirty();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Lifecycle Starting Step Selector ──────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF4F46E5).withValues(alpha: 0.4) : const Color(0xFFA5B4FC),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline_rounded, color: Color(0xFF4F46E5), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: SearchableDropdownField<String>(
                    value: dialog.initialStartingStep,
                    labelText: '${l.currentPhaseStage} *',
                    searchHintText: l.currentPhaseStage,
                    items: [
                      SearchableDropdownItem(value: 'STEP_01', label: DisplayNameResolver.resolveStepName('STEP_01', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_04', label: DisplayNameResolver.resolveStepName('STEP_04', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_05', label: DisplayNameResolver.resolveStepName('STEP_05', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_06', label: DisplayNameResolver.resolveStepName('STEP_06', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_08_PO', label: DisplayNameResolver.resolveStepName('STEP_08_PO', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_08_BL', label: DisplayNameResolver.resolveStepName('STEP_08_BL', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_08', label: DisplayNameResolver.resolveStepName('STEP_08', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_10', label: DisplayNameResolver.resolveStepName('STEP_10', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_12', label: DisplayNameResolver.resolveStepName('STEP_12', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_13', label: DisplayNameResolver.resolveStepName('STEP_13', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_14', label: DisplayNameResolver.resolveStepName('STEP_14', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_17', label: DisplayNameResolver.resolveStepName('STEP_17', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_19', label: DisplayNameResolver.resolveStepName('STEP_19', isArabic: isArabic)),
                      SearchableDropdownItem(value: 'STEP_20', label: DisplayNameResolver.resolveStepName('STEP_20', isArabic: isArabic)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        dialog.setState(() => dialog.initialStartingStep = v);
                        dialog.markDirty();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Logistics & Freight RFQ Details Container ─────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppTheme.emerald.withValues(alpha: 0.4) : const Color(0xFF86EFAC),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, color: AppTheme.emerald, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l.logisticsAndPortsDetails,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.emerald : const Color(0xFF166534),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SearchableDropdownField<String>(
                        value: dialog.polController.text.isNotEmpty ? dialog.polController.text : null,
                        labelText: l.portOfLoadingLabel,
                        searchHintText: l.portOfLoadingLabel,
                        items: [
                          if (dialog.polController.text.isNotEmpty && !locations.any((loc) => loc.locationName == dialog.polController.text))
                            SearchableDropdownItem<String>(value: dialog.polController.text, label: dialog.polController.text),
                          ...locations.map((loc) => SearchableDropdownItem<String>(
                                value: loc.locationName,
                                label: '${loc.locationName} (${loc.country}${loc.unLocode.isNotEmpty ? " - ${loc.unLocode}" : ""})',
                                subtitle: '${loc.locationType} - ${loc.country}',
                              )),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            dialog.setState(() => dialog.polController.text = v);
                            dialog.markDirty();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SearchableDropdownField<String>(
                        value: dialog.podController.text.isNotEmpty ? dialog.podController.text : 'El Dekheila Port (non TMT)',
                        labelText: l.portOfDischargeLabel,
                        searchHintText: l.portOfDischargeLabel,
                        items: [
                          if (dialog.podController.text.isNotEmpty && !locations.any((loc) => loc.locationName == dialog.podController.text))
                            SearchableDropdownItem<String>(value: dialog.podController.text, label: dialog.podController.text),
                          ...[
                            ...locations.where((loc) => loc.country == 'Egypt' || loc.unLocode.startsWith('EG')),
                            ...locations.where((loc) => loc.country != 'Egypt' && !loc.unLocode.startsWith('EG')),
                          ].map((loc) => SearchableDropdownItem<String>(
                                value: loc.locationName,
                                label: '${loc.locationName} (${loc.country}${loc.unLocode.isNotEmpty ? " - ${loc.unLocode}" : ""})',
                                subtitle: '${loc.locationType} - ${loc.country}',
                              )),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            dialog.setState(() => dialog.podController.text = v);
                            dialog.markDirty();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDatePickerField(
                        label: l.cargoReadyDateLabel,
                        value: dialog.cargoReadyDate,
                        onChanged: (d) {
                          if (d != null) {
                            dialog.setState(() => dialog.cargoReadyDate = d);
                            dialog.markDirty();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: TextFormField(
                        controller: dialog.targetFreeDaysController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l.targetFreeDaysLabel,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SearchableDropdownField<String>(
                        value: dialog.serviceTypePreference,
                        labelText: l.serviceTypePreferenceLabel,
                        items: const [
                          SearchableDropdownItem(value: 'Direct', label: 'Direct Service'),
                          SearchableDropdownItem(value: 'Transshipment Acceptable', label: 'Transshipment Acceptable'),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            dialog.setState(() => dialog.serviceTypePreference = v);
                            dialog.markDirty();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: dialog.pickupAddressController,
                        decoration: InputDecoration(
                          labelText: l.pickupAddressLabel,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: dialog.shippingInstructionsNotesController,
                  decoration: InputDecoration(
                    labelText: l.shippingInstructionsLabel,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
