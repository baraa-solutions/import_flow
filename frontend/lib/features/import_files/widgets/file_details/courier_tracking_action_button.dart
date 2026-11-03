// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/import_file_model.dart';

/// 📦 Decoupled Courier & Air Express Tracking Action Widget.
///
/// Complies with:
/// - Universal Mouse Selection (`SelectionArea`)
/// - Pure View Separation (100% Arabic in Arabic mode, zero bilingual parentheticals)
/// - Approved Theme & Widgets ([AppButton], [CopyHelper.copy], [AppTheme])
class CourierTrackingActionButton extends StatelessWidget {
  final String? courierOperator;
  final String? courierTrackingNo;
  final String? shipmentMode;
  final String? shipmentSubMode;
  final bool compact;

  const CourierTrackingActionButton({
    super.key,
    this.courierOperator,
    this.courierTrackingNo,
    this.shipmentMode,
    this.shipmentSubMode,
    this.compact = false,
  });

  factory CourierTrackingActionButton.fromImportFile(
    ImportFileModel file, {
    Key? key,
    bool compact = false,
  }) {
    return CourierTrackingActionButton(
      key: key,
      courierOperator: file.courierOperator,
      courierTrackingNo: file.courierTrackingNo,
      shipmentMode: file.shipmentMode,
      shipmentSubMode: file.shipmentSubMode,
      compact: compact,
    );
  }

  bool get _isCourier {
    final mode = (shipmentMode ?? '').toLowerCase();
    final subMode = (shipmentSubMode ?? '').toLowerCase();
    final op = (courierOperator ?? '').trim();
    final track = (courierTrackingNo ?? '').trim();

    return op.isNotEmpty ||
        track.isNotEmpty ||
        mode.contains('courier') ||
        subMode.contains('courier') ||
        mode.contains('بريد') ||
        subMode.contains('بريد');
  }

  static String getTrackingUrl(String? operator, String trackingNo) {
    final cleanNo = Uri.encodeComponent(trackingNo.trim());
    final op = (operator ?? '').toUpperCase().trim();

    if (op.contains('DHL')) {
      return 'https://www.dhl.com/en/express/tracking.html?AWB=$cleanNo';
    } else if (op.contains('FEDEX')) {
      return 'https://www.fedex.com/fedextrack/?trknbr=$cleanNo';
    } else if (op.contains('UPS')) {
      return 'https://www.ups.com/track?tracknum=$cleanNo';
    } else if (op.contains('ARAMEX')) {
      return 'https://www.aramex.com/track/results?mode=0&ShipmentNumber=$cleanNo';
    }
    return 'https://www.google.com/search?q=${Uri.encodeComponent('${operator ?? 'Courier'} $cleanNo')}';
  }

