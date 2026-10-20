import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../localization/app_localizations_ar.dart';
import '../theme/app_theme.dart';

class ShortcutDefinition {
  final List<String> keys;
  final String label;
  final String? note;

  const ShortcutDefinition({
    required this.keys,
    required this.label,
    this.note,
  });
}

class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => const KeyboardShortcutsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppTheme.isDark(context);
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ||
        l10n is AppLocalizationsAr;

    final navigationShortcuts = [
      ShortcutDefinition(
        keys: ['Ctrl', 'K'],
        label: l10n.shortcutCommandPalette,
      ),
      ShortcutDefinition(
        keys: ['Ctrl', 'Tab'],
        label: l10n.shortcutNextTab,
      ),
      ShortcutDefinition(
        keys: ['Ctrl', 'Shift', 'Tab'],
        label: l10n.shortcutPreviousTab,
      ),
      ShortcutDefinition(
        keys: ['Ctrl', 'W'],
        label: l10n.shortcutCloseTab,
      ),
      ShortcutDefinition(
        keys: ['F11'],
        label: l10n.shortcutToggleFullscreen,
      ),
      ShortcutDefinition(
        keys: ['ESC'],
        label: l10n.shortcutEscape,
      ),
    ];

    final operationsShortcuts = [
      ShortcutDefinition(
        keys: ['Ctrl', 'S'],
        label: l10n.shortcutSave,
      ),
      ShortcutDefinition(
        keys: ['Ctrl', 'N'],
        label: l10n.shortcutNewRecord,
      ),
      ShortcutDefinition(
        keys: ['Ctrl', 'D'],
        label: l10n.shortcutCloneRow,
      ),
      ShortcutDefinition(
        keys: ['Ctrl', 'F'],
        label: l10n.shortcutSearchTable,
      ),
    ];

    final productivityShortcuts = [
      ShortcutDefinition(
        keys: ['F1'],
        label: l10n.shortcutShowHelp,
      ),
      ShortcutDefinition(
        keys: ['Ctrl', '/'],
        label: l10n.shortcutShowHelp,
      ),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B232E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.keyboard_rounded,
                      color: AppTheme.cobalt,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.keyboardShortcutsTitle,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.keyboardShortcutsSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    splashRadius: 18,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Content Sections ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategorySection(
                      context,
                      title: l10n.shortcutsCategoryNavigation,
                      icon: Icons.navigation_rounded,
                      color: AppTheme.cobalt,
                      isDark: isDark,
                      shortcuts: navigationShortcuts,
                    ),
                    const SizedBox(height: 20),
                    _buildCategorySection(
                      context,
                      title: l10n.shortcutsCategoryOperations,
                      icon: Icons.flash_on_rounded,
                      color: AppTheme.emerald,
                      isDark: isDark,
                      shortcuts: operationsShortcuts,
                    ),
                    const SizedBox(height: 20),
                    _buildCategorySection(
                      context,
                      title: l10n.shortcutsCategoryProductivity,
                      icon: Icons.lightbulb_outline_rounded,
                      color: AppTheme.orange,
                      isDark: isDark,
                      shortcuts: productivityShortcuts,
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141A22) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'تعمل هذه الاختصارات بصورة فورية على بيئة سطح المكتب لجميع الشاشات'
                          : 'These shortcuts operate globally across all desktop screens',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      foregroundColor: isDark ? Colors.white : AppTheme.charcoal,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isArabic ? 'إغلاق' : 'Close',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required List<ShortcutDefinition> shortcuts,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A22) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shortcuts.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.6,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            itemBuilder: (context, index) {
              final shortcut = shortcuts[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        shortcut.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey.shade200 : AppTheme.charcoal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (int i = 0; i < shortcut.keys.length; i++) ...[
                          _buildKeyCap(isDark, shortcut.keys[i]),
                          if (i < shortcut.keys.length - 1)
                            Text(
                              '+',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeyCap(bool isDark, String keyName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            offset: const Offset(0, 1.5),
            blurRadius: 1,
          ),
        ],
      ),
      child: Text(
        keyName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF334155),
        ),
      ),
    );
  }
}
