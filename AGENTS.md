# Fairytrail Flutter UI — Agent Rules

**Scope:** Apply only when working under `flutter/`. Do not apply these rules to `api/` or other packages.

## Core rules

1. **Use custom widgets only** for UI. Prefer the shared widgets in `lib/widgets/` (exported via `lib/widgets/widgets.dart`).
2. **Follow existing screen patterns.** Mirror nearby screens in the same feature folder before inventing new layout or styling.
3. **If a needed widget does not exist, or you have any UI doubt — stop and ask first.** Do not invent one-off Text/Button/Scaffold styles or hardcode colors/fonts to “make it look right.”
4. **Titles always use `AppText` with `AppTextVariant.title`.** Do not use raw `Text` for titles, and do not invent custom title font sizes.
5. **Always support light and dark theme.** Use theme / `AppColors.*Of(context)` helpers — never hardcode light-only colors for text, surfaces, or borders.

Reference demo of shared widgets: `lib/screens/profile/widgets_showcase_screen.dart`.

---

## Required widgets (use these)

| Need | Use |
|------|-----|
| Screen shell / app bar | `AppScaffold` |
| Safe area | `AppSafeArea` |
| Title / body / labels | `AppText` + `AppTextVariant` |
| Buttons | `AppButton` (`primary` / `secondary` / `text`) |
| Single-line input | `AppTextField` |
| Multi-line input | `AppTextArea` |
| Card container | `AppCard` |
| Empty state | `AppEmptyView` |
| Dialogs | `AppDialog` |
| Toasts | `AppToast` |
| Images | `AppCachedImage` |
| Tabs | `AppSlidingTabs` |
| Date / age pickers | `AppDatePicker` / `AppAgePicker` |
| Multi-select sheet | `AppMultiSelectSheet` |
| Progress | `AppProgressBar` |

Import via:

```dart
import 'package:fairytrail/widgets/widgets.dart';
```

Do **not** use raw Material `ElevatedButton` / `OutlinedButton` / `TextField` / `SafeArea` / ad-hoc `Text` styling when an `App*` widget covers the case.

**Safe area:** always use `AppSafeArea`, never Flutter’s `SafeArea`. `AppScaffold` already wraps its body. Use `AppSafeArea` for sheets, custom `Scaffold`s, and any other inset. It drops the bottom inset while the keyboard is open so text fields do not show a white bar above the IME. Pass `top: false` / `bottom: false` when an edge is already handled (app bar, chat composer, floating nav).

---

## Typography

Font: **Outfit** (via `AppTheme`). Do not introduce other font families.

Use `AppText` variants only — do not pass one-off `fontSize` unless matching an existing screen that already does so for a clear reason.

| Variant | Use for | Theme size |
|---------|---------|------------|
| `display` | Hero / success / processing headlines | 28 / w600 |
| `headline` | Large section headers (rare) | 20 / w500 |
| **`title`** | **All titles** (screen, section, card, sheet) | **20 / w600** |
| `body` | Primary body copy | 16 / w400 |
| `bodySmall` | Secondary body / helper under fields | 14 / w400 |
| `label` | Field labels, chips, compact emphasis | 14 / w500 |
| `caption` | Muted hints, meta, empty-state subtitles | 12 / secondary |

Examples:

```dart
AppText('Account settings', variant: AppTextVariant.title),
AppText('We’ll email you a link.', variant: AppTextVariant.body),
AppText('Optional', variant: AppTextVariant.caption),
```

---

## Colors & theming

Source of truth:

- `lib/theme/app_colors.dart`
- `lib/theme/app_theme.dart`

Use context-aware helpers so dark mode works:

```dart
AppColors.textPrimaryOf(context)
AppColors.textSecondaryOf(context)
AppColors.backgroundOf(context)
AppColors.surfaceOf(context)
AppColors.borderOf(context)
AppColors.primary          // brand accent (same in both themes)
```

Rules:

- Prefer `Theme.of(context).colorScheme` / `AppColors.*Of(context)` over literal `Colors.grey`, `Color(0xFF…)`, etc.
- Do not assume white backgrounds or black text.
- Borders / dividers: `AppColors.borderOf(context)` or `colorScheme.outline`.
- Default corner radius for cards/inputs/buttons: **12** (already in theme / `AppCard`).

---

## Spacing (match existing screens)

Observed conventions across screens — stay on this scale; don’t invent odd values (e.g. 13, 17, 22).

### Screen horizontal padding

| Context | Typical padding |
|---------|-----------------|
| Signup / form steps | `EdgeInsets.fromLTRB(24, 8, 24, 24)` |
| Content / settings / sheets | horizontal **20** (often `fromLTRB(20, …, 20, 24)`) |
| List / card-heavy screens | horizontal **16** |
| Auth / welcome / centered CTA | horizontal **24–28** |
| Empty / success / session states | horizontal **24–32** |

Prefer `AppScaffold(padding: …)` when the whole body shares one inset.

### Vertical rhythm (`SizedBox` gaps)

| Gap | Typical use |
|-----|-------------|
| **8** | Label → field, tight stacked rows |
| **12** | Related blocks inside a card/section |
| **16** | Between sections / title → body |
| **20–24** | Before primary CTA / major section break |
| **32** | Empty-state outer padding / large breathing room |

`AppCard` default padding: `EdgeInsets.symmetric(horizontal: 16, vertical: 12)`.

Bottom safe area: use `AppSafeArea` (or `AppScaffold`) — do not add `MediaQuery.viewPadding` / `SafeArea` yourself. Extra `8 + bottom` padding is only for floating nav overlap.

### Before changing layout

Compare 1–2 sibling screens in the same feature (e.g. other files under `lib/screens/signup/steps/`, `lib/screens/auth/`, `lib/screens/profile/`) and reuse their padding, gaps, and widget choices.

---

## Patterns to copy

- **New screen:** start with `AppScaffold` + `AppText` titles + `AppButton` CTAs.
- **Insets:** `AppSafeArea` instead of `SafeArea` (skip if the screen already uses `AppScaffold`).
- **Forms:** `AppTextField` / `AppTextArea`; label spacing already includes an 8px gap.
- **Empty / unfinished:** `AppEmptyView`.
- **Confirm / alert:** `AppDialog.show` / `AppDialog.confirm`.
- **Feature-specific UI** already lives under `lib/components/<feature>/` — extend those before adding parallel widgets.

---

## Ask first when

- No suitable widget in `lib/widgets/`
- Unsure which `AppTextVariant` / padding to use
- Tempted to hardcode colors, fonts, or raw Material controls
- Design seems to conflict with light/dark support
- You would introduce a new shared widget or change theme tokens

When in doubt: **ask before coding UI.**
