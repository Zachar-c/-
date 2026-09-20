# Third-Party Notices

## GDQuest Godot Open RPG (derived theme assets only)

- Source URL: https://github.com/gdquest-demos/godot-open-rpg.git
- Pinned commit: 19bd328fae9e4b534d3bb6db380a3d871d6ea58f
- License: MIT License
- Upstream code: removed from `vendor/` on 2026-09-20

The upstream source was audited at the pinned commit but is not shipped as a
runtime dependency. The vendored source tree was removed; this notice remains
because local theme assets were derived from that source.

UI theme textures under `assets/theme/` are copied from the same pinned commit:
`src/combat/ui/action_menu/*.png` and `src/combat/ui/battler_entry/*.png`,
licensed under the upstream MIT license and modified only by renaming for the
local `gu_theme.tres`.

```text
MIT License

Copyright (c) 2018 GDquest

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

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

## Ma Shan Zheng (马善政) — card title typeface

- Font name: Ma Shan Zheng
- Source URL: https://github.com/google/fonts/tree/main/ofl/mashanzheng
- License: **SIL Open Font License 1.1**
- License retained at: `assets/wenzhen/fonts/OFL1.1_MaShanZheng.txt`
- Font file: `assets/wenzhen/fonts/MaShanZheng-Regular.ttf`

Usage: card title typeface only (`TITLE_BRUSH_FONT` in
`scripts/presentation/gu_style.gd`), used by `gu_card_view.gd` for card face
titles. Distributed unmodified under its original name; the license copy ships
beside the font and must be included in exported builds.
