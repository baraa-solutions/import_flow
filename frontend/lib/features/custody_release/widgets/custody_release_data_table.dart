import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/custody_release_model.dart';

/// Data table and listing widget for customs custody dossiers.
class CustodyReleaseDataTable extends StatelessWidget {
  final List<CustodyReleaseDossierModel> dossiers;
  final bool isLoading;
  final void Function(CustodyReleaseDossierModel)? onFreeze;
  final void Function(CustodyReleaseDossierModel)? onClearance;
  final void Function(CustodyReleaseDossierModel)? onBreach;
  final void Function(CustodyReleaseDossierModel)? onDelete;

  const CustodyReleaseDataTable({
    super.key,
    required this.dossiers,
    required this.isLoading,
    this.onFreeze,
    this.onClearance,
    this.onBreach,
    this.onDelete,
  });

  static String statusLabel(String status, bool isArabic) {
    switch (status) {
      case 'RELEASED_UNDER_CUSTODY':
        return isArabic ? 'إفراج مؤقت تحت التحفظ' : 'Released Under Custody';
      case 'FROZEN_IN_WAREHOUSE':
        return isArabic ? 'مجمدة بالمخزن (قيد الفحص)' : 'Frozen in Warehouse';
      case 'SAMPLE_CLEAR_FINAL_RELEASE':
        return isArabic ? 'مطابقة وإفراج نهائي' : 'Sample Clear - Final Release';
      case 'BREACH_REPORTED':
        return isArabic ? 'إبلاغ عن فض أحراز / مخالفة' : 'Breach Reported';
      default:
        return status;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'RELEASED_UNDER_CUSTODY':
        return Colors.orange;
      case 'FROZEN_IN_WAREHOUSE':
        return AppTheme.cobalt;
      case 'SAMPLE_CLEAR_FINAL_RELEASE':
        return AppTheme.emerald;
      case 'BREACH_REPORTED':
        return AppTheme.crimson;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dossiers.isEmpty) {
      return Center(
        child: Text(
          isArabic
              ? 'لا توجد ملفات إفراج تحت التحفظ مطابقة'
              : 'No custody dossiers found',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: dossiers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = dossiers[index];
        return Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lock badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.lockActive
                        ? Colors.orange.withValues(alpha: 0.15)
                        : AppTheme.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.lockActive
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    color: item.lockActive ? Colors.orange : AppTheme.emerald,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Main details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () => CopyHelper.copy(context, item.custodyCode),
                            child: Text(
                              item.custodyCode,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.cobalt,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${isArabic ? 'تعهد رقم:' : 'Undertaking:'} ${item.custodyUndertakingNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor(item.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel(item.status, isArabic),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: statusColor(item.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (item.warehouseAddress != null)
                            Text(
                              '${isArabic ? 'المخزن:' : 'Warehouse:'} ${item.warehouseAddress}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          Text(
                            '${isArabic ? 'عدد السيل:' : 'Seals:'} ${item.leadSealsCount} ${item.leadSealNumbers.isNotEmpty ? "(${item.leadSealNumbers.join(', ')})" : ""}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          if (item.transportPermitNumber != null)
                            Text(
                              '${isArabic ? 'تصريح نقل:' : 'Permit:'} ${item.transportPermitNumber}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          if (item.judicialOfficerName != null)
                            Text(
                              '${isArabic ? 'مأمور الضبط:' : 'Officer:'} ${item.judicialOfficerName}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                        ],
                      ),
                      if (item.finalClearanceLetterNumber != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${isArabic ? 'إذن الإفراج النهائي:' : 'Final release letter:'} ${item.finalClearanceLetterNumber}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.emerald,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      if (item.breachReason != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${isArabic ? 'بلاغ الخرق:' : 'Breach details:'} ${item.breachReason}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.crimson,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) {
                    if (action == 'freeze') {
                      onFreeze?.call(item);
                    } else if (action == 'clearance') {
                      onClearance?.call(item);
                    } else if (action == 'breach') {
                      onBreach?.call(item);
                    } else if (action == 'delete') {
                      onDelete?.call(item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'freeze',
                      child: Row(
                        children: [
                          const Icon(Icons.warehouse_rounded, color: AppTheme.cobalt, size: 18),
                          const SizedBox(width: 8),
                          Text(isArabic ? 'تأكيد وصول وتجميد المخزن' : 'Freeze in Warehouse'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clearance',
                      child: Row(
                        children: [
                          const Icon(Icons.lock_open_rounded, color: AppTheme.emerald, size: 18),
                          const SizedBox(width: 8),
                          Text(isArabic ? 'إفراج نهائي وفك الحظر 🔓' : 'Final Clearance'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'breach',
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 18),
                          const SizedBox(width: 8),
                          Text(isArabic ? 'إبلاغ عن فض أحراز ⚠️' : 'Report Breach'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                          const SizedBox(width: 8),
                          Text(isArabic ? 'حذف السجل' : 'Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
