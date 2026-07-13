# Neon Science-Fiction Style Guide

## Fixed Direction

Create high-resolution illustrated assets for a dark cyber-wasteland viewed from a top-down or top-down three-quarter camera. Preserve clean outer silhouettes and concentrate detail inside large forms so artwork remains readable during dense combat at the 1280×720 base viewport.

## Palette

- Background black-blue: `#061019`
- Primary cyan: `#33fff2`
- Secondary magenta: `#f559bf`
- Weapon and warning orange: `#ff571f`
- Acid green: reserve for Spitter attacks, healing, or explicit toxic cues

Do not give every asset all accent colors. Actors receive one dominant faction accent and one small functional accent. Backgrounds use lower saturation and contrast than actors, hazards, pickups, and HUD state.

## Lighting and Materials

- Use controlled cyan rim light as the shared scene light.
- Use magenta bounce light sparingly to separate planes.
- Reserve warm orange emission for player weapons, warnings, and high-priority interaction cues.
- Favor worn composite armor, oxidized metal, dark ceramic, smoked glass, exposed energy conduits, and dusty synthetic fabric.
- Avoid glossy showroom cyberpunk, crowded signage, photorealistic street scenes, thin loose cables, and decorative highlights that resemble hit effects.

## Source and Runtime Sizes

| Asset | Source target | Runtime target | Background |
|---|---:|---:|---|
| Player or standard enemy master | 1024×1024 | 64×64 | Transparent |
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

Reject baked-in text, accidental borders, cropped anatomy, opaque halos around transparent assets, mixed camera angles, noisy silhouettes, unreadable faction colors, excessive bloom, background contrast that competes with hazards, and UI decoration that reduces label space.
