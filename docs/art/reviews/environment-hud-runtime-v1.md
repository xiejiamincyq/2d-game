# Environment and HUD Runtime v1 Review

Date: 2026-08-18
Review state: gameplay-approved

## Decision

The revised industrial floor and overdrive HUD are approved for the
five-minute-overdrive branch. The work improves visual hierarchy while reducing
retained Canvas draw commands and preserving responsive UI contracts.

## Environment result

The old floor emitted roughly 49,923 tile-level base and edge commands before its
lanes and detail marks. The revised renderer uses one ground field, 64-pixel minor
lines, 256-pixel major lines, 512-pixel service lanes, outlined industrial plates,
and deterministic wear markers. Its retained list is 496 draw commands, below the
declared 900-command ceiling.

The new ground remains darker than actors and combat effects. Cyan vertical service
lanes, restrained orange horizontal lanes, and low-alpha panel accents provide
orientation without competing with bullets or enemy silhouettes.

## HUD result

- Top cards now use a near-black opaque field, one-pixel cyan border, three-pixel
  top accent, compact corners, and a restrained shadow.
- Every progress bar has an explicit dark track with a low-alpha cyan border.
- Overdrive charge now lives in a dedicated centered bottom capsule. Inactive
  charge reads `超载 N%` in cyan; active state reads `超载运行` with a magenta fill
  and border.
- The active fill color is changed on the `StyleBoxFlat` itself. This removes the
  old color-multiplication path that could darken or distort the intended hue.

## Verification and evidence

- Real 1280x720 combat capture:
  `docs/art/previews/characters-combat/player-m2-runtime-combat-v1.png`.
- `UITest` passes 68 assertions across 960x540, 1280x720, 1920x1080, and
  2560x1080, including contrast, focus target, responsive minimum-size, and both
  overdrive capsule states.
- `PerformanceTest` passes 28 assertions and directly verifies that the floor
  renders a non-empty retained command list below the 900-command ceiling.
- `SmokeTest` passes 23 assertions after the floor renderer replacement.

No generated source or third-party material was added, so this increment introduces
no new asset-license dependency.
