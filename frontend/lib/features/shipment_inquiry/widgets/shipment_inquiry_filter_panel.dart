import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../providers/shipment_inquiry_provider.dart';

class ShipmentInquiryFilterPanel extends ConsumerStatefulWidget {
  final VoidCallback onSearch;
  final VoidCallback onExportPrint;

  const ShipmentInquiryFilterPanel({
    super.key,
    required this.onSearch,
    required this.onExportPrint,
  });

  @override
  ConsumerState<ShipmentInquiryFilterPanel> createState() =>
      _ShipmentInquiryFilterPanelState();
}

class _ShipmentInquiryFilterPanelState
    extends ConsumerState<ShipmentInquiryFilterPanel> {
  late final TextEditingController _hsCodeController;
  late final TextEditingController _polController;
  late final TextEditingController _podController;
  late final TextEditingController _carrierController;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(shipmentInquiryStateProvider).filters;
    _hsCodeController = TextEditingController(text: filters.hsCodeOrProduct);
    _polController = TextEditingController(text: filters.portOfLoading ?? '');
    _podController = TextEditingController(text: filters.portOfDischarge ?? '');
    _carrierController = TextEditingController(text: filters.carrier ?? '');
  }

  @override
  void dispose() {
    _hsCodeController.dispose();
    _polController.dispose();
    _podController.dispose();
    _carrierController.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    ref.read(shipmentInquiryStateProvider.notifier).updateFilter(
          hsCodeOrProduct: _hsCodeController.text.trim(),
          portOfLoading: _polController.text.trim(),
          portOfDischarge: _podController.text.trim(),
          carrier: _carrierController.text.trim(),
        );
    widget.onSearch();
  }

  void _handleReset() {
    _hsCodeController.clear();
    _polController.clear();
    _podController.clear();
    _carrierController.clear();
    ref.read(shipmentInquiryStateProvider.notifier).resetFilters();
    widget.onSearch();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final inquiryState = ref.watch(shipmentInquiryStateProvider);
    final filters = inquiryState.filters;

    final suppliersAsync = ref.watch(suppliersProvider);
    final companiesAsync = ref.watch(importCompaniesProvider);

    final isExpanded = inquiryState.isAdvancedExpanded;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Primary Row (Matches user mockup image media_1789045131329.png) ────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Supplier Dropdown
              Expanded(
                flex: 3,
                child: suppliersAsync.maybeWhen(
                  data: (suppliers) {
                    final items = [
                      SearchableDropdownItem<int?>(
                        value: null,
                        label: l.inqAllSuppliers,
                      ),
                      ...suppliers.map((s) => SearchableDropdownItem<int?>(
                            value: s.supplierId,
                            label: s.country.isNotEmpty
                                ? '${s.companyName} (${s.country})'
                                : s.companyName,
                          )),
                    ];

                    return SearchableDropdownField<int?>(
                      value: filters.supplierId,
                      items: items,
                      labelText: l.inqSupplier,
                      hintText: l.inqAllSuppliers,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) {
                        ref.read(shipmentInquiryStateProvider.notifier).updateFilter(
                              supplierId: val,
                              clearSupplier: val == null,
                            );
                      },
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),

              // Importer Dropdown
              Expanded(
                flex: 3,
                child: companiesAsync.maybeWhen(
                  data: (companies) {
                    final items = [
                      SearchableDropdownItem<int?>(
                        value: null,
                        label: l.inqAllImporters,
                      ),
                      ...companies.map((c) => SearchableDropdownItem<int?>(
                            value: c.companyId,
                            label: c.importerName,
                          )),
                    ];

                    return SearchableDropdownField<int?>(
                      value: filters.companyId,
                      items: items,
                      labelText: l.inqImporter,
                      hintText: l.inqAllImporters,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) {
                        ref.read(shipmentInquiryStateProvider.notifier).updateFilter(
                              companyId: val,
                              clearCompany: val == null,
                            );
                      },
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),

              // HS Code / Product Search
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _hsCodeController,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: l.inqHsCodeOrProduct,
                    hintText: l.inqHsCodeHint,
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    prefixIcon: const Icon(Icons.manage_search_outlined, color: Colors.white60, size: 18),
                    suffixIcon: _hsCodeController.text.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                                tooltip: l.inqCopyCodeTooltip,
                                onPressed: () => CopyHelper.copy(context, _hsCodeController.text),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                                onPressed: () {
                                  _hsCodeController.clear();
                                  _triggerSearch();
                                },
                              ),
                            ],
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _triggerSearch(),
                ),
              ),
              const SizedBox(width: 12),

              // Search Button (Pill shaped per mockup)
              ElevatedButton.icon(
                icon: const Icon(Icons.search, size: 18),
                label: Text(
                  l.inqSearchBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _triggerSearch,
              ),
              const SizedBox(width: 10),

              // Export / Print Report Button (Pill shaped per mockup)
              ElevatedButton.icon(
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text(
                  l.inqExportPrintBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: widget.onExportPrint,
              ),
              const SizedBox(width: 8),

              // Advanced Filters Toggle Button
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.tune_rounded,
                  color: isExpanded ? AppTheme.cobalt : Colors.white70,
                ),
                tooltip: isExpanded ? l.inqHideAdvancedFilters : l.inqAdvancedFilters,
                onPressed: () {
                  ref.read(shipmentInquiryStateProvider.notifier).toggleAdvancedExpanded();
                },
              ),
            ],
          ),

          // ─── Advanced Filters Row (Expandable) ───────────────────────────
          if (isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                // Incoterm
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String?>(
                    value: filters.incotermCode,
                    items: [
                      SearchableDropdownItem(value: null, label: l.inqAllIncoterms),
                      SearchableDropdownItem(value: 'EXW', label: l.inqIncotermExw),
                      SearchableDropdownItem(value: 'FOB', label: l.inqIncotermFob),
                      SearchableDropdownItem(value: 'CFR', label: l.inqIncotermCfr),
                      SearchableDropdownItem(value: 'CIF', label: l.inqIncotermCif),
                      SearchableDropdownItem(value: 'CIP', label: l.inqIncotermCip),
                      SearchableDropdownItem(value: 'DPU', label: l.inqIncotermDpu),
                      SearchableDropdownItem(value: 'DAP', label: l.inqIncotermDap),
                      SearchableDropdownItem(value: 'DDP', label: l.inqIncotermDdp),
                    ],
                    labelText: l.inqIncoterm,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onChanged: (val) {
                      ref.read(shipmentInquiryStateProvider.notifier).updateFilter(
                            incotermCode: val,
                            clearIncoterm: val == null,
                          );
                      _triggerSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Port of Loading (POL)
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _polController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: l.inqPortOfLoading,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onSubmitted: (_) => _triggerSearch(),
                  ),
                ),
                const SizedBox(width: 8),

                // Port of Discharge (POD)
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String?>(
                    value: filters.portOfDischarge,
                    items: [
                      SearchableDropdownItem(value: null, label: l.inqPortOfDischarge),
                      const SearchableDropdownItem(value: 'Alexandria', label: 'Alexandria'),
                      const SearchableDropdownItem(value: 'El Dekheila', label: 'El Dekheila'),
                      const SearchableDropdownItem(value: 'Port Said', label: 'Port Said'),
                      const SearchableDropdownItem(value: 'Damietta', label: 'Damietta'),
                      const SearchableDropdownItem(value: 'Sokhna', label: 'Sokhna'),
                      const SearchableDropdownItem(value: 'Cairo Airport', label: 'Cairo Airport'),
                    ],
                    labelText: l.inqPortOfDischarge,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onChanged: (val) {
                      _podController.text = val ?? '';
                      ref.read(shipmentInquiryStateProvider.notifier).updateFilter(
                            portOfDischarge: val,
                            clearPod: val == null,
                          );
                      _triggerSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Shipping Mode
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String?>(
                    value: filters.shipmentMode,
                    items: [
                      SearchableDropdownItem(value: null, label: l.inqAllModes),
                      SearchableDropdownItem(value: 'Sea FCL', label: l.inqModeSeaFcl),
                      SearchableDropdownItem(value: 'Sea LCL', label: l.inqModeSeaLcl),
                      SearchableDropdownItem(value: 'Air', label: l.inqModeAir),
                      SearchableDropdownItem(value: 'Land', label: l.inqModeLand),
                    ],
                    labelText: l.inqShippingMode,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onChanged: (val) {
                      ref.read(shipmentInquiryStateProvider.notifier).updateFilter(
                            shipmentMode: val,
                            clearMode: val == null,
                          );
                      _triggerSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Carrier / Shipping Line
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String?>(
                    value: filters.carrier,
                    items: [
                      SearchableDropdownItem(value: null, label: l.inqCarrier),
                      const SearchableDropdownItem(value: 'MSC', label: 'MSC Line'),
                      const SearchableDropdownItem(value: 'Maersk', label: 'Maersk Line'),
                      const SearchableDropdownItem(value: 'CMA CGM', label: 'CMA CGM'),
                      const SearchableDropdownItem(value: 'Hapag-Lloyd', label: 'Hapag-Lloyd'),
                      const SearchableDropdownItem(value: 'COSCO', label: 'COSCO Shipping'),
                      const SearchableDropdownItem(value: 'ONE', label: 'Ocean Network Express'),
                      const SearchableDropdownItem(value: 'Evergreen', label: 'Evergreen Line'),
                    ],
                    labelText: l.inqCarrier,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onChanged: (val) {
                      _carrierController.text = val ?? '';
                      ref.read(shipmentInquiryStateProvider.notifier).updateFilter(
                            carrier: val,
                            clearCarrier: val == null,
                          );
                      _triggerSearch();
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Reset Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: Text(l.inqResetBtn),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onPressed: _handleReset,
                ),
                const SizedBox(width: 6),

                // Save Preset Button
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined, color: Colors.amberAccent, size: 20),
                  tooltip: l.inqSaveFilterPreset,
                  onPressed: () {
                    final searchVal = _hsCodeController.text.isNotEmpty
                        ? _hsCodeController.text
                        : l.inqFilterPanelTitle;
                    ref.read(shipmentInquiryStateProvider.notifier).saveCurrentPreset(
                          '${l.inqSearchPrefix}$searchVal',
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l.inqPresetSaved),
                        backgroundColor: AppTheme.cobalt,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Date Range & Status Filter Bar (UX-SEARCH-013 Section 2)
            Row(
              children: [
                // Status Multi-select Chips
                Text(
                  '${l.inqFilterStatus}: ',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                ...['Draft', 'Open', 'In Progress', 'Completed', 'Closed'].map((statusKey) {
                  final isSelected = filters.statuses.contains(statusKey);
                  String label = statusKey;
                  if (statusKey == 'Draft') label = l.inqStatusDraft;
                  if (statusKey == 'In Progress' || statusKey == 'Open') label = l.inqStatusInProgress;
                  if (statusKey == 'Completed') label = l.inqStatusCompleted;
                  if (statusKey == 'Closed') label = l.inqStatusClosed;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white70)),
                      selected: isSelected,
                      selectedColor: AppTheme.cobalt,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      checkmarkColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      onSelected: (selected) {
                        final current = List<String>.from(filters.statuses);
                        if (selected) {
                          current.add(statusKey);
                        } else {
                          current.remove(statusKey);
                        }
                        ref.read(shipmentInquiryStateProvider.notifier).updateFilter(statuses: current);
                        _triggerSearch();
                      },
                    ),
                  );
                }),

                const Spacer(),

                // Date Range Buttons
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_outlined, size: 14, color: Colors.white70),
                  label: Text(
                    filters.dateFrom != null
                        ? '${filters.dateFrom!.year}/${filters.dateFrom!.month} → ${filters.dateTo?.year ?? ''}/${filters.dateTo?.month ?? ''}'
                        : l.inqDateRange,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      initialDateRange: filters.dateFrom != null && filters.dateTo != null
                          ? DateTimeRange(start: filters.dateFrom!, end: filters.dateTo!)
                          : DateTimeRange(
                              start: DateTime.now().subtract(const Duration(days: 365)),
                              end: DateTime.now(),
                            ),
                    );
                    if (picked != null) {
                      ref.read(shipmentInquiryStateProvider.notifier).updateFilter(
                            dateFrom: picked.start,
                            dateTo: picked.end,
                          );
                      _triggerSearch();
                    }
                  },
                ),
                if (filters.dateFrom != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 14, color: Colors.white60),
                    tooltip: l.inqResetBtn,
                    onPressed: () {
                      ref.read(shipmentInquiryStateProvider.notifier).updateFilter(
                            clearDateFrom: true,
                            clearDateTo: true,
                          );
                      _triggerSearch();
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
