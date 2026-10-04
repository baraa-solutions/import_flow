import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../localization/app_localizations_ar.dart';
import '../services/command_palette_registry.dart';
import '../theme/app_theme.dart';

class CommandPaletteDialog extends StatefulWidget {
  final WidgetRef ref;

  const CommandPaletteDialog({super.key, required this.ref});

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => CommandPaletteDialog(ref: ref),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  List<CommandPaletteItem> _allItems = [];
  List<CommandPaletteItem> _filteredItems = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItems();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _loadItems() {
    _allItems = CommandPaletteRegistry.getItems(context, widget.ref);
    _applyFilter();
  }

  String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[\s\-_/]+'), ' ')
        .trim();
  }

  void _onSearchChanged() {
    setState(() {
      _applyFilter();
    });
  }

  void _applyFilter() {
    final rawQuery = _searchCtrl.text.trim();
    if (rawQuery.isEmpty) {
      _filteredItems = List.from(_allItems);
    } else {
      final q = _normalizeString(rawQuery);
      final tokens = q.split(' ').where((t) => t.isNotEmpty).toList();

      _filteredItems = _allItems.where((item) {
        final titleNorm = _normalizeString(item.title);
        final subNorm = _normalizeString(item.subtitle);
        final badgeNorm = item.badge != null ? _normalizeString(item.badge!) : '';
        final keywordsNorm = item.keywords.map(_normalizeString).join(' ');

        final fullText = '$titleNorm $subNorm $badgeNorm $keywordsNorm';
        return tokens.every((token) => fullText.contains(token));
      }).toList();
    }

    if (_selectedIndex >= _filteredItems.length) {
      _selectedIndex = max(0, _filteredItems.length - 1);
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_filteredItems.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _filteredItems.length;
        });
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_filteredItems.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + _filteredItems.length) % _filteredItems.length;
        });
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _selectCurrent();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToSelected() {
    if (!_scrollCtrl.hasClients || _filteredItems.isEmpty) return;
    const itemHeight = 64.0;
    final targetOffset = _selectedIndex * itemHeight;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final safeOffset = targetOffset.clamp(0.0, maxScroll);
    _scrollCtrl.animateTo(
      safeOffset,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  void _selectCurrent() {
    if (_filteredItems.isEmpty || _selectedIndex < 0 || _selectedIndex >= _filteredItems.length) {
      return;
    }
    final item = _filteredItems[_selectedIndex];
    Navigator.of(context).pop();
    if (item.onSelect != null) {
      item.onSelect!(context, widget.ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppTheme.isDark(context);
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ||
        l10n is AppLocalizationsAr;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final dialogWidth = min(720.0, screenWidth - 32);
    final dialogHeight = min(540.0, screenHeight - 64);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B232E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.6 : 0.25),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── 1. Top Search Header ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    const Icon(
                      Icons.travel_explore_rounded,
                      color: AppTheme.cobalt,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _focusNode,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.charcoal,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.commandPaletteSearchHint,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        splashRadius: 16,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        onPressed: () {
                          _searchCtrl.clear();
                          _focusNode.requestFocus();
                        },
                      ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        'ESC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 2. Results List ──
              Expanded(
                child: _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.commandPaletteNoResults,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: _filteredItems.length,
                        itemExtent: 64.0,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = index == _selectedIndex;

                          Color categoryColor;
                          String categoryName;
                          switch (item.category) {
                            case CommandPaletteCategory.screens:
                              categoryColor = AppTheme.cobalt;
                              categoryName = l10n.commandPaletteCategoryScreens;
                              break;
                            case CommandPaletteCategory.actions:
                              categoryColor = AppTheme.emerald;
                              categoryName = l10n.commandPaletteCategoryActions;
                              break;
                            case CommandPaletteCategory.records:
                              categoryColor = AppTheme.orange;
                              categoryName = l10n.commandPaletteCategoryRecords;
                              break;
                          }

                          return InkWell(
                            onTap: () {
                              setState(() => _selectedIndex = index);
                              _selectCurrent();
                            },
                            onHover: (hovering) {
                              if (hovering && _selectedIndex != index) {
                                setState(() => _selectedIndex = index);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF253346) : const Color(0xFFEFF6FF))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(
                                        color: isDark ? AppTheme.cobaltLight.withOpacity(0.5) : AppTheme.cobalt.withOpacity(0.4),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // Category icon box
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? categoryColor.withOpacity(0.18)
                                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      size: 20,
                                      color: isSelected ? categoryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Title and Subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                  color: isDark ? Colors.white : AppTheme.charcoal,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: categoryColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.badge ?? categoryName,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: categoryColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Enter action hint for selected
                                  if (isSelected)
                                    Container(
                                      margin: const EdgeInsetsDirectional.only(start: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isArabic ? 'فتح' : 'Open',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.keyboard_return_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ── 3. Bottom Footer Cheat-Sheet ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    _buildShortcutHint(isDark, '↑ ↓', isArabic ? 'للتنقل' : 'Navigate'),
                    const SizedBox(width: 14),
                    _buildShortcutHint(isDark, '↵ Enter', isArabic ? 'للاختيار' : 'Select'),
                    const SizedBox(width: 14),
                    _buildShortcutHint(isDark, 'ESC', isArabic ? 'للإغلاق' : 'Close'),
                    const Spacer(),
                    Text(
                      isArabic ? '${_filteredItems.length} نتيجة' : '${_filteredItems.length} results',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutHint(bool isDark, String keyText, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            keyText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
