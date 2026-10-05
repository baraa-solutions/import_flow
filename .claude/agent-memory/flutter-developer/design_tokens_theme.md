---
name: design-tokens-theme
description: AppTheme semantic tokens (surface/border/severity/radius/shadow), _buildTheme, AppSeverity, AppTheme.snackBar; theme pitfalls
metadata:
  type: project
---

AppTheme (frontend/lib/core/theme/app_theme.dart) builds light/dark via `_buildTheme`. Additive tokens: `surface`,
`surfaceAlt`, `border`, `borderStrong`, `textPrimary`, `textCaption`, `success/warning/danger/infoBackground|Foreground`,
`radiusSm/Md/Lg/Xl` (6/8/12/16), `shadowSoft`, `shadowFloating`; adaptive `surfaceOf/borderOf/textPrimaryOf/
textSecondaryOf/textMutedOf(context)`, `severityColor/BackgroundOf`, `AppSeverity` enum, `AppTheme.snackBar(...)`.
Pitfalls: textTheme letterSpacing is 0 on purpose (positive tracking breaks Arabic joining); do not set a global
iconTheme/IconButton foreground (AppBar icons turn grey); MetricCard value width must subtract icon chip padding+gap.
`.withOpacity` is deprecated: use `.withValues(alpha:)`.
