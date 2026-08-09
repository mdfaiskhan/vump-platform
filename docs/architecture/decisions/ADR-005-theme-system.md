# ADR-005 — Token-Based Material 3 Theme System

- **Status:** Accepted
- **Date:** 2026-08-09
- **Supersedes:** none

## Context

A professional platform needs a visual language that is consistent across every surface and legible in both light and dark appearance. Left to per-widget styling, colour and spacing values accumulate as literals in build methods, light and dark drift apart, and a rebrand becomes a codebase-wide search.

The design language had to be fixed before feature screens were built, because unstyled screens written first must all be revisited.

## Decision

The application uses a Material 3 theme built from centralised design tokens.

**Colour is centralised absolutely.** Every `Color` literal in the application lives in `app/theme/app_colors.dart`. No other file may declare one. Widgets read colour from the active `ColorScheme` via `Theme.of(context)`.

**Both schemes are explicit, not seed-generated.** `AppColors.light` and `AppColors.dark` are `const ColorScheme` declarations with every role stated. A finalised design language uses colours that are chosen rather than derived, so the two brightnesses stay in deliberate correspondence.

**Status colours Material 3 does not model are carried as a `ThemeExtension`.** `ColorScheme` defines an error role but no success or warning role. `AppSemanticColors` supplies both, registered in `ThemeData.extensions`, so they are brightness-aware and reachable the same way every other colour is.

**Non-colour values are tokens.** Spacing, radius, duration, size, elevation and opacity each have a dedicated token file under `app/theme/`. No layout may declare a spacing, radius or duration literal.

**Both themes are produced by one builder.** `AppTheme.light` and `AppTheme.dark` both route through a single private `_build`, so they can differ only in `ColorScheme` and status colours. Everything structural is shared by construction.

**Theme mode follows the system.** `themeModeProvider` returns `ThemeMode.system`.

## Alternatives Considered

- **`ColorScheme.fromSeed`** — used initially, then rejected. Deriving 40+ roles algorithmically means the palette shifts if the seed or the Flutter tonal algorithm changes, and light and dark are two independent derivations rather than a designed pair.
- **Raw statics for success and warning** — rejected. They force every call site to branch on brightness, which is exactly the logic a theme exists to remove.
- **Per-widget styling with no token layer** — rejected. It is the default outcome, and it is what this decision exists to prevent.
- **A third-party design system package** — rejected. It would impose a visual identity that is not Vump's.

## Consequences

- A rebrand is a change to one file.
- Light and dark cannot drift apart in anything except colour, because nothing else is declared twice.
- Consumers of success and warning must reach through `Theme.of(context).extension<AppSemanticColors>()`, which is more verbose than a static and must be documented for contributors.
- Explicit schemes mean adding a colour role is a manual edit in two places — the light scheme and the dark scheme. This is the accepted cost of not deriving them.
- The token files are declared ahead of consumers, so many tokens are currently unreferenced. This is intended: a token that exists prevents a literal from being written.
- Any `Color` literal outside `app_colors.dart` is a defect.

## Related Missions

- Mission 0.7.1 — Theme Foundation, which established the light and dark themes and `themeModeProvider`.
- Mission 0.7.2 — Design Tokens, which added the spacing, radius, duration and size scales.
- Mission 0.7.2 — UI Design Language, which finalised the palette, added the semantic colour extension and refined typography.
- Mission 0.8.1 — Configuration Cleanup, which split elevation and opacity into dedicated token files.

## Implementation Status

Fully implemented. Component theming covers the app bar, cards, dividers, icons, all four button variants, inputs and snack bars. No feature screen consumes the design language yet — `HomeScreen` renders unstyled text.
