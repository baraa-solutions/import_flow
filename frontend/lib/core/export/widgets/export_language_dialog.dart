import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../export_language.dart';

/// Modal dialog that allows the user to pick the language (Arabic or English)
/// before exporting or printing any PDF/Excel document in Sorour Logistics ERP.
/// Respects user's saved preferences and allows skipping the prompt via "remember choice".
class ExportLanguageDialog extends StatefulWidget {
  final ExportLanguage initialLanguage;

  const ExportLanguageDialog({
    super.key,
    required this.initialLanguage,
  });

  /// Displays the language picker modal.
  /// If user has previously configured a default export language in Settings or checked "Remember choice",
  /// it skips the prompt and returns that language immediately.
  static Future<ExportLanguage?> show(
    BuildContext context, {
    ExportLanguage? defaultLang,
    bool forcePrompt = false,
  }) async {
    if (!forcePrompt) {
      final savedDefault = await ExportLanguage.getSavedDefaultOption();
      if (savedDefault == ExportLanguage.optionAr) return ExportLanguage.ar;
      if (savedDefault == ExportLanguage.optionEn) return ExportLanguage.en;
    }

    if (!context.mounted) return null;

    // Determine initial selection
    ExportLanguage initial = defaultLang ?? ExportLanguage.ar;
    final lastChosen = await ExportLanguage.getLastChosenLanguage();
    if (lastChosen != null) {
      initial = lastChosen;
    } else {
      try {
        if (context.mounted) {
          final currentLocale = Localizations.localeOf(context);
          initial = currentLocale.languageCode == 'en' ? ExportLanguage.en : ExportLanguage.ar;
        }
      } catch (_) {}
    }

    if (!context.mounted) return null;

    return showDialog<ExportLanguage?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ExportLanguageDialog(initialLanguage: initial),
    );
  }

  @override
  State<ExportLanguageDialog> createState() => _ExportLanguageDialogState();
}

class _ExportLanguageDialogState extends State<ExportLanguageDialog> {
  late ExportLanguage _selected;
  bool _rememberChoice = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLanguage;
  }

  void _onConfirm() async {
    await ExportLanguage.saveLastChosenLanguage(_selected);
    if (_rememberChoice) {
      await ExportLanguage.saveDefaultOption(_selected.code);
    }
    if (mounted) {
      Navigator.of(context).pop(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final dialogBg = isDark ? const Color(0xFF1E2631) : Colors.white;
    final cardBg = isDark ? const Color(0xFF253140) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1);

    // Text helpers using current selection or UI locale
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      backgroundColor: dialogBg,
      child: SelectionArea(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Row ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: AppTheme.cobalt, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'تحديد لغة التحميل والتصدير' : 'Select Export Language',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAr
                              ? 'اختر لغة الملف (PDF / Excel) المراد تنزيله:'
                              : 'Choose document language for PDF / Excel download:',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: isAr ? 'إلغاء' : 'Cancel',
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Option 1: Arabic ──
              _buildLanguageCard(
                lang: ExportLanguage.ar,
                title: 'اللغة العربية (Arabic)',
                subtitle: 'ملف عربي موحد، اتجاه RTL، وتنسيق مطابق للمستندات الجمركية المصرية',
                badge: 'RTL',
                isSelected: _selected == ExportLanguage.ar,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
              const SizedBox(height: 10),

              // ── Option 2: English ──
              _buildLanguageCard(
                lang: ExportLanguage.en,
                title: 'English (الإنجليزية)',
                subtitle: 'Full English document, LTR layout, international trade standard',
                badge: 'LTR',
                isSelected: _selected == ExportLanguage.en,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
              const SizedBox(height: 16),

              // ── Remember Choice Checkbox ──
              InkWell(
                onTap: () => setState(() => _rememberChoice = !_rememberChoice),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _rememberChoice,
                        activeColor: AppTheme.cobalt,
                        onChanged: (val) => setState(() => _rememberChoice = val ?? false),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr
                                  ? 'تذكر اختياري كلغة افتراضية للتصدير'
                                  : 'Remember as default export language',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                            Text(
                              isAr
                                  ? 'يمكنك تعديل هذا الخيار لاحقاً من الإعدادات الأساسية للنظام'
                                  : 'You can change this anytime in System Settings',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextMuted : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Action Buttons ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(
                      isAr ? 'إلغاء' : 'Cancel',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      isAr ? 'تأكيد وتنزيل' : 'Confirm & Download',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _onConfirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildLanguageCard({
    required ExportLanguage lang,
    required String title,
    required String subtitle,
    required String badge,
    required bool isSelected,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    final activeBorder = isSelected ? AppTheme.cobalt : borderColor;
    final activeBg = isSelected
        ? (isDark ? AppTheme.cobalt.withValues(alpha: 0.18) : const Color(0xFFEFF6FF))
        : cardBg;

    return InkWell(
      onTap: () => setState(() => _selected = lang),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: activeBg,
          border: Border.all(color: activeBorder, width: isSelected ? 1.8 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Radio<ExportLanguage>(
              value: lang,
              groupValue: _selected,
              activeColor: AppTheme.cobalt,
              onChanged: (val) {
                if (val != null) setState(() => _selected = val);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.cobalt
                              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
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
}
