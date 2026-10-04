import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Represents a single tab item inside [AdaptiveTabScaffold].
class AdaptiveTabItem {
  final IconData icon;
  final String label;
  final Widget content;
  final Widget? badge;
  final String? tooltip;

  const AdaptiveTabItem({
    required this.icon,
    required this.label,
    required this.content,
    this.badge,
    this.tooltip,
  });
}

/// The layout mode currently adopted by [AdaptiveTabScaffold].
enum AdaptiveTabLayoutMode {
  /// Standard horizontal tab bar (used when space is abundant and tab count is low).
  horizontal,

  /// Vertical side navigation panel (used when horizontal space is constrained or tabs >= threshold).
  sidebar,

  /// Compact mobile dropdown/drawer bar (used when screen width is too narrow even for a sidebar).
  dropdown,
}

/// A unified, responsive navigation component that dynamically adapts its layout
/// based on available width and tab count.
///
/// Features:
/// - Eliminates horizontal tab-bar scrolling entirely.
/// - Automatically switches to a vertical sidebar when tab count >= [tabCountThreshold]
///   or when horizontal width < [sidebarThresholdWidth].
/// - Automatically converts to a compact dropdown selector when width < [dropdownThresholdWidth].
/// - Keeps the active tab synchronized across all layout modes.
/// - Preserves identical tab content rendering without state loss.
class AdaptiveTabScaffold extends StatefulWidget {
  final List<AdaptiveTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onTabSelected;
  final TabController? controller;
  final Color accentColor;
  final double sidebarWidth;
  final double sidebarThresholdWidth;
  final double dropdownThresholdWidth;
  final int tabCountThreshold;
  final Widget? header;
  final Widget? trailingHeaderAction;
  final EdgeInsetsGeometry contentPadding;
  final bool maintainState;

  const AdaptiveTabScaffold({
    super.key,
    required this.tabs,
    this.selectedIndex = 0,
    this.onTabSelected,
    this.controller,
    this.accentColor = AppTheme.cobalt,
    this.sidebarWidth = 220.0,
    this.sidebarThresholdWidth = AppTheme.tabBarSidebarThreshold,
    this.dropdownThresholdWidth = AppTheme.tabBarDropdownThreshold,
    this.tabCountThreshold = AppTheme.tabCountSidebarThreshold,
    this.header,
    this.trailingHeaderAction,
    this.contentPadding = EdgeInsets.zero,
    this.maintainState = true,
  });

  @override
  State<AdaptiveTabScaffold> createState() => _AdaptiveTabScaffoldState();
}

