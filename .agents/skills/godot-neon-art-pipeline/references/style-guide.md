# 2D Chibi Bio-Farm Style Guide

## Fixed Direction

Create original, fully opaque 2D chibi assets for an abandoned bio-farm laboratory viewed from one fixed elevated oblique camera. Use compact toy-like proportions, rounded shapes, clean medium outlines, minimal texture, and large color blocks so artwork remains readable during dense combat at the 1280×720 base viewport.

The selected direction is **B — 清爽玩具**. It may use the broad readability principles of compact arena-survival games, but it must not copy any existing character, costume, weapon, enemy, interface, or composition.

The player body and firearm are separate layers. The firearm remains attached to explicit hand sockets and must never orbit freely around the body. Player body facing is represented by four cardinal views (front, back, left, right); horizontal aim variation is handled by the weapon layer within a limited, anatomically plausible range.

## Palette

- Background/deep outline: `#123b3b`
- Player teal: `#35b8ac`
- Bio-farm mint: `#9bd7bd`
- Warm cream: `#f3eddc`
- Weapon and warning coral-orange: `#f27a4b`
- Acid green: `#82cf45`, reserved for poison, hostile spores, healing, or explicit toxicity

Do not give every asset all accent colors. Actors receive one dominant faction accent and one small functional accent. Backgrounds use lower saturation and contrast than actors, hazards, pickups, and HUD state.

## Lighting and Materials

- Use soft upper-left key light and one restrained cool lower-right shadow family.
- Reserve coral-orange for player weapons, warnings, and high-priority interaction cues.
- Favor painted farm-lab plastics, enamel panels, rounded tanks, rubber hoses, planter soil, greenhouse glass, and simplified bio-growth.
- Avoid glossy 3D rendering, realistic materials, cyberpunk neon overload, thin loose cables, and decorative highlights that resemble hit effects.

## Source and Runtime Sizes

| Asset | Source target | Runtime target | Background |
|---|---:|---:|---|
| Player cardinal body atlas | 2048×2048 | four 64×64 cells | Transparent |
| Player weapon master | 1024×1024 | 64×64 bounding box | Transparent |
| Standard enemy master | 1024×1024 | 64×64 | Transparent |
| Bruiser or large enemy master | 1024×1024 | 96×96 | Transparent |
| Pickup or projectile master | 512×512 | 24×24 to 48×48 | Transparent |
| Combat effect master | 1024×1024 | Determined by gameplay radius | Transparent or overlay |
| Battlefield background | 2560×1440 | 1280×720 base viewport | Opaque |
| Environment prop | 1024×1024 | 64×64 to 256×256 | Transparent |
| UI icon | 256×256 | 24×24 to 64×64 | Transparent |
| UI panel or frame | 2048×1024 | Responsive | Transparent, nine-patch-ready |

Keep transparent padding below 10% on isolated assets unless an effect needs intentional overflow. Keep contact points stable and place actor visual centers over their collision centers.

## Batch Gates

1. Characters/combat: approve player, one standard enemy, one large enemy, and one effect as the style-lock set.
2. Environment: approve one battlefield crop, one structure, and one atmospheric overlay before expanding the batch.
3. UI: approve one panel, one button treatment, and one icon family before expanding the batch.

Do not begin the next batch until the current style-lock set is approved.

## Rejection Conditions

Reject baked-in text, accidental borders, cropped anatomy, semi-transparent bodies, opaque halos around transparent assets, mixed camera angles, fake 3D turntables, freely orbiting weapons, noisy silhouettes, unreadable faction colors, excessive bloom, background contrast that competes with hazards, and UI decoration that reduces label space.
