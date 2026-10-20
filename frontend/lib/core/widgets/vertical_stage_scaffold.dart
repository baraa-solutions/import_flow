import 'package:flutter/material.dart';
import '../services/display_name_resolver.dart';
import '../theme/app_theme.dart';
import 'back_to_dashboard_button.dart';
import 'shipment_stage_lifecycle_control.dart';

class VerticalNavTabItem {
  final IconData icon;
  final String titleAr;
  final String titleEn;
  final Widget? badge;

  const VerticalNavTabItem({
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    this.badge,
  });
}

class VerticalStageScaffold extends StatelessWidget {
  final String stageCode;
  final String titleAr;
  final String titleEn;
  final IconData headerIcon;
  final Color headerColor;
  final List<VerticalNavTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Widget body;
  final List<Widget>? headerActions;
  final Widget? topBanner;
  final int? selectedImportFileId;
  final bool showStageLifecycleControls;
  final VoidCallback? onShipmentStatusChanged;

  const VerticalStageScaffold({
    super.key,
    required this.stageCode,
    required this.titleAr,
    required this.titleEn,
    required this.headerIcon,
    this.headerColor = AppTheme.cobalt,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.body,
    this.headerActions,
    this.topBanner,
    this.selectedImportFileId,
    this.showStageLifecycleControls = true,
    this.onShipmentStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectableBody = SelectionArea(child: body);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Top Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.charcoal,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final isArabic = Directionality.of(context) == TextDirection.rtl;
                final badgeText = DisplayNameResolver.resolveStageBadge(stageCode, isArabic: isArabic);

                final iconAndTitle = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: headerColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: headerColor.withOpacity(0.5)),
                      ),
                      child: Icon(headerIcon, color: headerColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            isArabic ? titleAr : titleEn,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                          if (badgeText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: headerColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: headerColor.withOpacity(0.6)),
                              ),
                              child: Text(
                                badgeText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );

                final hasControls = showStageLifecycleControls;
                final hasActions = headerActions != null && headerActions!.isNotEmpty;
                final hasButtons = hasControls || hasActions;

                // When action buttons/controls compete with the title on screens < 1280px,
                // wrap to two clean tiers so the title ALWAYS renders in full without truncation:
                // Tier 1: Title + Stage Badge + Back to Dashboard Button (Title gets full width)
                // Tier 2: Lifecycle controls and Action buttons in a compact unified row.
                final shouldWrapActions = hasButtons && headerConstraints.maxWidth < 1280;

                if (shouldWrapActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: iconAndTitle),
                          const SizedBox(width: 12),
                          BackToDashboardButton(isCompact: headerConstraints.maxWidth < 700),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasControls) ...[
                                ShipmentStageLifecycleControl(
                                  importFileId: selectedImportFileId,
                                  stageName: Directionality.of(context) == TextDirection.rtl ? titleAr : titleEn,
                                  stageCode: stageCode,
                                  stageNameEn: titleEn,
                                  onStatusChanged: onShipmentStatusChanged,
                                ),
                                if (hasActions) const SizedBox(width: 8),
                              ],
                              if (hasActions) ...headerActions!,
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (headerConstraints.maxWidth < 700) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: iconAndTitle),
                          const SizedBox(width: 8),
                          const BackToDashboardButton(),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: iconAndTitle),
                    if (showStageLifecycleControls) ...[
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ShipmentStageLifecycleControl(
                            importFileId: selectedImportFileId,
                            stageName: Directionality.of(context) == TextDirection.rtl ? titleAr : titleEn,
                            stageCode: stageCode,
                            stageNameEn: titleEn,
                            onStatusChanged: onShipmentStatusChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (headerActions != null) ...[
                      Flexible(
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: headerActions!,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    const BackToDashboardButton(),
                  ],
                );
              },
            ),
          ),

          // Shipment On-Hold Prominent Alert Banner
          if (showStageLifecycleControls && selectedImportFileId != null)
            ShipmentHoldWarningBanner(
              importFileId: selectedImportFileId,
              currentStageName: Directionality.of(context) == TextDirection.rtl ? titleAr : titleEn,
              onResumeSuccess: onShipmentStatusChanged,
            ),

          // Optional Top Banner (e.g. Legal Compliance, Warning, Info)
          if (topBanner != null) topBanner!,

          // Main Horizontal Workspace: Vertical Sub-Nav Sidebar + Expanded Content Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, workspaceConstraints) {
                final isMobileNav = workspaceConstraints.maxWidth < 700;

                if (isMobileNav) {
                  return Column(
                    children: [
                      // Horizontal Compact Tabs Strip
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          itemCount: tabs.length,
                          itemBuilder: (context, index) {
                            final tab = tabs[index];
                            final isSelected = selectedIndex == index;
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(tab.icon, size: 14, color: isSelected ? Colors.white : AppTheme.cobalt),
                                    const SizedBox(width: 4),
                                    Text(Directionality.of(context) == TextDirection.rtl ? tab.titleAr : tab.titleEn),
                                    if (tab.badge != null) ...[
                                      const SizedBox(width: 4),
                                      tab.badge!,
                                    ],
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor: headerColor,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppTheme.charcoal,
                                ),
                                onSelected: (_) => onTabSelected(index),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(child: selectableBody),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vertical Sub-Navigation Sidebar (Ultra-Compact)
                    Container(
                      width: 215,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: BorderDirectional(
                      start: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sub-Nav Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.view_sidebar_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                Directionality.of(context) == TextDirection.rtl ? 'العمليات والإجراءات' : 'Operations & Stages',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tabs List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          itemCount: tabs.length,
                          itemBuilder: (context, index) {
                            final tab = tabs[index];
                            final isSelected = selectedIndex == index;
                            final isRtl = Directionality.of(context) == TextDirection.rtl;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? headerColor.withOpacity(0.5) : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Material(
                                color: isSelected ? headerColor.withOpacity(0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => onTabSelected(index),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isSelected ? headerColor : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(
                                            tab.icon,
                                            size: 13,
                                            color: isSelected ? Colors.white : Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isRtl ? tab.titleAr : tab.titleEn,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              color: isSelected ? headerColor : Colors.grey.shade800,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (tab.badge != null) tab.badge!,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Active Tab Content View (Takes 100% remaining space)
                Expanded(
                  child: Container(
                    color: Colors.grey.shade100,
                    child: selectableBody,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  ),
);
  }
}