class _AdaptiveTabScaffoldState extends State<AdaptiveTabScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.controller?.index ?? widget.selectedIndex;
    widget.controller?.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant AdaptiveTabScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChange);
      widget.controller?.addListener(_handleControllerChange);
      if (widget.controller != null) {
        _currentIndex = widget.controller!.index;
      }
    } else if (widget.controller == null && widget.selectedIndex != oldWidget.selectedIndex) {
      _currentIndex = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    if (widget.controller != null && widget.controller!.index != _currentIndex) {
      setState(() {
        _currentIndex = widget.controller!.index;
      });
    }
  }

  void _onSelectTab(int index) {
    if (index < 0 || index >= widget.tabs.length) return;
    setState(() {
      _currentIndex = index;
    });
    if (widget.controller != null) {
      widget.controller!.animateTo(index);
    }
    widget.onTabSelected?.call(index);
  }

  AdaptiveTabLayoutMode _resolveLayoutMode(double availableWidth) {
    if (availableWidth < widget.dropdownThresholdWidth) {
      return AdaptiveTabLayoutMode.dropdown;
    }
    // Estimated width needed for horizontal tabs without cramped text (~140px per tab + margins)
    final estimatedRequiredTabSpace = widget.tabs.length * 140.0;
    if (availableWidth < widget.sidebarThresholdWidth ||
        availableWidth < estimatedRequiredTabSpace ||
        widget.tabs.length >= widget.tabCountThreshold) {
      return AdaptiveTabLayoutMode.sidebar;
    }
    return AdaptiveTabLayoutMode.horizontal;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeIndex = _currentIndex.clamp(0, widget.tabs.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = _resolveLayoutMode(constraints.maxWidth);
        final isBounded = constraints.hasBoundedHeight;

        switch (mode) {
          case AdaptiveTabLayoutMode.dropdown:
            return _buildDropdownLayout(safeIndex, isBounded);
          case AdaptiveTabLayoutMode.sidebar:
            return _buildSidebarLayout(safeIndex, constraints.maxWidth, isBounded);
          case AdaptiveTabLayoutMode.horizontal:
            return _buildHorizontalLayout(safeIndex, isBounded);
        }
      },
    );
  }

  // ── 1. Horizontal Tabs Layout ──────────────────────────────────────────────
  Widget _buildHorizontalLayout(int activeIndex, bool isBounded) {
    final content = Padding(
      padding: widget.contentPadding,
      child: _buildContentBody(activeIndex),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.header != null) widget.header!,
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(widget.tabs.length, (index) {
                    final item = widget.tabs[index];
                    final isSelected = index == activeIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () => _onSelectTab(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected ? widget.accentColor : Colors.transparent,
                                width: 3.0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: isSelected ? widget.accentColor : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? widget.accentColor : Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.badge != null) ...[
                                const SizedBox(width: 6),
                                item.badge!,
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (widget.trailingHeaderAction != null) widget.trailingHeaderAction!,
            ],
          ),
        ),
        if (isBounded) Expanded(child: content) else content,
      ],
    );
  }

  // ── 2. Vertical Sidebar Layout ─────────────────────────────────────────────
  Widget _buildSidebarLayout(int activeIndex, double availableWidth, bool isBounded) {
    final effectiveSidebarWidth = (availableWidth * 0.28).clamp(160.0, widget.sidebarWidth);

    Widget buildSidebarList() {
      final items = List.generate(widget.tabs.length, (index) {
        final item = widget.tabs[index];
        final isSelected = index == activeIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Tooltip(
            message: item.tooltip ?? item.label,
            waitDuration: const Duration(milliseconds: 600),
            child: Material(
              color: isSelected ? widget.accentColor.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _onSelectTab(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? widget.accentColor.withOpacity(0.4) : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isSelected ? widget.accentColor : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          item.icon,
                          size: 15,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? widget.accentColor : Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.badge != null) ...[
                        const SizedBox(width: 4),
                        item.badge!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });

      if (isBounded) {
        return Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            children: items,
          ),
        );
      } else {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items,
          ),
        );
      }
    }

    final sidebarPanel = Container(
      width: effectiveSidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: BorderDirectional(
          end: BorderSide(color: Colors.grey.shade300, width: 1.0),
          start: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(1, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          buildSidebarList(),
          if (widget.trailingHeaderAction != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: widget.trailingHeaderAction!,
            ),
        ],
      ),
    );

    final content = Padding(
      padding: widget.contentPadding,
      child: _buildContentBody(activeIndex),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sidebarPanel,
        Expanded(child: content),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.header != null) widget.header!,
        if (isBounded) Expanded(child: row) else row,
      ],
    );
  }

  // ── 3. Compact Dropdown Selector Layout (Mobile / Narrow) ───────────────────
  Widget _buildDropdownLayout(int activeIndex, bool isBounded) {
    final content = Padding(
      padding: widget.contentPadding,
      child: _buildContentBody(activeIndex),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.header != null) widget.header!,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.accentColor.withOpacity(0.3),
                      width: 1.2,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: activeIndex,
                      icon: Icon(Icons.arrow_drop_down_circle_outlined, color: widget.accentColor, size: 20),
                      items: List.generate(widget.tabs.length, (index) {
                        final tab = widget.tabs[index];
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tab.icon, size: 16, color: widget.accentColor),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  tab.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: index == activeIndex ? FontWeight.bold : FontWeight.normal,
                                    color: index == activeIndex ? widget.accentColor : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tab.badge != null) ...[
                                const SizedBox(width: 6),
                                tab.badge!,
                              ],
                            ],
                          ),
                        );
                      }),
                      onChanged: (newIdx) {
                        if (newIdx != null) _onSelectTab(newIdx);
                      },
                    ),
                  ),
                ),
              ),
              if (widget.trailingHeaderAction != null) ...[
                const SizedBox(width: 8),
                widget.trailingHeaderAction!,
              ],
            ],
          ),
        ),
        if (isBounded) Expanded(child: content) else content,
      ],
    );
  }

  // ── Helper: Content Body ───────────────────────────────────────────────────
  Widget _buildContentBody(int activeIndex) {
    if (widget.maintainState) {
      return IndexedStack(
        index: activeIndex,
        children: widget.tabs.map((t) => t.content).toList(),
      );
    } else {
      return widget.tabs[activeIndex].content;
    }
  }
}
