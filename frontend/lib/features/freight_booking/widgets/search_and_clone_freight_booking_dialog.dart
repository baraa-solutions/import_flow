import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/freight_booking_model.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
/// Search and Clone Previous Freight Booking Dialog (Screen 25 / UX-CLONE-025)
///
/// Allows operators to quickly search past freight bookings by code, confirmation number,
/// carrier, route (POL/POD), or vessel, and select one to clone into a new editable draft.
class SearchAndCloneFreightBookingDialog extends StatefulWidget {
  final List<ShipmentBookingModel> bookings;
  final ValueChanged<ShipmentBookingModel> onSelectBooking;

  const SearchAndCloneFreightBookingDialog({
    super.key,
    required this.bookings,
    required this.onSelectBooking,
  });

  @override
  State<SearchAndCloneFreightBookingDialog> createState() =>
      _SearchAndCloneFreightBookingDialogState();
}

class _SearchAndCloneFreightBookingDialogState
    extends State<SearchAndCloneFreightBookingDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';
  late List<ShipmentBookingModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.bookings;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.bookings.where((b) {
        final matchesStatus = _selectedStatus == 'All' || b.status == _selectedStatus;
        if (!matchesStatus) return false;

        if (q.isEmpty) return true;

        final code = b.bookingCode.toLowerCase();
        final confirmNo = (b.bookingConfirmationNo ?? '').toLowerCase();
        final file = (b.importFileCode ?? '').toLowerCase();
        final line = (b.shippingLineName ?? '').toLowerCase();
        final fwd = (b.freightForwarderName ?? '').toLowerCase();
        final pol = (b.polName ?? '').toLowerCase();
        final pod = (b.podName ?? '').toLowerCase();
        final vessel = (b.vesselName ?? '').toLowerCase();
        final voyage = (b.voyageNumber ?? '').toLowerCase();

        return code.contains(q) ||
            confirmNo.contains(q) ||
            file.contains(q) ||
            line.contains(q) ||
            fwd.contains(q) ||
            pol.contains(q) ||
            pod.contains(q) ||
            vessel.contains(q) ||
            voyage.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth - 32).clamp(360.0, 920.0);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.copy_all_rounded,
                      color: AppTheme.cobalt,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.cloneFreightBookingDialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.cloneFreightBookingDialogSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l.freightBookingCloseTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Search Box
              TextField(
                key: const Key('searchCloneBookingQueryField'),
                controller: _searchController,
                onChanged: (_) => _applyFilter(),
                decoration: InputDecoration(
                  hintText: l.freightBookingSearchHint,
                  hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                ),
                style: TextStyle(
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Status Filter Chips (Wrapped for responsive display)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildStatusChip('All', l.freightBookingStatusAll, isDark),
                  _buildStatusChip('Draft', l.freightBookingStatusDraft, isDark),
                  _buildStatusChip('Booking Requested', l.freightBookingStatusRequested, isDark),
                  _buildStatusChip('Confirmed', l.freightBookingStatusConfirmed, isDark),
                  _buildStatusChip('Sailed', l.freightBookingStatusSailed, isDark),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Booking Cards List
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          l.freightBookingEmptyRecords,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final bkg = _filtered[index];
                          return _buildBookingCard(bkg, isDark, l);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String statusKey, String label, bool isDark) {
    final isSelected = _selectedStatus == statusKey;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = statusKey;
        });
        _applyFilter();
      },
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? Colors.white
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
      selectedColor: AppTheme.cobalt,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? AppTheme.cobalt
              : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  Widget _buildBookingCard(ShipmentBookingModel bkg, bool isDark, AppLocalizations l) {
    final routeText = '${bkg.polName ?? "—"} ➔ ${bkg.podName ?? "—"}';
    final carrierText = '${bkg.shippingLineName ?? "—"} / ${bkg.freightForwarderName ?? "—"}';
    final containersText = bkg.containersData.isNotEmpty
        ? bkg.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', ')
        : '—';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: Code & Status & Confirmation
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: LtrText(
                        bkg.bookingCode,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cobalt,
                        ),
                      ),
                    ),
                    if (bkg.bookingConfirmationNo != null && bkg.bookingConfirmationNo!.isNotEmpty)
                      Text(
                        '#${bkg.bookingConfirmationNo}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: bkg.status == 'Confirmed' || bkg.status == 'Sailed'
                            ? AppTheme.emerald.withOpacity(0.15)
                            : AppTheme.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        bkg.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: bkg.status == 'Confirmed' || bkg.status == 'Sailed'
                              ? AppTheme.emerald
                              : AppTheme.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Line 2: Route & Carrier
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.cobalt),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        routeText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Line 3: Carrier & Containers & Cost
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      carrierText,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      containersText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cobalt,
                      ),
                    ),
                    Text(
                      '\$ ${bkg.totalFreightCostUsd.toStringAsFixed(2)} USD',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Clone Action Button
          ElevatedButton.icon(
            key: Key('selectCloneBookingBtn_${bkg.bookingCode}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: Text(
              l.cloneBookingRowTooltip,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onSelectBooking(bkg);
            },
          ),
        ],
      ),
    );
  }
}
