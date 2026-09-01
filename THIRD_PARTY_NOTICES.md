# Third-Party Notices

## GDQuest Godot Open RPG

- Source URL: https://github.com/gdquest-demos/godot-open-rpg.git
- Pinned commit: 19bd328fae9e4b534d3bb6db380a3d871d6ea58f
- License: MIT License
- License retained at: `vendor/godot-open-rpg/LICENSE`

The upstream source was audited at the pinned commit but is not shipped as a
runtime dependency. The repository retains the MIT license and attribution
because local theme assets were derived from that source.

UI theme textures under `assets/theme/` are copied from the same pinned commit:
`src/combat/ui/action_menu/*.png` and `src/combat/ui/battler_entry/*.png`,
licensed under the upstream MIT license and modified only by renaming for the
local `gu_theme.tres`.

## GUT

- Source URL: https://github.com/bitwes/Gut
- Version: 9.6.1
- License: MIT License
- License retained at: `addons/gut/LICENSE.md`

## LXGW ZhiSong CL (霞鹜致宋) — game typeface

- Font name: LXGW ZhiSong CL
- Version: 0.290 (April 9, 2024)
- Source URL: https://github.com/lxgw/LxgwZhiSong
- License: **IPA Font License 1.0** (SPDX: `IPA`)
- License retained at: `assets/wenzhen/fonts/IPA_FONT_LICENSE.txt`
- Font file: `assets/wenzhen/fonts/LXGWZhiSongCL-Regular.ttf`

Copyright notice, verbatim from the font's `name` table (nameID 0):

```
Copyright(c) 2024 LXGW; Information-technology Promotion Agency, Japan (IPA), 2003-2019.
You must accept "https://opensource.org/licenses/IPA/" to use this product.
```

Usage: this is the project's title and body typeface (`TITLE_FONT` / `BODY_FONT` in
`scripts/presentation/gu_style.gd`), embedded into the shipped game build.

**License caveat — this font is NOT under SIL OFL 1.1.** LXGW ZhiSong is derived
from IPAex Mincho / IPAmj Mincho and is licensed under IPA Font License 1.0. The
upstream project explicitly states that IPA Font License 1.0 and SIL OFL 1.1 are
incompatible, so do not substitute an OFL copy for it. Per Article 3.2(3), a copy
of the license must accompany any redistribution of the font file — that copy is
kept beside the font itself and must be included in exported builds.

Obligations that apply to this project:

- Redistribution requires attaching a copy of the license (Article 3.2(3)).
- The font file must be redistributed unmodified and under its original name
  (Article 3.2(1) and 3.2(2)) — do not rename or subset it for release.
- The embedded copyright notice must not be removed.
- Commercial use, embedding and digital distribution are permitted
  (Article 2.2, 2.3, 2.5).

"IPA Font" / "IPAフォント" is a registered trademark of the Information-technology
Promotion Agency, Japan.
