import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SettingsOptionCard extends StatelessWidget {
  final bool isDark;
  final bool isSelected;
  final IconData icon;
  final String title;
  final String badge;
  final String subtitle;
  final VoidCallback onTap;
  final Color cardBg;
  final Color borderColor;

  const SettingsOptionCard({
    super.key,
    required this.isDark,
    required this.isSelected,
    required this.icon,
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.onTap,
    required this.cardBg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    const selectedBorder = AppTheme.cobalt;
    final selectedBg = isDark
        ? AppTheme.cobalt.withValues(alpha: 0.18)
        : const Color(0xFFEFF6FF);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedBorder : borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.cobalt
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (isDark ? Colors.white : const Color(0xFF1E3A8A))
                                : (isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.cobalt.withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.cobalt
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.cobalt : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.cobalt
                      : (isDark ? AppTheme.darkTextMuted : const Color(0xFF94A3B8)),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
