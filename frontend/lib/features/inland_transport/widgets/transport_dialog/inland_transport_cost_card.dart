import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/inland_transport_model.dart';
import 'inland_transport_header.dart';

/// KPI cost and status summary cards for Inland Transport.
class InlandTransportCostCard extends StatelessWidget {
  final ImportFileModel file;
  final InlandTransportModel? existingBooking;

  const InlandTransportCostCard({
    super.key,
    required this.file,
    this.existingBooking,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = existingBooking?.status ?? file.inlandTransportStatus;
    final fare = existingBooking?.transportFareEgp ?? file.inlandTransportCostEgp;
    final driver = existingBooking?.driverName ?? file.inlandDriverName ?? l10n.inlandNotSet;
    final truck = existingBooking?.truckPlateNumber ?? file.inlandTruckPlateNo ?? l10n.inlandNotSet;
    final waybill = existingBooking?.waybillNumber ?? file.inlandTransportBookingNo ?? l10n.inlandWaybillPending;

    final tiles = <Widget>[
      _InlandKpiTile(
        title: l10n.inlandKpiStatus,
        value: InlandStatus.label(l10n, status),
        icon: Icons.alt_route_rounded,
        color: InlandStatus.color(status),
      ),
      _InlandKpiTile(
        title: l10n.inlandKpiWaybill,
        value: waybill,
        icon: Icons.receipt_rounded,
        color: AppTheme.cobalt,
      ),
      _InlandKpiTile(
        title: l10n.inlandKpiTruckDriver,
        value: '$truck / $driver',
        icon: Icons.person_pin_rounded,
        color: AppTheme.charcoal,
      ),
      _InlandKpiTile(
        title: l10n.inlandKpiFare,
        value: '${fare.toStringAsFixed(2)} ${l10n.inlandCurrencySuffix}',
        icon: Icons.monetization_on_outlined,
        color: AppTheme.emerald,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final cols = c.maxWidth >= 760 ? 4 : 2;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _InlandKpiTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InlandKpiTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: AppTheme.cardDecorationOf(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