  static Future<void> launchUrlSafe(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCourier || courierTrackingNo == null || courierTrackingNo!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final trackingNo = courierTrackingNo!.trim();

    return SelectionArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOperatorIcon(isAr: isAr, isDark: isDark),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _operatorLabel(isAr: isAr),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  ),
                ),
                Text(
                  trackingNo,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            AppButton(
              label: isAr ? 'نسخ' : 'Copy',
              icon: Icons.copy_rounded,
              size: AppButtonSize.small,
              variant: AppButtonVariant.ghost,
              tooltip: isAr ? 'نسخ رقم بوليصة التتبع' : 'Copy Tracking Number',
              onPressed: () => CopyHelper.copy(
                context,
                trackingNo,
                customMessage: isAr
                    ? 'تم نسخ رقم بوليصة الشحن السريع'
                    : 'Tracking number copied to clipboard',
              ),
            ),
            const SizedBox(width: 4),
            AppButton(
              label: isAr ? 'تتبع الشحنة' : 'Track',
              icon: Icons.travel_explore_rounded,
              size: AppButtonSize.small,
              variant: AppButtonVariant.primary,
              tooltip: isAr ? 'تتبع الشحنة مباشرة لدى شركة النقل السريع' : 'Open Live Tracking Page',
              onPressed: () => _showTrackingDetailsDialog(context, isAr: isAr, isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorIcon({required bool isAr, required bool isDark}) {
    final op = (courierOperator ?? '').toUpperCase().trim();
    IconData icon = Icons.local_shipping_outlined;
    Color iconColor = AppTheme.cobalt;
    Color bgColor = AppTheme.cobalt.withValues(alpha: 0.15);

    if (op.contains('DHL')) {
      icon = Icons.flash_on_rounded;
      iconColor = const Color(0xFFD40511);
      bgColor = const Color(0xFFFFCC00).withValues(alpha: 0.35);
    } else if (op.contains('FEDEX')) {
      icon = Icons.flight_takeoff_rounded;
      iconColor = const Color(0xFF4D148C);
      bgColor = const Color(0xFFFF6600).withValues(alpha: 0.25);
    } else if (op.contains('UPS')) {
      icon = Icons.inventory_2_rounded;
      iconColor = const Color(0xFF351C15);
      bgColor = const Color(0xFFFFB500).withValues(alpha: 0.25);
    } else if (op.contains('ARAMEX')) {
      icon = Icons.markunread_mailbox_rounded;
      iconColor = const Color(0xFFE31837);
      bgColor = const Color(0xFFE31837).withValues(alpha: 0.18);
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: iconColor),
    );
  }

  String _operatorLabel({required bool isAr}) {
    final op = (courierOperator ?? '').toUpperCase().trim();
    if (op.contains('DHL')) {
      return isAr ? 'البريد السريع دي إتش إل' : 'DHL Express';
    } else if (op.contains('FEDEX')) {
      return isAr ? 'البريد السريع فيديكس' : 'FedEx Express';
    } else if (op.contains('UPS')) {
      return isAr ? 'البريد السريع يو بي إس' : 'UPS Express';
    } else if (op.contains('ARAMEX')) {
      return isAr ? 'البريد السريع أرامكس' : 'Aramex';
    }
    return isAr ? 'بوليصة شحن بريد سريع' : 'Courier AWB';
  }

  void _showTrackingDetailsDialog(
    BuildContext context, {
    required bool isAr,
    required bool isDark,
  }) {
    final trackingNo = courierTrackingNo!.trim();
    final trackingUrl = getTrackingUrl(courierOperator, trackingNo);

    showDialog(
      context: context,
      builder: (ctx) {
        return SelectionArea(
          child: AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            title: Row(
              children: [
                _buildOperatorIcon(isAr: isAr, isDark: isDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAr ? 'تتبع بوليصة الشحن السريع' : 'Courier Tracking Details',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'شركة النقل السريع:' : 'Carrier:',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _operatorLabel(isAr: isAr),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Divider(height: 14),
                        Text(
                          isAr ? 'رقم بوليصة الشحن:' : 'Tracking Number / AWB:',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          trackingNo,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.cobalt,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (shipmentSubMode != null && shipmentSubMode!.isNotEmpty) ...[
                          const Divider(height: 14),
                          Text(
                            isAr ? 'نوع الشحنة الفرعي:' : 'Sub-mode:',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shipmentSubMode!,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isAr
                        ? 'يمكنك الانتقال مباشرة إلى صفحة التتبع الرسمية أو نسخ رقم البوليصة لمشاركته.'
                        : 'Navigate to the live carrier tracking portal or copy the tracking number.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: isAr ? 'نسخ رقم التتبع' : 'Copy Number',
                icon: Icons.copy_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () => CopyHelper.copy(
                  ctx,
                  trackingNo,
                  customMessage: isAr
                      ? 'تم نسخ رقم بوليصة الشحن السريع'
                      : 'Tracking number copied to clipboard',
                ),
              ),
              AppButton(
                label: isAr ? 'فتح موقع التتبع ↗' : 'Open Carrier Portal ↗',
                icon: Icons.open_in_new_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  launchUrlSafe(trackingUrl);
                  Navigator.of(ctx).pop();
                },
              ),
              AppButton(
                label: isAr ? 'إغلاق' : 'Close',
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}
