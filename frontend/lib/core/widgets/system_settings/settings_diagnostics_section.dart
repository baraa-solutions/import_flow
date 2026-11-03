import 'package:flutter/material.dart';
import '../../constants/api_constants.dart';
import '../../theme/app_theme.dart';

class SettingsDiagnosticsSection extends StatelessWidget {
  final bool isDark;
  final bool isArabic;
  final Color cardBg;
  final Color borderColor;
  final bool isClearingCache;
  final Future<void> Function() onClearCache;

  const SettingsDiagnosticsSection({
    super.key,
    required this.isDark,
    required this.isArabic,
    required this.cardBg,
    required this.borderColor,
    required this.isClearingCache,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  isArabic ? 'حالة النظام / الإصدار:' : 'System Version:',
                  'Sorour Logistics ERP v${ApiConstants.clientVersion} (Build ${ApiConstants.clientBuildNumber})',
                  isDark: isDark,
                  trailingIcon: Icons.verified_rounded,
                  iconColor: AppTheme.cobalt,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  isArabic ? 'خادم الواجهة الخلفية (Backend API):' : 'Backend API Service:',
                  '${ApiConstants.serverUrl} (FastAPI / Uvicorn)',
                  isDark: isDark,
                  trailingIcon: Icons.cloud_done_rounded,
                  iconColor: AppTheme.emerald,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  isArabic ? 'قاعدة البيانات التشغيلية:' : 'Active Database:',
                  'sorour_logistics.db (SQLite WAL Mode)',
                  isDark: isDark,
                  trailingIcon: Icons.storage_rounded,
                  iconColor: AppTheme.cobalt,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  isArabic ? 'شريط الساعات الدولية الموحد:' : 'Live World Clocks:',
                  isArabic
                      ? 'مفعل بنظام 24H (القاهرة، شنغهاي، هامبورغ، دبي، لندن، نيويورك)'
                      : 'Active 24H (Cairo, Shanghai, Hamburg, Dubai, London, New York)',
                  isDark: isDark,
                  trailingIcon: Icons.access_time_rounded,
                  iconColor: AppTheme.emerald,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Clear cache and refresh action
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2631) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cached_rounded,
                  color: AppTheme.cobalt,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'تحديث الذاكرة المؤقتة وإعادة المزامنة' : 'Clear Local Cache & Force Resync',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'إعادة تحميل كافة بيانات الموردين والشركات المرجعية من السيرفر مباشرة'
                            : 'Force-refresh all providers and refetch latest master data from backend',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: isClearingCache
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    isArabic ? 'تحديث فوري' : 'Sync Now',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: isClearingCache ? null : onClearCache,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    required bool isDark,
    IconData? trailingIcon,
    Color? iconColor,
  }) {
    return Row(
      children: [
        if (trailingIcon != null) ...[
          Icon(trailingIcon, size: 16, color: iconColor ?? AppTheme.cobalt),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
