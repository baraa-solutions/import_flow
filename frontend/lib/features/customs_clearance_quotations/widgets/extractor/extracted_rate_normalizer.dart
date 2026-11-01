/// Fills missing top-level rate fields from the preferred (40HQ) rate option.
void normalizeExtractedRateData(Map<String, dynamic> extracted) {
  if (extracted['rate_options'] is List && (extracted['rate_options'] as List).isNotEmpty) {
    final opts = extracted['rate_options'] as List;
    final primaryOpt = opts.firstWhere(
      (o) => (o as Map)['container_type'] == '40HQ',
      orElse: () => opts.first,
    ) as Map<String, dynamic>;

    final currentTotal = (extracted['total_estimated_clearance_cost'] as num?)?.toDouble() ?? 0.0;
    final currentType = extracted['container_type'] as String?;

    if (currentType == null || currentType.isEmpty || currentTotal < 2000.0) {
      extracted['container_type'] = primaryOpt['container_type'];
      extracted['clearance_fee'] = primaryOpt['clearance_fee'];
      extracted['inland_transport_fee'] = primaryOpt['inland_transport_fee'];
      extracted['inspection_fee'] = primaryOpt['inspection_fee'];
      extracted['port_expenses'] = primaryOpt['port_expenses'];
      extracted['total_estimated_clearance_cost'] = primaryOpt['total_estimated_clearance_cost'];
      if (primaryOpt['notes'] != null) {
        extracted['notes'] = primaryOpt['notes'];
      }
    }
  }
}
