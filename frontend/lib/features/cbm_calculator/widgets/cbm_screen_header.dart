import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class CbmScreenHeader extends StatelessWidget {
  final TabController tabController;

  const CbmScreenHeader({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1600;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: isCompact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppTheme.darkScaffoldBackground, AppTheme.cobaltMedium]
                  : [AppTheme.charcoal, AppTheme.cobalt],
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
            ),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calculate_outlined, color: AppTheme.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.cbmCalculatorTitle,
                                style: const TextStyle(color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                l.cbmCalculatorSubtitle,
                                style: const TextStyle(color: AppTheme.cloudWhite, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const BackToDashboardButton(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TabBar(
                      controller: tabController,
                      isScrollable: true,
                      indicatorColor: AppTheme.orange,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelColor: Colors.white70,
                      labelColor: AppTheme.orange,
                      tabs: [
                        Tab(icon: const Icon(Icons.speed), text: l.quickOperationalCalculatorTab),
                        Tab(icon: const Icon(Icons.history), text: l.savedCalculationsRegistryTab),
                        Tab(icon: const Icon(Icons.view_in_ar_rounded), text: context.l10n.isArabic ? 'محاكي تحميل الحاويات 3D' : 'Container 3D Loader'),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.calculate_outlined, color: AppTheme.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.cbmCalculatorTitle,
                            style: const TextStyle(color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l.cbmCalculatorSubtitle,
                            style: const TextStyle(color: AppTheme.cloudWhite, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const BackToDashboardButton(),
                    const SizedBox(width: 10),
                    Flexible(
                      child: TabBar(
                        controller: tabController,
                        isScrollable: true,
                        indicatorColor: AppTheme.orange,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelColor: Colors.white70,
                        labelColor: AppTheme.orange,
                        tabs: [
                          Tab(icon: const Icon(Icons.speed), text: l.quickOperationalCalculatorTab),
                          Tab(icon: const Icon(Icons.history), text: l.savedCalculationsRegistryTab),
                          Tab(icon: const Icon(Icons.view_in_ar_rounded), text: context.l10n.isArabic ? 'محاكي تحميل الحاويات 3D' : 'Container 3D Loader'),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
